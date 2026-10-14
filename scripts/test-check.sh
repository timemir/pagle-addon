#!/usr/bin/env bash
# Tests the check gate itself: plants a known mistake in a scratch copy of the tree and asserts that
# scripts/check.sh fails at the stage that should catch it (and that the untouched tree passes).
#
#   scripts/test-check.sh
#   TEST_CHECK_JOBS=1 scripts/test-check.sh    # one case at a time
#
# Needs the tools from scripts/setup.sh. Never touches the working tree, .tools/cache/ included.
#
# A case is `copy`, its planted mistake under "$scratch/tree", then `expect`. Each case gets its own copy in
# native tmp and runs the whole gate in the background, TEST_CHECK_JOBS at a time (default: the CPU count, at
# most 8). Verdicts print in the order the cases are written.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
# On an early exit, the running cases finish before their copies go.
trap 'wait; rm -rf "$scratch"' EXIT
failures=0
cases=0
reported=0

max_jobs=${TEST_CHECK_JOBS:-$(nproc)}
[[ -n ${TEST_CHECK_JOBS:-} ]] || ((max_jobs <= 8)) || max_jobs=8
((max_jobs >= 1)) || max_jobs=1
echo "test-check: $max_jobs cases at a time"

# The tree is copied once, from a working tree that may sit across WSL's slow /mnt bridge, into native tmp;
# every case copies this base. Its .tools/ links each installed tool, but cache/ is the case's own: check.sh
# writes luacov's stats and report and mypy's cache there, and cases run at once. mypy's cache starts as a copy
# of the working tree's, so no case checks cold.
base="$scratch/base"
mkdir "$base" "$scratch/cases" "$scratch/results"
tar -C "$root" --exclude=./.git --exclude=./.tools --exclude=./.release -cf - . | tar -C "$base" -xf -
mkdir -p "$base/.tools/cache"
for tool in "$root/.tools"/*; do
	[[ ${tool##*/} == cache ]] || ln -s "$tool" "$base/.tools/"
done
if [[ -d $root/.tools/cache/mypy ]]; then
	cp -a "$root/.tools/cache/mypy" "$base/.tools/cache/"
fi

# Fresh copy of the tree for the next case. "$scratch/tree" points at it until the next copy.
copy() {
	cases=$((cases + 1))
	case_tree="$scratch/cases/$cases"
	cp -a "$base" "$case_tree"
	ln -sfn "$case_tree" "$scratch/tree"
}

# expect <case> <stage|pass> [text]: runs the gate on the copy and checks where it stopped, and that its
# output names the reason when text is given. The case starts in the background once a job slot is free.
expect() {
	while (($(jobs -pr | wc -l) >= max_jobs)); do
		wait -n || true
		report
	done
	run_case "$case_tree" "$scratch/results/$cases" "$@" &
}

# run_case <tree> <verdict file> <case> <stage|pass> [text]: the gate on one copy, as expect describes.
run_case() {
	local tree=$1 verdict=$2 output status=0 ok=no
	shift 2
	output=$(bash "$tree/scripts/check.sh" 2>&1) || status=$?
	if [[ $2 == pass && $status -eq 0 ]] || [[ $2 != pass && $status -ne 0 && $output == *"FAILED at $2"* ]]; then
		[[ $output == *"${3:-}"* ]] && ok=yes
	fi
	if [[ $ok == yes ]]; then
		echo "ok   $1" >"$verdict.part"
	else
		{
			echo "FAIL $1: expected $2${3:+ naming \"$3\"}, got exit $status"
			sed 's/^/     | /' <<<"$output"
		} >"$verdict.part"
	fi
	mv "$verdict.part" "$verdict"
	rm -rf "$tree"
}

# Prints the finished cases' verdicts in case order, up to the first case still running.
report() {
	local verdict
	while verdict="$scratch/results/$((reported + 1))" && [[ -f $verdict ]]; do
		cat "$verdict"
		[[ $(head -c 4 "$verdict") != FAIL ]] || failures=$((failures + 1))
		reported=$((reported + 1))
	done
}

