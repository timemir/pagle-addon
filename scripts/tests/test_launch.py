"""scripts/launch.py, the launch-night kit (docs/agents/launch-runbook.md, #383). Nothing here touches the network,
the shell or a client folder: every download goes through a canned fetch, read-wtf.sh through a fake runner, and the
interface bump, the dump pin and the Angleur stub write into a copy of the files they edit under tmp_path."""

import hashlib
import io
import json
import re
import shutil
import zipfile
from collections.abc import Sequence
from pathlib import Path

import pytest

from cli_fixture import Canned, run
from pagle_data import launch
from pagle_data.launch import (
    ADDONS,
    BUILDS_URL,
    KETHO_URL,
    STEPS,
    cut_sections,
    dump_text,
    game_version,
    heading_of,
    interface_edits,
    leased_cvars,
    main,
)

REPO = Path(__file__).resolve().parents[2]
PINNED = "c5a49d394564f20c508c71014d6f60d9cd240c71"
NEWER = "d1ee569878094270c0ad8d8b00de0762158fd578"

# The files the interface bump edits, copied from the repo into tmp_path.
INTERFACE_FILES = [
    *(f"addons/{addon}/{addon}.toc" for addon in ADDONS),
    *(f"spec/{addon}/{addon}_toc_spec.lua" for addon in ADDONS[1:]),
    "docs/spec/core/README.md",
    "docs/spec/README.md",
    ".github/workflows/release.yml",
]

TOOLS_ENV = f"""\
# Ketho/BlizzardInterfaceResources, branch "forever": the API dump the API presence stage checks against.
# This commit is the dump of build 1.60.1 (70338).
BIR_COMMIT={PINNED}

# Ketho/vscode-wow-api: the LuaCATS annotations the types stage checks against (only Annotations/Core is kept).
WOW_API_COMMIT=d0b5b51fac4c52c493371b9b18e66ce604ea4326
"""

BUILD_TOML = """\
build = 70450
version = "1.60.1"
products = ["wow_classic_beta"]
"""


def copy_repo_files(root: Path, files: Sequence[str]) -> None:
    for path in files:
        (root / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / path, root / path)


def pins_tree(root: Path) -> Path:
    (root / "scripts").mkdir(parents=True)
    (root / "scripts" / "tools.env").write_text(TOOLS_ENV, encoding="utf-8")
    (root / "data" / "db2").mkdir(parents=True)
    (root / "data" / "db2" / "build.toml").write_text(BUILD_TOML, encoding="utf-8")
    return root


def ketho_json(sha: str, message: str) -> bytes:
    """The GitHub API's answer for one commit, cut to what the watch reads."""
    return json.dumps(
        {"sha": sha, "commit": {"message": message, "committer": {"date": "2026-11-05T02:10:00Z"}}}
    ).encode("utf-8")


def builds_json(answer: dict[str, list[str]]) -> bytes:
    """wago.tools' builds API: products as keys, each a list of builds, not in order."""
    return json.dumps(
        {
            product: [{"product": product, "version": version, "created_at": "2026-11-05 01:00:00"} for version in versions]
            for product, versions in answer.items()
        }
    ).encode("utf-8")


# --- interface -------------------------------------------------------------------------------------------------------


def test_game_version_reads_the_interface_as_the_packager_does() -> None:
    assert game_version(16001) == "1.60.1"
    assert game_version(16100) == "1.61.0"
    assert game_version(11508) == "1.15.8"


def test_the_repo_reads_as_the_interface_bump_expects() -> None:
    """Launch night's bump (runbook §3.2) finds every place it edits as it expects, on the repo as it stands."""
    old, edits = interface_edits(REPO, 16100)

    assert old == 16001
    assert sorted(edit.path for edit in edits) == sorted(INTERFACE_FILES)
    assert all(edit.after != edit.before for edit in edits)


