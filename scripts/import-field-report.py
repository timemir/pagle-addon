"""Imports Field report issues into data/observed/reports/ and prints what they change in the catalogue
(DATA-R119–R121).

    .tools/bin/python scripts/import-field-report.py <issue> [<issue> ...]

Run by hand from WSL (gh lives there; docs/agents/issue-tracker.md), giving every part's issue of each report. It
writes data/observed/reports/<reporterKey>.toml, runs scripts/generate-data.py and prints the changes, the "Closes"
line for the PR and what to commit with it (DATA-R120). scripts/check.sh never runs it: the gate never touches the
network.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("import-field-report: needs Python 3.12; run it as .tools/bin/python scripts/import-field-report.py")

from pagle_data.importer import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
