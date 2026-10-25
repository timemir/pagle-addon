"""Does re-pricing counts (planner unchanged) agree with a re-run at the real pays? FINAL_T exact vs re-priced."""
import sys
from dataclasses import replace
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C, finals as F
from explore import KEYS
for k in (F.FINAL_T, replace(F.FINAL_T, exact=False, name="re-priced")):
    ev = C.evaluate(k)
    print(k.name, "exact" if k.exact else "")
    for p in ("casual", "dedicated"):
        print(" ", p, " ".join(C.fmt_h(ev["miles"][p][x][1]) for x in KEYS[1:]), f"| rep coins/day {ev['curves'][p].rep.per_day:.1f} xp {ev['curves'][p].rep.xp_per_day:.0f}")
