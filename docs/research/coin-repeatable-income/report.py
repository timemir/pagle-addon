"""Markdown tables for FINDINGS.md, rendered from model.py's results (kept apart so the model stays readable)."""

from __future__ import annotations

import json
import statistics
from collections import defaultdict
from pathlib import Path


def md_table(headers: list[str], rows: list[list]) -> str:
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(out) + "\n"


def hours_to(sweep: list[dict], policy: str, mode: str, frac: float) -> float | None:
    """The smallest swept hours/day whose income reaches `frac` of that policy's plateau (its best swept income)."""
    rows = [r for r in sweep if r["policy"] == policy and r["mode"] == mode]
    plateau = max(statistics.fmean(r["coins_per_day"] for r in rows if r["hours"] >= 6), 1e-9)
    for r in sorted(rows, key=lambda r: r["hours"]):
        if r["coins_per_day"] >= frac * plateau:
            return r["hours"]
    return None


def render(res: dict, tables: Path) -> None:
    res = json.loads(json.dumps(res, default=str))  # string keys everywhere, as results.json has them
    sc, ce = res["scenarios"], res["ceilings"]
    names = {"casual": "Casual, 1.5 h/day", "casual_minmax": "Min-maxed play at 1.5 h/day", "dedicated": "Dedicated, 4 h/day",
             "minmax": "Min-maxed, 4 h/day", "casual_skill150": "Casual, skill 150", "casual_skill75": "Casual, skill 75"}
    rows = []
    for key, rec in sc.items():
        s = rec["steady"]
        hrs = rec["params"]["hours"]
        rows.append([names.get(key, key), f"{s['coins']:.0f}", f"{s['coins_p10']:.0f}-{s['coins_p90']:.0f}",
                     f"{s['notice_coins']:.0f} / {s['expedition_coins']:.1f} / {s['event_coins']:.0f}",
                     f"{s['hours_used']:.2f}", f"{s['coins'] / max(s['hours_used'], 1e-9):.0f}",
                     f"{100 * s['coins'] / ce['total_per_day']:.0f}%", f"{s['coins'] * 7:.0f}"])
    (tables / "headline.md").write_text(md_table(
        ["Player", "Coins/day", "p10-p90", "Notices / Expeditions / Events", "Hours fished/day", "Coins per fishing hour",
         "% of ceiling", "Coins/week"], rows), encoding="utf-8")

    sw = res["sweep"]
    rows = []
    for pol in ("typical", "minmax"):
        for mode in ("both", "board", "events"):
            if pol == "minmax" and mode != "both":
                continue
            rows.append([pol, mode] + [
                (f"{hours_to(sw, pol, mode, f):g} h" if hours_to(sw, pol, mode, f) else "n/a") for f in (0.5, 0.9, 0.95, 0.99)])
    (tables / "saturation.md").write_text(md_table(
        ["Play", "Sources", "50% of plateau", "90%", "95%", "99%"], rows), encoding="utf-8")

    rows = []
    for pol in ("typical", "minmax"):
        for r in sorted((r for r in sw if r["policy"] == pol and r["mode"] == "both"), key=lambda r: r["hours"]):
            rows.append([pol, f"{r['hours']:g}", f"{r['coins_per_day']:.0f}", f"{r['notice']:.0f}", f"{r['expedition']:.1f}",
                         f"{r['event']:.0f}", f"{r['hours_used']:.2f}", f"{r['coins_per_day'] / max(r['hours_used'], 1e-9):.0f}"])
    (tables / "sweep.md").write_text(md_table(
        ["Play", "Hours/day budget", "Coins/day", "Notices", "Expeditions", "Events", "Hours used", "Coins per hour used"], rows),
        encoding="utf-8")

    rows = [["Tackle Board: Notices (3/day x mean pay {:.2f})".format(ce["notice_mean_pay"]), f"{3 * ce['notice_mean_pay']:.1f}", f"{21 * ce['notice_mean_pay']:.0f}"],
            ["Tackle Board: Expeditions (60, 1/week)", f"{60 / 7:.1f}", "60"],
            ["Tackle Board total", f"{ce['board_per_day']:.1f}", f"{ce['board_per_week']:.0f}"],
            ["Hunt Events, all three skill bands (mean max run {:.1f} per 72 h)".format(ce["event_max_all"]), f"{ce['event_per_day_all_bands']:.1f}", f"{ce['event_per_week_all_bands']:.0f}"],
            ["Hunt Events, low band only (1 slot in 3)", f"{ce['event_per_day_low_only']:.1f}", f"{ce['event_per_day_low_only'] * 7:.0f}"],
            ["Hunt Events, low + mid bands", f"{ce['event_per_day_low_mid']:.1f}", f"{ce['event_per_day_low_mid'] * 7:.0f}"],
            ["Repeatable ceiling (board + events, all bands)", f"{ce['total_per_day']:.1f}", f"{ce['total_per_week']:.0f}"],
            ["One-off on top: Campfire 25+75+200+500", "-", "800 (year one)"],
            ["One-off on top: Standing Hunts (12 Hunts, 4 sets)", "-", "1,000"]]
    (tables / "ceilings.md").write_text(md_table(["Source", "Coins/day", "Coins/week"], rows), encoding="utf-8")

    rows = []
    agg = defaultdict(lambda: [0, 0.0, 0.0, 0.0, 0.0])
    for r in res["solo"]:
        a = agg[(r["type"], r["kind"])]
        a[0] += r["n"]
        a[1] += r["n"] * r["pay"]
        a[2] += r["n"] * r["minutes_mean"]
        a[3] += r["n"] * r["minutes_median"]
        a[4] += r["n"] * r["capped"]
    for (typ, kind), (n, pay, mean_m, med_m, capped) in sorted(agg.items()):
        pay_m, mean_m, med_m, capped = pay / n, mean_m / n, med_m / n, capped / n
        rows.append([typ, kind, f"{pay_m:.1f}", f"{med_m:.0f}", f"{mean_m:.0f}", f"{60 * pay_m / max(mean_m, 1e-9):.0f}",
                     f"{100 * capped:.0f}%"])
    (tables / "goal_costs.md").write_text(md_table(
        ["Type", "Kind", "Mean pay", "Median min alone", "Mean min alone", "Coins per hour alone", "Never done in 10 h"], rows),
        encoding="utf-8")

    rows = []
    for label in ("random", "aligned"):
        for k in (1, 2, 3):
            e = res["event_by_tier"][label][str(k)] if str(k) in res["event_by_tier"][label] else res["event_by_tier"][label][k]
            rows.append([label, f"tier {k} of every Hunt", f"{e['pay']:.0f}", f"{e['hours']:.2f}", f"{e['coins_per_hour']:.0f}"])
    (tables / "event_by_tier.md").write_text(md_table(
        ["Clock", "Reached", "Mean coins in the run", "Hours in the zone (slowest Hunt)", "Coins per hour"], rows), encoding="utf-8")

    rows = []
    for key, m in res["mix90"].items():
        for tag, label in (("levels_and_events_only", "levels + events only"), ("plus_pots", "+ Standing Hunts 1,000 / discovery 2,485")):
            t = m[tag]
            rows.append([names.get(key, key), label, f"{t['tb']:.0f}%", f"{t['ledger']:.0f}%", f"{t['hunts']:.0f}%", f"{t['total']:,.0f}"])
    (tables / "mix90.md").write_text(md_table(
        ["Player (first 90 days)", "Counting", "Tackle Board", "Ledger", "Hunts", "Total coins"], rows), encoding="utf-8")

    rows = [[r["axis"], r["value"], r["hours"], f"{r['coins_per_day']:.1f}", f"{r['notice']:.1f}", f"{r['expedition']:.1f}",
             f"{r['event']:.1f}", f"{r['hours_used']:.2f}"] for r in res["sensitivity"]]
    (tables / "sensitivity.md").write_text(md_table(
        ["Axis", "Value", "Budget h/day", "Coins/day", "Notices", "Expeditions", "Events", "Hours used"], rows), encoding="utf-8")

    rows = []
    for pp, d in res["campfire"].items():
        rows.append([f"{float(pp):.3f}"] + [
            (f"{100 * d[m]['p_by_730d']:.0f}% (median day {d[m]['median_day']:.0f})" if d[m]["median_day"] else f"{100 * d[m]['p_by_730d']:.0f}%")
            for m in ("7", "30", "100", "365")])
    (tables / "campfire.md").write_text(md_table(
        ["P(play on a given day)", "Day 7 (25)", "Day 30 (75)", "Day 100 (200)", "Day 365 (500)"], rows), encoding="utf-8")

    # cumulative repeatable coins (Notices + Expeditions + Events + Campfire) after N fishing hours, counting every hour
    # the player fishes (the dedicated player fishes 4 h/day although these sources stop paying after ~3 h)
    def cum_at(rec: dict, day: float) -> float:
        pts = sorted((int(d), c) for d, c in rec["cum"].items())
        if day <= pts[0][0]:
            return pts[0][1] * day / pts[0][0]
        for (d0, c0), (d1, c1) in zip(pts, pts[1:]):
            if day <= d1:
                return c0 + (c1 - c0) * (day - d0) / (d1 - d0)
        d_last, c_last = pts[-1]
        extra = c_last + (day - d_last) * rec["steady"]["coins"]
        return extra + (500 if day >= 365 else 0) + (0 if day < 365 else 0)

    rows = []
    for key in ("casual", "casual_minmax", "dedicated", "minmax"):
        rec = sc[key]
        hpd = rec["params"]["hours"]
        row = [names[key]]
        for h in (5, 20, 100, 300, 500):
            row.append(f"{cum_at(rec, h / hpd):,.0f}")
        row.append(f"{86050 / (rec['steady']['coins'] + 0.0):,.0f} d / {86050 / rec['steady']['coins'] * hpd:,.0f} h")
        rows.append(row)
    (tables / "coins_by_hours.md").write_text(md_table(
        ["Player", "After 5 h", "20 h", "100 h", "300 h", "500 h", "Days / hours to earn 86,050 from these sources alone"], rows),
        encoding="utf-8")

    rows = []
    for key in ("casual", "dedicated"):
        l = res["ledger"][key]
        rows.append([names[key], f"{l['catch_xp_per_day']:.0f}", f"{l['activity_xp_board']:.0f}", f"{l['activity_xp_event']:.0f}",
                     f"{100 * (l['activity_xp_board'] + l['activity_xp_event']) / l['catch_xp_per_day']:.0f}%",
                     f"{l['level_coins_90d_with'] - l['level_coins_90d_without']:.0f}",
                     f"{(l['level_coins_365d_with'] - l['level_coins_365d_without']) / 365:.1f}"])
    (tables / "activity_xp.md").write_text(md_table(
        ["Player", "Catch XP/day (Fresh Water)", "Board Activity XP/day", "Event Activity XP/day", "Activity XP vs Catch XP",
         "Extra level-up coins in 90 days", "Extra level-up coins per day (year)"], rows), encoding="utf-8")


if __name__ == "__main__":
    here = Path(__file__).resolve().parent
    render(json.loads((here / "results.json").read_text(encoding="utf-8")), here / "tables")
    print("rendered tables/*.md from results.json")
