#!/usr/bin/env bash
# Runs scripts/rewrite-bindings.lua on the pinned Lua 5.1 from scripts/setup.sh, from any directory: the one-off
# rewrite of the dev's saved data when Journal bindings and notebook covers became one Core slot (ADR 0015, #353).
#
#   scripts/rewrite-bindings.sh <WTF folder> [--dry-run]
#
# e.g. scripts/rewrite-bindings.sh "/mnt/g/World of Warcraft/_classic_beta_/WTF" --dry-run
#
# Run it in WSL with the game fully closed: the client writes every SavedVariables file when it logs out, over
# whatever this put there. Unless --dry-run, it refuses while a WoW process runs, and warns when it can't tell
# (no tasklist.exe). Exits as the Lua script does: 0 done, 1 refused (nothing written), 2 a usage error.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -x $root/.tools/bin/lua ]]; then
	echo "rewrite-bindings: no $root/.tools/bin/lua; run scripts/setup.sh" >&2
	exit 2
fi
dry_run=false
for word in "$@"; do
	[[ $word == --dry-run ]] && dry_run=true
done
if [[ $dry_run == false ]]; then
	if command -v tasklist.exe >/dev/null 2>&1; then
		if tasklist.exe 2>/dev/null | grep -qi '^wow'; then
			echo "rewrite-bindings: World of Warcraft is running; quit it fully, then run this again. Nothing written." >&2
			exit 1
		fi
	else
		echo "rewrite-bindings: can't tell whether World of Warcraft is running (no tasklist.exe); make sure it's" \
			"fully closed, or the next logout writes over this rewrite." >&2
	fi
fi
exec "$root/.tools/bin/lua" "$root/scripts/rewrite-bindings.lua" "$@"
