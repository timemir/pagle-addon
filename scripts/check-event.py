"""Checks one Hunt Event file or one pushed huntEvent item against the committed data (DATA-R99).

    .tools/bin/python scripts/check-event.py <file>

<file> is an <event-id>.toml (DATA-R97) or a pushed huntEvent item as JSON (.json, hunts.md › Contracts). It runs the
generator's DATA-R97 and DATA-R99 checks on it against the committed catalogue, Hunt list and event pool, and
prints each failure on its own line in the generator's words. Exit 0: it passes; 1: it fails a check; 2: the
committed data itself fails the generator. pagle-backend runs it on a p_ definition before pushing it.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("check-event: needs Python 3.12; run it as .tools/bin/python scripts/check-event.py")

from pagle_data.check_event import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
