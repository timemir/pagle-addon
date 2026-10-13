"""The Field report parser (DATA-R116): the PAGLE-REPORT format exactly as REP-R30–R33 define it, read from the golden
reports in fixtures/reports/ that Core's busted spec writes too (#122), its parts joined into one report, its rows in
data/observed/'s shape (DATA-R121), and the report field of an issue as GitHub renders the form (DATA-R115)."""

from collections.abc import Iterable
from dataclasses import replace
from pathlib import Path

import pytest

from observed_fixture import write_observed
from pagle_data.errors import At, Problems
from pagle_data.observed import CatchRow, PoolTextRow, SkillRow, read_observed
from pagle_data.report import FieldReport, Identity, Part, join, observed_toml, parse_part, report_field

FIXTURES = Path(__file__).parent / "fixtures"
HEADER = "addon 0.9.0 data 3f9a2c1e locale enUS reporter f38e76b0 part 1/1"


def golden(name: str) -> str:
    return (FIXTURES / "reports" / name).read_text(encoding="utf-8")


def part_of(*rows: str, header: str = HEADER, source: str = "paste") -> Part:
    """A part with the rows given, parsed without problems."""
    problems = Problems()
    part = parse_part("\n".join(["PAGLE-REPORT 1", header, *rows, "END"]), source, problems)
    assert problems.found == []
    assert part is not None
    return part


def parsed(text: str) -> Part:
    problems = Problems()
    part = parse_part(text, "paste", problems)
    assert problems.found == []
    assert part is not None
    return part


def unplaced[Row: (CatchRow, SkillRow, PoolTextRow)](rows: Iterable[Row]) -> list[Row]:
    """rows without where they were read, to compare rows read from different places."""
    return [replace(row, at=At("")) for row in rows]


def problems_of(text: str) -> list[str]:
    problems = Problems()
    assert parse_part(text, "#7", problems) is None
    return problems.found


def test_rep_r30_s_example_parses_into_its_header_and_six_rows() -> None:
    # REP-R30: line 1 the format version; line 2 addon, data, locale, reporter and part; the rows (REP-R20–R22);
    # END. The comments (" # " and the names after it) are left out (REP-R31).
    part = parsed(golden("rep-r30.txt"))
    header = part.header
    assert (header.addon, header.data, header.locale, header.reporter) == ("0.9.0", "3f9a2c1e", "deDE", "f38e76b0")
    assert (header.part, header.parts) == (1, 1)
    assert [(r.item, r.area, r.build, r.count, r.auras, r.events, r.t, r.m) for r in part.catches] == [
        (6362, 33, 70338, 2, (1280341,), (), None, None),
        (13755, 331, 70338, 6, (), (301,), 14 * 60 + 30, 5),
        (6359, 1519, 70338, 14, (), (), None, None),
        (13760, 2657, 70338, 3, (), (), 21 * 60 + 15, 11),
    ]
    assert [(k.area, k.build, k.casts, k.away, k.land, k.lost) for k in part.skills] == [(1519, 70338, 40, 6, 75, 60)]
    assert [(p.area, p.locale, p.text, p.casts, p.items) for p in part.pool_texts] == [
        (1519, "deDE", "Schwarm öliger Schwarzmaulfische", 5, ((6358, 5),))
    ]
    # Each row is at its line, and I and K rows carry the header's reporter key (REP-R36).
    assert [str(row.at) for row in part.catches] == [f"paste: line {n}" for n in (3, 4, 5, 6)]
    assert {r.reporter for r in part.catches} | {k.reporter for k in part.skills} == {"f38e76b0"}


def test_a_quoted_text_keeps_its_hash_and_its_escapes() -> None:
    # REP-R31: " # " starts a comment only outside double quotes. REP-R32: inside quotes, \ escapes ", \ and n.
    part = parsed(golden("quotes.txt"))
    assert [p.text for p in part.pool_texts] == [
        'School of "Oily" Blackmouth # not a comment',
        "back\\slash\nsecond line",
    ]
    assert [(p.casts, p.items) for p in part.pool_texts] == [(2, ((6358, 2),)), (1, ())]


