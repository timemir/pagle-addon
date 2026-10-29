#!/usr/bin/env bash
# Builds the release zip locally with the BigWigsMods packager, uploads off, then checks its contents.
# The release workflow (.github/workflows/release.yml) runs the same packager commit on a tag push:
# PACKAGER_COMMIT in scripts/tools.env, which scripts/check.sh holds the workflow to. There the zip also goes to
# the tag's GitHub Release (CORE-R74); here -d skips every upload, that one included.
#
#   scripts/package.sh             build .release/Pagle-<version>-forever.zip from HEAD and check it
#
# It packages the committed HEAD from a fresh clone, as the workflow packages the tagged commit,
# so commit first. (The packager also can't read a git worktree, whose .git is a file.)
# Before the first tag, @project-version@ becomes the short commit hash.
#
# The check: the zip's top-level folders are exactly the addons/<Addon>/ folders (Pagle and Pagle_QoL
# from M1, Pagle_Ledger from M2, Pagle_Hunts from M5, Pagle_Stats from M6, Pagle_TackleBoard from M7; each
# Module adds its own with its .pkgmeta move-folders line), each holding exactly that folder's tracked files
# (Pagle_QoL's Bindings.xml among them) but any .tga art source, plus the repo's LICENSE, NOTICE and
# CHANGELOG.md in Pagle/. Pagle/CHANGELOG.md must be the hand-written one (.pkgmeta's manual-changelog), not
# one the packager generated from the commits. Nothing else: no docs/, spec/, scripts/, probes/, prototypes/,
# data/, no stray addons/ path and no empty folder.
#
# Run it in WSL or on macOS. Needs bash >= 4.3 (the packager's), git, curl, unzip, zip and jq (sudo apt-get install
# zip jq); the packager builds the zip with zip and reads upload APIs with jq. macOS's own bash is 3.2, so there
# `brew install bash jq` and have Homebrew's bash first on PATH; zip and unzip ship with macOS. The packager is
# cached in the .tools/ that scripts/lib/tools.sh finds, so a worktree shares the main checkout's.
set -euo pipefail

case "${1:-}" in
	-h | --help)
		# The header comment: every line after the shebang up to the first that isn't a comment.
		awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
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
# shellcheck source=lib/tools.sh
source "$root/scripts/lib/tools.sh"
releasedir="$root/.release"
tools=$(tools_dir "$root")
packager="$tools/packager/release-$PACKAGER_COMMIT.sh"

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
# Without GITHUB_ACTIONS, so it runs in the Check workflow as it does locally: under Actions the packager skips a
# branch push whose commit carries a tag, which would leave no zip to check.
env -u GITHUB_ACTIONS bash "$packager" -d -t "$src" -r "$releasedir"

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
	git -C "$src" ls-files -- 'addons/*' | { grep -v '\.tga$' || true; } | sed 's#^addons/##'
	printf '%s\n' Pagle/CHANGELOG.md Pagle/LICENSE Pagle/NOTICE
} | LC_ALL=C sort >"$expected"
unzip -Z1 "$zipfile" | grep -v '/$' | LC_ALL=C sort >"$actual"

# One top-level folder per addon: a Module without its move-folders line lands under Pagle/addons/ instead.
want_tops=$(git -C "$src" ls-files -- 'addons/*' | cut -d/ -f2 | LC_ALL=C sort -u | paste -sd' ' -)
got_tops=$(unzip -Z1 "$zipfile" | cut -d/ -f1 | LC_ALL=C sort -u | paste -sd' ' -)
if [[ $got_tops != "$want_tops" ]]; then
	echo "FAIL: the zip's top-level folders are '$got_tops', expected '$want_tops', one per addons/ folder" \
		"(give each its .pkgmeta move-folders line)." >&2
	exit 1
fi

if ! diff -u --label expected --label "$(basename "$zipfile")" "$expected" "$actual"; then
	echo "FAIL: the zip's files differ from addons/ (see the diff above; fix .pkgmeta)." >&2
	exit 1
fi

# Folder entries: each must be a folder an expected file sits in, so an empty one (say Pagle/addons/) fails too.
awk -F/ '{ path = ""; for (i = 1; i < NF; i++) { path = path $i "/"; print path } }' "$expected" |
	LC_ALL=C sort -u >"$work/folders.txt"
stray=$(unzip -Z1 "$zipfile" | { grep '/$' || true; } | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$work/folders.txt")
if [[ -n $stray ]]; then
	echo "FAIL: the zip has folders that no file from addons/ is in (fix .pkgmeta):" >&2
	echo "$stray" >&2
	exit 1
fi

# The packager falls back to a generated changelog when the manual one is missing, under the same name.
# It writes text files with CRLF line endings, so compare without them.
if ! diff -u --label CHANGELOG.md --label "$(basename "$zipfile"):Pagle/CHANGELOG.md" \
	<(tr -d '\r' <"$src/CHANGELOG.md") <(unzip -p "$zipfile" Pagle/CHANGELOG.md | tr -d '\r'); then
	echo "FAIL: the zip's Pagle/CHANGELOG.md isn't the repo's CHANGELOG.md (see .pkgmeta's manual-changelog)." >&2
	exit 1
fi

if unzip -p "$zipfile" '*.toc' | grep -q '@project-version@'; then
	echo "FAIL: a TOC in the zip still says @project-version@." >&2
	exit 1
fi

# Exercise the shipped TOCs, startup and slash commands, rather than the development sources.
mkdir "$work/addons"
unzip -q "$zipfile" -d "$work/addons"
cd "$root"
PAGLE_RELEASE_ADDONS="$work/addons" "$tools/bin/busted" --pattern=recording.lua spec/release

echo "OK: $(basename "$zipfile") holds only ${got_tops// //, }/, as built from addons/."
