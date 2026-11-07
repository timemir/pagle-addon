"""Pagle's content generator (DATA-R60): reads data/ and writes the generated files.

    .tools/bin/python scripts/generate-data.py            rewrite every generated file
    .tools/bin/python scripts/generate-data.py --check    write nothing; fail if a generated file is out of date
    .tools/bin/python scripts/generate-data.py --propose-aliases
                                                          write nothing; print the uncommitted alias candidates
    .tools/bin/python scripts/generate-data.py --min-build <n>
                                                          write nothing; print the facts that would lose
                                                          confirmation if only builds >= n counted
    .tools/bin/python scripts/generate-data.py --explain <itemID|areaID>
                                                          write nothing; print every layer's value for it and
                                                          which won
    .tools/bin/python scripts/generate-data.py --translators [--since <tag>]
                                                          write nothing; print the CHANGELOG's TRANSLATORS block
                                                          from the listed Locales' headers (with --since, only
                                                          for those whose translations changed since that tag)
    .tools/bin/python scripts/generate-data.py --check-changelog <version> [--since <tag>]
                                                          write nothing; fail if that release's CHANGELOG entry
                                                          lacks a TRANSLATORS line for a language whose
                                                          translations changed since the previous release tag,
                                                          or credits one whose translations did not
    .tools/bin/python scripts/generate-data.py --stale    write nothing; list, per Locale, every translated string
                                                          (interface and Lore) whose EN snapshot is not today's English,
                                                          as same fields or fields changed; --json for a script
    .tools/bin/python scripts/generate-data.py --drop-stale
                                                          remove the fields-changed strings from the Locales' TOML so
                                                          English shows for them, then regenerate; run it in the PR
                                                          that changes English
    .tools/bin/python scripts/generate-data.py --stale-issue <code>
                                                          write nothing; print the body of that Locale's "translations
                                                          stale" issue (--json adds the title and the counts)
    .tools/bin/python scripts/generate-data.py --lock     rewrite data/hunts/released.lock from the Hunt list and
                                                          nothing else; only when a release is tagged, from 1.0 on

Runs on the pinned Python in .tools/ (scripts/setup.sh); scripts/check.sh runs --check as its generator stage.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("generate-data: needs Python 3.12; run it as .tools/bin/python scripts/generate-data.py")

from pagle_data.cli import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
