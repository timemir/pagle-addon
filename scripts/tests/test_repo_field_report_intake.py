"""The repo's Field report intake files: the issue form (DATA-R115) and the triage workflow (DATA-R117). The
standard library has no YAML reader, so the files are checked as text, block by block; actionlint lints the workflow
(#127's hand-off), and only a real issue filed through the form shows GitHub's rendering."""

import re
from pathlib import Path

from pagle_data.report import REPORT_LABEL, report_field

REPO = Path(__file__).resolve().parents[2]
FORM = REPO / ".github" / "ISSUE_TEMPLATE" / "field-report.yml"
WORKFLOW = REPO / ".github" / "workflows" / "field-report-triage.yml"
FIXTURES = Path(__file__).resolve().parent / "fixtures" / "issues"


def fields() -> dict[str, str]:
    """The form's body fields by id, each the text of its block."""
    text = FORM.read_text(encoding="utf-8")
    blocks = re.split(r"\n  - type: ", text.split("\nbody:\n", 1)[1])
    found: dict[str, str] = {}
    for block in blocks:
        named = re.search(r"^    id: (\S+)$", block, re.MULTILINE)
        if named is not None:
            found[named[1]] = block
    return found


def test_the_form_has_data_r115_s_title_labels_and_description() -> None:
    # DATA-R115: the file REP-R46's URL names, title "Field report", labels field-report and needs-triage; its
    # description says a report in several parts is filed as one issue per part, and DATA-R123: a report posted
    # anywhere else reaches Pagle only when the dev pastes it into an issue.
    text = FORM.read_text(encoding="utf-8")
    assert "https://github.com/timemir/wow-fish/issues/new?template=field-report.yml" in text
    assert re.search(r"^title: Field report$", text, re.MULTILINE)
    assert re.search(r'^labels: \["field-report", "needs-triage"\]$', text, re.MULTILINE)
    description = " ".join(text.split("\nbody:\n", 1)[0].split())
    assert "one issue per part" in description
    assert "A report posted anywhere else reaches Pagle only when the dev pastes it into an issue." in description


def test_the_form_has_the_report_notes_and_public_fields() -> None:
    # DATA-R115: report, a required textarea rendered as a code block (labelled as report_field() looks for it);
    # notes, "Anything you noticed?", optional; public, a required checkbox "I understand this is posted publicly".
    found = fields()
    assert set(found) == {"report", "notes", "public"}
    report = found["report"]
    assert report.startswith("textarea\n")
    assert f"\n      label: {REPORT_LABEL}\n" in report
    assert "\n      render: text\n" in report
    assert report.rstrip().endswith("validations:\n      required: true")
    notes = found["notes"]
    assert notes.startswith("textarea\n") and "\n      label: Anything you noticed?\n" in notes
    assert notes.rstrip().endswith("required: false")
    public = found["public"]
    assert public.startswith("checkboxes\n")
    assert "\n        - label: I understand this is posted publicly\n          required: true" in public


def test_the_recorded_issue_bodies_have_the_forms_fields() -> None:
    # DATA-R115: the fixture bodies stand for the form's rendering: a "### <label>" heading per field, the report
    # fenced.
    # rep-r30.md is in GitHub's exact shape for this form (test_report.py); a body recorded from a real issue is
    # still to come.
    labels = ["### Report", "### Anything you noticed?", "### Public"]
    for name in ("triage-clean.md", "rep-r30.md", "uncharted.md"):
        body = (FIXTURES / name).read_text(encoding="utf-8")
        assert [line for line in body.splitlines() if line.startswith("### ")] == labels, name
        assert (report_field(body) or "").startswith("PAGLE-REPORT 1\n"), name


def test_the_workflow_runs_on_field_report_issues_with_the_token_alone() -> None:
    # DATA-R117: on issues labelled field-report, when opened or edited; GITHUB_TOKEN only, with issues: write and
    # contents: read; it runs the triage script and creates the field-report and needs-info labels if missing.
    text = WORKFLOW.read_text(encoding="utf-8")
    assert "on:\n  issues:\n    types: [opened, edited]\n" in text
    assert "permissions:\n  contents: read\n  issues: write" in text
    assert "if: contains(github.event.issue.labels.*.name, 'field-report')" in text
    assert "secrets." not in text
    assert "python scripts/triage-field-report.py" in text
    assert "gh label create field-report" in text and "gh label create needs-info" in text
    # The issue's body is untrusted: it reaches the script only through the event file, never the run lines.
    assert "github.event.issue.body" not in text
