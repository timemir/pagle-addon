"""The Curio crate's art kit (scripts/crate-art.py, pagle_data/crate_art.py): the sprite table in addons/Pagle/data/CrateArt.lua
is the lossless atlas's (data/art/crate/tga/Crate.tga) and the shipped BLP's, every piece the opening needs is in it, a sprite
meant for tinting is grey, and (where resvg-py is installed) a fresh draw of the SVG sources is the committed atlas, to a rounding
of the texel."""

import re
import struct
from pathlib import Path

import numpy as np
import numpy.typing as npt
import pytest
from PIL import Image, ImageChops

from pagle_data.crate_art import (
    ART_LUA,
    ATLAS_BLP,
    ATLAS_TGA,
    EMBLEMS,
    GUTTER,
    SCALE,
    all_sprites,
    atlas_image,
    pack,
)

REPO = Path(__file__).resolve().parents[2]
BLP_HEADER = struct.Struct("<4sIBBBBII16I16I")  # magic, type, encoding, alpha depth, alpha encoding, mips, size, mip table
ATLAS_LIMIT = 2048 * 1024  # the spec's budget: one texture of 2048 x 1024 or smaller
USES = {"tint", "add", "fixed", "cap", "mirror", "slice"}
ANCHORS = {"crate", "plaque", "reel", "line", "bobber", "hook", "card", "centre", "box"}
# What the opening needs (wallet-and-shop.md › Motion, "A crate opens"), by sprite name.
NEEDED = [
    "crate-body", "crate-lid", "crate-seal-left", "crate-seal-right", "crate-ribbon",
    "plaque-cap", "plaque-mid",
    "reel-frame-cap", "reel-frame-mid", "reel-fade", "reel-line", "reel-line-glow", "reel-bobber", "reel-hook", "reel-light",
    "card-base", "card-tint", "card-hatch", "card-sheen", "card-shadow", "card-glow", "card-curio", "card-coin",
    *(f"emblem-{kind}" for kind in ("toast", "book", "sound", "tracker", "coin")),
    *(f"emblem-{kind}-hi" for kind in ("toast", "book", "sound", "tracker", "coin")),
    "kind-toast", "kind-book", "kind-sound",
    "rays-crate", "rays-a", "rays-b", "fx-burst", "fx-beam", "fx-spark", "fx-ember", "fx-dust", "fx-straw", "fx-flash",
    "fx-halo", "fx-seal-glow", "fx-coin",
]  # fmt: skip


def parse_table(text: str) -> tuple[dict[str, float], dict[str, dict[str, object]]]:
    """The atlas's own fields, and each sprite's, from CrateArt.lua (written by crate_art.lua_table, then StyLua)."""
    head = text[: text.index("sprites = {")]
    atlas = {k: float(v) for k, v in re.findall(r"^\t(width|height|scale) = ([\d.]+),", head, re.M)}
    sprites: dict[str, dict[str, object]] = {}
    for name, body in re.findall(r'\["([\w-]+)"\] = \{(.*?)\n\t\t\},', text, re.S):
        entry: dict[str, object] = {}
        for key, value in re.findall(r"^\t\t\t(\w+) = (.+),$", body, re.M):
            if value.startswith("{"):
                entry[key] = [float(v) for v in value.strip("{} ").split(",")]
            elif value.startswith('"'):
                entry[key] = value.strip('"')
            else:
                entry[key] = float(value)
        sprites[name] = entry
    return atlas, sprites


ATLAS, SPRITES = parse_table((REPO / ART_LUA).read_text(encoding="utf-8"))


def number(name: str, key: str) -> float:
    value = SPRITES[name][key]
    assert isinstance(value, float)
    return value


def numbers(name: str, key: str) -> list[float]:
    value = SPRITES[name][key]
    assert isinstance(value, list)
    return value


def rect(name: str) -> tuple[int, int, int, int]:
    return int(number(name, "x")), int(number(name, "y")), int(number(name, "w")), int(number(name, "h"))


@pytest.fixture(scope="module")
def tga() -> npt.NDArray[np.uint8]:
    return np.asarray(Image.open(REPO / ATLAS_TGA).convert("RGBA"))


def test_the_sprite_table_names_every_piece_the_opening_needs() -> None:
    assert not [name for name in NEEDED if name not in SPRITES]
    assert not [name for name in SPRITES if name not in NEEDED], "a sprite the test's list doesn't know"
    assert len(EMBLEMS) == 5


def test_the_atlas_is_one_texture_within_budget_and_the_same_size_in_the_table_the_tga_and_the_blp(
    tga: npt.NDArray[np.uint8],
) -> None:
    width, height = int(ATLAS["width"]), int(ATLAS["height"])
    assert ATLAS["scale"] == SCALE
    assert width * height <= ATLAS_LIMIT
    assert width & (width - 1) == 0 and height & (height - 1) == 0, "textures are powers of two"
    assert tga.shape == (height, width, 4)
    fields = BLP_HEADER.unpack_from((REPO / ATLAS_BLP).read_bytes())
    assert fields[:8] == (b"BLP2", 1, 2, 8, 7, 1, width, height)


