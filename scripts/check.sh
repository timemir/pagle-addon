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
if [[ ! -x $bin/lua || ! -x $bin/stylua || ! -x $bin/luacheck ]]; then
	echo "check: the tools aren't installed; run scripts/setup.sh" >&2
	exit 1
fi

stage() {
	echo "==> $1"
}

fail() {
	echo "check: FAILED at $1" >&2
	exit 1
}

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

echo "check: passed"
