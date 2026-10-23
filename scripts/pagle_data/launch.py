"""scripts/launch.py's command line: the launch-night kit (docs/agents/launch-runbook.md, #383). Each subcommand is
one of the runbook's prepared steps, so the night only fills in numbers:

- `watch` (P4): Ketho's BlizzardInterfaceResources `forever` dump and wago.tools' build list, fetched with
  unauthenticated curl, and whether the live build has appeared on either.
- `interface <n>` (P2, runbook §3.2): the interface bump, CORE-R2's number in every place that states it.
- `dump <commit> <version> <build>` (P6, runbook §3.1): the dump pin in scripts/tools.env.
- `angleur-stub <AddOns folder>` (P5, launch re-verification check 15): writes or removes the `Angleur` stub.
- `post-tag <tag>` (P7): the GitHub Release zip's SHA-256 and contents, against the local package.sh zip.
- `read <step>` (runbook §5.2): scripts/read-wtf.sh with a dev step's flags, cut to the step's sections.

None of it runs in scripts/check.sh: the gate never touches the network or the client's folders.
"""

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from pathlib import Path

PROG = "launch"

Fetch = Callable[[str], bytes]
Run = Callable[[Sequence[str]], tuple[int, str, str]]

# --- Fetching -------------------------------------------------------------------------------------------------------

KETHO_URL = "https://api.github.com/repos/Ketho/BlizzardInterfaceResources/commits/forever"
BUILDS_URL = "https://wago.tools/api/builds"
RELEASE_URL = "https://api.github.com/repos/timemir/pagle-addon/releases/tags/{tag}"


def curl(url: str) -> bytes:
    """url's body, fetched with curl and no credentials at all: the agents' gh token is scoped to pagle-addon's
    issues, and the GitHub API answers public reads without one (60 an hour)."""
    done = subprocess.run(
        ["curl", "-fsSL", "--max-time", "120", "-A", "Pagle scripts/launch.py", url],
        capture_output=True,
        check=False,
    )
    if done.returncode != 0:
        raise OSError(f"curl exit {done.returncode}: {done.stderr.decode('utf-8', 'replace').strip()}")
    return done.stdout


# --- The interface bump (P2) ----------------------------------------------------------------------------------------

