#!/usr/bin/env python3
"""Independent Recovery v1 framing and TEST ONLY OpenSSL signatures."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent

def field(value):
    if not isinstance(value, bytes):
        value = str(value).encode()
    return str(len(value)).encode() + b":" + value + b","

def digest(value):
    return hashlib.sha256(value).hexdigest()

base = base64.b64decode(json.loads((ROOT / "spec/fixtures/recovery-snapshot-v1.json").read_text())["vectors"][0]["snapshot"])
old_entry = b"B1|1|1792422000|0|70338|1.60.1|pagle-2026a"
head = base[:-(len(field(old_entry)) + len(field(1)))]
source_entries = [old_entry, b"S1|1|1793000001|0|80|150|0", b"U1|1|1793000002|0|some.good|25"]
replacement_entries = source_entries[:2]
source = head + field(3) + b"".join(map(field, source_entries))
replacement = head + field(2) + b"".join(map(field, replacement_entries))
checkpoint = digest(b"PGL-CHECKPOINT|1|0123456789abcdef|4\n")
guid = b"Player-4618-0A1B2C3D"
checkpoint = digest(b"PGL-ENTRY|1|" + checkpoint.encode() + b"|1|" + str(len(guid)).encode() + b"|" + guid + b"|" + str(len(old_entry)).encode() + b"|" + old_entry + b"\n")

def envelope(name, **changes):
    values = dict(application="app.pagle.recovery", logId="0123456789abcdef", format=4, seq=1,
                  checkpoint=checkpoint, revision=7, rules="pagle-ranked-1-" + hashlib.sha256(b"TEST ONLY rules version").hexdigest(), expected=digest(source),
                  resulting=digest(replacement), replacement=replacement, staged=1, originalSeq=3,
                  reason="action_requires_review")
    values.update(changes)
    if values["staged"] == 0:
        del values["originalSeq"]
        del values["reason"]
    body = b"".join(field(v) for v in values.values())
    application_id = digest(body)
    payload = b"PGL-RECOVERY-DATA|1\n" + field(application_id) + body
    if name == "trailing":
        payload += b"junk"
    signature_input = b"PGL-RECOVERY|1|testKey|" + str(len(payload)).encode() + b"|" + payload
    if name == "wrongDomain":
        signature_input = b"PGL-CONTENT|1|" + payload
    with tempfile.TemporaryDirectory() as tmp:
        source_path = Path(tmp) / "input"
        source_path.write_bytes(signature_input)
        sig = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", str(ROOT / "spec/Pagle/fixtures/signing/test-only-private-key.pem"), str(source_path)])
    return dict(v=1, keyId="testKey", payload=base64.b64encode(payload).decode(), sig=base64.b64encode(sig).decode(), applicationId=application_id)

fixtures = dict(opaqueSnapshotSha256=digest(head + field(2) + field(old_entry) + field(b"Unknown|bad bytes")), multipartSha256=digest(head + field(1500) + field(old_entry) * 1500), source=base64.b64encode(source).decode(), replacement=base64.b64encode(replacement).decode(),
                replacementDigest=digest(replacement), checkpoint=checkpoint)
for name, changes in [("good", {}), ("wrongDomain", {}), ("wrongTarget", {"logId": "ffffffffffffffff"}),
                      ("wrongDigest", {"resulting": "0" * 64}), ("wrongCheckpoint", {"checkpoint": "0" * 64}),
                      ("trailing", {}), ("unknownReason", {"reason": "made_up"}),
                      ("capacity", {"reason": "capacity_limit"}),
                      ("second", {"expected": digest(replacement), "resulting": digest(base), "replacement": base, "staged": 0}),
                      ("noncanonicalNumber", {"seq": "01"}),
                      ("noncanonicalSnapshot", {"replacement": replacement.replace(b"16:0123456789abcdef", b"016:0123456789abcdef", 1), "resulting": digest(replacement.replace(b"16:0123456789abcdef", b"016:0123456789abcdef", 1))})]:
    fixtures[name] = envelope(name, **changes)
(ROOT / "spec/fixtures/recovery-signed-v1.json").write_text(json.dumps(fixtures, indent=2) + "\n")
