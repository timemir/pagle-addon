#!/usr/bin/env python3
"""Update the script specs' SavedVariables fixtures to Catch log format 3.

Run from the repository root. Existing line endings and unrelated bytes stay exact.
The script is idempotent and only changes test fixtures and their literal expectations.
"""

from pathlib import Path
import re


def migrate(data: bytes) -> bytes:
    data = data.replace(b'["format"] = 2,', b'["format"] = 3,')
    data = re.sub(
        rb'"(B1\|[^"\r\n]+)"',
        lambda match: b'"' + match[1] + b'|pagle-2026a"'
        if match[1].count(b"|") == 5
        else match[0],
        data,
    )
    data = data.replace(b"P1|1|1791800400|0|1\"", b"P1|1|1791800400|0|1|0\"")
    data = data.replace(b"Ledger|start|v1", b"Ledger|title|title:level1")
    return data.replace(b"Hunts|note|U1|", b"Hunts|def|p_note|1/1|U1|")


for path in sorted(Path("spec/scripts/fixtures/WTF").rglob("Pagle.lua*")):
    before = path.read_bytes()
    after = migrate(before)
    if after != before:
        path.write_bytes(after)
        print(path)

path = Path("spec/scripts/fixtures/WTF/Account/M7#1/SavedVariables/Pagle_TackleBoard.lua")
path.write_bytes(path.read_bytes().replace(b'["rulesVersion"] = 3002,', b'["rulesVersion"] = 6002,'))

for name in ["make-test-log", "read-wtf", "read-wtf-exit-check", "rewrite-bindings"]:
    path = Path(f"spec/scripts/{name}_spec.lua")
    before = path.read_bytes()
    after = migrate(before).replace(b"format 2", b"format 3")
    after = after.replace(b"assert.are.equal(2, log.format)", b"assert.are.equal(3, log.format)")
    after = after.replace(b"3002", b"6002").replace(b"TKB_RULES_VERSION 3", b"TKB_RULES_VERSION 6")
    if after != before:
        path.write_bytes(after)
        print(path)
