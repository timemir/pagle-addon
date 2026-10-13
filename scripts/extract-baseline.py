"""The one-time extraction of VMaNGOS's fishing data into data/baseline/ (DATA-R9).

    .tools/bin/python scripts/extract-baseline.py <dump>

<dump> is VMaNGOS's db_latest SQLite release asset, db-sqlite-4641790.zip, from the dev's audit archive. Its
SHA-256 is checked first; the zip is only read. Run once: it refuses to touch an existing data/baseline/.
Then run scripts/generate-data.py and commit data/baseline/ with the regenerated files (DATA-R61).
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("extract-baseline: needs Python 3.12; run it as .tools/bin/python scripts/extract-baseline.py")

from pagle_data.extract_baseline import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