def test_interface_bumps_every_toc_spec_and_text(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    copy_repo_files(tmp_path, INTERFACE_FILES)

    code, out = run(tmp_path, capsys, "interface", "16002", main=main)

    assert code == 0, out
    for addon in ADDONS:
        toc = (tmp_path / "addons" / addon / f"{addon}.toc").read_text(encoding="utf-8")
        assert toc.startswith("## Interface: 16002\n"), addon
    for addon in ADDONS[1:]:
        spec = (tmp_path / "spec" / addon / f"{addon}_toc_spec.lua").read_text(encoding="utf-8")
        assert 'assert.are.equal("16002", fields.Interface)' in spec
    assert "`## Interface: 16002`" in (tmp_path / "docs/spec/core/README.md").read_text(encoding="utf-8")
    assert "interface 16002," in (tmp_path / "docs/spec/README.md").read_text(encoding="utf-8")
    release = (tmp_path / ".github/workflows/release.yml").read_text(encoding="utf-8")
    assert "## Interface: 16002 as game type" in release
    assert "version 1.60.2" in release and "list 1.60.2" in release and "1.60.1" not in release
    assert "changed 14 files, 16001 -> 16002" in out


def test_interface_dry_run_writes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    copy_repo_files(tmp_path, INTERFACE_FILES)

    code, out = run(tmp_path, capsys, "interface", "16100", "--dry-run", main=main)

    assert code == 0
    assert "would change 14 files, 16001 -> 16100" in out
    for path in INTERFACE_FILES:
        assert (tmp_path / path).read_bytes() == (REPO / path).read_bytes(), path


@pytest.mark.parametrize("number", ["16001", "16100"])
def test_interface_refuses_disagreeing_tocs_or_the_same_number(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], number: str
) -> None:
    copy_repo_files(tmp_path, INTERFACE_FILES)
    if number == "16100":
        stats = tmp_path / "addons/Pagle_Stats/Pagle_Stats.toc"
        stats.write_text(stats.read_text(encoding="utf-8").replace("16001", "16002"), encoding="utf-8")
    before = {path: (tmp_path / path).read_bytes() for path in INTERFACE_FILES}

    code, out = run(tmp_path, capsys, "interface", number, main=main)

    assert code == 1
    assert "changed nothing" in out
    assert ("already say 16001" if number == "16001" else "the TOCs disagree") in out
    assert {path: (tmp_path / path).read_bytes() for path in INTERFACE_FILES} == before


# --- dump ------------------------------------------------------------------------------------------------------------


def test_dump_moves_the_pin_and_its_build_comment() -> None:
    after = dump_text(TOOLS_ENV, NEWER, "1.60.2", 70777, None)

    assert f"# This commit is the dump of build 1.60.2 (70777).\nBIR_COMMIT={NEWER}\n" in after
    assert PINNED not in after
    assert "WOW_API_COMMIT=d0b5b51fac4c52c493371b9b18e66ce604ea4326" in after


def test_dump_moves_the_annotations_when_asked() -> None:
    after = dump_text(TOOLS_ENV, NEWER, "1.60.1", 70532, "f" * 40)

    assert f"WOW_API_COMMIT={'f' * 40}" in after


def test_the_repo_tools_env_reads_as_the_dump_expects() -> None:
    """Launch night's dump bump (runbook §3.1) finds tools.env's pin and its build comment as it expects."""
    text = (REPO / "scripts" / "tools.env").read_text(encoding="utf-8")

    assert NEWER in dump_text(text, NEWER, "1.60.1", 70532, "f" * 40)


@pytest.mark.parametrize(
    ("commit", "version", "annotations"),
    [("d1ee569", "1.60.1", None), (NEWER, "70532", None), (NEWER, "1.60.1", "abc")],
)
def test_dump_refuses_a_short_hash_or_a_bad_version(commit: str, version: str, annotations: str | None) -> None:
    with pytest.raises(ValueError):
        dump_text(TOOLS_ENV, commit, version, 70532, annotations)