def test_the_blp_is_dxt5_with_its_whole_mip_chain_and_nothing_else() -> None:
    data = (REPO / ATLAS_BLP).read_bytes()
    fields = BLP_HEADER.unpack_from(data)
    width, height = fields[6], fields[7]
    offsets, sizes = fields[8:24], fields[24:40]
    levels = max(width, height).bit_length()
    assert sum(1 for size in sizes if size) == levels, "a level down to 1 x 1"
    at = BLP_HEADER.size + 1024
    for i in range(levels):
        w, h = max(1, width >> i), max(1, height >> i)
        assert (offsets[i], sizes[i]) == (at, max(1, -(-w // 4)) * max(1, -(-h // 4)) * 16), f"level {i}"
        at += sizes[i]
    assert at == len(data)


def test_every_sprite_is_inside_the_atlas_with_clear_texels_round_it_and_art_in_it(tga: npt.NDArray[np.uint8]) -> None:
    width, height = int(ATLAS["width"]), int(ATLAS["height"])
    covered = np.zeros((height, width), dtype=np.uint8)
    for name in SPRITES:
        x, y, w, h = rect(name)
        assert x >= GUTTER and y >= GUTTER and x + w + GUTTER <= width and y + h + GUTTER <= height, name
        assert covered[y - GUTTER : y + h + GUTTER, x - GUTTER : x + w + GUTTER].sum() == 0, f"{name} touches another"
        covered[y : y + h, x : x + w] = 1
        assert tga[y : y + h, x : x + w, 3].max() > 0, f"{name} is clear"
    assert tga[covered == 0, 3].max() == 0, "something is drawn outside the sprites"


def test_each_sprite_says_where_it_goes_how_big_it_is_meant_to_be_and_what_it_is_for() -> None:
    for name, s in SPRITES.items():
        assert s["anchor"] in ANCHORS, name
        assert set(str(s["use"]).split()) <= USES, name
        size, box = numbers(name, "size"), numbers(name, "box")
        assert len(numbers(name, "at")) == 2 and len(size) == 2 and len(box) == 4, name
        assert size[0] > 0 and size[1] > 0
        # a sprite is stored at the atlas's density, or 1.5 times it (the cards), or a fraction (the smooth effects)
        density = number(name, "w") / size[0]
        assert 0.1 <= density <= SCALE * 1.5 + 0.05, f"{name}: {density} texels a unit"
        assert 0 <= box[0] and 0 <= box[1] and box[0] + box[2] <= size[0] + 0.05 and box[1] + box[3] <= size[1] + 0.05, name
        if "alpha" in s:
            assert 0 < number(name, "alpha") < 1, name


def test_the_spec_s_sizes_hold() -> None:
    # wallet-and-shop.md: the crate is 256 x 214 units (the prototype's 320 x 268 at 0.8), a card 120 x 138, the reel 170 tall.
    assert numbers("card-base", "size") == pytest.approx([120, 138], abs=0.5)
    assert numbers("crate-lid", "box")[2] == pytest.approx(236.8, abs=1)  # the lid's 296 px
    assert numbers("crate-body", "box")[3] <= 214
    assert numbers("reel-frame-cap", "box")[3] == pytest.approx(170, abs=0.5)


@pytest.mark.parametrize("kind", EMBLEMS)
def test_an_emblem_and_the_pieces_a_card_tints_are_grey_or_white(kind: str, tga: npt.NDArray[np.uint8]) -> None:
    # SetVertexColor multiplies: a tinted sprite that isn't grey would not come out the tier's colour.
    for name in (f"emblem-{kind}", "card-tint", "card-hatch", "card-glow", "rays-a", "rays-b", "fx-halo", "fx-spark"):
        x, y, w, h = rect(name)
        texels = tga[y : y + h, x : x + w]
        seen = texels[texels[:, :, 3] > 8, :3].astype(int)
        assert (seen.max(axis=1) - seen.min(axis=1)).max() <= 2, f"{name} has colour"


def test_the_blp_reads_back_as_the_tga_to_dxt5_s_error(tga: npt.NDArray[np.uint8]) -> None:
    source = Image.fromarray(tga, "RGBA")
    black = Image.new("RGBA", source.size, (0, 0, 0, 255))
    drawn = Image.alpha_composite(black, source).convert("RGB")
    back = Image.alpha_composite(black, Image.open(REPO / ATLAS_BLP).convert("RGBA")).convert("RGB")
    difference = np.asarray(ImageChops.difference(drawn, back))
    assert float(np.percentile(difference, 99.9)) <= 64  # encode-blp.py's MIPS_MAX_ERROR, over the whole atlas
    assert difference.mean() < 2.5  # the clear texels' zeros count: this is an average over a mostly empty atlas


def over_black(texels: npt.NDArray[np.int_]) -> npt.NDArray[np.float64]:
    """The texels as the client draws them over black."""
    return np.asarray(texels[:, :, :3] * texels[:, :, 3:] / 255.0, dtype=np.float64)


def test_a_fresh_draw_of_the_sources_is_the_committed_atlas(tga: npt.NDArray[np.uint8]) -> None:
    pytest.importorskip("resvg_py", reason="the art's sources are drawn by resvg-py (scripts/setup.sh)")
    sprites = all_sprites(REPO)
    width, height = pack(sprites)
    assert (width, height) == tga.shape[1::-1]
    assert sorted(s.name for s in sprites) == sorted(SPRITES)
    for s in sprites:
        assert (s.w, s.h) == rect(s.name)[2:], f"{s.name} is a different size"
    fresh = np.asarray(atlas_image(sprites, width, height)).astype(int)
    difference = np.abs(over_black(fresh) - over_black(tga.astype(int)))
    assert float(np.percentile(difference, 99.99)) <= 6, "the SVG sources and the atlas have come apart"
    assert difference.mean() < 0.05
