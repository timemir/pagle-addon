#!/usr/bin/env bash
# Tests the check gate itself: plants a known mistake in a scratch copy of the tree and asserts that
# scripts/check.sh fails at the stage that should catch it (and that the untouched tree passes).
#
#   scripts/test-check.sh
#   TEST_CHECK_JOBS=1 scripts/test-check.sh    # one case at a time
#
# Needs the tools from scripts/setup.sh (a worktree's are the main checkout's, scripts/lib/tools.sh). Never touches the
# working tree, .tools/cache/ included. Runs on macOS too, in bash 3.2 and up, as scripts/check.sh does.
#
# A case is `copy`, its planted mistake under "$scratch/tree", then `expect`. Each case gets its own copy in
# native tmp and runs the whole gate in the background, TEST_CHECK_JOBS at a time (default: the CPU count, at
# most 8, and no more than the memory available holds; see case_memory_kb), without coverage but for the cases about
# it. Verdicts print in the order the cases are written.
#
# CI runs this in its own job, only when the gate's own machinery changes (.github/workflows/check.yml).
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/tools.sh
source "$root/scripts/lib/tools.sh"
tools=$(tools_dir "$root")
scratch=$(mktemp -d)
# On an early exit, the running cases finish before their copies go.
trap 'wait; rm -rf "$scratch"' EXIT
failures=0
cases=0
reported=0
# The cases run the gate without coverage, in a fraction of the time and memory: where the gate stops doesn't depend
# on it. The cases about coverage itself (luacov's report, a coverage run killed by a signal) set PAGLE_NO_COVERAGE=0.
export PAGLE_NO_COVERAGE=1
# Cases run at once, so each gate runs its busted shards one at a time (#254); the case that wants more sets its own.
export GATE_JOBS=1

# What one case's gate can take at its peak: its stages run at once, a busted shard up to 1.5 GB with
# lua-language-server at 2.3 GB beside it. Cases past what MemAvailable holds get their busted OOM-killed, and fail;
# in CI, the runner likely shuts down mid-run instead.
case_memory_kb=$((4 * 1024 * 1024))
max_jobs=${TEST_CHECK_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}
if [[ -z ${TEST_CHECK_JOBS:-} ]]; then
	((max_jobs <= 8)) || max_jobs=8
	available_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo 2>/dev/null || true)
	# No /proc/meminfo on macOS: the installed memory stands in for what's available.
	if [[ -z $available_kb ]] && memory=$(sysctl -n hw.memsize 2>/dev/null); then
		available_kb=$((memory / 1024))
	fi
	if [[ $available_kb =~ ^[0-9]+$ ]] && ((max_jobs > available_kb / case_memory_kb)); then
		max_jobs=$((available_kb / case_memory_kb))
	fi
fi
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
for tool in "$tools"/*; do
	[[ ${tool##*/} == cache ]] || ln -s "$tool" "$base/.tools/"
done
if [[ -d $root/.tools/cache/mypy ]]; then
	cp -a "$root/.tools/cache/mypy" "$base/.tools/cache/"
fi

# Fresh copy of the tree for the next case. "$scratch/tree" points at it until the next copy.
copy() {
	local spec
	local retained=(
		spec/Pagle/adapter/Core_spec.lua
		spec/Pagle/Pagle_toc_spec.lua
		spec/Pagle_QoL/Pagle_QoL_toc_spec.lua
		# scripts/tests/test_launch.py opens every Module's TOC spec, which the launch-night interface bump edits.
		spec/Pagle_Ledger/Pagle_Ledger_toc_spec.lua
		spec/Pagle_Hunts/Pagle_Hunts_toc_spec.lua
		spec/Pagle_Stats/Pagle_Stats_toc_spec.lua
		spec/Pagle_TackleBoard/Pagle_TackleBoard_toc_spec.lua
	)
	local keep=()
	cases=$((cases + 1))
	case_tree="$scratch/cases/$cases"
	cp -a "$base" "$case_tree"
	for spec in "${retained[@]}"; do
		[[ -f $case_tree/$spec ]] || { echo "test-check: missing retained spec $spec" >&2; exit 1; }
	done
	for spec in "${retained[@]}"; do
		keep+=(! -path "$case_tree/$spec")
	done
	find "$case_tree/spec" -name '*_spec*.lua' "${keep[@]}" -delete
	ln -sfn "$case_tree" "$scratch/tree"
}

# expect <case> <stage|pass> [text...]: runs the gate on the copy and checks where it stopped, and that its
# output names each text given. The case starts in the background once a job slot is free.
expect() {
	while (($(jobs -pr | wc -l) >= max_jobs)); do
		wait_any
		report
	done
	run_case "$case_tree" "$scratch/results/$cases" "$@" &
}

