#!/usr/bin/env bash
# Links each addons/* folder of this checkout into the game's Interface/AddOns folder, so edits go live after
# /reload. The macOS counterpart of scripts/link-addons.ps1 (docs/agents/in-game-verification.md > Linking the addons).
#
#   scripts/link-addons.sh <AddOns folder> [--source <addons folder>] [--unlink]
#   scripts/link-addons.sh <AddOns folder> --retail [--interface N] [--source <addons folder>] [--unlink]
#
# Without --retail (a Forever or beta install), each addon folder is symlinked whole, as the .ps1 junctions it.
#
# With --retail (a retail client, to check the UI there), the addons can't load as they are: their TOCs say
# `## Interface: 16001` and `## AllowLoadGameType: camelot`, and CORE-R2 keeps it so, with no per-flavour TOC in the
# repo. So each addon becomes a real folder holding a symlink to every top-level entry of its repo folder but the
# TOC, plus a generated <Addon>.toc: the repo's, with the retail client's interface number, `standard` (the
# retail game type) as the game type and `dev` for `@project-version@`. A subfolder is linked whole, so edits in it
# go live after /reload; a new top-level file or folder, or a changed TOC, needs this run again. The generated
# folder holds a .pagle-dev-link marker: it says the script owns the folder, and a folder without it is never touched.
#
# Core stops on a client that isn't Forever (CORE-R4), so Pagle's retail folder also gets a generated
# PagleRetailDev.lua, listed first in its TOC: it makes the check pass while Core's files load (WOW_PROJECT_CAMELOT
# is WOW_PROJECT_ID until Pagle's ADDON_LOADED, then as the client had it) and prints one chat line saying this is a
# dev link. Nothing of it is in the repo or a release.
#
# The interface number is --interface N, else the retail build's from the .build.info the Battle.net client keeps
# beside _retail_ (12.1.5.70575 is 120105), else 120105, and the script says which it used. Run it again after the
# client patches.
#
# Safe to run again: a link that already points at the source is left alone, one that points somewhere else (another
# checkout or worktree, or a folder since deleted) is re-pointed, and the TOCs are written again. A real folder or file
# with an addon's name is never touched; the script stops and names it. --source is the addons folder to link (the
# default is this checkout's), so a script run from a worktree can link the main checkout's addons.
#
# --unlink removes what a run made: the links (those to --source's addons), and a generated folder with its TOC and
# marker. A folder with other files in it is kept.
#
# Exits 0 on success, 1 when it stops on a folder it must not touch (or another failure), 2 on a usage error.
set -euo pipefail

marker=.pagle-dev-link
shim=PagleRetailDev.lua
default_retail_interface=120105
game_type=standard

usage() {
	cat >&2 <<-'EOF'
		usage: link-addons.sh <AddOns folder> [--retail [--interface N]] [--source <addons folder>] [--unlink]
	EOF
	exit 2
}

die() {
	echo "link-addons: $*" >&2
	exit 1
}

addons_path=
src=
retail=0
unlink=0
interface=
while (($# > 0)); do
	case $1 in
	--retail) retail=1 ;;
	--unlink) unlink=1 ;;
	--interface)
		(($# >= 2)) || usage
		interface=$2
		shift
		;;
	--source)
		(($# >= 2)) || usage
		src=$2
		shift
		;;
	-h | --help) usage ;;
	-*) usage ;;
	*)
		[[ -z $addons_path ]] || usage
		addons_path=$1
		;;
	esac
	shift
done
[[ -n $addons_path ]] || usage
if [[ -n $interface ]]; then
	((retail && !unlink)) || usage
	[[ $interface =~ ^[0-9]+$ ]] || usage
fi

[[ -d $addons_path ]] || die "AddOns folder not found: $addons_path (the client makes it at its first login, or mkdir -p it)"
addons_path=$(cd "$addons_path" && pwd -P)
[[ -n $src ]] || src=$(dirname "${BASH_SOURCE[0]}")/../addons
[[ -d $src ]] || die "addons folder not found: $src"
src=$(cd "$src" && pwd -P)

scratch=$(mktemp "${TMPDIR:-/tmp}/link-addons.XXXXXX")
chmod 644 "$scratch"
trap 'rm -f "$scratch"' EXIT

