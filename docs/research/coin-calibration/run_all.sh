#!/usr/bin/env bash
# Re-runs everything for #402 from the repo root (about 30 minutes on 24 cores; every step is cached or idempotent).
# The branch research/coin-calibration carries the results (inputs/, results/rep/, tables/), so you only need this to change something.
#
# 0. Needs luajit and python 3.12+ on PATH; the vendored research models are copies of
#    research/coin-onetime-income (model.lua -> onetime_counts.lua) and research/coin-repeatable-income (model.py -> repeatable.py).
set -e
D=docs/research/coin-calibration
AXP="casual=877.04,dedicated=1044.97,minmax_1.5h=943.98,minmax_4h=1055.94"   # Activity XP per day #396 fed to the Ledger
# 1. the one-time / Ledger model (counts), base = no Activity XP, act = with #396's Activity XP; 30 seeds at 180/h, 10 at 120 and 240
bash $D/run_lua.sh $D/inputs/lua_base_30 180 none 30
bash $D/run_lua.sh $D/inputs/lua_act_30 180 "$AXP" 30
for c in 120 240; do
  bash $D/run_lua.sh $D/inputs/lua_base_$c $c none 10
  bash $D/run_lua.sh $D/inputs/lua_act_$c $c "$AXP" 10
done
# 2. the repeatable model with the calibrated pays, with and without tickets, at 180 / 120 / 240 Catches an hour
python -I $D/finals.py 180 120 240
# 3. the lever runs (supply, tickets) and the tables
python -I $D/run_levers.py tickets_1_1 tickets_1_0 tickets_2_1 tickets_0_1 tickets_notice_only notices4 notices5 exp2 notices4_exp2 notices4_exp2_tickets
python -I $D/lever_study.py
python -I $D/scan5.py
python -I $D/report.py
# validation of the engine against #396 (old constants -> 28 / 315 / 845 h): python -I $D/validate.py
