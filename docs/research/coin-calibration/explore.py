"""Exploration helper: evaluate constants sets and print the casual / dedicated / min-max milestones against the pacing table.
    python -I docs/research/coin-calibration/explore.py
Edit CANDIDATES (or import `show`). Repeatable runs are cached in results/rep (re-priced unless exact=True)."""
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C

NEWP = dict(prices=(250, 400, 900, 3000, 10000), tier6_price=25000, tier6_goods=2)
KEYS = ["first", "items25", "items50", "items75", "tier4", "tier5", "t6_1", "t6_2"]


def score(ev, player="casual"):
    import math

    err = []
    for k in KEYS[1:]:
        h = ev["miles"][player].get(k, (0, None))[1]
        err.append(abs(math.log(h / C.TARGET_H[k])) if h else 9.0)
    return sum(e * e for e in err) ** 0.5


def show(k, players=("casual", "dedicated", "minmax15", "minmax4"), full=False):
    ev = C.evaluate(k, players=list(players))
    print(f"== {k.name}  score(casual)={score(ev):.3f}")
    rows = []
    for key in KEYS + ["items100"]:
        row = [key, C.TARGETS.get(key, "-")]
        for p in players:
            h = ev["miles"][p].get(key, (0, None))[1]
            row.append(C.fmt_h(h) + (f" (d{C.fmt_h(h / ev['curves'][p].hpd)})" if h else ""))
        rows.append(row)
    print(C.md_table(["milestone", "target"] + list(players), rows))
    if full:
        print(C.phase_table(ev))
        print(C.mix_table(ev, "casual"))
    return ev


if __name__ == "__main__":
    base = C.K(name="rarity fix only")
    show(base)
    show(replace(base, name="new prices only", **NEWP), full=True)
