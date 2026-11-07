#!/usr/bin/env bash
# The hotfix path: one command from a committed fix to a tagged release and the backend's pin bump,
# each step waiting on the one before and stopping at the first failure. Every step is idempotent, so a run that
# stopped (a red check, a lost connection) is run again with the same arguments and picks up where it was.
#
#   scripts/hotfix.sh start <version>                # a hotfix/<version> branch off origin/main, with the
#                                                    # changelog's <version> section started for you to fill in
#   scripts/hotfix.sh ship <version>                 # the committed branch: push, pull request, Check green, merge,
#                                                    # tag, Release workflow, then pagle-backend's local pin bump
#
# What ship does, in order, and what it won't do:
#   1. The changelog's first section must be `## <version> (<date>)`, finished (no {placeholder} left): the
#      release's notes come from it (CORE-R74), and this is what makes the fix and its changelog one pull request
#      and one Check run, instead of a release commit of its own.
#   2. Pushes the branch and opens the pull request (or finds the open one), then waits for its checks.
#   3. Merges it as a squash, so main's new tree is the very tree the pull request's run tested. A newer push cancels
#      a running Check (check.yml's concurrency), so only a green, finished run gets here.
#   4. Tags main's new commit <version> when that tree was tested: check.yml's `tested` job leaves an artifact named
#      tested-tree-<tree sha> for every green pull request run. When main moved in between (another merge), the tree
#      is new and the script waits for main's own Check run of it instead. Never moves or deletes a tag.
#   5. Waits for the Release workflow (release.yml) and checks the GitHub Release has its one zip: players can
#      download from here.
#   6. The backend's pin bump. pagle-backend's CI runs locally while its Actions minutes are off (its OPS-R9), so its
#      pin-bump workflow doesn't run. With HOTFIX_BACKEND_DIR set to a pagle-backend checkout, this runs that
#      checkout's ci/local-pin-bump.sh (its PRJ-R66), which opens or updates the bump pull request and runs the
#      backend's local CI on it, the image fold check included (its OPS-R11); without it, this prints the commands
#      for the Operator. Either way it stops there, with the add-on released: merging the bump, and deploying it with
#      the backend's ci/local-promote.sh (its OPS-R12), stay the Operator's. It says what the pin bump did, from the
#      `local-pin-bump: outcome=` line the backend ends with (or, from an older backend checkout, its GREEN, RED and
#      "nothing to do" lines): GREEN with the pull request, RED, the pin at this version already, the pin left on a
#      commit (its OPS-R131), or a new ranked policy needed first (its TRU-R72). RED and the new policy stop it red.
#
# Needs gh 2.40 or later, signed in with push access to both repositories (the Mac's gh; WSL's 2.4 is too old), and
# git 2.38 or later. Run it from the hotfix branch's checkout or worktree. Step 6 also needs what the backend's local
# CI needs: Docker, and bash 4 or later on PATH.
set -euo pipefail

addon=timemir/pagle-addon

say() {
	echo "hotfix: $*"
}

fail() {
	echo "hotfix: $*" >&2
	exit 1
}

usage() {
	awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0" >&2
	exit 2
}

