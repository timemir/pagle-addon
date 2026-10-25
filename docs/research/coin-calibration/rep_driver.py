#!/usr/bin/env python3
"""Runs repeatable.py (the #395 model with #401 rarity goals and #398 refresh tickets) for one constants set and
returns, per player, the cumulative COUNTS of every repeatable payout by calendar day, the steady counts per day, and
the intra-day shape (counts by hours played that day). Counts, not coins: calibrate.py prices them, so a pay change
that does not change the player's behaviour is re-priced without a re-run (and the finals are re-run with the pay).

    python -I docs/research/coin-calibration/rep_driver.py            # smoke test: the #395 baseline

Players (the same four as #396's combine.py): casual 1.5 h/day, dedicated 4 h/day, min-max 1.5 h/day, min-max 4 h/day.
"""
from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import repeatable as R  # noqa: E402

ANCHORS = [1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 90, 120, 150, 180]
COUNT_FIELDS = ["n1_n", "n2_n", "n3_n", "exp_n", "ev1_n", "evk_n", "runs_done", "xp_board", "xp_event", "tickets_earned",
                "tickets_used", "tickets_lost", "hours_used", "lit"]
HOURS_GRID = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0]

PLAYERS = {
    # key: (label, hours/day, Params kwargs, sweep policy)
    "casual": ("Casual 1.5 h/day", 1.5, {}, "typical"),
    "dedicated": ("Dedicated 4 h/day", 4.0, {}, "typical"),
    "minmax15": ("Min-max 1.5 h/day", 1.5, dict(hop_min=2.0, reroll_floor=0.6, align_timed=True), "minmax"),
    "minmax4": ("Min-max 4 h/day", 4.0, dict(hop_min=2.0, reroll_floor=0.6, align_timed=True), "minmax"),
}

# module attributes of repeatable.py that a constants set may override
SETTABLE = ["NOTICE_PAY", "EXPEDITION_PAY", "EVENT_TIER1_PAY", "EVENT_TIER_PAY", "EVENT_RUN_PAY", "NOTICES_PER_RESET",
            "EXPEDITIONS_PER_WEEK", "NOTICE_CAP", "EXPEDITION_CAP", "START_OWED", "RARITY", "EXPEDITION_RARITY_NEED",
            "TICKETS_PER_RUN", "TICKETS_PER_TIER3_HUNT", "TICKETS_RUN_MAX", "TICKET_HOLD", "TICKET_PREF", "STOP_VALUE_SCALE"]
_DEFAULTS = {k: getattr(R, k) for k in SETTABLE}


def configure(**kw) -> None:
    for k in SETTABLE:
        setattr(R, k, _DEFAULTS[k])
    for k, v in kw.items():
        if k not in SETTABLE:
            raise KeyError(k)
        setattr(R, k, v)


def _mean_days(runs, field, lo, hi):
    return statistics.fmean(sum(r.get(field, 0.0) for r in run[lo:hi]) / (hi - lo) for run in runs)


def _cum(runs, field, d):
    return statistics.fmean(sum(r.get(field, 0.0) for r in run[:d]) for run in runs)


def run_config(kw: dict, seeds: int = 24, days: int = 240, sweep_seeds: int = 10, lo: int = 30, players=None) -> dict:
    configure(**kw)
    world = R.World()
    out = {"constants": {k: getattr(R, k) for k in SETTABLE}, "players": {}}
    for key, (label, hpd, extra, policy) in PLAYERS.items():
        if players and key not in players:
            continue
        p = R.Params(name=label, hours=hpd, **extra)
        runs = R.run_many(world, p, seeds, days)
        rec = {"label": label, "hours_per_day": hpd, "policy": policy}
        rec["steady"] = {f: _mean_days(runs, f, lo, days) for f in COUNT_FIELDS}
        rec["cum"] = {str(d): {f: _cum(runs, f, d) for f in COUNT_FIELDS} for d in ANCHORS}
        sweep = []
        base = R.Params(name="sweep", hours=1.5, **extra)
        for h in HOURS_GRID:
            q = R.Params(**{**base.__dict__, "hours": h})
            sr = R.run_many(world, q, sweep_seeds, days)
            sweep.append({"hours": h, **{f: _mean_days(sr, f, lo, days) for f in COUNT_FIELDS}})
        rec["sweep"] = sweep
        out["players"][key] = rec
    return out


if __name__ == "__main__":
    res = run_config(dict(RARITY=False), seeds=6, days=120, sweep_seeds=3, players=["casual"])
    st = res["players"]["casual"]["steady"]
    print({k: round(v, 2) for k, v in st.items()})
