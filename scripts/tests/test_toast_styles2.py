"""scripts/toast-styles2.py's fold() (ANN-R82, ANN-R84): a layer's CSS transform list as one translate, rotation and scale.
A full turn must stay a full turn: the client interpolates a layer's rotation linearly between keys, so a spin that
runs rotate(0) to rotate(360deg) is keys 0 and 360, and 0 and 0 is a layer that does not move (#409)."""

import importlib.util
import json
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

SCRIPTS = Path(__file__).resolve().parent.parent


def _load(name: str) -> ModuleType:
    """A script by its file name, which a hyphen keeps from being imported by name."""
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


toast_styles = _load("toast-styles2")


def _rotation(css: str) -> float:
    return float(toast_styles.fold(css)[2])


@pytest.mark.parametrize(
    ("css", "degrees"),
    [
        ("rotate(0deg)", 0),
        ("rotate(45deg)", 45),
        ("rotate(180deg)", 180),
        ("rotate(-90deg)", -90),
        ("rotate(270deg)", 270),
        ("rotate(360deg)", 360),
        ("rotate(-360deg)", -360),
        ("rotate(720deg)", 720),
        ("rotate(180deg) rotate(180deg)", 360),
        ("translateX(10px) rotate(360deg)", 360),
        ("rotate(360deg) scale(1.2)", 360),
        ("rotate(360deg) scaleX(-1)", 360),
        ("rotate(360deg) skewX(10deg)", 360),
    ],
)
def test_fold_keeps_the_rotation_as_the_kit_wrote_it(css: str, degrees: float) -> None:
    assert _rotation(css) == pytest.approx(degrees, abs=1e-6)


def test_fold_does_not_invent_a_turn_when_the_angle_is_not_the_authored_one() -> None:
    """A mirror before the rotation reverses its direction: the matrix's angle is not the rotate() argument, so it is
    left as the matrix has it rather than unwrapped against the wrong sign."""
    assert abs(_rotation("scaleX(-1) rotate(100deg)")) <= 180


@pytest.mark.parametrize(
    ("css", "expected"),
    [
        (None, (0, 0, 0, 1, 1, 0, 0)),
        ("translate(10px, 20px)", (10, 20, 0, 1, 1, 0, 0)),
        ("translateX(-4px) translateY(6px)", (-4, 6, 0, 1, 1, 0, 0)),
        ("scale(1.5)", (0, 0, 0, 1.5, 1.5, 0, 0)),
        ("scale(2, 3)", (0, 0, 0, 2, 3, 0, 0)),
        # CSS applies a list right to left: the fish is mirrored, then moved 120 along its own mirrored x, so right.
        ("scaleX(-1) translateX(-120px)", (120, 0, 0, -1, 1, 0, 0)),
        ("translateX(-120px) scaleX(-1)", (-120, 0, 0, -1, 1, 0, 0)),
        ("rotate(30deg) scale(0.5)", (0, 0, 30, 0.5, 0.5, 0, 0)),
        ("rotate(-5deg)", (0, 0, -5, 1, 1, 0, 0)),
        ("rotate(10deg) skewX(20deg) scale(2)", (0, 0, 10, 2, 2, 20, 0)),
    ],
)
def test_fold_keeps_its_results_for_ordinary_transforms(css: str | None, expected: tuple[float, ...]) -> None:
    assert toast_styles.fold(css) == pytest.approx(expected, abs=1e-6)


def _kit_rung(name: str) -> dict[str, Any]:
    """A kit rung with one layer drawing the sprite `<name>-body`."""
    box = {"x": 0, "y": 0, "w": 10, "h": 10}
    return {
        "w": 464,
        "h": 92,
        "med": [1, 1, 90, 90],
        "icon": [15, 15, 62, 62],
        "text": [115, 20, 285, 54],
        "coin": None,
        "amt": None,
        "inks": {},
        "layers": [
            {"name": "body", "sprite": f"{name}-body", "rect": box, "x": 0, "y": 0, "w": 10, "h": 10, "z": 1, "blend": "BLEND"}
        ],
    }