version_ok() { # <version>: the bare version a tag is (release.yml)
	[[ $1 =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

gh_ok() {
	command -v gh >/dev/null || fail "gh isn't installed"
	local v
	v=$(gh --version | sed -n 's/^gh version \([0-9.]*\).*/\1/p')
	[[ -n $v ]] || fail "couldn't read gh's version"
	local major=${v%%.*} minor=${v#*.}
	minor=${minor%%.*}
	((major > 2 || (major == 2 && minor >= 40))) || fail "gh $v is too old; 2.40 or later (the Mac's, not WSL's)"
}

# --- start

start() {
	local version=$1 branch="hotfix/$1"
	git fetch --quiet origin main
	if git show-ref --verify --quiet "refs/heads/$branch"; then
		say "$branch exists; switching to it"
		git switch --quiet "$branch"
	else
		git switch --quiet -c "$branch" origin/main
	fi
	if grep -q "^## $version (" CHANGELOG.md; then
		say "CHANGELOG.md has its $version section"
	else
		local today
		today=$(date +%Y-%m-%d)
		# The section goes under the title, above the last release's.
		awk -v v="$version" -v d="$today" 'NR == 1 { print; print ""; print "## " v " (" d ")"; print "";
			print "### Fixed"; print ""; print "- {what a player saw, in a player'\''s words} (#{n})"; next } { print }' \
			CHANGELOG.md >CHANGELOG.md.new
		mv CHANGELOG.md.new CHANGELOG.md
		say "started CHANGELOG.md's $version section; fill it in (ship refuses a {placeholder})"
	fi
	say "on $branch; write the fix, commit it with the changelog, then: scripts/hotfix.sh ship $version"
}

# --- ship

# The changelog's first section is this version's and is finished.
changelog_ok() { # <version>
	local first
	first=$(grep -m1 '^## ' CHANGELOG.md || true)
	[[ $first == "## $1 ("* ]] || fail "CHANGELOG.md's first section is '${first:-none}', not '## $1 (<date>)'"
	if awk '/^## /{ n++ } n == 1' CHANGELOG.md | grep -q '{'; then
		fail "CHANGELOG.md's $1 section still has a {placeholder}"
	fi
}

# The number of the branch's open pull request onto main, opened if there is none.
pull_request() { # <branch>
	local pr
	pr=$(gh pr list -R "$addon" --head "$1" --base main --state open --json number --jq '.[0].number // empty')
	if [[ -z $pr ]]; then
		local subject body
		subject=$(git log -1 --format=%s)
		body=$(git log -1 --format=%b)
		pr=$(gh pr create -R "$addon" --base main --head "$1" --title "$subject" \
			--body "$body"$'\n\n'"A hotfix, shipped by scripts/hotfix.sh: its changelog section is in this pull request, and its merge commit is tagged once this run is green." \
			| sed -n 's#.*/pull/\([0-9][0-9]*\)$#\1#p')
		[[ -n $pr ]] || fail "couldn't open the pull request"
		say "opened pull request #$pr" >&2
	fi
	echo "$pr"
}

# Waits for the pull request's checks, which may take a moment to appear after a push.
checks_green() { # <repo> <pr>
	local i out
	for ((i = 0; i < 24; i++)); do
		out=$(gh pr checks -R "$1" "$2" 2>&1 || true)
		[[ $out == *"no checks reported"* ]] || break
		sleep 5
	done
	say "waiting for $1#$2's checks"
	gh pr checks -R "$1" "$2" --watch --fail-fast || fail "$1#$2 has a failed check; fix it, push, and ship again"
}

# Whether a green pull request run tested this tree: check.yml's tested job leaves tested-tree-<sha>.
tree_tested() { # <tree sha>
	local n
	n=$(gh api "repos/$addon/actions/artifacts?name=tested-tree-$1&per_page=100" \
		--jq '[.artifacts[] | select(.expired | not)] | length' 2>/dev/null || echo 0)
	[[ $n != 0 ]]
}

# The id of the workflow's newest run on this commit, waiting for one to appear.
run_on_commit() { # <repo> <workflow> <sha>
	local id i
	for ((i = 0; i < 36; i++)); do
		id=$(gh run list -R "$1" --workflow "$2" --commit "$3" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
		[[ -z $id ]] || break
		sleep 5
	done
	[[ -n $id ]] || fail "no $2 run on $3 in $1 after 3 minutes"
	echo "$id"
}

ship() {
	local version=$1 branch
	gh_ok
	branch=$(git branch --show-current)
	[[ -n $branch && $branch != main ]] || fail "run ship from the hotfix branch, not from ${branch:-a detached HEAD}"
	[[ -z $(git status --porcelain) ]] || fail "the working tree has uncommitted changes; commit them first"
	changelog_ok "$version"
	git fetch --quiet origin main "+refs/tags/*:refs/tags/*"

	# 2. The pull request, pushed and green.
	local merged
	merged=$(gh pr list -R "$addon" --head "$branch" --base main --state merged --json mergeCommit --jq '.[0].mergeCommit.oid // empty')
	if [[ -z $merged ]]; then
		git push --quiet -u origin "HEAD:refs/heads/$branch"
		local pr
		pr=$(pull_request "$branch")
		checks_green "$addon" "$pr"
		# 3. The merge: a squash, so main's new tree is the tested merge tree when main didn't move.
		say "merging #$pr"
		# No --delete-branch: gh would check main out here too, which fails in a worktree that has it elsewhere.
		gh pr merge -R "$addon" "$pr" --squash || fail "couldn't merge #$pr"
		merged=$(gh pr view -R "$addon" "$pr" --json mergeCommit --jq '.mergeCommit.oid')
		[[ -n $merged ]] || fail "#$pr merged but has no merge commit"
		git push --quiet origin --delete "$branch" 2>/dev/null || true
	else
		say "the branch's pull request is merged already, as $merged"
	fi
	git fetch --quiet origin main
	git merge-base --is-ancestor "$merged" origin/main || fail "$merged isn't on main"

	# 4. The tag, on a tested tree.
	if git rev-parse --verify --quiet "refs/tags/$version^{commit}" >/dev/null; then
		local tagged
		tagged=$(git rev-parse "refs/tags/$version^{commit}")
		[[ $tagged == "$merged" ]] || fail "tag $version is on $tagged, not on $merged; a tag is never moved"
		say "tag $version is on $merged already"
	else
		local tree
		tree=$(git rev-parse "$merged^{tree}")
		if tree_tested "$tree"; then
			say "a green pull request run tested $merged's tree; tagging now"
		else
			say "main moved since the pull request's run, so its tree is new; waiting for main's Check run of $merged"
			gh run watch -R "$addon" --exit-status "$(run_on_commit "$addon" Check "$merged")" \
				|| fail "main's Check run of $merged failed"
		fi
		git tag "$version" "$merged"
		git push --quiet origin "refs/tags/$version"
		say "pushed tag $version on $merged"
	fi

	# 5. The Release workflow and its zip.
	local release
	release=$(run_on_commit "$addon" Release "$merged")
	say "waiting for the Release workflow (run $release)"
	gh run watch -R "$addon" --exit-status "$release" || fail "the Release workflow failed; re-run it on the same tag"
	local zips
	zips=$(gh release view -R "$addon" "$version" --json assets --jq '[.assets[] | select(.name | endswith(".zip"))] | length')
	[[ $zips == 1 ]] || fail "the $version Release has $zips zip assets, not one"
	say "Release $version is published; players can download it"

	# 6. The backend's pin bump.
	backend_bump "$version"
}

# --- 6. the backend's pin bump, local while its Actions minutes are off (pagle-backend OPS-R9, PRJ-R66)

# What ci/local-pin-bump.sh did, as `<outcome> [key=value]...`, from the transcript of a backend checkout that
# predates its outcome line: its GREEN, RED and "nothing to do" lines.
legacy_outcome() { # <transcript> <exit status>
	local n pin
	n=$(sed -n 's/^local-pin-bump: GREEN: pull request #\([0-9][0-9]*\).*/\1/p' "$1" | tail -n 1)
	[[ -z $n ]] || { echo "green pr=$n"; return; }
	n=$(sed -n 's/^local-pin-bump: RED: pull request #\([0-9][0-9]*\).*/\1/p' "$1" | tail -n 1)
	[[ -z $n ]] || { echo "red pr=$n"; return; }
	if (($2 == 0)); then
		if grep -q '^pin-bump: the pin names a wow-fish commit' "$1"; then
			echo "commit-pin-by-hand"
			return
		fi
		pin=$(sed -n 's/^pin-bump: .* is not newer than the pinned \([^ ;]*\); nothing to do$/\1/p' "$1" | tail -n 1)
		[[ -z $pin ]] || { echo "up-to-date pin=$pin"; return; }
		if grep -q '^pin-bump: .* has no Release yet' "$1"; then
			echo "no-release"
			return
		fi
		echo "unknown"
	else
		echo "failed"
	fi
}

# The value of <key> in an outcome's key=value details, empty when it has none.
outcome_value() { # <key> <outcome>
	local word
	for word in $2; do
		[[ $word != "$1="* ]] || { echo "${word#*=}"; return 0; }
	done
	return 0
}

backend_bump() { # <version>
	local version=$1
	if [[ -z ${HOTFIX_BACKEND_DIR:-} ]]; then
		say "$version is released. pagle-backend's CI runs locally, so its pin bump is the Operator's, in a pagle-backend checkout:"
		say "  ci/local-pin-bump.sh                 # opens the bump pull request and runs local CI on it"
		say "  ci/local-promote.sh <merge commit>   # after merging it by hand: deploys it"
		say "or set HOTFIX_BACKEND_DIR to that checkout and ship $version again: the steps before this one are done"
		return
	fi
	[[ -x $HOTFIX_BACKEND_DIR/ci/local-pin-bump.sh ]] \
		|| fail "HOTFIX_BACKEND_DIR ($HOTFIX_BACKEND_DIR) has no ci/local-pin-bump.sh; $version is released, bump the backend by hand"
	say "running pagle-backend's local pin bump in $HOTFIX_BACKEND_DIR; its local CI takes a while"
	local transcript status result
	transcript=$(mktemp)
	set +e
	(cd "$HOTFIX_BACKEND_DIR" && ci/local-pin-bump.sh) 2>&1 | tee "$transcript"
	status=${PIPESTATUS[0]}
	set -e
	result=$(sed -n 's/^local-pin-bump: outcome=//p' "$transcript" | tail -n 1)
	[[ -n $result ]] || result=$(legacy_outcome "$transcript" "$status")
	rm -f "$transcript"
	local pr pin release
	pr=$(outcome_value pr "$result")
	pin=$(outcome_value pin "$result")
	release=$(outcome_value release "$result")
	case ${result%% *} in
	green)
		say "$version is released and pagle-backend's bump pull request #$pr passed its local CI"
		say "next, the Operator's: review and merge #$pr by hand, then in $HOTFIX_BACKEND_DIR run ci/local-promote.sh <merge commit>"
		;;
	red)
		fail "$version is released, but pagle-backend's bump pull request #$pr failed its local CI (above); fix it there, then run ci/local-pin-bump.sh again"
		;;
	up-to-date)
		say "$version is released; pagle-backend's pin is at ${pin:-$version} already, so there is no bump to make"
		;;
	commit-pin)
		say "$version is released; pagle-backend's pin stays on the wow-fish commit $pin, which ${release:-$version} doesn't hold (its OPS-R131), so no bump pull request was opened"
		say "a commit pin moves to the tag of the release that holds it; until then there is nothing to bump"
		;;
	commit-pin-by-hand)
		say "$version is released, but pagle-backend's pin is in commit form and this checkout's ci/local-pin-bump.sh doesn't move it, so no bump pull request was opened"
		say "next, the Operator's: make the tag-form pin by hand (as pagle-backend#417 and #429 were), or run ci/local-pin-bump.sh from a pagle-backend checkout of main that has pagle-backend#430, which writes it"
		;;
	policy-needed)
		fail "$version is released, but it changes a file pagle-backend's ranked policy hashes after the pinned commit $pin, so the pin stays: a new ranked policy is needed first (its OPS-R131, TRU-R72)"
		;;
	no-release)
		fail "pagle-backend's pin bump saw no pagle-addon Release, though $version is published; run ci/local-pin-bump.sh there again"
		;;
	unknown)
		say "$version is released; pagle-backend's local pin bump finished without saying what it did (above): check its bump pull request by hand"
		;;
	*)
		fail "the backend's local pin bump failed (above); $version is released, so run ci/local-pin-bump.sh there again once fixed"
		;;
	esac
}

# --- main

# Sourced (by scripts/tests/test_hotfix.py), it only defines the functions.
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

(($# >= 2)) || usage
command=$1
version=$2
shift 2
version_ok "$version" || fail "'$version' isn't a bare version like 1.0.2"
case $command in
start)
	(($# == 0)) || usage
	start "$version"
	;;
ship)
	for arg in "$@"; do
		case $arg in
		--merge-bump) fail "--merge-bump is gone while pagle-backend's CI is local: merge the bump by hand, then run its ci/local-promote.sh" ;;
		*) usage ;;
		esac
	done
	ship "$version"
	;;
*) usage ;;
esac
