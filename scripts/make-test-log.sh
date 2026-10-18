#!/usr/bin/env bash
# Runs scripts/make-test-log.lua on the pinned Lua 5.1 from scripts/setup.sh, from any directory: makes, installs
# and restores the M4 and M7 exit checks' test logs, launch re-verification's big ones and the look-and-feel
# check's showcase (docs/agents/in-game-verification.md).
#
#   scripts/make-test-log.sh --account <WTF/Account/<ACCT> folder>
#       --preset <level10|level60|catches1000|boardday|big5|big20|showcase>
#       [--out <folder>] [--catalogue <Catalogue.lua>]
#   scripts/make-test-log.sh --account <folder> --install [--out <folder>]
#   scripts/make-test-log.sh --account <folder> --restore [--out <folder>]
#
# Run it in WSL with the game fully closed: the client writes every SavedVariables file when it logs out, over
# whatever --install or --restore put there. Before either, it refuses while a WoW process runs. Exits as the Lua
# script does: 0 done, 1 refused (nothing changed), 2 a usage error.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -x $root/.tools/bin/lua ]]; then
	echo "make-test-log: no $root/.tools/bin/lua; run scripts/setup.sh" >&2
	exit 2
fi
for word in "$@"; do
	if [[ $word == --install || $word == --restore ]] && command -v tasklist.exe >/dev/null 2>&1; then
		if tasklist.exe 2>/dev/null | grep -qi '^wow'; then
			echo "make-test-log: World of Warcraft is running; quit it fully, then run this again. Nothing changed." >&2
			exit 1
		fi
	fi
done
exec "$root/.tools/bin/lua" "$root/scripts/make-test-log.lua" "$@"
