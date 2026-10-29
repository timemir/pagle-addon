"""Draws the Refresh ticket's icon (#466) into its atlas, for the Tackle Board and for Core.

    .tools/bin/python scripts/ticket-art.py

then StyLua the two sprite tables (.tools/bin/stylua addons/Pagle/data/TicketArt.lua addons/Pagle_TackleBoard/data/TicketArt.lua).
Writes data/art/ticket/tga/Ticket.tga (the atlas, lossless, the source), addons/Pagle_TackleBoard/media/board/Ticket.blp and
addons/Pagle/media/ticket/Ticket.blp (BLP2, uncompressed BGRA with its mipmaps, by scripts/encode-blp.py --raw) and the two
sprite tables addons/Pagle_TackleBoard/data/TicketArt.lua and addons/Pagle/data/TicketArt.lua. Commit what it writes.

The drawing is data/art/ticket/src/ticket.svg; edit that, not the output. Rasterising is resvg's (the resvg-py wheel in
PYTHON_PACKAGES, scripts/setup.sh installs it). tests/test_ticket_art.py checks the committed files against each other and
against a fresh draw. pagle_data/ticket_art.py has the details.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("ticket-art: needs Python 3.12; run it as .tools/bin/python scripts/ticket-art.py")

from pagle_data.ticket_art import build  # noqa: E402 (after the version check, which must run first)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    for path in build(root):
        print(path.relative_to(root).as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
