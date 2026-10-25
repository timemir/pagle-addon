#!/usr/bin/env python3
"""Writes the #402 tables (tables/*.md, tables/curves.csv) for the calibrated constants sets.
    python -I docs/research/coin-calibration/report.py            # needs finals.py 180 120 240 and the Lua sets in inputs/
"""
from __future__ import annotations

import csv
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C
import finals as F
import rep_driver

TAB = C.HERE / "tables"
TAB.mkdir(exist_ok=True)
PLAYERS = ["casual", "dedicated", "minmax15", "minmax4"]
OWN_HOURS = [10, 20, 40, 100, 200, 430, 720, 870, 1015]


def write(name, text):
    (TAB / name).write_text(text, encoding="utf-8", newline="\n")


def owned_share(k: C.K, coins: float) -> float:
    n, goods, results = C.milestone_coins(k)  # noqa: F841 (n)
    goods, seqs = C.sequences(k)
    tot = 0.0
    for p, seq in seqs:
        spent, cnt = 0, 0
        for st in seq:
            if spent + st.cost > coins + 1e-9:
                break
            spent += st.cost
            cnt += 1 if st.good else 0
        tot += p * cnt
    return tot / len(goods)


def milestone_block(ev, title):
    return f"### {title}\n\n" + C.milestone_table(ev) + "\n"


def three_way(c, a, b):
    pa, pb = c.parts(a), c.parts(b)
    d = {s: pb[s] - pa[s] for s, _ in C.SRC}
    tot = sum(d.values())
    board = d["notices"] + d["expeditions"] + d["campfire"]
    ledger = d["levels_first"] + d["levels_repeat"] + d["prestige"] + d["discovery"]
    hunts = d["standing"] + d["events"]
    return 100 * board / tot, 100 * ledger / tot, 100 * hunts / tot


def curves_csv(ev, name):
    hrs = [0.25, 0.5, 1, 2, 3, 5, 7.5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500, 750, 1000, 1500, 2000]
    with open(TAB / name, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["player", "hours", "day", "total"] + [s for s, _ in C.SRC])
        for pk, c in ev["curves"].items():
            for h in hrs:
                p = c.parts(h)
                w.writerow([pk, h, round(h / c.hpd, 2), round(sum(p.values()))] + [round(p[s]) for s, _ in C.SRC])


def full_report(k: C.K, tag: str, title: str):
    ev = C.evaluate(k)
    md = [f"## {title}\n"]
    md.append(milestone_block(ev, "Milestones, hours fished (calendar day), cheapest-first buying"))
    # cumulative coins
    marks = [1, 5, 20, 40, 100, 200, 430, 720, 1000]
    rows = [[c.label] + [f"{c.total(h):,.0f}" for h in marks] for c in ev["curves"].values()]
    md.append("### Cumulative coins by hours fished\n\n" + C.md_table(["Player"] + [f"{h} h" for h in marks], rows))
    dm = [1, 7, 30, 90, 180, 365, 540, 730]
    rows = [[c.label] + [f"{c.total(d * c.hpd):,.0f}" for d in dm] for c in ev["curves"].values()]
    md.append("### Cumulative coins by calendar day\n\n" + C.md_table(["Player"] + [f"day {d}" for d in dm], rows))
    md.append("### Average coins per fishing hour, by phase\n\n" + C.phase_table(ev))
    rows = []
    for pk, c in ev["curves"].items():
        row = [c.label]
        for a, b in C.PHASES:
            row.append(f"{(c.total(b) - c.total(a)) / ((b - a) / c.hpd):,.0f}")
        rows.append(row)
    md.append("### Coins per calendar day, by phase\n\n" + C.md_table(["Player"] + [f"{a}-{b} h" for a, b in C.PHASES], rows))
    for pk in ("casual", "dedicated", "minmax4"):
        c = ev["curves"][pk]
        md.append(f"### Income mix by source, {c.label} (share of the phase's coins)\n\n" + C.mix_table(ev, pk))
    rows = []
    for pk in ("casual", "dedicated", "minmax4"):
        c = ev["curves"][pk]
        row = [c.label]
        for a, b in [(0, 20), (20, 100), (100, 500), (500, 1000)]:
            bd, ld, hn = three_way(c, a, b)
            row.append(f"{bd:.0f} / {ld:.0f} / {hn:.0f}")
        rows.append(row)
    md.append("### Board / Ledger / Hunts split (the wallet's three bars)\n\nBoard = Notices + Expeditions + Campfire; Ledger = level-ups, Prestige, discovery; Hunts = Standing Hunts + Event runs.\n\n"
              + C.md_table(["Player", "0-20 h", "20-100 h", "100-500 h", "500-1000 h"], rows))
    c = ev["curves"]["casual"]
    rows = [[f"{h} h", f"{c.total(h):,.0f}", f"{100 * owned_share(k, c.total(h)):.0f}%"] for h in OWN_HOURS]
    md.append("### Casual: items owned (cheapest-first) after N hours\n\n" + C.md_table(["Hours", "Coins earned", "Items owned"], rows))
    rep = ev["curves"]
    rows = []
    for pk, cu in rep.items():
        r = cu.rep
        rows.append([cu.label, f"{r.steady['notices']:.0f}", f"{r.steady['expeditions']:.0f}", f"{r.steady['events']:.0f}", f"{r.per_day:.0f}",
                     f"{r.tickets['tickets_earned']:.2f}", f"{r.xp_per_day:.0f}"])
    md.append("### Repeatable sources per day in steady state (Notices, Expeditions, Event runs, total; tickets earned/day; Activity XP/day)\n\n"
              + C.md_table(["Player", "Notices", "Expeditions", "Events", "Total", "Tickets/day", "Activity XP/day"], rows))
    write(f"{tag}.md", "\n".join(md))
    curves_csv(ev, f"curves_{tag}.csv")
    return ev


