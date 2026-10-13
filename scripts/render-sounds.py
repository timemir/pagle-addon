"""Renders Pagle's own Announcement sounds (ANN-R72, ANN-R74) into addons/Pagle/media/sounds/.

    .tools/bin/python scripts/render-sounds.py

Runs on the pinned Python in .tools/ (scripts/setup.sh installs numpy and soundfile). Commit what it writes: the
files ship as they are, and scripts/check.sh checks their format and loudness but doesn't re-render them.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("render-sounds: needs Python 3.12; run it as .tools/bin/python scripts/render-sounds.py")

from pagle_data.sounds import SOUNDS_DIR, render  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for path in render(root / SOUNDS_DIR):
        print(path.relative_to(root).as_posix())