def test_k_and_p_rows_leave_out_their_optional_fields() -> None:
    # REP-R21: land or lost is left out when there is no such Cast. REP-R22: a P row's Casts may all have got away,
    # leaving no items. The items come out ascending by item ID.
    part = part_of("K 40 70338 casts=3 away=3 lost=12", 'P 40 enUS "Bobber" casts=4 6358x2 6303x1')
    assert [(k.casts, k.away, k.land, k.lost) for k in part.skills] == [(3, 3, None, 12)]
    assert [p.items for p in part.pool_texts] == [((6303, 1), (6358, 2))]


def test_crlf_line_ends_and_stray_blank_lines_read_the_same() -> None:
    # DATA-R115: a paste through the issue form may come back with CRLF line ends; a blank line is no row.
    text = golden("rep-r30.txt").replace("\n", "\n\n").replace("\n", "\r\n")
    spaced, plain = parsed(text), parsed(golden("rep-r30.txt"))
    assert spaced.header == plain.header
    assert unplaced(spaced.catches) == unplaced(plain.catches)
    assert unplaced(spaced.pool_texts) == unplaced(plain.pool_texts)
    assert str(spaced.pool_texts[0].at) == "paste: line 15"  # problems still name the line as pasted


def test_an_unknown_key_and_an_unknown_row_letter_are_ignored() -> None:
    # REP-R31: parsers ignore unknown key=value keys (adding a key needs no version bump) and unknown row letters.
    part = part_of(
        "I 6362 33 70338 2 aura=1280341 depth=9 # a key a later Core may add",
        "K 1519 70338 casts=40 away=6 lure=yes",
        'P 1519 enUS "Oily" casts=5 6358x5 seen="at dusk"',
        "Z 1 2 3 # a row kind a later Core may add",
    )
    assert [(r.item, r.auras) for r in part.catches] == [(6362, (1280341,))]
    assert [(k.area, k.casts) for k in part.skills] == [(1519, 40)]
    assert [p.text for p in part.pool_texts] == ["Oily"]


def report_of(*rows: str) -> str:
    return "\n".join(["PAGLE-REPORT 1", HEADER, *rows, "END"])


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        # A first line other than PAGLE-REPORT 1 (REP-R30).
        ("PAGLE-REPORT 2\n" + HEADER + "\nEND", "#7: line 1: expected 'PAGLE-REPORT 1', got 'PAGLE-REPORT 2'"),
        ("Hi! Here is my report:\n" + report_of(), "#7: line 1: expected 'PAGLE-REPORT 1'"),
        # A malformed header (REP-R30, REP-R33, REP-R36).
        ("PAGLE-REPORT 1\naddon 0.9.0 data 3f9a2c1e locale enUS part 1/1\nEND", "#7: line 2: a malformed header"),
        ("PAGLE-REPORT 1\n" + HEADER.replace("3f9a2c1e", "3F9A2C1E") + "\nEND", "#7: line 2: a malformed header"),
        ("PAGLE-REPORT 1\n" + HEADER.replace("enUS", "english") + "\nEND", "#7: line 2: a malformed header"),
        ("PAGLE-REPORT 1\n" + HEADER.replace("f38e76b0", "f38e76b") + "\nEND", "#7: line 2: a malformed header"),
        ("PAGLE-REPORT 1\n" + HEADER.replace("1/1", "3/2") + "\nEND", "#7: line 2: a malformed header"),
        # A missing field and a non-integer field (REP-R20–R22).
        (report_of("I 6362 33 70338"), "#7: line 3: missing fields"),
        (report_of("I 6362 33 70338 two"), "#7: line 3: count: expected an integer, got 'two'"),
        (report_of("I 6362 33 70338 2 aura=1280341,x"), "#7: line 3: aura=: expected an integer, got 'x'"),
        (report_of("I 6362 33 70338 2 t=14:30 m=May"), "#7: line 3: m=: expected an integer, got 'May'"),
        (report_of("K 1519 70338 away=6"), "#7: line 3: missing field casts="),
        (report_of("K 1519 70338 casts=40 away=6 land=high"), "#7: line 3: land=: expected an integer"),
        (report_of('P 1519 enUS "Oily" casts=5 6358xfive'), "#7: line 3: expected <itemID>x<count>"),
        (report_of("P 1519 enUS casts=5"), "#7: line 3: missing fields"),
        # A bad quote escape (REP-R32), and a quote never closed.
        (report_of('P 1519 enUS "Oily \\t" casts=5'), "#7: line 3: a bad quote escape '\\t'"),
        (report_of('P 1519 enUS "Oily casts=5'), "#7: line 3: a quote isn't closed"),
        # Two rows with the same key (DATA-R121): I by everything but count, K by area and build, P by area, locale
        # and text.
        (report_of("I 6359 1519 70338 14", "I 6359 1519 70338 2 # again"), "#7: line 4: the same row key as line 3"),
        (report_of("K 1519 70338 casts=4 away=0", "K 1519 70338 casts=9 away=1"), "#7: line 4: the same row key"),
        (report_of('P 1519 enUS "Oily" casts=5', 'P 1519 enUS "Oily" casts=1'), "#7: line 4: the same row key"),
    ],
)
def test_each_failure_fails_the_part_naming_its_line(text: str, expected: str) -> None:
    # DATA-R116: a part fails on a first line other than PAGLE-REPORT 1, a malformed header, a row with missing or
    # non-integer fields, a bad quote escape and two rows with the same key; the problem names the line.
    found = problems_of(text)
    assert any(problem.startswith(expected) for problem in found), found


