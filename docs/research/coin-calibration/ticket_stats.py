import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C
from dataclasses import replace
for name, kw in (("1 per run", dict(tickets_run=1)), ("1 per run + 1 per tier-3 Hunt", dict(tickets_run=1, tickets_t3=1)), ("2 per run + 1 per tier-3 Hunt", dict(tickets_run=2, tickets_t3=1)), ("(all with 4/day + 2/wk)", dict(notices_per_day=4, expeditions_per_week=2, tickets_run=1, tickets_t3=1))):
    r = C.rep_run(C.K(**kw))
    for p, rec in r["players"].items():
        s = rec["steady"]
        print(f"{name:34s} {p:10s} earned {s['tickets_earned']:.2f}/day used {s['tickets_used']:.2f} lost {s['tickets_lost']:.2f}  runs/day {s['runs_done']:.2f} tickets per run {s['tickets_earned']/max(s['runs_done'],1e-9):.2f}")
