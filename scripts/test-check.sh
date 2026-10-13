#!/usr/bin/env bash
# Tests the check gate itself: plants a known mistake in a scratch copy of the tree and asserts that
# scripts/check.sh fails at the stage that should catch it (and that the untouched tree passes).
#
#   scripts/test-check.sh
#
# Needs the tools from scripts/setup.sh. Never touches the working tree.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0

# Fresh copy of the tree, sharing the installed tools.
copy() {
	rm -rf "$scratch/tree"
	mkdir "$scratch/tree"
	tar -C "$root" --exclude=./.git --exclude=./.tools --exclude=./.release -cf - . | tar -C "$scratch/tree" -xf -
	ln -s "$root/.tools" "$scratch/tree/.tools"
}

# expect <case> <stage|pass> [text]: runs the gate on the copy and checks where it stopped, and that its
# output names the reason when text is given.
expect() {
	local output status=0 ok=no
	output=$(bash "$scratch/tree/scripts/check.sh" 2>&1) || status=$?
	if [[ $2 == pass && $status -eq 0 ]] || [[ $2 != pass && $status -ne 0 && $output == *"FAILED at $2"* ]]; then
		[[ $output == *"${3:-}"* ]] && ok=yes
	fi
	if [[ $ok == yes ]]; then
		echo "ok   $1"
	else
		echo "FAIL $1: expected $2${3:+ naming \"$3\"}, got exit $status"
		sed 's/^/     | /' <<<"$output"
		failures=$((failures + 1))
	fi
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

# Drops a file from Pagle.toc.
toc_drop() {
	grep -vxF "$1" "$toc" >"$toc.new"
	mv "$toc.new" "$toc"
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
uses_create_frame "$addon/adapter/Global.lua"
expect "a WoW global in adapter/ fails lint until inventoried" lint "accessing undefined variable 'CreateFrame'"

copy
uses_create_frame "$addon/adapter/Global.lua"
inventory_add CreateFrame
expect "a WoW global in adapter/ passes once inventoried" pass

copy
mkdir "$addon/ui"
uses_create_frame "$addon/ui/Global.lua"
inventory_add CreateFrame
expect "a WoW global anywhere but adapter/ fails lint, even when inventoried" lint \
	"accessing undefined variable 'CreateFrame'"

copy
for name in CreateFrame hooksecurefunc ChatFrame1 LE_EXPANSION_CLASSIC Enum.ItemQuality FISHING; do
	inventory_add "$name"
done
echo 'stds.wow.read_globals.C_Weather = { fields = { "GetCurrentWeather" } }' >>"$scratch/tree/.luacheckrc"
expect "real names from each part of the dump pass api" pass "api: 8 inventoried names"

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
expect "a vendored lib dropped from Pagle.toc fails tests" tests "embeds AceDB-3.0"

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

if ((failures)); then
	echo "test-check: $failures failed" >&2
	exit 1
fi
echo "test-check: all passed"
