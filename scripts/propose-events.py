"""Drafts candidate Hunt Event files from a zone's loot for people to curate (DATA-R99, hunts.md › The 1.0 event pool).

    .tools/bin/python scripts/propose-events.py --zone <areaID> [--zone <areaID>] [--out <dir>]

One zone, or two zones of one band. It writes one <event-id>.toml per draft to --out (default a dated folder under
the system temp directory, never under data/) and prints each Hunt's expected minutes per tier; it never commits.
Curate a draft, write its {TODO ...} lore, check it with scripts/check-event.py and copy it to data/hunts/events/.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("propose-events: needs Python 3.12; run it as .tools/bin/python scripts/propose-events.py")

from pagle_data.propose_events import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