ADDONS = ("Pagle", "Pagle_Ledger", "Pagle_QoL", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard")
_INTERFACE_LINE = re.compile(r"^## Interface: ([0-9]+)\s*$", re.MULTILINE)
# Where an interface bump leaves the old number on purpose: client-build fixtures, research notes and the beta's
# probe reports keep the build they were written against.
_LEFT_ALONE = ("docs/research/", "probes/", "prototypes/", "spec/Pagle/fixtures/")


def game_version(interface: int) -> str:
    """The game version an interface number stands for, as the packager reads it: 16001 is 1.60.1."""
    return f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"


@dataclass
class Edit:
    """One file's text before and after, and what changed in it."""

    path: str
    before: str
    after: str
    notes: list[str] = field(default_factory=list)


def _replace(edit: Edit, old: str, new: str, count: int) -> None:
    found = edit.after.count(old)
    if found != count:
        raise ValueError(f"{edit.path}: expected {count} of '{old}', found {found}")
    edit.after = edit.after.replace(old, new)
    edit.notes.append(f"'{old}' -> '{new}'" + (f" ({count}x)" if count > 1 else ""))


def interface_edits(root: Path, new: int) -> tuple[int, list[Edit]]:
    """The current interface number and every edit the bump to new makes (CORE-R2): the six TOCs, the five Module
    TOC specs, CORE-R2's text, spec/README's and release.yml's comment. Raises ValueError when the TOCs disagree or
    a place doesn't read as expected, so nothing is half done."""
    numbers = {}
    for addon in ADDONS:
        text = (root / "addons" / addon / f"{addon}.toc").read_text(encoding="utf-8")
        match = _INTERFACE_LINE.search(text)
        if match is None:
            raise ValueError(f"addons/{addon}/{addon}.toc: no ## Interface: line")
        numbers[addon] = int(match.group(1))
    if len(set(numbers.values())) != 1:
        raise ValueError(f"the TOCs disagree: {numbers}; make them one number by hand first (CORE-R2)")
    old = numbers["Pagle"]
    if new == old:
        raise ValueError(f"the TOCs already say {old}")
    edits: list[Edit] = []

    def edit(path: str) -> Edit:
        text = (root / path).read_text(encoding="utf-8")
        made = Edit(path, text, text)
        edits.append(made)
        return made

    for addon in ADDONS:
        _replace(edit(f"addons/{addon}/{addon}.toc"), f"## Interface: {old}", f"## Interface: {new}", 1)
    for addon in ADDONS[1:]:
        spec = f"spec/{addon}/{addon}_toc_spec.lua"
        assertion = 'assert.are.equal("{}", fields.Interface)'
        _replace(edit(spec), assertion.format(old), assertion.format(new), 1)
    _replace(edit("docs/spec/core/README.md"), f"`## Interface: {old}`", f"`## Interface: {new}`", 1)
    _replace(edit("docs/spec/README.md"), f"interface {old},", f"interface {new},", 1)
    release = edit(".github/workflows/release.yml")
    _replace(release, f"## Interface: {old}", f"## Interface: {new}", 1)
    if game_version(new) != game_version(old):
        _replace(release, game_version(old), game_version(new), 2)
    return old, edits


def leftovers(root: Path, number: int, done: Sequence[str]) -> list[str]:
    """Each tracked line outside the edited files and the places left alone that still names number."""
    listed = subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True, check=False)
    if listed.returncode != 0:
        return [f"(git ls-files failed, so this list is empty: grep the tracked files for {number} by hand)"]
    found = []
    pattern = re.compile(rf"(?<![0-9]){number}(?![0-9])")
    for path in listed.stdout.splitlines():
        if path in done or path.startswith(_LEFT_ALONE):
            continue
        try:
            text = (root / path).read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for index, line in enumerate(text.splitlines(), 1):
            if pattern.search(line):
                found.append(f"{path}:{index}: {line.strip()[:120]}")
    return found


def run_interface(root: Path, new: int, dry_run: bool) -> int:
    try:
        old, edits = interface_edits(root, new)
    except (OSError, ValueError) as error:
        print(f"{PROG} interface: {error}; changed nothing", file=sys.stderr)
        return 1
    for made in edits:
        print(f"{made.path}: {'; '.join(made.notes)}")
        if not dry_run:
            (root / made.path).write_text(made.after, encoding="utf-8", newline="")
    left = leftovers(root, old, [made.path for made in edits])
    print(f"\n{'would change' if dry_run else 'changed'} {len(edits)} files, {old} -> {new}")
    if left:
        print(f"still naming {old} (client-build fixtures and test expectations; judge each by hand):")
        for line in left:
            print(f"  {line}")
    print(
        "next: run the TOC specs (spec/Pagle*/*_toc_spec.lua) and spec/scripts/read-wtf_spec.lua one at a time,"
        " then the full check (runbook §3.2)"
    )
    return 0


# --- The dump pin (P6) ----------------------------------------------------------------------------------------------

_SHA = re.compile(r"[0-9a-f]{40}")
_BIR_BLOCK = re.compile(r"^# This commit is the dump of build .*\nBIR_COMMIT=[0-9a-f]{40}$", re.MULTILINE)
_WOW_API = re.compile(r"^WOW_API_COMMIT=[0-9a-f]{40}$", re.MULTILINE)


