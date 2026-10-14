"""The Field report triage (DATA-R117): writes the comment the triage Action posts on a Field report issue, or edits
in place on later runs, from the issue and the default branch's data/.

    .tools/bin/python scripts/triage-field-report.py --event <event.json> --open-issues <open.json>
        --comments <comments.json> --out <folder>

It writes <folder>/comment.md and <folder>/result.json ({"comment": the Action's earlier comment's ID or null,
"needsInfo": true or false}). .github/workflows/field-report-triage.yml fetches the inputs with gh, runs it and
posts the comment. It downloads ItemSparse from wago.tools for the Uncharted items' names and never writes under
data/; scripts/check.sh never runs it: the gate never touches the network.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("triage-field-report: needs Python 3.12; run it as .tools/bin/python scripts/triage-field-report.py")

from pagle_data.triage import main  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], Path(__file__).resolve().parent.parent))