def test_a_part_without_end_reads_as_truncated() -> None:
    # DATA-R116, REP-R30: END closes every part, so a truncated paste is detected. The problem names the last line.
    text = golden("rep-r30.txt").removesuffix("END\n")
    assert problems_of(text) == ["#7: line 8: no END after this line: the paste is truncated (REP-R30)"]


def test_rows_with_different_aura_lists_are_different_rows() -> None:
    # DATA-R121: the I row key holds the auras and events, so aura=5 and aura=5,7 are two rows, not a duplicate.
    part = part_of("I 6359 1519 70338 1 aura=5", "I 6359 1519 70338 1 aura=5,7", "I 6359 1519 70338 1")
    assert [r.auras for r in part.catches] == [(5,), (5, 7), ()]


# Parts (REP-R33, DATA-R116, DATA-R117)

PART_1 = "addon 0.9.0 data 3f9a2c1e locale enUS reporter f38e76b0 part 1/2"
PART_2 = "addon 0.9.0 data 3f9a2c1e locale enUS reporter f38e76b0 part 2/2"


def joined(*parts: Part) -> list[FieldReport]:
    problems = Problems()
    reports = join(parts, problems)
    assert problems.found == []
    return reports


def test_two_parts_of_one_report_join_in_order() -> None:
    # DATA-R116: the parts of one report share the header except part and are joined in order (REP-R33: rows fill
    # each part in sort order). Given part 2 first, the rows still come out part 1's first.
    first = part_of("I 6359 1519 70338 14", header=PART_1, source="#11")
    second = part_of("K 1519 70338 casts=40 away=6", 'P 1519 enUS "Oily" casts=5', header=PART_2, source="#12")
    (report,) = joined(second, first)
    assert report.complete
    assert [part.source for part in report.parts] == ["#11", "#12"]
    assert [r.item for r in report.catches] == [6359]
    assert [(k.area, k.build) for k in report.skills] == [(1519, 70338)]
    assert [p.text for p in report.pool_texts] == ["Oily"]


def test_a_report_with_a_part_missing_is_incomplete() -> None:
    # DATA-R116: a report with a part missing is incomplete, and the caller is told which part.
    (report,) = joined(part_of("I 6359 1519 70338 14", header=PART_2))
    assert not report.complete
    assert report.missing == (1,)


