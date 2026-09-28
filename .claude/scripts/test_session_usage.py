"""Tests for session_usage. Run: python3 -m unittest ~/.claude/scripts/test_session_usage.py"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_usage as su  # noqa: E402


def assistant(mid, model, usage, sidechain=False):
    return {"type": "assistant", "isSidechain": sidechain, "timestamp": "2026-09-28T12:00:00Z",
            "message": {"id": mid, "model": model, "usage": usage, "content": []}}


class UsageTests(unittest.TestCase):
    def transcript(self, records):
        fd, path = tempfile.mkstemp(suffix=".jsonl")
        with os.fdopen(fd, "w") as fh:
            for r in records:
                fh.write(json.dumps(r) + "\n")
        self.addCleanup(os.remove, path)
        return path

    def test_streamed_copies_of_one_message_count_once_using_the_last(self):
        path = self.transcript([
            assistant("m1", "claude-opus-5-5", {"input_tokens": 100, "output_tokens": 10}),
            assistant("m1", "claude-opus-5-5", {"input_tokens": 1000, "output_tokens": 100,
                                                "cache_read_input_tokens": 10000}),
        ])
        u = su.usage_of(path, main_only=True)
        self.assertEqual(u["tot"]["requests"], 1)
        self.assertEqual(u["tot"]["input"], 1000)
        # 1000 in at $4, 10000 cache reads at $0.20, 100 out at $20, per million
        self.assertAlmostEqual(u["dollars"], 0.008)

    def test_sidechain_records_stay_out_of_the_main_thread(self):
        path = self.transcript([
            assistant("m1", "claude-opus-5-5", {"input_tokens": 1000}),
            assistant("m2", "claude-opus-5-5", {"input_tokens": 5000}, sidechain=True),
        ])
        self.assertEqual(su.usage_of(path, main_only=True)["tot"]["input"], 1000)
        self.assertEqual(su.usage_of(path, main_only=False)["tot"]["input"], 5000)

    def test_sonnet_is_priced_as_sonnet_not_opus(self):
        path = self.transcript([
            assistant("m1", "claude-sonnet-5", {"input_tokens": 1_000_000}),
        ])
        self.assertAlmostEqual(su.usage_of(path)["dollars"], 2.00)

    def test_opus_5_cache_reads_cost_a_tenth_of_input_not_a_twentieth(self):
        # Opus 5.5 reads are 5% of input; Opus 5's were 10%. Pricing old runs at the new
        # ratio understated them by about 40% (checked against Claude Code's cost records).
        path = self.transcript([
            assistant("m1", "claude-opus-5", {"cache_read_input_tokens": 1_000_000}),
        ])
        self.assertAlmostEqual(su.usage_of(path)["dollars"], 0.50)

    def test_one_hour_cache_writes_cost_twice_input(self):
        path = self.transcript([
            assistant("m1", "claude-sonnet-5", {
                "cache_creation_input_tokens": 1_000_000,
                "cache_creation": {"ephemeral_5m_input_tokens": 0,
                                   "ephemeral_1h_input_tokens": 1_000_000}}),
        ])
        self.assertAlmostEqual(su.usage_of(path)["dollars"], 4.00)

    def test_unknown_model_is_flagged_not_silently_priced(self):
        path = self.transcript([
            assistant("m1", "claude-mystery-9", {"input_tokens": 1_000_000}),
        ])
        u = su.usage_of(path)
        self.assertEqual(u["unpriced"], {"claude-mystery-9"})
        self.assertAlmostEqual(u["dollars"], 4.00)

    def test_compactions_are_counted(self):
        path = self.transcript([
            {"type": "system", "subtype": "compact_boundary", "timestamp": "2026-09-28T12:00:00Z",
             "compactMetadata": {"trigger": "auto", "preTokens": 180000}},
        ])
        self.assertEqual(len(su.usage_of(path, main_only=True)["compacts"]), 1)


if __name__ == "__main__":
    unittest.main()
