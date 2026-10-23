# Core: the book shell

> Status: In progress · Prefix `BOOK` · Sources: [#357](https://github.com/timemir/pagle-addon/issues/357), [#319](https://github.com/timemir/pagle-addon/issues/319), the four shells it folds (the Stats book's, which is the base, the Fish Journal's, the Hunts board's and the Field guide's); ADR 0001, 0015, 0016

Part of [Core](README.md). The Fish Journal, the Stats book, the Hunts board and the Field guide are one kind of window: two parchment pages in a binding, a gilt strip of crumbs above them, a wax close button, a brass nameplate, ribbons, a page router and a page turn (ADR 0016). Core draws that **shell** once: a book calls `Pagle.NewBook(options)` and gets a handle that opens, closes, routes and turns, and draws only its own pages, its leather anchors (a search slip, a clock, a live line) and its own effects.

## Purpose and boundary

**Owns (Core):** the book's window (strata, fit, clamp, Esc, raise, drag, its saved position), its open and close fades and sounds, the binding round it (through `Pagle.NewBookBinding`, [book-binding.md](book-binding.md)), the two parchment pages and the spine, the strip's crumbs and fleurons, the back link, the nameplate, the wax close and "?" buttons, the ribbons, the page router and the page turn, and the art it draws them with (`Pagle/media/books`).

**Doesn't own:** what a page shows (the book's renderers), what each crumb and ribbon says and where it goes (the book's lists), what its leather anchors hold, when a book opens (its entry points), and any effect a book adds through the turn hook (BOOK-R33).

## Rules

### The handle

- **BOOK-R1** `Pagle.NewBook(options)` returns the book's handle at once and builds no frame: the frame is built at the book's first opening, so a Module that never opens its book makes no frames (CORE-R13). It raises on options it can't use: no `id` or `name`, an `id` another book took, no `pages`, or a `home` its pages refuse (BOOK-R20).
- **BOOK-R2** The frame is named `options.name` and is in `UISpecialFrames`, so Esc closes it. It is a plain, non-secure frame: it opens and works in combat and while restricted.

### The window

- **BOOK-R3** The frame is `options.width` × `options.height` units, on `options.strata` (`"HIGH"` by default), top-level (`SetToplevel`, so a click brings it over the other windows of its strata) and raised at each opening. It is clamped to the screen with the ribbons' hang as its bottom inset, so the ribbons stay on screen too. At each opening it is fitted to the screen with `Pagle.FitToScreen` (keeping its place), its extent the frame plus 30 units across (the close past the top right) and 100 down (the ribbons).
- **BOOK-R4** **Opening** shows the frame, plays the book's open sound (IG_SPELLBOOK_OPEN, sound kit 829) and fades it in over 0.16 s (ease-out). **Closing** (`book:Close()`, the wax close, a toggle) fades it out over 0.12 s (easing in, `Bezier(0.42, 0, 1, 1)`), then hides it; however it hides (Esc too), the close sound (IG_SPELLBOOK_CLOSE, 830) plays. With Animations off (`Pagle.IsAnimationsOn()`), both happen at once; the sounds play either way, on the SFX channel. Opened again while fading out, it stays, whole. Hiding UIParent (Alt-Z) isn't closing: the book neither closes nor plays a sound.
- **BOOK-R5** A **movable** book (the default) is moved by dragging its leather: the pages, the buttons and the anchors take the mouse, so a drag starts only on the binding. Where it is left is saved at each drag's end in `PagleDB.profile.books[id]`, as `{ point, relativePoint, x, y }` relative to UIParent and in UIParent's units, so a change of UI scale or of the fit never moves it. Each opening puts it there, or, with none saved, at the screen's centre lifted 40 units (half the ribbons' hang). The client never saves it in its own layout cache (`SetUserPlaced(false)`).
- **BOOK-R6** A book with `options.fixed` never moves: it opens at the screen's centre, lifted 40 units, takes no drag and saves nothing (the Field guide). `options.dim` (an alpha, the Field guide's 0.58) draws a dim of the world behind the book on its strata while it shows, in `#060808` at that alpha; the dim fades in and out with the book (BOOK-R4) and is whole again once the book is closed or settled (BOOK-R35). The dim takes no mouse, so the game keeps running behind it.

