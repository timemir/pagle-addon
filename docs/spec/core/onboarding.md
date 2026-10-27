# Core: Onboarding (the Letter, the Field guide, Margin notes, First looks, the First evening list)

> Status: Ready to build · Prefix `ONB` · Milestone: M8.5 Onboarding · Sources: [Backlog: an onboarding experience on first open](https://github.com/timemir/pagle-addon/issues/260), [the onboarding kit, grilled with the dev](https://github.com/timemir/pagle-addon/issues/260#issuecomment-6335904394) (the kit is in [`prototypes/onboarding-kit/`](../../../prototypes/onboarding-kit/README.md): 18 canvas boards and the `PagleArtGuide` probe); ADR 0001, 0007

Part of [Core](README.md). Every capitalised term means what `CONTEXT.md` says. A number in brackets that isn't `ONB-` points at the rest of the spec. The rules this feature changes elsewhere are amended in their own files: CORE-R40, CORE-R53–R56 (the minimap icon) and CORE-R61 in [README.md](README.md); ANN-R31, ANN-R38, ANN-R64 and `PagleMoment.firstNote` in [announcements.md](announcements.md); SET-R10 and SET-R30 in [settings.md](../settings.md).

## Purpose and boundary

A new Angler gets a **Letter**, which opens an eight-page **Field guide** in a book like the Fish Journal's. After it, they learn by fishing: a **First evening list** in the tracker dock, a **Margin note** beside each first moment, and a **First look** (a set of notes) the first time each window opens, which the window's **"?"** shows again on request.

**Core owns:** the Letter, the guide's book, its ribbons and navigation, the step registry, Core's own steps (Welcome, What's in the box, Moments, Off you go), the Margin note widget and its once-only bookkeeping, the First looks' display and coach bar, the First evening list, `/pagle guide`, the Getting started rows on the Settings root, the Write-up's "Show me around" link, and the onboarding state in `PagleDB.global.onboarding`.

**Modules own:** their own guide steps (QoL: Casting and Fishing clothes; Ledger: Your Ledger; Tackle Board: the Tackle Board), the text of their Margin notes and First-look notes, which of their regions each note points at, their window's "?" button, and telling Core when one of their First evening items is done. A Module that is off registers nothing, so its steps, notes and items don't exist (CORE-R17). Hunts and Stats have no guide step: a row on What's in the box and their First look introduce them.

**Doesn't own:** what any control on a step does. Every control calls the owner's existing action: `Input` and the next-action button (QOL-R12, QOL-R70), the fishing set and Swap gear (QOL-R40–R46), the Announcement settings (announcements.md › Settings), Start my board (TKB-R5). The guide is a second door to settings that already exist, plus one new key-binding flow (ONB-R40–R44).

**Uses from Core:** CORE-R12 (Module handle), CORE-R17, CORE-R19 (`ModulesChanged`), CORE-R30 (restriction), CORE-R40–R44 (Settings root), CORE-R50–R56 (the Pagle menu, its compartment entry and minimap icon), CORE-R60–R62 (`/pagle`), CORE-R65 (tour stops), CORE-R70–R73 (tracker dock), ANN-R4/R13/R20/R21/R35–R38/R40/R53/R60–R64 (moments, the catch Nod, lanes, cards, holds, Cozy mode, the Session summary, the Write-up), LOG-R2, LOG-R9, LOG-R60–R63 (`CastStarted`, `Catch`, Sessions), `Pagle.IsAnimationsOn()`, `Pagle.FitToScreen`, `Pagle.Animate`.

Modules still see only Core (ADR 0001): a Module's step never reads another Module, and Core's What's in the box step reads only the registered Modules' `def` fields.

## Rules

### State and who sees what

- **ONB-R1** Onboarding state is account-wide, in `PagleDB.global.onboarding` (see [Data](#data)). It is created at the first `PLAYER_LOGIN` that finds it missing, with `letter` set by ONB-R2.
- **ONB-R2** **New or returning.** When the state is created: if the Catch log already holds at least one Cast entry (a reinstall, a new computer with old SavedVariables, a Pagle from before this feature), `letter = "returning"`; otherwise `letter = "waiting"`. A returning Angler gets no Letter and no First evening list. At the first `SessionStarted` or 20 s after login, whichever comes first, Core shows the Margin note `core.welcome` on Pagle's menu button (ONB-R52): "Welcome back. */pagle guide* shows you around, if you want the tour." Margin notes and First looks still apply to them, each once (ONB-R50).
- **ONB-R3** **Another character.** The state is account-wide, so a second character sees no Letter. The first time a character other than the ones in `characters` logs in, and only while QoL is registered, Core shows the Margin note `core.character` on Pagle's menu button: "Same Ledger on every character. Only your *fishing clothes* are per character." The character's GUID is then added, whether or not the note showed.

### The Letter

- **ONB-R10** While `letter` is `"waiting"` or `"later"`, Core shows the **Letter** once per login, when all of these hold: the login's held Announcements, Write-up and "Your last session" card have shown and closed (ANN-R21), QoL's conflict note isn't open (ONB-R100), `Pagle.IsRestricted()` is false, `IsInInstance()` is false, and 4 s have passed since `PLAYER_ENTERING_WORLD`. If a condition fails it waits and checks again on `RestrictionChanged`, `ZONE_CHANGED_NEW_AREA` and when a card or the conflict note closes.
- **ONB-R11** The Letter is a frame of Core's own at the Toast column's foot (above the action bar, centred, unless the Angler moved the column: it sits wherever the foot is, clamped to the screen as the column is, ANN-R98), not an Announcement: it never counts as an interruption (ANN-R30), plays the `letter` sound, is never held by Cozy mode and has no expiry. It reads, kicker "A letter, left on the dock", hand "Pagle has arrived. Open it whenever you’re ready; it’ll keep.", with **Open the letter** and **Later** (board "1 · The letter arrives").
- **ONB-R12** **Open the letter** sets `letter = "opened"`, hides the Letter and opens the guide at its first step (ONB-R20). **Later** hides it: from `"waiting"` it sets `letter = "later"`, and the next login shows it once more (ONB-R10); from `"later"` it sets `letter = "declined"`. A declined or opened Letter never shows again; the guide is then reached only from `/pagle guide` and the Settings root (ONB-R80, ONB-R81).
- **ONB-R13** While the Letter shows, the tooltip of Pagle's menu (CORE-R55) adds the line "A letter for you".
- **ONB-R14** A restriction that starts while the Letter shows hides it; it shows again when the restriction ends (ONB-R10's checks).

### The Field guide

- **ONB-R20** The **guide** is a two-page book at 920 x 600 on Core's book shell (`Pagle.NewBook`, [book.md](book.md), ADR 0016): the shell draws its window, parchment pages, strip, wax close, ribbons, fades, sounds and page turn, and the guide draws only its steps' pages (no nameplate, as the canvas has none) and adds no book art. It is `fixed` (BOOK-R6): it opens at the screen's centre, lifted 40 units, takes no drag and saves no position. Each registered step is a page of the book, in the steps' order (ONB-R21), its body the whole page, so a step lays its 442 x 546 pages from their top left. Its leather is Field Leather (`core.binding.field`), the shell's binding `pinned` there: it never follows the equipped binding, since the guide is read before the Angler owns anything (ADR 0015). Its strip's crumbs read "Pagle ❧ A field guide" (the shell's `trail`, neither a link) with "{n} of {m}" at the strip's right (`SetStripText`), and a row of **step ribbons** hangs under its bottom edge (ONB-R24). It opens from the Letter, `/pagle guide`, the Settings root's **Show me around again** and a Write-up's link (ONB-R82), in `DIALOG` strata over the shell's dim of the world (alpha 0.58), which fades with the book, and is `PagleGuide` in `UISpecialFrames` (Esc closes it). However the book closes (Esc, the wax close), the guide closes with it.
- **ONB-R21** **Steps.** The guide is the registered steps in `order`. Core's own: `welcome` (10), `box` (20), `moments` (50), `off` (90). Modules': QoL `casting` (30) and `clothes` (40), Ledger `ledger` (60), Tackle Board `board` (70). A Module registers its steps with `M:RegisterGuideStep(step)` before `ModulesChanged` (as CORE-R42); a later call is reported through `geterrorhandler()` and dropped. With every Module on there are 8 steps; with the Tackle Board off, 7, and the count reads "{n} of 7".
- **ONB-R22** **Opening.** The guide opens at `guideStep` if it is set and still registered, else at the first step; a Write-up's link opens it at that Module's first step. Each step shown sets `guideStep` to its id and adds it to `stepsSeen`. Closing (the wax close, Esc, a restriction) keeps `guideStep`, so the guide reopens where it was left.
- **ONB-R23** **Moving.** Each step's right page ends in a foot: a **skip link** on the left and **Next »** on the right. The last step has **Off to the water** instead (ONB-R38). Each step but the first has **« back** at its left page's foot. Next and back turn the page forward or backward (the shell's page turn, BOOK-R31), and "{n} of {m}" changes as the page passes the spine. The skip link's label is the step's own (`skipLabel`, default "Skip the rest"); it jumps to the last step without visiting the rest, or to the next step where the step says so (`skipTo = "next"`).
- **ONB-R24** **Ribbons.** One ribbon per registered step, in order: the shell's ribbons (BOOK-R17, one geometry for every book), each in the guide's red (`#a23a28`) with its step's `ribbon` text. The current step's ribbon is the shell's chosen one, hanging longer and brighter; a step in `stepsSeen` has full colour and a tick (GuideParts' `tick-red`, desaturated and lit in gilt, centred across the ribbon just under the book's edge, on a layer a level over the ribbons); a step not yet seen is dimmed (82%). Clicking a ribbon turns to that step (forward or back by order), and the guide follows it (ONB-R22's marks).
- **ONB-R25** **Restriction.** A restriction that starts while the guide is open closes it (keeping `guideStep`) and sets `reopen = true`; when the restriction ends Core reopens it at that step and clears `reopen`. Key-binding calls (`SetBinding`, `SaveBindings`) and equipment-set calls are never made while restricted; their buttons are disabled meanwhile.
- **ONB-R26** **Done.** The guide counts as done (`guideDone = true`) when the last step's **Off to the water** is pressed. The skip link on the Welcome step ("I’ll find my own way") sets `skipped = true` and closes the guide instead of jumping.
- **ONB-R27** **Fit.** The guide, its ribbons and the wax close fit the screen as every book does (BOOK-R3: `Pagle.FitToScreen`, the extent the frame plus 30 units across and 100 down, 950 x 700): it shrinks at large UI scales, never grows, and re-fits on `UI_SCALE_CHANGED`.

### The steps

Copy is the probe's, verbatim (`prototypes/onboarding-kit/PagleArtGuide/Guide.lua` and `World.lua`), with `›` written `»` (CORE-R9) and each string in `ns.L` (CORE-R8). Layout per step is the canvas board named in brackets (renders in `prototypes/onboarding-kit/canvas/`); the probe's Lua gives its sizes and offsets in UI units. On Core's pages, what follows a text that wraps (the Letter's paragraphs and its signature, each promise after the line above it, What's in the box's rows and their rules after the blurb above, a preset card's pencilled line and the cards and note under it) is laid from that text's measured height with the board's spacing: wrapped as on the board it sits where the board has it, and a text that wraps to more lines in the client's font pushes the rest down, a card growing to fit, instead of running into it. What's in the box's rows fill their page to its foot, so when they would pass it the gaps between them tighten evenly, to no less than 8 UI units (about half the board's 16), before anything overlaps.

- **ONB-R30** **Welcome** (Core; board "2 · Welcome: three promises"; ribbon "Welcome"). Left: kicker "A letter, left on the dock", title "Dear Angler,", three paragraphs in the hand, signed "Pagle", foot "Everything here is also in Options » AddOns » Pagle." Right: kicker "Before anything else", title "Three promises", three promises each beside a wax disc with I, II, III: "I never fish for you.", "Nothing expires.", "Every part is optional." with their lines. Foot: skip "I’ll find my own way" (ONB-R26), **Show me around »**. The third promise's line names the count of parts: "Pagle comes in {n} parts." with n the roster size (5).
- **ONB-R31** **What's in the box** (Core; board 3; ribbon "What’s in the box"). Left: kicker "The kit", title "What came in the box", a paragraph, and a drawing of the Pagle menu built from the real menu's labels at that moment (CORE-R50, CORE-R52: the views, "Input: …", "Curio Shop" with the balance and coin, "Help chart the waters", "Settings"), with a margin note "Click a name to open it. /pagle opens Settings." Right: kicker "{n} parts, and a shop" (the count in words), one row per registered Module in `def.order` (icon from the kit's `ic-*` sprites, `def.title`, the Module's `def.guideBlurb`, ONB-R91), then the Curio Shop's row (Core's). A Module that is off has no row.
- **ONB-R32** **Casting** (QoL; board 4; ribbon "Casting"). Left: "One key for the whole cast", the next-action sequence Gear » Lure » Cast » Reel drawn with the next-action button (QOL-R70, R71) and its key cap, each with its caption, a paragraph, and a margin note about the double right-click. Right: kicker "Your choice", "How would you like to cast?", three choice cards for Input (*Fishing key*, *Double right-click*, *Both*; the current value chosen, *Both* carries the pencilled tag "the usual"), the **Fishing key** binding field (ONB-R40), and the checkbox **Show the next-action button** (QoL's setting, its tooltip text as the line under it). Choosing a card sets Input as `/pagle qol input` does (QOL-R17) and prints nothing. Under *Double right-click* the binding field is greyed, as on the Fishing page.
- **ONB-R33** **Fishing clothes** (QoL; board 5; ribbon "Fishing clothes"; skip label "I don’t keep fishing clothes", `skipTo = "next"`). Left: "Your hat, your pole", a paragraph, the two sets *Pagle Previous* and *Pagle Fishing* drawn as cards of four slots each with the kit's `arrows` sprite between them (the canvas's ⇄, outside CORE-R9), and a paragraph. The slots show the player's real items when the sets exist (`C_EquipmentSet.GetItemIDs`), else the drawn placeholders. Right: "Put it on, then save it", **Save what I’m wearing as my fishing set** (QOL-R41, its own messages and disabling, QOL-R42), the Fishing set dropdown (QOL-R40), the **Swap gear** binding field (ONB-R40, for `PAGLE_SWAP_GEAR`), the slot note, and the swap-back Nudge drawn as a sample with the Swap gear key on its key cap (QOL-R77's text), drawn smaller when its line is too long for the column. The dropdown is the page's own, not the game's context menu: the kit's `field` panel with the chosen set's name and a `caret`, whose click opens its list directly under it, left-aligned and as wide (wider only to the left for a long name, at most the column, so never off the page), on the same paper in the same type (IM Fell English at 14.5), above the page's other controls. A row per choice carries the choice cards' `radio`, the chosen one's `radio-on`; under the mouse a row is washed warm brown and its words go red, as the guide's links. A pick chooses the set as the Fishing page's dropdown does (QOL-R40, QOL-R42) and closes the list; so do Esc (which goes no further) and a click anywhere but on the list or its field. The list closes while the field is greyed and when the step is left, and is shut each time the step shows.
- **ONB-R34** **Moments** (Core; board 6; ribbon "Moments"). Left: "When something good happens", three samples (a Nod, a toast, a banner) drawn by the real display frames from `/pagle dev preview`'s samples, scaled into the page and standing still (as the Curio Shop's stage draws a toast), each with its name and line, and the budget paragraph. Right: three presets (ONB-R35) as choice cards, and the note "Each one only sets the switches in Settings » Announcements, where you can fine-tune them later."
- **ONB-R35** **Presets.** Choosing one writes the existing settings at once:

  | Preset | Cozy mode | Show every catch | Interruption budget | Interruptions | Per |
  |---|---|---|---|---|---|
  | Lively | off | on | on | 40 | 5 min |
  | Quieter | off | off | on | 10 | 5 min |
  | Cozy | on | (unchanged) | (unchanged) | (unchanged) | (unchanged) |

  The card shown chosen is the preset the current settings match exactly (Cozy matches whenever Cozy mode is on); if none matches, none is chosen and a fourth line reads "Your own mix, kept as it is." Lively is the default settings (ANN-R31), so a new Angler sees it chosen. The cards read, Lively "A toast for every Catch; banners too, with sound." and Quieter "No toast for ordinary Catches, and fewer pop-ups. The big moments still show." (Lively's count was 20 before [#437](https://github.com/timemir/pagle-addon/issues/437), when its line read "Every Catch gets its Nod; toasts and banners with sound."), and the samples read, a Nod "When Pagle's said a lot lately. One line, gone in 3 seconds." and a toast "Every Catch, a new fish, a record, Coins earned." Toast style, sound set and Animations are never touched.
- **ONB-R36** **Your Ledger** (Ledger; board 7; ribbon "Your Ledger"). Left: "It starts with your next fish", a paragraph, and the bookplate: "EX LIBRIS", the player's portrait in a gilt ring, "The Angler’s Ledger", the character's name, and "kept since … your first Catch" until there is one, then "kept since {firstDate}" (LED-R146). Right: "What Pagle could see", a paragraph, a Write-up-style box headed "{name} · Fishing {skill}" with "read just now", one line per Skill Milestone (LED-R40): credited ones ticked in red with their XP; the next one with "{n} skill to go"; the rest folded into one "for later" line. Then the account paragraph and a margin note "Turn a part on later and it reads back through every Catch since today, then writes up what you’d earned." The Skill Milestone toast itself still shows as the Ledger raises it.
- **ONB-R37** **Tackle Board** (Tackle Board; board 8; ribbon "Tackle Board"; skip label "Not now", `skipTo = "next"`). Left: "Goals that wait for you", a paragraph, a sample strip of two Notices, the Campfire and the Fly Box drawn by the board's own art (standing still) with their lines. Right: "Shall I put up a board?", four facts with coin bullets, **Start my board** (TKB-R5; afterwards the button reads "Your board is up", disabled, and Next stays), and "Or leave it for now. The board waits under Tackle Board in the Pagle menu, and in Settings." A board already started shows the started state from the first.
- **ONB-R38** **Off you go** (Core; board 9; ribbon "Off you go"). Left: "The rest you learn by fishing", a paragraph, a sample Nod with margin note 1, and the margin-notes paragraph naming only the registered windows that have First looks. Right: "A short list, if you like", the First evening list as it will look (ONB-R60), **Off to the water** (closes the guide, sets `guideDone`, shows the list), and "/pagle guide opens this guide again."

### Key binding fields

- **ONB-R40** A **binding field** shows, for one binding action (`PAGLE_FISHING_KEY` or `PAGLE_SWAP_GEAR`): its label, a key cap, and a note. **Not bound**: a dashed cap "click to bind", note "default: nothing is bound". **Listening** (after a click): the dashed cap reads "press a key…" with a red outline, note "Esc leaves it as it was"; the field takes keyboard input (`EnableKeyboard`, `SetPropagateKeyboardInput(false)`). **Bound**: a gilt key cap with `GetBindingText(key, true)` and "Bound" in green. With two keys bound, the first shows.
- **ONB-R41** While listening, a key press is taken with its modifiers by the same key-capture helper as the Settings key rows (SET-R20: `adapter/KeyBindingRow.lua`'s capture, moved into one Core helper both use, `adapter/KeyCapture.lua`, with the client calls it already makes). A bare modifier, `UNKNOWN` and `ESCAPE` aren't bindable: `ESCAPE` cancels and returns to the previous state; the others are ignored. Mouse buttons aren't taken.
- **ONB-R42** **No conflict:** if `GetBindingAction(key)` is empty or already this action, Core calls `SetBinding(key, action)` then `SaveBindings(GetCurrentBindingSet())`, and the field shows Bound.
- **ONB-R43** **Conflict:** otherwise the field turns into the conflict box: "{key cap} already does {GetBindingName(action) in red}. Use it for fishing instead?" (for Swap gear: "…Use it to swap gear instead?") with **Use {key} for fishing** / **Use {key} to swap gear** and **Pick another key**, and the note "the old use is listed, never silently lost" under the buttons (so the box is 92 units tall, not the kit's 76). Use → `SetBinding(key, action)` and `SaveBindings`, which unbinds the old action from that key as the Key Bindings frame does; Core prints "Pagle: {key} now casts. It used to do {old name}; rebind that in Key Bindings if you need it." (for Swap gear, "now swaps your gear"). Pick another key → back to Listening. The Settings key rows keep taking a used key without asking, as Blizzard's do (SET-R20); the guide asks because a first-day player may not know what the key did. QOL-R10 still holds: the player chose the key.
- **ONB-R44** A field never binds while restricted, and never touches the other key bound to the same action. Changing the binding elsewhere (Key Bindings, the Fishing page) is reflected when the step is next shown, and `UPDATE_BINDINGS` redraws an open field.

### Margin notes

- **ONB-R50** A **Margin note** is a slip of paper pencilled in blue (Caveat), one key term in red, with a red-pencil number badge, a curved pencil arrow from its nearest edge to a red ring on the thing it explains. Each note has an id and shows **once per account**: `notesSeen[id] = true` as it shows. With **Margin notes** off (ONB-R81), none shows (the guide's own illustrative notes are part of its pages and always show).
- **ONB-R51** A note shows beside its target and leaves when it's clicked, when its target hides, or after 12 s, whichever comes first. It never takes the mouse from the world except over its own paper. It shows only when not restricted; one raised while restricted waits until the restriction ends, and is dropped if its target has hidden by then (unseen, so its next first occurrence shows it). A note on screen when a restriction starts hides at once and waits with the rest; when the restriction ends it comes back beside its target, if that still shows, with a fresh 12 s.
- **ONB-R52** **First moments.** Core shows these notes the first time each happens, beside the frame that shows it:

  | Id | When | Target | Text | Owner |
  |---|---|---|---|---|
  | `core.nod` | the first Nod of any kind shows: a toast stepped down by the budget (ANN-R31, the catch toast's too), a Module's Nod, a login Nod ([#437](https://github.com/timemir/pagle-addon/issues/437); the catch Nod's before) | the Nod | "That’s a *Nod*: when Pagle’s had a lot to say lately, the small news steps down to one quiet line. It’s gone in three seconds, and it’s in your Ledger for good." | Core |
  | `core.toast` | the first toast with Coins shows | the toast's coin | "… The coin is *Pagle Coins*: earned by doing things, never bought, spent on looks in the Curio Shop." prefixed by the moment's `firstNote` if it has one (the Ledger's `newSpecies`: "A new Species for your Ledger.") | Core |
  | `core.summary` | the first Session summary card shows | the card | "You stepped away five minutes, so the Session closed. Everything it earned is here, *even what never popped up*." | Core |
  | `core.uncharted` | the first Uncharted Catch's announcement, whether it shows as a toast (the Ledger's `toast.low`, or Core's catch toast) or as a Nod | the toast or Nod | "Pagle hasn’t charted this one yet. It’s kept, and credited the day it is. *Help chart the waters* in the Pagle menu copies it out, to share if you like." | Core |
  | `core.welcome` | a returning Angler (ONB-R2) | Pagle's menu button | ONB-R2's text | Core |
  | `core.character` | another character (ONB-R3) | Pagle's menu button | ONB-R3's text | Core |
  | `qol.lure` | the next-action button first shows "Lure" | the button | "Your pole has no lure on. Your next press puts the best one in your bags on. *Only that*; then you cast." | QoL |
  | `ledger.fresh` | the Fish Journal opens with Fresh Water above 0 for the first time once the Angler has had a real break (LED-R22's minimum break, 1 hour): the Catch log holds a gap of at least that between two consecutive Catches, any character, or at least that has passed since the last Catch; a Session end alone isn't one. Until then it isn't shown and isn't marked seen, so a new Angler, whose Fresh Water starts at its cap, doesn't read it before ever being away | the ink bar's blue part | "You’ve been away, so your next Catches earn bonus XP. That’s *Fresh Water*, the blue in your bar. A rest is never a penalty." | Ledger |

  **Pagle's menu button** is the minimap icon while it shows (CORE-R53), else the Addon Compartment's button. A moment held by Cozy mode never shows its note; the note shows at its next first occurrence outside Cozy mode. Core tells an Uncharted Catch itself, from the catalogue (LOG-R55), as the Cast ends, whichever Module's toast or Nod shows it; that frame gets `core.uncharted`, not `core.nod`. One frame never carries two Core notes: `core.nod`, `core.uncharted` and `core.toast` are each prefixed by the `firstNote` of the Announcement's first moment that has one unseen, as `core.toast` is, and a toast with Coins that shows `core.uncharted` leaves `core.toast` for the next one. Samples (`/pagle dev preview`'s, the Curio Shop's toasts in their own style, a preview card) and the "While you were fighting" digest get no note. A Module shows its own with `M:ShowMarginNote(note)` (ONB-R92).
- **ONB-R53** **Moment notes.** A moment may carry `firstNote` (`PagleMoment.firstNote`, ONB-R93): the first time a moment of that Module and `kind` shows, Core shows a note with that text beside its frame, id `{module}.{kind}`. Used for `core.toast` above; Modules may add more later.

### First looks

- **ONB-R55** A **First look** is a set of 4–5 numbered Margin notes on one window, shown together the first time that window opens (and only when Margin notes is on), with a leather **coach bar** under the window: "First look · {window}", "{n} notes, shown once", "Got it, put the notes away". The bar's link hides the set; so do closing the window and Esc (which closes the window as usual). Opening the window again doesn't show the set again (`looksSeen[id] = true` as it first shows). The set plays `noteIn` once, not once per note.
- **ONB-R56** A Module registers a set with `M:RegisterFirstLook(set)` and shows it with `M:ShowFirstLook(id)` from its window's `OnShow`. Core places each note beside the window at the given offset and draws its arrow to its target region, re-reading the target's position each time the set is shown or the window moves or rescales (`OnSizeChanged` and a scale check on `OnUpdate` while shown); a moved target's arrow is redrawn at once, without motion. A target that is hidden or not laid out drops that note; the numbers close up.
- **ONB-R57** The sets on the canvas (boards "First look · …"; texts verbatim there and in the probe):
  - Fish Journal (Ledger, 5): a water's tile and its rank; the Angler Level ink bar and Fresh Water; Notes to self; search and "never named" (LED-R124); the dashed tiles of unfished waters.
  - Hunts (Hunts, 5): Now / Soon / Later; the red now line; *Natural* vs imposed; Pin; the ribbons: "Each ribbon is a *Hunt set*. Finish every Hunt in one and its title is yours. *Pagle Wagers* holds the wagers on the table now." (its target is the Pagle Wagers ribbon, HNT-R61, so the note waits for M8's board; until then it drops, ONB-R56).
  - Stats (Stats, 5): the list's odds and "since"; *Your odds*; the Dry spell and "nothing is owed"; Watch (up to three, STA-R60); "Stats never pops up".
  - Tackle Board (Tackle Board, 5): Expeditions; a Notice never expires and its take-down; the Campfire and Kindling; the Fly Box; Coins.
  - Curio Shop (Core, 4): Coins and the source bar; everything is a look; Show on screen; the stock never rotates (SHOP-R24).
- **ONB-R58** Notes sit in the margin beside the window, never over its controls, when there is room; with less than 210 units free on a side, they overlap the window's edge.
- **ONB-R59** **The "?".** Each window with a First look has a small **"?"** button beside its close button, drawn by the window's owner from that window's own art (the books' wax, the board's pin, the shop's brass), with the tooltip "Show the notes for this page again". Pressing it shows the set with `M:ShowFirstLook(id, true)`: it shows whether or not the set was seen and whether or not Margin notes is on, and marks it seen. While the set shows, pressing it again hides the set.

### The First evening list

- **ONB-R60** After **Off to the water** (and never for a returning or skipped Angler), the **First evening list** docks in the tracker dock as the top tracker (`order = 1`, CORE-R70), on the kit's tracker paper (red double margin rule, blue ruling): header "First evening" with "{done} of {total}" at its right, then one line per registered item. `evening.shown` is set as it first docks.
- **ONB-R61** **Items**, in order, each only while its owner is registered:

  | Id | Text | Hint (shown under the next item) | Done when | Owner |
  |---|---|---|---|---|
  | `cast` | Make a Cast | press your Fishing key, or double right-click (QoL on) / right-click the water with Fishing (QoL off) | `CastStarted` | Core |
  | `catch` | Land a Catch | | the first `Catch` | Core |
  | `journal` | Open the Fish Journal | Pagle menu by the minimap » Fish Journal | the Journal opens | Ledger |
  | `hunts` | See what’s biting on Hunts | Pagle menu » Hunts | the Hunts board opens | Hunts |
  | `session` | Finish a Session | step away 5 minutes for your summary | `SessionEnded`, whether or not a card shows (ANN-R53) | Core |
  | `shop` | Peek into the Curio Shop | Pagle menu » Curio Shop | the Curio Shop opens | Core |

  So no item waits on Show every catch, Cozy mode or a card. A Module marks its own with `M:CompleteEveningItem(id)`; Core ignores the call when the list is closed or the item done. Items done before the list docks (an Angler who fished with the Letter unopened) are kept in `evening.done` and show ticked.
- **ONB-R62** A done item is ticked in green and struck through; the first item not done is "next": a green wash behind it and its hint under it. Each tick plays `tick` and the ink motion (MOTION.md). When the last item is ticked, the list plays `listDone`, waits 2.5 s, then folds away (0.4 s), sets `evening.closed = true`, and never returns.
- **ONB-R63** The list has a small close mark at its header's right; closing it sets `evening.closed = true`. The **First evening list** checkbox on the Settings root shows it again (unclosed) while any item isn't done.
- **ONB-R64** **No Coins.** Finishing the list pays nothing and raises no moment (Coins are for achievements, SHOP-R1).

### The world while learning

- **ONB-R70** While the guide is open, Core holds Announcements for the reason `guide` (ANN-R38): what's raised is held as in combat (ANN-R35, Nods dropped), and when the guide closes it shows at once, held toasts as themselves without the "While you were fighting" fold.
- **ONB-R71** The guide never pauses or blocks anything else: it's a frame, and the game keeps running behind the dim.

### Coming back to it

- **ONB-R80** **`/pagle guide`** opens the guide (ONB-R22). **`/pagle guide notes`** clears `notesSeen` and `looksSeen` and prints "Pagle: margin notes will show again, once each." `guide` is a reserved Core subcommand (CORE-R61).
- **ONB-R81** **Settings root.** A section **Getting started**, after the status list (SET-R10), with three rows: "Field guide", the line "The eight pages you saw on your first day." and the button **Show me around again**; the checkbox **Margin notes** ("Explain things the first time they happen.", `notesOn`) with the button **Show them again** (as `/pagle guide notes`); the checkbox **First evening list** ("{done} of {total} done"), shown only until the list's last item is done. The Pagle menu gets **no** new entry.
- **ONB-R82** **A Module turned on later** gets no Letter and no guide shown on its own. Its First looks and Margin notes apply as usual, its step joins the guide, and its Write-up section (ANN-R60) carries the link **Show me around »** when the Module has a guide step: the link closes the card and opens the guide at that Module's first step (ANN-R64). A Module without a step (Hunts, Stats) gets no link; its First look introduces it.
- **ONB-R83** **Dev commands** (dev mode only, [in-game-verification.md](../../agents/in-game-verification.md#dev-commands)): `/pagle dev onboarding reset` puts the state back as created for a new Angler (`letter = "waiting"`, everything else default, the current character in `characters`), whatever the Catch log holds; `letter` shows the Letter now; `step <id>` opens the guide at a step; `note <id>` shows one Margin note on its target (if shown); `look <id>` shows a First look (its window must be open); `evening` docks the list. None of them is reserved outside `/pagle dev`.
- **ONB-R84** **Tour stops** (CORE-R65): Core adds `core.onboarding.letter`, one `core.onboarding.step.<id>` per registered step (Modules' included, since the step registry is Core's), `core.onboarding.evening`, and one `core.onboarding.look.<id>` per registered First look (opening its window through the Module's view, then showing the set). Each `hide` puts back the state its `show` changed (CORE-R68): it never marks a note or set seen and never writes `guideStep`.

## Data

`PagleDB.global.onboarding` (Core, account-wide):

| Key | Shape | Default |
|---|---|---|
| `letter` | `"waiting"`, `"later"`, `"declined"`, `"opened"`, `"returning"` | set by ONB-R2 |
| `guideStep` | step id last shown | `nil` |
| `stepsSeen` | `{ [stepId] = true }` (ONB-R24) | `{}` |
| `guideDone`, `skipped`, `reopen` | boolean | `false` |
| `notesOn` | boolean, the Margin notes setting | `true` |
| `notesSeen` | `{ [noteId] = true }` | `{}` |
| `looksSeen` | `{ [setId] = true }` | `{}` |
| `evening` | `{ shown = bool, closed = bool, done = { [itemId] = true } }` | `{ shown = false, closed = false, done = {} }` |
| `characters` | `{ [GUID] = true }` (ONB-R3) | the first character's |

Schema: one migration step adds the table (catch-log.md `global.schemaVersion`). The read-wtf script prints it in an Onboarding section (in-game-verification.md).

## Contracts

New Module handle calls (CORE-R12), and one new `def` field:

```lua
---@class PagleGuideStep
---@field id string             -- unique in the guide; Core's: welcome, box, moments, off
---@field order integer         -- ONB-R21
---@field ribbon string         -- the ribbon's label
---@field skipLabel? string     -- the foot's skip link; default "Skip the rest"
---@field skipTo? "next"|"last" -- default "last"
---@field build fun(left: Frame, right: Frame, nav: PagleGuideNav)  -- draw the two pages once (UI units, 442 x 546 each)
---@field onShow? fun()         -- each time the step shows (re-read live state: bindings, sets, board)
M:RegisterGuideStep(step)       -- ONB-R21; before ModulesChanged

---@class PagleGuideNav
---@field Next fun()  ---@field Back fun()  ---@field Close fun()
---@field BindingField fun(parent: Frame, action: string, label: string): Frame   -- ONB-R40–R44, Core's widget, 382 x 62; field:Refresh() re-reads the bindings (a step's onShow), field:SetGreyed(bool) greys it (ONB-R32, ONB-R100)
---@field ChoiceCard fun(parent: Frame, title: string, line: string, tag?: string): Button
---@field Note fun(parent: Frame, text: string, x: number, y: number, w: number, target?: Region)  -- an illustrative note, part of the page
---@field Part fun(parent: Frame, sprite: string): Texture  -- a sprite of the guide's atlas (GuideParts), for pages a Module draws
---@field Panel fun(frame: Frame, sprite: string, cap: number): PagleNineSlice  -- a GuideParts sprite nine-sliced on `frame`, `cap` units kept at each corner, following its size (QoL's set cards, ONB-R33)

---@class PagleMarginNote
---@field id string             -- "<module>.<name>"
---@field text string           -- |cff9a2a1a…|r marks the red term
---@field target Region         -- what the arrow points at
---@field side? "LEFT"|"RIGHT"|"ABOVE"|"BELOW"  -- where the note sits; default: the side with most room
M:ShowMarginNote(note)          -- ONB-R50–R52; no-op if seen or notes are off

---@class PagleFirstLook
---@field id string             -- "<module>.<window>"
---@field window Frame|fun(): Frame?  -- the window the set belongs to, or a function returning it (nil until it's made)
---@field title string          -- "the Fish Journal" (the bar reads "First look · {title}")
---@field notes { text: string, target: fun(): Region?, x: number, y: number, w: number }[]  -- x, y from the window's top left; *term* or |cff9a2a1a…|r marks the red term
---@field open? fun()           -- the tour's way to open the window (ONB-R84); without it the tour calls window:Show()
M:RegisterFirstLook(set)        -- ONB-R56; once, before the window first shows (at OnInitialize or OnEnable to join Off you go's list and the tour)
M:ShowFirstLook(id, again?)     -- from the window's OnShow; no-op if seen or notes are off, unless `again` (the "?", ONB-R59); returns whether it shows

M:CompleteEveningItem(id)       -- ONB-R61 ("journal" for the Ledger, "hunts" for Hunts)

M:SetDialogOpen(open)           -- ONB-R100: a dialog of the Module's own that asks the player something opened (true)
                                -- or closed (false); the Letter waits while any is open (QoL's conflict note)
```

- **ONB-R90** Each call raises a Lua error at the caller, adding nothing, for a missing or mistyped field (CORE-R14's sense). A Module calls them only `if M.RegisterGuideStep then` (and likewise for each), so the same code runs on a Core without them.
- **ONB-R91** `def.guideBlurb` (string, optional): the Module's one line on the What's in the box step. Ledger: "Your book: every water and every fish, your Angler Level, records and titles." Hunts: "Fish that only bite at night, in winter or at the fair, and which of them bite right now." Stats: "Your own numbers: your odds, from your own Casts, and how long you’ve waited. It never pops up." Tackle Board: "Small goals pinned to a cork board, if you want them. They wait while you’re away." QoL: "The Fishing key, your fishing clothes, lures and clams: one press, one action." A Module without one shows its title alone.
- **ONB-R92** Margin notes, First looks and the coach bar are Core's frames; a Module never draws its own. The "?" (ONB-R59) and a step's page contents are the Module's, drawn with its own art and `nav`.
- **ONB-R93** `PagleMoment.firstNote?: string` (announcements.md › Contracts), additive (CORE-R15).

Events Core fires (CORE-R20): `GuideOpened`, `GuideClosed(stepId)`. No Module needs them today; they let a Module refresh a sample it drew.

## UI

Every new piece is drawn from the guide atlas, `GuideParts` (one 1024 x 2048 BLP, DXT5 with mips, from the kit's `PagleArtGuide/Textures/GuideParts.blp`, its sprite table from `Atlases/GuideParts.lua`), in Core's `media/guide/`: ribbons, the Letter's seal and slip, note paper and badge, the target ring, key caps, choice cards and radios, checkboxes, the bind field, the coach bar, the next-action bezel and slip, promise discs, the bookplate ring, the tracker paper and its boxes, the lacquer box for Nudge and tooltip samples, the part icons. The book shell is Core's `media/books` (ONB-R20); the kit's own copies of the book textures, its fonts, its `Samples` atlas and its `Screen-*` stand-ins don't ship. Where the probe uses stand-ins (screenshots of other windows, the samples on Moments and Tackle Board, the menu), the addon uses the real frames, standing still.

The repo's own pieces are used wherever there is one: `Pagle.Animate`, `Pagle.Bezier`, `Pagle.EASE` and `Pagle.IsAnimationsOn()` for motion; `Pagle.FitToScreen`; `Pagle.IsRestricted()` and `RestrictionChanged`; the tracker dock; the key-capture helper (ONB-R41); `ns.DrawAnnouncement` for the still samples (the Nod and banner forms exposed beside the toast's, ONB-R34); QoL's key cap and buttons for its steps. New in Core: the Line-drawn arrow and ring, the Margin note, a general nine-slice paper panel, choice cards, the coach bar, the step ribbons' seen state, the tracker with tick rows, and a small-caps (IM Fell English SC) font object.

- Arrows are `Line` objects (`frame:CreateLine()`, `SetStartPoint`/`SetEndPoint`, thickness 2, `#23407a` at 90%), a quadratic curve cut into 14 segments with a two-stroke head, and a 12-unit red ring at the target. `CreateLine` drew in the client in the probe.
- Margin notes are straight in game (the canvas tilts them ±1.3°; a frame can't rotate its text).
- A note sits on its `side`, or the side with most room past the note itself, 40 units from its target (beside it, its top 30 above the target's middle; above or below it, centred on it), and at least 8 units inside the screen. Core's own notes take the canvas's widths (`core.nod` 250, `core.toast` 280, `core.summary` 260, `core.uncharted` 300, `core.welcome` and `core.character` 250); any other note is 270 wide. Each note carries the badge 1.
- Fonts: Core's bundled IM Fell English (print, italic), IM Fell English SC (kickers), Caveat (the hand: notes, Letter, signature, tags) and Marcellus (ribbons, buttons, the coach bar).

### Motion

See the kit's `MOTION.md`. In short: the Letter rises 30 units and fades in (0.5 s, ease-out) with its seal dropping from 1.6x (0.15–0.55 s); the guide fades in and out, turns its pages and drops its current ribbon as the book shell does (BOOK-R4, BOOK-R17, BOOK-R31); a Margin note fades in (0.25 s), then its arrow draws from note to target (0.35 s) and the ring pops (0.15 s), a set's notes 0.12 s apart; a First evening tick inks in (0.3 s) and the list folds away (0.4 s). With Animations off, each appears settled. Nothing loops, and nothing moves while the guide is idle.

### Sounds

See the kit's `SOUND.md`. New events: `letter` (TUTORIAL_POPUP), `noteIn` (IG_CHAT_SCROLL_DOWN, once per note or set), `tick` (IG_MAINMENU_OPTION_CHECKBOX_ON), `listDone` (IG_QUEST_LIST_COMPLETE). The book's open, close and page-turn sounds are the shell's (BOOK-R4, BOOK-R31); the guide reuses the books' `click`, `check`, `uncheck`. SFX channel only; in Cozy mode only what the player clicks plays.

## Settings

| Option | Values | Default | Where |
|---|---|---|---|
| Show me around again | button | | Settings root › Getting started (ONB-R81) |
| Margin notes | on/off | on | Settings root › Getting started |
| Show them again | button | | Settings root › Getting started |
| First evening list | on/off (shown only while unfinished) | on after the guide | Settings root › Getting started |

## Tunables

| Name | Value | Rules |
|---|---|---|
| Letter delay after `PLAYER_ENTERING_WORLD` | 4 s | ONB-R10 |
| Letter showings before it's declined | 2 | ONB-R12 |
| Returning Angler's note delay | 20 s or first `SessionStarted` | ONB-R2 |
| Margin note lifetime | 12 s | ONB-R51 |
| Margin note gap from its target, inset from the screen's edge, default width | 40, 8, 270 units | core/onboarding.md › UI |
| First evening fold delay | 2.5 s | ONB-R62 |
| Ribbon colour, a step not yet seen | `#a23a28`, 82% | ONB-R24 |
| World dim behind the guide | 0.58 | ONB-R20 |
| Free margin before First-look notes overlap the window | 210 units | ONB-R58 |

## Edge cases

- **ONB-R100 Angleur or Fishing Buddy loaded.** QoL's conflict note (QOL-R81) comes first; the Letter waits until it's answered or dismissed (ONB-R10). Core knows it is open without reading QoL (ADR 0001): QoL calls `M:SetDialogOpen(true)` as the note shows and `M:SetDialogOpen(false)` once it, and the Reload now note that follows a choice (QOL-R83), have both gone. While QoL stands down (QOL-R82), the Casting step reads, under its title, "Pagle’s Fishing key is resting while {other} has it. You can still cast with a double right-click." and its binding field is disabled.
- **ONB-R101 QoL off.** No Casting or Fishing clothes steps, no `qol.lure` or `core.character` note; the `cast` item's hint is the QoL-off one.
- **ONB-R102 Ledger off.** No Your Ledger step, no `journal` item, no Journal First look; Welcome and What's in the box still read correctly (they name only registered parts).
- **ONB-R103 Every Module off.** The guide has Core's four steps; What's in the box shows only the Curio Shop and the line "Turn parts on in the AddOns list."
- **ONB-R104 Logged out mid-guide.** `guideStep` is saved; the Letter isn't shown again (`letter = "opened"`); `/pagle guide` resumes.
- **ONB-R105 Not enough equipment-set slots.** The Fishing clothes step's Save button stays enabled; pressing it runs QOL-R42, which prints its message; the step adds the message under the button in red until the step is left.
- **ONB-R106 UI scale and small screens.** ONB-R27; the Letter and notes are unscaled frames in UIParent; First-look notes that don't fit beside a window overlap its edge (ONB-R58).
- **ONB-R107 Another addon moved the tracker dock or Blizzard's objective tracker.** The First evening list follows the dock (CORE-R71).
- **ONB-R108 The minimap icon hidden.** Notes meant for Pagle's menu button point at the Addon Compartment's button instead (ONB-R52); hiding or showing the icon while such a note shows moves its arrow (ONB-R56).
- **ONB-R109 Hunts before M8's board.** The Hunts First look's last note has no Pagle Wagers ribbon to point at and drops (ONB-R56); the set shows its four other notes. Since M8's ribbon (#303) the note points at it and shows (#333).

## In-game exit check

1. Fresh SavedVariables (or `/pagle dev onboarding reset`), every Module on: the Letter appears 4 s after the world, above the action bar; Later; `/reload`; it appears once more; Later; `/reload`; it doesn't.
2. `/pagle guide`: eight steps, ribbons tick as visited, back and next turn pages, Esc closes and `/pagle guide` resumes at the same step.
3. Casting step: bind F where F is Assist Target → conflict box; Use F → Key Bindings shows F on "Pagle: Fishing key" and Assist Target unbound; Esc while listening leaves it as it was.
4. Fishing clothes: save a set; *Pagle Fishing* and *Pagle Previous* appear in the equipment manager.
5. Moments: Lively writes 40 per 5 min with Show every catch on, Quieter 10 per 5 min with it off, Cozy turns Cozy mode on (check the Announcements page).
6. Tackle Board: Start my board starts it (TKB-R5); the step then reads "Your board is up".
7. Off to the water: the First evening list docks; with Quieter chosen, cast, catch, open the Journal, Hunts, wait out a Session, open the shop: each ticks; it folds away.
8. First Nod (a catch is a toast now: turn Interruptions down to 1 in Settings » Announcements, then catch twice, the second steps down to a Nod), first toast with Coins, first Session summary: one note each, never again (`/reload` and check); `/pagle guide notes` brings them back. An Uncharted catch shows `core.uncharted` beside its toast.
9. Open the Journal, Hunts, Stats, the board and the shop: each shows its First look once; each window's "?" shows it again, also with Margin notes off.
10. Disable Pagle_TackleBoard: the guide has 7 steps, "of 7". Enable it again with a fresh board: its Write-up carries Show me around », which opens the guide at the Tackle Board step.
11. Enter combat with the guide open: it closes; leave combat: it reopens at the same step. A toast raised while the guide was open shows when it closes.
12. A second character: the "Same Ledger" note shows once on the minimap icon; with the icon hidden, it points at the compartment.
13. UI scale 1.15 on 1366 x 768: guide and ribbons fit.
14. read-wtf's Onboarding section shows the state after each step above.
