#!/usr/bin/env bash
# The real-font layout harness (docs/agents/layout-harness.md): runs `/pagle dev tour` on the package as shipped,
# every font string measured in its real face from the bundled TTFs, and reports text that's cut, off its page or
# overlapping, beyond what scripts/measure-layout/allowlist.toml accepts.
#
#   scripts/measure-layout.sh deDE              # the whole tour in German
#   scripts/measure-layout.sh all               # enUS, deDE, esES and ruRU, at once
#   scripts/measure-layout.sh ruRU hunts        # one Module's stops (`/pagle dev tour hunts`): core, ledger, hunts, …
#   MEASURE_PNG=all scripts/measure-layout.sh esES     # a PNG of every stop, not only those with a finding
#   MEASURE_VERBOSE=1 scripts/measure-layout.sh deDE   # list the allowed findings too
#
# Exits 1 if any language has a finding the allowlist doesn't cover, or the addons raised an error on the tour.
# Writes into build/measure-layout/<language>[-<module>]/ (ignored): findings.jsonl, each stop's regions, and png/.
# Needs the pinned tools in .tools/ (scripts/setup.sh); offline. Not a gate stage: scripts/check.sh runs it only with
# GATE_LAYOUT=1.
set -euo pipefail

usage() {
	echo "usage: scripts/measure-layout.sh <enUS|deDE|esES|ruRU|all> [module]" >&2
	exit 2
}
(($# >= 1 && $# <= 2)) || usage
case $1 in
enUS | deDE | esES | ruRU) languages=("$1") ;;
all) languages=(enUS deDE esES ruRU) ;;
*) usage ;;
esac
module=${2:-}
[[ $module =~ ^[a-z_]*$ ]] || usage
png=${MEASURE_PNG:-findings}
verbose=()
[[ ${MEASURE_VERBOSE:-0} == 1 ]] && verbose=(--verbose)

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
# shellcheck source=lib/tools.sh
source "$root/scripts/lib/tools.sh"
bin="$(tools_dir "$root")/bin"
export PYTHONDONTWRITEBYTECODE=1
started=$SECONDS

# The widths come from the faces as they are now.
"$bin/python" scripts/measure-layout.py advances --check

# One language's run: the tour under busted into its folder, its log beside it.
run() {
	local out=$1
	MEASURE_LANG=$2 MEASURE_MODULE=$module MEASURE_OUT=$out "$bin/busted" \
		--helper=scripts/measure-layout/helper.lua scripts/measure-layout/tour.lua >"$out/busted.log" 2>&1
}

outs=() pids=()
for language in "${languages[@]}"; do
	out=build/measure-layout/$language${module:+-$module}
	rm -rf "$out"
	mkdir -p "$out"
	outs+=("$out")
	run "$out" "$language" &
	pids+=($!)
done

status=0
for i in "${!languages[@]}"; do
	language=${languages[i]} out=${outs[i]}
	if ! wait "${pids[i]}"; then
		echo "measure-layout: the $language tour didn't run; $out/busted.log:" >&2
		tail -n 40 "$out/busted.log" >&2
		status=1
		continue
	fi
	"$bin/python" scripts/measure-layout.py report "$out" "$language" --png "$png" ${verbose[@]+"${verbose[@]}"} ||
		status=1
done
echo "measure-layout: ${languages[*]}${module:+ ($module)} in $((SECONDS - started))s"
exit "$status"