### The leather and the pages

- **BOOK-R10** The binding is Core's renderer: `Pagle.NewBookBinding(frame, { pinned = options.pinned, onLook = … })`, the handle's `binding`, which a book may `SetLook` (the Hunts board's `Board:SetBinding`). With each look it wears, the shell inks its own parts (BIND-R3): the crumbs in the look's `gilt` and `giltShadow`, the fleurons toned toward that gilt, the nameplate silver when `silver`, and the paper under `paperTint`; then it calls `options.onLook(look)` so the book inks its own.
- **BOOK-R11** The **pages** are two parchments side by side, between the leather's sides (`options.side`, 18 units), the strip above them (`options.strip`, 38) and the foot band below them (`options.foot`, 16; the Stats book's 36). The left page takes `split / (split + 1)` of the room across (`options.split`, 1 by default; the Hunts board's 1.45). Each is the books' parchment (mirrored on the right page, so the two don't match), its outer corners rounded 6 units (Core's corner masks), with the spine's 40-unit gutter shade on its inner edge. The paper takes the mouse. Each page has a **body** inside its padding (`options.pad`, 28 across, 22 at the top, 20 at the foot).
- **BOOK-R12** The **strip** above the pages carries the **crumbs** (BOOK-R24) at its left, midway between the leather's band (7 units in) and the pages, in the gilt font (Marcellus, 14, shadowed), each after the first behind a fleuron. Each crumb with a target opens it, and brightens to `#fff4c8` under the mouse; the trail is cut short before `options.stripRoom` units at the strip's right (0 by default), which the book keeps for its anchors. `book:SetStripText(text)` writes words at the strip's right in the gilt, `#c9b27a` (the Field guide's "{n} of {m}"); nil clears them.
- **BOOK-R13** `options.back` adds a **back link** at the left page's foot, in its words (the Journal's "« back"), in the hand (`#7a3a10`, turning `#9a2a1a` under the mouse). It shows while `options.back.target(place)` gives a target, and opens it.
- **BOOK-R14** `options.plate` adds the brass **nameplate** on the leather, its top left at `plate.x`, `plate.y` units from the frame's (the Stats book's 30, 605), ten levels up: the books' brass plate three-sliced to its words (Marcellus, 12, `#2a1a04`), which `book:SetPlate(text, tooltip?)` writes. It turns silver with a look's `silver` (BOOK-R10). With `tooltip` (lines, the first its heading), the plate shows them in GameTooltip while the mouse is over it (the Hunts board's earned titles, HNT-R61); without, it takes no mouse.
- **BOOK-R15** The **wax close** is 26 units square, centred on the frame's top right corner 3 units in (`CENTER`, `TOPRIGHT`, -3, -3), ten levels up, pressed while clicked and glowing under the mouse; a click closes the book (BOOK-R4). `options.help` adds the **"?"** in the same wax, 4 units left of the close, the same size and level, a gilt "?" (`#f4dfa8`) pressed into the seal, darker while pressed; its tooltip (`help.tooltip`) shows under it while the mouse is over it, and a click calls `help.onClick`. `book:SetHelpShown(shown)` shows or hides it (hidden on a Core without First looks, ONB-R90).
- **BOOK-R16** **Leather anchors**: `options.anchors` names frames the shell makes on the leather, each placed by its `point`, `x`, `y` (from the frame's same point) and sized `width` × `height`, ten levels up, taking the mouse: the Stats book's search slip and live line, the Journal's search slip, the Hunts board's clock and checkbox. `book.anchors[name]` is each one; `book:RegisterLeather(name, renderer)` draws one at each draw, after the pages (BOOK-R21).

### The ribbons

- **BOOK-R17** **Ribbons** hang from under the leather's foot, left to right from `options.ribbonsLeft` units (40 by default; the Stats book's 456), one geometry for every book: 96 units wide with a 12-unit gap, their tops tucked 2 units under the band (a level under it), hanging 75 units, the chosen one 86. Each is the books' grosgrain ribbon tinted to its `color`, with a gold stitch over it and its words in gilt (Marcellus, 12, shadowed; `#efd286`, the chosen one's `#fff0bc`) 31 units above its swallowtail end, wrapped to at most two lines 82 units across and growing upward, so a second line raises the name; the chosen one and one under the mouse brighten (×1.13). A change of the chosen ribbon while the book is open runs the lengths over 0.2 s (ease-out); at once with Animations off.
- **BOOK-R18** The ribbons are `options.ribbons`, and `book:SetRibbons(list)` replaces them at any time, open or not (the Hunts board's ribbon per set): ribbons past the new list's end hide. A ribbon's click opens its `target`, a place or a function giving one when clicked (the Stats book's *Where I am*). The chosen ribbon is the one `options.chosenRibbon(place)` names, or by default the first whose target's page is the page shown.
- **BOOK-R19** A ribbon's `count` is written under its name in the hand (Caveat, 15, shadowed, `#e8c96a`), 17 units above its swallowtail end, its name rising from 31 to 38 (the Hunts board's "{n} on", HNT-R162). A ribbon's `tooltip` (lines, the first its heading) shows in GameTooltip above it while the mouse is over it. `book:RibbonFrame(id)` is the shown ribbon with that id, nil for none or before the first opening (a First look's arrow points at it, ONB-R58).

