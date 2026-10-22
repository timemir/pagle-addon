"""Exports the Prestige frames, Prestige emblems and Legend crests as web art for the website (pagle-backend).

    python scripts/export-web-art.py [--out build/web-art] [--only <key> ...]

Reads data/art/prestige/ (art.json, the TGA atlases, wells/*.svg) and writes, at 2 pixels per unit, a rest-pose
`<key>.webp` for every frame and crest, a `<key>/` folder (a WebP per layer, manifest.json and <key>.css) for each one
that moves, the emblems at 128, 68 and 44 px, and index.json. `--only` takes keys such as prestige-frame-5,
legend-crest-19803 or prestige-emblem-master. pagle_data/web_art.py has the details.

No Blizzard texture or icon goes into any output (pagle-backend ANG-R54): every pixel is Pagle-drawn art from
data/art/prestige/, and a Legend crest's well holds a Pagle-drawn sepia fish, not the item's icon.

Needs Python 3.12+ with Pillow built with WebP support. The pinned Python in .tools/ has no Pillow, so run it with one
that does (`pip install Pillow`). The output is not committed: pagle-backend copies it from a pinned commit.
"""

import argparse
import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("export-web-art: needs Python 3.12 or later")

try:
    from PIL import features
except ImportError:
    sys.exit("export-web-art: needs Pillow (pip install Pillow); the pinned Python in .tools/ has none")
if not features.check("webp"):
    sys.exit("export-web-art: this Pillow was built without WebP support")

from pagle_data.web_art import ART_DIR, export  # noqa: E402 (after the checks, which must run first)


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Export the Prestige frames, emblems and Legend crests as web art.")
    parser.add_argument("--out", type=Path, default=root / "build" / "web-art", help="output folder (build/web-art/)")
    parser.add_argument("--art", type=Path, default=root / ART_DIR, help="the kit's sources (data/art/prestige/)")
    parser.add_argument("--only", nargs="+", metavar="KEY", help="export only these pieces and emblems")
    args = parser.parse_args(argv)
    try:
        written = export(args.art, args.out, args.only)
    except ValueError as error:
        print(f"export-web-art: {error}", file=sys.stderr)
        return 1
    out = args.out.resolve()
    for path in written:
        print(path.resolve().relative_to(out).as_posix())
    print(f"export-web-art: {len(written)} files in {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
