"""Rewrites Pagle's interface text to the text helper (CORE-R8, DATA-R114, #519). See pagle_data/text_convert.py."""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("convert-text: needs Python 3.12; run it as .tools/bin/python scripts/convert-text.py")

from pagle_data.text_convert import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
