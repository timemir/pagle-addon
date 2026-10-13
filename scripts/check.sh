#!/usr/bin/env bash
# The check gate: runs every stage in order and stops at the first failure. Exit 0 means the tree passes.
#
#   scripts/check.sh
#
# Needs the pinned tools in .tools/ (run scripts/setup.sh once). Runs locally in WSL and in CI alike.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
bin="$root/.tools/bin"

stage() {
	echo "==> $1"
}

fail() {
	echo "check: FAILED at $1" >&2
	exit 1
}

# setup.sh keeps a copy of the pins it installed; any difference means .tools/ is missing or out of date.
if ! cmp -s scripts/tools.env .tools/tools.env; then
	echo "check: .tools/ doesn't match scripts/tools.env; run scripts/setup.sh" >&2
	fail setup
fi

# The Lua the gate covers: every addon (minus vendored libs/, which the tool configs exclude), the specs,
# the scripts and the type stubs. probes/ and prototypes/ are throwaway experiments, never shipped or checked.
lua_dirs=()
for dir in addons spec scripts types; do
	[[ -d $dir ]] && lua_dirs+=("$dir")
done

# Each stage below is one self-contained block: a banner, its commands, `|| fail <stage>`.

# --- 1. format (#47): StyLua defaults, Lua 5.1 syntax (.stylua.toml); vendored libs skipped (.styluaignore).
stage format
"$bin/stylua" --check "${lua_dirs[@]}" || fail format

# --- 2. lint (#47): luacheck, Lua 5.1, no WoW globals in logic/ or locale/ (CORE-R7), the WoW API inventory
# in .luacheckrc; vendored libs excluded there.
stage lint
"$bin/luacheck" --quiet --no-color "${lua_dirs[@]}" || fail lint

# --- 3. api (#47): every inventoried WoW API is in the pinned forever dump (BIR_COMMIT in scripts/tools.env).
stage api
"$bin/lua" scripts/api-presence.lua .luacheckrc .tools/bir/Resources || fail api

# --- 4. types (#48): lua-language-server --check, zero warnings. Not built yet.

# --- 5. tests (#49): busted on Lua 5.1, every spec/**/*_spec.lua. spec/support/addon.lua loads each addon from its
# real .toc, in order, so TOC and load-order mistakes fail specs. luacov then reports coverage of addons/ (.luacov);
# the report never gates.
stage tests
mkdir -p .tools/cache
rm -f .tools/cache/luacov.*.out # luacov adds to an existing stats file
"$bin/busted" --coverage || fail tests
{ "$bin/luacov" && echo "coverage (reported, never gates):" && sed -n '/^File /,$p' .tools/cache/luacov.report.out; } ||
	echo "check: no coverage report (coverage never gates)"

# --- 6. generator (M1, DATA-R61): the content generator's check and tests. Not built yet.

echo "check: passed"
