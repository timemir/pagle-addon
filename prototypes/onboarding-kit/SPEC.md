# Core: Onboarding (the letter, the field guide, margin notes, the First evening list)

> Status: Draft for review · Prefix `ONB` · Proposed home: `docs/spec/core/onboarding.md` · Sources: the "Onboarding redesign" canvas (18 boards, renders in `canvas/`), the probe addon `PagleArtGuide` in this kit · Milestone: proposed M5.5 (needs every Module's views, so after M5–M7 surfaces exist; each step lands with its Module if built earlier)

This file is written in the spec's own style so it can be dropped into `docs/spec/core/` and split into build tickets. Every capitalised term means what `CONTEXT.md` says. Every number in brackets that isn't `ONB-` points at the existing spec. **Where this file adds something the spec doesn't have yet, it says so under [Decisions to confirm](#decisions-to-confirm)**; nothing here changes an existing rule.

## Purpose and boundary

A first-time Angler gets a **letter**, which opens an eight-step **field guide** in the Fish Journal's book shell. After it, they learn by fishing: a **First evening list** in the tracker dock, a **margin note** beside each first moment, and a **first look** set of notes the first time each window opens.

**Core owns:** the letter, the guide's book, its ribbons and navigation, the step registry, Core's own steps (Welcome, What's in the box, Moments, Off you go), the margin note widget and its once-only bookkeeping, the first-look sets' display, the First evening list, `/pagle guide`, the "Getting started" rows on the Settings root, and the onboarding state in `PagleDB.global.onboarding`.

**Modules own:** their own guide steps (QoL: Casting and Fishing clothes; Ledger: Your Ledger; Tackle Board: the Tackle Board), the text of their margin notes and first-look notes, which of their regions each note points at, and telling Core when one of their First evening items is done. A Module that is off registers nothing, so its steps, notes and items don't exist (CORE-R17).

**Doesn't own:** what any control on a step does. Every control calls the owner's existing action: `Input` and the next-action button (QOL-R12, QOL-R70), the fishing set and Swap gear (QOL-R40–R46), the Announcement settings (announcements.md › Settings), Start my board (TKB-R5). The guide is a second door to settings that already exist, plus two new key-binding flows (ONB-R40–R44).

**Uses from Core:** CORE-R12 (Module handle), CORE-R17, CORE-R19 (`ModulesChanged`), CORE-R30 (restriction), CORE-R40–R44 (Settings root), CORE-R50 (compartment menu labels, for the What's in the box step), CORE-R60–R62 (`/pagle`), CORE-R70–R73 (tracker dock), ANN-R4/R13/R20/R21/R40/R53 (moments, the catch toast, lanes, cards, Cozy mode, the Session summary), LOG-R60–R63 (Sessions), `Pagle.IsAnimationsOn()`.

Modules still see only Core (ADR 0001): a Module's step never reads another Module, and Core's What's in the box step reads only the registered Modules' `def` fields.

## Rules

### State and who sees what

- **ONB-R1** Onboarding state is account-wide, in `PagleDB.global.onboarding` (see [Data](#data)). It is created at the first `PLAYER_LOGIN` that finds it missing, with `letter` set by ONB-R2.
- **ONB-R2** **New or returning.** When the state is created: if the Catch log already holds at least one Cast entry (a reinstall, a new computer with old SavedVariables, a Pagle that predates this feature), `letter = "returning"`; otherwise `letter = "waiting"`. A returning Angler gets no letter and no First evening list; at the first `SessionStarted` or 20 s after login, whichever comes first, Core raises one `nod` (no `cast`), "Welcome back", text "/pagle guide if you want the tour". Margin notes and first looks still apply to them, each still once (ONB-R50).
- **ONB-R3** **Another character.** The state is account-wide, so a second character sees no letter. The first time a character other than the one that opened the letter logs in (`characters` in the state doesn't hold its GUID), Core raises one `nod`, "Same Ledger", text "fishing clothes are per character" — only while QoL is registered; otherwise nothing. The GUID is then added.

### The letter

- **ONB-R10** While `letter == "waiting"`, Core shows the **letter** once per login, when all of these hold: the login's held Announcements, Write-up and "Your last session" card have shown and closed (ANN-R21), `Pagle.IsRestricted()` is false, `IsInInstance()` is false, and 4 s have passed since `PLAYER_ENTERING_WORLD`. If a condition fails it waits and checks again on `RestrictionChanged`, `ZONE_CHANGED_NEW_AREA` and when a card closes.
- **ONB-R11** The letter is a frame of Core's own in the toast column's place (above the action bar, centred), not an Announcement: it never counts as an interruption (ANN-R30), plays the `letter` sound, is never held by Cozy mode and has no expiry. It reads, kicker "A letter, left on the dock", hand "Pagle has arrived. Open it whenever you’re ready; it’ll keep.", with **Open the letter** and **Later**.
- **ONB-R12** **Open the letter** sets `letter = "opened"`, hides the letter and opens the guide at its first step (ONB-R20). **Later** hides it and sets `letter = "later"`; at the next login it shows once more (as ONB-R10), and **Later** a second time sets `letter = "declined"`. A declined or opened letter never shows again; the guide is then reached only from `/pagle guide` and Settings (ONB-R80, ONB-R81).
- **ONB-R13** While the letter shows, the compartment entry's tooltip line reads "A letter for you" (CORE-R51's line shows instead while it applies).
- **ONB-R14** A restriction that starts while the letter shows hides it; it shows again when the restriction ends (ONB-R10's checks).

### The field guide

- **ONB-R20** The **guide** is the Fish Journal's book shell at 920 x 600 (`media/book`, the Ledger art kit's shell, LED-R112's binding fixed to the default), named "Pagle · A field guide" in the strip's crumbs, with "{n} of {m}" at the strip's right, and a row of **step ribbons** hanging under its bottom edge (ONB-R24). It opens from the letter, `/pagle guide` and the Settings root's **Show me around again**, in `DIALOG` strata over a dim of the world (alpha 0.58), and is in `UISpecialFrames` (Esc closes it).
- **ONB-R21** **Steps.** The guide is the registered steps in `order`. Core's own: `welcome` (10), `box` (20), `moments` (50), `off` (90). Modules': QoL `casting` (30) and `clothes` (40), Ledger `ledger` (60), Tackle Board `board` (70). A Module registers its steps with `M:RegisterGuideStep(step)` before `ModulesChanged` (as CORE-R42); a later call is reported through `geterrorhandler()` and dropped. With every Module on there are 8 steps; with the Tackle Board off, 7, and the count reads "{n} of 7".
- **ONB-R22** **Opening.** The guide opens at `guideStep` if it is set and still registered, else at the first step. Each step shown sets `guideStep` to its id. Closing (the wax close, Esc, a restriction) keeps `guideStep`, so the guide reopens where it was left.
- **ONB-R23** **Moving.** Each step's right page ends in a foot: a **skip link** on the left and **Next ›** on the right. The last step has **Off to the water** instead (ONB-R36). Each step but the first has **« back** at its left page's foot. Next and back turn the page forward or backward (the Ledger kit's page turn, LED's book motion). The skip link's label is the step's own (`skipLabel`, default "Skip the rest"); it jumps to the last step without visiting the rest.
- **ONB-R24** **Ribbons.** One ribbon per registered step, in order, 98 x 92 units with an 8-unit gap, its top hidden under the book's bottom edge (the ribbon is drawn below the book frame's level). The current step's ribbon hangs 110 units and is brighter; a step already shown has a tick and full colour; a step not yet shown is dimmed (82%). Clicking a ribbon turns to that step (forward or back by order). Labels are each step's `ribbon` text.
- **ONB-R25** **Restriction.** A restriction that starts while the guide is open closes it (keeping `guideStep`) and sets `reopen = true`; when the restriction ends Core reopens it at that step and clears `reopen`. Key-binding calls (`SetBinding`, `SaveBindings`) and equipment-set calls are never made while restricted; their buttons are disabled meanwhile.
- **ONB-R26** **Done.** The guide counts as done (`guideDone = true`) when the last step's **Off to the water** is pressed. The skip link on the Welcome step ("I’ll find my own way") sets `skipped = true` and closes the guide instead of jumping (ONB-R37).
- **ONB-R27** **Fit.** The guide, its ribbons and the wax close fit the screen as the books do (`Fit.lua`, the extent is 950 x 760 units with the ribbons): it shrinks at large UI scales, never grows, and re-fits on `UI_SCALE_CHANGED`.

### The steps

Copy is verbatim from the canvas; the probe has every string. Layout per step is the canvas board named in brackets (renders in `canvas/`).

- **ONB-R30** **Welcome** (Core; board "2 · Welcome: three promises"; ribbon "Welcome"). Left: kicker "A letter, left on the dock", title "Dear Angler,", three paragraphs in the hand, signed "Pagle", foot "Everything here is also in Options › AddOns › Pagle." Right: kicker "Before anything else", title "Three promises", three promises each beside a wax disc with I, II, III: "I never fish for you.", "Nothing expires.", "Every part is optional." with their lines. Foot: skip "I’ll find my own way" (ONB-R26), **Show me around ›**. The third promise's line names the count of parts: "Pagle comes in {n} parts." with n = the roster size (5).
- **ONB-R31** **What's in the box** (Core; board 3; ribbon "What’s in the box"). Left: kicker "The kit", title "What came in the box", a paragraph, and a drawing of the compartment menu built from the real menu's labels at that moment (CORE-R50, CORE-R52: the views, "Input: …", "Curio Shop" with the balance and coin, "Help chart the waters", "Settings"), with a margin note "Click a name to open it. /pagle opens Settings." Right: kicker "Five parts, and a shop", one row per registered Module in `def.order` (icon, `def.title`, the Module's new `def.guideBlurb`, ONB-R91), then the Curio Shop's row (Core's). A Module that is off has no row.
- **ONB-R32** **Casting** (QoL; board 4; ribbon "Casting"). Left: "One key for the whole cast", the next-action sequence Gear › Lure › Cast › Reel drawn with the next-action button (QOL-R70, R71) and its key cap, each with its caption, a paragraph, and a margin note about the double right-click. Right: kicker "Your choice", "How would you like to cast?", three choice cards for Input (*Fishing key*, *Double right-click*, *Both*; the current value chosen, *Both* carries the pencilled tag "the usual"), the **Fishing key** binding field (ONB-R40), and the checkbox **Show the next-action button** (QOL's setting, its tooltip text as the line under it). Choosing a card sets Input as `/pagle qol input` does (QOL-R17) and prints nothing. Under *Double right-click* the binding field is greyed, as on the Fishing page.
- **ONB-R33** **Fishing clothes** (QoL; board 5; ribbon "Fishing clothes"; skip label "I don’t keep fishing clothes", which goes to the next step, not the last). Left: "Your hat, your pole", a paragraph, the two sets *Pagle Previous* ⇄ *Pagle Fishing* drawn as cards of four slots each, and a paragraph. The slots show the player's real items when the sets exist (`C_EquipmentSet.GetItemIDs`), else the drawn placeholders. Right: "Put it on, then save it", **Save what I’m wearing as my fishing set** (QOL-R41, its own messages and disabling, QOL-R42), the Fishing set dropdown (QOL-R40), the **Swap gear** binding field (ONB-R40, for `PAGLE_SWAP_GEAR`), the slot note, and the swap-back Nudge drawn as a sample with the Swap gear key on its key cap (QOL-R77's text).
- **ONB-R34** **Moments** (Core; board 6; ribbon "Moments"). Left: "When something good happens", three samples (a Nod, a toast, a banner) drawn by the real display frames from `/pagle dev preview`'s samples, scaled into the page and standing still (as on the Curio Shop's stage), each with its name and line, and the budget paragraph. Right: three presets (ONB-R35) as choice cards, and the note "Each one only sets the switches in Settings › Announcements, where you can fine-tune them later."
- **ONB-R35** **Presets.** Choosing one writes the existing settings at once:

  | Preset | Cozy mode | Show every catch | Interruption budget | Interruptions | Per |
  |---|---|---|---|---|---|
  | Lively | off | on | on | 4 | 5 min |
  | Quieter | off | off | on | 2 | 5 min |
  | Cozy | on | (unchanged) | (unchanged) | (unchanged) | (unchanged) |

  The card shown chosen is the preset the current settings match exactly (Cozy matches whenever Cozy mode is on); if none matches, none is chosen and a fourth line reads "Your own mix, kept as it is." Toast style, sound set and Animations are never touched.
- **ONB-R36** **Your Ledger** (Ledger; board 7; ribbon "Your Ledger"). Left: "It starts with your next fish", a paragraph, and the bookplate: "EX LIBRIS", the player's portrait in a gilt ring, "The Angler’s Ledger", the character's name, and "kept since … your first Catch" until there is one, then "kept since {firstDate}" (LED-R146). Right: "What Pagle could see", a paragraph, a Write-up-style box headed "{name} · Fishing {skill}" with "read just now", one line per Skill Milestone (LED-R40): credited ones ticked in red with "+1,000 XP"; the next one with "{n} skill to go"; the rest folded into one "for later" line. Then the account paragraph and a margin note "Turn a part on later and it reads back through every Catch since today, then writes up what you’d earned." The Skill Milestone toast itself still shows as the Ledger raises it.
- **ONB-R37** **Tackle Board** (Tackle Board; board 8; ribbon "Tackle Board"; skip label "Not now", which goes to the next step). Left: "Goals that wait for you", a paragraph, a sample strip of two Notices, the Campfire and the Fly Box drawn by the board's own art (standing still) with their lines. Right: "Shall I put up a board?", four facts with coin bullets, **Start my board** (TKB-R5; afterwards the button reads "Your board is up" disabled and Next stays), and "Or leave it for now. The board waits under Tackle Board in the Pagle menu, and in Settings." A board already started shows the started state from the first.
- **ONB-R38** **Off you go** (Core; board 9; ribbon "Off you go"). Left: "The rest you learn by fishing", a paragraph, a sample Nod with margin note 1, and the margin-notes paragraph naming only the registered windows that have first looks. Right: "A short list, if you like", the First evening list as it will look (ONB-R60), **Off to the water** (closes the guide, sets `guideDone`, shows the list), and "/pagle guide opens this guide again."

### Key binding fields

- **ONB-R40** A **binding field** shows, for one binding action (`PAGLE_FISHING_KEY` or `PAGLE_SWAP_GEAR`): its label, a key cap, and a note. **Not bound**: a dashed cap "click to bind", note "default: nothing is bound". **Listening** (after a click): the dashed cap reads "press a key…" with a red outline, note "Esc leaves it as it was"; the field takes keyboard input (`EnableKeyboard`, `SetPropagateKeyboardInput(false)`). **Bound**: a gilt key cap with `GetBindingText(key, true)` and "Bound" in green. With two keys bound, the first shows.
- **ONB-R41** While listening, a key press is taken with its modifiers, as the Key Bindings frame forms it (`CreateKeyChordStringUsingMetaKeyState(key)` or the `ALT-CTRL-SHIFT-` prefix order). A bare modifier (`LSHIFT`, `RSHIFT`, `LCTRL`, `RCTRL`, `LALT`, `RALT`), `UNKNOWN`, and `ESCAPE` aren't bindable: `ESCAPE` cancels and returns to the previous state; the others are ignored. Mouse buttons aren't taken (the field doesn't listen to clicks while listening).
- **ONB-R42** **No conflict:** if `GetBindingAction(key)` is empty or already this action, Core calls `SetBinding(key, action)` then `SaveBindings(GetCurrentBindingSet())`, and the field shows Bound.
- **ONB-R43** **Conflict:** otherwise the field turns into the conflict box: "{key cap} already does {GetBindingName(action) in red}. Use it for fishing instead?" (for Swap gear: "…Use it to swap gear instead?") with **Use {key} for fishing** / **Use {key} to swap gear** and **Pick another key**, and the note "the old use is listed, never silently lost". Use → `SetBinding(key, action)` and `SaveBindings`, which unbinds the old action from that key as the Key Bindings frame does; Core prints "Pagle: {key} now casts. It used to do {old name}; rebind that in Key Bindings if you need it." Pick another key → back to Listening.
- **ONB-R44** A field never binds while restricted, and never touches the other key bound to the same action. Changing the binding elsewhere (Key Bindings) is reflected when the step is next shown (`UPDATE_BINDINGS` redraws an open field).

### Margin notes

- **ONB-R50** A **margin note** is a slip of paper pencilled in blue (Caveat), one key term in red, with a red-pencil number badge, a curved pencil arrow from its nearest edge to a red ring on the thing it explains. Each note has an id and shows **once per account**: `notesSeen[id] = true` as it shows. With **Margin notes** off (ONB-R81), none shows (the guide's own illustrative notes are part of the pages and always show).
- **ONB-R51** A note shows beside its target and leaves when it's clicked, when its target hides, or after 12 s, whichever comes first. It never takes the mouse from the world except over its own paper. It shows only when not restricted; one raised while restricted waits until the restriction ends, and is dropped if its target has hidden by then.
- **ONB-R52** **First moments.** Core shows these notes the first time each happens, beside the frame that shows it:

  | Id | When | Target | Text | Owner |
  |---|---|---|---|---|
  | `core.nod` | the first Nod of any kind shows (ANN-R31, #437) | the Nod | "That’s a *Nod*: when Pagle’s had a lot to say lately, the small news steps down to one quiet line. It’s gone in three seconds, and it’s in your Ledger for good." | Core |
  | `core.toast` | the first toast with Coins shows | the toast's coin | "… The coin is *Pagle Coins*: earned by doing things, never bought, spent on looks in the Curio Shop." prefixed by the moment's `firstNote` if it has one (Ledger's `newSpecies`: "A new Species for your Ledger.") | Core |
  | `core.summary` | the first Session summary card shows | the card | "You stepped away five minutes, so the Session closed. Everything it earned is here, *even what never popped up*." | Core |
  | `core.uncharted` | the first Uncharted Catch's toast or Nod (#437) | the toast or Nod | "Pagle hasn’t charted this one yet. It’s kept, and credited the day it is. *Help chart the waters* in the Pagle menu copies it out, to share if you like." | Core |
  | `qol.lure` | the next-action button first shows "Lure" | the button | "Your pole has no lure on. Your next press puts the best one in your bags on. *Only that*; then you cast." | QoL |
  | `ledger.fresh` | the Fish Journal opens with Fresh Water above 0 for the first time | the ink bar's blue part | "You’ve been away, so your next Catches earn bonus XP. That’s *Fresh Water*, the blue in your bar. A rest is never a penalty." | Ledger |

  A moment held by Cozy mode never shows its note; the note shows at its next first occurrence outside Cozy mode. A Module shows its own with `M:ShowMarginNote(note)` (ONB-R92).
- **ONB-R53** **Moment notes.** A moment may carry `firstNote` (new field on `PagleMoment`, ONB-R93): the first time a moment of that Module and `kind` shows, Core shows a note with that text beside its frame, id `{module}.{kind}`. Used for `core.toast` above; Modules may add more later.

### First looks

- **ONB-R55** A **first look** is a set of 4–5 numbered margin notes on one window, shown together the first time that window opens (and only when Margin notes is on), with a leather **coach bar** under the window: "First look · {window}", "{n} notes, shown once", "Got it, put the notes away". The bar's link hides the set; so do closing the window and Esc (which closes the window as usual). Opening the window again doesn't show the set again (`looksSeen[id] = true` as it first shows).
- **ONB-R56** A Module registers a set with `M:RegisterFirstLook(set)` and shows it with `M:ShowFirstLook(id)` from its window's `OnShow`. Core places each note beside the window at the given offset and draws its arrow to its target region, re-reading the target's position each time the set is shown or the window moves or rescales (`OnSizeChanged` and a scale check on `OnUpdate` while shown). A target that is hidden or not laid out drops that note; the numbers close up.
- **ONB-R57** The sets on the canvas (boards "First look · …"; texts verbatim there):
  - Fish Journal (Ledger, 5): a water's tile and its rank; the Angler Level ink bar and Fresh Water; Notes to self; search and "never named" (LED-R124); the dashed tiles of unfished waters.
  - Hunts (Hunts, 5): Now / Soon / Later; the red now line; *Natural* vs imposed; Pin; the ribbons as Hunt sets.
  - Stats (Stats, 5): the list's odds and "since"; *Your odds*; the Dry spell and "nothing is owed"; Watch (up to three, STA-R60); "Stats never pops up".
  - Tackle Board (Tackle Board, 5): Expeditions; a Notice never expires and its take-down; the Campfire and Kindling; the Fly Box; Coins.
  - Curio Shop (Core, 4): Coins and the source bar; everything is a look; Show on screen; the stock never rotates (SHOP-R24).
- **ONB-R58** Notes sit in the margin beside the window, never over its controls, when there is room; with less than 210 units free on a side, they overlap the window's edge. The probe's `coach` command shows each set over a stand-in of its window.

### The First evening list

- **ONB-R60** After **Off to the water** (and never for a returning or skipped Angler), the **First evening list** docks in the tracker dock as the top tracker (`order = 1`, CORE-R70) on the Stats logbook paper (red double margin rule, blue ruling): header "First evening" with "{done} of {total}" at its right, then one line per registered item.
- **ONB-R61** **Items**, in order, each only while its owner is registered:

  | Id | Text | Hint (shown under the next item) | Done when | Owner |
  |---|---|---|---|---|
  | `cast` | Make a Cast | press your Fishing key, or double right-click (QoL on) / right-click the water with Fishing (QoL off) | `CastStarted` | Core |
  | `catch` | Land a Catch and see its toast | | a catch toast shows (ANN-R13) | Core |
  | `journal` | Open the Fish Journal | Pagle menu by the minimap › Fish Journal | the Journal opens | Ledger |
  | `hunts` | See what’s biting on Hunts | Pagle menu › Hunts | the Hunts board opens | Hunts |
  | `session` | Finish a Session | step away 5 minutes for your summary | a Session summary card shows | Core |
  | `shop` | Peek into the Curio Shop | Pagle menu › Curio Shop | the Curio Shop opens | Core |

  A Module marks its own with `M:CompleteEveningItem(id)`; Core ignores the call when the list is closed or the item done.
- **ONB-R62** A done item is ticked in green and struck through; the first item not done is "next": a green wash behind it and its hint under it. Each tick plays `tick` and the ink motion (MOTION.md). When the last item is ticked, the list waits 2.5 s, then folds away (0.4 s), sets `evening.closed = true`, and never returns.
- **ONB-R63** The list has a small close mark at its header's right; closing it sets `evening.closed = true`. The **First evening list** checkbox on the Settings root shows it again (unclosed) while any item isn't done.
- **ONB-R64** **No Coins.** Finishing the list pays nothing and raises no moment (Coins are for achievements, SHOP-R1).

### The world while learning

- **ONB-R70** While the guide is open, no Announcement shows: they are held exactly like the combat hold (ANN-R36's rules, "While you were fighting" excluded: the held ones show normally when the guide closes).
- **ONB-R71** The guide never pauses or blocks anything else: it's a frame, the game keeps running behind the dim.

### Coming back to it

- **ONB-R80** **`/pagle guide`** opens the guide (ONB-R22). **`/pagle guide notes`** clears `notesSeen` and `looksSeen` and prints "Pagle: margin notes will show again, once each." `guide` becomes a reserved Core subcommand (CORE-R61).
- **ONB-R81** **Settings root.** A new section **Getting started**, after the status list (CORE-R40), with three rows: "Field guide" — "The eight pages you saw on your first day." — button **Show me around again**; checkbox **Margin notes** — "Explain things the first time they happen." — and button **Show them again** (as `/pagle guide notes`); checkbox **First evening list** — "{done} of {total} done" — shown only until the list's last item is done. The compartment menu gets **no** new entry.
- **ONB-R82** **A Module turned on later** gets no guide step shown to the Angler and no letter: its first looks and margin notes apply as usual, and its Write-up shows (CORE-R80). Its step joins the guide for the next `/pagle guide`.

## Data

`PagleDB.global.onboarding` (Core, account-wide):

| Key | Shape | Default |
|---|---|---|
| `letter` | `"waiting"`, `"later"`, `"declined"`, `"opened"`, `"returning"` | set by ONB-R2 |
| `guideStep` | step id last shown | `nil` |
| `guideDone`, `skipped`, `reopen` | boolean | `false` |
| `notesOn` | boolean, the Margin notes setting | `true` |
| `notesSeen` | `{ [noteId] = true }` | `{}` |
| `looksSeen` | `{ [setId] = true }` | `{}` |
| `evening` | `{ shown = bool, closed = bool, done = { [itemId] = true } }` | `{ shown = false, closed = false, done = {} }` |
| `characters` | `{ [GUID] = true }` (ONB-R3) | the first character's |

Schema: one migration step adds the table (catch-log.md `global.schemaVersion`).

## Contracts

New Module handle calls (CORE-R12), and one new `def` field:

```lua
---@class PagleGuideStep
---@field id string             -- unique in the guide; Core's: welcome, box, moments, off
---@field order integer         -- ONB-R21
---@field ribbon string         -- the ribbon's label
---@field skipLabel? string     -- the foot's skip link; default "Skip the rest"
---@field skipTo? "next"|"last" -- default "last"
---@field build fun(left: Frame, right: Frame, nav: PagleGuideNav)  -- draw the two pages once (UI units, 460 x 546 each)
---@field onShow? fun()         -- each time the step shows (re-read live state: bindings, sets, board)
M:RegisterGuideStep(step)       -- ONB-R21; before ModulesChanged

---@class PagleGuideNav
---@field Next fun()  ---@field Back fun()  ---@field Close fun()
---@field BindingField fun(parent: Frame, action: string, label: string): Frame   -- ONB-R40–R44, Core's widget
---@field ChoiceCard fun(parent: Frame, title: string, line: string, tag?: string): Button
---@field Note fun(parent: Frame, text: string, x: number, y: number, w: number, target?: Region)  -- an illustrative note, part of the page

---@class PagleMarginNote
---@field id string             -- "<module>.<name>"
---@field text string           -- |cff9a2a1a…|r marks the red term
---@field target Region         -- what the arrow points at
---@field side? "LEFT"|"RIGHT"|"ABOVE"|"BELOW"  -- where the note sits; default: the side with most room
M:ShowMarginNote(note)          -- ONB-R50–R52; no-op if seen or notes are off

---@class PagleFirstLook
---@field id string             -- "<module>.<window>"
---@field window Frame          -- the window the set belongs to
---@field title string          -- "the Fish Journal" (the bar reads "First look · {title}")
---@field notes { text: string, target: fun(): Region?, x: number, y: number, w: number }[]  -- x, y from the window's top left
M:RegisterFirstLook(set)        -- ONB-R56
M:ShowFirstLook(id)             -- from the window's OnShow; no-op if seen or notes are off

M:CompleteEveningItem(id)       -- ONB-R61 ("journal" for the Ledger, "hunts" for Hunts)
```

- **ONB-R90** Each call raises a Lua error at the caller, adding nothing, for a missing or mistyped field (CORE-R14's sense).
- **ONB-R91** `def.guideBlurb` (string, optional): the Module's one line on the What's in the box step. Ledger: "Your book: every water and every fish, your Angler Level, records and titles." Hunts: "Fish that only bite at night, in winter or at the fair, and which of them bite right now." Stats: "Your own numbers: your odds, from your own Casts, and how long you’ve waited. It never pops up." Tackle Board: "Small goals pinned to a cork board, if you want them. They wait while you’re away." QoL: "The Fishing key, your fishing clothes, lures and clams: one press, one action." A Module without one shows its title alone.
- **ONB-R92** Margin notes and first looks are Core's frames; a Module never draws its own.
- **ONB-R93** `PagleMoment.firstNote?: string` (announcements.md › Contracts), additive (CORE-R15).

Events Core fires (CORE-R20): `GuideOpened`, `GuideClosed(stepId)`. No Module needs them today; they let a Module refresh a sample it drew.

## UI

Every piece is drawn from the guide art kit (this zip): the book shell is the Ledger kit's, the rest is `GuideParts` (ribbons, the letter's seal and slip, note paper and badge, the target ring, key caps, choice cards and radios, checkboxes, the bind field, the coach bar, the next-action bezel and slip, promise discs, the bookplate ring, the tracker paper and its boxes, the lacquer box for Nudge and tooltip samples, the part icons). The probe `PagleArtGuide` draws every board with real textures; its Lua is the reference for sizes and offsets. Where the probe uses stand-ins (screenshots of other kits' windows, the samples on Moments and Tackle Board, the compartment menu), the addon uses the real frames.

- Arrows are `Line` objects (`frame:CreateLine()`, `SetStartPoint`/`SetEndPoint`, thickness 2, `#23407a` at 90%), a quadratic curve cut into 14 segments with a two-stroke head, and a 12-unit red ring at the target.
- Margin notes are straight in game (the canvas tilts them ±1.3°; a frame can't rotate its text).
- Fonts: IM Fell English (print, italic), IM Fell English SC (kickers), Caveat (the hand: notes, letter, signature, tags), Marcellus (ribbons, buttons, the coach bar), all already bundled with the other kits.

### Motion

See `MOTION.md`. In short: the letter slides up 30 units and fades in (0.5 s, ease-out) with its seal dropping from 1.6x (0.15–0.55 s); the guide fades in as the books do; page turns are the books' turn; the current ribbon drops from 92 to 110 units as the old one draws up (0.2 s); a margin note fades in (0.25 s), then its arrow draws from note to target (0.35 s) and the ring pops (0.15 s); a First evening tick inks in (0.3 s) and the list folds away (0.4 s). With Animations off (`Pagle.IsAnimationsOn()`), each appears settled.

### Sounds

See `SOUND.md`. New events: `letter` (the letter arrives), `noteIn` (a margin note or first-look set appears), `tick` (a First evening item is done), `listDone` (the list's last tick). The guide reuses the books' `bookOpen`, `bookClose`, `pageTurn`, `click`, `check`, `uncheck`.

## Settings

| Option | Values | Default | Where |
|---|---|---|---|
| Margin notes | on/off | on | Settings root › Getting started (ONB-R81) |
| First evening list | on/off (shown only while unfinished) | on after the guide | Settings root › Getting started |
| Show me around again | button | | Settings root › Getting started |
| Show them again | button | | Settings root › Getting started |

## Tunables

| Name | Value | Rules |
|---|---|---|
| Letter delay after `PLAYER_ENTERING_WORLD` | 4 s | ONB-R10 |
| Letter showings before it's declined | 2 | ONB-R12 |
| Returning Angler's Nod delay | 20 s or first `SessionStarted` | ONB-R2 |
| Margin note lifetime | 12 s | ONB-R51 |
| First evening fold delay | 2.5 s | ONB-R62 |
| Ribbon size, gap, current length | 98 x 92, 8, 110 | ONB-R24 |
| World dim behind the guide | 0.58 | ONB-R20 |

## Edge cases

- **ONB-R100 Angleur or Fishing Buddy loaded.** QoL's conflict note (QOL-R81) comes first; the letter waits until it's answered or dismissed (ONB-R10 treats an open conflict note like a card). While QoL stands down (QOL-R82), the Casting step reads, under its title, "Pagle’s Fishing key is resting while {other} has it. You can still cast with a double right-click." and its binding field is disabled.
- **ONB-R101 QoL off.** No Casting or Fishing clothes steps, no `qol.lure` note; the `cast` item's hint is the QoL-off one.
- **ONB-R102 Ledger off.** No Your Ledger step, no `journal` item, no Journal first look; Welcome's letter and What's in the box still read correctly (they name only registered parts).
- **ONB-R103 Every Module off.** The guide has Core's four steps; What's in the box shows only the Curio Shop and the line "Turn parts on in the AddOns list.".
- **ONB-R104 Logged out mid-guide.** `guideStep` is saved; the letter isn't shown again (`letter = "opened"`); `/pagle guide` resumes.
- **ONB-R105 Not enough equipment-set slots.** The Fishing clothes step's Save button stays enabled; pressing it runs QOL-R42, which prints its message; the step adds the message under the button in red until the step is left.
- **ONB-R106 UI scale and small screens.** ONB-R27; the letter and notes are unscaled frames in UIParent; first-look notes that don't fit beside a window overlap its edge (ONB-R58).
- **ONB-R107 Another addon moved the tracker dock or Blizzard's objective tracker.** The First evening list follows the dock (CORE-R71).

## Decisions to confirm

These are new or chosen here, not in the spec; the probe implements them as written:

1. The whole feature (letter, guide, notes, list), `/pagle guide` and `/pagle guide notes`, the Getting started section, and no compartment entry.
2. Presets map onto existing settings exactly as ONB-R35; "Quieter" is 2 per 5 min with Show every catch off.
3. The guide's binding flow rebinds a key the player already uses, with consent (ONB-R43). QOL-R10's "never borrows another binding" still holds: nothing is overridden, the player chose.
4. No Coins for the list (ONB-R64).
5. The letter never shows inside an instance (ONB-R10), beyond the restriction rule.
6. Margin notes and first looks are once per account, not per character.
7. Announcements are held while the guide is open (ONB-R70).
8. A second "Later" declines the letter for good (ONB-R12).

## In-game exit check

1. Fresh SavedVariables, every Module on: the letter appears 4 s after the world, above the action bar; Later; `/reload`; it appears once more; Later; `/reload`; it doesn't.
2. `/pagle guide`: eight steps, ribbons tick as visited, back and next turn pages, Esc closes and `/pagle guide` resumes at the same step.
3. Casting step: bind F where F is Assist Target → conflict box; Use F → Key Bindings shows F on "Pagle: Fishing key" and Assist Target unbound; Esc while listening leaves it as it was.
4. Fishing clothes: save a set; *Pagle Fishing* and *Pagle Previous* appear in the equipment manager.
5. Moments: each preset writes the switches in ONB-R35 (check the Announcements page).
6. Tackle Board: Start my board starts it (TKB-R5); the step then reads "Your board is up".
7. Off to the water: the First evening list docks; cast, catch, open the Journal, Hunts, wait out a Session, open the shop: each ticks; it folds away.
8. First Nod, first toast with Coins, first Session summary: one note each, never again (`/reload` and check); `/pagle guide notes` brings them back.
9. Open the Journal, Hunts, Stats, the board and the shop: each shows its first look once.
10. Disable Pagle_TackleBoard: the guide has 7 steps, "of 7".
11. Enter combat with the guide open: it closes; leave combat: it reopens at the same step.
12. UI scale 1.15 on 1366 x 768: guide and ribbons fit.
