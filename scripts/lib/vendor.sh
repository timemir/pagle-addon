# What scripts/update-ace3.sh and scripts/update-libdeflate.sh share, written once: vendoring a fixed list of files
# from one commit of a GitHub repo into a folder under addons/*/libs/, recording the commit, and writing the manifest
# the check gate's libs stage holds those files to (scripts/check.sh). Each script sets its own upstream, files and
# paths, then calls vendor_main with its arguments. Sourced, never run.
#
# Needs bash, curl, tar, cmp, diff and sha256sum (WSL or Git Bash; on macOS tools.sh stands shasum in for it).

# shellcheck source=tools.sh
source "$(dirname "${BASH_SOURCE[0]}")/tools.sh"

# vendor_sums <dir> <prefix> <file>...: sha256sum lines for each listed file in <dir>, sorted, each named by its path
# in the repo (<prefix>/<file>), so check.sh can run sha256sum --check on them from the repo root. Only the listed
# files: two libraries share addons/Pagle/libs/, and each manifest covers its own.
vendor_sums() {
	local dir=$1 prefix=$2
	shift 2
	(cd "$dir" && printf '%s\n' "$@" | LC_ALL=C sort | tr '\n' '\0' | xargs -0 sha256sum) | sed "s#  #  $prefix/#"
}

# vendor_main <name> <upstream> <root> <record> <manifest> <dest> <file>... -- <args>: the script's whole run.
#   <name>      the script's name, for its messages (update-ace3)
#   <upstream>  the GitHub repo, owner/name
#   <root>      the repo root
#   <record>    the file holding the vendored commit, from <root>
#   <manifest>  the sha256 manifest, from <root>
#   <dest>      the folder the files go into, from <root>
#   <file>...   the files to vendor, as paths in upstream's tree, which are also their paths under <dest>
#   <args>      the script's own arguments: none (re-vendor the recorded commit), a ref (vendor it and record its
#               commit), or --check (exit 1 unless <dest>'s files and the manifest match the recorded commit)
vendor_main() {
	local name=$1 upstream=$2 root=$3 record=$4 manifest=$5 dest=$6
	shift 6
	local files=()
	while [[ $# -gt 0 && $1 != -- ]]; do
		files+=("$1")
		shift
	done
	[[ ${1:-} == -- ]] && shift

	local mode=update ref=""
	case "${1:-}" in
	--check) mode=check ;;
	"") ;;
	*) ref=$1 ;;
	esac
	if [[ -z $ref ]]; then
		ref=$(tr -d '[:space:]' <"$root/$record")
	fi

	# Resolve any ref to its full commit hash.
	local commit
	commit=$(curl -fsSL -H "Accept: application/vnd.github.sha" "https://api.github.com/repos/$upstream/commits/$ref")
	if [[ ! $commit =~ ^[0-9a-f]{40}$ ]]; then
		echo "$name: could not resolve '$ref' in $upstream" >&2
		return 1
	fi

	local tmp
	tmp=$(mktemp -d)
	# shellcheck disable=SC2064 # $tmp is fixed now; the trap removes this run's folder
	trap "rm -rf '$tmp'" EXIT

	curl -fsSL "https://codeload.github.com/$upstream/tar.gz/$commit" -o "$tmp/src.tar.gz"
	mkdir "$tmp/src" "$tmp/libs"
	tar -xzf "$tmp/src.tar.gz" -C "$tmp/src" --strip-components=1

	local f
	for f in "${files[@]}"; do
		mkdir -p "$tmp/libs/$(dirname "$f")"
		cp "$tmp/src/$f" "$tmp/libs/$f"
	done

	if [[ $mode == check ]]; then
		local same=yes
		for f in "${files[@]}"; do
			cmp -s "$tmp/libs/$f" "$root/$dest/$f" || {
				echo "$name: $dest/$f differs from $upstream@$commit" >&2
				same=no
			}
		done
		if [[ $same == yes ]] &&
			diff -u --label "$manifest" --label "$upstream@$commit" "$root/$manifest" \
				<(vendor_sums "$tmp/libs" "$dest" "${files[@]}"); then
			echo "$name: $dest and $manifest match $upstream@$commit"
			return 0
		fi
		echo "$name: $dest or $manifest differs from $upstream@$commit; run scripts/$name.sh" >&2
		return 1
	fi

	# Each file's top folder under <dest> goes first (the file itself when it has none), so a file upstream dropped
	# goes too, and nothing else in <dest> is touched: another library may share it.
	for f in "${files[@]}"; do
		rm -rf "${root:?}/$dest/${f%%/*}"
	done
	mkdir -p "$root/$dest"
	cp -r "$tmp/libs/." "$root/$dest/"
	printf '%s\n' "$commit" >"$root/$record"
	vendor_sums "$root/$dest" "$dest" "${files[@]}" >"$root/$manifest"
	echo "$name: vendored $upstream@$commit into $dest and wrote $manifest"
}
