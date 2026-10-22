"""Prints a public key's entry for Core's addons/Pagle/logic/PushedKeys.lua (PUSH-R11, PUSH-R12).

    scripts/pushed-key.py <key.pem> <keyId>

<key.pem> is an RSA-2048 key with public exponent 65537, public or private, in any PEM form openssl reads; only its
public half is used. The entry holds the modulus n and the two values Core's Montgomery multiplication needs, worked
out here once so a login does no key setup:

- rr, R^2 mod n, with R = 2^(24 * 86): the modulus is 86 limbs of 24 bits (addons/Pagle/logic/Rsa.lua);
- n0inv, -n^-1 mod 2^24.

n and rr are 512 lowercase hex digits, big-endian. It reads the key with the openssl command (any 3.x or later) and
fails, printing nothing, on a key that isn't RSA-2048 with exponent 65537.
"""

import re
import subprocess
import sys

LIMB_BITS = 24
LIMBS = 86
MODULUS_BYTES = 256
# keyId's form (PUSH-R2), the backend's: no "|", so the canonical header (PUSH-R11) reads one way.
KEY_ID = re.compile(r"[A-Za-z0-9_-]{1,32}")


def public_numbers(pem_path: str) -> tuple[int, int]:
    """The key's modulus and public exponent, read through openssl."""
    # A private key first; a public one needs -pubin.
    public_pem = subprocess.run(
        ["openssl", "pkey", "-in", pem_path, "-pubout"], check=False, capture_output=True, text=True
    ).stdout
    if "-----BEGIN PUBLIC KEY-----" not in public_pem:
        public_pem = subprocess.run(
            ["openssl", "pkey", "-pubin", "-in", pem_path, "-pubout"], check=True, capture_output=True, text=True
        ).stdout
    text = subprocess.run(
        ["openssl", "rsa", "-pubin", "-noout", "-text"], input=public_pem, check=True, capture_output=True, text=True
    ).stdout
    modulus = subprocess.run(
        ["openssl", "rsa", "-pubin", "-noout", "-modulus"],
        input=public_pem,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    found_n = re.search(r"Modulus=([0-9A-Fa-f]+)", modulus)
    found_e = re.search(r"Exponent: (\d+)", text)
    if found_n is None or found_e is None:
        raise SystemExit(f"{pem_path}: openssl didn't print an RSA modulus and exponent")
    return int(found_n.group(1), 16), int(found_e.group(1))


def entry(n: int, key_id: str) -> str:
    """The Lua table entry for modulus `n` under `key_id`."""
    r = 1 << (LIMB_BITS * LIMBS)
    rr = (r * r) % n
    n0inv = (-pow(n, -1, 1 << LIMB_BITS)) % (1 << LIMB_BITS)
    width = 2 * MODULUS_BYTES
    return (
        f'\t["{key_id}"] = {{\n'
        f'\t\tn = "{n:0{width}x}",\n'
        f'\t\trr = "{rr:0{width}x}",\n'
        f"\t\tn0inv = {n0inv},\n"
        "\t},"
    )


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    pem_path, key_id = argv[1], argv[2]
    if not KEY_ID.fullmatch(key_id):
        print(f"keyId {key_id!r}: use 1 to 32 letters A-Z or a-z, digits, '_' and '-' (PUSH-R2)", file=sys.stderr)
        return 2
    n, e = public_numbers(pem_path)
    if e != 65537:
        print(f"{pem_path}: the public exponent is {e}, not 65537 (PUSH-R11)", file=sys.stderr)
        return 1
    if n.bit_length() != 8 * MODULUS_BYTES:
        print(f"{pem_path}: the modulus is {n.bit_length()} bits, not 2048 (PUSH-R11)", file=sys.stderr)
        return 1
    print(entry(n, key_id))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
