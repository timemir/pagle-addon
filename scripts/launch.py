"""The launch-night kit (docs/agents/launch-runbook.md, #383): the runbook's prepared steps, so launch night only
fills in numbers.

    .tools/bin/python scripts/launch.py watch [--live-build N] [--every SECONDS]
    .tools/bin/python scripts/launch.py interface <n> [--dry-run]
    .tools/bin/python scripts/launch.py dump <commit> <version> <build> [--annotations <commit>]
    .tools/bin/python scripts/launch.py angleur-stub <Interface/AddOns folder> [--remove]
    .tools/bin/python scripts/launch.py post-tag <tag> [--zip <file>] [--local <scripts/package.sh's zip>]
    .tools/bin/python scripts/launch.py read [<step>] [--list] [--env <launch.env>] [--account <folder>]
        [--character <realm>/<Name-Surname>] [--expect-casts N] [--since T] [-- <more read-wtf.sh arguments>]

Run it in WSL. `watch` and `post-tag` fetch with unauthenticated curl; `read` runs scripts/read-wtf.sh and reads
launch.env (~/pagle-launch.env, or $PAGLE_LAUNCH_ENV), which stays outside the repo: it names the dev's account.
scripts/check.sh never runs it.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("launch: needs Python 3.12; run it as .tools/bin/python scripts/launch.py")

from pagle_data.launch import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