def dump_text(text: str, commit: str, version: str, build: int, annotations: str | None) -> str:
    """scripts/tools.env with BIR_COMMIT (and its build comment) at commit, and WOW_API_COMMIT at annotations when
    given. Raises ValueError on a malformed argument or a tools.env that doesn't read as expected."""
    if not _SHA.fullmatch(commit):
        raise ValueError(f"'{commit}' isn't a full 40-character commit hash")
    if annotations is not None and not _SHA.fullmatch(annotations):
        raise ValueError(f"'{annotations}' isn't a full 40-character commit hash")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError(f"'{version}' isn't a version such as 1.60.1")
    if len(_BIR_BLOCK.findall(text)) != 1:
        raise ValueError("scripts/tools.env has no single build comment and BIR_COMMIT line pair")
    text = _BIR_BLOCK.sub(f"# This commit is the dump of build {version} ({build}).\nBIR_COMMIT={commit}", text)
    if annotations is not None:
        if len(_WOW_API.findall(text)) != 1:
            raise ValueError("scripts/tools.env has no single WOW_API_COMMIT line")
        text = _WOW_API.sub(f"WOW_API_COMMIT={annotations}", text)
    return text


def run_dump(root: Path, commit: str, version: str, build: int, annotations: str | None) -> int:
    path = root / "scripts" / "tools.env"
    try:
        text = path.read_text(encoding="utf-8")
        after = dump_text(text, commit, version, build, annotations)
    except (OSError, ValueError) as error:
        print(f"{PROG} dump: {error}; changed nothing", file=sys.stderr)
        return 1
    path.write_text(after, encoding="utf-8", newline="")
    print(f"scripts/tools.env: BIR_COMMIT={commit}, the dump of build {version} ({build})")
    if annotations is not None:
        print(f"scripts/tools.env: WOW_API_COMMIT={annotations}")
    print("next, in WSL (runbook §3.1): scripts/setup.sh, then the api stage alone:")
    print("  .tools/bin/lua scripts/api-presence.lua .luacheckrc .tools/bir/Resources")
    print("  .tools/bin/lua scripts/api-inventory.lua --check .luacheckrc addons/Pagle/data/ApiInventory.lua")
    if annotations is not None:
        print("  and the types stage, as scripts/check.sh's stage_types runs it")
    return 0


# --- The Angleur stub (P5) ------------------------------------------------------------------------------------------

STUB = "Angleur"
STUB_MARK = "## X-Pagle-Stub: launch re-verification check 15"


def wow_running() -> bool | None:
    """Whether a WoW process runs, from tasklist.exe; None when it can't tell (no tasklist.exe)."""
    if shutil.which("tasklist.exe") is None:
        return None
    done = subprocess.run(["tasklist.exe"], capture_output=True, text=True, check=False)
    return any(line.lower().startswith("wow") for line in done.stdout.splitlines())


def stub_toc(root: Path) -> str:
    """The stub's TOC: Pagle.toc's ## Interface: and ## AllowLoadGameType:, so the client loads it as it loads Pagle
    (QoL's conflict check reads C_AddOns.IsAddOnLoaded), and the mark --remove looks for."""
    copied = [
        line
        for line in (root / "addons" / "Pagle" / "Pagle.toc").read_text(encoding="utf-8").splitlines()
        if line.startswith(("## Interface:", "## AllowLoadGameType:"))
    ]
    return "\n".join([*copied, "## Title: Angleur (Pagle's check 15 stub)", STUB_MARK, "", "Angleur.lua", ""])


def run_stub(root: Path, addons: Path, remove: bool, running: Callable[[], bool | None]) -> int:
    folder = addons / STUB
    state = running()
    if state:
        print(f"{PROG} angleur-stub: World of Warcraft is running; quit it fully, then run this again. Nothing changed.",
              file=sys.stderr)
        return 1
    if state is None:
        print(f"{PROG} angleur-stub: can't tell whether World of Warcraft is running (no tasklist.exe); make sure it's"
              " fully closed.", file=sys.stderr)
    if not addons.is_dir():
        print(f"{PROG} angleur-stub: no folder {addons}; nothing changed", file=sys.stderr)
        return 1
    toc = folder / f"{STUB}.toc"
    ours = toc.is_file() and STUB_MARK in toc.read_text(encoding="utf-8", errors="replace")
    if remove:
        if not folder.exists():
            print(f"{folder}: not there; nothing to remove")
            return 0
        if not ours:
            print(f"{PROG} angleur-stub: {folder} isn't the stub (no '{STUB_MARK}'); left it alone", file=sys.stderr)
            return 1
        shutil.rmtree(folder)
        print(f"removed the stub {folder}")
        return 0
    if folder.exists() and not ours:
        print(f"{PROG} angleur-stub: {folder} exists and isn't the stub: a real Angleur? Left it alone.",
              file=sys.stderr)
        return 1
    folder.mkdir(exist_ok=True)
    (folder / f"{STUB}.toc").write_text(stub_toc(root), encoding="utf-8", newline="\r\n")
    (folder / f"{STUB}.lua").write_text("-- Pagle's check 15 stub: loads, does nothing.\n", encoding="utf-8")
    print(f"wrote the stub {folder}; log in for check 15, then quit and run this again with --remove")
    return 0


