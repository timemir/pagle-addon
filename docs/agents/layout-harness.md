# The real-font layout harness

The fake client the specs run on measures every string at 6 units a byte, so no spec can see a German name that's too long for its row. `scripts/measure-layout.sh` runs `/pagle dev tour` on the package as shipped, every roster Module loaded as `spec/tour_spec.lua` loads it, with every font string measured in its real face. At each stop's screenshot it reports text that's cut, off its page or overlapping. It's a dev tool: the tour isn't in CI (its advance table's freshness check is, below), and nothing under `addons/` or `spec/support/` changes for it.

## Running it

```sh
scripts/measure-layout.sh deDE           # the whole tour in one language: enUS, deDE, esES or ruRU
scripts/measure-layout.sh all            # all four at once: about 16 s on the dev's Mac
scripts/measure-layout.sh ruRU hunts     # one Module's stops, as `/pagle dev tour hunts`: core, ledger, hunts, …
MEASURE_PNG=all scripts/measure-layout.sh esES     # draw every stop, not only those with a finding
MEASURE_VERBOSE=1 scripts/measure-layout.sh deDE   # list the allowed findings with their reasons too
GATE_LAYOUT=1 scripts/check.sh           # the gate with the layout stage last; or scripts/check.sh layout alone
```

It runs on the pinned tools in `.tools/` (busted, and Pillow from `PYTHON_PACKAGES`) and fetches nothing. It exits 1 if a language has a finding the allowlist doesn't cover, or the addons raised a Lua error on the tour. Each language's output goes to `build/measure-layout/<language>[-<module>]/`, which git ignores: `findings.jsonl`, one `NN-<stop>.jsonl` per stop (every shown region and its screen rect), `busted.log`, and `png/`, a picture of each stop with a finding. New findings are outlined red, allowed ones amber.

A report line reads:

```
deDE NEW     cut     "Neue Wetten mit dem Pagle-Begleiter"
        wider than its box: 208 wide in 181; at core.onboarding.letter, core.announce.toast, … and 39 more
```

A finding names its kind, its text, what it is and the tour stops it's on. A text that's on many stops, such as the docked tracker's, is one finding.

## What it checks

- **cut**: the client would truncate the text with "…". A one-line string is wider than its box, a wrapping one needs more lines than `SetMaxLines` allows or than its box is tall, or one word is wider than the box.
- **out**: the text's ink isn't on its surface. On a surface with a ground (a texture over half of it, such as a book's paper or a card), each corner and the middle of the ink must lie on one of its textures. On a surface with none, such as the plain tracker, the ink must stay inside its edges. Inside a scroll frame only the frame's sides count, since its content scrolls. Inside a frame that clips its children, every edge counts.
- **overlap**: two texts' em boxes cross (each line one font size tall, not one line height), or a text crosses a rule: a texture or line 3 units thin or less, such as Hunts' now line.

Two units of slack apply at every edge, because line heights are estimates.

## What it can and can't prove

Its scratch predecessor, run on Hunts' spec fixtures renamed to German Lore, reproduced the German Hunts findings from the in-game tour to within a few units. On the real tour sample this harness surfaces the ones that sample shows: the left list's "Gepanzert nach Einbruch der Nacht", the trackers' "Forelle im Morgengrauen", the now line under the headings' notes and the companion hint line. So a finding in a bundled face is worth a look in-game. A clean run doesn't prove a surface is clean:

- **Widths**: advances are summed with no kerning. `scripts/measure-layout/advances.lua` holds each bundled face's advance per codepoint, generated from `addons/Pagle/media/fonts/*.ttf` by `.tools/bin/python scripts/measure-layout.py advances`, as measured by the FreeType that the pinned Pillow wheel bundles (FreeType alone, no HarfBuzz shaping). The run fails when the table is stale, and so does `scripts/tests/test_layout.py` in the default gate's generator stage, which CI runs. A `pillow` pin bump in `scripts/tools.env` can change the advances and turn that check red: run `.tools/bin/python scripts/measure-layout.py advances` in the same PR as the bump.
- **Line height**: each face's ascent plus descent (IM Fell 1.27 times the size, Caveat 1.26). The client's own may differ a little. `MEASURE_LINE=1.1` forces one factor for every face.
- **ruRU and the client's faces are estimates.** On a ruRU client Pagle draws in the client's FRIZQT___CYR and ARIALN, which aren't bundled; any face the add-on doesn't bundle measures in Marcellus as a stand-in. A Cyrillic letter a face lacks takes its Latin look-alike's width (Ж as W). Such findings are marked `(estimated)`. Treat a margin under about 10% as unproven.
- **What the tour shows**: a new Angler's package, each Module's tour sample, at the default sizes and settings, with Animations off. The fake client runs no OnUpdate, so each animation shows where it settles, which is what the tour's screenshot shows in-game. Other data, resized trackers, other looks and hover states aren't measured.
- **Placement**: frames are laid out from their anchors and scales as the fake keeps them. The minimap is put at the screen's top right. A frame the fakes never place is skipped.
- **Overlap** only knows texts and thin rules. Text over art, such as an ornament in a tracker frame's texture, isn't seen.

## The allowlist

`scripts/measure-layout/allowlist.toml` holds the known, accepted findings. Each `[[allow]]` entry needs:

- `kind`: `cut`, `out` or `overlap`.
- `text`: a glob of the finding's text.
- `reason`: why it's accepted.

These narrow it:

- `other`: the text an overlap meets, or `"(rule)"`.
- `stop`: the tour stop, as `/pagle dev tour list` names it.
- `detail`: the report's detail line.
- `languages`: for example `["deDE"]`.

A finding is allowed only if one entry covers it on every stop it's on, so an accepted cut that spreads to a new surface comes back as new. To accept a finding:

1. Look at its PNG, and in-game if it's in doubt.
2. Add the narrowest entry that covers it, with the reason, and the issue or decision behind it if there is one.

Run with `MEASURE_VERBOSE=1` to see each allowed finding with its reason. Only accept a finding that's the design, such as First evening's strike-through, Hunts' now line under a heading's note, or a toast name that scrolls, or one the maintainer has accepted for a release. Fix everything else.

## Real widths in a spec

The measuring lives in `scripts/measure-layout/realfont.lua`, so a spec can measure a font string in its real face where the width matters:

```lua
local RealFont = dofile("scripts/measure-layout/realfont.lua")
RealFont.patch(label) -- GetStringWidth, GetUnboundedStringWidth, GetStringHeight and IsTruncated in its real face
```

`RealFont.install()`, which the harness's helper calls, does the same for every font string the fake client makes, by wrapping `dofile` for `spec/support/widgets.lua`. A spec shouldn't call it: every other spec keeps 6 units a byte.
