"""Every texture the package ships has art in it (BIND-R13, #382): each BLP under addons/ is decoded at its top level,
and one that is entirely transparent, or one flat colour, fails. Such a file loads in the client without an error and
draws nothing, so nothing else catches it: the shop expansion's 34 binding materials shipped that way.

The blocks are decoded here with numpy, not Pillow: Pillow's BLP reader decodes DXT in Python (about 40 seconds for the
whole package) and can't read BLP2's uncompressed BGRA at all (the minimap icon's, CORE-R53). Only which texels there
are matters, not where, so the blocks are never put back in their places."""

import struct
from pathlib import Path

import numpy as np
import numpy.typing as npt
import pytest

REPO = Path(__file__).resolve().parents[2]
ADDONS = REPO / "addons"
HEADER = struct.Struct("<4sIBBBBII16I16I")  # magic, type, encoding, alpha depth, alpha encoding, mips, size, mip table
SAMPLE_BLOCKS = 1024  # the spread read first: 16,384 texels however large the texture

# The shop expansion's materials (Pagle/media/books/bindings/) still blank since they were added: each is a mipmapped
# DXT5 whose every block has zero endpoints, the encoding of a fully transparent image. Their art is being repainted
# (#382, #384); each passes, and so fails this list, once its art is back. All 34 are back, so the list is empty; it
# stays, for a texture that ships blank again while its art is being redone.
BLANK_KEYS: tuple[str, ...] = ()
BLANK_SINCE_ADDED = frozenset(f"Pagle/media/books/bindings/{key}.blp" for key in BLANK_KEYS)

Texels = npt.NDArray[np.uint8]  # one RGBA row per texel, in no particular order


def _expand(bits: npt.NDArray[np.uint64], count: int, width: int) -> npt.NDArray[np.intp]:
    """The `count` indices of `width` bits each packed into every one of `bits`, low bits first."""
    shifts = np.arange(count, dtype=np.uint64) * np.uint64(width)
    return ((bits[:, None] >> shifts) & np.uint64((1 << width) - 1)).astype(np.intp)


def _little(columns: Texels) -> npt.NDArray[np.uint64]:
    """Each row of `columns`, its bytes read as one little-endian unsigned number."""
    weights = np.uint64(1) << (np.arange(columns.shape[1], dtype=np.uint64) * np.uint64(8))
    return (columns.astype(np.uint64) * weights).sum(axis=1, dtype=np.uint64)