# Sets $interface and $interface_from, from --interface, the retail build in .build.info, or the default.
resolve_interface() {
	if [[ -n $interface ]]; then
		interface_from="--interface"
		return
	fi
	local retail_dir info version major minor patch
	retail_dir=$(dirname "$(dirname "$addons_path")")
	for info in "$retail_dir/.build.info" "$(dirname "$retail_dir")/.build.info"; do
		[[ -f $info ]] || continue
		version=$(awk -F'|' '
			NR == 1 {
				for (i = 1; i <= NF; i++) {
					split($i, field, "!")
					if (field[1] == "Version") v = i
					if (field[1] == "Product") p = i
				}
				next
			}
			p && v && $p == "wow" { print $v; exit }' "$info")
		if [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\. ]]; then
			major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
			interface=$((10#$major * 10000 + 10#$minor * 100 + 10#$patch))
			interface_from="$info: retail build $version"
			return
		fi
	done
	interface=$default_retail_interface
	interface_from="the default: no retail build in a .build.info beside $retail_dir; --interface N sets it"
}

# Writes the retail TOC for the repo TOC $1 to stdout, with the file $2 (if any) listed before the first file.
generate_toc() {
	awk -v interface="$interface" -v game_type="$game_type" -v shim="$2" '
		BEGIN { print "# Generated by scripts/link-addons.sh --retail from the repo TOC. Do not edit; run the script again." }
		/^## Interface:/ { print "## Interface: " interface; seen_interface = 1; next }
		/^## AllowLoadGameType:/ { print "## AllowLoadGameType: " game_type; seen_game_type = 1; next }
		shim != "" && !listed && !/^#/ && !/^[[:space:]]*$/ { print shim; listed = 1 }
		{ gsub(/@project-version@/, "dev"); print }
		END { if (!seen_interface || !seen_game_type || (shim != "" && !listed)) exit 3 }' "$1"
}

# Writes the dev shim for Pagle's retail folder to stdout. Core's CORE-R4 check reads WOW_PROJECT_ID and
# WOW_PROJECT_CAMELOT as its first adapter file loads; nothing else in addons/ reads either but /pagle dev probe, which
# should see the client's own values. So the override stands only until Pagle's ADDON_LOADED.
generate_shim() {
	cat <<'LUA'
-- Generated by scripts/link-addons.sh --retail for UI checks on the retail client only. Never shipped.
-- Makes Core's CORE-R4 check pass while Pagle's files load, then puts WOW_PROJECT_CAMELOT back as the client had it.
local addonName = ...

local camelot = WOW_PROJECT_CAMELOT
WOW_PROJECT_CAMELOT = WOW_PROJECT_ID

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, loadedName)
	if loadedName ~= addonName then
		return
	end
	self:UnregisterAllEvents()
	WOW_PROJECT_CAMELOT = camelot
	print("Pagle: retail UI-check build (dev link) — game data is Forever's; some things won't work.")
end)
LUA
}

# Makes $2 a symlink to $1 and sets $placed to ok, linked or relinked. A real file or folder at $2 stops the script.
place_link() {
	local target=$1 link=$2
	if [[ -L $link ]]; then
		if [[ $(readlink "$link") == "$target" ]]; then
			placed=ok
			return
		fi
		rm "$link"
		ln -s "$target" "$link"
		placed=relinked
	elif [[ -e $link ]]; then
		die "$link exists and is not a symlink. Move it out of the way, then run this again."
	else
		ln -s "$target" "$link"
		placed=linked
	fi
}

# Whether $1 is a folder this script generated: a real folder (not a link) holding the marker.
is_generated() {
	[[ ! -L $1 && -d $1 && -f $1/$marker ]]
}

# Removes the generated folder $1 of addon $2: its links, its TOC and its marker. A folder with other files left in
# it is kept, with its marker, and the return is 1.
remove_generated() {
	local dir=$1 name=$2 item
	for item in "$dir"/*; do
		if [[ -L $item ]]; then
			rm "$item"
		fi
	done
	rm -f "$dir/$name.toc" "$dir/$shim"
	for item in "$dir"/* "$dir"/.[!.]*; do
		if [[ (-e $item || -L $item) && ${item##*/} != "$marker" ]]; then
			return 1
		fi
	done
	rm "$dir/$marker"
	rmdir "$dir"
}

