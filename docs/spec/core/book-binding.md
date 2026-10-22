# Core: the book binding

> Status: In progress · Prefix `BIND` · Sources: [#351](https://github.com/timemir/wow-fish/issues/351), the four leather forks it folds (the Field guide's, the Stats book's, the Hunts board's and the Fish Journal's); ADR 0001, 0015

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
- **BIND-R13** Everything the renderer draws is Core's art in `Pagle/media/books`: the band and the vignette in `BookAtlas`, the corner pieces in `BindingCorners`, the gilt corner in `BindingGilt`, and Core's leather. The materials and the swatches are the bindings' own ([wallet-and-shop.md](wallet-and-shop.md)). A spec checks that every atlas the renderer reads names a BLP file that ships, and that every corner kind has its sprite.

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

---@class PagleBookBinding
---@field skin PagleBookBindingSkin  -- what draws it, for a spec or a probe to read; a book never changes it
---@field Look fun(self): PagleBindingLook
---@field SetLook fun(self, goodID: string?)
```

`frame` should have its size before the call, as the material is tiled to it (BIND-R10). The band's frame is six levels above `frame` and the features' one more, so a book puts what must cover the binding (its close button, its plate) ten levels up, as the Journal does. The look's fields are `ns.BindingLook`'s (`PagleBindingLook`): `texture` or `fill`, `tileW`, `tileH`, `tint`, `foot`, `band`, `gilt`, `giltShadow` (`{ r, g, b, a, x, y }`), `silver`, `corners`, `tooled`, `giltCorner`, `paperTint`, and the shop's `swatchAtlas` and `swatch`.

In Module specs, FakePagle's `Pagle.NewBookBinding` follows the slot and dips on Core's real logic (`logic/BookBinding.lua`), plays the page turn through the Module's client (`client.sounds`, `"836 SFX"`), and draws nothing: a book's `binding.skin` records the look it wears (`look`) and the dip's alpha (`dim`, 1 at rest).

## Tunables

| Tunable | Value | Rule |
|---|---|---|
| The material's inset | 7 units | BIND-R10 |
| The band's corners | 16 units | BIND-R11 |
| The corner pieces, the gilt corner | 44, 40 units | BIND-R12 |
| The tooled rule | `#d8b660`, 1.5 units, 9 and 12 units in | BIND-R12 |
| The dip | 0.4 s, ease-in-out, to 25% (the band and features to 55%), the change at 0.2 s | BIND-R20 |
| The page turn | sound kit 836, SFX | BIND-R21 |
