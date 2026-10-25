"""Validation: the old constants through calibrate.py must give back #396's numbers (casual: 25% of items 28 h, 75% 315 h,
100% 845 h; 125 coins/h over the first 100 h; 93 over 100-500 h). Run: python -I docs/research/coin-calibration/validate.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C

if __name__ == "__main__":
    C.SEEDS180 = "_10"  # #396's 10-seed Lua files, to compare like with like
    k = C.K(name="old", rarity=False)  # #395 as published: item-quality goals, Expeditions mostly dead
    ev = C.evaluate(k)
    print(C.milestone_table(ev))
    print(C.phase_table(ev))
    print(C.mix_table(ev, "casual"))
    c = ev["curves"]["casual"]
    for h in (1, 5, 20, 50, 100, 200, 300, 500, 1000):
        print(h, round(c.total(h)))
