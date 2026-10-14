"""Field report parts for the tests: a PAGLE-REPORT part's text as Core writes it (REP-R30), the issue body the form
renders it in (DATA-R115), and the part or whole report parsed from it (DATA-R116). Every row is a fixture row."""

from collections.abc import Iterable

from pagle_data.errors import Problems
from pagle_data.observed import Report
from pagle_data.report import Part, join, parse_part

# The default fixture header's data (REP-R30) and reporter key (REP-R36): REP-R30's example's.
DATA = "3f9a2c1e"
REPORTER = "f38e76b0"


def header(n: int = 1, m: int = 1, *, data: str = DATA, locale: str = "enUS", reporter: str = REPORTER) -> str:
    """A part's header line (REP-R30): addon 0.9.0, then data, locale, reporter and part n of m."""
    return f"addon 0.9.0 data {data} locale {locale} reporter {reporter} part {n}/{m}"


HEADER = header()


def part_text(*rows: str, header: str = HEADER) -> str:
    """A PAGLE-REPORT part (REP-R30) with these rows, one per line, closed by END with no newline after it."""
    return "\n".join(["PAGLE-REPORT 1", header, *rows, "END"])


def part(
    rows: str = "", n: int = 1, m: int = 1, *, data: str = DATA, locale: str = "enUS", reporter: str = REPORTER
) -> str:
    """A PAGLE-REPORT part (REP-R30) as Core writes it, END and its newline last: rows is the row lines, each ending
    in a newline."""
    return part_text(*rows.splitlines(), header=header(n, m, data=data, locale=locale, reporter=reporter)) + "\n"


def issue_body(report: str) -> str:
    """An issue body as GitHub renders the issue form (DATA-R115) with report pasted: the report field in a text
    fence, then the notes field left empty."""
    return f"### Report\n\n```text\n{report}\n```\n\n### Anything you noticed?\n\n_No response_"


def parsed_part(text: str, source: str = "paste") -> Part:
    """One part parsed from text without problems."""
    problems = Problems()
    found = parse_part(text, source, problems)
    assert problems.found == []
    assert found is not None
    return found


def part_of(*rows: str, header: str = HEADER, source: str = "paste") -> Part:
    """A part with these rows under header, parsed without problems."""
    return parsed_part(part_text(*rows, header=header), source)


def parsed_report(text: str, issues: Iterable[int]) -> Report:
    """One whole report parsed from text, as data/observed/ holds it after importing issues (DATA-R121)."""
    problems = Problems()
    (field_report,) = join([parsed_part(text, "test")], problems)
    assert problems.found == []
    return field_report.observed(issues)
