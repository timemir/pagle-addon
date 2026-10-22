"""scripts/pushed-content.py and scripts/pushed-key.py (PUSH-R2, PUSH-R11, PUSH-R12): the keyId each takes holds
PUSH-R2's form, the backend's [A-Za-z0-9_-]{1,32}, so it never holds the canonical header's "|"."""

import importlib.util
from pathlib import Path
from types import ModuleType

import pytest

SCRIPTS = Path(__file__).resolve().parent.parent

# keyIds outside the form: a "|" (the reason for it), a dot (pushed-key.py's old rule took one), a quote, a backslash,
# a line end (alone, or after a good keyId, which a "$" would let through), a space, a letter outside A-Z, none, and 33.
BAD_KEY_IDS = [
    "test|Key",
    "test.Key",
    'test"Key',
    "test\\Key",
    "test\nKey",
    "testKey\n",
    "test Key",
    "testKéy",
    "",
    "k" * 33,
]
GOOD_KEY_IDS = ["testKey", "k", "AZaz09_-" + "k" * 24, "pagle-2026_01"]


def _load(name: str) -> ModuleType:
    """A script by its file name, which a hyphen keeps from being imported by name."""
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


pushed_content = _load("pushed-content")
pushed_key = _load("pushed-key")


def _content(tmp_path: Path, key_id: str) -> list[str]:
    payload = tmp_path / "payload"
    payload.write_bytes(b'{ kind = "huntRun", v = 1 }\n')
    return ["pushed-content.py", str(payload), "--key-id", key_id, "--seq", "42", "--generated-at", "100", "--table"]


@pytest.mark.parametrize("key_id", BAD_KEY_IDS)
def test_pushed_content_refuses_a_key_id_outside_the_form(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], key_id: str
) -> None:
    code = pushed_content.main(_content(tmp_path, key_id))
    out, err = capsys.readouterr()

    assert code == 2
    assert out == ""
    assert f"keyId {key_id!r}: use 1 to 32 letters A-Z or a-z, digits, '_' and '-' (PUSH-R2)" in err


@pytest.mark.parametrize("key_id", GOOD_KEY_IDS)
def test_pushed_content_writes_a_key_id_of_the_form(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], key_id: str
) -> None:
    code = pushed_content.main(_content(tmp_path, key_id))
    out, err = capsys.readouterr()

    assert code == 0
    assert err == ""
    assert f'\tkeyId = "{key_id}",' in out.splitlines()


def test_the_header_of_a_key_id_of_the_form_reads_one_way() -> None:
    # PUSH-R11: with no "|" in keyId, the canonical header splits back into its five fields.
    header = pushed_content.header(1, 100, "AZaz09_-", 42, 200)

    assert header == b"1|100|AZaz09_-|42|200|"
    assert header.decode().split("|") == ["1", "100", "AZaz09_-", "42", "200", ""]


@pytest.mark.parametrize("key_id", BAD_KEY_IDS)
def test_pushed_key_refuses_a_key_id_outside_the_form(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], key_id: str
) -> None:
    # The keyId is checked before the key is read, so no key file is needed.
    code = pushed_key.main(["pushed-key.py", str(tmp_path / "absent.pem"), key_id])
    out, err = capsys.readouterr()

    assert code == 2
    assert out == ""
    assert f"keyId {key_id!r}: use 1 to 32 letters A-Z or a-z, digits, '_' and '-' (PUSH-R2)" in err


@pytest.mark.parametrize("key_id", GOOD_KEY_IDS)
def test_pushed_key_takes_a_key_id_of_the_form(key_id: str) -> None:
    assert pushed_key.KEY_ID.fullmatch(key_id)
    # Any odd 2048-bit modulus has the entry's n0inv.
    assert pushed_key.entry((1 << 2047) + 1, key_id).startswith(f'\t["{key_id}"] = {{\n')