# --- The watchers (P4) ----------------------------------------------------------------------------------------------

_TOOLS_BUILD = re.compile(r"# This commit is the dump of build ([0-9.]+) \(([0-9]+)\)\.\nBIR_COMMIT=([0-9a-f]{40})")
_MESSAGE_BUILD = re.compile(r"([0-9]+\.[0-9]+\.[0-9]+) \(([0-9]+)\)")
_BUILD_NAME = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)")


@dataclass(frozen=True)
class Pins:
    """What the repo pins now: the dump's commit and build (scripts/tools.env), and data/db2/'s build, its version
    line and its products (data/db2/build.toml)."""

    bir_commit: str
    bir_build: int
    db2_build: int
    db2_line: str
    db2_products: tuple[str, ...]


def read_pins(root: Path) -> Pins:
    tools = (root / "scripts" / "tools.env").read_text(encoding="utf-8")
    match = _TOOLS_BUILD.search(tools)
    if match is None:
        raise ValueError("scripts/tools.env: no build comment and BIR_COMMIT line pair")
    build_toml = (root / "data" / "db2" / "build.toml").read_text(encoding="utf-8")
    build = re.search(r"^build = ([0-9]+)$", build_toml, re.MULTILINE)
    version = re.search(r'^version = "([0-9]+)\.([0-9]+)\.[0-9]+"$', build_toml, re.MULTILINE)
    products = re.search(r"^products = \[(.*)\]$", build_toml, re.MULTILINE)
    if build is None or version is None or products is None:
        raise ValueError("data/db2/build.toml: no build, version or products line")
    return Pins(
        match.group(3),
        int(match.group(2)),
        int(build.group(1)),
        f"{version.group(1)}.{version.group(2)}",
        tuple(re.findall(r'"([^"]+)"', products.group(1))),
    )


def ketho_lines(answer: bytes, pins: Pins, live: int | None) -> list[str]:
    """What Ketho's `forever` head says: its commit, the build its message names, against the pinned dump."""
    head = json.loads(answer.decode("utf-8"))
    sha = head["sha"]
    message = head["commit"]["message"].splitlines()[0]
    when = head["commit"]["committer"]["date"]
    named = _MESSAGE_BUILD.search(message)
    build = int(named.group(2)) if named else None
    state = "the pinned dump" if sha == pins.bir_commit else f"newer than the pinned {pins.bir_commit[:7]} ({pins.bir_build})"
    lines = [f'ketho forever: {sha[:7]} "{message}" {when}, {state}']
    if live is not None and build is not None and build >= live:
        version = named.group(1) if named else "?"
        lines.append(f"LIVE: Ketho's dump has build {build}: scripts/launch.py dump {sha} {version} {build}")
    return lines


