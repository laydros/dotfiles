"""Tests for merge_shared_settings. Run: python3 -m unittest ~/.claude/scripts/test_merge_shared_settings.py"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import merge_shared_settings as m  # noqa: E402


class MergeTests(unittest.TestCase):
    def test_shared_scalar_overrides_local_scalar(self):
        self.assertEqual(m.merge({"a": 1}, {"a": 2}), {"a": 2})

    def test_local_only_keys_survive(self):
        self.assertEqual(m.merge({"model": "opus"}, {"env": {}}), {"model": "opus", "env": {}})

    def test_nested_objects_merge_key_by_key(self):
        local = {"env": {"LOCAL_ONLY": "1", "SHARED": "old"}}
        shared = {"env": {"SHARED": "new"}}
        self.assertEqual(m.merge(local, shared), {"env": {"LOCAL_ONLY": "1", "SHARED": "new"}})

    def test_arrays_are_replaced_not_appended(self):
        local = {"hooks": {"PreToolUse": [{"matcher": "stale"}]}}
        shared = {"hooks": {"PreToolUse": [{"matcher": "Bash"}]}}
        self.assertEqual(m.merge(local, shared), shared)

    def test_shared_object_replaces_local_scalar_of_same_key(self):
        self.assertEqual(m.merge({"env": "oops"}, {"env": {"A": "1"}}), {"env": {"A": "1"}})

    def test_inputs_are_not_mutated(self):
        local = {"env": {"A": "1"}}
        shared = {"env": {"B": "2"}}
        m.merge(local, shared)
        self.assertEqual(local, {"env": {"A": "1"}})
        self.assertEqual(shared, {"env": {"B": "2"}})


class ApplyTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.local = os.path.join(self.dir, "settings.json")
        self.shared = os.path.join(self.dir, "settings.shared.json")

    def write(self, path, obj):
        with open(path, "w", encoding="utf-8") as f:
            json.dump(obj, f)

    def read(self, path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)

    def test_creates_local_file_when_missing(self):
        self.write(self.shared, {"hooks": {}})
        changed = m.apply(self.shared, self.local)
        self.assertTrue(changed)
        self.assertEqual(self.read(self.local), {"hooks": {}})

    def test_reports_no_change_when_already_merged(self):
        self.write(self.shared, {"env": {"A": "1"}})
        self.write(self.local, {"env": {"A": "1"}, "model": "opus"})
        self.assertFalse(m.apply(self.shared, self.local))

    def test_refuses_to_clobber_unparseable_local_file(self):
        self.write(self.shared, {"env": {}})
        with open(self.local, "w", encoding="utf-8") as f:
            f.write("{not json")
        with self.assertRaises(m.MergeError):
            m.apply(self.shared, self.local)
        with open(self.local, encoding="utf-8") as f:
            self.assertEqual(f.read(), "{not json")

    def test_fails_when_shared_file_missing(self):
        with self.assertRaises(m.MergeError):
            m.apply(self.shared, self.local)

    def test_rejects_shared_file_that_is_not_an_object(self):
        self.write(self.shared, [1, 2])
        with self.assertRaises(m.MergeError):
            m.apply(self.shared, self.local)

    def test_written_file_keeps_local_only_keys_and_ends_with_newline(self):
        self.write(self.shared, {"hooks": {"PreToolUse": []}})
        self.write(self.local, {"model": "opus"})
        m.apply(self.shared, self.local)
        with open(self.local, encoding="utf-8") as f:
            raw = f.read()
        self.assertTrue(raw.endswith("\n"))
        self.assertEqual(json.loads(raw), {"model": "opus", "hooks": {"PreToolUse": []}})

    def test_leaves_no_temp_file_behind(self):
        self.write(self.shared, {"env": {}})
        m.apply(self.shared, self.local)
        self.assertEqual(sorted(os.listdir(self.dir)), ["settings.json", "settings.shared.json"])


if __name__ == "__main__":
    unittest.main()
