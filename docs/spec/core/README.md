# Core

> Status: Done · Milestones: M0, M1, M2, M3, M4 (`/pagle shop`), M5 (the tracker dock, CORE-R70–R73) · Sources: [Define the Core/Module contract](https://github.com/timemir/wow-fish/issues/9#issuecomment-6112445901), [How do DBM-style multi-addon packages wire Core and Modules?](https://github.com/timemir/wow-fish/issues/3#issuecomment-6109740635), [Choose the toolchain and libraries](https://github.com/timemir/wow-fish/issues/8#issuecomment-6112249259), [Beta probe: which fishing signals can the Forever client see?](https://github.com/timemir/wow-fish/issues/7#issuecomment-6110508010), [Define the content data pipeline](https://github.com/timemir/wow-fish/issues/19#issuecomment-6113646946), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Hunts board](https://github.com/timemir/wow-fish/issues/24#issuecomment-6114195571), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0004, 0007, 0008, 0009

Core is the `Pagle` addon. This file covers how Modules attach to it, the whole `Pagle` API at a glance, and the surfaces Core hosts for everyone: the Settings root, the compartment menu, `/pagle` and the tracker dock. The rest of Core is split by topic:

| File | Prefix | Covers |
|---|---|---|
| [catch-log.md](catch-log.md) | `LOG` | Observing fishing, the Catch log and its entries, conditions, Sessions, the content catalogue, projections |
| [announcements.md](announcements.md) | `ANN` | Moments, the Announcement policy, toasts, sounds, the Session summary, the Write-up |
| [wallet-and-shop.md](wallet-and-shop.md) | `SHOP` | Pagle Coins and the Curio Shop |
| [field-report.md](field-report.md) | `REP` | `/pagle report` and the diagnostics it reads |

Terms are used as `CONTEXT.md` defines them. Numbers live in each file's Tunables table.

## Purpose and boundary

**Core owns:**
- observing the game's fishing, conditions and restriction state (the only addon that does, ADR 0001)
- the Catch log, the Angler and the shared content catalogue with its condition evaluator
- cutting Sessions
- presenting every Announcement, the Session summary and the Write-up (ADR 0007)
- Pagle Coins and the Curio Shop (ADR 0009)
- the Field report
- the hosted surfaces: Settings root, compartment menu, `/pagle`, tracker dock
- the projection machinery every Module uses (ADR 0004)

**Core does not own:** any Module view (Journal, Hunts board, Stats window, Tackle Board), any content only one Module reads (the Hunt list, the Ledger's curve and titles, the Tackle Board's templates), or any reward rule.

**Core alone shows:** its Settings root and topic pages, the Curio Shop, the Field report box, Announcements, the Session summary and the Write-up. With no Module enabled, Core records silently.

## Rules

### Packaging and load

- **CORE-R1** The package is one zip holding `Pagle` (Core) and the Modules `Pagle_Ledger`, `Pagle_Hunts`, `Pagle_Stats`, `Pagle_TackleBoard` and `Pagle_QoL`, each its own addon folder under `addons/`. This list is the **roster**; Core knows it by name.
- **CORE-R2** Every TOC has `## Interface: 16001`, `## AllowLoadGameType: camelot`, `## Group: Pagle`, `## Category: Professions` and `## Version: @project-version@` (the packager fills it in). No other game type and no per-flavour TOC files exist.
- **CORE-R3** Every Module TOC has `## Dependencies: Pagle` and `## X-Pagle-API: <n>`. Modules are loaded normally, not on demand.
- **CORE-R4** Code detects Forever with a nil-guarded `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, never with interface or build numbers. If the check fails, Core prints one chat line and never creates the `Pagle` global, so every Module's guard (CORE-R11) stops it.
- **CORE-R5** Core's SavedVariables are `PagleLog` and `PagleDB` (see [catch-log.md](catch-log.md#data)), both account-wide. No addon in the package uses `SavedVariablesPerCharacter`; per-character facts are keyed by character GUID.
- **CORE-R6** Core embeds LibStub, CallbackHandler-1.0, AceAddon-3.0, AceEvent-3.0 and AceDB-3.0, vendored at a recorded commit. Modules reach them through LibStub and embed nothing themselves.
- **CORE-R7** Every addon splits its code into `logic/` (pure Lua: no WoW globals, everything passed in as arguments, unit-tested with busted) and `adapter/` (events, frames, SavedVariables, Ace). luacheck enforces it with a per-path `std`.
- **CORE-R8** Every user-facing string goes through the addon's string table (`ns.L`), enUS only in 1.0.

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
  | Curio Shop | chat line | closes, with its Buy popup |
  | Field report box | chat line | stays open |
  | Session summary, Write-up | held ([announcements.md](announcements.md)) | hidden and held |

  Module views follow their own spec.

### Settings root

- **CORE-R40** Core registers one Settings category, "Pagle", with Blizzard's native Settings API; AceConfig and AceGUI are not used. The root is a hub. It holds:
  - a "Recording your Catches. Enable a Module to see them." line when no Module is enabled
  - the Module status list (CORE-R41), with each On Module's action button (CORE-R44)
  - a "Help chart the waters" button that opens the Field report
  - Core's saving option ([catch-log.md](catch-log.md#settings))

  Under the root, Core registers four **topic pages**, in this order: **Fishing**, **Announcements**, **Trackers** and **Look and Feel**. Pages are grouped by what the player is doing, not by owner. The list is fixed: Modules add rows to it (CORE-R42) and never register pages of their own. The layout and order of rows belong to `docs/spec/settings.md`.
- **CORE-R41** The status list shows the roster in CORE-R1 order, each with its TOC version and one state:
  - **On**: enabled and registered
  - **Needs a newer Pagle**: inert (CORE-R13)
  - **Failed to start**: enabled, loaded, but never registered (it errored)
  - **Off**: disabled in the AddOns list (this session's state, read with CORE-R16)
  - **Not installed**: `C_AddOns.GetAddOnInfo` reports it missing
- **CORE-R42** A Module adds options with `M:AddSetting(topic, setting)`, where `topic` is `"fishing"`, `"announcements"` or `"trackers"`. It does this before `ModulesChanged` (CORE-R19); Core builds the pages then. A later call is reported through `geterrorhandler()` and dropped.
  - On each page, Core's own rows come first. Each Module's rows follow, in `def.order`, under a header with its `def.title`. The header is left out when the Module's first row is a header of its own.
  - A page with no rows isn't registered: Fishing while QoL is off, or Trackers with no tracker Module on.
  - A setting's value lives in the Module's own DB, reached through the setting's `get` and `set`.
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

### Slash commands

- **CORE-R60** Core owns `/pagle`. With no argument it opens the Settings root. `/pagle help` lists every command with its help text, Core's and each registered Module's.
- **CORE-R61** Core's own subcommands are `help`, `settings` (same as no argument), `shop` (toggle the Curio Shop) and `report` (open the Field report). They are reserved.
- **CORE-R62** A Module's `slash = {{ name, fn, help }}` entries become `/pagle <name> <args>`; `fn` receives the rest of the line, trimmed. Subcommand names match case-insensitively. A name that collides with a reserved one or an earlier Module's is skipped and reported through `geterrorhandler()`; the rest of the Module's registration goes ahead. An unknown subcommand prints the help list.

### Tracker dock

- **CORE-R70** Core owns one HUD anchor, the **tracker dock**, by default under the minimap cluster at its right edge. Module trackers stack in it. A Module docks its tracker with `M:RegisterTracker{ id, order, frame }`; the dock stacks visible frames top to bottom by the tracker's `order` (Hunts 10, Stats 20, Tackle Board 30; ties by Module name), with fixed spacing, and reflows when one hides, resizes or its Module is disabled.
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
| `Pagle.CONTENT_FINGERPRINT` | string | catch-log.md |
| `Pagle.GetItem(itemID)`, `GetArea(areaID)`, `GetZones()`, `GetZoneOf(areaID)`, `GetZoneCatches(zoneAreaID)`, `GetWindowSpec(windowID)` | catalogue records | catch-log.md |
| `Pagle.SIZE_BANDS`, `Pagle.SIZE_RULES_VERSION`, `Pagle.FormatLength(mm)` | band list, integer, string | catch-log.md |
| `Pagle.GetBalance()` | `Balance` | [wallet-and-shop.md](wallet-and-shop.md#contracts) |
| `Pagle.IsOwned(goodID)`, `GetEquipped(slotID)`, `SetEquipped(slotID, goodID)`, `OpenShop(goodID?)` | | wallet-and-shop.md |
| `Pagle.OpenFieldReport()`, `GetFieldReportCount()` | | [field-report.md](field-report.md#contracts) |

### Module handle (returned by `RegisterModule`)

| Method | Where |
|---|---|
| `M:IterateCatches(afterSeq)`: Core records plus this Module's own Module records | catch-log.md |
| `M:AppendRecord(kind, payload)` | catch-log.md |
| `M:RecordPrestige()` | catch-log.md |
| `M:NewProjection(def)` | catch-log.md |
| `M:RaiseMoment(moment)`, `M:SetSummaryLine(key, text)`, `M:RaiseWriteUp(section)` | [announcements.md](announcements.md#contracts) |
| `M:ReportCoinsEarned(total)`, `M:RegisterSlot(slot)`, `M:RegisterGood(good)`, `M:RefreshGoods()` | wallet-and-shop.md |
| `M:RegisterTracker{ id, order, frame }` | here |
| `M:AddSetting(topic, setting)` | here |

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
```

### `M:AddSetting(topic, setting)`

```lua
---@class PagleSetting
---@field kind "header"|"checkbox"|"slider"|"dropdown"|"button"|"keybinding"|"custom"
---@field id? string               -- needed if another row names it as parent
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
---@field binding? string          -- keybinding: the Bindings.xml name, also listed in Key Bindings › AddOns
---@field parent? string           -- id of the row it hangs under (indented)
---@field isEnabled? fun(): boolean  -- greyed out when false
---@field init? fun(): table       -- custom: returns a Settings initializer (e.g. Stats' watched Dry spells)
```

Rows map onto the native Settings initializers; `AddSetting` raises a Lua error for an unknown `topic` or `kind`.

### Events Core fires (owned here)

| Event | Payload |
|---|---|
| `RestrictionChanged` | `isRestricted: boolean` |
| `ModulesChanged` | none (CORE-R19) |

Fishing, Session and wallet events are listed in their topic files.

## UI

- **Settings root and topic pages:** native Settings panels; layout in `docs/spec/settings.md`. Look reference: `prototypes/settings-tree/` (variant B).
- **Compartment menu:** the native Addon Compartment dropdown (CORE-R50).
- **Tracker dock:** an invisible anchor; each docked tracker draws itself.

## Settings

| Option | Values | Default |
|---|---|---|
| Reset tracker dock position | button | |

The other Core options are in each topic file's Settings section.

## Tunables

| Name | Value | Rules |
|---|---|---|
| `Pagle.API_VERSION` before 1.0 | 1 | CORE-R15 |
| Module menu order | Ledger 10, Hunts 20, Stats 30, TackleBoard 40, QoL 50 | CORE-R50 |
| Tracker order | Hunts 10, Stats 20, TackleBoard 30 | CORE-R70 |
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
