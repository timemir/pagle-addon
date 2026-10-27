#!/usr/bin/env bash
# The check gate: runs every stage and fails at the first one, in the order below, that fails. Exit 0 means the tree
# passes.
#
#   scripts/check.sh
#   GATE_JOBS=8 scripts/check.sh    # busted shards at a time without coverage (default 4)
#
# A busted shard peaks near its largest spec file, under 1.5 GB, since spec/support/addon.lua lets each file's blocks
# go once it ends; before that, one shard kept every file it ran and spec/Pagle_Ledger's reached 12 GB, which shut down
# CI's 16 GB runner (exit 143). CI runs the default 4 shards at once too, on its 4 vCPUs.
#
# Needs the pinned tools in .tools/ (run scripts/setup.sh once). Runs locally in WSL, natively on macOS (bash 3.2 and
# up; every stage runs there too, so no stage is skipped) and in CI alike. A `git worktree` with no .tools/ of its own
# runs the main checkout's (scripts/lib/tools.sh), keeping only the coverage and mypy caches in its own .tools/cache/;
# PAGLE_TOOLS=<absolute path> names another .tools/.
#
# setup and libs run first, in turn, and stop the gate at once. The numbered stages then all run at the same time,
# each into its own log (#254). Their logs print in stage order, then each stage's wall time, then the verdict: the
# first failing stage in that order, whichever finished first, so a lint error that also breaks types fails at lint.
# Once the verdict is known, the stages still running are stopped and their logs left out.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
# shellcheck source=lib/tools.sh
source "$root/scripts/lib/tools.sh"
tools=$(tools_dir "$root")
export PAGLE_TOOLS=$tools
bin="$tools/bin"
started=$SECONDS

stage() {
	echo "==> $1"
}

fail() {
	echo "check: FAILED at $1" >&2
	exit 1
}

