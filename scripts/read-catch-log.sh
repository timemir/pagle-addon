#!/usr/bin/env bash
# Runs scripts/read-catch-log.lua on the pinned Lua 5.1 from scripts/setup.sh: reads the Catch log from a
# SavedVariables folder and checks the M1 exit check's steps 3 and 4 (#75). docs/agents/exit-check.md has the details.
#
#   scripts/read-catch-log.sh <WTF/Account/<ACCOUNT>/SavedVariables folder> [--expect-casts N] [--since T]
#
# Run it in WSL, from any directory. Exits as the Lua script does: 0 read (and passed), 1 a check failed, 2 a usage
# error or an unreadable Pagle.lua.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -x $root/.tools/bin/lua ]]; then
	echo "read-catch-log: no $root/.tools/bin/lua; run scripts/setup.sh" >&2
	exit 2
fi
exec "$root/.tools/bin/lua" "$root/scripts/read-catch-log.lua" "$@"