def fallback_tail(ev, k):
    """Hours after the whole shop is bought until the 26 earned goods are bought at their fallback price."""
    rows = []
    n_fallback = 26
    base_cost = max(c for c, _ in [(v[0], v[1]) for v in ev["miles"]["casual"].values()])
    for tier_label, price in (("tier 3 (900)", k.prices[2]), ("tier 4 (3,000)", k.prices[3]), ("tier 5 (10,000), today's FALLBACK_TIER = 5", k.prices[4])):
        row = [tier_label, f"{n_fallback * price:,}"]
        for pk in ("casual", "dedicated"):
            c = ev["curves"][pk]
            ys = ev["grids"][pk]
            h = C.hours_to(ys, base_cost + n_fallback * price)
            row.append(f"{C.fmt_h(h)} h (d{C.fmt_h(h / c.hpd) if h else '-'})")
        rows.append(row)
    return "### Earned-goods fallback tail: all 26 bought at the fallback price, on top of the whole shop\n\n" + C.md_table(["Fallback tier", "Coins (26 goods)", "Casual: everything incl. fallback", "Dedicated"], rows)


def sensitivity(k0: C.K, tag: str):
    md = []
    for catches in (180, 120, 240):
        k = replace(k0, catches=catches)
        ev = C.evaluate(k)
        md.append(f"### {catches} Catches per fishing hour\n\n" + C.milestone_table(ev) + "\n" + C.phase_table(ev) + "\n")
    return "\n".join(md)


def carve_and_lumps(k):
    md = ["### The tier-6 goods carved out of tier 5 instead of added to the 101 (casual, hours)\n"]
    rows = []
    for label, kk in (("Added: 101 + 2 tier-6 goods", k), ("Carved: the 2 direct tier-5 goods move to tier 6", replace(k, tier6_carve=True))):
        ev = C.evaluate(kk, players=["casual", "dedicated"])
        rows.append([label] + [C.fmt_h(ev["miles"]["casual"][m][1]) for m in ("items75", "tier4", "tier5", "t6_1", "t6_2")] + ["d" + C.fmt_h(ev["miles"]["dedicated"]["t6_2"][1] / 4)])
    md.append(C.md_table(["Catalogue", "75% items", "Tiers 1-4", "Tiers 1-5", "1st tier-6", "2nd tier-6", "Dedicated 2nd tier-6 (day)"], rows))
    lb, la = C.lua_sets(180)
    rows = []
    for key in PLAYERS:
        prof = C.LUA_PROFILE[key]
        d = la[prof]
        h1, h2 = 300, 1000
        n = C.interp(d["hs"], d["prestiges"], h2) - C.interp(d["hs"], d["prestiges"], h1)
        hpd = rep_driver.PLAYERS[key][1]
        rows.append([rep_driver.PLAYERS[key][0], f"{(h2 - h1) / n:.0f} h", f"{(h2 - h1) / n / hpd:.0f} days", f"{k.prestige:,}"])
    md.append("### How lumpy: fishing hours between two Prestiges (300-1000 h), at the base Activity XP\n\n" + C.md_table(["Player", "Hours per climb", "Calendar days per climb", "Coins per Prestige"], rows))
    return "\n".join(md)


if __name__ == "__main__":
    ev_t = full_report(F.FINAL_T, "final_with_tickets", "Calibrated constants, with the refresh tickets (1 per run + 1 per tier-3 Hunt, hold 5)")
    ev_0 = full_report(F.FINAL_0, "final_no_tickets", "Calibrated constants, no refresh tickets (if #398 misses the tag)")
    ev_o = full_report(F.OLD, "today", "Today's constants and prices (with the #401 fix) for comparison")
    extra = [fallback_tail(ev_t, F.FINAL_T)]
    write("fallback.md", "\n".join(extra))
    write("carve_and_lumps.md", carve_and_lumps(F.FINAL_T))
    write("sensitivity_with_tickets.md", "## Sensitivity: Catches per fishing hour (with tickets)\n\n" + sensitivity(F.FINAL_T, "t"))
    write("sensitivity_no_tickets.md", "## Sensitivity: Catches per fishing hour (no tickets)\n\n" + sensitivity(F.FINAL_0, "0"))
    print("written", [p.name for p in sorted(TAB.iterdir())])
