"""The calibrated constants sets. FINAL_T = with the refresh tickets (#398 merged by the tag), FINAL_0 = without.
    python -I docs/research/coin-calibration/finals.py <catches per hour> ...   # fills the repeatable cache (exact pays)
"""
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C

NEW_PRICES = dict(prices=(250, 400, 900, 3000, 10000), tier6_price=25000, tier6_goods=2)

FINAL_0 = C.K(name="Calibrated, no tickets", prestige=3000, event=(8, 5, 25), exact=True, **NEW_PRICES)
FINAL_T = replace(FINAL_0, name="Calibrated, with refresh tickets (1 per run + 1 per tier-3 Hunt)", tickets_run=1, tickets_t3=1)
OLD = C.K(name="Today (origin/main 72f82efc) with the #401 fix", rarity=True)
OLD_395 = C.K(name="Today as #395/#396 modelled it (dead Expeditions)", rarity=False)

if __name__ == "__main__":
    for catches in [int(a) for a in sys.argv[1:]] or [180]:
        for k in (FINAL_0, FINAL_T):
            C.rep_run(replace(k, catches=catches))
            print("done", k.name, catches, flush=True)
