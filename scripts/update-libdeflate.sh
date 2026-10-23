#!/usr/bin/env bash
# Vendors LibDeflate, which Core embeds for the Paste string (CORE-R6, PST-R30), into addons/Pagle/libs/LibDeflate/.
# This script is the only way to change those files; never edit them by hand.
#
#   scripts/update-libdeflate.sh           re-vendor the commit recorded in scripts/libdeflate.commit
#   scripts/update-libdeflate.sh <ref>     vendor <ref> (a commit, branch or tag of SafeteeWoW/LibDeflate) and record
#                                          its commit
#   scripts/update-libdeflate.sh --check   exit 1 unless addons/Pagle/libs/LibDeflate/ and scripts/libdeflate.sha256
#                                          match the recorded commit byte for byte
#
# The recorded commit is the 1.0.2-release tag's, 6831edca (LibDeflate 1.0.2, its last release): pagle-backend's
# upload.md names LibDeflate 1.0.2's CompressDeflate and EncodeForPrint as the Paste string's encoding, so a new ref is
# a change to agree with pagle-backend first. LibDeflate is under the zlib License, in LICENSE.txt beside it (NOTICE).
#
# Vendoring also writes scripts/libdeflate.sha256, the sha256 of every file it vendored. The check gate
# (scripts/check.sh) holds addons/*/libs/ to it and scripts/ace3.sha256 offline, so a hand edit fails the gate.
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

vendor_main update-libdeflate SafeteeWoW/LibDeflate "$root" scripts/libdeflate.commit scripts/libdeflate.sha256 \
	addons/Pagle/libs/LibDeflate \
	LibDeflate.lua \
	LICENSE.txt \
	-- "$@"
