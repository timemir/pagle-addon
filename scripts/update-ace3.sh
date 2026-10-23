#!/usr/bin/env bash
# Vendors the Ace3 libraries Core embeds (CORE-R6) into addons/Pagle/libs/.
# This script is the only way to change those files; never edit them by hand.
#
#   scripts/update-ace3.sh             re-vendor the commit recorded in scripts/ace3.commit
#   scripts/update-ace3.sh <ref>       vendor <ref> (a commit, branch or tag of WoWUIDev/Ace3) and record its commit
#   scripts/update-ace3.sh --check     exit 1 unless the Ace3 files in addons/Pagle/libs/ and scripts/ace3.sha256
#                                      match the recorded commit byte for byte
#
# Vendoring also writes scripts/ace3.sha256, the sha256 of every file it vendored. The check gate (scripts/check.sh)
# holds addons/*/libs/ to it and scripts/libdeflate.sha256 offline, so a hand edit fails the gate. LibDeflate shares
# addons/Pagle/libs/ (scripts/update-libdeflate.sh owns it); this script leaves it alone.
#
# Needs bash, curl, tar, cmp, diff and sha256sum (WSL or Git Bash).
set -euo pipefail

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
	# The header comment: every line after the shebang up to the first that isn't a comment.
	awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
	exit 0
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/vendor.sh
source "$root/scripts/lib/vendor.sh"

vendor_main update-ace3 WoWUIDev/Ace3 "$root" scripts/ace3.commit scripts/ace3.sha256 addons/Pagle/libs \
	LICENSE.txt \
	LibStub/LibStub.lua \
	CallbackHandler-1.0/CallbackHandler-1.0.lua \
	AceAddon-3.0/AceAddon-3.0.lua \
	AceEvent-3.0/AceEvent-3.0.lua \
	AceDB-3.0/AceDB-3.0.lua \
	-- "$@"