# Adds a name to the WoW API inventory (stds.wow in .luacheckrc).
inventory_add() {
	printf 'table.insert(stds.wow.read_globals, "%s")\n' "$1" >>"$scratch/tree/.luacheckrc"
}

addon="$scratch/tree/addons/Pagle"
toc="$addon/Pagle.toc"

# Writes a Lua file that calls the WoW global CreateFrame.
uses_create_frame() {
	printf 'local frame = CreateFrame("Frame")\nreturn frame\n' >"$1"
}

# Writes a Lua file that calls the WoW global Screenshot, which Pagle never inventories.
uses_screenshot() {
	printf 'Screenshot()\n' >"$1"
}

# Drops a file from Pagle.toc, or from the TOC given second.
toc_drop() {
	local from=${2:-$toc}
	grep -vxF "$1" "$from" >"$from.new"
	mv "$from.new" "$from"
}

# Moves a file in Pagle.toc to just after another (TOC paths keep their backslashes, so no awk -v).
toc_move_after() {
	FILE=$1 AFTER=$2 awk '$0 != ENVIRON["FILE"] { print } $0 == ENVIRON["AFTER"] { print ENVIRON["FILE"] }' \
		"$toc" >"$toc.new"
	mv "$toc.new" "$toc"
}

copy
expect "the tree as it is passes" pass

copy
echo "STYLUA_VERSION=0.0.0" >>"$scratch/tree/scripts/tools.env"
expect "a pin changed since the last setup stops the gate" setup "run scripts/setup.sh"

copy
sed -i 's#BigWigsMods/packager@[0-9a-f]*#BigWigsMods/packager@0123456789abcdef0123456789abcdef01234567#' \
	"$scratch/tree/.github/workflows/release.yml"
expect "a packager pin in release.yml that differs from tools.env stops the gate" setup \
	"PACKAGER_COMMIT in scripts/tools.env"

copy
printf -- '-- edited by hand\n' >>"$addon/libs/AceDB-3.0/AceDB-3.0.lua"
expect "a hand-edited vendored lib fails libs" libs "addons/Pagle/libs/AceDB-3.0/AceDB-3.0.lua: FAILED"

copy
printf 'return 1\n' >"$addon/libs/Stray.lua"
expect "a file in libs/ that update-ace3.sh didn't vendor fails libs" libs "addons/Pagle/libs/Stray.lua"

copy
printf 'local t = {a=1}\nreturn t\n' >"$addon/logic/Badly.lua"
expect "a badly formatted file fails format" format "Diff in addons/Pagle/logic/Badly.lua"

copy
uses_create_frame "$addon/logic/Global.lua"
inventory_add CreateFrame
expect "a WoW global in logic/ fails lint, even when inventoried" lint "accessing undefined variable 'CreateFrame'"

copy
uses_create_frame "$addon/locale/Global.lua"
inventory_add CreateFrame
expect "a WoW global in locale/ fails lint, even when inventoried" lint "accessing undefined variable 'CreateFrame'"

copy
printf 'local item = Pagle.GetItem(6358)\nreturn item\n' >>"$scratch/tree/addons/Pagle_QoL/logic/Data.lua"
expect "a Module's logic/ calling Pagle beyond its CORE-R11 guard fails lint" lint \
	"accessing undefined variable 'Pagle'"

copy
printf 'local version = Pagle.API_VERSION\nreturn version\n' >>"$scratch/tree/addons/Pagle_QoL/locale/enUS.lua"
expect "a Module's locale/ reading Pagle beyond its CORE-R11 guard fails lint" lint \
	"accessing undefined variable 'Pagle'"

copy
uses_screenshot "$addon/adapter/Global.lua"
expect "a WoW global in adapter/ fails lint until inventoried" lint "accessing undefined variable 'Screenshot'"

copy
uses_screenshot "$addon/adapter/Global.lua"
inventory_add Screenshot
expect "a WoW global in adapter/ passes once inventoried" pass

copy
mkdir "$addon/ui"
uses_create_frame "$addon/ui/Global.lua"
inventory_add CreateFrame
expect "a WoW global anywhere but adapter/ fails lint, even when inventoried" lint \
	"accessing undefined variable 'CreateFrame'"

