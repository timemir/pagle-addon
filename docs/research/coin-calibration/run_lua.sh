#!/usr/bin/env bash
# Runs onetime_counts.lua for the four profiles in parallel and merges by_hour.csv.
#   docs/research/coin-calibration/run_lua.sh <outdir> <catches per hour> <axp "casual=877,dedicated=1045,minmax_1.5h=944,minmax_4h=1056" | none> [seeds]
# From the repo root. About 3 minutes (the min-max profile is the slow one).
set -e
out=$1; catches=${2:-180}; axp=${3:-none}; seeds=${4:-10}
mkdir -p "$out"
pids=()
for p in casual dedicated minmax_1.5h minmax_4h; do
  args=(--seeds "$seeds" --hours 3000 --catches "$catches" --only "$p" --out "$out/p_$p")
  [ "$axp" != "none" ] && args+=(--axp "$axp")
  luajit docs/research/coin-calibration/onetime_counts.lua "${args[@]}" > "$out/log_$p.txt" 2>&1 &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done
head -n 1 "$out/p_casual/by_hour.csv" > "$out/by_hour.csv"
for p in casual dedicated minmax_1.5h minmax_4h; do tail -n +2 "$out/p_$p/by_hour.csv" >> "$out/by_hour.csv"; done
rm -rf "$out"/p_*
echo merged "$out/by_hour.csv"