# The stages' logs, results and scratch (LuaLS's, the busted shards') live outside the repo, and go on any exit with
# whatever stage is still running.
logs=$(mktemp -d)
stages=(format lint api types tests generator)
pids=() # each stage's pid, at its place in stages
# Stops every stage without a result yet, with all it started: each runs in its own process group, named by its pid.
# A stage with a result is left alone, as its group may be gone and its number reused.
stop_stages() {
	local i
	for i in "${!stages[@]}"; do
		if [[ -n ${pids[i]:-} && ! -f $logs/${stages[i]}.result ]]; then
			kill -TERM -- "-${pids[i]}" 2>/dev/null || true
		fi
	done
}
cleanup() {
	stop_stages
	wait 2>/dev/null || true
	rm -rf "$logs"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# setup.sh keeps a copy of the pins it installed; any difference means .tools/ is missing or out of date.
if ! cmp -s scripts/tools.env "$tools/tools.env"; then
	echo "check: $tools doesn't match scripts/tools.env; run scripts/setup.sh" >&2
	fail setup
fi

# The release workflow's `uses:` line can't read tools.env, so its packager commit must equal PACKAGER_COMMIT.
# shellcheck source=tools.env
source scripts/tools.env
release_pins=$(grep -oE 'BigWigsMods/packager@[^[:space:]]*' .github/workflows/release.yml | sort -u)
if [[ $release_pins != "BigWigsMods/packager@$PACKAGER_COMMIT" ]]; then
	echo "check: .github/workflows/release.yml uses ${release_pins:-no BigWigsMods/packager}," \
		"but PACKAGER_COMMIT in scripts/tools.env is $PACKAGER_COMMIT; make them the same" >&2
	fail setup
fi

# The Lua the gate covers: every addon (minus vendored libs/, which the tool configs exclude), the specs,
# the scripts and the type stubs. probes/ and prototypes/ are throwaway experiments, never shipped or checked.
lua_dirs=()
for dir in addons spec scripts types; do
	[[ -d $dir ]] && lua_dirs+=("$dir")
done

# --- libs (#46), ahead of the numbered stages: the vendored libraries are exactly the files scripts/update-ace3.sh
# and scripts/update-libdeflate.sh vendored, byte for byte, as their manifests scripts/ace3.sha256 and
# scripts/libdeflate.sha256 record them. Offline: the manifests are in the repo, and each script's --check compares
# its files and manifest with upstream.
stage libs
lib_manifests=(scripts/ace3.sha256 scripts/libdeflate.sha256)
if ! cat "${lib_manifests[@]}" | sha256sum --check --quiet --strict >&2 ||
	! diff --label "${lib_manifests[*]}" --label addons/ \
		<(cat "${lib_manifests[@]}" | sed 's/^[0-9a-f]*  //' | LC_ALL=C sort) \
		<(find addons/*/libs -type f | LC_ALL=C sort) >&2; then
	echo "libs: addons/*/libs/ differs from ${lib_manifests[*]};" \
		"only scripts/update-ace3.sh and scripts/update-libdeflate.sh change it" >&2
	fail libs
fi
libs_time=$((SECONDS - started))

# Each numbered stage is one function, stage_<name>, that run_stage calls in the background. errexit doesn't reach
# into a function called with ||, so each of its commands ends in `|| return 1`.

# --- 1. format (#47): StyLua defaults, Lua 5.1 syntax (.stylua.toml); vendored libs skipped (.styluaignore).
stage_format() {
	"$bin/stylua" --check "${lua_dirs[@]}" || return 1
}

# --- 2. lint (#47): luacheck, Lua 5.1, no WoW globals outside adapter/ (CORE-R7), the WoW API inventory
# in .luacheckrc; vendored libs excluded there.
stage_lint() {
	"$bin/luacheck" --quiet --no-color "${lua_dirs[@]}" || return 1
}

# --- 3. api (#47): every inventoried WoW API is in the pinned forever dump (BIR_COMMIT in scripts/tools.env), and
# the inventory the addon ships for `/pagle dev probe` (addons/Pagle/data/ApiInventory.lua, #261) is .luacheckrc's.
stage_api() {
	"$bin/lua" scripts/api-presence.lua .luacheckrc "$tools/bir/Resources" || return 1
	"$bin/lua" scripts/api-inventory.lua --check .luacheckrc addons/Pagle/data/ApiInventory.lua || return 1
}

# --- 4. types (#48): lua-language-server --check, zero warnings, against Ketho's vscode-wow-api annotations
# (WOW_API_COMMIT in scripts/tools.env) and the types/ stubs; .luarc.json holds the setup. scripts/ is left out
# there: it runs on stock Lua 5.1, not in the WoW client the annotations describe.
stage_types() {
	# The one suppression allowed is inline, names its codes and gives a reason:
	#   ---@diagnostic disable-next-line: <code>[, <code>] -- <reason>
	# A file-wide disable, or one without a reason, fails. Vendored libs/ are not ours to change.
	if grep -rnE --include='*.lua' --exclude-dir=libs -e '---[[:space:]]*@diagnostic' "${lua_dirs[@]}" |
		grep -vE -e '^[^:]+:[0-9]+:[[:space:]]*---@diagnostic disable-next-line: [a-z-]+(, ?[a-z-]+)* -- [^[:space:]]' >&2; then
		echo "types: each suppression must be ---@diagnostic disable-next-line: <code> -- <reason>" >&2
		return 1
	fi
	# LuaLS's log and its generated meta files for the Lua builtins go outside the repo: .luarc.json ignores .tools/,
	# and meta files under an ignored dir leave even `integer` undefined.
	local luals="$logs/luals" luals_out luarc=.luarc.json luarc_text
	mkdir "$luals" || return 1
	# .luarc.json names the annotations at .tools/wow-api; with the tools of another checkout, a copy names theirs.
	if [[ $tools != "$root/.tools" ]]; then
		luarc=$luals/luarc.json
		luarc_text=$(<.luarc.json)
		printf '%s\n' "${luarc_text//\".tools\/wow-api\//\"$tools/wow-api/}" >"$luarc" || return 1
	fi
	if ! luals_out=$("$bin/lua-language-server" --check=. --checklevel=Warning --configpath="$luarc" \
		--logpath="$luals" --metapath="$luals/meta" --check_format=pretty 2>&1); then
		echo "$luals_out"
		return 1
	fi
	echo "types: no warnings"
}

# --- 5. tests (#49): busted on Lua 5.1, every spec/**/*_spec.lua. spec/support/addon.lua loads each addon from its
# real .toc, in order, so TOC and load-order mistakes fail specs. luacov then reports coverage of addons/ (.luacov);
# the report never gates. The specs tagged #slow (LOG-R66's 300,000-ID draw, make-test-log's level60 preset) run
# once, in a second pass without coverage, where they take a tenth of the time luacov's line hook gives them; a
# failing one fails the stage as any spec does.
# busted itself only ever exits 0 or 1, so a status over 128 means a signal killed it before the specs finished: it
# says nothing about them. On the dev's machine the coverage run has died of SIGSEGV that way, at instructions that
# can't fault (#149). Such a run gets one rerun, without coverage, which gates instead, and no report is made.
# PAGLE_NO_COVERAGE=1 skips luacov from the start: the specs gate the same, faster and in about half the memory, and
# run in shards at once (busted_shards). The agents' gate limiter sets it; a run without it reports coverage as before.
stage_tests() {
	rm -f .tools/cache/luacov.*.out # luacov adds to an existing stats file
	local coverage=yes status=0
	if [[ ${PAGLE_NO_COVERAGE:-0} == 1 ]]; then
		coverage=no
		busted_shards || return 1
	else
		"$bin/busted" --coverage --exclude-tags=slow || status=$?
	fi
	if ((status > 128)); then
		echo "tests: busted --coverage was killed by signal $((status - 128));" \
			"running the specs again without coverage (#149)" >&2
		coverage=no
		"$bin/busted" --exclude-tags=slow || return 1
	elif ((status != 0)); then
		return 1
	fi
	# Without coverage, busted_shards ran the #slow pass already.
	if [[ ${PAGLE_NO_COVERAGE:-0} != 1 ]]; then
		"$bin/busted" --tags=slow || return 1
	fi
	{ [[ $coverage == yes ]] && "$bin/luacov" && echo "coverage (reported, never gates):" &&
		sed -n '/^File /,$p' .tools/cache/luacov.report.out; } ||
		echo "check: no coverage report (coverage never gates)"
}

# Without coverage, busted runs once per directory in spec/ that holds specs, and once for the specs at the top of
# spec/, each without #slow, and the #slow pass is one more shard; GATE_JOBS run at a time (#254). Every shard's
# output prints after they all finish, in that order, then whether it passed and its wall time; any shard that
# doesn't pass fails tests. A coverage run stays one busted: luacov's stats file isn't shard-safe.
busted_shards() {
	local jobs=${GATE_JOBS:-4} shards=() dir i running=0 status took failed=0
	[[ $jobs =~ ^[1-9][0-9]*$ ]] || {
		echo "tests: GATE_JOBS must be a whole number from 1, not '$jobs'" >&2
		return 1
	}
	for dir in spec/*/; do
		[[ -n $(find "$dir" -name '*_spec*.lua' -print -quit) ]] && shards+=("${dir%/}")
	done
	[[ -n $(find spec -maxdepth 1 -name '*_spec*.lua' -print -quit) ]] && shards+=(spec)
	if ((${#shards[@]} == 0)); then
		echo "tests: no specs in spec/" >&2
		return 1
	fi
	shards+=("#slow")
	echo "tests: PAGLE_NO_COVERAGE=1, so the specs run without coverage, in ${#shards[@]} shards, $jobs at a time"
	mkdir "$logs/shards" || return 1
	for i in "${!shards[@]}"; do
		while ((running >= jobs)); do
			wait_any
			running=$(jobs -pr | wc -l)
		done
		# spec itself is the specs at its top: busted's own --no-recursive picks them, as its pattern would.
		{
			status=0 from=$SECONDS
			case ${shards[i]} in
			spec) "$bin/busted" --exclude-tags=slow --no-recursive spec || status=$? ;;
			"#slow") "$bin/busted" --tags=slow || status=$? ;;
			*) "$bin/busted" --exclude-tags=slow "${shards[i]}" || status=$? ;;
			esac
			echo "$status $((SECONDS - from))" >"$logs/shards/$i.status"
		} >"$logs/shards/$i.log" 2>&1 &
		running=$((running + 1))
	done
	wait
	for i in "${!shards[@]}"; do
		cat "$logs/shards/$i.log"
		read -r status took 2>/dev/null <"$logs/shards/$i.status" || status=none took=0
		if [[ $status == 0 ]]; then
			echo "tests: ${shards[i]} passed in ${took}s"
		else
			failed=1
			if [[ $status =~ ^[0-9]+$ ]] && ((status > 128)); then
				echo "tests: ${shards[i]} failed in ${took}s: busted was killed by signal $((status - 128))" >&2
			else
				echo "tests: ${shards[i]} failed in ${took}s" >&2
			fi
		fi
	done
	return "$failed"
}

# --- 6. generator (#55, DATA-R61): every generated file is what data/ gives (generate-data.py --check), the
# generator's pytest suite passes, and mypy --strict passes over the typed package (DATA-R60). scripts/pyproject.toml
# holds the pytest and mypy setup. No bytecode or caches in the tree: mypy's cache goes in .tools/cache/.
stage_generator() {
	export PYTHONDONTWRITEBYTECODE=1
	"$bin/python" scripts/generate-data.py --check || return 1
	"$bin/pytest" --quiet scripts/tests || return 1
	"$bin/mypy" --config-file scripts/pyproject.toml || return 1
}

# run_stage <name>: stage_<name> into its log; then its exit status and wall time, in that order, into its result.
run_stage() {
	local status=0 from=$SECONDS
	"stage_$1" >"$logs/$1.log" 2>&1 </dev/null || status=$?
	echo "$status $((SECONDS - from))" >"$logs/$1.result.part"
	mv "$logs/$1.result.part" "$logs/$1.result"
	echo "check: $1 completed in $((SECONDS - from))s (exit $status)"
}

# verdict: prints the first stage that failed, or pass, once every stage before that one has passed; fails while
# that's still open. A stage whose process is gone without a result failed.
verdict() {
	local i name result
	for i in "${!stages[@]}"; do
		name=${stages[i]}
		if ! kill -0 "${pids[i]}" 2>/dev/null && [[ ! -f $logs/$name.result ]]; then
			echo "1 0" >"$logs/$name.result"
			echo "$name: stopped without a result" >>"$logs/$name.log"
		fi
		[[ -f $logs/$name.result ]] || return 1
		read -r result _ <"$logs/$name.result"
		if [[ $result != 0 ]]; then
			echo "$name"
			return 0
		fi
	done
	echo pass
}

mkdir -p .tools/cache # luacov's stats and report, mypy's cache
echo "check: running ${stages[*]} at once"
# Job control only while they start: each stage gets its own process group, for stop_stages.
set -m
for i in "${!stages[@]}"; do
	run_stage "${stages[i]}" &
	pids[i]=$!
done
set +m
until failed_at=$(verdict); do
	wait_any
done
stop_stages

for name in "${stages[@]}"; do
	stage "$name"
	cat "$logs/$name.log"
	[[ $name != "$failed_at" ]] || break
done
times="libs ${libs_time}s"
for name in "${stages[@]}"; do
	if [[ -f $logs/$name.result ]]; then
		read -r _ took <"$logs/$name.result"
		times+=", $name ${took}s"
	else
		times+=", $name stopped"
	fi
done
echo "check: times: $times; $((SECONDS - started))s in all"
[[ $failed_at == pass ]] || fail "$failed_at"
echo "check: passed"