copy
# The api stage counts what the tree inventories already, plus the 8 names added here.
inventoried=$("$root/.tools/bin/lua" "$root/scripts/api-presence.lua" "$scratch/tree/.luacheckrc" \
	"$root/.tools/bir/Resources" | grep -oE '[0-9]+ inventoried names')
for name in CreateFrame hooksecurefunc ChatFrame1 LE_EXPANSION_CLASSIC Enum.ItemQuality FISHING; do
	inventory_add "$name"
done
echo 'stds.wow.read_globals.C_Weather = { fields = { "GetCurrentWeather" } }' >>"$scratch/tree/.luacheckrc"
expect "real names from each part of the dump pass api" pass "api: $((${inventoried%% *} + 8)) inventoried names"

copy
echo 'table.insert(stds.wow_variables.read_globals, "CreateFrame")' >>"$scratch/tree/.luacheckrc"
expect "a client variable the dump does list fails api" api "move it from stds.wow_variables"

copy
inventory_add MadeUpApi
expect "a made-up API in the inventory fails api" api "MadeUpApi is in stds.wow but not in the forever dump"

copy
inventory_add C_Weather.MadeUp
expect "a made-up function of a real namespace fails api" api "C_Weather.MadeUp is in stds.wow"

copy
printf 'read_globals = { "CreateFrame" }\n' >>"$scratch/tree/.luacheckrc"
expect "a top-level read_globals (reaching logic/) fails api" api "top-level read_globals"

copy
toc_drop 'logic\Forever.lua'
expect "a file dropped from Pagle.toc that Core needs fails tests" tests "attempt to call field 'IsForever'"

copy
toc_drop 'libs\AceDB-3.0\AceDB-3.0.lua'
expect "a vendored lib dropped from Pagle.toc fails tests" tests 'Cannot find a library instance of "AceDB-3.0"'

copy
toc_drop 'adapter\Bindings.lua' "$scratch/tree/addons/Pagle_QoL/Pagle_QoL.toc"
expect "a file dropped from Pagle_QoL.toc fails tests" tests "lists every Lua file in the addon folder"

copy
toc_move_after 'logic\Forever.lua' 'adapter\Core.lua'
expect "a file listed after the file that needs it fails tests" tests "adapter/Core.lua failed while loading"

copy
toc_move_after 'libs\LibStub\LibStub.lua' 'libs\CallbackHandler-1.0\CallbackHandler-1.0.lua'
expect "a vendored lib listed after the lib that needs it fails tests" tests \
	"CallbackHandler-1.0.lua failed while loading"

copy
expect "the tests stage reports coverage of addon code" pass "addons/Pagle/logic/Forever.lua"

copy
printf 'local ns = select(2, ...)\n\nfunction ns.Untested()\n\treturn 1\nend\n' >"$addon/logic/Untested.lua"
echo 'logic\Untested.lua' >>"$toc"
expect "code no spec runs passes; coverage doesn't gate" pass "addons/Pagle/logic/Untested.lua"

copy
rm "$scratch/tree/.luacov"
expect "a coverage report that can't be made doesn't gate" pass "no coverage report"

# Plants a spec that kills the busted running it with SIGSEGV, as the coverage run has died on the dev's machine
# (#149). With "coverage", only a busted running with luacov dies.
kills_busted() {
	local when='true'
	[[ ${1:-} == coverage ]] && when='package.loaded["luacov.runner"]'
	cat >"$scratch/tree/spec/killed_spec.lua" <<EOF
it("is killed", function()
	if $when then
		os.execute("kill -SEGV \$PPID")
	end
end)
EOF
}

copy
kills_busted coverage
expect "a coverage run killed by a signal doesn't gate; the specs run again without coverage" pass \
	"killed by signal 11; running the specs again without coverage"

copy
kills_busted
expect "specs that kill busted without coverage too fail tests" tests "killed by signal 11"

copy
printf 'Pagle.API_VERSION = "2"\n' >>"$addon/adapter/Core.lua"
expect "a string assigned to Pagle.API_VERSION in Core fails types" types "assign-type-mismatch"

