# Core: the book binding

> Status: In progress · Prefix `BIND` · Sources: [#351](https://github.com/timemir/pagle-addon/issues/351), the four leather forks it folds (the Field guide's, the Stats book's, the Hunts board's and the Fish Journal's); ADR 0001, 0015

Part of [Core](README.md). The Angler's books (the Fish Journal, the Hunts board, the Stats book) wear one **binding**, chosen once in the Curio Shop (ADR 0015). Core owns the slot that holds it, `core.binding` ([wallet-and-shop.md](wallet-and-shop.md)), and draws it: every book calls `Pagle.NewBookBinding` on its frame, and Core draws the leather round it and changes it when the Angler picks another binding. The book draws everything else on itself, its own crumbs, nameplate and paper inked from the look Core hands it.

## Purpose and boundary

**Owns (Core):** the one renderer of a binding on a book's frame: its material, its band, its corner pieces and features, the change of binding on every open book with its one page-turn sound, and the art it draws with (`Pagle/media/books`).

**Doesn't own:** which bindings exist and what each looks like (the `core.binding` slot, its goods and each one's look, `ns.BindingLook`; [wallet-and-shop.md](wallet-and-shop.md)), when an earned binding is owned (the Module that registers it), or anything inside the binding: a book's pages, its crumbs, its plate and its paper, which it inks itself from the look (BIND-R3).

## Rules

### The binding a book wears