def test_style_art_leaves_out_the_kits_slim_toast_rung_and_its_sprites() -> None:
    """Every toast is drawn full size (ANN-R80): the kit's toast.low rung and the `low-*` sprites only it draws are not
    written, the others as they were."""
    good = {
        "art": {
            "atlas": "Toasts2\\Glass",
            "atlasSize": [2048, 1024],
            "scale": 1.5,
            "rungs": {name: _kit_rung(name) for name in ("toast", "high", "low", "nod")},
        }
    }

    _, atlas, rungs = toast_styles.style_art(good)

    assert list(rungs) == ["toast", "high", "nod"]
    assert list(atlas["sprites"]) == ["toast-body", "high-body", "nod-body"]


def test_round_four_writes_the_epic_five_under_their_own_header_and_owners_ids(tmp_path: Path) -> None:
    """`--round 4` writes data/ToastStyleArt4.lua (ANN-R85): its own header, which leaves the tables to
    ToastStyleArt2.lua, and every style keyed by the ID its kit gives it (a Hunts' or the Ledger's earned good), never
    renamed as round three's race styles are."""
    goods = tmp_path / "goods.json"
    out = tmp_path / "ToastStyleArt4.lua"
    good = {
        "id": "hunts.toaststyle.nightfin",
        "slot": "core.toaststyle",
        "name": "Nightfin Tide",
        "art": {
            "atlas": "Interface\\AddOns\\Pagle\\media\\announce\\Toasts2Nightfin",
            "atlasSize": [2048, 1024],
            "scale": 1.5,
            "rungs": {name: _kit_rung(name) for name in ("toast", "high", "nod")},
        },
    }
    goods.write_text(json.dumps({"goods": [good]}), encoding="utf-8")

    toast_styles.main(["--round", "4", str(goods), str(out)])

    text = out.read_text(encoding="utf-8")
    assert "-- The epic five composed toast styles" in text
    assert "ns.TOAST_STYLE_ART2 = ns.TOAST_STYLE_ART2 or {}" in text
    assert 'ns.TOAST_STYLE_ART2["hunts.toaststyle.nightfin"]' in text
    assert 'ns.ATLASES["Toasts2Nightfin"]' in text


def test_stage_art_lists_each_stage_with_its_sprite_and_box_and_adds_the_kits_stage_sprites() -> None:
    """The Cartographer's Folio's stages (ANN-R85): stage 4 is the rung's own deco, the others the kit's stage sprites,
    each with its own box, and those sprites join the atlas."""
    deco = {"name": "deco", "sprite": "toast-deco", "rect": {"x": 0, "y": 0, "w": 9, "h": 9}, "x": 20, "y": 14, "w": 400, "h": 60}
    high = {**deco, "sprite": "high-deco", "w": 460}
    extra = {"x": 19, "y": 14, "w": 401, "h": 61, "rect": {"x": 100, "y": 200, "w": 600, "h": 90}}
    good = {
        "art": {
            "rungs": {"toast": {"layers": [deco]}, "high": {"layers": [high]}},
            "stages": [
                {"min": 5, "toast": "toast-deco-st1", "high": "high-deco-st1"},
                {"min": 45, "toast": "toast-deco", "high": "high-deco"},
            ],
            "stageSprites": {"toast-deco-st1": extra, "high-deco-st1": {**extra, "w": 461}},
        }
    }
    sprites: dict[str, Any] = {}

    stages = toast_styles.stage_art(good, sprites)

    assert stages == [
        {
            "min": 5,
            "toast": {"sprite": "toast-deco-st1", "x": 19, "y": 14, "w": 401, "h": 61},
            "high": {"sprite": "high-deco-st1", "x": 19, "y": 14, "w": 461, "h": 61},
        },
        {
            "min": 45,
            "toast": {"sprite": "toast-deco", "x": 20, "y": 14, "w": 400, "h": 60},
            "high": {"sprite": "high-deco", "x": 20, "y": 14, "w": 460, "h": 60},
        },
    ]
    assert sorted(sprites) == ["high-deco-st1", "toast-deco-st1"]
    assert toast_styles.stage_art({"art": {"rungs": {}}}, {}) is None