def wago_lines(answer: bytes, pins: Pins, live: int | None) -> list[str]:
    """Each wago.tools product listing a build on data/db2/'s version line newer than data/db2/'s: its newest, and
    whether build.toml's products name it (the DB2 watch reads only those)."""
    document = json.loads(answer.decode("utf-8-sig"))
    lines = []
    for product in sorted(document):
        newest: tuple[int, str, str] | None = None
        for entry in document[product] if isinstance(document[product], list) else []:
            match = _BUILD_NAME.fullmatch(str(entry.get("version", "")))
            if match is None or f"{int(match.group(1))}.{int(match.group(2))}" != pins.db2_line:
                continue
            number = int(match.group(4))
            if number > pins.db2_build and (newest is None or number > newest[0]):
                newest = (number, entry["version"], str(entry.get("created_at", "")))
        if newest is None:
            continue
        listed = "" if product in pins.db2_products else "; not in data/db2/build.toml's products"
        lines.append(f"wago.tools {product}: {newest[1]} ({newest[2]}), newer than data/db2/'s {pins.db2_build}{listed}")
        if live is not None and newest[0] >= live:
            lines.append(f"LIVE: wago.tools lists build {newest[0]} under {product}: scripts/update-db2.py {newest[1]}")
    if not lines:
        lines.append(f"wago.tools: no {pins.db2_line} build newer than data/db2/'s {pins.db2_build}")
    return lines


def poll(fetch: Fetch, pins: Pins, live: int | None) -> list[str]:
    lines = []
    for name, url, read in (("ketho", KETHO_URL, ketho_lines), ("wago.tools", BUILDS_URL, wago_lines)):
        try:
            lines += read(fetch(url), pins, live)
        except (OSError, ValueError, KeyError, TypeError) as error:
            lines.append(f"{name}: can't read {url}: {error}")
    return lines


def run_watch(root: Path, live: int | None, every: int | None, fetch: Fetch,
              sleep: Callable[[float], None], rounds: int | None) -> int:
    try:
        pins = read_pins(root)
    except (OSError, ValueError) as error:
        print(f"{PROG} watch: {error}", file=sys.stderr)
        return 1
    seen: list[str] = []
    done = 0
    while True:
        lines = poll(fetch, pins, live)
        stamp = time.strftime("%Y-%m-%d %H:%M:%SZ", time.gmtime())
        for line in lines:
            if line not in seen:
                print(f"{stamp} {line}", flush=True)
        seen = lines
        done += 1
        if every is None:
            return 1 if any(": can't read " in line for line in lines) else 0
        if rounds is not None and done >= rounds:
            return 0
        sleep(every)


# --- After the tag (P7) ---------------------------------------------------------------------------------------------

REQUIRED_IN_PAGLE = ("Pagle/LICENSE", "Pagle/NOTICE", "Pagle/CHANGELOG.md")


