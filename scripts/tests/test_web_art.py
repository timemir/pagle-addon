"""The web art export (scripts/export-web-art.py, pagle_data/web_art.py), run on a few pieces: the file names, the
manifest's shape, the CSS keyframes and the WebP sizes."""

import json
import re
from pathlib import Path
from typing import Any

import pytest
from PIL import Image

from pagle_data.web_art import ART_DIR, export

REPO = Path(__file__).resolve().parents[2]
SUBSET = ["prestige-frame-none", "prestige-frame-5", "prestige-frame-6", "legend-crest-19803",
          "legend-crest-unwritten", "prestige-emblem-master"]
ANIMATED = {
    "prestige-frame-5": ["back", "fx2", "fx1", "body", "lab"],
    "prestige-frame-6": ["body", "fx1", "fx2", "lab"],
    "legend-crest-19803": ["back", "fx2", "well", "body", "fx1", "front", "lab"],
    "legend-crest-unwritten": ["fx1", "well", "body", "lab"],
}


@pytest.fixture(scope="module")
def out(tmp_path_factory: pytest.TempPathFactory) -> Path:
    folder = tmp_path_factory.mktemp("web-art")
    export(REPO / ART_DIR, folder, SUBSET)
    return folder


def files(folder: Path) -> list[str]:
    return sorted(p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file())


def manifest(out: Path, key: str) -> Any:
    return json.loads((out / key / "manifest.json").read_text(encoding="utf-8"))


def size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        assert image.format == "WEBP"
        assert image.mode == "RGBA"
        width, height = image.size
        return width, height


def test_the_file_names(out: Path) -> None:
    expected = ["index.json", "prestige-frame-6.webp", "prestige-frame-none.webp", "prestige-frame-5.webp",
                "legend-crest-19803.webp", "legend-crest-unwritten.webp",
                *(f"prestige-emblem-master-{s}.webp" for s in (64, 34, 22))]
    for key, layers in ANIMATED.items():
        expected += [f"{key}/manifest.json", f"{key}/{key}.css", *(f"{key}/{layer}.webp" for layer in layers)]
    assert files(out) == sorted(expected)


def test_rank_iii_is_the_lighthouse_as_in_the_game(tmp_path: Path) -> None:
    # The kit's `lamproom`, "The Lamp Room", is the addon's `lighthouse`, "The Lighthouse" (LED-R154): the site gets
    # the addon's name, and never the kit's key.
    export(REPO / ART_DIR, tmp_path, ["prestige-frame-3"])
    assert files(tmp_path) == ["index.json", "prestige-frame-3.webp"]
    index = (tmp_path / "index.json").read_text(encoding="utf-8")
    assert [(p["key"], p["rank"], p["name"]) for p in json.loads(index)["pieces"]] == [
        ("prestige-frame-3", 3, "The Lighthouse")]
    assert "lamproom" not in index.lower() and "The Lamp Room" not in index


def test_an_unknown_key_is_refused(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="no such piece: prestige-frame-12"):
        export(REPO / ART_DIR, tmp_path, ["prestige-frame-12"])
    assert files(tmp_path) == []


@pytest.mark.parametrize("key", sorted(ANIMATED))
def test_the_manifest_lists_the_layers_in_z_order(out: Path, key: str) -> None:
    data = manifest(out, key)
    assert set(data) == {"key", "kind", "name", "box", "scale", "rest", "css", "well", "label", "layers"}
    assert data["key"] == key and data["box"] == {"w": 260, "h": 280} and data["scale"] == 2
    assert data["rest"] == f"{key}.webp" and data["css"] == f"{key}.css"
    layers = data["layers"]
    assert [layer["name"] for layer in layers] == ANIMATED[key]
    zs = [layer["z"] for layer in layers]
    assert zs == sorted(zs)
    for layer in layers:
        assert set(layer) == {"name", "file", "rect", "z", "blend", "opacity", "animation", "class", "timing"}
        assert layer["file"] == f"{layer['name']}.webp"
        assert set(layer["rect"]) == {"x", "y", "w", "h"}
        assert all(isinstance(v, (int, float)) for v in layer["rect"].values())
        assert layer["blend"] in {"normal", "add"}
        assert 0 <= layer["opacity"] <= 1
        if layer["animation"] is None:
            assert layer["class"] is None and layer["timing"] is None
        else:
            assert layer["class"] == f"{prefix(key)}-{layer['name']}"
            assert set(layer["timing"]) == {"duration", "easing", "delay", "iterations"}


def prefix(key: str) -> str:
    """The CSS namespace: prestige-frame-5 -> pg-frame-5, legend-crest-19803 -> pg-crest-19803."""
    if key.startswith("prestige-frame-"):
        return "pg-frame-" + key.removeprefix("prestige-frame-")
    return "pg-crest-" + key.removeprefix("legend-crest-")


