"""Scan 6: PRESTIGE_COINS with Hunt Event pay x0.5, without / with tickets, dense Lua marks (final inputs)."""
import sys
from dataclasses import replace
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C
from explore import NEWP, KEYS, score
base = C.K(name="scan", event=(8, 5, 25), **NEWP)
print("tickets PC | casual h: " + " ".join(KEYS[1:]) + " | score")
for tk in ((0, 0), (1, 1)):
    for pc in (2500, 3000, 3250, 3500, 4000):
        k = replace(base, prestige=pc, tickets_run=tk[0], tickets_t3=tk[1])
        e = C.evaluate(k, players=["casual"])
        m = e["miles"]["casual"]
        print(tk, pc, "|", " ".join(C.fmt_h(m[x][1]) for x in KEYS[1:]), "|", f"{score(e):.2f}")
