#!/usr/bin/env bash
# Installs the pinned toolchain (scripts/tools.env) into .tools/, the repo-local, gitignored prefix
# scripts/check.sh runs from. Non-interactive and re-runnable: a component whose pin hasn't changed is skipped,
# and a changed pin reinstalls just that component. Re-run it after moving the clone (LuaRocks hardcodes paths).
#
#   scripts/setup.sh
#
# Runs in WSL Ubuntu (or any x86_64 Linux) as a normal user. Its only prerequisites are the apt packages
# SETUP_APT_PACKAGES in scripts/tools.env, which the Check workflow (.github/workflows/check.yml) installs too.
#
# Layout:
#   .tools/lua/       Lua 5.1, LuaRocks and the rocks (luacheck, busted, luacov and its C hook cluacov)
#   .tools/stylua/    StyLua
#   .tools/luals/     lua-language-server
#   .tools/bir/       Ketho BlizzardInterfaceResources forever dump, Resources/ only
#   .tools/wow-api/   Ketho vscode-wow-api, Annotations/Core only
#   .tools/python/    uv, the CPython it installs (cpython/) and the venv holding PYTHON_PACKAGES (venv/)
#   .tools/bin/       one link per tool: lua luarocks luacheck busted luacov stylua lua-language-server
#                     python pytest mypy
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=tools.env
source "$root/scripts/tools.env"
tools="$root/.tools"

