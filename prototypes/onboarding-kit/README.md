> **In the repo:** this is the dev's onboarding kit (`pagle-guide-kit.zip`, 18 Oct), kept as the look reference for [docs/spec/core/onboarding.md](../../docs/spec/core/onboarding.md), which wins wherever the two differ (the kit's `SPEC.md` is the draft it was adapted from; [the grilling](https://github.com/timemir/pagle-addon/issues/260#issuecomment-6335904394) lists the changes). Left out to keep the repo small: `tga/`, `previews/`, the probe's `Fonts/` (byte-identical to `addons/Pagle/media/fonts/`) and every texture but `GuideParts.blp` (the book textures are Core's `media/books`; `Samples` and the `Screen-*` stand-ins never ship). So the probe doesn't run from here as it is: install it from the zip, or copy those files back in.

# Pagle onboarding kit (the guide kit)

A first-time Angler gets a **letter**, which opens an eight-step **field guide** in the Fish Journal's book. After that they learn by fishing, with a **First evening list**, a **margin note** beside each first moment, and a **first look** set of notes the first time each window opens. This zip is everything an agent needs to build that in the addon.

## For the implementing agent: read in this order

1. **`SPEC.md`**: the behaviour, written as a spec file in the repo's own style (prefix `ONB`, proposed home `docs/spec/core/onboarding.md`). It covers ownership (Core vs each Module), triggers, state, the new Module-handle calls, every page's controls and what existing rule each one calls, settings, edge cases, an in-game exit check, and the **Decisions to confirm** list (things the current spec doesn't have yet). Nothing in it changes an existing rule.
2. **`canvas/`**: the 18 approved design boards as rendered images, numbered in flow order. They are the look; `SPEC.md` names the board for each rule.
3. **`PagleArtGuide/`**: a throwaway probe addon that draws every board in game with the real textures, and plays its motion and sounds. Its Lua is the layout reference: sizes and offsets are the canvas's CSS px, which are UI units. `GuideKit.lua` holds the widgets (nine-slice, margin note, pencil arrow, key cap, choice card, next-action button, coach bar, tracker, step ribbons), `Guide.lua` the eight steps, and `World.lua` the letter, the First evening scene, the first-moment notes and the first looks.
4. **`MOTION.md`, `SOUND.md`**: the timings and sound kits.

How the probe maps to the addon:

| Probe | Addon (SPEC.md) |
|---|---|
| `P.ShowLetter` | the letter, ONB-R10–R14: a Core frame in the toast column's place |
| `P.ShowGuide`, `P.StepRibbons`, `Guide.lua`'s `step{}` list | the guide and its step registry, ONB-R20–R27; each `step{}` becomes a `M:RegisterGuideStep` by its owner |
| `bindingField` in `Guide.lua` | the binding field, ONB-R40–R44. The probe only *reads* bindings (`GetBindingAction`, `GetBindingText`, `GetBindingName`) and never calls `SetBinding` |
| `P.Note`, `P.Arrow`, `P.Pointed`, `P.NoteIn` | margin notes, ONB-R50–R53 |
| `P.ShowLook`, `P.CoachBar` | first looks, ONB-R55–R58. The addon anchors notes to the real window and its regions, not to a screenshot |
| `P.Tracker`, `P.TickEvening` | the First evening list, ONB-R60–R63, docked in Core's tracker dock |
| `P.Sample`, `Samples` atlas | stand-ins only. The addon draws the real Nod, toast, banner and board art, standing still, as the Curio Shop's stage does |

The book shell (binding, parchment, strip, wax close, page turn) is the Ledger kit's, renamed so both probes can be installed at once. In the addon it is the same shell the Fish Journal uses, so the guide adds no new book art.

## Install the probe

Copy `PagleArtGuide` into the Forever client's `Interface\AddOns\`. At character select, tick **Pagle Art: Guide (throwaway)**, and tick **Load out of date AddOns** if needed. It can be installed beside the other `PagleArt*` probes.

## Commands

| Command | What it shows (canvas board) |
|---|---|
| `/pagleguide` or `letter` | The letter sliding in above the action bar, with the compartment tooltip ("1 · The letter arrives"). **Open the letter** opens the guide. |
| `/pagleguide guide` | The guide at its first step. Next, back, the ribbons, the skip links and the wax close all work. |
| `welcome`, `box`, `casting`, `clothes`, `moments`, `ledger`, `board`, `off` | Each step ("2 · Welcome" to "9 · Off you go"). Choice cards toggle, and **Start my board** changes to "Your board is up". |
| `casting`, then click the binding field and press a key | Listening, then Bound, or the conflict box if the key already does something (e.g. F: Assist Target). **Use F for fishing** only shows Bound; nothing is rebound. Esc goes back. |
| `without` | The guide with the Tackle Board off: seven ribbons, "3 of 7". |
| `turn` | Welcome, then a page turn to What's in the box. |
| `evening` | The First evening scene: the list with two items done and the Journal next, the next-action button reading Reel, a Nod, two notes ("First evening"). |
| `list`, then `tick` (repeatedly) | An empty list, then each tick; after the sixth it folds away. |
| `first` | All six first-moment notes ("Margin notes on first moments"). `first nod`, `toast`, `summary`, `uncharted`, `lure`, `fresh` show one. |
| `look journal`, `hunts`, `stats`, `board`, `shop` | Each first-look set over a stand-in of its window, with the coach bar ("First look · …"). |
| `sounds` | Plays the kit's sounds in turn, naming each. `sound` and `motion` turn sound and motion off and on. |
| `hide` | Clears the screen. |

## What to check

1. **It loads.** Chat says `Guide kit loaded`. A red `these fonts failed to load` line means a bundled TTF was rejected.
2. **Textures show.** No green squares and no white boxes. If one shows, copy its TGA from `tga/` into `Textures/`, delete the BLP and tell me which.
3. **Lines.** The pencil arrows are `Line` objects (`CreateLine`). Each should be one smooth curve with a two-stroke head and a red ring at its point. If they don't show at all, `CreateLine` isn't available on this client; report that, since the spec relies on it.
4. **Ribbons.** Their tops hide under the book's bottom edge. The current one hangs longer and drops as a page turns.
5. **The binding field.** Keys with modifiers read as the Key Bindings frame writes them (`SHIFT-F`), a bare Shift does nothing, and Esc cancels.
6. **Notes over the world.** The Casting step's note sits right of the book, on the world, and scales with the book.
7. **Fit.** `/console uiscale 1.15` (or Interface options): the guide and its ribbons still fit.

Report back with screenshots of each command, a short capture of `letter`, `turn` and `first`, and anything from this list that failed.

## Known limits

- **Stand-ins.** The first-look windows are screenshots of the other kits' renders; the samples on the Moments, Tackle Board and Off you go steps and in `first` are crops of them.
- **Straight notes.** The canvas tilts notes by ±1.3°. A frame can't rotate its text, so in game they are straight (SPEC.md › UI).
- **Inline styles.** One FontString has one font, so bold or italic runs inside a sentence keep their colour but are set in the line's face.
- **Icons.** The next-action button and the gear slots use stock icons as stand-ins; the addon uses the real spell, lure and set icons (QOL-R71).
- **Textures are BLP.** BLP2, DXT5, full mips, from `source/art/lib/blp.py`; they decode at 33–37 dB against the TGAs. `GuideParts` is 1024 x 2048, and each screen stand-in is 1024 x 1024 (about 9 MB of the probe's 14 MB; none of it ships in the addon).
- **Not tested in the client.** Everything was checked in the offline simulator only (`source/sim`), at UI scale 1, 0.64 and 1.15, against the canvas rendered in a browser (`previews/cmp-*` pairs are canvas above, simulator below).

## What's in the zip

```
SPEC.md                 the behaviour, ONB-R1–R107, for docs/spec/core/onboarding.md
README.md MOTION.md SOUND.md
canvas/                 the 18 design boards, in flow order
previews/               the probe in the simulator, one image per command (staged BLPs)
PagleArtGuide/          the probe addon (BLP textures, bundled OFL fonts)
tga/                    the textures as TGA, for a client that rejects a BLP
source/art/guide/generate.py   renders GuideParts and the stand-ins straight from the canvas
source/art/lib/         sprites.py (render + pack), blp.py (TGA → BLP), Fit/Motion/Sound.lua (shared by the probes)
source/sim/             sim.py + wowmock.lua: the offline simulator (now with Line support and inherited strata)
source/tools/           run.sh (every command through the simulator), pair.py, measure.py (canvas layout dump)
```