def zip_files(data: bytes) -> dict[str, str]:
    """Each file in a zip, by its path, with its bytes' SHA-256."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        return {
            info.filename: hashlib.sha256(archive.read(info)).hexdigest()
            for info in archive.infolist()
            if not info.is_dir()
        }


def run_post_tag(tag: str, zip_path: Path | None, local: Path | None, fetch: Fetch) -> int:
    try:
        if zip_path is not None:
            name, data = zip_path.name, zip_path.read_bytes()
        else:
            release = json.loads(fetch(RELEASE_URL.format(tag=tag)).decode("utf-8"))
            assets = [asset for asset in release.get("assets", []) if str(asset.get("name", "")).endswith(".zip")]
            if len(assets) != 1:
                names = [asset.get("name") for asset in release.get("assets", [])]
                print(f"{PROG} post-tag: expected one .zip asset on release {tag}, found {names}", file=sys.stderr)
                return 1
            name, data = assets[0]["name"], fetch(assets[0]["browser_download_url"])
        files = zip_files(data)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f"{PROG} post-tag: {error}", file=sys.stderr)
        return 1
    problems = []
    folders = sorted({path.split("/")[0] for path in files})
    if folders != sorted(ADDONS):
        problems.append(f"top folders {folders}, expected {sorted(ADDONS)}")
    problems += [f"no {path}" for path in REQUIRED_IN_PAGLE if path not in files]
    print(f"SHA-256 {hashlib.sha256(data).hexdigest()}  {name}")
    print(f"{len(data)} bytes, {len(files)} files, folders: {', '.join(folders)}")
    if local is not None:
        try:
            mine = zip_files(local.read_bytes())
        except (OSError, zipfile.BadZipFile) as error:
            print(f"{PROG} post-tag: {local}: {error}", file=sys.stderr)
            return 1
        only_release = sorted(set(files) - set(mine))
        only_local = sorted(set(mine) - set(files))
        differ = sorted(path for path in set(files) & set(mine) if files[path] != mine[path])
        print(f"against {local.name}: {len(only_release)} only in the release, {len(only_local)} only local,"
              f" {len(differ)} differ")
        for label, paths in (("only in the release", only_release), ("only local", only_local), ("differ", differ)):
            for path in paths:
                print(f"  {label}: {path}")
        if only_release or only_local:
            problems.append("the release zip and the local one hold different files")
    for problem in problems:
        print(f"FAIL  {problem}")
    print("ok" if not problems else f"{len(problems)} problem(s)")
    return 1 if problems else 0


# --- The read-wtf checklist (runbook §5.2) --------------------------------------------------------------------------

LAUNCH_ENV = "~/pagle-launch.env"
LEASED_CVARS = "addons/Pagle_QoL/logic/Stretch.lua"


@dataclass(frozen=True)
class Step:
    """One dev step: what it is, the read-wtf sections an agent reports after it, and its flags."""

    what: str
    sections: tuple[str, ...]
    casts: bool = False  # takes --expect-casts and --since
    addons: tuple[str, ...] = ()  # --addon names beyond the six
    cvars: bool = False  # QoL's leased CVars (QOL-R62, QOL-R67)
    hand: str = ""  # what read-wtf doesn't read, for the agent to read by hand


STEPS: dict[str, Step] = {
    "reload": Step("any /reload or logout", ("Lua errors",)),
    "first-login": Step("first login: the Letter, Later, /reload twice, /pagle guide (M8.5 steps 1-2)",
                        ("Lua errors", "Onboarding", "Addons")),
    "check1": Step("check 1: Pagle_Stats off, log in, on again", ("Lua errors", "Addons")),
    "check15": Step("check 15: the Angleur stub, Use Pagle, Reload now", ("Lua errors", "Addons"), addons=("Angleur",)),
    "probe": Step("the probe: N Casts, /pagle dev probe, /reload (checks 3, 8, 11, 12, 16, 18-21, 23; 4 and 6)",
                  ("Lua errors", "Probe", "Catch log", "Re-verification", "Exit check"), casts=True),
    "check9": Step("check 9: a kill mid-Session, then log in", ("Lua errors", "Catch log", "CVars"), cvars=True),
    "big-log": Step("checks 2 and 10: a big test log's login and /reload", ("Lua errors", "Re-verification")),
    "places": Step("checks 5, 6 and 7: pools, zones and deDE", ("Lua errors", "Re-verification", "Field report")),
    "check16": Step("check 16: the set limit", ("Lua errors", "Probe"),
                    hand="SavedVariables/Pagle_QoL.lua's PagleQoLDB.global.gear (read-wtf has no QoL section)"),
    "onboarding": Step("M8.5 steps 3-16", ("Lua errors", "Onboarding")),
    "m8": Step("M8 steps 1-7: runs, marks, settled, Notices, Prestige",
               ("Lua errors", "Hunts", "Activity XP", "Ledger M4", "Wallet", "Tackle Board")),
    "fresh-install": Step("#276 steps 2-3: the release zip on a fresh install, then the real log back",
                          ("Lua errors", "Catch log", "Ledger", "Hunts", "Stats", "Tackle Board", "Wallet", "Varieties",
                           "Field report", "Exit check"), casts=True),
}

_SECTION_START = re.compile(r"^== ")


def heading_of(line: str, names: Sequence[str]) -> bool:
    """Whether line opens one of the named sections: `== <name>` then the end, " (", ":", "," or " <digit>" (so "Hunts"
    isn't "Hunt 12", "Ledger" isn't "Ledger M4" and "Stats" isn't "Stats item 6303 in area 12")."""
    for name in names:
        prefix = f"== {name}"
        if line.startswith(prefix):
            rest = line[len(prefix):]
            if rest == "" or rest.startswith((" (", ":", ",")) or re.match(r" [0-9]", rest):
                return True
    return False


def cut_sections(out: str, names: Sequence[str]) -> list[str]:
    """The lines of out's sections named (each from its `==` heading to the next), in out's order."""
    kept: list[str] = []
    keep = False
    for line in out.splitlines():
        if _SECTION_START.match(line):
            keep = heading_of(line, names)
        if keep:
            kept.append(line)
    return kept


def read_env(path: Path) -> dict[str, str]:
    """launch.env's NAME=value lines (P3), quotes stripped; comments and blank lines skipped."""
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        values[name.strip()] = value.strip().strip("'\"")
    return values


def leased_cvars(root: Path) -> list[str]:
    """QoL's leased CVars, as Stretch.lua lists them (QOL-R62), for check 9 (QOL-R67)."""
    text = (root / LEASED_CVARS).read_text(encoding="utf-8")
    return list(dict.fromkeys(re.findall(r'\{ name = "([A-Za-z_]+)", value = ', text)))


def read_args(root: Path, step: Step, account: str, character: str | None, wow: str | None, casts: int | None,
              since: str | None) -> list[str]:
    """read-wtf.sh's arguments for step."""
    args = [account]
    if character:
        args += ["--character", character]
    if wow:
        installed = Path(wow) / "Interface" / "AddOns"
        for flag, path in (("--catalogue", "Pagle/data/Catalogue.lua"), ("--huntlist", "Pagle_Hunts/data/HuntList.lua"),
                           ("--eventlist", "Pagle_Hunts/data/EventList.lua")):
            if (installed / path).is_file():
                args += [flag, str(installed / path)]
    if step.addons:
        for addon in (*ADDONS, *step.addons):
            args += ["--addon", addon]
    if step.cvars:
        for cvar in leased_cvars(root):
            args += ["--cvar", cvar]
    if step.casts and casts is not None:
        args += ["--expect-casts", str(casts)]
        if since:
            args += ["--since", since]
    return args


def run_command(command: Sequence[str]) -> tuple[int, str, str]:
    done = subprocess.run(list(command), capture_output=True, text=True, check=False)
    return done.returncode, done.stdout, done.stderr


def run_read(root: Path, args: argparse.Namespace, runner: Run) -> int:
    if args.list:
        for name, step in STEPS.items():
            flags = " --expect-casts N --since T" if step.casts else ""
            print(f"{name}: {step.what}\n    {'; '.join(step.sections)}{flags}" + (f"\n    by hand: {step.hand}"
                                                                                 if step.hand else ""))
        return 0
    if args.step not in STEPS:
        print(f"{PROG} read: no step '{args.step}'; --list lists them", file=sys.stderr)
        return 2
    step = STEPS[args.step]
    env: dict[str, str] = {}
    env_path = Path(os.path.expanduser(args.env or os.environ.get("PAGLE_LAUNCH_ENV", LAUNCH_ENV)))
    if env_path.is_file():
        env = read_env(env_path)
    elif args.account is None:
        print(f"{PROG} read: no {env_path} and no --account; fill launch.env (runbook › P3)", file=sys.stderr)
        return 2
    wow = env.get("WOW")
    account = args.account or (f"{wow}/WTF/Account/{env['ACCT']}" if wow and env.get("ACCT") else None)
    if account is None:
        print(f"{PROG} read: {env_path} names no WOW and ACCT", file=sys.stderr)
        return 2
    character = args.character or (f"{env['REALM']}/{env['CHAR']}" if env.get("REALM") and env.get("CHAR") else None)
    if step.casts and args.expect_casts is None:
        print(f"{PROG} read: step '{args.step}' needs --expect-casts N, the dev's Cast count", file=sys.stderr)
        return 2
    grabber = Path(account) / "SavedVariables" / "!BugGrabber.lua"
    if grabber.is_file():
        written = grabber.stat().st_mtime
        print(f"!BugGrabber.lua written {time.strftime('%Y-%m-%d %H:%M:%SZ', time.gmtime(written))},"
              f" {int(time.time() - written)} s ago: it must be newer than the dev's action")
    else:
        print("!BugGrabber.lua: missing (install !BugGrabber; Lua errors can't be read without it)")
    command = [str(root / "scripts" / "read-wtf.sh"),
               *read_args(root, step, account, character, wow, args.expect_casts,
                          args.since or env.get("T0")),
               *args.extra]
    code, out, err = runner(command)
    for line in cut_sections(out, step.sections):
        print(line)
    if err:
        print(err.rstrip(), file=sys.stderr)
    if step.hand:
        print(f"by hand: {step.hand}")
    return code


# --- The command line -----------------------------------------------------------------------------------------------


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="scripts/launch.py", description="The launch-night kit (#383).")
    sub = parser.add_subparsers(dest="command", required=True)
    watch = sub.add_parser("watch", help="Ketho's forever dump and wago.tools' builds (P4)")
    watch.add_argument("--live-build", type=int, help="the live build number, once known (launch.env's BUILD)")
    watch.add_argument("--every", type=int, help="poll every this many seconds, printing what changed; once if left out")
    interface = sub.add_parser("interface", help="bump ## Interface: and CORE-R2's number (P2)")
    interface.add_argument("number", type=int)
    interface.add_argument("--dry-run", action="store_true", help="print the edits, write nothing")
    dump = sub.add_parser("dump", help="move the dump pin in scripts/tools.env (P6)")
    dump.add_argument("commit")
    dump.add_argument("version", help="the build's version, e.g. 1.60.1")
    dump.add_argument("build", type=int)
    dump.add_argument("--annotations", help="also move WOW_API_COMMIT, vscode-wow-api's commit")
    stub = sub.add_parser("angleur-stub", help="write or remove the Angleur stub for check 15 (P5)")
    stub.add_argument("addons", type=Path, help="the live install's Interface/AddOns folder")
    stub.add_argument("--remove", action="store_true")
    post = sub.add_parser("post-tag", help="the release zip's SHA-256 and contents (P7)")
    post.add_argument("tag")
    post.add_argument("--zip", type=Path, help="read this zip instead of downloading the release's")
    post.add_argument("--local", type=Path, help="compare with this zip, scripts/package.sh's")
    read = sub.add_parser("read", help="read-wtf for one dev step, cut to its sections (runbook §5.2)")
    read.add_argument("step", nargs="?", default="reload")
    read.add_argument("--list", action="store_true", help="list the steps and their sections")
    read.add_argument("--env", help=f"launch.env (default $PAGLE_LAUNCH_ENV or {LAUNCH_ENV})")
    read.add_argument("--account", help="a WTF/Account/<ACCT> folder, over launch.env's")
    read.add_argument("--character", help="<realm folder>/<Name-Surname>, over launch.env's")
    read.add_argument("--expect-casts", type=int)
    read.add_argument("--since", help="server time, Unix seconds (default launch.env's T0)")
    read.add_argument("extra", nargs="*", help="after --: more read-wtf.sh arguments")
    return parser


def main(argv: Sequence[str], root: Path, fetch: Fetch = curl, runner: Run = run_command,
         running: Callable[[], bool | None] = wow_running, sleep: Callable[[float], None] = time.sleep,
         rounds: int | None = None) -> int:
    """Runs the command line on the repo at root; returns the exit code. fetch, runner, running, sleep and rounds
    stand in for the network, the shell, tasklist.exe, the clock and Ctrl+C in tests."""
    args = _parser().parse_args(argv)
    if args.command == "watch":
        return run_watch(root, args.live_build, args.every, fetch, sleep, rounds)
    if args.command == "interface":
        return run_interface(root, args.number, args.dry_run)
    if args.command == "dump":
        return run_dump(root, args.commit, args.version, args.build, args.annotations)
    if args.command == "angleur-stub":
        return run_stub(root, args.addons, args.remove, running)
    if args.command == "post-tag":
        return run_post_tag(args.tag, args.zip, args.local, fetch)
    return run_read(root, args, runner)
