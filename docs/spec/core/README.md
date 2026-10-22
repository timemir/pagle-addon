# Core

> Status: Done · Milestones: M0, M1, M2, M3, M4 (`/pagle shop`), M5 (the tracker dock, CORE-R70–R73), M8.5 Onboarding (the minimap icon, CORE-R53–R56; `guide`, CORE-R61) · Sources: [Define the Core/Module contract](https://github.com/timemir/wow-fish/issues/9#issuecomment-6112445901), [How do DBM-style multi-addon packages wire Core and Modules?](https://github.com/timemir/wow-fish/issues/3#issuecomment-6109740635), [Choose the toolchain and libraries](https://github.com/timemir/wow-fish/issues/8#issuecomment-6112249259), [Beta probe: which fishing signals can the Forever client see?](https://github.com/timemir/wow-fish/issues/7#issuecomment-6110508010), [Define the content data pipeline](https://github.com/timemir/wow-fish/issues/19#issuecomment-6113646946), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Hunts board](https://github.com/timemir/wow-fish/issues/24#issuecomment-6114195571), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0004, 0007, 0008, 0009

Core is the `Pagle` addon. This file covers how Modules attach to it, the whole `Pagle` API at a glance, and the surfaces Core hosts for everyone: the Settings root, the compartment menu, `/pagle` and the tracker dock. The rest of Core is split by topic:

| File | Prefix | Covers |
|---|---|---|
| [catch-log.md](catch-log.md) | `LOG` | Observing fishing, the Catch log and its entries, conditions, Sessions, the content catalogue, projections |
| [announcements.md](announcements.md) | `ANN` | Moments, the Announcement policy, toasts, sounds, the Session summary, the Write-up |
| [wallet-and-shop.md](wallet-and-shop.md) | `SHOP` | Pagle Coins and the Curio Shop |
| [field-report.md](field-report.md) | `REP` | `/pagle report` and the diagnostics it reads |
| [varieties.md](varieties.md) | `VAR` | Fish varieties, their rarity, Core's variety projection and the fish crests |
| [book-binding.md](book-binding.md) | `BIND` | The book binding: `Pagle.NewBookBinding`, which draws the `core.binding` look on every book and changes it |
| [book.md](book.md) | `BOOK` | The book shell: `Pagle.NewBook`, the window, pages, strip, buttons, ribbons, router and page turn every book is built on |

Terms are used as `CONTEXT.md` defines them. Numbers live in each file's Tunables table.

## Purpose and boundary

**Core owns:**
- observing the game's fishing, conditions and restriction state (the only addon that does, ADR 0001)
- the Catch log, the Angler and the shared content catalogue with its condition evaluator
- cutting Sessions
- presenting every Announcement, the Session summary and the Write-up (ADR 0007)
- Pagle Coins and the Curio Shop (ADR 0009)
- the Field report
- onboarding: the Letter, the Field guide, Margin notes, First looks and the First evening list ([onboarding.md](onboarding.md))
- the hosted surfaces: Settings root, the Pagle menu (its compartment entry and minimap icon), `/pagle`, tracker dock
- the projection machinery every Module uses (ADR 0004)

**Core does not own:** any Module view (Journal, Hunts board, Stats window, Tackle Board), any content only one Module reads (the Hunt list, the Ledger's curve and titles, the Tackle Board's templates), or any reward rule.

**Core alone shows:** its Settings root and topic pages, the Curio Shop, the Field report box, Announcements, the Session summary and the Write-up, the Letter, the Field guide, Margin notes, First looks, the First evening list and the minimap icon. With no Module enabled, Core records silently.

## Rules

### Packaging and load

- **CORE-R1** The package is one zip holding `Pagle` (Core) and the Modules `Pagle_Ledger`, `Pagle_Hunts`, `Pagle_Stats`, `Pagle_TackleBoard` and `Pagle_QoL`, each its own addon folder under `addons/`. This list is the **roster**; Core knows it by name.
- **CORE-R2** Every TOC has `## Interface: 16001`, `## AllowLoadGameType: camelot`, `## Group: Pagle`, `## Category: Professions` and `## Version: @project-version@` (the packager fills it in). No other game type and no per-flavour TOC files exist.
- **CORE-R3** Every Module TOC has `## Dependencies: Pagle` and `## X-Pagle-API: <n>`. Modules are loaded normally, not on demand.
- **CORE-R4** Code detects Forever with a nil-guarded `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, never with interface or build numbers. If the check fails, Core prints one chat line and never creates the `Pagle` global, so every Module's guard (CORE-R11) stops it.
- **CORE-R5** Core's SavedVariables are `PagleLog` and `PagleDB` (see [catch-log.md](catch-log.md#data)), both account-wide. No addon in the package uses `SavedVariablesPerCharacter`; per-character facts are keyed by character GUID.
- **CORE-R6** Core embeds LibStub, CallbackHandler-1.0, AceAddon-3.0, AceEvent-3.0 and AceDB-3.0, vendored at a recorded commit. Nothing else is embedded: the minimap icon (CORE-R53) is Core's own button, since LibDBIcon-1.0 is "All Rights Reserved" and LibDataBroker-1.1 states no licence, neither of which a GPL package can ship (ADR 0006). Modules reach them through LibStub and embed nothing themselves.
- **CORE-R7** Every addon splits its code into `logic/` (pure Lua: no WoW globals, everything passed in as arguments, unit-tested with busted) and `adapter/` (events, frames, SavedVariables, Ace). luacheck enforces it with a per-path `std`.
- **CORE-R8** Every user-facing string goes through the addon's string table (`ns.L`), enUS only in 1.0.
- **CORE-R9** Every string the package draws uses only characters the client's fonts have: ASCII, Latin-1 (U+00A0–U+00FF), the en and em dashes (– —, U+2013, U+2014), curly single and double quotes (‘ ’ “ ”, U+2018, U+2019, U+201C, U+201D), the bullet (•, U+2022) and the ellipsis (…, U+2026). On 2026-10-15 `/pagle dev glyphs` on build 1.60.1.70374 showed each of these, and every Latin-1 character tried (· « » ×), drawn in all four fonts Pagle uses (GameFontHighlight, ChatFontNormal, NumberFontNormalSmallGray, `Fonts\MORPHEUS.TTF`); ★ and ✓ as a box in all four, and → as a box in GameFontHighlight and MORPHEUS (#248). The build also draws a box for ☆, ☑, ☐, ❧, ☚ and ▸. Anything outside the set stays out, even where one font has it. A symbol outside the set is drawn as an in-client texture (`|T…|t`, its path in the build's ManifestInterfaceData) or written in words; each one the Ledger draws is one shared constant in its string table. A busted spec (`spec/glyphs_spec.lua`) checks every Lua string literal, XML and TOC line the package ships outside `libs/`, generated files included; the generator checks lore on the way in (DATA-R107). `/pagle dev glyphs` shows a probe line in each font Pagle uses, to settle in game whether a character renders.

### Attaching a Module

- **CORE-R10** Core finishes its `ADDON_LOADED` work (SavedVariables loaded, `PagleDB` migrated, catalogue built) before any Module's `OnInitialize` runs. The TOC dependency guarantees the order.
- **CORE-R11** Every Module file starts with `if not Pagle then return end`, so a broken install or a non-Forever client loads nothing.
- **CORE-R12** A Module calls `Pagle.RegisterModule(def)` once, in its AceAddon `OnInitialize`. Core returns a **Module handle**, the only way to reach the calls that act for one Module (running a projection, raising moments, appending records, paying Coins, registering goods, docking a tracker).
- **CORE-R13** Core reads the Module's `X-Pagle-API` with `C_AddOns.GetAddOnMetadata`. If it is missing, not a number, or greater than `Pagle.API_VERSION`, `RegisterModule` returns `nil`, Core prints one chat line ("Pagle: Pagle Hunts needs a newer Pagle."), and lists the Module as inert. An inert Module must stop.
- **CORE-R14** `RegisterModule` raises a Lua error, registering nothing, if `def.name` isn't in the roster, was already registered, or `def.title` or `def.order` is missing. Throughout the spec, "raises a Lua error" means `error(message, 2)`: the call is aborted and has no effect.
- **CORE-R15** The `Pagle` API is additive only from 1.0 on: a function, event or field is never removed or changed in meaning; `Pagle.API_VERSION` rises by one with each addition. Before 1.0 it changes freely and stays `1`.
- **CORE-R16** Core never enables or loads a Module, and never re-enables one the player disabled. It reads enable state with `C_AddOns.GetAddOnEnableState(name, UnitGUID("player"))`.
- **CORE-R17** A disabled Module runs no code, so it registers nothing: it vanishes from Settings, the compartment menu, `/pagle`, the tracker dock and the Curio Shop's goods for sale. What it left in Core's data (its Module records, its last reported Coins, purchases of its goods) stays.
- **CORE-R18** Records Core hands to Modules (log records, the Angler, catalogue entries, conditions snapshots) are shared and immutable; Modules never change them, and Core makes no defensive copies. In tests, Core's `spec/support/fake_pagle.lua` (**FakePagle**, built on Core's real `logic/`) hands Modules read-only proxies that raise an error on any write.
- **CORE-R19** `ModulesChanged` fires once at `PLAYER_LOGIN`, after every addon's `ADDON_LOADED`, so every enabled Module has registered (or failed to). Projections start later, at `PLAYER_ENTERING_WORLD` ([catch-log.md](catch-log.md#login-order)).

### The event bus

- **CORE-R20** Core publishes events through one CallbackHandler registry on `Pagle`: `Pagle.RegisterCallback(owner, event, fn)`, `Pagle.UnregisterCallback(owner, event)`, `Pagle.UnregisterAllCallbacks(owner)`. It is separate from AceEvent's shared message bus, which Pagle doesn't use. The handler receives `(event, ...)`.
- **CORE-R21** Each listener runs through `securecallfunction`, so an error in one Module's handler goes to `geterrorhandler()` (BugGrabber when installed, otherwise the default error frame) and never stops the others.
- **CORE-R22** Only Core fires events on `Pagle`. Modules never fire events for other Modules (ADR 0001).
- **CORE-R23** Every WoW event registration, in Core and Modules, goes through `Pagle.RegisterEvent(owner, event, fn)` or `Pagle.RegisterUnitEvent(owner, event, unit, fn)`, removed with `Pagle.UnregisterEvent(owner, event)`. The handler receives `(event, ...)`. Registration and each handler call run in `pcall`; a failure goes to `geterrorhandler()` once per owner and event per login. A registration that fails (an event missing on Forever) is reported, not fatal.

### Restriction state

- **CORE-R30** Core alone tracks restriction state, from `ADDON_RESTRICTION_STATE_CHANGED`, `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`, and reads the starting state at `ADDON_LOADED` (`InCombatLockdown()` plus the restriction API's current state). `Pagle.IsRestricted()` is true while either is active. `RestrictionChanged(isRestricted)` fires on every change after load, not for the starting state.
- **CORE-R31** Before publishing anything (events, snapshots, records), Core replaces every secret value (`issecretvalue(v)` true) with `nil`. How each field is then stored is in [catch-log.md](catch-log.md#entry-formats).
- **CORE-R32** Nothing in the package registers Settings, creates secure frames or changes bindings while `Pagle.IsRestricted()` is true. Core queues such work and runs it, in order, at `RestrictionChanged(false)`. The one exception is clearing override bindings (disarming), which is allowed while `InCombatLockdown()` is still false, so QoL can make its key inert as combat starts (QOL-R31); setting a binding (arming) never is. After a `/reload` in combat, Core's Settings root and topic pages register then, with every row Modules added.
- **CORE-R33** While restricted, Core's surfaces behave like this:

  | Surface | Opening while restricted | Already open when restriction starts |
  |---|---|---|
  | Compartment menu | opens; entries for the surfaces below print their chat line instead | |
  | Settings (`Pagle.OpenSettings`) | chat line "Pagle: settings open after combat." | Blizzard's panel handles it |
  | Curio Shop | chat line | closes, with its bill of sale |
  | Field report box | chat line | stays open |
  | Session summary, Write-up | held ([announcements.md](announcements.md)) | hidden and held |

  Module views follow their own spec.

### Settings root

- **CORE-R40** Core registers one Settings category, "Pagle", with Blizzard's native Settings API; AceConfig and AceGUI are not used. The root is a hub. It holds:
  - a "Recording your Catches. Enable a Module to see them." line when no Module is enabled
  - the Module status list (CORE-R41), with each On Module's action button (CORE-R44)
  - from M8.5, the Getting started section: the Field guide, Margin notes and the First evening list ([onboarding.md](onboarding.md), ONB-R81)
  - a "Help chart the waters" button that opens the Field report
  - Core's options: the Saving section (the `/reload` reminder, LOG-R86), the Units section (the length unit, LOG-R69) and, from M8.5, the Pagle menu section (Show the minimap icon, CORE-R56); the first two are in [catch-log.md](catch-log.md#settings), and all their rows in `docs/spec/settings.md` (SET-R10)

  Under the root, Core registers four **topic pages**, in this order: **Fishing**, **Announcements**, **Trackers** and **Look and Feel**. Pages are grouped by what the player is doing, not by owner. The list is fixed: Modules add rows to it (CORE-R42) and never register pages of their own. The layout and order of rows belong to `docs/spec/settings.md`.
- **CORE-R41** The status list shows the roster in CORE-R1 order, each with its TOC version and one state. The version is never the packager's raw token: while the TOC still says `@project-version@` (any whole `@…@`, a checkout the packager never filled in, CORE-R2), it reads "dev"; a Module that isn't installed shows none (`ns.ShownVersion`). The states:
  - **On**: enabled and registered
  - **Needs a newer Pagle**: inert (CORE-R13)
  - **Failed to start**: enabled, loaded, but never registered (it errored)
  - **Off**: disabled in the AddOns list (this session's state, read with CORE-R16)
  - **Not installed**: `C_AddOns.GetAddOnInfo` reports it missing
- **CORE-R42** A Module adds options with `M:AddSetting(topic, setting)`, where `topic` is `"fishing"`, `"announcements"` or `"trackers"`. It does this before `ModulesChanged` (CORE-R19); Core builds the pages then. A later call is reported through `geterrorhandler()` and dropped.
  - A call with a mistake in it raises an error at the caller and adds nothing: an unknown topic or `kind`, a `setting` that isn't a table, a missing `label`, a field its kind requires missing or of the wrong type (`get` and `set` for checkbox, slider and dropdown; `min`, `max` and `step` for a slider; `options` for a dropdown; `onClick` for a button; `binding` for a keybinding; `init` for custom), a button's `caption` that isn't a string, an `id` the Module already used on that page, or a `parent` naming none of its earlier rows there.
  - On each page, Core's own rows come first. Each Module's rows follow, in `def.order`, under a header with its `def.title`. The header is left out when the Module's first row is a header of its own.
  - A page with no rows isn't registered: Fishing while QoL is off, or Trackers with no tracker Module on.
  - A setting's value lives in the Module's own DB, reached through the setting's `get` and `set`.
  - A row reads `get` and `isEnabled` when the panel draws it and after a change through the row itself, which is when Blizzard's setting tells its control (SET-R61, SET-R62). A value that changed elsewhere (a choice the Module made itself) shows the next time the row is drawn. There is no call to make a shown row re-read: it would run Blizzard's Settings code from Pagle's, which taints the Settings list (SET-R6, [#246](https://github.com/timemir/wow-fish/issues/246)).
  - Setting ids are scoped per Module: an `id` is unique among one Module's rows on one topic page, and a `parent` names a row in the same Module's section of that page. Two Modules may use the same id (Stats and the Tackle Board both use `tracker`). `AddSetting` raises a Lua error for an id the Module already used on that page, or a `parent` that names none of its earlier rows there.
  - Look and Feel takes no rows. Core builds it from the goods registry ([wallet-and-shop.md](wallet-and-shop.md#ui)).
  - A slot's dropdown also appears beside the thing it changes. A slot in the "Announcements" category ends Core's rows on Announcements; a slot in the "Trackers" category ends its Module's rows on Trackers.
- **CORE-R43** `Pagle.OpenSettings(topic?)` opens the root, or the topic page named `topic`: `"fishing"`, `"announcements"`, `"trackers"` or `"look"`. It uses `Settings.OpenToCategory(category:GetID())`. An unknown topic, or one whose page isn't registered, opens the root.
- **CORE-R44** Each On Module's row in the status list has one button: `def.settingsAction` if set, otherwise "Open {label}" for its first view. For example, the Tackle Board shows "Start my board" until the board is started, and QoL, which has no view, opens Fishing.

### Compartment menu

- **CORE-R50** Core registers one Addon Compartment entry, "Pagle". Clicking it opens a menu, in this order:
  1. for each registered Module by `def.order`: its views, then its extra `menu` entries
  2. "Curio Shop" with the balance (`BreakUpLargeNumbers`, then a coin icon), from M2; it shows 0 while held. Until the shop exists (M4) the entry is shown disabled, with the balance.
  3. "Help chart the waters", followed by "(N)" when the Field report count is above 0
  4. "Settings"

  For example, with the Ledger and QoL enabled: "Fish Journal", "Input: Both", "Curio Shop  1,950 ●", "Help chart the waters (3)", "Settings".
- **CORE-R51** While Cozy mode holds moments, the compartment entry's label shows how many are waiting ("Pagle · 3 waiting"); the count is defined in ANN-R42.
- **CORE-R52** A menu `label` may be a function, so a Module can show live state (QoL's "Input: Both"); it is called each time the menu opens.
- **CORE-R53** From M8.5, Core also shows a **minimap icon**: Core's own round button on the minimap's edge (a child of `Minimap`, in the usual minimap-button look: the favicon in a round mask with the client's tracking-border ring), its icon the website's favicon (a gilt "P" on parchment; `media/minimap/Pagle.blp`, from pagle-backend's `favicon.ico`, the 48 px image at 64 x 64). The player drags it around the minimap's edge (it stays on the edge, by angle; it never moves while restricted); its angle and shown state are saved account-wide (`PagleDB.global.minimap = { angle, hide }`). It is named `PagleMinimapButton`, so minimap-button collectors that gather a minimap's named children can take it. The compartment entry stays. Together they are **Pagle's menu**.
- **CORE-R54** A left click on the icon opens the same menu as the compartment entry (CORE-R50, CORE-R52), anchored at the icon. Other buttons do nothing.
- **CORE-R55** **The tooltip.** The icon and the compartment entry (its `funcOnEnter`/`funcOnLeave`) show the same tooltip: "Pagle", then each line that applies: the waiting count while Cozy mode holds moments (CORE-R51's "3 waiting") and "A letter for you" while the Letter shows (ONB-R13).
- **CORE-R56** **Show the minimap icon** (Settings root, SET-R10; default on) shows or hides the icon at once. With it hidden, nothing else changes: the compartment entry is still there, and notes meant for Pagle's menu point at the compartment's button (ONB-R52).

### Slash commands

- **CORE-R60** Core owns `/pagle`. With no argument it opens the Settings root. `/pagle help` lists every command with its help text, Core's and each registered Module's.
- **CORE-R61** Core's own subcommands are `help`, `settings` (same as no argument), `shop` (toggle the Curio Shop), `report` (open the Field report) and, from M8.5, `guide` (open the Field guide; `guide notes` shows Margin notes again, ONB-R80). They are reserved.
- **CORE-R62** A Module's `slash = {{ name, fn, help }}` entries become `/pagle <name> <args>`; `fn` receives the rest of the line, trimmed. Subcommand names match case-insensitively. A name that collides with a reserved one or an earlier Module's is skipped and reported through `geterrorhandler()`; the rest of the Module's registration goes ahead. An unknown subcommand prints the help list.

### Screenshot tour (dev)

`/pagle dev tour` is one of the hidden dev commands ([in-game verification › Dev commands](../../agents/in-game-verification.md#dev-commands)): it shows every surface Pagle draws, one at a time, and takes a screenshot of each, so a redesign can be judged from a folder of pictures.

- **CORE-R65** A Module adds a **tour stop** with `M:RegisterTourStop(id, label, show, hide)`: `show` puts one surface on screen in a representative state, and `hide` puts back everything `show` changed. The stop is named `<module>.<id>`, the Module's name lowercased (`ledger.journal.home`); Core's own stops are named `core.<id>`. `id` is `[%w_.]+` and unique among the Module's stops; `label` is a non-empty string, shown only by `/pagle dev tour list`. A mistake raises a Lua error at the Module's call and adds nothing. A Module calls it only `if M.RegisterTourStop then`, so the same code runs on a Core without it. Core's own surfaces register through the same registry.
- **CORE-R66** `/pagle dev tour` runs every stop: Core's first, then each Module's by `def.order`, each Module's in the order registered. `/pagle dev tour <module>` runs one Module's (`core` for Core's), any case. For each stop it prints `tour <n>/<count>: <name>`, calls `show`, and 2.8 s later (after a toast's motion settles, announcements.md › Motion, and before a Nod leaves, ANN-R20) calls `Screenshot()`; 0.5 s after that it calls `hide`, and the next stop shows 0.3 s later. It prints the local time as it starts (the client names screenshot files by it) and as it ends. On a client without `Screenshot()` the start line asks the dev to press Print Screen as each stop's line appears, and each stop waits 4 s instead of 0.5 s before its `hide`. A `show` or `hide` that errors is reported through `geterrorhandler()` and the tour goes on.
- **CORE-R67** The tour doesn't start while restricted (CORE-R30): it prints one line and opens nothing, since stops open Settings and the Curio Shop. A restriction that starts during a tour ends it: the stop on screen hides without its screenshot and no further stop shows. One tour runs at a time; `/pagle dev tour stop` ends the one running the same way.
- **CORE-R68** Nothing is saved: every `hide` leaves the screen and the saved variables as they were before its `show` (a window open before its stop stays open). `/pagle dev tour list [module]` prints each stop's name and label, in tour order, and shows nothing. Core's own stops are each Announcement form (`/pagle dev preview`'s samples through the real lanes, taken back off screen at `hide`), a sample Session summary card and a sample Write-up, the Curio Shop, the Field report box, the glyph probe panel, and the Settings root and each registered page.

### Tracker dock

- **CORE-R70** Core owns one HUD anchor, the **tracker dock**, by default under the minimap cluster at its right edge. Module trackers stack in it. A Module docks its tracker with `M:RegisterTracker{ id, order, frame }`; the dock stacks visible frames top to bottom by the tracker's `order` (Core's First evening list 1, ONB-R60; Hunts 10, Stats 20, Tackle Board 30; ties by Module name), with fixed spacing, and reflows when one hides, resizes or its Module is disabled.
- **CORE-R71** The player moves the dock by Shift-dragging any docked tracker; the whole stack moves. The position is saved and can be reset from the Trackers page (CORE-R40). It never moves while restricted. If it overlaps Blizzard's own tracker, the player moves it.
- **CORE-R72** A Module decides when its own tracker is shown (each Module's setting); the dock only stacks. With no tracker visible, the dock shows nothing.
- **CORE-R73** Each tracker is a native objective-tracker-style block. Its frame is drawn by its Module, which reads its equipped tracker-frame look from Core (`Pagle.GetEquipped`).

## Data

Core's SavedVariables are specified in [catch-log.md](catch-log.md#data). This file adds one `PagleDB.profile` key:

| Key | Type | Default |
|---|---|---|
| `dock.point` | `{ point, relativeTo = "UIParent", relativePoint, x, y }` or `nil` | `nil` (CORE-R70 default) |

## Contracts

### `Pagle` (global, read-only to Modules)

Grouped by topic; the rules live in the linked file.

| Function / field | Returns | Where |
|---|---|---|
| `Pagle.API_VERSION` | integer | here |
| `Pagle.VERSION` | string, Core's TOC version | here |
| `Pagle.RegisterModule(def)` | Module handle or `nil` | here |
| `Pagle.RegisterCallback(owner, event, fn)`, `UnregisterCallback`, `UnregisterAllCallbacks` | | here |
| `Pagle.RegisterEvent(owner, event, fn)`, `RegisterUnitEvent(owner, event, unit, fn)`, `UnregisterEvent(owner, event)` | | here |
| `Pagle.IsRestricted()` | boolean | here |
| `Pagle.OpenSettings(topic?)` | | here |
| `Pagle.IterateCatches(afterSeq)` | iterator over Core records | [catch-log.md](catch-log.md#contracts) |
| `Pagle.GetFishingState()` | `"idle"`, `"channeling"`, `"looting"` | catch-log.md |
| `Pagle.GetAngler()` | `Angler` | catch-log.md |
| `Pagle.GetConditions()` | `ConditionsSnapshot` | catch-log.md |
| `Pagle.MatchesConditions(spec, snapshot)` | boolean | catch-log.md |
| `Pagle.NextWindow(spec, fromTime)` | `Window` or `nil` | catch-log.md |
| `Pagle.GetSession()` | `Session` or `nil` | catch-log.md |
| `Pagle.SESSION_RULES_VERSION` | integer | catch-log.md |
| `Pagle.SESSION_GAP` | integer, the Session gap in seconds (300) | catch-log.md |
| `Pagle.CONTENT_FINGERPRINT` | string | catch-log.md |
| `Pagle.GetItem(itemID)`, `GetArea(areaID)`, `GetZones()`, `GetZoneOf(areaID)`, `GetZoneCatches(zoneAreaID)`, `GetWindowSpec(windowID)` | catalogue records | catch-log.md |
| `Pagle.SIZE_BANDS`, `Pagle.SIZE_RULES_VERSION`, `Pagle.FormatLength(mm)` | band list, integer, string | catch-log.md |
| `Pagle.GetVarieties(speciesID)`, `Pagle.VARIETY_RARITIES` | a Species' ten or `nil`, rarity list | [varieties.md](varieties.md) |
| `Pagle.GetVarietiesCaught(speciesID)` | a fresh set `{ [index] = true }` of the positions caught | [varieties.md](varieties.md) |
| `Pagle.GetBalance()` | `Balance` | [wallet-and-shop.md](wallet-and-shop.md#contracts) |
| `Pagle.IsOwned(goodID)`, `GetEquipped(slotID)`, `SetEquipped(slotID, goodID)`, `GetGood(goodID)`, `GetSlotGoods(slot)`, `GetBindingLook(goodID)`, `OpenShop(goodID?)` | | wallet-and-shop.md |
| `Pagle.OpenFieldReport()`, `GetFieldReportCount()` | | [field-report.md](field-report.md#contracts) |
| `Pagle.IsAnimationsOn()` | boolean, the Animations setting | [announcements.md](announcements.md#contracts) |
| `Pagle.GetActivityXP()` | `ActivityXP` | [activity-xp.md](activity-xp.md#contracts) |
| `Pagle.GetCompanionState()`, `Pagle.GetPushedContent(kind)` | state string, items | [pushed-content.md](pushed-content.md#contracts) |
| `Pagle.GetFollowedAnglers()` | `{ state, anglers }` | [anglers-in-game.md](anglers-in-game.md#contracts) |
| `Pagle.Animate(owner, animations, onDone?)`, `Cue(owner, seconds, fn)`, `StopMotion(owner)`, `EASE`, `Bezier(x1, y1, x2, y2)` | Core's one motion driver | announcements.md |
| `Pagle.WheelScroll(scroll, delta, options?)` | a mouse wheel notch: a third of the view, gliding | [announcements.md](announcements.md#paglewheelscrollscroll-delta-options) |
| `Pagle.FitToScreen(frame, options)` | number, the scale used | [here](#paglefittoscreenframe-options) |
| `Pagle.NewBookBinding(frame, options?)` | `PagleBookBinding`: `Look()`, `SetLook(goodID?)` | [book-binding.md](book-binding.md#contracts) |
| `Pagle.NewBook(options)` | `PagleBook`: `RegisterPage`, `RegisterLeather`, `Open(place?, how?)`, `Close`, `Settle`, `Toggle`, `IsShown`, `Showing`, `Place`, `Draw`, `QueueDraw`, `SetRibbons`, `SetPlate(text, tooltip?)`, `RibbonFrame(id)`, `SetStripText`, `SetHelpShown`, `Look` | [book.md](book.md#contracts) |

### Module handle (returned by `RegisterModule`)

| Method | Where |
|---|---|
| `M:IterateCatches(afterSeq)`: Core records plus this Module's own Module records | catch-log.md |
| `M:AppendRecord(kind, payload)` | catch-log.md |
| `M:RecordPrestige()` | catch-log.md |
| `M:NewProjection(def)` | catch-log.md |
| `M:RaiseMoment(moment)`, `M:SetSummaryLine(key, text)`, `M:RaiseWriteUp(section)` | [announcements.md](announcements.md#contracts) |
| `M:ReportCoinsEarned(total)`, `M:RegisterSlot(slot)`, `M:RegisterGood(good)`, `M:RefreshGoods()` | wallet-and-shop.md |
| `M:ReportXPEarned(total)` | activity-xp.md |
| `M:RegisterTracker{ id, order, frame }` | here |
| `M:AddSetting(topic, setting)` | here |
| `M:RegisterTourStop(id, label, show, hide)`: a stop for the dev screenshot tour (CORE-R65) | here |
| `M:RegisterGuideStep(step)`, `M:ShowMarginNote(note)`, `M:RegisterFirstLook(set)`, `M:ShowFirstLook(id, again?)`, `M:CompleteEveningItem(id)`, `M:SetDialogOpen(open)` | [onboarding.md](onboarding.md#contracts) |

ADR 0008 names the record call `Pagle.AppendRecord`; it lives on the handle so Core knows which Module wrote the record.

### `RegisterModule(def)`

```lua
---@class PagleModuleDef
---@field name string            -- roster name without "Pagle_": "Ledger", "Hunts", "Stats", "TackleBoard", "QoL"
---@field title string           -- display name: "Ledger", "Hunts", "Stats", "Tackle Board", "QoL"
---@field order integer          -- menu order: Ledger 10, Hunts 20, Stats 30, TackleBoard 40, QoL 50
---@field settingsAction? { label: string|fun():string, onClick: fun() }   -- its button in the Settings status list (CORE-R44)
---@field views? { id: string, label: string|fun():string, open: fun() }[]   -- compartment menu views
---@field menu? { label: string|fun():string, onClick: fun() }[]             -- extra compartment entries
---@field slash? { name: string, fn: fun(args: string), help: string }[]     -- /pagle <name>
---@field guideBlurb? string    -- its line on the Field guide's What's in the box page (ONB-R91)
```

### `M:AddSetting(topic, setting)`

```lua
---@class PagleSetting
---@field kind "header"|"checkbox"|"slider"|"dropdown"|"button"|"keybinding"|"custom"
---@field id? string               -- needed if another row names it as parent; unique among this Module's rows on this page
---@field label string
---@field tooltip? string
---@field get? fun(): any          -- value kinds: checkbox, slider, dropdown
---@field set? fun(value: any)
---@field default? any             -- what the page's Defaults button restores
---@field min? number              -- slider
---@field max? number
---@field step? number
---@field options? fun(): { value: any, label: string }[]   -- dropdown
---@field onClick? fun()           -- button
---@field caption? string          -- button: the text on the button, with `label` beside it; without it, `label` is on the button and the row has no label (SET-R2)
---@field binding? string          -- keybinding: the Bindings.xml name, also listed in Key Bindings › AddOns
---@field parent? string           -- id of the row it hangs under (indented), a row of the same Module on the same page
---@field isEnabled? fun(): boolean  -- greyed out when false
---@field init? fun(): table       -- custom: returns a Settings initializer (e.g. Stats' watched Dry spells)
```

Rows map onto the native Settings initializers, except a keybinding row, which Core draws itself so that it can grey out (SET-R20); `AddSetting` raises a Lua error for an unknown `topic` or `kind`.

### `M:RegisterTourStop(id, label, show, hide)`

```lua
-- A stop for /pagle dev tour (CORE-R65): named "<module>.<id>", in the order registered.
if M.RegisterTourStop then
  M:RegisterTourStop("journal.home", "the Fish Journal: Home",
    function() --[[ open the surface, in a representative state ]] end,
    function() --[[ put back everything show changed ]] end)
end
```

### `Pagle.FitToScreen(frame, options)`

```lua
---@class PagleFitOptions
---@field width number        -- the window's whole extent in its own units, with what hangs outside its frame
---@field height number       --   (ribbons, a plate, the wax close button)
---@field lift? number        -- how far its centre sits above that extent's centre (default 0)
---@field keepPlace? boolean  -- keep it where it is on the screen instead of centring it
```

The big windows (the Curio Shop, the books, the Hunts and Tackle boards) are drawn at 1 UI unit per canvas px, and at a large UI scale UIParent is only 668 units tall, so each fits itself to the screen with this one call. Its scale is the largest that leaves 24 units clear round the extent, never above 1, and 1 while the screen has no size yet. It then centres the window on UIParent, `lift` up; a window that keeps its place instead keeps its first anchor where it is on the screen, its offsets rescaled for the new scale, as a scaled frame reads them in its own units. Every window fitted is fitted again when the UI scale or the window's size changes (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`), through Core's one pair of registrations (CORE-R23), made at the first fit, so nothing listens before a window is fitted (CORE-R13).

### Events Core fires (owned here)

| Event | Payload |
|---|---|
| `RestrictionChanged` | `isRestricted: boolean` |
| `ModulesChanged` | none (CORE-R19) |
| `GuideOpened`, `GuideClosed` | none; `stepId` (ONB-R20, onboarding.md) |

Fishing, Session, wallet, Activity XP (`ActivityXPChanged`) and pushed-content (`PushedContentReady`) events are listed in their topic files.

## UI

- **Settings root and topic pages:** native Settings panels; layout in `docs/spec/settings.md`. Look reference: `prototypes/settings-tree/` (variant B).
- **Compartment menu:** the native Addon Compartment dropdown (CORE-R50).
- **Minimap icon:** Core's own round minimap button with the favicon (CORE-R53).
- **Tracker dock:** an invisible anchor; each docked tracker draws itself.

## Settings

| Option | Values | Default |
|---|---|---|
| Tracker position (Trackers page, SET-R40) | button "Reset": puts the dock back at its default place (CORE-R71) | |

The other Core options are in each topic file's Settings section.

## Tunables

| Name | Value | Rules |
|---|---|---|
| `Pagle.API_VERSION` before 1.0 | 1 | CORE-R15 |
| Module menu order | Ledger 10, Hunts 20, Stats 30, TackleBoard 40, QoL 50 | CORE-R50 |
| Tracker order | First evening list 1, Hunts 10, Stats 20, TackleBoard 30 | CORE-R70 |
| Dock default offset | 10 px below the minimap cluster, right-aligned | CORE-R70 |
| Dock spacing between trackers | 8 px | CORE-R70 |

## Edge cases

- **CORE-R80 Module disabled, then enabled again.** While disabled it registers nothing (CORE-R17); Core keeps recording. When enabled, its projection catches up from its stored `lastSeq` and raises a Write-up for anything that history earned ([catch-log.md](catch-log.md#projections), [announcements.md](announcements.md#write-up)). Nothing earned is lost, and nothing pops up.
- **CORE-R81 Projection rebuild and first build:** handled by Core's projection machinery ([catch-log.md](catch-log.md#projections)) and the Write-up ([announcements.md](announcements.md#write-up)).
- **CORE-R82 In combat:** CORE-R30–R33.
- **CORE-R83 Crash mid-Session:** Core keeps nothing in memory that it can't rebuild; what was written before the crash is whatever WoW last saved ([catch-log.md](catch-log.md#crashes)).
- **CORE-R84 Daily or weekly reset:** no rule in this file depends on it.
- **CORE-R85 Uncharted or unconfirmed Catch:** recorded like any Catch ([catch-log.md](catch-log.md#observing-fishing)); nothing in this file treats it differently. A Catch whose item ID was secret is stored as item `0` (LOG-R8).
- **CORE-R86 Core missing or disabled:** the client refuses to load the Modules (`DEP_MISSING` / `DEP_DISABLED`); CORE-R11 covers a broken install.
