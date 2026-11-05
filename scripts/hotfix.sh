#!/usr/bin/env bash
# The hotfix path: one command from a committed fix to a tagged release and the backend's pin-bump pull request,
# each step waiting on the one before and stopping at the first failure. Every step is idempotent, so a run that
# stopped (a red check, a lost connection) is run again with the same arguments and picks up where it was.
#
#   scripts/hotfix.sh start <version>                # a hotfix/<version> branch off origin/main, with the
#                                                    # changelog's <version> section started for you to fill in
#   scripts/hotfix.sh ship <version> [--merge-bump]  # the committed branch: push, pull request, Check green, merge,
#                                                    # tag, Release workflow, then pagle-backend's pin-bump
#                                                    # workflow and its pull request's checks; --merge-bump merges
#                                                    # that too, which deploys (pagle-backend OPS-R12, OPS-R13)
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
#   6. Starts pagle-backend's pin-bump workflow (its PRJ-R66), which otherwise runs once a day, and waits for the
#      bump pull request's checks (its image fold check gates the bump, OPS-R11). With --merge-bump it merges that
#      pull request; main's run then promotes to production. Without it, the dev merges by hand.
#
# Needs gh 2.40 or later, signed in with push access to both repositories (the Mac's gh; WSL's 2.4 is too old), and
# git 2.38 or later. Run it from the hotfix branch's checkout or worktree. Set HOTFIX_BACKEND to point at another
# backend repository, for trying it out.
set -euo pipefail

addon=timemir/pagle-addon
backend=${HOTFIX_BACKEND:-timemir/pagle-backend}
bump_branch=wow-fish-pin-bump

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

# The pin-bump workflow's newest run, started by us: the newest run that began after <since>.
run_after() { # <repo> <workflow> <since, ISO 8601>
	local id i
	for ((i = 0; i < 36; i++)); do
		id=$(gh run list -R "$1" --workflow "$2" --limit 5 --json databaseId,createdAt \
			--jq "[.[] | select(.createdAt >= \"$3\")] | sort_by(.createdAt) | last | .databaseId // empty")
		[[ -z $id ]] || break
		sleep 5
	done
	[[ -n $id ]] || fail "no $2 run started in $1 after 3 minutes"
	echo "$id"
}

ship() {
	local version=$1 merge_bump=$2 branch
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
	local bump_pr title since
	bump_pr=$(gh pr list -R "$backend" --head "$bump_branch" --state open --json number,title --jq '.[0].number // empty')
	title=$(gh pr list -R "$backend" --head "$bump_branch" --state open --json number,title --jq '.[0].title // empty')
	if [[ -z $bump_pr || $title != *" $version" ]]; then
		since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
		gh workflow run -R "$backend" pin-bump.yml || fail "couldn't start pin-bump.yml in $backend"
		say "started pin-bump.yml in $backend"
		gh run watch -R "$backend" --exit-status "$(run_after "$backend" pin-bump "$since")" \
			|| fail "pin-bump.yml failed in $backend"
		bump_pr=$(gh pr list -R "$backend" --head "$bump_branch" --state open --json number,title \
			--jq ".[] | select(.title | endswith(\" $version\")) | .number" | head -n 1)
		[[ -n $bump_pr ]] || fail "pin-bump.yml opened no pull request for $version in $backend (was the Release seen as latest?)"
	fi
	say "the bump pull request is $backend#$bump_pr"
	checks_green "$backend" "$bump_pr"
	if [[ $merge_bump == yes ]]; then
		say "merging $backend#$bump_pr; its main run then promotes to production (OPS-R12)"
		gh pr merge -R "$backend" "$bump_pr" --squash || fail "couldn't merge $backend#$bump_pr"
		say "merged; watch https://github.com/$backend/actions and compare production's head with Clever Cloud's deployed commit (OPS-R13)"
	else
		say "the bump is green; review and merge https://github.com/$backend/pull/$bump_pr (or ship again with --merge-bump)"
	fi
}

# --- main

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
	merge_bump=no
	for arg in "$@"; do
		case $arg in
		--merge-bump) merge_bump=yes ;;
		*) usage ;;
		esac
	done
	ship "$version" "$merge_bump"
	;;
*) usage ;;
esac
