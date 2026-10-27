"""Builds Pagle's generated Announcement sounds (ANN-R74) from their raw takes into addons/Pagle/media/sounds/.

    .tools/bin/python scripts/build-generated-sounds.py

Runs on the pinned Python in .tools/, like render-sounds.py. Commit what it writes.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("build-generated-sounds: needs Python 3.12; run it as .tools/bin/python scripts/build-generated-sounds.py")

from pagle_data.generated_sounds import build  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for path in build(root):
        print(path.relative_to(root).as_posix())
