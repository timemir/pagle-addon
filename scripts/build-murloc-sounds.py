"""Builds the Mrglglgl sound set (ANN-R74) from the game's murloc clips into addons/Pagle/media/sounds/mrglglgl/.

    WOW_MURLOC_DIR=<wow.export>/sound/creature/murloc .tools/bin/python scripts/build-murloc-sounds.py

The clips are Blizzard's and aren't in the repo; see pagle_data/murloc_sounds.py. Commit what it writes.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("build-murloc-sounds: needs Python 3.12; run it as .tools/bin/python scripts/build-murloc-sounds.py")

from pagle_data.murloc_sounds import build  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for path in build(root):
        print(path.relative_to(root).as_posix())