### The router

- **BOOK-R20** `options.pages` names the book's pages, each with what it keeps of a place (`keeps`, its fields besides `page`), what it can't do without (`needs`, a field) and its place in the turn order (`order`, a number). A **place** is a table with its `page` and those fields. `book:Open(place)` raises on a page the book doesn't have or a place without what its page needs, and the book stays where it was; otherwise the book is there, keeping only what its page keeps. `book:Place()` returns a copy. The first opening after a login or `/reload` shows `options.home` (the book's own choice, BOOK-R22, may open it elsewhere).
- **BOOK-R21** `book:RegisterPage(page, side, renderer)` registers what draws side `"left"` or `"right"` of `page` (a later one replaces it; it raises on an unknown page or side). At each draw while open, each side's renderer draws on that side's own content frame, inside a scroll frame over the body, as wide as the body: `renderer(content, place)` returns the height it drew, so the body scrolls (a mouse wheel notch glides a third of it, `Pagle.WheelScroll`) when that overflows; nil fits the body. A side with no renderer is blank. A redraw of the same place keeps each side's scroll; another place starts at the top. Then the shell draws the crumbs, the ribbons, the back link and each registered anchor, and calls `options.onDraw(place, notice)` last. `book:QueueDraw()` redraws on the next frame, once however many ask in it, and does nothing while the book is closed.
- **BOOK-R22** While `options.notice()` gives words (the Stats book's "Updating my records…", STA-R72), both pages show only those words in the book's hand (or the book's own drawing of them, BOOK-R25), no renderer runs and no turn plays; the crumbs, ribbons and anchors still draw (an anchor's renderer gets `notice` to disable itself).
- **BOOK-R23** `book:Open(place?, how?)` opens the book if it is closed (BOOK-R4), at `place` or where it was left, and draws it; open, it goes there in place and never closes. `book:Toggle()` closes an open book (not one fading out) and opens a closed one. `book:IsShown()` reads whether it is open (not while it fades out after a close), `book:Showing()` which showing this is (it changes each time the book closes).
- **BOOK-R24** The **crumbs** are `options.trail(place)`: `{ text, target? }` in order, the book's words. The shell lays them (BOOK-R12) and each with a target opens it.
- **BOOK-R25** A book that gives `options.noticeView(sides, words)` draws its notice itself (the Journal's quill, LED-R122): each page has a **notice layer**, a frame over its whole paper above the body, and while the notice shows (BOOK-R22) the shell shows both layers and calls `noticeView(sides, words)` at each draw, `sides.left` and `sides.right` the layers and `words` the notice's, in place of writing the words itself. When the notice ends the shell hides both layers, so a layer's `OnHide` is the book's signal to stop what it set moving there (as is the book's closing). A book without it has no layers, and the shell writes the words (BOOK-R22).

### The page turn

- **BOOK-R30** `how.motion` says how a book already open moves to `place`: `"auto"` (the default) turns the page when the page shown changes and draws in place when it doesn't; `"turn"` turns it even on the same page (the Journal's forced turn); `"fade"` crossfades each side to the new drawing over 0.2 s (the Journal's fish picked on a zone page); `"still"` draws in place. A book opening from closed never turns: it fades in.
- **BOOK-R31** The **turn** is the kit's: forward, the right page lifts away toward the spine (0.22 s, `Bezier(0.5, 0, 0.9, 0.6)`), uncovering the new right page, then lands on the left from the spine outward (0.28 s, `Bezier(0.1, 0.4, 0.4, 1)`), covering the old left page; backward is its mirror image. A fold shade darkens the lifting page (up to 28%), a 26-unit shadow (up to 32%) falls beside the moving edge, with a 1.5-unit light line (55%) on the edge itself; both fade as the page lands. The fold is a frame 40 levels above the book's. The crumbs change as the page passes the spine. It plays the page turn (IG_ABILITY_PAGE_TURN, 836, SFX). Its direction is forward when the new page's `order` is above the old one's (`how.forward` overrides it).
- **BOOK-R32** With Animations off a turn or a crossfade settles at once and silently. A new turn, a close, or a draw that can't turn (BOOK-R22) settles the one under way at once: its new spread whole, its old one gone.
- **BOOK-R33** `options.onTurn(turn, phase, k)` is the turn's hook, for a book's own effect (the Hunts board's fold, the Stats book's ink reveal): `phase` `"start"` as it begins, `"lift"` and `"land"` at each step of its halves with `k` from 0 to 1, `"midway"` at the spine and `"done"` when it has settled, however (with Animations off, `"start"`, `"midway"` and `"done"` at once). `turn` is `{ from, to, forward, papers }`: the sides turned from and to (each `{ clip, scroll, content, paper }`, nil for a blank side) and the pages' paper frames.
- **BOOK-R34** `options.how(from, to)` is asked for every `Open` made without a `how` (a crumb, the back link, a ribbon, the book's own calls), with the place the book was at and the place it goes to, and its answer is used as that `how`; nil is `"auto"` (the Journal turns by its crumbs' depth and crossfades within one page).
- **BOOK-R35** `book:Settle()` ends every motion of the book at once, as settled: an opening fade (the book whole), a closing fade (the book closed) and a turn or crossfade (its new spread whole), for a tour stop's screenshot.

### Callbacks

- **BOOK-R40** `options.onShow()` runs as the book opens from closed, after its first draw; `options.onHide()` runs once each time it closes, however it closes, after a turn under way settles.

### Edge cases

- **BOOK-R90** A saved position that can no longer be read (a point the client doesn't know) is dropped, and the book opens centred.

## Contracts

### `Pagle.NewBook(options)`

```lua
---@alias PagleBookSide "left"|"right"

--- A place in a book: its page and what that page keeps (BOOK-R20). The book's own fields, besides `page`.
---@class PagleBookPlace
---@field page string

--- One page of a book (BOOK-R20).
---@class PagleBookPageDef
---@field keeps? string[]   -- the place's fields it keeps besides `page` ({})
---@field needs? string     -- a field it can't do without
---@field order? number     -- its place in the turn order (0)

--- One crumb (BOOK-R24).
---@class PagleBookCrumb
---@field text string
---@field target? PagleBookPlace     -- nil: it does nothing (the page itself)

--- One ribbon (BOOK-R17, BOOK-R18).
---@class PagleBookRibbon
---@field id string
---@field text string
---@field color number[]                                  -- { r, g, b }, 0 to 1
---@field target PagleBookPlace|fun(): PagleBookPlace
---@field count? string                                   -- words under its name, in the hand (BOOK-R19)
---@field tooltip? string[]                               -- tooltip lines on hover (BOOK-R19)

--- A leather anchor's place (BOOK-R16): its `point` on the frame, `x`, `y` from that point, and its size.
---@class PagleBookAnchorDef
---@field point FramePoint
---@field x number
---@field y number
---@field width number
---@field height number

--- One side of one page as the shell draws it (BOOK-R21, BOOK-R33).
---@class PagleBookSideView
---@field clip Frame          -- on the side's paper, the page turn narrows it
---@field scroll ScrollFrame  -- over the body
---@field content Frame       -- what the renderer draws on
---@field paper Frame         -- the side's paper

---@class PagleBookTurn
---@field from table<PagleBookSide, PagleBookSideView?>
---@field to table<PagleBookSide, PagleBookSideView?>
---@field forward boolean
---@field papers table<PagleBookSide, Frame>

---@alias PagleBookTurnPhase "start"|"lift"|"midway"|"land"|"done"

---@class PagleBookOpenHow
---@field motion? "auto"|"turn"|"fade"|"still"   -- BOOK-R30 ("auto")
---@field forward? boolean                        -- a turn's direction, in place of the pages' order

---@class PagleBookOptions
---@field id string                        -- the book's key, unique: its saved position (BOOK-R5)
---@field name string                      -- the frame's global name, for UISpecialFrames (BOOK-R2)
---@field width number
---@field height number
---@field pages table<string, PagleBookPageDef>
---@field home PagleBookPlace              -- the first opening's place (BOOK-R20)
---@field strata? FrameStrata              -- ("HIGH")
---@field fixed? boolean                   -- never moves, never saved (BOOK-R6)
---@field dim? number                      -- the world's dim behind it, an alpha (BOOK-R6)
---@field pinned? string                   -- a binding good to wear always (BIND-R1)
---@field side? number                     -- the leather at the sides (18)
---@field strip? number                    -- the strip above the pages (38)
---@field foot? number                     -- the band below them (16)
---@field split? number                    -- the left page's width over the right's (1)
---@field pad? { x: number, top: number, bottom: number } -- a body's padding ({ x = 28, top = 22, bottom = 20 })
---@field stripRoom? number                -- the strip's room kept at its right, past the crumbs (0)
---@field trail? fun(place: PagleBookPlace): PagleBookCrumb[]   -- the crumbs (none)
---@field back? { text: string, target: fun(place: PagleBookPlace): PagleBookPlace? } -- the back link (BOOK-R13)
---@field plate? { x: number, y: number }  -- the nameplate's top left (BOOK-R14)
---@field help? { tooltip: string, onClick: fun() } -- the "?" (BOOK-R15)
---@field anchors? table<string, PagleBookAnchorDef> -- the leather anchors (BOOK-R16)
---@field ribbons? PagleBookRibbon[]       -- (BOOK-R18)
---@field ribbonsLeft? number              -- the first ribbon's left (40)
---@field chosenRibbon? fun(place: PagleBookPlace): string? -- the chosen ribbon's id (BOOK-R18)
---@field notice? fun(): string?           -- words both pages show in place of their renderers (BOOK-R22)
---@field noticeView? fun(sides: table<PagleBookSide, Frame>, words: string) -- draws the notice itself (BOOK-R25)
---@field onLook? fun(look: PagleBindingLook)  -- after the shell inks its own parts (BOOK-R10)
---@field onDraw? fun(place: PagleBookPlace, notice: string?) -- last at each draw (BOOK-R21)
---@field onTurn? fun(turn: PagleBookTurn, phase: PagleBookTurnPhase, k: number?) -- the turn's hook (BOOK-R33)
---@field how? fun(from: PagleBookPlace, to: PagleBookPlace): PagleBookOpenHow? -- an Open's how when it gives none (BOOK-R34)
---@field onShow? fun()
---@field onHide? fun()

---@class PagleBookFrame: Frame
---@field papers table<PagleBookSide, Frame>    -- each page's paper
---@field bodies table<PagleBookSide, Frame>    -- each page's body, inside its padding

---@class PagleBook
---@field frame PagleBookFrame?                       -- nil until the first opening (BOOK-R1)
---@field binding PagleBookBinding?                   -- Core's renderer, from the first opening (BOOK-R10)
---@field anchors table<string, Frame>                -- the leather anchors, from the first opening (BOOK-R16)
---@field RegisterPage fun(self, page: string, side: PagleBookSide, renderer: fun(content: Frame, place: PagleBookPlace): number?)
---@field RegisterLeather fun(self, name: string, renderer: fun(anchor: Frame, place: PagleBookPlace, notice: string?))
---@field Open fun(self, place: PagleBookPlace?, how: PagleBookOpenHow?)
---@field Close fun(self)
---@field Settle fun(self)                            -- ends every motion at once (BOOK-R35)
---@field Toggle fun(self)
---@field IsShown fun(self): boolean
---@field Showing fun(self): integer
---@field Place fun(self): PagleBookPlace
---@field Draw fun(self)
---@field QueueDraw fun(self)
---@field SetRibbons fun(self, ribbons: PagleBookRibbon[])
---@field SetPlate fun(self, text: string, tooltip: string[]?)
---@field RibbonFrame fun(self, id: string): Button?
---@field SetStripText fun(self, text: string?)
---@field SetHelpShown fun(self, shown: boolean)
---@field Look fun(self): PagleBindingLook?           -- the look it wears now, nil before the first opening
```

A book makes its handle when its file loads and registers its pages and anchors on it; the frame, the binding and the anchors exist from the first `Open`. Everything a book draws on the leather beyond the anchors goes on `book.frame` at ten levels up, over the binding's band (six up) and features (seven up); a ribbon is one level up, under the band.

In Module specs, FakePagle's `Pagle.NewBook` is Core's real shell, built on the Module's client fake at the first opening: its frames are the widget fake's, so a spec clicks a ribbon, a crumb or the close and reads the pages' content. Its saved positions are in `fake.profile.books`.

## Data

`PagleDB.profile.books`: each movable book's saved position by its `id`, `{ point, relativePoint, x, y }`, absent until the Angler drags it (BOOK-R5).

## Tunables

| Tunable | Value | Rule |
|---|---|---|
| The open and close fades | 0.16 s ease-out, 0.12 s `Bezier(0.42, 0, 1, 1)` | BOOK-R4 |
| The open, close and turn sounds | sound kits 829, 830, 836, SFX | BOOK-R4, BOOK-R31 |
| The lift without a saved position | 40 units | BOOK-R5, BOOK-R6 |
| The extent fitted to the screen | the frame plus 30 across, 100 down | BOOK-R3 |
| The leather's sides, strip, foot | 18, 38, 16 units | BOOK-R11 |
| A body's padding | 28 across, 22 top, 20 foot | BOOK-R11 |
| The pages' corners, the gutter | 6, 40 units | BOOK-R11 |
| The wax close, the "?" | 26 units, 4 apart, ten levels up | BOOK-R15 |
| The ribbons | 96 wide, 12 apart, 75 and 86 long, 2 tucked, ×1.13 brighter, 0.2 s | BOOK-R17 |
| A ribbon's words | its name 31 above its end, 38 over a count; the count 17 | BOOK-R17, BOOK-R19 |
| The turn | 0.22 s lift, 0.28 s land, fold 28%, cast 26 units at 32%, edge 1.5 units at 55%, 40 levels up | BOOK-R31 |
| The crossfade | 0.2 s | BOOK-R30 |
