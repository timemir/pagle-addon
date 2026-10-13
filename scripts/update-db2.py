"""Rewrites data/db2/ from one Forever build's DB2 tables on wago.tools (DATA-R11, DATA-R12).

    .tools/bin/python scripts/update-db2.py 1.60.1.70338

Run by hand, in a PR; then run scripts/generate-data.py and commit data/db2/ with the regenerated files (DATA-R61).
scripts/check.sh never runs it: the gate never touches the network.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("update-db2: needs Python 3.12; run it as .tools/bin/python scripts/update-db2.py")

from pagle_data.db2_update import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