def test_add_layers_and_rest_opacity_come_from_art_json(out: Path) -> None:
    storm = {layer["name"]: layer for layer in manifest(out, "prestige-frame-5")["layers"]}
    assert storm["fx2"]["blend"] == "add" and storm["fx2"]["opacity"] == 0  # the lightning glow, dark at rest
    assert storm["body"]["animation"] == "pg-frame-5-helm" and storm["body"]["opacity"] == 1
    racer = {layer["name"]: layer for layer in manifest(out, "legend-crest-19803")["layers"]}
    assert racer["fx1"]["blend"] == "add" and racer["fx1"]["animation"] == "pg-crest-19803-lap"
    assert racer["well"] == {"name": "well", "file": "well.webp", "rect": {"x": 74, "y": 68, "w": 112, "h": 112},
                             "z": 3, "blend": "normal", "opacity": 1.0, "animation": None, "class": None,
                             "timing": None}


KEYFRAMES = re.compile(r"@keyframes\s+([\w-]+)\s*\{((?:[^{}]*\{[^{}]*\})*)\s*\}")


@pytest.mark.parametrize("key", sorted(ANIMATED))
def test_the_css_holds_namespaced_keyframes_of_transform_and_opacity_only(out: Path, key: str) -> None:
    css = (out / key / f"{key}.css").read_text(encoding="utf-8")
    blocks = KEYFRAMES.findall(css)
    assert blocks
    names = {name for name, _ in blocks}
    assert all(name.startswith(prefix(key) + "-") for name in names)
    for _, body in blocks:
        for decls in re.findall(r"\{([^{}]*)\}", body):
            for decl in filter(None, (d.strip() for d in decls.split(";"))):
                prop, value = (s.strip() for s in decl.split(":", 1))
                assert prop in {"transform", "opacity"}
                if prop == "transform":
                    assert set(re.findall(r"([a-zA-Z]+)\(", value)) <= {"rotate", "scale", "translate"}
    # every moving layer's keyframes are in the file, and its class runs them
    for layer in manifest(out, key)["layers"]:
        if layer["animation"]:
            assert layer["animation"] in names
            assert re.search(rf"\.{layer['class']} \{{ animation: {layer['animation']} [\d.]+s ", css)


def test_storm_and_dive_keyframes(out: Path) -> None:
    storm = (out / "prestige-frame-5" / "prestige-frame-5.css").read_text(encoding="utf-8")
    assert {n for n, _ in KEYFRAMES.findall(storm)} == {"pg-frame-5-glow", "pg-frame-5-flash", "pg-frame-5-helm"}
    assert ".pg-frame-5-body { animation: pg-frame-5-helm 4.6s ease-in-out 0s infinite both;" in storm
    # a translation is a share of the layer's own box, so the two bubbles (different sizes) get a keyframes each
    dive = (out / "prestige-frame-6" / "prestige-frame-6.css").read_text(encoding="utf-8")
    assert {n for n, _ in KEYFRAMES.findall(dive)} == {"pg-frame-6-bubble-fx1", "pg-frame-6-bubble-fx2"}
    assert "translate(0%, 32.532%)" in dive  # 18 units of a 55.33-unit layer
    assert ".pg-frame-6-fx2 { animation: pg-frame-6-bubble-fx2 3.2s ease-in 1.6s infinite both;" in dive


def test_webp_sizes(out: Path) -> None:
    for key in ("prestige-frame-none", "prestige-frame-5", "prestige-frame-6", "legend-crest-19803",
                "legend-crest-unwritten"):
        assert size(out / f"{key}.webp") == (520, 560)
    for key in ANIMATED:
        for layer in manifest(out, key)["layers"]:
            r = layer["rect"]
            assert size(out / key / layer["file"]) == (round(r["w"] * 2), round(r["h"] * 2))
    assert size(out / "legend-crest-19803" / "well.webp") == (224, 224)
    for design, pixels in ((64, 128), (34, 68), (22, 44)):
        assert size(out / f"prestige-emblem-master-{design}.webp") == (pixels, pixels)


def test_every_crest_has_a_full_well(out: Path) -> None:
    # the well holds a Pagle-drawn fish (never the game's item icon), so the crest is whole without the client
    for key in ("legend-crest-19803", "legend-crest-unwritten"):
        with Image.open(out / f"{key}.webp") as image:
            assert image.getchannel("A").getpixel((130 * 2, 124 * 2)) == 255


def test_the_index_lists_what_was_written(out: Path) -> None:
    index = json.loads((out / "index.json").read_text(encoding="utf-8"))
    assert [p["key"] for p in index["pieces"]] == ["prestige-frame-none", "prestige-frame-5", "prestige-frame-6",
                                                     "legend-crest-19803", "legend-crest-unwritten"]
    by_key = {p["key"]: p for p in index["pieces"]}
    assert by_key["prestige-frame-none"]["animated"] is None
    assert by_key["prestige-frame-5"]["animated"] == "prestige-frame-5/"
    assert by_key["legend-crest-19803"]["item"] == 19803 and by_key["legend-crest-19803"]["well"]["drawn"] is True
    assert index["emblems"] == [{"key": "prestige-emblem-master",
                                 "files": {s: f"prestige-emblem-master-{s}.webp" for s in ("64", "34", "22")}}]
