#!/usr/bin/env bash
# Runs scripts/read-wtf.lua on the pinned Lua 5.1 from scripts/setup.sh, from any directory: reads in-game results
# from a WTF account folder (docs/agents/in-game-verification.md).
#
#   scripts/read-wtf.sh <WTF/Account/<ACCT> folder> [--character <realm>/<Name-Surname>] [--cvar <name>]...
#       [--addon <name>]... [--catalogue <Catalogue.lua>] [--expect-casts N] [--since T]
#
# Run it in WSL or on macOS. Exits as the Lua script does: 0 read (and, with --expect-casts, passed), 1 an
# --expect-casts check failed, 2 a usage error.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/tools.sh
source "$root/scripts/lib/tools.sh"
tools=$(tools_dir "$root")
if [[ ! -x $tools/bin/lua ]]; then
	echo "read-wtf: no $tools/bin/lua; run scripts/setup.sh" >&2
	exit 2
fi
export PAGLE_TOOLS=$tools
exec "$tools/bin/lua" "$root/scripts/read-wtf.lua" "$@"
