"""Scan 5: LEVEL_UP_COINS x PRESTIGE_COINS pairs that all pay about the same per climb, with events x0.5 and the tickets."""
import sys
from dataclasses import replace
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C
from explore import NEWP, KEYS, score

base = C.K(name="scan", event=(8, 5, 25), tickets_run=1, tickets_t3=1, **NEWP)
rows = []
print("LU PC | repeat climb pays | casual h: " + " ".join(KEYS[1:]) + " | score | coins at 20h 40h | prestige share 100-500 | ded t5 day")
for lu, pc in ((20, 3000), (25, 2500), (30, 2000), (40, 1500), (50, 1000), (60, 500), (70, 100), (80, 100)):
    k = replace(base, level_up=lu, prestige=pc)
    e = C.evaluate(k, players=["casual", "dedicated"])
    m = e["miles"]["casual"]; d = e["miles"]["dedicated"]; c = e["curves"]["casual"]
    pa, pb = c.parts(100), c.parts(500)
    tot = sum(pb.values()) - sum(pa.values())
    psh = (pb["prestige"] - pa["prestige"]) / tot
    rows.append([f"{lu} / {pc:,}", f"{59 * lu + pc:,}"] + [C.fmt_h(m[x][1]) for x in KEYS[1:]] + [f"{c.total(20):,.0f} / {c.total(40):,.0f}", f"{100*psh:.0f}%", "d" + C.fmt_h(d["tier5"][1] / 4)])
    print(lu, pc, "|", 59 * lu + pc, "|", " ".join(C.fmt_h(m[x][1]) for x in KEYS[1:]), "|", f"{score(e):.2f}", "|", f"{c.total(20):,.0f} {c.total(40):,.0f}", "|", f"{100*psh:.0f}%", "|", C.fmt_h(d["tier5"][1] / 4))

text = C.md_table(["LEVEL_UP / PRESTIGE_COINS", "A repeat climb pays"] + ["25% items", "50%", "75%", "Tiers 1-4", "Tiers 1-5", "1st tier-6", "2nd tier-6"] + ["Coins at 20 h / 40 h", "Prestige share of coins 100-500 h", "Dedicated tiers 1-5"], rows)
(C.HERE / "tables").mkdir(exist_ok=True)
(C.HERE / "tables" / "alt_pairs.md").write_text("Casual hours fished, with the new prices, Hunt Event pay x0.5 and the refresh tickets (1 + 1):\n\n" + text, encoding="utf-8")
