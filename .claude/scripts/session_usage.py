#!/usr/bin/env python3
"""Sum token usage and estimated cost for Claude Code sessions, main thread and subagents apart.

Usage: session_usage.py SESSION_JSONL [SESSION_JSONL ...]
Transcripts live in ~/.claude/projects/<project>/<session-id>.jsonl, with subagent transcripts
under <session-id>/subagents/. Prints counts only, never message content.

Prefer Claude Code's own figure when it prints: it comes from the session's cost-state record,
covers subagents too, and has counted 7-22% more cache reads than the transcripts show. The
estimate here is a floor, but it is the only way to split main thread from subagents. Both are
API-rate dollars; on a Max plan they measure usage, not what is billed.
"""
import collections
import glob
import json
import os
import sys
from datetime import datetime

# $ per million tokens: (input, output, cache read, 5-minute cache write, 1-hour cache write).
# Checked 2026-09-28 against Claude Code's cost-state records: every session fits these.
# Cache-read ratios differ by model: Opus 5.5 is 5% of input, Opus 5 and Sonnet 5 are 10%.
PRICES = {
    "claude-opus-5-5": (4.0, 20.0, 0.20, 5.0, 8.0),
    "claude-opus-5": (5.0, 25.0, 0.50, 6.25, 10.0),
    "claude-sonnet-5": (2.0, 10.0, 0.20, 2.5, 4.0),
}
FALLBACK_MODEL = "claude-opus-5-5"


def price_of(model):
    """Price tuple for a model ID, and whether it had to fall back."""
    if model in PRICES:
        return PRICES[model], False
    return PRICES[FALLBACK_MODEL], True


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def usage_of(path, main_only=None):
    """Sum one transcript's usage, deduplicated by message ID (the last record wins).

    main_only=True keeps main-thread records only; None keeps everything, which is right for a
    subagent's own transcript.
    """
    per_id = {}
    first = last = None
    compacts = []
    turn_ms = 0
    cost_states = []
    skills = []
    agents = []
    with open(path) as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            t = d.get("timestamp")
            if t:
                first = first or t
                last = t
            typ = d.get("type")
            if typ == "cost-state":
                cost_states.append(d)
                continue
            if main_only is not None and d.get("isSidechain", False) == main_only:
                continue
            if typ == "system":
                st = d.get("subtype")
                if st == "compact_boundary":
                    cm = d.get("compactMetadata") or {}
                    compacts.append((t, cm.get("trigger"), cm.get("preTokens")))
                elif st == "turn_duration":
                    turn_ms += d.get("durationMs") or 0
            if typ != "assistant":
                continue
            m = d.get("message") or {}
            mid = m.get("id") or d.get("requestId") or d.get("uuid")
            u = m.get("usage")
            if u:
                per_id[mid] = (m.get("model"), u)
            for c in m.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    inp = c.get("input") or {}
                    if c.get("name") == "Skill":
                        skills.append((t, inp.get("skill")))
                    elif c.get("name") in ("Agent", "Task"):
                        agents.append((t, inp.get("model")))

    tot = collections.Counter()
    models = collections.Counter()
    unpriced = set()
    dollars = 0.0
    max_ctx = 0
    for model, u in per_id.values():
        if model == "<synthetic>":
            continue
        models[model] += 1
        (p_in, p_out, p_read, p_w5, p_w1), fell_back = price_of(model)
        if fell_back:
            unpriced.add(model)
        cc = u.get("cache_creation") or {}
        w5 = cc.get("ephemeral_5m_input_tokens")
        w1 = cc.get("ephemeral_1h_input_tokens")
        cw = u.get("cache_creation_input_tokens") or 0
        if w5 is None and w1 is None:
            w5, w1 = cw, 0
        w5, w1 = w5 or 0, w1 or 0
        inp = u.get("input_tokens") or 0
        cr = u.get("cache_read_input_tokens") or 0
        out = u.get("output_tokens") or 0
        tot["requests"] += 1
        tot["input"] += inp
        tot["cache_write"] += cw
        tot["cache_read"] += cr
        tot["output"] += out
        dollars += (inp * p_in + cr * p_read + out * p_out + w5 * p_w5 + w1 * p_w1) / 1e6
        max_ctx = max(max_ctx, inp + cw + cr)
    return dict(tot=tot, dollars=dollars, models=models, unpriced=unpriced, first=first,
                last=last, compacts=compacts, turn_ms=turn_ms, cost_states=cost_states,
                skills=skills, agents=agents, max_ctx=max_ctx)


def fmt(tot, dollars):
    total = tot["input"] + tot["cache_write"] + tot["cache_read"] + tot["output"]
    return (f"req={tot['requests']} in={tot['input']:,} cache_write={tot['cache_write']:,} "
            f"cache_read={tot['cache_read']:,} out={tot['output']:,} total={total:,} ${dollars:.2f}")


def report(path):
    sid = os.path.basename(path)[: -len(".jsonl")]
    print("=" * 100)
    print("SESSION", sid)
    main = usage_of(path, main_only=True)
    if main["first"]:
        span_h = (ts(main["last"]) - ts(main["first"])).total_seconds() / 3600
        print(f" span {main['first']} -> {main['last']} ({span_h:.1f}h), "
              f"active {main['turn_ms'] / 3.6e6:.2f}h")
    print(" MAIN ", fmt(main["tot"], main["dollars"]), " models", dict(main["models"]),
          f" max_ctx={main['max_ctx']:,}")
    print(" compactions", len(main["compacts"]), main["compacts"])
    print(" skills", [s[1] for s in main["skills"]])
    print(" agent dispatches", len(main["agents"]), "by model",
          dict(collections.Counter(a[1] for a in main["agents"])))
    if main["cost_states"]:
        cs = main["cost_states"][-1]
        print(f" Claude Code's own figure: ${cs.get('totalCostUSD', 0):.2f}")

    subdir = os.path.join(os.path.dirname(path), sid, "subagents")
    sub_tot = collections.Counter()
    sub_dollars = 0.0
    unpriced = set(main["unpriced"])
    rows = []
    for sp in sorted(glob.glob(os.path.join(subdir, "**", "*.jsonl"), recursive=True)):
        su = usage_of(sp)
        meta = {}
        mp = sp[: -len(".jsonl")] + ".meta.json"
        if os.path.exists(mp):
            with open(mp) as fh:
                meta = json.load(fh)
        sub_tot.update(su["tot"])
        sub_dollars += su["dollars"]
        unpriced |= su["unpriced"]
        rows.append((su["first"] or "", meta.get("model"), meta.get("spawnDepth"),
                     su["dollars"], su["tot"]["requests"], su["max_ctx"]))
    if rows:
        print(" SUBS ", fmt(sub_tot, sub_dollars), " n=", len(rows))
        for first, model, depth, dol, req, ctx in sorted(rows):
            print(f"   {first[:16]} model={model} depth={depth} ${dol:.2f} req={req} max_ctx={ctx:,}")
    print(" BOTH ", fmt(main["tot"] + sub_tot, main["dollars"] + sub_dollars))
    if unpriced:
        print(f" note: no price for {sorted(unpriced)}; priced as {FALLBACK_MODEL}")


def main(argv):
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    for path in argv:
        report(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