def test_parts_with_different_identities_are_not_joined() -> None:
    # DATA-R117: a report's identity is the header without part: addon, data, locale, reporter and part count. Parts
    # differing in any of them belong to different reports.
    first = part_of("I 6359 1519 70338 14", header=PART_1)
    newer = part_of("I 6362 33 70338 2", header=PART_2.replace("data 3f9a2c1e", "data 0badcafe"))
    reports = joined(first, newer)
    assert [report.identity for report in reports] == [
        Identity("0.9.0", "3f9a2c1e", "enUS", "f38e76b0", 2),
        Identity("0.9.0", "0badcafe", "enUS", "f38e76b0", 2),
    ]
    assert [report.missing for report in reports] == [(2,), (1,)]
    assert first.header.identity == reports[0].identity


def test_a_part_pasted_twice_counts_once_unless_its_rows_differ() -> None:
    # DATA-R116: parts are joined, not doubled: the same part from two issues is one part; two different parts
    # with the same number can't both be the report's, which is a problem naming the later one.
    row = "I 6359 1519 70338 14"
    (report,) = joined(part_of(row, header=PART_1, source="#11"), part_of(row, header=PART_1, source="#13"))
    assert [part.source for part in report.parts] == ["#11"]
    problems = Problems()
    other = part_of("I 6362 33 70338 2", header=PART_1, source="#13")
    join([part_of(row, header=PART_1, source="#11"), other], problems)
    assert problems.found == ["#13: part 1/2 again, with other rows than in #11"]


# data/observed/'s shape (DATA-R121, #94's reader)


def test_rows_converted_to_the_observed_shape_read_back_equal(tmp_path: Path) -> None:
    # DATA-R121, the Data section's data/observed/ table: the importer writes reports/<reporterKey>.toml with
    # issues, the header and [[i]], [[k]], [[p]] rows; pagle_data.observed (#94) reads them back as the same rows.
    # REP-R30's example, plus the quotes golden's escaped texts and a rejected mark the importer keeps.
    rep_r30, quotes = parsed(golden("rep-r30.txt")), parsed(golden("quotes.txt"))
    (report,) = joined(rep_r30)
    stored = report.observed([7, 9])
    stored = replace(stored, pool_texts=stored.pool_texts + quotes.pool_texts)
    stored = replace(stored, catches=(replace(stored.catches[0], rejected='a "client" bug'), *stored.catches[1:]))
    write_observed(tmp_path, reports={"f38e76b0": observed_toml(stored)})
    problems = Problems()
    layer = read_observed(tmp_path, problems)
    assert problems.found == []
    read = layer.reports["f38e76b0"]
    assert (read.key, read.issues, read.header) == (stored.key, (7, 9), stored.header)
    assert unplaced(read.catches) == unplaced(stored.catches)
    assert unplaced(read.skills) == unplaced(stored.skills)
    assert unplaced(read.pool_texts) == unplaced(stored.pool_texts)
    assert len(read.catches) == 4 and len(read.skills) == 1 and len(read.pool_texts) == 3


def test_the_observed_shape_writes_t_as_hh_mm() -> None:
    # The Data section's data/observed/ table and #94's reader: t is "HH:MM", the 15-minute bucket's start.
    (report,) = joined(part_of("I 13755 331 70338 6 event=301 t=04:15 m=5"))
    assert 't = "04:15"\nm = 5\n' in observed_toml(report.observed([1]))


# The issue form (DATA-R115)


def test_the_form_helper_pulls_the_report_field_out_of_an_issue_body() -> None:
    # DATA-R115: the report field is a textarea rendered as a code block. GitHub renders the form's fields as
    # "### <label>" sections; the helper returns the paste without its fence or the blank lines around it, whether
    # the body comes with LF or CRLF line ends. The body is the form's rendering as GitHub documents it (#127 adds
    # the form itself).
    body = (FIXTURES / "issues" / "rep-r30.md").read_text(encoding="utf-8")
    expected = golden("rep-r30.txt").removesuffix("\n")
    assert report_field(body) == expected
    assert report_field(body.replace("\n", "\r\n")) == expected
    assert parsed(expected).header.reporter == "f38e76b0"


def test_the_form_helper_finds_no_report_in_a_body_without_the_field() -> None:
    # DATA-R115: an issue not made with the form has no report field.
    assert report_field("I caught a fish!\r\n\r\n### Notes\r\n\r\nnone") is None