def _colours(blocks: Texels, punch_through: bool) -> tuple[Texels, npt.NDArray[np.bool_]]:
    """The 16 texels' RGB of each DXT colour block (its 8 bytes), and which are DXT1's transparent black."""
    ends = blocks[:, 0:4].astype(np.uint32)
    c0, c1 = ends[:, 0] | ends[:, 1] << 8, ends[:, 2] | ends[:, 3] << 8
    rgb = []
    for c in (c0, c1):
        r, g, b = (c >> 11) & 31, (c >> 5) & 63, c & 31
        rgb.append(np.stack([(r * 255 + 15) // 31, (g * 255 + 31) // 63, (b * 255 + 15) // 31], axis=1))
    p0, p1 = rgb
    four = (c0 > c1) | (not punch_through)
    p2 = np.where(four[:, None], (2 * p0 + p1) // 3, (p0 + p1) // 2)
    p3 = np.where(four[:, None], (p0 + 2 * p1) // 3, 0)
    palette = np.stack([p0, p1, p2, p3], axis=1)  # block, entry, channel
    index = _expand(_little(blocks[:, 4:8]), 16, 2)
    texels = np.take_along_axis(palette, index[:, :, None], axis=1)
    return texels.reshape(-1, 3).astype(np.uint8), ((index == 3) & ~four[:, None]).reshape(-1)


def _dxt5_alpha(blocks: Texels) -> Texels:
    """The 16 texels' alpha of each DXT5 alpha block (its 8 bytes)."""
    a0, a1 = blocks[:, 0].astype(np.int32), blocks[:, 1].astype(np.int32)
    eight = (a0 > a1)[:, None]
    steps = np.arange(1, 7, dtype=np.int32)
    between8 = ((7 - steps) * a0[:, None] + steps * a1[:, None]) // 7
    steps5 = np.arange(1, 5, dtype=np.int32)
    between6 = ((5 - steps5) * a0[:, None] + steps5 * a1[:, None]) // 5
    six = np.concatenate([between6, np.zeros_like(a0)[:, None], np.full_like(a0, 255)[:, None]], axis=1)
    palette = np.concatenate([a0[:, None], a1[:, None], np.where(eight, between8, six)], axis=1)
    index = _expand(_little(blocks[:, 2:8]), 16, 3)
    return np.take_along_axis(palette, index, axis=1).reshape(-1).astype(np.uint8)


def top_level(data: bytes, units: int | None = None) -> Texels:
    """The texels of a BLP2 file's first mip level, as RGBA rows: all of them, or only those of about `units` blocks
    (or BGRA texels) spread evenly through it."""
    fields = HEADER.unpack_from(data)
    magic, kind, encoding, alpha_depth, alpha_encoding, _, width, height = fields[:8]
    offset, size = fields[8], fields[24]
    assert magic == b"BLP2" and kind == 1, "not a BLP2 colour texture"
    level = np.frombuffer(data, dtype=np.uint8, count=size, offset=offset)
    if encoding == 3:  # uncompressed BGRA
        assert size == width * height * 4, f"{size} bytes for {width} x {height} BGRA texels"
        bgra = level.reshape(-1, 4)
        return bgra[:: _stride(len(bgra), units), [2, 1, 0, 3]]
    assert encoding == 2, f"BLP encoding {encoding}: only DXT (2) and BGRA (3) ship"
    count = max(1, width // 4) * max(1, height // 4)
    if alpha_encoding == 7:  # DXT5: an interpolated alpha block, then a colour block
        blocks = level.reshape(count, 16)[:: _stride(count, units)]
        rgb, _ = _colours(blocks[:, 8:], punch_through=False)
        alpha = _dxt5_alpha(blocks)
    elif alpha_encoding == 1:  # DXT3: 4 bits of alpha a texel, then a colour block
        blocks = level.reshape(count, 16)[:: _stride(count, units)]
        rgb, _ = _colours(blocks[:, 8:], punch_through=False)
        alpha = (_expand(_little(blocks[:, :8]), 16, 4) * 17).reshape(-1).astype(np.uint8)
    else:  # DXT1: a colour block alone, with 1-bit alpha when the texture has any
        blocks = level.reshape(count, 8)[:: _stride(count, units)]
        rgb, clear = _colours(blocks, punch_through=alpha_depth > 0)
        alpha = np.where(clear, 0, 255).astype(np.uint8)
    return np.concatenate([rgb, alpha[:, None]], axis=1)


def _stride(count: int, units: int | None) -> int:
    return 1 if units is None else max(1, -(-count // units))


def blankness(texels: Texels) -> str | None:
    """Why `texels` draw nothing, or None when they hold some art."""
    if not texels[:, 3].any():
        return "entirely transparent"
    if (texels == texels[0]).all():
        return f"one flat colour, RGBA {tuple(int(v) for v in texels[0])}"
    return None


def why_blank(data: bytes) -> str | None:
    """Why a BLP2 file's first level draws nothing, or None. A spread of its blocks is read first, which settles nearly
    every texture with art; only a sample with nothing in it (a blank texture, or an atlas with little in it) is read
    whole, so the answer is the whole level's."""
    if blankness(top_level(data, SAMPLE_BLOCKS)) is None:
        return None
    return blankness(top_level(data))


def _shipped() -> list[object]:
    params: list[object] = []
    for path in sorted(ADDONS.rglob("*.blp")):
        name = path.relative_to(ADDONS).as_posix()
        marks = [pytest.mark.xfail(reason="#382: blank since added, its art not back yet", strict=True)]
        params.append(pytest.param(path, id=name, marks=marks if name in BLANK_SINCE_ADDED else ()))
    return params


@pytest.mark.parametrize("path", _shipped())
def test_every_shipped_texture_has_art(path: Path) -> None:
    problem = why_blank(path.read_bytes())
    assert problem is None, f"{path.relative_to(REPO).as_posix()} decodes as {problem}"


def test_the_known_blank_ones_still_ship() -> None:
    # A name on the list that no longer ships would hide nothing: the list shrinks as art comes back.
    shipped = {path.relative_to(ADDONS).as_posix() for path in ADDONS.rglob("*.blp")}
    assert BLANK_SINCE_ADDED <= shipped


def _blp(encoding: int, alpha_depth: int, alpha_encoding: int, width: int, height: int, level: bytes) -> bytes:
    offsets = [HEADER.size + 1024] + [0] * 15
    sizes = [len(level)] + [0] * 15
    fields = (b"BLP2", 1, encoding, alpha_depth, alpha_encoding, 0, width, height, *offsets, *sizes)
    return HEADER.pack(*fields) + bytes(1024) + level


def test_a_dxt5_of_zero_endpoints_is_transparent_and_one_with_art_is_not() -> None:
    # The blank materials' blocks: zero alpha and colour endpoints, every colour index 1.
    blank = bytes(8) + bytes(4) + b"\x55" * 4
    assert blankness(top_level(_blp(2, 8, 7, 8, 4, blank * 2))) == "entirely transparent"
    # Opaque (alpha endpoint 255, index 0), red and green ends, texels on either end and between.
    art = b"\xff\x00" + bytes(6) + struct.pack("<HH", 0xF800, 0x07E0) + b"\x1b\x1b\xe4\xe4"
    texels = top_level(_blp(2, 8, 7, 4, 4, art))
    assert blankness(texels) is None
    assert {tuple(int(v) for v in t) for t in texels} == {(255, 0, 0, 255), (0, 255, 0, 255), (170, 85, 0, 255),
                                                          (85, 170, 0, 255)}


def test_art_the_first_spread_misses_is_still_found() -> None:
    # 2,048 blocks are read every other one first: art in one odd block alone, as in a sparse atlas, is found whole.
    blank = bytes(8) + bytes(4) + b"\x55" * 4
    art = b"\xff\x00" + bytes(6) + struct.pack("<HH", 0xF800, 0x07E0) + b"\x1b\x1b\xe4\xe4"
    sparse = _blp(2, 8, 7, 256, 128, blank + art + blank * 2046)
    assert blankness(top_level(sparse, SAMPLE_BLOCKS)) == "entirely transparent"
    assert why_blank(sparse) is None
    assert why_blank(_blp(2, 8, 7, 256, 128, blank * 2048)) == "entirely transparent"


def test_a_flat_texture_is_blank_and_bgra_is_read_as_rgba() -> None:
    flat = bytes([10, 20, 30, 255]) * 16
    assert blankness(top_level(_blp(3, 8, 8, 4, 4, flat))) == "one flat colour, RGBA (30, 20, 10, 255)"
    varied = flat[:-4] + bytes([10, 20, 30, 128])
    assert blankness(top_level(_blp(3, 8, 8, 4, 4, varied))) is None
