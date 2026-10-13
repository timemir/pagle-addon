"""The DB2 watch (DATA-R128 to DATA-R130): looks on wago.tools for a Forever build newer than data/db2/'s and, when
there is one, writes the issue listing what changed in the DB2 tables Pagle watches.

    .tools/bin/python scripts/db2-watch.py --out <folder> [--issues <issues.json>]

It writes <folder>/title.txt and <folder>/body.md, or nothing when there's no newer build or an issue in
<issues.json> (`gh issue list --state all --json number,title`) already has the title. .github/workflows/db2-watch.yml
runs it weekly and opens the issue. It never edits data/ (DATA-R130); scripts/check.sh never runs it: the gate never
touches the network.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("db2-watch: needs Python 3.12; run it as .tools/bin/python scripts/db2-watch.py")

from pagle_data.db2_watch import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