missing=()
for cmd in gcc make unzip curl tar sha256sum; do
	command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if ((${#missing[@]})); then
	echo "setup: missing ${missing[*]}; run: sudo apt-get install -y $SETUP_APT_PACKAGES" >&2
	exit 1
fi

mkdir -p "$tools/bin"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Runs a command with its output kept out of the way, showing it only on failure.
quiet() {
	if ! "$@" >"$tmp/log" 2>&1; then
		cat "$tmp/log" >&2
		echo "setup: failed: $*" >&2
		exit 1
	fi
}

# fetch <url> <out> [sha256]: downloads <url>, verifying its checksum when one is given.
fetch() {
	curl -fsSL --retry 3 -o "$2" "$1"
	if [[ -n ${3:-} ]] && ! echo "$3  $2" | sha256sum -c --quiet - >/dev/null 2>&1; then
		echo "setup: checksum mismatch for $1" >&2
		exit 1
	fi
}

# stale <component> <key>: true when the component must be (re)installed, after emptying its folder. Its stamp
# records the key it was installed with and is written only once the install has finished, so an interrupted run
# starts it over. Callers run it as an `if` condition, where set -e is off, so a failed reset exits explicitly:
# returning false would read as "up to date".
stale() {
	local stamp="$tools/.stamp-$1"
	if [[ -f $stamp && $(<"$stamp") == "$2" ]]; then
		echo "setup: $1 is up to date"
		return 1
	fi
	echo "setup: installing $1"
	if ! { rm -f "$stamp" && rm -rf "${tools:?}/$1" && mkdir -p "$tools/$1"; }; then
		echo "setup: can't empty .tools/$1 to reinstall it" >&2
		exit 1
	fi
}

stamp() {
	printf '%s\n' "$2" >"$tools/.stamp-$1"
}

# Lua 5.1, LuaRocks and the rocks: one component, since rocks are built against that Lua and LuaRocks.
# Unquoted on purpose: word splitting folds the multi-line list onto one line, so the key stays one line.
# shellcheck disable=SC2086
rocks=$(echo $LUA_ROCKS)
key="lua $LUA_VERSION $LUA_SHA256 luarocks $LUAROCKS_VERSION $LUAROCKS_SHA256 rocks $rocks prefix $tools"
if stale lua "$key"; then
	prefix="$tools/lua"
	fetch "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz" "$tmp/lua.tar.gz" "$LUA_SHA256"
	tar -xzf "$tmp/lua.tar.gz" -C "$tmp"
	# POSIX with dlopen (so C rocks load) and no readline; -Wl,-E exports the Lua API to those rocks.
	quiet make -C "$tmp/lua-$LUA_VERSION/src" all MYCFLAGS="-DLUA_USE_POSIX -DLUA_USE_DLOPEN" MYLIBS="-Wl,-E -ldl"
	quiet make -C "$tmp/lua-$LUA_VERSION" install INSTALL_TOP="$prefix"

	fetch "https://luarocks.github.io/luarocks/releases/luarocks-$LUAROCKS_VERSION.tar.gz" "$tmp/luarocks.tar.gz" "$LUAROCKS_SHA256"
	tar -xzf "$tmp/luarocks.tar.gz" -C "$tmp"
	# --force-config: ignore any user-level LuaRocks config, so the rocks tree is this prefix.
	(cd "$tmp/luarocks-$LUAROCKS_VERSION" &&
		quiet ./configure --prefix="$prefix" --with-lua="$prefix" --lua-version=5.1 --force-config &&
		quiet make &&
		quiet make install)

	while read -r name version; do
		[[ -n $name ]] || continue
		echo "setup:   rock $name $version"
		quiet "$prefix/bin/luarocks" install "$name" "$version"
	done <<<"$LUA_ROCKS"

	installed=$("$prefix/bin/luarocks" list --porcelain | awk '{ print $1, $2 }' | sort)
	pinned=$(awk 'NF { print $1, $2 }' <<<"$LUA_ROCKS" | sort)
	if [[ $installed != "$pinned" ]]; then
		echo "setup: the installed rocks differ from LUA_ROCKS in scripts/tools.env:" >&2
		diff <(echo "$pinned") <(echo "$installed") >&2 || true
		exit 1
	fi
	stamp lua "$key"
fi

key="stylua $STYLUA_VERSION $STYLUA_SHA256"
if stale stylua "$key"; then
	fetch "https://github.com/JohnnyMorganz/StyLua/releases/download/v$STYLUA_VERSION/stylua-linux-x86_64-musl.zip" \
		"$tmp/stylua.zip" "$STYLUA_SHA256"
	quiet unzip -o "$tmp/stylua.zip" -d "$tools/stylua"
	chmod +x "$tools/stylua/stylua"
	stamp stylua "$key"
fi

key="luals $LUALS_VERSION $LUALS_SHA256"
if stale luals "$key"; then
	fetch "https://github.com/LuaLS/lua-language-server/releases/download/$LUALS_VERSION/lua-language-server-$LUALS_VERSION-linux-x64.tar.gz" \
		"$tmp/luals.tar.gz" "$LUALS_SHA256"
	tar -xzf "$tmp/luals.tar.gz" -C "$tools/luals"
	stamp luals "$key"
fi

# The dump is pinned by commit, so the raw files at that commit can't change; there is no separate checksum.
key="bir $BIR_COMMIT"
if stale bir "$key"; then
	for file in GlobalAPI.lua FrameXML.lua Frames.lua LuaEnum.lua GlobalStrings/enUS.lua; do
		mkdir -p "$(dirname "$tools/bir/Resources/$file")"
		fetch "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/$BIR_COMMIT/Resources/$file" \
			"$tools/bir/Resources/$file"
	done
	stamp bir "$key"
fi

key="wow-api $WOW_API_COMMIT"
if stale wow-api "$key"; then
	fetch "https://codeload.github.com/Ketho/vscode-wow-api/tar.gz/$WOW_API_COMMIT" "$tmp/wow-api.tar.gz"
	tar -xzf "$tmp/wow-api.tar.gz" -C "$tools/wow-api" --strip-components=1 --wildcards '*/Annotations/Core/*'
	stamp wow-api "$key"
fi

# Python, pytest and mypy for the content generator (DATA-R60), numpy, soundfile and SciPy for render-sounds.py
# (ANN-R74), and Pillow for export-web-art.py: one component, since the venv is built on that CPython. uv runs with no user config and its caches in $tmp, and leaves ~/.local/bin alone (--no-bin). The venv
# hardcodes its paths, hence the prefix in the key.
# shellcheck disable=SC2086
packages=$(echo $PYTHON_PACKAGES)
key="uv $UV_VERSION $UV_SHA256 python $PYTHON_VERSION packages $packages prefix $tools"
if stale python "$key"; then
	fetch "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-unknown-linux-musl.tar.gz" \
		"$tmp/uv.tar.gz" "$UV_SHA256"
	tar -xzf "$tmp/uv.tar.gz" -C "$tools/python" --strip-components=1
	export UV_NO_CONFIG=1 UV_CACHE_DIR="$tmp/uv-cache" UV_PYTHON_CACHE_DIR="$tmp/uv-python-cache" \
		UV_PYTHON_INSTALL_DIR="$tools/python/cpython"
	uv="$tools/python/uv"
	quiet "$uv" python install --no-bin "$PYTHON_VERSION"
	quiet "$uv" venv --python "$PYTHON_VERSION" --managed-python --no-python-downloads "$tools/python/venv"
	# Exact pins, no resolving and no source builds: each pair becomes name==version.
	quiet "$uv" pip install --python "$tools/python/venv/bin/python" --no-deps --only-binary :all: \
		$(awk 'NF { print $1 "==" $2 }' <<<"$PYTHON_PACKAGES")

	# Names compared normalized (PEP 503: lowercase, runs of -_. as -).
	normalize() { awk -F'==' 'NF { name = tolower($1); gsub(/[-_.]+/, "-", name); print name, $2 }' | sort; }
	installed=$("$uv" pip freeze --quiet --python "$tools/python/venv/bin/python" | normalize)
	pinned=$(awk 'NF { print $1 "==" $2 }' <<<"$PYTHON_PACKAGES" | normalize)
	if [[ $installed != "$pinned" ]]; then
		echo "setup: the installed Python packages differ from PYTHON_PACKAGES in scripts/tools.env:" >&2
		diff <(echo "$pinned") <(echo "$installed") >&2 || true
		exit 1
	fi
	stamp python "$key"
fi

for tool in lua luarocks luacheck busted luacov; do
	ln -sfn "../lua/bin/$tool" "$tools/bin/$tool"
done
ln -sfn ../stylua/stylua "$tools/bin/stylua"
ln -sfn ../luals/bin/lua-language-server "$tools/bin/lua-language-server"
for tool in pytest mypy; do
	ln -sfn "../python/venv/bin/$tool" "$tools/bin/$tool"
done
# Python finds its venv from the path it was started by, so python is a script, not a link (rm first: writing
# through an earlier link would overwrite the venv's python).
rm -f "$tools/bin/python"
printf '#!/bin/sh\nexec "$(dirname "$0")/../python/venv/bin/python" "$@"\n' >"$tools/bin/python"
chmod +x "$tools/bin/python"

"$tools/bin/lua" -v 2>&1
"$tools/bin/luacheck" --version | sed -n 1p
"$tools/bin/busted" --version | sed 's/^/busted /'
"$tools/bin/stylua" --version
echo "lua-language-server $("$tools/bin/lua-language-server" --version)"
"$tools/bin/python" --version
"$tools/bin/pytest" --version
"$tools/bin/mypy" --version
"$tools/bin/python" -c 'import numpy, scipy.signal, soundfile
print("numpy", numpy.__version__, "soundfile", soundfile.__version__, "scipy", scipy.__version__)'

# The pins this prefix now holds; check.sh refuses to run while they differ from scripts/tools.env.
cp "$root/scripts/tools.env" "$tools/tools.env"
echo "setup: ready; run scripts/check.sh"
