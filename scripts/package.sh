#!/usr/bin/env bash
# Builds the release zip locally with the BigWigsMods packager, uploads off, then checks its contents.
# The release workflow (.github/workflows/release.yml) runs the same packager commit on a tag push:
# PACKAGER_COMMIT in scripts/tools.env, which scripts/check.sh holds the workflow to.
#
#   scripts/package.sh             build .release/Pagle-<version>-forever.zip from HEAD and check it
#
# It packages the committed HEAD from a fresh clone, as the workflow packages the tagged commit,
# so commit first. (The packager also can't read a git worktree, whose .git is a file.)
# Before the first tag, @project-version@ becomes the short commit hash.
#
# The check: the zip holds one top-level folder per addons/<Addon>/ folder (Pagle only, until the
# Modules arrive), each holding exactly that folder's tracked files, plus the packager's
# Pagle/CHANGELOG.md and the repo's LICENSE and NOTICE in Pagle/. Nothing else: no docs/, spec/,
# scripts/, probes/, prototypes/ and no stray addons/ path.
#
# Run it in WSL. Needs bash >= 4.3, git, curl, unzip, zip and jq (sudo apt-get install zip jq);
# the packager builds the zip with zip and reads upload APIs with jq.
set -euo pipefail

case "${1:-}" in
	-h | --help)
		sed -n '2,17p' "$0"
		exit 0
		;;
	"") ;;
	*)
		echo "Unknown argument: $1" >&2
		exit 2
		;;
esac

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=tools.env
source "$root/scripts/tools.env"
releasedir="$root/.release"
packager="$root/.tools/packager/release-$PACKAGER_COMMIT.sh"

for tool in git curl unzip zip jq; do
	if ! command -v "$tool" >/dev/null; then
		echo "Missing '$tool'. Install it (sudo apt-get install $tool) and run again." >&2
		exit 1
	fi
done

if [[ ! -f $packager ]]; then
	mkdir -p "$(dirname "$packager")"
	curl -fsSL -o "$packager.part" \
		"https://raw.githubusercontent.com/BigWigsMods/packager/$PACKAGER_COMMIT/release.sh"
	if ! echo "$PACKAGER_RELEASE_SH_SHA256  $packager.part" | sha256sum -c --quiet -; then
		rm -f "$packager.part"
		echo "The downloaded packager $PACKAGER_VERSION doesn't match PACKAGER_RELEASE_SH_SHA256 in scripts/tools.env." >&2
		exit 1
	fi
	mv "$packager.part" "$packager"
fi

if [[ -n $(git -C "$root" status --porcelain) ]]; then
	echo "Note: uncommitted changes are not packaged; this builds HEAD." >&2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
src="$work/src"
git clone --quiet --no-checkout "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)" "$src"
git -C "$src" checkout --quiet --detach "$(git -C "$root" rev-parse HEAD)"

rm -rf "$releasedir"
mkdir -p "$releasedir"
bash "$packager" -d -t "$src" -r "$releasedir"

# --- check the zip -----------------------------------------------------------

zips=("$releasedir"/*.zip)
if [[ ${#zips[@]} -ne 1 || ! -f ${zips[0]} ]]; then
	echo "FAIL: expected exactly one zip in .release/, found: ${zips[*]}" >&2
	exit 1
fi
zipfile=${zips[0]}

expected="$work/expected.txt"
actual="$work/actual.txt"
{
	git -C "$src" ls-files -- 'addons/*' | sed 's#^addons/##'
	printf '%s\n' Pagle/CHANGELOG.md Pagle/LICENSE Pagle/NOTICE
} | LC_ALL=C sort >"$expected"
unzip -Z1 "$zipfile" | grep -v '/$' | LC_ALL=C sort >"$actual"

if ! diff -u --label expected --label "$(basename "$zipfile")" "$expected" "$actual"; then
	echo "FAIL: the zip's files differ from addons/ (see the diff above; fix .pkgmeta)." >&2
	exit 1
fi

if unzip -p "$zipfile" '*.toc' | grep -q '@project-version@'; then
	echo "FAIL: a TOC in the zip still says @project-version@." >&2
	exit 1
fi

echo "OK: $(basename "$zipfile") holds only $(cut -d/ -f1 "$actual" | sort -u | paste -sd' ' -)/, as built from addons/."