copy
line=$(($(wc -l <"$addon/adapter/Core.lua") + 1))
printf -- '---@diagnostic disable\nPagle.API_VERSION = "2"\n' >>"$addon/adapter/Core.lua"
expect "a bare ---@diagnostic disable fails types" types "adapter/Core.lua:$line:---@diagnostic disable"

copy
printf -- '---@diagnostic disable-next-line: assign-type-mismatch\nPagle.API_VERSION = "2"\n' >>"$addon/adapter/Core.lua"
expect "a suppression without a reason fails types" types "each suppression must be"

copy
printf 'do\n\t---@diagnostic disable-next-line: assign-type-mismatch, cast-local-type -- testing the gate\n' \
	>>"$addon/adapter/Core.lua"
printf '\tPagle.API_VERSION = "2"\nend\n' >>"$addon/adapter/Core.lua"
# types lets it through; the stage after it, tests, still catches the string (CORE-R15).
expect "an inline suppression with codes and a reason passes types" tests "API version 1 before 1.0 (CORE-R15)"

copy
printf 'auras = [1]\nfishingSpells = [7620]\n' >"$scratch/tree/data/forever/lists.toml"
expect "a data/ change committed without its regenerated file fails generator" generator \
	"addons/Pagle/data/Catalogue.lua is out of date with data/"

copy
printf 'x1,0,0,Planted\n' >>"$scratch/tree/data/db2/areas.csv"
expect "an areas.csv row with a non-integer ID fails generator" generator "ID: expected a positive integer, got 'x1'"

copy
sed -i '2s/^1,/2,/' "$scratch/tree/data/baseline/skill.csv"
expect "a hand-edited baseline CSV fails generator" generator \
	"data/baseline/skill.csv: its SHA-256 differs from data/baseline/source.toml"

copy
printf '\n[[alias]]\nfrom = 16562\nto = 267\n' >>"$scratch/tree/data/forever/aliases.toml"
expect "an alias without a why fails generator" generator "data/forever/aliases.toml: alias[10]: missing key 'why'"

copy
# Drops Raw Nightfin Snapper's category, the line after its table header.
sed -i '/^\[item\.13759\]$/{n;d;}' "$scratch/tree/data/forever/items.toml"
expect "an item with no category fails generator" generator "data/forever/items.toml: item.13759: no category"

copy
# Drops spring's why, the second line after its table header.
sed -i '/^\[window\.spring\]$/{n;n;d;}' "$scratch/tree/data/forever/windows.toml"
expect "a window without a why fails generator" generator "data/forever/windows.toml: window.spring: missing key 'why'"

copy
printf '\n[[catch]]\narea = 33\nitem = 6303\nop = "add"\ngate = "dusk"\nwhy = "planted"\n' \
	>>"$scratch/tree/data/forever/areas.toml"
expect "a catch gated by an unknown window fails generator" generator "gate: 'dusk' isn't a window ID (DATA-R35)"

copy
printf '\n[pool.planted]\nentries = [999999]\n' >>"$scratch/tree/data/forever/pools.toml"
expect "a pool type without a why fails generator" generator "data/forever/pools.toml: pool.planted: missing key 'why'"

copy
sed -i '1i colour = "red"' "$scratch/tree/data/observed/dev.toml"
expect "an unknown key in dev.toml fails generator" generator "data/observed/dev.toml: unknown key 'colour'"

copy
# With the Ledger's lore check on since #131 (DATA-R66), replaces Raw Nightfin Snapper's riddle, inside its table,
# with an 81-character one (DATA-R107).
sed -i "/^\[species\.13759\]/,/^\$/ s/^riddle = .*/riddle = \"$(head -c 81 /dev/zero | tr '\0' x)\"/" \
	"$scratch/tree/data/lore/ledger.toml"
expect "with the ledger lore check on, a riddle over 80 code points fails generator" generator \
	"data/lore/ledger.toml: species.13759.riddle: length: 81 code points, over riddle's limit of 80"

wait
report
if ((reported != cases)); then
	echo "test-check: only $reported of $cases cases gave a verdict" >&2
	exit 1
fi
if ((failures)); then
	echo "test-check: $failures failed" >&2
	exit 1
fi
echo "test-check: all passed"
