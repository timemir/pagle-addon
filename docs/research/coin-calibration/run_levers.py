"""Fill the cache with the repeatable runs the lever study needs (supply, tickets). Usage: run_levers.py <name> [<name>...]"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import calibrate as C

LEVERS = {
    "tickets_1_1": dict(tickets_run=1, tickets_t3=1),
    "tickets_1_0": dict(tickets_run=1, tickets_t3=0),
    "tickets_2_1": dict(tickets_run=2, tickets_t3=1),
    "notices4": dict(notices_per_day=4),
    "notices5": dict(notices_per_day=5),
    "exp2": dict(expeditions_per_week=2),
    "tickets_notice_only": dict(tickets_run=1, tickets_t3=1, ticket_pref="notice"),
    "tickets_0_1": dict(tickets_run=0, tickets_t3=1),
    "notices4_exp2": dict(notices_per_day=4, expeditions_per_week=2),
    "notices4_exp2_tickets": dict(notices_per_day=4, expeditions_per_week=2, tickets_run=1, tickets_t3=1),
}
if __name__ == "__main__":
    for name in sys.argv[1:]:
        C.rep_run(C.K(name=name, **LEVERS[name]))
        print("done", name, flush=True)
