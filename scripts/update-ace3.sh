#!/usr/bin/env bash
# Vendors the Ace3 libraries Core embeds (CORE-R6) into addons/Pagle/libs/.
# This script is the only way to change those files; never edit them by hand.
#
#   scripts/update-ace3.sh             re-vendor the commit recorded in scripts/ace3.commit
#   scripts/update-ace3.sh <ref>       vendor <ref> (a commit, branch or tag of WoWUIDev/Ace3) and record its commit
#   scripts/update-ace3.sh --check     exit 1 unless addons/Pagle/libs/ matches the recorded commit byte for byte
#
# Needs bash, curl, tar and diff (WSL or Git Bash).
set -euo pipefail

upstream="WoWUIDev/Ace3"
files=(
	LICENSE.txt
	LibStub/LibStub.lua
	CallbackHandler-1.0/CallbackHandler-1.0.lua
	AceAddon-3.0/AceAddon-3.0.lua
	AceEvent-3.0/AceEvent-3.0.lua
	AceDB-3.0/AceDB-3.0.lua
)

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
record="$root/scripts/ace3.commit"
dest="$root/addons/Pagle/libs"

mode=update
ref=""
case "${1:-}" in
	--check) mode=check ;;
	-h | --help)
		# The header comment: every line after the shebang up to the first that isn't a comment.
		awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
		exit 0
		;;
	"") ;;
	*) ref=$1 ;;
esac

if [[ -z $ref ]]; then
	ref=$(tr -d '[:space:]' <"$record")
fi

# Resolve any ref to its full commit hash.
commit=$(curl -fsSL -H "Accept: application/vnd.github.sha" "https://api.github.com/repos/$upstream/commits/$ref")
if [[ ! $commit =~ ^[0-9a-f]{40}$ ]]; then
	echo "update-ace3: could not resolve '$ref' in $upstream" >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://codeload.github.com/$upstream/tar.gz/$commit" -o "$tmp/ace3.tar.gz"
mkdir "$tmp/src" "$tmp/libs"
tar -xzf "$tmp/ace3.tar.gz" -C "$tmp/src" --strip-components=1

for f in "${files[@]}"; do
	mkdir -p "$tmp/libs/$(dirname "$f")"
	cp "$tmp/src/$f" "$tmp/libs/$f"
done

if [[ $mode == check ]]; then
	if diff -r -q "$tmp/libs" "$dest"; then
		echo "update-ace3: addons/Pagle/libs matches $upstream@$commit"
	else
		echo "update-ace3: addons/Pagle/libs differs from $upstream@$commit; run scripts/update-ace3.sh" >&2
		exit 1
	fi
	exit 0
fi

rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -r "$tmp/libs" "$dest"
printf '%s\n' "$commit" >"$record"
echo "update-ace3: vendored $upstream@$commit into addons/Pagle/libs"
