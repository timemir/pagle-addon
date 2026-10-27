"""Draws the Curio crate's art kit into one atlas (wallet-and-shop.md › Motion, "A crate opens"): the crate in parts, the
plaque, the reel, the cards, the kinds' emblems, the Curio card, the coin card and the effects.

    .tools/bin/python scripts/crate-art.py            # draw it all, write the three files below
    .tools/bin/python scripts/crate-art.py --sheet <crate-sheet.png>   # also a contact sheet of the sprites (not committed)

then StyLua the sprite table (.tools/bin/stylua addons/Pagle/data/CrateArt.lua). Writes data/art/crate/tga/Crate.tga (the
atlas, lossless, the source), addons/Pagle/media/crate/Crate.blp (BLP2, DXT5, with its mipmaps, by scripts/encode-blp.py
--mips) and addons/Pagle/data/CrateArt.lua (where each sprite is, how big it is meant to be, and what it is for). Commit
what it writes. The sounds are scripts/render-crate-sounds.py's.

The drawings are data/art/crate/src/*.svg, the prototype's own art (prototypes/curio-crate/) where it is SVG and its CSS
written out as SVG where it isn't; edit those, not the output. Rasterising is resvg's (the resvg-py wheel in
PYTHON_PACKAGES, scripts/setup.sh installs it), the same on every machine to within a rounding of the texel; the fans of
rays are drawn with numpy. tests/test_crate_art.py checks the committed files against each other and against a fresh draw.
pagle_data/crate_art.py has the details.
"""

import argparse
import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("crate-art: needs Python 3.12; run it as .tools/bin/python scripts/crate-art.py")

from pagle_data.crate_art import build, contact_sheet  # noqa: E402 (after the version check, which must run first)


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Draw the Curio crate's art kit.")
    parser.add_argument("--sheet", type=Path, help="also write a contact sheet of the sprites here (not committed)")
    args = parser.parse_args(argv)
    for path in build(root):
        print(path.relative_to(root).as_posix())
    if args.sheet:
        contact_sheet(root, args.sheet)
        print(args.sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