# run_case <tree> <verdict file> <case> <stage|pass> [text...]: the gate on one copy, as expect describes.
run_case() {
	local tree=$1 verdict=$2 output status=0 ok=no text from=$SECONDS
	shift 2
	output=$(bash "$tree/scripts/check.sh" 2>&1) || status=$?
	if [[ $2 == pass && $status -eq 0 ]] || [[ $2 != pass && $status -ne 0 && $output == *"FAILED at $2"* ]]; then
		ok=yes
		for text in "${@:3}"; do
			[[ $output == *"$text"* ]] || ok=no
		done
	fi
	if [[ $ok == yes ]]; then
		{
			echo "ok   $1 ($((SECONDS - from))s)"
			while IFS= read -r text; do
				[[ $text != "check: times:"* ]] || echo "     $text"
			done <<<"$output"
		} >"$verdict.part"
	else
		{
			echo "FAIL $1: expected $2${3:+ naming$(printf ' "%s"' "${@:3}")}, got exit $status"
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

# Writes the inventory the addon ships (addons/Pagle/data/ApiInventory.lua) from the copy's .luacheckrc, as a commit
# that changes the inventory does (#261): the api stage fails while it's stale.
inventory_write() {
	"$tools/bin/lua" "$root/scripts/api-inventory.lua" "$scratch/tree/.luacheckrc" \
		"$scratch/tree/addons/Pagle/data/ApiInventory.lua" >/dev/null
}

# Adds a name to the WoW API inventory (stds.wow in .luacheckrc), and writes the inventory the addon ships.
inventory_add() {
	printf 'table.insert(stds.wow.read_globals, "%s")\n' "$1" >>"$scratch/tree/.luacheckrc"
	inventory_write
}

addon="$scratch/tree/addons/Pagle"
toc="$addon/Pagle.toc"

# Writes a Lua file that calls the WoW global CreateFrame.
uses_create_frame() {
	printf 'local frame = CreateFrame("Frame")\nreturn frame\n' >"$1"
}

# Writes a Lua file that calls the WoW global Logout, which Pagle never inventories (the dev tour took Screenshot).
uses_logout() {
	printf 'Logout()\n' >"$1"
}

# Puts a key dev.toml doesn't have on its first line (sed -i '1i' is GNU's).
dev_toml_colour() {
	local toml="$scratch/tree/data/observed/dev.toml"
	{ echo 'colour = "red"'; cat "$toml"; } >"$toml.new"
	mv "$toml.new" "$toml"
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
# Each stage's wall time prints before the verdict (#254).
expect "the tree as it is passes" pass "check: times: libs "

copy
echo "STYLUA_VERSION=0.0.0" >>"$scratch/tree/scripts/tools.env"
expect "a pin changed since the last setup stops the gate" setup "run scripts/setup.sh"

copy
sed 's#BigWigsMods/packager@[0-9a-f]*#BigWigsMods/packager@0123456789abcdef0123456789abcdef01234567#' \
	"$scratch/tree/.github/workflows/release.yml" >"$scratch/release.yml"
mv "$scratch/release.yml" "$scratch/tree/.github/workflows/release.yml"
expect "a packager pin in release.yml that differs from tools.env stops the gate" setup \
	"PACKAGER_COMMIT in scripts/tools.env"

copy
printf -- '-- edited by hand\n' >>"$addon/libs/AceDB-3.0/AceDB-3.0.lua"
expect "a hand-edited vendored lib fails libs" libs "addons/Pagle/libs/AceDB-3.0/AceDB-3.0.lua: FAILED"

copy
printf -- '-- edited by hand\n' >>"$addon/libs/LibDeflate/LibDeflate.lua"
expect "a hand-edited LibDeflate fails libs" libs "addons/Pagle/libs/LibDeflate/LibDeflate.lua: FAILED"

copy
printf 'return 1\n' >"$addon/libs/Stray.lua"
expect "a file in libs/ that no update script vendored fails libs" libs "addons/Pagle/libs/Stray.lua"

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
uses_logout "$addon/adapter/Global.lua"
expect "a WoW global in adapter/ fails lint until inventoried" lint "accessing undefined variable 'Logout'"

copy
uses_logout "$addon/adapter/Global.lua"
inventory_add Logout
expect "a WoW global in adapter/ passes once inventoried" pass

copy
mkdir "$addon/ui"
uses_create_frame "$addon/ui/Global.lua"
inventory_add CreateFrame
expect "a WoW global anywhere but adapter/ fails lint, even when inventoried" lint \
	"accessing undefined variable 'CreateFrame'"

copy
# The api stage counts what the tree inventories already, plus the 8 names added here.
inventoried=$("$tools/bin/lua" "$root/scripts/api-presence.lua" "$scratch/tree/.luacheckrc" \
	"$tools/bir/Resources" | grep -oE '[0-9]+ inventoried names')
for name in CreateFrame hooksecurefunc ChatFrame1 LE_EXPANSION_CLASSIC Enum.ItemQuality FISHING; do
	inventory_add "$name"
done
echo 'stds.wow.read_globals.C_Weather = { fields = { "GetCurrentWeather" } }' >>"$scratch/tree/.luacheckrc"
inventory_write
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
PAGLE_NO_COVERAGE=0 expect "the tests stage reports coverage of addon code" pass "addons/Pagle/logic/Forever.lua"

copy
printf 'local ns = select(2, ...)\n\nfunction ns.Untested()\n\treturn 1\nend\n' >"$addon/logic/Untested.lua"
echo 'logic\Untested.lua' >>"$toc"
PAGLE_NO_COVERAGE=0 expect "code no spec runs passes; coverage doesn't gate" pass "addons/Pagle/logic/Untested.lua"

copy
rm "$scratch/tree/.luacov"
PAGLE_NO_COVERAGE=0 expect "a coverage report that can't be made doesn't gate" pass "no coverage report"

copy
# GATE_JOBS=1, as every case here has it: the shards run one after another (#254).
PAGLE_NO_COVERAGE=1 expect "PAGLE_NO_COVERAGE=1 runs the specs without coverage, in shards one at a time, and passes" \
	pass "PAGLE_NO_COVERAGE=1, so the specs run without coverage" "1 at a time" "tests: spec/Pagle passed"

copy
printf 'it("fails", function()\n\tassert.is_true(false)\nend)\n' >"$scratch/tree/spec/fails_spec.lua"
PAGLE_NO_COVERAGE=0 expect "a failing spec fails tests with coverage, as the gate runs by default" tests "fails_spec.lua"

copy
printf 'it("fails", function()\n\tassert.is_true(false)\nend)\n' >"$scratch/tree/spec/fails_spec.lua"
PAGLE_NO_COVERAGE=1 expect "a failing spec fails tests without coverage too" tests "fails_spec.lua"

copy
printf 'it("fails", function()\n\tassert.is_true(false)\nend)\n' >"$scratch/tree/spec/Pagle_QoL/fails_spec.lua"
PAGLE_NO_COVERAGE=1 GATE_JOBS=3 expect "a failing spec in one shard fails tests and names the spec" tests \
	"spec/Pagle_QoL/fails_spec.lua" "tests: spec/Pagle_QoL failed" "tests: spec/Pagle passed"

copy
# The first pass leaves #slow specs out (--exclude-tags=slow); the second runs only them.
printf 'it("fails #slow", function()\n\tassert.is_true(false)\nend)\n' >"$scratch/tree/spec/slow_fails_spec.lua"
PAGLE_NO_COVERAGE=1 expect "a failing spec tagged #slow fails tests in the #slow pass" tests "slow_fails_spec.lua"

# Plants a spec that kills the busted running it with SIGSEGV, as the coverage run has died on the dev's machine
# (#149). With "coverage", only a busted running with luacov dies.
kills_busted() {
	local when='package.loaded'
	[[ ${1:-} == coverage ]] && when='package.loaded["luacov.runner"]'
	cat >"$scratch/tree/spec/killed_spec.lua" <<EOF
it("is killed", function()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no package
	if $when then
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
		os.execute("kill -SEGV \$PPID")
	end
end)
EOF
}

copy
kills_busted coverage
PAGLE_NO_COVERAGE=0 expect "a coverage run killed by a signal doesn't gate; the specs run again without coverage" pass \
	"killed by signal 11; running the specs again without coverage"

copy
kills_busted
PAGLE_NO_COVERAGE=0 expect "specs that kill busted without coverage too fail tests" tests "killed by signal 11"

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

# The stages after libs run at once, but the verdict is the first failing stage in their order (#254).
copy
uses_create_frame "$addon/logic/Global.lua"
printf 'Pagle.API_VERSION = "2"\n' >>"$addon/adapter/Core.lua"
expect "a lint error and a types error at once fail lint" lint "accessing undefined variable 'CreateFrame'"

copy
printf 'Pagle.API_VERSION = "2"\n' >>"$addon/adapter/Core.lua"
dev_toml_colour
# generator finishes long before types, and still doesn't give the verdict.
expect "a types error and a generator error at once fail types" types "assign-type-mismatch"

copy
# Keeps the auras data/hunts/hunts.toml names (Rack 1280341, Hut 1280342), which DATA-R39 checks before the catalogue.
printf 'auras = [1280341, 1280342]\nfishingSpells = [7620]\n' >"$scratch/tree/data/forever/lists.toml"
expect "a data/ change committed without its regenerated file fails generator" generator \
	"addons/Pagle/data/Catalogue.lua is out of date with data/"

copy
dev_toml_colour
expect "an unknown key in dev.toml fails generator" generator "data/observed/dev.toml: unknown key 'colour'"

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