- **BIND-R1** `Pagle.NewBookBinding(frame, options)` draws a binding on `frame` at once and returns its handle. By default it wears the **equipped** binding, the look of `Pagle.GetEquipped("core.binding")` (Field Leather's for an ID with no look of its own), and follows it (BIND-R20). With `options.pinned` it wears that good's binding always and never follows: the Field guide wears Field Leather, read before the Angler owns anything (ADR 0015), and a shop preview or a tour stop wears the good it shows.
- **BIND-R2** `binding:SetLook(goodID)` pins the book to `goodID`'s binding from then on, and `binding:SetLook(nil)` makes it follow the equipped binding again. Either redraws it at once, with no dip and no sound: what the book shows is its own choice, not a change the Angler made. `binding:Look()` returns the look it wears now.
- **BIND-R3** `options.onLook(look)` is called with the look each time the binding the book wears changes: once while `NewBookBinding` draws it, before it returns, then at each change, as the cover changes (BIND-R20's deepest point, or at once). The book inks its own parts from it, in the look's `gilt` and `giltShadow` (crumbs, fleurons), `silver` (a silver plate for brass) and `paperTint` (its paper); the renderer draws none of them.

### What it draws

- **BIND-R10** The **material**, over `frame` less 7 units at each edge (under the band's opaque lines): the look's `texture` tiled from that rectangle's top left, one repeat every `tileW` × `tileH` UI units, tiled again whenever the frame's size changes; or its `fill`, stretched over the rectangle once. It is shaded by a vertical gradient: the look's `tint` (white without one) at the top, the tint times `foot` at the bottom (Field Leather's 0.8 darkens toward the foot; 1 shades nothing). It is on `frame`'s `BACKGROUND` layer at `options.sublevel` (0 by default).
- **BIND-R11** The leather's **vignette** over the material, on the next sublevel, then the **band**: the books' binding sprite nine-sliced round the whole frame, its corners 16 units square, its edges stretched. The band is on a frame of its own six levels above `frame`, so what a book tucks under it (the Hunts board's ribbon tops) hides under it and its pages sit inside it. With the look's `band`, the band is desaturated and tinted to that tone; without one, it shows its own colours.
- **BIND-R12** The look's **features**, on a frame one level above the band's:
  - `corners`: that metal's corner piece (`brass`, `gold`, `silver`, `iron`, `bone`, `pearl` or `silverfiligree`) at each of the four corners, 44 units square (`options.cornerSize`), the top-left piece mirrored across and down into the others;
  - `tooled`: Tooled Leather's double gilt rule, two 1.5-unit lines in the kit's gilt (`#d8b660`) 9 and 12 units in from the frame's edges;
  - `giltCorner`: Verdigris's gilt corner at the top left, 40 units square (`options.giltCornerSize`).

  Each is hidden in a look without it.
- **BIND-R13** Everything the renderer draws is Core's art in `Pagle/media/books`: the band and the vignette in `BookAtlas`, the corner pieces in `BindingCorners`, the gilt corner in `BindingGilt`, a whole book's parts in `BindingParts2`, and Core's leather. The materials and the swatches are the bindings' own ([wallet-and-shop.md](wallet-and-shop.md)). A spec checks that every atlas the renderer reads names a BLP file that ships, and that every corner kind has its sprite. `scripts/tests/test_repo_textures.py` checks that every BLP under `addons/` has art in it: one whose top level decodes as entirely transparent or one flat colour fails, since the client draws it without an error. The shop expansion's 34 materials in `bindings/` shipped blank. All 34 have their art back: eleven re-rendered from the shop expansion kit's own canvas (`chartlinen`, `eelskin`, `frosthide`, `keeper`, `kodo`, `kraft`, `legend`, `morocco`, `snakeskin`, `velvet` and `wagersilk`), and two repainted as small repeating patterns that repeat every 32 × 32 units rather than at the closed book's 150 × 196 (`lacquer`, gilt koi and ripples on red lacquer, and `trophycase`, mahogany panels in gilt beading with a gilt fish medallion in one of four), and seventeen painted for #384 as small repeating patterns at their repeat and slot size as they were (`abyssal`, `brasscase`, `copper`, `driftwood`, `fiveseal`, `maplinen`, `monster`, `moss`, `netcork`, `oilskin`, `pearl`, `planks`, `sailcloth`, `scrimshaw`, `shagreen`, `tartan` and `turtle`), and the last four in a further pass for #384, at their repeat and slot size as they were (`bone`, with one large dark-outlined toggle pair at the tile's centre among the small ones; `canvas`, its "No.7" stencilled once at the centre, dark enough to read in the 24 px shop icon; `iridescent`, pastel overlapping scales in mint, teal and sky with violet, pink and butter drifting through; and `pathfinder`, with a large compass rose at the centre among the small roses and trails), all with their sources in `data/art/books/tga/bindings/`. The test's list of known blank materials is empty now; it stays, so a material that ships blank again while its art is redone can go back on it as a known failure ([#382](https://github.com/timemir/pagle-addon/issues/382), [#384](https://github.com/timemir/pagle-addon/issues/384)).

#### A whole book's parts

The Curio Shop's second round's ten bindings (LED-R118, SHOP-R25) are whole books: each has a closed cover of its own (the shop's preview, in `Bindings3`), and on the open book, beside its material and band, four parts of its own, each a look field only they set (`BindingParts2`, the round-two kit's goods.json, measured on its 920 × 600 Journal). Every other binding has none of them, and draws exactly as BIND-R10–R12 say. All four are on the features' frame (BIND-R12), so they dip with the band (BIND-R20).

- **BIND-R14** `clasp`: the clasp on the fore-edge, at its sprite's size (110 high), its left edge `claspX` units from the frame's right edge (the kit's place less 920: −22 to −54, so it sits on the band and stands out past it), centred down the frame's right edge, over the corner pieces (sublevel 3).
- **BIND-R15** `ribbon`: the silk ribbon, its sprite 32 × 136 of which only the foot shows, 32 × 60 (the sprite's top cropped away by its texture coordinates, its swallowtail notch kept), under the corner pieces (sublevel 0), hanging from the pages' foot out past the frame's by a short tail: its top left 60 units right of the pages' centre and 24 up into their foot when the book passes `options.pages` (the page block's rect in the frame, `{ x, y, w, h }` from its top left), else 60 right of the frame's centre and 40 up from its foot (the same place on the kit's Journal, its pages 884 × 546 at 18, 38). So 40 units of it lie over the book and 20 hang below the frame's foot, enough to read as a bookmark without covering the screen under the book (the dev's call, after the whole sprite's 96 hung out). No book's shell anchors it.
- **BIND-R16** `fillet`: a line round the binding in its own colour, at 75%, 1.6 units wide and 5 units in from the frame's edges (four edges, as the tooled rule's).
- **BIND-R17** `cornerArt`: its own corner piece in place of a metal's, 76 units square standing 4 out past each corner (both at the corner pieces' 44, scaled with `options.cornerSize`), the top-left piece mirrored across and down into the others as BIND-R12's. A look has at most one of `corners` and `cornerArt`; changing to a look with `corners` puts the pieces back at their size, at the corners.

### A change of binding

- **BIND-R20** When `AppearanceChanged` fires for `core.binding` (SHOP-R33), every book that follows the equipped binding (BIND-R1) and doesn't already wear the new one changes to it. A book shown now (`frame:IsVisible()`) **dips** while Core's Animations setting is on (`Pagle.IsAnimationsOn()`): the material fades to a quarter and back over 0.4 s (ease-in-out), the band and the features to 0.4 + 0.6 times the material's alpha (55% at the deepest), and the cover changes at the deepest point, 0.2 s in. A book not shown, or any book while the setting is off, changes at once. A change during a dip starts it again from rest, toward the newest binding.
- **BIND-R21** Core plays the **page turn** (IG_ABILITY_PAGE_TURN, sound kit 836, on the SFX channel) **once** for each change that BIND-R20 changes at least one shown book for, however many are open, and whether or not things move. With no book shown, or none that changes, it plays nothing. A book never plays a sound of its own for a change of binding.
- **BIND-R22** A pinned book (BIND-R1, BIND-R2) ignores `AppearanceChanged`: it neither dips nor counts toward BIND-R21's sound.

### Edge cases

- **BIND-R90** A book changed while hidden (BIND-R20) is drawn in the new binding already when it next shows: it never dips on showing.
- **BIND-R91** An equipped binding whose Module is off falls back to Field Leather (SHOP-R32), and `AppearanceChanged` brings the change, so an open book dips to Field Leather and back to the earned binding when its Module returns.

## Contracts

### `Pagle.NewBookBinding(frame, options?)`

```lua
---@class PagleBookBindingOptions
---@field pinned? string            -- a binding good to wear always, in place of the equipped one (BIND-R1)
---@field onLook? fun(look: PagleBindingLook) -- the look worn, at creation and at each change (BIND-R3)
---@field sublevel? integer         -- the material's BACKGROUND sublevel, the vignette's is one more (0)
---@field cornerSize? number        -- the corner pieces' size (44)
---@field giltCornerSize? number    -- the gilt corner's size (40)
---@field pages? { x: number, y: number, w: number, h: number } -- the page block in the frame, for the ribbon (BIND-R15)

---@class PagleBookBinding
---@field skin PagleBookBindingSkin  -- what draws it, for a spec or a probe to read; a book never changes it
---@field Look fun(self): PagleBindingLook
---@field SetLook fun(self, goodID: string?)
```

`frame` should have its size before the call, as the material is tiled to it (BIND-R10). The band's frame is six levels above `frame` and the features' one more, so a book puts what must cover the binding (its close button, its plate) ten levels up, as the Journal does. The look's fields are `ns.BindingLook`'s (`PagleBindingLook`): `texture` or `fill`, `tileW`, `tileH`, `tint`, `foot`, `band`, `gilt`, `giltShadow` (`{ r, g, b, a, x, y }`), `silver`, `corners`, `tooled`, `giltCorner`, `paperTint`, the shop's `swatchAtlas` and `swatch`, and, for the second round's whole books only, `cornerArt`, `clasp`, `claspX`, `ribbon` and `fillet` (BIND-R14–R17).

In Module specs, FakePagle's `Pagle.NewBookBinding` follows the slot and dips on Core's real logic (`logic/BookBinding.lua`), plays the page turn through the Module's client (`client.sounds`, `"836 SFX"`), and draws nothing: a book's `binding.skin` records the look it wears (`look`) and the dip's alpha (`dim`, 1 at rest).

## Tunables

| Tunable | Value | Rule |
|---|---|---|
| The material's inset | 7 units | BIND-R10 |
| The band's corners | 16 units | BIND-R11 |
| The corner pieces, the gilt corner | 44, 40 units | BIND-R12 |
| The tooled rule | `#d8b660`, 1.5 units, 9 and 12 units in | BIND-R12 |
| A whole book's clasp | its left edge `claspX` from the frame's right edge, centred down it | BIND-R14 |
| A whole book's ribbon | 32 × 60 (the foot of its 32 × 136 sprite, notch kept), 20 below the frame's foot; 60 right of the pages' centre and 24 up into their foot, else 60 right of the frame's centre and 40 up from its foot | BIND-R15 |
| A whole book's fillet | 75%, 1.6 units, 5 units in | BIND-R16 |
| A whole book's corner art | 76 units, 4 out past each corner, at the corner pieces' 44 | BIND-R17 |
| The dip | 0.4 s, ease-in-out, to 25% (the band and features to 55%), the change at 0.2 s | BIND-R20 |
| The page turn | sound kit 836, SFX | BIND-R21 |
