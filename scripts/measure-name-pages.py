"""Measures each toast style's page behind a variety's name from the BLP art and writes the NAME_PAGES block in
addons/Pagle/adapter/Art.lua (#582, VAR-R28; pagle_data/name_pages.py has the details).

    .tools/bin/python scripts/measure-name-pages.py            # write the block
    .tools/bin/python scripts/measure-name-pages.py --check    # fail if the block isn't what the art gives

Runs scripts/measure-name-pages/probe.lua under the pinned busted (.tools/bin/busted, or --busted), then composites the
textures it reports. scripts/check.sh's generator stage runs it with --check, so a change to a style's art or layout
that moves the page behind the name fails the gate until the block is written again.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("measure-name-pages: needs Python 3.12 or later")

try:
    import PIL  # noqa: F401 (only checks that Pillow is there)
except ImportError:
    sys.exit("measure-name-pages: needs Pillow; run it as .tools/bin/python scripts/measure-name-pages.py")

from pagle_data import name_pages  # noqa: E402 (after the checks, which must run first)


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Measure the pages behind a variety's name.")
    parser.add_argument("--check", action="store_true", help="only check that the committed block is current")
    parser.add_argument("--busted", type=Path, default=root / ".tools/bin/busted",
                        help="the busted to run the probe with (default: .tools/bin/busted)")
    args = parser.parse_args(argv)

    with tempfile.TemporaryDirectory() as scratch:
        out = Path(scratch) / "name-pages.jsonl"
        run = subprocess.run([str(args.busted), str(name_pages.PROBE)], cwd=root, capture_output=True, text=True,
                             env={**os.environ, "NAME_PAGES_OUT": str(out)})
        if run.returncode != 0 or not out.exists():
            print(run.stdout[-4000:] + run.stderr[-4000:], file=sys.stderr)
            print("measure-name-pages: the probe failed", file=sys.stderr)
            return 1
        pages = name_pages.measure(name_pages.read_records(out), root / "addons")

    art = root / name_pages.ART_LUA
    text = art.read_text(encoding="utf-8")
    if args.check:
        wrong = name_pages.differences(name_pages.read_block(text), pages)
        for line in wrong:
            print(f"measure-name-pages: {line}", file=sys.stderr)
        if wrong:
            print(f"measure-name-pages: {name_pages.ART_LUA}'s NAME_PAGES isn't what the art gives; run "
                  ".tools/bin/python scripts/measure-name-pages.py", file=sys.stderr)
            return 1
        return 0
    art.write_text(name_pages.replace_block(text, name_pages.lua_block(pages)), encoding="utf-8")
    print(f"measure-name-pages: wrote {name_pages.ART_LUA} ({len(pages)} styles)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