link_whole() {
	local name=$1 link=$addons_path/$1
	if is_generated "$link"; then
		remove_generated "$link" "$name" || die "$link was generated by --retail and holds other files. Move them out, then run this again."
		place_link "$src/$name" "$link"
		placed=relinked
	else
		place_link "$src/$name" "$link"
	fi
	printf '%-8s %s -> %s\n' "$placed" "$name" "$src/$name"
}

link_retail() {
	local name=$1 srcdir=$src/$1 dir=$addons_path/$1
	local created=0 repointed=0 changes=0 links=0 entry base item
	[[ -f $srcdir/$name.toc ]] || die "$srcdir/$name.toc not found"
	local shim_file=
	if [[ $name == Pagle ]]; then
		[[ ! -e $srcdir/$shim ]] || die "$srcdir/$shim exists; the script writes a file of that name into the retail folder"
		shim_file=$shim
	fi

	if [[ -L $dir ]]; then
		rm "$dir"
		repointed=1
	fi
	if [[ ! -e $dir ]]; then
		mkdir "$dir"
		((repointed)) || created=1
	elif ! is_generated "$dir"; then
		die "$dir exists and this script did not create it. Move it out of the way, then run this again."
	fi

	printf '%s\nsource=%s\n' "Generated by scripts/link-addons.sh --retail. --unlink removes this folder." "$srcdir" >"$scratch"
	if ! cmp -s "$scratch" "$dir/$marker"; then
		cp "$scratch" "$dir/$marker"
		changes=1
	fi

	for entry in "$srcdir"/*; do
		[[ -e $entry ]] || continue
		base=${entry##*/}
		[[ $base == *.toc ]] && continue
		place_link "$entry" "$dir/$base"
		links=$((links + 1))
		case $placed in
		linked) changes=1 ;;
		relinked) repointed=1 ;;
		esac
	done

	for item in "$dir"/*; do
		[[ -L $item ]] || continue
		base=${item##*/}
		if [[ ! -e $srcdir/$base || $base == *.toc ]]; then
			rm "$item"
			changes=1
		fi
	done

	if [[ -n $shim_file ]]; then
		generate_shim >"$scratch"
		if ! cmp -s "$scratch" "$dir/$shim"; then
			cp "$scratch" "$dir/$shim"
			changes=1
		fi
	fi

	generate_toc "$srcdir/$name.toc" "$shim_file" >"$scratch" || die "$srcdir/$name.toc lacks a ## Interface or ## AllowLoadGameType line (CORE-R2), or a file to list"
	if ! cmp -s "$scratch" "$dir/$name.toc"; then
		cp "$scratch" "$dir/$name.toc"
		changes=1
	fi

	local verb=ok
	if ((created)); then
		verb=linked
	elif ((repointed)); then
		verb=relinked
	elif ((changes)); then
		verb=updated
	fi
	printf '%-8s %s -> %s (retail: %d links, generated %s.toc%s)\n' "$verb" "$name" "$srcdir" "$links" "$name" "${shim_file:+ and $shim_file}"
}

unlink_addon() {
	local name=$1 dir=$addons_path/$1 target
	if [[ -L $dir ]]; then
		target=$(readlink "$dir")
		if [[ $target == "$src/$name" ]]; then
			rm "$dir"
			printf '%-8s %s\n' removed "$name"
		else
			printf '%-8s %s (a link to %s, not to this source; --source says which to remove)\n' kept "$name" "$target"
		fi
	elif is_generated "$dir"; then
		if remove_generated "$dir" "$name"; then
			printf '%-8s %s\n' removed "$name"
		else
			printf '%-8s %s (a generated folder with other files in it)\n' kept "$name"
		fi
	elif [[ -e $dir ]]; then
		printf '%-8s %s (this script did not create it)\n' kept "$name"
	else
		printf '%-8s %s\n' absent "$name"
	fi
}

if ((retail && !unlink)); then
	resolve_interface
	echo "interface $interface ($interface_from)"
fi

for addon in "$src"/*/; do
	[[ -d $addon ]] || continue
	name=$(basename "$addon")
	if ((unlink)); then
		unlink_addon "$name"
	elif ((retail)); then
		link_retail "$name"
	else
		link_whole "$name"
	fi
done