def test_dump_writes_tools_env(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    pins_tree(tmp_path)

    code, out = run(tmp_path, capsys, "dump", NEWER, "1.60.1", "70532", main=main)

    assert code == 0, out
    assert f"BIR_COMMIT={NEWER}" in (tmp_path / "scripts" / "tools.env").read_text(encoding="utf-8")
    assert "scripts/api-presence.lua" in out


# --- angleur-stub ----------------------------------------------------------------------------------------------------


def stub_tree(root: Path) -> Path:
    copy_repo_files(root, ["addons/Pagle/Pagle.toc"])
    addons = root / "live" / "Interface" / "AddOns"
    addons.mkdir(parents=True)
    return addons


def test_the_stub_loads_as_pagle_does_and_goes_again(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    addons = stub_tree(tmp_path)

    code, out = run(tmp_path, capsys, "angleur-stub", str(addons), main=main, running=lambda: False)

    assert code == 0, out
    toc = (addons / "Angleur" / "Angleur.toc").read_bytes().decode("utf-8")
    pagle = (tmp_path / "addons/Pagle/Pagle.toc").read_text(encoding="utf-8")
    for field in ("## Interface:", "## AllowLoadGameType:"):
        line = next(line for line in pagle.splitlines() if line.startswith(field))
        assert line + "\r\n" in toc
    assert "Angleur.lua\r\n" in toc
    assert (addons / "Angleur" / "Angleur.lua").is_file()

    code, out = run(tmp_path, capsys, "angleur-stub", str(addons), "--remove", main=main, running=lambda: False)

    assert code == 0, out
    assert not (addons / "Angleur").exists()


def test_the_stub_refuses_while_wow_runs(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    addons = stub_tree(tmp_path)

    code, out = run(tmp_path, capsys, "angleur-stub", str(addons), main=main, running=lambda: True)

    assert code == 1
    assert "World of Warcraft is running" in out
    assert not (addons / "Angleur").exists()


@pytest.mark.parametrize("remove", [False, True])
def test_the_stub_never_touches_a_real_angleur(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], remove: bool
) -> None:
    addons = stub_tree(tmp_path)
    (addons / "Angleur").mkdir()
    (addons / "Angleur" / "Angleur_Camelot.toc").write_text("## Interface: 16001\n", encoding="utf-8")

    args = ["angleur-stub", str(addons), *(["--remove"] if remove else [])]
    code, out = run(tmp_path, capsys, *args, main=main, running=lambda: False)

    assert code == 1
    assert "left it alone" in out.lower()
    assert sorted(path.name for path in (addons / "Angleur").iterdir()) == ["Angleur_Camelot.toc"]


# --- watch -----------------------------------------------------------------------------------------------------------


def test_watch_reports_the_dump_and_builds_against_the_pins(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    fetch = Canned(
        {
            KETHO_URL: ketho_json(NEWER, "1.60.1 (70532)"),
            BUILDS_URL: builds_json(
                {
                    "wow_classic_beta": ["1.60.1.70450", "1.60.1.70532", "5.5.0.62071"],
                    "wowf": ["1.60.1.70245", "1.60.1.70532"],
                    "wow_classic_era": ["1.15.9.70003"],
                }
            ),
        }
    )

    code, out = run(pins_tree(tmp_path), capsys, "watch", main=main, fetch=fetch)

    assert code == 0, out
    assert f'ketho forever: d1ee569 "1.60.1 (70532)" 2026-11-05T02:10:00Z, newer than the pinned c5a49d3 (70338)' in out
    assert "wago.tools wow_classic_beta: 1.60.1.70532 (2026-11-05 01:00:00), newer than data/db2/'s 70450\n" in out
    assert "wago.tools wowf: 1.60.1.70532 (2026-11-05 01:00:00), newer than data/db2/'s 70450; not in" in out
    assert "era" not in out
    assert "LIVE" not in out
    assert all("Authorization" not in url for url in fetch.asked)


def test_watch_says_when_the_live_build_appears(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    fetch = Canned(
        {
            KETHO_URL: ketho_json(NEWER, "1.60.1 (70900)"),
            BUILDS_URL: builds_json({"wowf": ["1.60.1.70900"]}),
        }
    )

    code, out = run(pins_tree(tmp_path), capsys, "watch", "--live-build", "70900", main=main, fetch=fetch)

    assert code == 0
    assert f"LIVE: Ketho's dump has build 70900: scripts/launch.py dump {NEWER} 1.60.1 70900" in out
    assert "LIVE: wago.tools lists build 70900 under wowf: scripts/update-db2.py 1.60.1.70900" in out


def test_watch_prints_only_what_changed_between_polls(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    fetch = Canned({KETHO_URL: ketho_json(PINNED, "1.60.1 (70338)"), BUILDS_URL: builds_json({"wowf": []})})
    sleeps: list[float] = []

    code, out = run(
        pins_tree(tmp_path), capsys, "watch", "--every", "600", main=main, fetch=fetch, sleep=sleeps.append, rounds=3
    )

    assert code == 0
    assert sleeps == [600, 600]
    assert len(fetch.asked) == 6
    assert out.count("ketho forever: c5a49d3") == 1
    assert out.count("the pinned dump") == 1
    assert out.count("wago.tools: no 1.60 build newer than data/db2/'s 70450") == 1


def test_watch_says_what_it_cant_download(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code, out = run(pins_tree(tmp_path), capsys, "watch", main=main, fetch=Canned({}))

    assert code == 1
    assert f"ketho: can't read {KETHO_URL}" in out
    assert f"wago.tools: can't read {BUILDS_URL}" in out


# --- post-tag --------------------------------------------------------------------------------------------------------


def release_zip(changed: str = "", extra: str = "") -> bytes:
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as archive:
        for addon in ADDONS:
            archive.writestr(f"{addon}/{addon}.toc", f"## Title: {addon}{changed if addon == 'Pagle_QoL' else ''}\n")
        for name in ("LICENSE", "NOTICE", "CHANGELOG.md"):
            archive.writestr(f"Pagle/{name}", name)
        if extra:
            archive.writestr(extra, "stray")
    return data.getvalue()


def test_post_tag_prints_the_release_zips_sha_and_compares_it(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    published = release_zip()
    asset = "https://github.com/timemir/pagle-addon/releases/download/1.0.0/Pagle-1.0.0-forever.zip"
    fetch = Canned(
        {
            "https://api.github.com/repos/timemir/pagle-addon/releases/tags/1.0.0": json.dumps(
                {"assets": [{"name": "release.json"}, {"name": "Pagle-1.0.0-forever.zip", "browser_download_url": asset}]}
            ).encode("utf-8"),
            asset: published,
        }
    )
    local = tmp_path / "Pagle-1.0.0-forever.zip"
    local.write_bytes(release_zip(changed=" (local)"))

    code, out = run(tmp_path, capsys, "post-tag", "1.0.0", "--local", str(local), main=main, fetch=fetch)

    assert code == 0, out
    assert f"SHA-256 {hashlib.sha256(published).hexdigest()}  Pagle-1.0.0-forever.zip" in out
    assert "0 only in the release, 0 only local, 1 differ" in out
    assert "  differ: Pagle_QoL/Pagle_QoL.toc" in out
    assert out.rstrip().endswith("ok")


def test_post_tag_fails_a_zip_with_a_stray_folder(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    zipped = tmp_path / "release.zip"
    zipped.write_bytes(release_zip(extra="docs/README.md"))

    code, out = run(tmp_path, capsys, "post-tag", "1.0.0", "--zip", str(zipped), main=main, fetch=Canned({}))

    assert code == 1
    assert "FAIL  top folders" in out


# --- read ------------------------------------------------------------------------------------------------------------

READ_WTF_OUT = """\
== Lua errors (!BugGrabber, latest session 12): 0 errors
== Catch log (PagleLog): format 2, logId x, 1 character, 3 entries
C1 Casts: 1
== Ledger (PagleLedgerDB)
projection: none stored
== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles
climb: rank 0
== Hunts (PagleHuntsDB)
runs: none known
== Hunt 12: not in the Hunt list
== Stats item 6303 in area 12 (--stats-item, --area)
side: none
== Probe: none stored
== Addons (70/Ada-Brook/AddOns.txt)
Pagle: enabled
== Exit check (#75 steps 3 and 4): 1 of 2 FAIL
FAIL  10 C1 Casts
"""


def test_a_heading_names_its_own_section_only() -> None:
    assert heading_of("== Ledger (PagleLedgerDB)", ["Ledger"])
    assert not heading_of("== Ledger M4 (PagleLedgerDB): Prestige", ["Ledger"])
    assert not heading_of("== Hunt 12: not in the Hunt list", ["Hunts"])
    assert heading_of("== Hunt 12: not in the Hunt list", ["Hunt"])
    assert not heading_of("== Stats item 6303 in area 12 (--stats-item, --area)", ["Stats"])
    assert heading_of("== Probe: none stored", ["Probe"])


def test_cut_sections_keeps_the_named_ones_whole() -> None:
    assert cut_sections(READ_WTF_OUT, ["Ledger", "Exit check"]) == [
        "== Ledger (PagleLedgerDB)",
        "projection: none stored",
        "== Exit check (#75 steps 3 and 4): 1 of 2 FAIL",
        "FAIL  10 C1 Casts",
    ]


def test_every_section_the_checklist_names_is_a_read_wtf_heading() -> None:
    """The checklist (runbook §5.2) names only sections read-wtf.lua prints."""
    source = (REPO / "scripts" / "read-wtf.lua").read_text(encoding="utf-8")
    headings = set(re.findall(r'"== ([A-Z][A-Za-z0-9 .-]*?)(?: \(|:|,|")', source))
    for name, step in STEPS.items():
        for section in step.sections:
            assert section in headings, f"{name}: {section}"


def test_check_9_reads_every_leased_cvar() -> None:
    cvars = leased_cvars(REPO)

    assert "SoftTargetInteract" in cvars and "autoLootDefault" in cvars and "Sound_EnableMusic" in cvars
    assert len(cvars) == len(set(cvars)) >= 8


class FakeRunner:
    """read-wtf.sh as the read step runs it: records the command, answers with READ_WTF_OUT."""

    def __init__(self, code: int = 0) -> None:
        self.commands: list[list[str]] = []
        self.code = code

    def __call__(self, command: Sequence[str]) -> tuple[int, str, str]:
        self.commands.append(list(command))
        return self.code, READ_WTF_OUT, ""


def launch_env(root: Path) -> Path:
    wow = root / "World of Warcraft" / "_forever_"
    (wow / "WTF" / "Account" / "ACCT1" / "SavedVariables").mkdir(parents=True)
    (wow / "WTF" / "Account" / "ACCT1" / "SavedVariables" / "!BugGrabber.lua").write_text("BugGrabberDB = {}\n")
    (wow / "Interface" / "AddOns" / "Pagle" / "data").mkdir(parents=True)
    (wow / "Interface" / "AddOns" / "Pagle" / "data" / "Catalogue.lua").write_text("-- installed\n")
    env = root / "launch.env"
    env.write_text(f'# launch night\nWOW="{wow}"\nACCT=ACCT1\nREALM=1234\nCHAR=Ada-Brook\nT0=1793840000\nBUILD=70900\n')
    return env


def test_read_runs_the_probe_step_with_its_flags_and_sections(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    env = launch_env(tmp_path)
    runner = FakeRunner(code=1)

    code, out = run(
        REPO, capsys, "read", "probe", "--env", str(env), "--expect-casts", "10", main=main, runner=runner
    )

    assert code == 1
    command = runner.commands[0]
    assert command[0] == str(REPO / "scripts" / "read-wtf.sh")
    wow = tmp_path / "World of Warcraft" / "_forever_"
    assert command[1] == f"{wow}/WTF/Account/ACCT1"
    assert command[2:4] == ["--character", "1234/Ada-Brook"]
    assert ["--catalogue", str(wow / "Interface/AddOns/Pagle/data/Catalogue.lua")] == command[4:6]
    assert command[-4:] == ["--expect-casts", "10", "--since", "1793840000"]
    assert "!BugGrabber.lua written" in out
    assert "== Lua errors (!BugGrabber, latest session 12): 0 errors" in out
    assert "== Probe: none stored" in out and "C1 Casts: 1" in out and "FAIL  10 C1 Casts" in out
    assert "== Ledger" not in out and "== Hunts" not in out and "== Addons" not in out


def test_read_names_every_addon_and_cvar_its_step_needs(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    env = launch_env(tmp_path)
    runner = FakeRunner()

    run(REPO, capsys, "read", "check15", "--env", str(env), main=main, runner=runner)
    run(REPO, capsys, "read", "check9", "--env", str(env), "--", "--now", "5", main=main, runner=runner)

    check15, check9 = runner.commands
    assert [check15[i + 1] for i, word in enumerate(check15) if word == "--addon"] == [*ADDONS, "Angleur"]
    assert [check9[i + 1] for i, word in enumerate(check9) if word == "--cvar"] == leased_cvars(REPO)
    assert check9[-2:] == ["--now", "5"]


def test_read_needs_the_cast_count_for_a_cast_step(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    runner = FakeRunner()

    code, out = run(REPO, capsys, "read", "probe", "--env", str(launch_env(tmp_path)), main=main, runner=runner)

    assert code == 2
    assert "needs --expect-casts N" in out
    assert runner.commands == []


def test_read_lists_the_checklist(capsys: pytest.CaptureFixture[str]) -> None:
    code, out = run(REPO, capsys, "read", "--list", main=main)

    assert code == 0
    for name in STEPS:
        assert f"{name}: " in out
    assert launch.LEASED_CVARS == "addons/Pagle_QoL/logic/Stretch.lua"
