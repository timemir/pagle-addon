"""Writes a hand-made Pagle_Content, the companion's data addon (PUSH-R1, PUSH-R2), for a dev test or a spec fixture.

    scripts/pushed-content.py <payload> --key-id <keyId> --seq <n> [--generated-at <t>] [--expires <t>] [--v <n>]
        [--sign <private.pem>] (--out <AddOns folder> | --table)

<payload> is a file holding the payload's bytes exactly, in the grammar of docs/spec/core/pushed-content.md › The
payload. The header fields are integers but keyId, 1 to 32 of A-Z, a-z, 0-9, _ and - (PUSH-R2); --generated-at defaults to now and --expires to a week after it,
both Unix seconds.

--sign signs `v|generatedAt|keyId|seq|expires|` followed by the payload's bytes (PUSH-R11) with the openssl command
(SHA256withRSA, PKCS#1 v1.5); without it the file is unsigned and has no `sig`, which Core reports absent (PUSH-R13).
Only the TEST ONLY key under spec/Pagle/fixtures/signing/ signs anything here: Core ships no key that checks it, so a
file signed with it passes only in a local-only build that adds the test key to logic/PushedKeys.lua.

--out writes <AddOns folder>/Pagle_Content/, its TOC (## Interface: and ## AllowLoadGameType: copied from
addons/Pagle/Pagle.toc, ## Dependencies: Pagle) and its one data file, which sets PagleContentData. --table prints the
PagleContentData table alone, for scripts/make-content-fixtures.sh.
"""

import argparse
import base64
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGLE_TOC = ROOT / "addons" / "Pagle" / "Pagle.toc"
WEEK = 7 * 24 * 3600
# keyId's form (PUSH-R2), the backend's: no "|", so the canonical header (PUSH-R11) reads one way.
KEY_ID = re.compile(r"[A-Za-z0-9_-]{1,32}")


def header(v: int, generated_at: int, key_id: str, seq: int, expires: int) -> bytes:
    """The canonical header the signature covers, before the payload's bytes (PUSH-R11)."""
    return f"{v}|{generated_at}|{key_id}|{seq}|{expires}|".encode()


def sign(message: bytes, pem: str) -> bytes:
    """openssl dgst -sha256 -sign over `message`: an RSA PKCS#1 v1.5 SHA-256 signature, deterministic."""
    return subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", pem], input=message, check=True, capture_output=True
    ).stdout


def table(fields: list[tuple[str, int | str]], indent: str) -> str:
    """A Lua table constructor of `fields` in order, one per line."""
    lines = ["{"]
    for name, value in fields:
        text = f'"{value}"' if isinstance(value, str) else str(value)
        lines.append(f"{indent}\t{name} = {text},")
    lines.append(f"{indent}}}")
    return "\n".join(lines)


def toc() -> str:
    """Pagle_Content's TOC (PUSH-R1): the client fields copied from Pagle.toc, loaded after Pagle."""
    copied = [
        line
        for line in PAGLE_TOC.read_text().splitlines()
        if line.startswith("## Interface:") or line.startswith("## AllowLoadGameType:")
    ]
    return "\n".join([*copied, "## Title: Pagle_Content", "## Dependencies: Pagle", "", "Content.lua", ""])


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("payload")
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--seq", type=int, required=True)
    parser.add_argument("--generated-at", type=int)
    parser.add_argument("--expires", type=int)
    parser.add_argument("--v", type=int, default=1)
    parser.add_argument("--sign", metavar="PEM")
    where = parser.add_mutually_exclusive_group(required=True)
    where.add_argument("--out", metavar="ADDONS")
    where.add_argument("--table", action="store_true")
    args = parser.parse_args(argv[1:])
    if not KEY_ID.fullmatch(args.key_id):
        print(f"keyId {args.key_id!r}: use 1 to 32 letters A-Z or a-z, digits, '_' and '-' (PUSH-R2)", file=sys.stderr)
        return 2

    payload = pathlib.Path(args.payload).read_bytes()
    generated_at = args.generated_at if args.generated_at is not None else int(time.time())
    expires = args.expires if args.expires is not None else generated_at + WEEK
    fields: list[tuple[str, int | str]] = [
        ("v", args.v),
        ("generatedAt", generated_at),
        ("keyId", args.key_id),
        ("seq", args.seq),
        ("expires", expires),
        ("payload", base64.b64encode(payload).decode()),
    ]
    if args.sign:
        message = header(args.v, generated_at, args.key_id, args.seq, expires) + payload
        fields.append(("sig", base64.b64encode(sign(message, args.sign)).decode()))

    if args.table:
        print(table(fields, ""))
        return 0
    folder = pathlib.Path(args.out) / "Pagle_Content"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "Pagle_Content.toc").write_text(toc())
    (folder / "Content.lua").write_text(
        "-- A hand-made Pagle_Content written by scripts/pushed-content.py, for a dev test.\n"
        f"PagleContentData = {table(fields, '')}\n"
    )
    print(f"Wrote {folder}{' (signed)' if args.sign else ' (unsigned)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
