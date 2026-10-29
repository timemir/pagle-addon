"""The Refresh ticket's icon (scripts/ticket-art.py, pagle_data/ticket_art.py): the two sprite tables (the Tackle Board's and
Core's) say where the ticket is in the lossless atlas (data/art/ticket/tga/Ticket.tga), both shipped BLPs are that atlas
texel for texel, and (where resvg-py is installed) a fresh draw of the SVG is the committed atlas."""

import re
import struct
from pathlib import Path

import numpy as np
import numpy.typing as npt
import pytest
from PIL import Image

from pagle_data.ticket_art import (
    ATLAS_TGA,
    BOARD_BLP,
    BOARD_LUA,
    BOX,
    CORE_BLP,
    CORE_LUA,
    GUTTER,
    HEIGHT,
    SCALE,
    SIZE,
    WIDTH,
    atlas_image,
)

REPO = Path(__file__).resolve().parents[2]
BLP_HEADER = 1172  # magic, type, four encoding bytes, size, 16 mip offsets and sizes, the 256-entry palette


@pytest.fixture(scope="module")
def tga() -> npt.NDArray[np.uint8]:
    return np.asarray(Image.open(REPO / ATLAS_TGA).convert("RGBA"))


@pytest.mark.parametrize("lua", [BOARD_LUA, CORE_LUA])
def test_each_sprite_table_says_where_the_ticket_is_in_the_atlas(lua: Path) -> None:
    text = (REPO / lua).read_text(encoding="utf-8")
    fields = {k: int(v) for k, v in re.findall(r"^\t(width|height|scale) = (\d+),", text, re.M)}
    assert fields == {"width": WIDTH, "height": HEIGHT, "scale": SCALE}
    match = re.search(r"ticket = \{ x = (\d+), y = (\d+), w = (\d+), h = (\d+), box = \{ ([\d, .]+) \} \}", text)
    assert match, "no ticket sprite"
    x, y, w, h = (int(v) for v in match.groups()[:4])
    assert (x, y, w, h) == (GUTTER, GUTTER, *SIZE)
    assert tuple(float(v) for v in match.group(5).split(",")) == BOX
    assert (BOX[2] * SCALE, BOX[3] * SCALE) == (w, h)


def test_the_ticket_has_art_in_it_and_clear_texels_round_it(tga: npt.NDArray[np.uint8]) -> None:
    assert tga.shape == (HEIGHT, WIDTH, 4)
    inside = tga[GUTTER : GUTTER + SIZE[1], GUTTER : GUTTER + SIZE[0], 3]
    assert (inside > 200).sum() > 1000
    rest = tga[:, :, 3].copy()
    rest[GUTTER : GUTTER + SIZE[1], GUTTER : GUTTER + SIZE[0]] = 0
    assert rest.max() == 0


@pytest.mark.parametrize("blp", [BOARD_BLP, CORE_BLP])
def test_each_blp_is_the_atlas_texel_for_texel(blp: Path, tga: npt.NDArray[np.uint8]) -> None:
    data = (REPO / blp).read_bytes()
    assert data[:4] == b"BLP2"
    assert struct.unpack_from("<IBBBBII", data, 4) == (1, 3, 8, 8, 1, WIDTH, HEIGHT)
    offset, size = struct.unpack_from("<I", data, 20)[0], struct.unpack_from("<I", data, 84)[0]
    top = np.frombuffer(data[offset : offset + size], dtype=np.uint8).reshape(HEIGHT, WIDTH, 4)
    assert np.array_equal(top[:, :, [2, 1, 0, 3]], tga)  # BGRA


def test_a_fresh_draw_of_the_source_is_the_committed_atlas(tga: npt.NDArray[np.uint8]) -> None:
    pytest.importorskip("resvg_py", reason="the art's source is drawn by resvg-py (scripts/setup.sh)")
    fresh = np.asarray(atlas_image(REPO)).astype(int)
    assert np.abs(fresh - tga.astype(int)).max() <= 2, "the SVG source and the atlas have come apart"
