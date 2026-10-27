# What the scripts that run the pinned tools share, written once: where .tools/ is, a sha256sum on a Mac, and
# wait_any. Sourced,
# never run; plain bash 3.2 (macOS's /bin/bash) is enough.

# macOS has shasum, and a sha256sum (newer releases) without GNU's --quiet and --strict; shasum's -c, --quiet and
# --strict read and print as GNU's do.
if [[ $(uname -s) == Darwin ]]; then
	sha256sum() {
		shasum -a 256 "$@"
	}
fi

# tools_dir <root>: the .tools/ the scripts of the checkout at <root> run the pinned tools from (scripts/setup.sh):
#   1. $PAGLE_TOOLS, when set: an absolute path, taken as it is;
#   2. <root>/.tools, when scripts/setup.sh finished there (it writes tools.env last);
#   3. the main worktree's .tools, when <root> is a linked `git worktree` and the main checkout has one, so a
#      worktree needn't set up a toolchain of its own;
#   4. <root>/.tools anyway, which is where a message to run scripts/setup.sh points.
# Per-run files (luacov's stats, mypy's cache) stay in <root>/.tools/cache, whichever .tools/ the tools come from.
tools_dir() {
	local root=$1 common main
	if [[ -n ${PAGLE_TOOLS:-} ]]; then
		printf '%s\n' "$PAGLE_TOOLS"
		return
	fi
	if [[ ! -f $root/.tools/tools.env ]] && common=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null) &&
		[[ -n $common ]]; then
		[[ $common == /* ]] || common=$root/$common
		main=${common%/.git}
		if [[ $main != "$common" && -f $main/.tools/tools.env ]]; then
			printf '%s\n' "$main/.tools"
			return
		fi
	fi
	printf '%s\n' "$root/.tools"
}

# wait_any: returns once a background job has finished. bash 4.3 has `wait -n`; macOS's bash 3.2 polls instead.
wait_any() {
	if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))); then
		wait -n 2>/dev/null || true
	else
		local before
		before=$(jobs -pr | wc -l)
		while ((before > 0 && $(jobs -pr | wc -l) >= before)); do
			sleep 0.1
		done
		sleep 0.1
	fi
}
