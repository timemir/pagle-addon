"""The real-font layout harness's Python half; scripts/measure-layout.sh runs it. pagle_data/layout.py has the details.

    .tools/bin/python scripts/measure-layout.py advances [--check]
    .tools/bin/python scripts/measure-layout.py report <out> <language> [--png all|findings|none] [--verbose]

`advances` writes scripts/measure-layout/advances.lua from the bundled faces (addons/Pagle/media/fonts/); with
--check it only fails if the file isn't what the faces give. `report` reads the Lua half's findings in <out>, prints
them against scripts/measure-layout/allowlist.toml, draws the PNGs into <out>/png/ and exits 1 on any finding the
allowlist doesn't cover.
"""

import argparse
import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("measure-layout: needs Python 3.12 or later")

try:
    import PIL  # noqa: F401 (only checks that Pillow is there)
except ImportError:
    sys.exit("measure-layout: needs Pillow; run it as .tools/bin/python scripts/measure-layout.py (scripts/setup.sh)")

from pagle_data import layout  # noqa: E402 (after the checks, which must run first)

ALLOWLIST = Path("scripts/measure-layout/allowlist.toml")


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="The real-font layout harness's advances and report.")
    commands = parser.add_subparsers(dest="command", required=True)
    advances = commands.add_parser("advances", help="write scripts/measure-layout/advances.lua")
    advances.add_argument("--check", action="store_true", help="only check that it's current")
    report = commands.add_parser("report", help="report the Lua half's findings")
    report.add_argument("out", type=Path, help="the folder the Lua half wrote")
    report.add_argument("language", help="the Language it ran in")
    report.add_argument("--png", choices=("all", "findings", "none"), default="findings",
                        help="the stops to draw: every one, those with a finding (default) or none")
    report.add_argument("--verbose", action="store_true", help="list the allowed findings too")
    args = parser.parse_args(argv)

    if args.command == "advances":
        text = layout.advances_lua(root / layout.FONTS_DIR)
        target = root / layout.ADVANCES_LUA
        if args.check:
            if not target.exists() or target.read_text(encoding="utf-8") != text:
                print(f"measure-layout: {layout.ADVANCES_LUA} isn't what the bundled faces give; run "
                      ".tools/bin/python scripts/measure-layout.py advances", file=sys.stderr)
                return 1
            return 0
        target.write_text(text, encoding="utf-8")
        print(f"measure-layout: wrote {layout.ADVANCES_LUA}", file=sys.stderr)
        return 0

    try:
        allowlist = layout.load_allowlist(root / ALLOWLIST)
    except (ValueError, OSError) as error:
        print(f"measure-layout: {error}", file=sys.stderr)
        return 1
    findings = layout.read_findings(args.out / "findings.jsonl")
    groups = layout.group(findings, allowlist, args.language)
    for line in layout.report(groups, args.language, args.verbose):
        print(line)
    errors = args.out / "errors.txt"
    error_text = errors.read_text(encoding="utf-8").strip() if errors.exists() else ""
    if error_text:
        print(f"{args.language}: the addons raised errors on the tour:\n{error_text}")
    if args.png != "none":
        written = layout.draw_findings(args.out, groups, root / layout.FONTS_DIR, args.png == "all")
        if written:
            print(f"{args.language}: {len(written)} PNGs in {(args.out / 'png').resolve()}")
    return 1 if error_text or any(g.allow is None for g in groups) else 0


if __name__ == "__main__":
    sys.exit(main())
