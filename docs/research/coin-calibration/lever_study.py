"""Lever study: one change at a time from candidate A (the baseline row), what it does to the casual's hours and to the
dedicated / min-max days. Output: tables/levers.md. Run after run_levers.py has filled the cache."""
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C
from explore import NEWP

A = C.K(name="A", prestige=3000, event=(8, 5, 25), **NEWP)  # the calibrated set without tickets, re-priced counts


def scale(t, f):
    return tuple(round(x * f) for x in t)


VARIANTS = [
    ("Calibrated, no tickets (baseline)", {}),
    ("PRESTIGE_COINS 2,500 (-500)", dict(prestige=2500)),
    ("PRESTIGE_COINS 3,500 (+500)", dict(prestige=3500)),
    ("PRESTIGE_COINS back to 100", dict(prestige=100)),
    ("PRESTIGE_COINS 100 and LEVEL_UP_COINS 70", dict(prestige=100, level_up=70)),
    ("PRESTIGE_COINS 1,500 and LEVEL_UP_COINS 40", dict(prestige=1500, level_up=40)),
    ("LEVEL_UP_COINS 40 (x2)", dict(level_up=40)),
    ("Hunt Event pay back to today's 15/10/50", dict(event=(15, 10, 50))),
    ("Hunt Event pay 5/3/15 (x0.3)", dict(event=(5, 3, 15))),
    ("Notice + Expedition pay x1.5 (15/23/30, 90)", dict(notice=(15, 23, 30), expedition=90)),
    ("Notice + Expedition pay x2 (20/30/40, 120)", dict(notice=(20, 30, 40), expedition=120)),
    ("First-catch bonuses x2 (Species 20, curio 10, trophy 10, rank 4, Legend 200)", dict(species=20, curio=10, trophy=10, zone_rank=4, legend=200)),
    ("Standing Hunts x2 (60/30/200)", dict(standing=(60, 30, 200))),
    ("Campfire x3 (75/225/600/1,500)", dict(campfire=((7, 75), (30, 225), (100, 600), (365, 1500)))),
    ("Curio crate 5,000 (new constant)", dict(crate=5000)),
    ("Curio crate 6,000 (new constant)", dict(crate=6000)),
    ("Board supply 4 Notices/day", dict(notices_per_day=4)),
    ("Board supply 5 Notices/day", dict(notices_per_day=5)),
    ("Board supply 2 Expeditions/week", dict(expeditions_per_week=2)),
    ("Board supply 4 Notices/day + 2 Expeditions/week", dict(notices_per_day=4, expeditions_per_week=2)),
    ("Refresh tickets: 1 per run", dict(tickets_run=1)),
    ("Refresh tickets: 1 per run + 1 per tier-3 Hunt (the guess)", dict(tickets_run=1, tickets_t3=1)),
    ("Refresh tickets: 2 per run + 1 per tier-3 Hunt", dict(tickets_run=2, tickets_t3=1)),
    ("Refresh tickets: only 1 per tier-3 Hunt (none for the run)", dict(tickets_run=0, tickets_t3=1)),
    ("Refresh tickets (the guess) but a ticket posts Notices only", dict(tickets_run=1, tickets_t3=1, ticket_pref="notice")),
    ("Supply 4/day + 2/week + tickets (guess)", dict(notices_per_day=4, expeditions_per_week=2, tickets_run=1, tickets_t3=1)),
]


def row(label, ev, ref):
    out = [label]
    for p, key in (("casual", "items25"), ("casual", "items75"), ("casual", "tier4"), ("casual", "tier5"), ("casual", "t6_2")):
        h = ev["miles"][p][key][1]
        out.append(f"{C.fmt_h(h)} ({100 * (h / ref['miles'][p][key][1] - 1):+.0f}%)")
    for p in ("dedicated", "minmax4"):
        h = ev["miles"][p]["tier5"][1]
        d = h / ev["curves"][p].hpd
        dc = ref["miles"]["casual"]["tier5"][1] / ref["curves"]["casual"].hpd
        out.append(f"d{C.fmt_h(d)} ({d / dc:.2f}x casual)")
    cu, de = ev["curves"]["casual"], ev["curves"]["dedicated"]
    out.append(f"{(cu.total(500) - cu.total(100)) / 400:.0f} / {(de.total(500) - de.total(100)) / 400:.0f}")
    out.append(f"{ev['curves']['casual'].rep.per_day:.0f} / {ev['curves']['dedicated'].rep.per_day:.0f}")
    return out


if __name__ == "__main__":
    ref = C.evaluate(A, players=["casual", "dedicated", "minmax4"])
    rows = [row("Calibrated, no tickets (baseline)", ref, ref)]
    for label, kw in VARIANTS[1:]:
        k = replace(A, name=label, **kw)
        ev = C.evaluate(k, players=["casual", "dedicated", "minmax4"])
        rows.append(row(label, ev, ref))
    hdr = ["Change from the calibrated set (no tickets)", "Casual 25% items (h)", "75% items (h)", "Tiers 1-4 (h)", "Tiers 1-5 (h)", "2nd tier-6 (h)",
           "Dedicated tiers 1-5 (day)", "Min-max 4 h tiers 1-5 (day)", "Coins/fishing h 100-500: casual / dedicated", "Board+Event coins/day: casual / dedicated"]
    text = C.md_table(hdr, rows)
    (C.HERE / "tables").mkdir(exist_ok=True)
    (C.HERE / "tables" / "levers.md").write_text(text, encoding="utf-8")
    print(text)
