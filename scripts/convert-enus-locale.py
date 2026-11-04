"""The one-time conversion of each addon's hand-written locale/enUS.lua into data/locale/enUS/*.toml (DATA-R114, #517).

    .tools/bin/python scripts/convert-enus-locale.py              convert, then run the generator
    .tools/bin/python scripts/convert-enus-locale.py --no-generate   write the TOML and the reference copies only

It writes data/locale/enUS/ (the header and one file per addon) and copies each hand-written file to
spec/fixtures/enUS-handwritten/, which spec/locale_enus_spec.lua compares the generated enUS.lua with. The generator then
writes addons/<Addon>/locale/enUS.lua and Locales.xml. The conversion is repeatable: after English changes on main, drop
the conversion commit, rebase, and run this again.

Runs on the pinned Python in .tools/ (scripts/setup.sh); it needs the Lua 5.1 there too.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("convert-enus-locale: needs Python 3.12; run it as .tools/bin/python scripts/convert-enus-locale.py")

from pagle_data.locale_convert import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
