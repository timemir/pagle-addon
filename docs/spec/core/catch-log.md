# Core: Catch log, conditions, Sessions and projections

> Status: Done · Milestones: M1 (recording, conditions snapshot, catalogue lookup), M2 (projections, Sessions, catalogue v1), M3 (the Field report projection, `NextWindow`), M4 (Simulated Size, the length unit, Prestige and purchase entries, the wallet projection), M7 (Module records) · Sources: [Define the Core data model](https://github.com/timemir/pagle-addon/issues/10#issuecomment-6112707372), [Define the Core/Module contract](https://github.com/timemir/pagle-addon/issues/9#issuecomment-6112445901), [Beta probe: which fishing signals can the Forever client see?](https://github.com/timemir/pagle-addon/issues/7#issuecomment-6110508010), [How can Pagle identify items and places independent of client language?](https://github.com/timemir/pagle-addon/issues/20), [Design Hunts and the Now/Soon board](https://github.com/timemir/pagle-addon/issues/14#issuecomment-6113353568), [Design Stats: session stats, honest odds and dry spells](https://github.com/timemir/pagle-addon/issues/21#issuecomment-6113657288), [Define the content data pipeline](https://github.com/timemir/pagle-addon/issues/19#issuecomment-6113646946), [Design the /pagle report format and issue form](https://github.com/timemir/pagle-addon/issues/26#issuecomment-6124884698), [Design the Tackle Board](https://github.com/timemir/pagle-addon/issues/25#issuecomment-6124911363), [Design the Pagle currency and shop](https://github.com/timemir/pagle-addon/issues/28#issuecomment-6125331898), [Cut the MVP slice and roadmap](https://github.com/timemir/pagle-addon/issues/18#issuecomment-6113973068), [Decide how the spec is assembled](https://github.com/timemir/pagle-addon/issues/31#issuecomment-6128960652), [Design the Simulated Size bands](https://github.com/timemir/pagle-addon/issues/33#issuecomment-6129722545); ADR 0001, 0003, 0004, 0008, 0009, 0010

Part of [Core](README.md). This file covers what Core observes, how it is stored, and how Modules read it back.

## Purpose and boundary

**Owns:** detecting Casts and Catches, the account-wide append-only Catch log (`PagleLog`), `PagleDB`, the character table and the Angler, Skill Readings, build entries, Prestige entries, purchase entries (written for the Curio Shop), Module records, the conditions service, the content catalogue lookups, Simulated Sizes, cutting Sessions, the projection machinery, and the diagnostics buffer.

**Doesn't own:** what any Module derives from the log, how the catalogue is generated (`docs/spec/content-data.md`), or how moments are presented ([announcements.md](announcements.md)).

## Rules

### Login order

- **LOG-R1** At load and login, Core runs in this order:
  1. `ADDON_LOADED` (Core): check the `PagleLog` format (LOG-R18), note **`loginSeq`** (the log's length before anything is appended this session), migrate `PagleDB`, build the catalogue, read the starting restriction state (CORE-R30).
  2. `PLAYER_LOGIN`: add or update the current character (LOG-R25), build the area name index (LOG-R23), fire `ModulesChanged` (CORE-R19).
  3. First `PLAYER_ENTERING_WORLD` after a login or reload: start every projection's catch-up or rebuild (LOG-R71, LOG-R72).
  4. In the same handler, after starting projections: append a build entry if due (LOG-R36), then a Skill Reading if due (LOG-R31).

  Every entry appended after `loginSeq` (these, and any earlier in the session, such as a Skill Reading from `SKILL_LINES_CHANGED` during login or a Module record from a Module's login code) reaches every projection as a `"live"` entry (LOG-R74), never as `"replay"`.

### Observing fishing

- **LOG-R2** A **fishing channel** is `UNIT_SPELLCAST_CHANNEL_START` for `"player"` with a spell ID in the catalogue's fishing-spell list. It sets the fishing state to `"channeling"` and fires `CastStarted`.
- **LOG-R3** A Cast ends **caught** at `LOOT_READY` when `IsFishingLoot()` is true. When `IsFishingLoot()` is secret, the window counts as fishing only while a Cast is in progress. Core reads every loot slot with `GetLootSlotInfo` / `GetLootSlotLink`, skips money and currency slots, and keeps each remaining item's ID and quantity in slot order. The fishing state becomes `"looting"` until `LOOT_CLOSED`, then `"idle"`.
- **LOG-R4** Further `LOOT_READY` fires before `LOOT_CLOSED` belong to the same loot window and are ignored. `LOOT_OPENED` is never used, because it fires only with auto-loot off.
- **LOG-R5** A fishing `LOOT_READY` with no channel seen (the player reloaded mid-cast) still ends a caught Cast.
- **LOG-R6** A Cast ends **got away** when the game reports the fish escaped (`UI_INFO_MESSAGE` with the `ERR_FISH_ESCAPED` text, as Forever sends it during the channel; or the same text as a `UI_ERROR_MESSAGE` or a system message, kept as fallbacks) during the channel or within the grace time after it stops, with no fishing loot window. Verified on the live build during M1 dogfooding (#112); if Forever reports it differently, this rule is updated, not worked around.
- **LOG-R7** When a channel stops (`UNIT_SPELLCAST_CHANNEL_STOP`), Core waits up to the grace time for a fishing `LOOT_READY` or the escaped message. If neither comes, or a new fishing channel starts first, the Cast was **interrupted** (moved, recast, cancelled, combat): `CastEnded("interrupted")` fires (before the new channel's `CastStarted`, on a recast), nothing is written, and the state returns to `"idle"` unless a new channel is running. A Cast ends exactly once; later signals for it are ignored. A fishing `LOOT_READY` that comes after the grace time has ended a Cast interrupted (a lag spike) is not lost: it is recorded as a new caught Cast with no channel seen (LOG-R5), and the interrupted Cast is never ended again.
- **LOG-R8** **A Catch counts once offered** in a fishing loot window, whether or not it reaches the bags. Every offered item is a Catch, Uncharted items (unknown to the catalogue) included. An item whose ID is secret is recorded as item `0`; item `0` never matches the catalogue and is never credited later. A quantity that is secret or missing is recorded as `1`, the least a slot offers.
- **LOG-R9** When a Cast ends caught or got away, Core, in this order:
  1. takes the Cast snapshot (LOG-R20)
  2. appends the Cast entry (LOG-R11)
  3. fires any `SessionEnded` still due for the previous Session (LOG-R63), then `SessionStarted` if this Cast starts a new Session (LOG-R62)
  4. hands the entry to every projection as `"live"` (LOG-R73)
  5. fires `Catch(catch)` once per item in order, then `CastEnded(outcome, cast)`
  6. sets `"idle"` or keeps `"looting"`, and fires `FishingStateChanged` if the state changed
  
  Every event fires only after the entry is in `PagleLog.entries`.

### The Catch log

- **LOG-R10** `PagleLog` is a plain Lua table, not managed by AceDB, so a companion app reads exactly what Core writes. Its shape is under [Data](#data).
- **LOG-R11** Each entry is one string: a kind-and-version tag, then fields separated by `|` (ADR 0003). Every entry starts with the same **header**: `<tag>|<char>|<time>|<tie>`, where `char` is the 1-based index into `PagleLog.characters`, `time` is `GetServerTime()` and `tie` is the tie-break counter. The kinds and their fields are under [Entry formats](#entry-formats).
- **LOG-R12** `tie` is 0 unless an entry with the same `char` and `time` was already appended this second; then it is one more than the highest such entry's `tie`.
- **LOG-R13** An entry's **entry ID** is `<character GUID>-<time>-<tie>`. A **Catch ID** is `<entry ID>:<n>`, where `n` is the item's 1-based position in the Cast's `items` field. Both are permanent and globally unique, cost no stored bytes, and are the same live and replayed.
- **LOG-R14** An entry's **`seq`** is its index in `PagleLog.entries`. The log is append-only: an entry is never rewritten, reordered, migrated or deleted, and there is no compaction.
- **LOG-R15** `PagleLog.logId` is created once, with the file: 16 lowercase hex characters drawn from the first character's GUID, the server time and `math.random`. A `(logId, seq)` pair is the upload cursor for a future backend.
- **LOG-R16** The codec in Core's `logic/` encodes and decodes every kind and reads every tag it has ever written. An entry it can't decode is skipped by every reader and counted in `PagleDB.global.decodeErrors`, once per entry per login however many readers meet it.
- **LOG-R101** **No line feed in the log** ([#363](https://github.com/timemir/pagle-addon/issues/363), [#76](https://github.com/timemir/pagle-addon/issues/76) item 14). No `PagleLog` entry of any kind ever holds a line feed (LF, `0x0A`), and neither does the character table's text; a carriage return (CR, `0x0D`) may. Pagle's backend reads the log line by line and rejects a file with one (pagle-backend UPL-R10 step 8, UPL-R12 `nolf`, CMP-R31). Every writer keeps it out in the way that fits it:
  - **Entries:** Core's codec refuses any entry that would hold one: `Append` raises an error in its caller and appends nothing, whatever wrote the record (Core, a Module through `M:AppendRecord`, the test-log tooling). The fields that could carry text are a build entry's `version`, a purchase's `good`, a Companion entry's `keyId` and a Module record's `payload`; the others are numbers.
  - **Module records:** `M:AppendRecord` raises for a payload with one before it reaches the codec (LOG-R40), so a Module that logs free text escapes or drops line feeds itself (Hunts' pushed definitions are written on one line, a line break in their strings escaped as `\n`, HNT-R154).
  - **The character table** (LOG-R25, LOG-R26): the names the client reports are kept with any line feed stripped, since a login can't refuse a character.
- **LOG-R17** From 1.0 the entry formats below are frozen, and so is `PagleLog.format`: format 2, the one 1.0 ships (LOG-R18), is the frozen 1.0 format. A changed shape gets a new tag (`C2`), and the codec reads both; the format number stays 2.
- **LOG-R18** Before 1.0 the formats change freely. When `PagleLog.format` differs from the codec's format number, Core starts a new log (new `logId`, no entries, characters kept) and prints one chat line ("Pagle: dev log format changed; started a new log."). Every projection then rebuilds (LOG-R72). 1.0 ships format 2, and every beta or dev log is format 1, so each one starts over at its first 1.0 login. That is pagle-backend's line between them: it refuses a log in any format below 1.0's as `dev_log` (pagle-backend OPS-R135, OPS-R136), and a 1.0 log always arrives under a new `logId` (pagle-backend CMP-R133). From 1.0 the format number never changes in a way that needs this (LOG-R17).

### The Cast snapshot

- **LOG-R20** Taken when a Cast ends, it holds raw observations only, never derived conditions ("night", "in a pool", Hunt matches):
  - character and server time (the entry header)
  - realm minute of day (`GetGameTime()`: `hour * 60 + minute`)
  - uiMapID (`C_Map.GetBestMapForUnit("player")`) and instance mapID (8th return of `GetInstanceInfo()`)
  - zone and subzone areaIDs (LOG-R22)
  - skill rank and modifier, read live with `GetProfessionInfo` at that moment
  - lure enchant ID (4th return of `GetWeaponEnchantInfo()`), if any
  - active calendar events from the catalogue's event list (LOG-R46)
  - active fishing auras from the catalogue's aura list
  - per item: item ID and quantity
- **LOG-R21** Weather and pools are not recorded. Pools have no runtime ID; weather waits for launch re-verification. Either may be added later as a new field (LOG-R17).
- **LOG-R22** The zone areaID comes from `GetRealZoneText()` and the subzone areaID from `GetSubZoneText()`, through the runtime area index (LOG-R23), which gives every areaID with that name in the client's language:
  - **Zone:** of those IDs, the ones in the catalogue's AreaTable slice with no parent zone and the current instance's continent. If exactly one remains, it's used. If none is in the slice and the name has exactly one ID, that ID is used. Otherwise `0`.
  - **Subzone:** an empty subzone text, or one equal to the zone text, gives `0`. Otherwise, of the name's IDs, the ones in the slice whose parent chain, walked up until it reaches a zone, reaches the resolved zone; then as for zones. A parent missing from the slice or a cycle in the chain ends the walk, and that ID doesn't count.
  - The resolved ID is then mapped through the catalogue's alias table (an area on another map that stands for a baseline fishing area, e.g. 16521 → 18).
  - An unresolved name gives `0`, and the text goes to the diagnostics buffer (LOG-R81). An empty text (`""`) gives `0` and is not unresolved, the same as a secret one (`nil`): it has no text to report.
- **LOG-R23** The **runtime area index** maps the names `C_Map.GetAreaInfo(id)` returns for ids 1 to 40,000 to their IDs, built once per login (about 15 ms on the beta). It is the only source of area names; the catalogue ships none.

### Characters and the Angler

- **LOG-R25** At `PLAYER_LOGIN`, Core adds the character to `PagleLog.characters` if its GUID is new, and updates `lastSeen` and the display fields if not. A faction or realm transfer that produces a new GUID is a new character; nothing links the two.
- **LOG-R26** Display fields: `UnitName("player")` (first name and surname on Forever), `UnitClass` and `UnitRace` IDs, `UnitFactionGroup`, and the realm ID from the GUID. `hardcore` is `C_GameRules.IsHardcoreActive()` when that call exists, `nil` otherwise. Characters are never keyed by name.
- **LOG-R27** `Pagle.GetAngler()` returns the `Angler` (see [Contracts](#contracts)). Two `PagleLog` files belong to the same Angler when they share a character GUID; no account ID or BattleTag is stored.

### Skill Readings

- **LOG-R30** Core reads fishing skill with `GetProfessions()` then `GetProfessionInfo(index)` (skill line 356): rank, max rank and modifier.
- **LOG-R31** It reads skill at login (LOG-R1), on `SKILL_LINES_CHANGED` and on `CHAT_MSG_SKILL`. It appends a **Skill Reading** (`S1`) when the rank or max rank differs from that character's last Skill Reading, or the character has none. A change in modifier alone (a lure going on or off) writes no entry; the modifier is in every Cast snapshot.
- **LOG-R32** `SkillChanged(reading)` fires after each Skill Reading is appended. Any change in rank or modifier also fires `ConditionsChanged({"skill"})`.

### Builds

- **LOG-R36** At login (LOG-R1), Core reads `GetBuildInfo()` and appends a **build entry** (`B1`) if the build number differs from the last build entry in the log. The last one is cached in `PagleDB.global.lastBuild` as `{ logId, build }`; if the cache is missing or its `logId` differs from `PagleLog.logId`, Core finds it by scanning the log backwards.

### Prestige

- **LOG-R38** `M:RecordPrestige()` appends a **Prestige** entry (`P1`) for the current character, with the new prestige rank: one more than the number of `P1` entries already in the log, and Core's Activity XP total at that moment ([activity-xp.md](activity-xp.md), AXP-R5). Any Module may call it; only the Ledger does, and the Ledger decides when Prestige is allowed. `Prestige(record)` fires after it is appended.

### Purchases

- **LOG-R39** A purchase entry (`U1`) is appended only by the Curio Shop's buy flow ([wallet-and-shop.md](wallet-and-shop.md)). It stores the good's ID and the price paid.

### Companion

- **LOG-R37** A **Companion entry** (`K1`) records that the companion's data addon passed Core's check once ([pushed-content.md](pushed-content.md), PUSH-R13). When `Pagle.GetCompanionState()` first becomes `"connected"` and the log holds no `K1`, Core appends one for the current character with the file's `keyId` and `seq`; a log has at most one. It records the fact, never the content (PUSH-R23). Only Core's wallet projection reads it (Sonar Scope, SHOP-R29); `IterateCatches` never yields it. Core's projections are handed it, live and replayed, as Module records go to their Module's (LOG-R41); `Pagle.IterateCatches` and `M:IterateCatches` skip it, never counting it undecodable. Its record carries the file's `keyId` and `seq` as `keyId` and `pushedSeq`. `K1` is an additive kind: no earlier entry changes shape, so it doesn't raise `PagleLog.format` (LOG-R18 is untouched) and no log is started over; a Core from before it skips a `K1` as an entry it can't decode (LOG-R16).

### Module records

- **LOG-R40** `M:AppendRecord(kind, payload)` appends `A1|<header>|<module>|<kind>|<payload>` (ADR 0008), with `module` the Module's `def.name`. `kind` matches `[%w_.]+`. `payload` is any string without a line feed (LOG-R101), at most 200 bytes; a longer or invalid one raises a Lua error in the caller. Core never reads the payload. It returns the record and hands it to the Module's projections as a `"live"` entry under LOG-R73/R74: right away if they are up to date, after the current `apply` returns if called from inside one, or when the catch-up finishes if they are updating. Calling it during a `"replay"` or `"rebuild"` apply or from `done` raises a Lua error, so a rebuild never writes records twice.
- **LOG-R41** A Module record is replayed only to the Module that wrote it, through its handle's `M:IterateCatches` and its projections. Records from a disabled or uninstalled Module stay in the log and are skipped. A Module never appends a record as a cache of derived state.

### Reading the log back

- **LOG-R42** `Pagle.IterateCatches(afterSeq)` walks entries with `seq > afterSeq` up to the log's length when called, in order, and yields typed records (see [Contracts](#contracts)), decoding lazily. It yields Casts, Skill Readings, Prestiges, builds and purchases, never Module records. `M:IterateCatches(afterSeq)` yields the same plus that Module's own Module records. Casts and Skill Readings carry their Session's ID (LOG-R98).
- **LOG-R43** `Catch` and `CastEnded` hand Modules the same records `IterateCatches` would yield for that Cast.

### Conditions

- **LOG-R45** `Pagle.GetConditions()` returns a live `ConditionsSnapshot` with the same fields as a Cast's (LOG-R20), plus the realm date (`C_DateAndTime.GetCurrentCalendarTime()`) and the restriction flag. Secret values are `nil` (CORE-R31).
- **LOG-R46** An event in the catalogue's event list is **active** when today's `C_Calendar` day events include it and the current realm time is inside it: for a multi-day event, all of its middle days, from its start time on its first day, and until its end time on its last day; for a single-day event, between its start and end times. Calendar data read while secret counts as no events.
- **LOG-R47** `ConditionsChanged(changedKeys)` fires when any of `area` (zone or subzone, on the zone-change events), `auras` (on `UNIT_AURA` for the player), `lure`, `events` or `skill` changes. Lure and events have no reliable game event, so Core also polls them (lure every 5 s, events every 60 s and on `CALENDAR_UPDATE_EVENT_LIST`). The passing of realm time is not a change; Modules that care about time windows use `NextWindow` and their own timers.
- **LOG-R48** A **condition spec** is a table with any of these fields. Fields combine with AND; the values within a field combine with OR; there is no NOT.

  | Field | Value | Matches when |
  |---|---|---|
  | `areas` | list of areaIDs | the snapshot's zone or subzone is one of them |
  | `time` | list of `{ from, to }` realm minutes of day, `from` inclusive, `to` exclusive, wrapping past midnight when `to < from` | realm minute is in any range |
  | `season` | list of `{ from = {month, day}, to = {month, day} }`, both days inclusive, wrapping the year when `to < from` | realm date is in any range |
  | `events` | list of calendar event IDs | any of them is active |
  | `auras` | list of spell IDs from the catalogue's aura list | any of them is active |
  | `lure` | `true` (any lure) or a list of enchant IDs | a matching lure is on |
  | `skill` | `{ min = n }` | effective skill (rank + modifier) ≥ n |

  A field that is absent doesn't constrain. A `confirmed` field (a boolean, which a window spec from `GetWindowSpec` carries, LOG-R55) is not a condition and never constrains, so a window spec can be matched as it is. An empty list, or a range with `from == to`, is invalid: the generator rejects it in content data, and `MatchesConditions` raises an error. A snapshot field that is `nil` or `0` (secret or unresolved) never matches a field that tests it. There is no pool and no weather field.
- **LOG-R49** `Pagle.MatchesConditions(spec, snapshot)` is pure Core `logic/` and accepts a live snapshot or a Cast's. For a Cast, the realm date is derived from its server time and realm minute: the realm's UTC offset is the difference between the realm minute and the UTC minute of the server time, rounded to 15 minutes. Real offsets run from −12 to +14 hours (NZDT is +13, Kiribati +14), but a minute of day fixes the offset only to within a day, so the offset is taken in the 24 hours after −10 h, up to and including +14 h: a difference outside that range wraps by a day into it. Every offset east of UTC is then read right; −10 to −12 h, where no realm runs, read as +14 to +12 h.
- **LOG-R50** `Pagle.NextWindow(spec, fromTime)` forecasts the spec's time-based fields (`time`, `season`, `events`), intersected, and returns a `Window`:
  - if the spec has `time`, `season` or `events`: `{ openNow = true, closesAt }` if they all hold at `fromTime`, otherwise `{ opensAt, closesAt }` for the next opening within 400 days, or `nil` if there is none (or an event in it has no weekly rule)
  - otherwise, if it has `auras`: `{ onDemand = true }`
  - otherwise: `{ always = true }`

  Times are server times. Events are forecast only from the catalogue's weekly rules (LOG-R56), never by reading future calendar days, because calendar reads can be secret during lockdown; the live calendar still decides whether an event is open now (LOG-R46). `confirmed` on the result is false if any catalogue part it used is unconfirmed (a window spec or a weekly rule), and true otherwise, including for a Module's own specs.

### The content catalogue

- **LOG-R55** Core ships the catalogue generated by the content data pipeline as Lua in `addons/Pagle/data/` and exposes it read-only:
  - `Pagle.GetItem(itemID)` → `{ category, species?, family?, weight?, typicalLength?, quality?, legend, noise, removed, pool }`, or `nil` for an **Uncharted** item. `pool` is true when the item is in any pool type's catches (LOG-R56). `category` is one of `fish`, `questFish`, `trophy`, `container`, `treasure`, `junk`, `other`. `quality` is the item's DB2 quality (0 poor … 5 legendary), absent when unknown; an Uncharted item has none until a release classifies it.
  - `Pagle.GetZones()` → every zone areaID (`parent = 0`) in the AreaTable slice, ascending, whether or not it has catch data.
  - `Pagle.GetArea(areaID)` → `{ parent, continent, skillBase?, skillBaseConfirmed, hasData, catches = { { itemID, confirmed, window?, gate?, gateConfirmed? } } }`, or `nil` for an unknown area. `parent` is `0` for a zone. `gate` is a condition spec (LOG-R48). Every gated entry is gated by exactly one window, and carries that window's ID as `window` (`"night"`, `"summer"`, `"event.301"`; the IDs `GetWindowSpec` takes); `window`, `gate` and `gateConfirmed` are present together or not at all. A Module labels or groups a gate by its `window` ID and never matches or compares condition specs to work out which window it is.
  - `Pagle.GetZoneOf(areaID)` → the zone areaID a subzone belongs to (itself for a zone).
  - `Pagle.GetZoneCatches(zoneAreaID)` → every catch entry of the zone and its subzones, each with an added `areaID` field saying which area it came from. An item listed in several of them appears once per area.
  - `Pagle.GetWindowSpec(windowID)` → one condition spec table that carries the window's `confirmed` as a field (`{ time = …, confirmed = false }`), for the named windows `day`, `night`, `spring`, `summer`, `autumn`, `winter` and each event with a weekly rule; `nil` for any other ID.
  - `Pagle.CONTENT_FINGERPRINT` → the generator's hash of everything in the catalogue, as lowercase hex.
- **LOG-R56** The catalogue also holds:
  - the AreaTable slice (`{ id, parent, continent }` per area, no names) and the alias table (`areaID → baseline areaID`, LOG-R22)
  - `poolType → catches` (display only)
  - the fishing-spell list (LOG-R2) and the fishing-aura list (LOG-R20)
  - the event list: fishing-relevant calendar event IDs (starting with the Extravaganza, 301), each with an optional weekly rule `{ weekday (1 = Sunday), start (realm minute), duration (minutes), confirmed }`

  It ships IDs and numbers only; names and icons resolve at runtime with `C_Item` and `C_Map`. Item quality ships in the catalogue (LOG-R55) rather than being read from `C_Item`, because `C_Item` can't answer for an uncached item during a rebuild, and a rule that counts by quality must give the same result every time; a quality change from DB2 therefore changes `CONTENT_FINGERPRINT`.
- **LOG-R57** Before M2 the catalogue holds only what M1 recording needs: the fishing-spell list, the fishing-aura list, the event list and the AreaTable slice with aliases.

### Sessions

- **LOG-R60** A **Session** is a run of the Angler's Casts (caught and got away) in which no two consecutive Casts are 300 seconds (5 minutes) or more apart, by entry `time`. Character switches, zone changes, logouts and reloads don't split it; only the gap does, or in dev mode a Session break (LOG-R99).
- **LOG-R61** Sessions are cut from the log by a pure function in Core `logic/`; they are never stored in `PagleLog`. `Pagle.SESSION_RULES_VERSION` changes whenever the rule changes (Tunables; it went from 1 to 2 when the gap went from 900 s to 300 s), and Modules that store Sessions fold it into their rules version. `Pagle.SESSION_GAP` is the Session gap in seconds (300, LOG-R60): a Module that needs the gap reads Core's, never a copy of its own.
- **LOG-R62** Live: `SessionStarted(session)` fires right after the entry of a Cast that starts a new Session is appended (LOG-R9); its payload already counts that Cast. `SessionEnded(session)` fires when 300 seconds pass with no Cast while logged in. A Session's `endTime` is its last Cast's `time`.
- **LOG-R63** At login, if the latest Session's last Cast is 300 seconds or more ago and its ID isn't `PagleDB.global.lastEndedSession`, Core fires `SessionEnded(session)` once, with `whileAway = true`, as soon as no projection is updating (catching up or rebuilding, LOG-R74), or earlier if a new Cast is recorded first (LOG-R9), so a `SessionEnded` always comes before the next `SessionStarted`. `lastEndedSession` is set whenever `SessionEnded` fires.
- **LOG-R64** `Pagle.GetSession()` returns the current Session while one is open (last Cast under 300 seconds ago), else `nil`. A Session's `catches` counts Catches (items), not quantities; `zones` lists zone areaIDs (not subzones), without `0`.
- **LOG-R98** Every Cast and Skill Reading record Core hands out (from `Pagle.IterateCatches`, `M:IterateCatches`, `Catch`, `CastEnded` and `SkillChanged`) carries `session`, so Modules never cut Sessions themselves:
  - a Cast: the ID of the Session it belongs to (LOG-R60)
  - a Skill Reading: the ID of the Session open when it was appended, meaning the latest earlier Cast is less than 300 seconds before it; otherwise `nil`. A Skill Reading appended before a new Session's first Cast belongs to no Session.

  The tag is computed by the same `logic/` function that cuts Sessions and is never stored in the entry. When an iteration starts after `seq` 0, Core looks back from `afterSeq` to the Casts that open the Session in progress, so the tags are the same whether the log is read whole or in parts.
- **LOG-R99** A **Session break** ends a Session early, for testing. `/pagle dev endsession` (dev mode only, [in-game-verification.md](../../agents/in-game-verification.md#dev-commands)) ends the open Session as if its gap had passed: `SessionEnded` fires (LOG-R62), and the entry ID of the Session's last Cast goes into `PagleDB.global.sessionBreaks`. The next Cast then starts a new Session, however soon it comes: the cutter splits after a break as it splits at the gap, live and in every later read, so the projections that fold Sessions see two. A break splits Casts only. A Skill Reading still takes the Session whose last Cast is under 300 seconds before it (LOG-R98). The log is untouched. In real play no break is ever written, so the rule changes nothing there and `SESSION_RULES_VERSION` stays as it is.

### Simulated Size

- **LOG-R65** A Catch has a **Simulated Size** when `Pagle.GetItem(itemID)` has category `fish` or `questFish`, is not Noise and gives its Species a `typicalLength`; Legends included. Trophy fish (they have a real weight), Sub-collection items, Noise, Uncharted items and item `0` have none. Each Catch (one loot slot) has one size, whatever its quantity. Core computes it whenever it decodes a record and never stores it; records carry it as `size = { length, band }` (`length` in whole millimetres, `band` 1–5). It comes from the Catch ID (LOG-R66), the current catalogue and two things the log holds as recorded ([ADR 0014](../../adr/0014-simulated-size-is-bounded-by-a-reach-of-skill-and-experience.md)):
  - the **skill rank**: the Cast's `skillRank`, its modifier (lures, gear) never counting; without one, the `rank` of that character's latest Skill Reading before the Cast in the log; without one, 1.
  - the **earlier Catches** `n`: the Angler's Catches of the same item ID earlier in the log, on any character, one per slot whatever its quantity, the earlier slots of the same Cast included. Item `0` is never counted. They are counted from the log alone (LOG-R100), never through the catalogue, so a release that classifies an Uncharted item, moves an item between Species or retunes a typical length changes no item's count. Pagle's experience starts at install: nothing before the log is credited.

  An Uncharted Catch gains its size when a release classifies it as a Species (LOG-R96), the one it would have had live. Beside `size`, a decoded item of a Species with varieties carries its `variety` (VAR-R4), from the Catch ID and the catalogue alone.
- **LOG-R66** The **percentile** `u` of a Catch is a frozen hash of its Catch ID string (LOG-R13), computed in Core `logic/` with the `bit` library (LuaBitOp, which WoW ships; tests install the same library) and all arithmetic kept exact below 2^53:
  1. FNV-1a 32-bit over the ID's bytes: `h = 2166136261`; for each byte `c`, `h = bxor(h, c) % 2^32`, then `h = ((h % 256) * 16777216 + h * 403) % 2^32` (that is, `h * 16777619 mod 2^32`).
  2. Murmur3's `fmix32` finaliser: `h = h xor (h >> 16)`, `h = mul32(h, 0x85ebca6b)`, `h = h xor (h >> 13)`, `h = mul32(h, 0xc2b2ae35)`, `h = h xor (h >> 16)`, with `mul32(a, b) = (a * (b % 65536) + ((a * floor(b / 65536)) % 65536) * 65536) % 2^32` and every `bit` result taken `% 2^32`.
  3. `u = h / 2^32`, in [0, 1).

  Test vectors (`h` after step 2), with their size at a typical length of 300 mm as a Legend's (LOG-R67):

  | Catch ID | `h` | `u` | Band as a Legend | Length as a Legend |
  |---|---|---|---|---|
  | A `Player-4395-0A1B2C3D-1791731747-0:1` | 2657620567 | 0.618776 | 2 Decent | 314 |
  | B `Player-4395-0A1B2C3D-1791731747-0:2` | 4227872046 | 0.984378 | 4 Whopper | 453 |
  | C `Player-4395-0A1B2C3D-1791731762-1:1` | 1190098033 | 0.277091 | 2 Decent | 249 |
  | D `Player-1-00000001-1700000000-0:1` | 3063819173 | 0.713351 | 3 Hefty | 333 |

  A test also draws 300,000 synthetic Catch IDs (sequential times, 1–3 items per Cast) and checks every band's share at a full Reach is within 0.5 percentage points of LOG-R67's (Tiddler 0.41%, Decent 8.11%, Hefty 13.08%, Whopper 29.6%, Monster 48.8%: band `i` from `u ≥ c³` of its low edge), and that the percentiles of items 1 and 2 of the same Cast are uncorrelated.

  The **1.0 freeze spec** (`spec/Pagle/logic/Size_spec.lua`, [#267](https://github.com/timemir/pagle-addon/issues/267)) pins the hash of these vectors and LOG-R67's worked examples; for each band edge `c`, the two synthetic Catch IDs whose `u` lies closest below and at or above `c³` (within 0.00000011, from a search of 30,000,000), with their `h` and band at a full Reach; the two closest either side of `u = 0.421875`, where a Reach of 0.8 meets Whopper's edge, with the bands that skill 239, 240 and 241 (at `n` 1,000) and `n` 639, 640 and 641 (at skill 300) give them; and, for Legends, the two either side of each cut point (within 0.00000005) and the multipliers' ends at the full range's. Changing the hash, the 300 or 1,000, either curve, the exponent, a band edge, a range end or a Legend's cut point fails it, with a message naming ADR 0014.
- **LOG-R67** The **Reach** `R` of a Species Catch that isn't a Legend is how big a fish the Angler can land at that Cast, as a place in its Species' **full range**, 0.55× to 1.80× the typical length (ADR 0014): the lesser of the **skill reach** `min(max(skillRank / 300, 0), 1)` and the **experience reach** `√(min(n, 1000) / 1000)` (LOG-R65's skill rank and `n`). The Catch's place in that range is `p = R × u^(1/3)`, so `p` never exceeds `R`, and `n = 0` puts every first Catch of an item at the range's bottom. Then:
  - `length = floor(typical * (0.55 + 1.25 * p) + 0.5)`
  - the **Size band** is the one whose low edge `c` `p` has reached: 1 Tiddler [0, 0.16), 2 Decent [0.16, 0.44), 3 Hefty [0.44, 0.60), 4 Whopper [0.60, 0.80), 5 Monster [0.80, 1]. Core tests `R * R * R * u >= c * c * c` in doubles, multiplications only, so the band is the same on every platform's maths library; only the length uses `^`. The band never reads the typical length.

  Worked examples at a typical length of 300 mm, on LOG-R66's vectors:

  | Skill rank, `n` | `R` | A | B | C | D |
  |---|---|---|---|---|---|
  | any, 0 | 0 | 165 Tiddler | 165 Tiddler | 165 Tiddler | 165 Tiddler |
  | 300, 10 | 0.1 | 197 Tiddler | 202 Tiddler | 189 Tiddler | 199 Tiddler |
  | 150, 1,000 or 300, 250 | 0.5 | 325 Decent | 352 Hefty | 287 Decent | 333 Hefty |
  | 200, 300 | √0.3 = 0.548 | 340 Hefty | 369 Hefty | 299 Decent | 349 Hefty |
  | 225, 1,000 | 0.75 | 405 Whopper | 445 Whopper | 348 Hefty | 416 Whopper |
  | 300 (or more), 1,000 (or more) | 1 | 485 Monster | 538 Monster | 409 Whopper | 500 Monster |

  A **Legend** has no Reach, as a once-in-a-career Catch would otherwise always be a Tiddler: its band is the one whose cut points hold `u` (ADR 0010), 1 Tiddler [0, 0.15), 2 Decent [0.15, 0.70), 3 Hefty [0.70, 0.93), 4 Whopper [0.93, 0.995), 5 Monster [0.995, 1), and within band `i` its length is linear between that band's two multipliers (Tunables) of the typical length: `length = floor(typical * (m[i] + (m[i+1] - m[i]) * (u - cut[i]) / (cut[i+1] - cut[i])) + 0.5)`. The multipliers' ends are the full range's.

  Length rises with `p` (with `u`, for a Legend) within a Species. `Pagle.SIZE_BANDS` lists the bands in order as `{ key, name }`; the names are signed off for 1.0 ([#264](https://github.com/timemir/pagle-addon/issues/264)), and band 2's key stays `typical`.
- **LOG-R68** Everything that places a Catch in a band is frozen once shipped (ADR 0014): the hash, the 300 and 1,000, both reach curves, the exponent 3, the band edges, the full range's ends and a Legend's cut points. Every input is in the log as recorded, so a Catch's band never changes on a rebuild, and Hunts and Notices that target a minimum band are never revoked. The typical lengths (in the catalogue, LOG-R55) and a Legend's four inner multipliers can be retuned: a change to a typical length changes `CONTENT_FINGERPRINT`, and a change to the multipliers, or before 1.0 to anything else about how a size is drawn, changes `Pagle.SIZE_RULES_VERSION` (2 from the Reach), which Modules that store sizes fold into their rules version. Neither moves a Catch between bands or changes which Catch is a Species' longest.
- **LOG-R100** Core knows each item's earlier Catches (LOG-R65) at every Cast it hands out, from `Pagle.IterateCatches` and `M:IterateCatches` from any `afterSeq`, `CatchLog:Reverse`, `Catch` and `CastEnded`, so a Cast's sizes are the same whether the log is read whole, from a later `seq` or back:
  - It counts the raw entries, decoding none: a `C1` entry counts each slot of its last field, the items, when that field reads as the codec reads it (`<itemID>x<quantity>`, comma-separated); its other fields aren't read, so a Cast entry whose other fields don't decode (LOG-R16) still counts. Nothing is stored in `PagleLog` for it (ADR 0003).
  - For the login it keeps the counts at each `seq` a read started or ended at, and at the log's end as Casts are appended, and counts on or back from the nearest, so a read from `seq` 0 counts as it goes and a read near the end counts only the entries between. The Skill Readings the fallback skill needs are found by tag and decoded once a login, as far as a Cast needs them.
  - It keeps the counts at the log's end in `PagleDB.global.catchCounts` (Data), so the next login counts on from there rather than from `seq` 0: a raw count of a 100,000-entry log takes about 55 ms in Lua 5.1, more than a login step should. They are counted on from only when their `logId` and `rulesVersion` are the log's and `SIZE_RULES_VERSION`, and the log still holds their `entry` at their `seq`; otherwise Core counts the log again. They are a cache of the log, never a source: losing them changes no size.
- **LOG-R69** Lengths show in the Angler's **length unit** (Core setting): `Pagle.FormatLength(mm)` returns "34.2 cm" or "13.5 in", to 0.1 of the unit. The default is inches when `GetCurrentRegion()` returns 1 (Americas and Oceania) and cm otherwise, including when the call doesn't exist; `GetCurrentRegion` is on the launch re-verification list. Changing the unit changes only the display, never a comparison: Modules compare `length` in millimetres.

### Projections

Core runs every Module's stored projection the same way (ADR 0004).

- **LOG-R70** `M:NewProjection(def)` binds a projection to a table in the Module's own SavedVariables. Core keeps in it: `projection` (the Module's derived state), `lastSeq`, `logId`, `fingerprint` (the content fingerprint, plus `def.extraFingerprint` if given) and `rulesVersion`.
- **LOG-R71** From the first `PLAYER_ENTERING_WORLD` (LOG-R1), a projection **catches up**: Core applies every entry after `lastSeq` up to `loginSeq` through `def.apply(state, record, "replay")`. These are entries the Module never saw live: those recorded while it was disabled. Entries after `loginSeq` are queued and applied as `"live"` (LOG-R74). Catch-up runs in chunks across frames (a time budget per frame) when more than 500 entries are pending, and synchronously otherwise.
- **LOG-R72** The projection **rebuilds from `seq` 0** instead when `projection` is missing, `logId` differs from `PagleLog.logId`, `lastSeq` is greater than the log's length (an older backup), `fingerprint` differs, or `rulesVersion` differs from `def.rulesVersion`. Core calls `def.reset()` for a fresh state, then applies every entry up to `loginSeq`, in chunks across frames, with mode `"rebuild"`; later entries are queued as in LOG-R74. Core writes the new `projection`, `lastSeq`, `logId`, `fingerprint` and `rulesVersion` to the Module's table only when the rebuild finishes. A rebuild cut short by logout, reload or crash leaves the old values, so the next login rebuilds again from `seq` 0, with the same `firstBuild`.
- **LOG-R73** When an entry is appended while a projection is up to date, Core immediately calls `def.apply(state, record, "live")` for it and sets `lastSeq`, before firing any event for that entry other than the Session events (LOG-R9). Live entries are where a Module raises moments ([announcements.md](announcements.md#a-casts-announcements)).
- **LOG-R74** While catching up or rebuilding, `projection:IsUpdating()` is true and the Module shows that it's updating. Entries appended meanwhile are queued and applied in order as `"live"` right after the catch-up or rebuild finishes. `IsUpdating()` stays true after `done` until those entries are applied, so a Module that appends from a step it schedules at `done` reads its own records back before it reads the state again; inside its own `done` it reads false.
- **LOG-R75** `mode` tells the Module how to treat an entry: `"live"` (just recorded while the Module was running: may raise moments), `"replay"` (catch-up: never raises moments) or `"rebuild"` (never raises moments). Core drops moments raised during a `"replay"` or `"rebuild"` apply (ANN-R4).
- **LOG-R76** When a catch-up or rebuild finishes (even one with nothing to apply), Core calls `def.done(state, info)`:
  - `info.firstBuild`: true when the projection had never been built, or the Module's DB was lost, and the entries applied include at least one Cast
  - `info.rebuilt`: true after a rebuild
  - `info.replayed`: the number of entries applied in `"replay"` mode
  
  In `done`, a Module may only raise a Write-up and `summaryOnly` moments ([announcements.md](announcements.md#write-up)).
- **LOG-R77** The Module's **celebrated set** (the high-water mark of what was already shown) lives in its DB outside `projection`, so a rebuild never clears it. Core never touches it. If the whole Module DB is lost, the celebrated set is lost with it, and the next build counts as a first build (LOG-R76).
- **LOG-R78** Core runs its own projections (the Field report's, the wallet's spent total and owned goods, the varieties caught of [varieties.md](varieties.md) VAR-R10) with the same machinery.
- **LOG-R79** Pagle's backend folds the Catch log through `logic/` alone ([#223](https://github.com/timemir/pagle-addon/issues/223), [#76](https://github.com/timemir/pagle-addon/issues/76) item 5). Its projection driver loads each addon's `logic/` files, Core's `data/Catalogue.lua` and Hunts' `data/HuntList.lua` and `data/EventList.lua`, never `adapter/` or `locale/`, and computes no value itself. So every `logic/` file loads without `ns.L`, each projection can be bound from `logic/`, and every value the backend shows is a function of projection state in `logic/`. The driver reads the log with Core's `ns.OpenCatchLog(log, global, now, getItem)`, `getItem` being the catalogue's `GetItem`: without that fourth argument no Catch has a Simulated Size (LOG-R65). Its Casts carry the client's sizes, as the earlier Catches and skill come from the log alone (LOG-R100). The functions it calls are in [Contracts › The backend's hooks](#the-backends-hooks); a binding hook folds to the same state as the client's projection, with none of its moments, Coins reports or other effects.

### The diagnostics buffer

- **LOG-R80** Core keeps the text of world objects the player hovers, using `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, …)`: the tooltip's first line and `GetTime()`.
- **LOG-R81** For each Cast it records, Core adds one entry to `PagleDB.global.diagnostics`: `{ id, zone, subzone, locale, texts, unresolved? }`, with the Cast's entry ID, its zone and subzone areaIDs, `GetLocale()`, up to 3 distinct object texts hovered in the 60 s before the channel started (most recent first), and the zone and subzone text when either didn't resolve (LOG-R22). The buffer keeps the last 500 entries and drops the oldest.
- **LOG-R82** The diagnostics buffer is outside the sync rules: it isn't part of the Catch log, isn't uploaded, and may be dropped. Only the Field report reads it.

### Crashes

- **LOG-R85** SavedVariables are written only on logout or `/reload`, so a client crash loses the Casts since the last write. Core does nothing to work around it.
- **LOG-R86** An opt-in setting (off by default) shows one chat line each time 50 more Casts are unsaved since the last load: "Pagle: 50 Casts not yet saved. `/reload` to keep them safe." A line due while restricted is shown when the restriction ends. The line stays plain text, with no clickable "Reload now" (decided in #113): a chat link would need new infrastructure, a hyperlink handler and a SET or ANN rule for it, so the player types `/reload`.

## Data

### `PagleLog` (plain table)

```lua
PagleLog = {
  format = 2,            -- PagleLog layout version: 2 from 1.0, frozen (LOG-R17, LOG-R18)
  logId = "3f9a2c1e7b0d4a65",
  characters = {         -- array; entries refer to the index
    { guid = "Player-4618-0A1B2C3D", name = "Ada", surname = "Brook",
      classID = 1, raceID = 1, faction = "Alliance", realmID = 4618,
      hardcore = false,      -- nil when the game exposes no flag
      firstSeen = 1791731680, lastSeen = 1791735000 },
  },
  entries = { "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1", ... },
  test = true,           -- only on a test log (see below); absent on a player's log
  devCoins = 50000,      -- only on a test log: Coins it grants (see below)
  devXP = 700000,        -- only on a test log: Activity XP it grants (see below)
  devHuntsSince = 1791000000, -- only on a test log: its Hunts' release date (see below)
}
```

`test = true` marks a **test log**: one the test-log tooling wrote for the dev, never one a player fished. Only on a test log does `/pagle dev catch` append synthetic Casts ([in-game verification › Dev commands](../../agents/in-game-verification.md#dev-commands)). A test log is never a release concern: 1.0's freeze rules (LOG-R17) don't apply to it. A format change (LOG-R18) starts a new log without the flag.

A test log may also grant Coins (`devCoins`) and Activity XP (`devXP`), each a whole number, 0 or more, so the tooling can set up a rich or high-prestige account without months of synthetic Casts. At login step 1 Core stores each under the source "Dev", beside the Modules' totals (SHOP-R3, AXP-R3): the wallet counts the Coins, and Activity XP counts the XP, which the Ledger's climb and its Prestige snapshots read (LED-R37, AXP-R5). "Dev" counts as On, and the Curio Shop's purse counts its Coins in the balance but draws no segment for it. It may also set a release date for Hunts (`devHuntsSince`, a server time): Hunts then treats every Hunt whose `since` is later as out from that date (HNT-R2), so a test log can play the standing Hunts before they are released. Modules read the grants with `Pagle.GetTestLogGrant(name)`. All three are read only on a log with `test = true`: on a player's log the fields mean nothing, and the totals' tie to the logId (SHOP-R3, AXP-R3) drops the Coins and XP when another log is installed.

### Entry formats

Every entry starts with the header `<tag>|<char>|<time>|<tie>` (LOG-R11). The canonical Core grammar and checkpoint contract are shared with [pagle-backend](https://github.com/timemir/pagle-backend/blob/main/docs/spec/record-contract.md) (#302). Numbers have no plus sign, leading zeros, negative zero, fractions, or exponent notation; absolute values are at most 2^53 − 1. Only skill modifiers may be negative. Lists inside a field are comma-separated, ascending and without duplicates, except `items`, which keeps slot order and may repeat an item ID. An empty field means "none" or "unknown".

| Tag | Kind | Fields after the header |
|---|---|---|
| `C1` | Cast | `outcome` (`c` caught, `g` got away) · `minute` (realm minute of day) · `uiMap` (empty if unknown) · `instance` (empty if unknown) · `zone` (`0` if unresolved or secret) · `subzone` (`0` if none, unresolved or secret) · `rank` · `mod` · `lure` (empty if none) · `events` · `auras` · `items` (`<itemID>x<qty>` per item, in slot order; empty when got away) |
| `S1` | Skill Reading | `rank` · `max` · `mod` |
| `P1` | Prestige | `rank` (the new prestige rank), `activityXP` (Core's Activity XP total when it was recorded, AXP-R5; required by the canonical contract) |
| `B1` | Build | `build` (the `GetBuildInfo()` build number) · `version` (e.g. `1.60.1`) |
| `U1` | Purchase | `good` (good ID, `[%w_.]+`, or `core.crate` for a Curio crate) · `price` |
| `K1` | Companion | `keyId` · `seq` (the accepted file's, LOG-R37) |
| `A1` | Module record | `module` (`def.name`) · `kind` (`[%w_.]+`) · `payload` (everything after the 6th `\|`, verbatim) |

Example, a caught Cast: `C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1`. That is character 1, caught at realm 08:14 in The Long Wash (148/453), skill 86+25 with lure 263, no listed event or aura, one Oily Blackmouth. About 60 bytes.

The ADR 0003 and ADR 0008 notes sketch `B1`, `U1` and `A1` without the shared header; this table is the canonical layout.

### `PagleDB` (AceDB, one shared `Default` profile)

| Key | Contents |
|---|---|
| `global.schemaVersion` | integer; ordered `if version < N` migration steps run on load. Migrations exist only here and in each `Pagle<Module>DB`, never for `PagleLog`. |
| `global.lastBuild` | `{ logId, build }`, the last logged build number (LOG-R36) |
| `global.lastEndedSession` | the ID of the last Session `SessionEnded` fired for (LOG-R63) |
| `global.sessionBreaks` | `{ [castEntryID] = true }`, the Casts after which `/pagle dev endsession` ended a Session (LOG-R99); absent until it's first used |
| `global.decodeErrors` | count of entries the codec couldn't decode (LOG-R16) |
| `global.catchCounts` | the earlier Catch counts at the log's end, for the next login (LOG-R100): `logId`, `rulesVersion` (`SIZE_RULES_VERSION`), `seq`, `entry` (the entry string at `seq`) and `counts` (`{ [itemID] = n }`); absent until Core has first counted to the log's end. A cache: losing it changes nothing. |
| `global.dev` | boolean, the `/pagle dev` switch (#247); default `false`. Never shown to players. |
| `global.diagnostics` | ring buffer of up to 500 entries (LOG-R81) |
| `global.probe` | what `/pagle dev probe` saved for launch re-verification (#261): `time`, `build`, `locale`, `checks`; and `timings`, the load timings of the last login made with dev mode on (#262): `time`, `entries`, `budget`, `syncLimit`, `marks` (debugprofilestop ms at each login step) and `projections` (each catch-up or rebuild: `name`, `mode`, `started`, `finished`, `applied`, `frames`, `longest`). Absent until either is first saved; tooling only, never shown to players. |
| `global.summary`, `global.pending`, `global.cards`, `global.writeUp` | Announcement data ([announcements.md](announcements.md#data)) |
| `global.coins`, `global.goods` | the wallet ([wallet-and-shop.md](wallet-and-shop.md#data)); `coins.logId` given the log's by migration step 3 (SHOP-R3) |
| `global.activityXP` | the Activity XP totals ([activity-xp.md](activity-xp.md#data)) |
| `global.pushed` | `seq`, the last pushed file's `seq` Core accepted ([pushed-content.md](pushed-content.md#data), PUSH-R13); no default |
| `global.onboarding` | the onboarding state ([onboarding.md](onboarding.md#data)), added by migration step 2 (ONB-R1) |
| `global.projections.*` | Core's own projections (LOG-R78): `fieldReport` ([field-report.md](field-report.md#data)), `wallet` ([wallet-and-shop.md](wallet-and-shop.md#data)), `varieties` ([varieties.md](varieties.md#data)) |
| `global.pasteExports` | `{ [logId] = seq }`, each log's last exported seq for the Paste string ([paste-string.md](paste-string.md#data), PST-R40); default `{}` |
| `global.minimap` | the minimap icon's place and shown state (CORE-R53, CORE-R56): `angle`, degrees round the minimap counterclockwise from its right, to 0.1, default `225` (its bottom left); `hide`, default `false` |
| `profile.reloadReminder` | boolean, the `/reload` reminder (LOG-R86); default `false` |
| `profile.lengthUnit` | `"cm"`, `"in"`, or `nil` for the region default (LOG-R69); default `nil`. The Defaults button sets it back to `nil` (SET-R13). |
| `profile.anglerTooltips` | the "Show other Anglers on player tooltips" setting ([anglers-in-game.md](anglers-in-game.md#data), VIEW-R30); default `true` |
| `profile.*` (other keys) | Core settings in the other topic files: `profile.announcements`, `profile.appearance`, `profile.dock` |

### Module SavedVariables

Each Module keeps one AceDB SavedVariable, `Pagle<Module>DB`, account-wide with one shared profile, holding its settings, its celebrated set and its projection table (LOG-R70). A Module never reads or writes `PagleLog`, `PagleDB` or another Module's DB.

## Contracts

### Typed records

```lua
---@class PagleRecord
---@field seq integer
---@field id string              -- entry ID (LOG-R13)
---@field kind "cast"|"skill"|"prestige"|"build"|"purchase"|"module"
---@field char integer           -- index into Angler.characters
---@field time integer           -- server time

---@class PagleCast : PagleRecord
---@field outcome "caught"|"gotAway"
---@field session string        -- its Session's ID (LOG-R98)
---@field conditions ConditionsSnapshot
---@field items { n: integer, itemID: integer, quantity: integer, catchId: string, size?: PagleSize, variety?: PagleVariety }[]

---@class PagleCatch            -- payload of the Catch event, one per item
---@field catchId string
---@field itemID integer         -- 0 if it was secret
---@field quantity integer
---@field n integer              -- position in the Cast's items
---@field size? PagleSize        -- LOG-R65
---@field variety? PagleVariety  -- VAR-R4
---@field cast PagleCast

---@class PagleSize             -- a Simulated Size (LOG-R65–R67, LOG-R100)
---@field length integer         -- millimetres
---@field band integer           -- 1 Tiddler … 5 Monster

---@class PagleVariety          -- a Catch's variety (VAR-R4, varieties.md)
---@field id string              -- "<speciesID>.<key>"
---@field index integer          -- position 1–10
---@field rarity "common"|"uncommon"|"rare"|"epic"

---@class ConditionsSnapshot
---@field time integer           -- server time
---@field minute integer         -- realm minute of day
---@field date { year: integer, month: integer, day: integer, weekday: integer }  -- realm date; derived for Casts (LOG-R49)
---@field uiMap? integer
---@field instance? integer
---@field zone integer           -- 0 if unresolved or secret
---@field subzone integer        -- 0 if none, unresolved or secret
---@field skillRank? integer
---@field skillMod? integer
---@field lure? integer
---@field events integer[]
---@field auras integer[]
---@field restricted? boolean    -- live snapshots only

---@class Angler
---@field logId string?          -- nil only on a fresh install before the first PLAYER_LOGIN
---@field characters { guid: string, name: string, surname?: string, classID: integer, raceID: integer, faction: string, realmID: integer, hardcore?: boolean, firstSeen: integer, lastSeen: integer }[]
---@field current integer?       -- index of the logged-in character; nil before PLAYER_LOGIN
---@field skill { [integer]: PagleSkillReading }   -- latest Skill Reading per character index
---@field bestBaseSkill integer  -- highest skill rank among all characters (0 if none)

---@class PagleItem             -- Pagle.GetItem
---@field category "fish"|"questFish"|"trophy"|"container"|"treasure"|"junk"|"other"
---@field species? integer       -- Species ID (fish and quest fish); equal for the items of one Species
---@field family? integer        -- trophy family ID
---@field weight? number         -- a trophy's real weight, in pounds
---@field typicalLength? integer -- fish and quest fish: the Species' typical length in mm (LOG-R67)
---@field quality? integer       -- DB2 item quality, 0 poor … 5 legendary; nil when unknown (LOG-R55)
---@field legend boolean         -- a Legend (CONTEXT.md)
---@field noise boolean          -- Noise (CONTEXT.md)
---@field removed boolean        -- proven gone from Forever; left out of every list
---@field pool boolean           -- in any pool type's catches (LOG-R56)

---@class PagleCatchEntry        -- one element of PagleArea.catches (keyed, not positional)
---@field itemID integer
---@field confirmed boolean
---@field window? string         -- the gate's window ID (LOG-R55); present when gate is
---@field gate? table            -- condition spec (LOG-R48), the spec of that window
---@field gateConfirmed? boolean -- present when gate is

---@class PagleArea              -- Pagle.GetArea
---@field parent integer         -- 0 for a zone
---@field continent integer
---@field skillBase? integer
---@field skillBaseConfirmed boolean
---@field hasData boolean        -- false for areas without catch data (e.g. the new Forever zones)
---@field catches PagleCatchEntry[]

---@class Window
---@field openNow? boolean
---@field opensAt? integer
---@field closesAt? integer
---@field always? boolean
---@field onDemand? boolean
---@field confirmed boolean
```

`PagleSkillReading` adds `rank`, `max`, `mod` and `session?` (LOG-R98); `PaglePrestige` adds `rank`; `PagleBuild` adds `build`, `version`; `PaglePurchase` adds `good`, `price`; `PagleModuleRecord` adds `module`, `recordKind`, `payload`.

### Events Core fires (owned here)

| Event | Payload | When |
|---|---|---|
| `CastStarted` | none | LOG-R2 |
| `FishingStateChanged` | `state` | whenever `GetFishingState()` changes |
| `Catch` | `PagleCatch` | LOG-R9, once per item |
| `CastEnded` | `outcome` (`"caught"`, `"gotAway"`, `"interrupted"`), `PagleCast` or `nil` when interrupted | LOG-R7, LOG-R9 |
| `SkillChanged` | `PagleSkillReading` | LOG-R32 |
| `Prestige` | `PaglePrestige` | LOG-R38 |
| `ConditionsChanged` | `changedKeys: string[]` | LOG-R47 |
| `SessionStarted` | `Session` | LOG-R62 |
| `SessionEnded` | `Session` | LOG-R62, LOG-R63 |

`Session` is `{ id, startTime, endTime, firstSeq, lastSeq, casts, catches, gotAway, characters = {char…}, zones = {areaID…}, whileAway? }`, with `id` the entry ID of its first Cast.

### Projection definition

```lua
---@class PagleProjectionDef
---@field db table                   -- a table in the Module's SavedVariables, owned by Core from here on
---@field rulesVersion integer
---@field extraFingerprint? string   -- Hunts: its own list fingerprint
---@field reset fun(): table         -- a fresh, empty state
---@field apply fun(state: table, record: PagleRecord, mode: "live"|"replay"|"rebuild")
---@field done? fun(state: table, info: { firstBuild: boolean, rebuilt: boolean, replayed: integer })
```

`M:NewProjection(def)` returns a projection with `:GetState()`, `:IsUpdating()` and `:Rebuild()` (a manual full rebuild, for a debug command).

### The backend's hooks

What the backend's projection driver calls in `logic/` (LOG-R79), by the names agreed on [#223](https://github.com/timemir/pagle-addon/issues/223). The driver looks each one up and leaves out a value whose function is missing. Each `state` is that projection's state after `done`, except `Measures` and `AnglerLevel`, which the driver may read after any record. `MeasureRises` keeps when the other three measures last rose, so for the rise times the driver needs only `AnglerLevel` after each record. The Ledger's reads that work out the level take Core's Activity XP total as their last argument, `total`: the sum of `ActivityXPEarned` over the paying Modules at that point (AXP-R9, LED-R37), which the driver reads alongside. Without it they count none, since `logic/` alone sets no source; the client counts `Pagle.GetActivityXP().total`. Only Core's adapter and FakePagle reach a Module through `Pagle`, so a binding hook reads the `Pagle` API (and Hunts the server time) from the globals the driver hosts. The client never calls these hooks.

| Where (`ns` of) | Function | Returns |
|---|---|---|
| `Pagle` | `BindCoreProjections(newProjection)` | nothing: calls `newProjection(name, def)` for each of Core's projections by its `PagleDB.global.projections` key: `"wallet"`, whose state has `spent` (SHOP-R11), and `"varieties"`, whose state has `bySpecies` (VAR-R10). The Field report's is left out, as its input never leaves the client (LOG-R82). |
| `Pagle_Ledger`, `Pagle_Hunts`, `Pagle_Stats`, `Pagle_TackleBoard` | `BindProjections(M)` | the projection `M:NewProjection(def)` bound over a table of the hook's own making. QoL has no projection, so it has no hook. |
| `Pagle_Hunts`, `Pagle_TackleBoard` | `CoinsEarned(state)` | the lifetime Coins earned, as the Module reports them (SHOP-R2) |
| `Pagle_Ledger` | `CoinsEarned(state, total)` | the lifetime Coins earned, as the Ledger reports them (SHOP-R2): the state's and those of the levels the climb's Activity XP adds (LED-R38) |
| `Pagle_Hunts`, `Pagle_TackleBoard` | `ActivityXPEarned(state)` | the lifetime Activity XP earned, as the Module reports it (AXP-R2, AXP-R9): a whole number, 0 or more. Their sum, keyed by `def.name`, is the Ledger's `total`. |
| `Pagle_Ledger` | `Measures(state, total)` | `{ anglerLevel = { prestige, level, xp }, ledgerCompletion = { percent, done, total }, speciesCaught, legendsCaught }`: the climb's level and XP, its Activity XP included (LED-R30–R32, LED-R37), LED-R70's completion, and the Species and distinct Legends caught, removed ones left out (LED-R71, LED-R63) |
| `Pagle_Ledger` | `MeasureRises(state)` | `{ ledgerCompletion, speciesCaught, legendsCaught }`: for each of those measures, by `Measures`' keys, the entry `time` of the record whose apply last made it greater than it was just before (Ledger completion by its percentage), nil when it never rose. That is what reading `Measures` after every record gives, kept by the fold (LED-R158) since `LEDGER_RULES_VERSION` 9. The Angler Level isn't in it, because Hunts and Tackle Board records raise it through Activity XP. |
| `Pagle_Ledger` | `FirstComplete(state)` | `{ seq, char, time }` of the record after whose apply Ledger completion first stood at 100% (`done == total`), from the entry: its `seq`, its `char` (the index into the log's characters) and its `time`; nil while it never has. Kept once set, even when completion falls below 100 later and rises back (LED-R158, since `LEDGER_RULES_VERSION` 9). It is a hook of its own beside `MeasureRises`, so a pin without it shows as a missing function, never as a nil that could mean "never complete". |
| `Pagle_Ledger` | `AnglerLevel(state, total)` | `Measures`' `anglerLevel`, `{ prestige, level, xp }`, its Activity XP counted from `total` (LED-R37), without working out Ledger completion, so it is cheap to read after every record (LED-R159) |
| `Pagle_Ledger` | `EarnedTitles(state, total)` | the title keys the state earns, in LED-R75's order, without the celebrated set's (LED-R76, LOG-R77); the level titles count the climb's Activity XP (LED-R37) |
| `Pagle_Ledger` | `AutomaticTitle(state, total)` | the automatic title's key (LED-R77), or nil with none earned |
| `Pagle_Ledger` | `ZonesMastered(state)` | the charted zones at computed rank Master (LED-R50, LED-R71) |
| `Pagle_Ledger` | `LifetimeCatches(state)` | lifetime Catches (LED-R42) |
| `Pagle_Ledger` | `LegendList()` | the release's Legends for Region firsts (PRJ-R15): the item IDs LED-R63's "x of N" counts for an Angler with no Catches, listed and not removed (LED-R11, LED-R12), ascending. The driver calls it after `BindProjections`. |
| `Pagle_Hunts` | `EventPool()` | the release's Hunt Event pool (DATA-R98, HNT-R140): every pool event, retired ones included, in event-ID order, each a plain `{ id, tags, skill, band, rotation, retired }` (`skill` is `{ low, high }`, `band` HNT-R156's, `retired` a server time or nil). The driver calls it after `BindProjections`, which builds the pool. |
| `Pagle_Ledger` | `PickedTitle(record)` | for a Ledger Module record: nil when it isn't the title record, false when it picks automatic, else the picked title key. The title record (#76 item 2) has kind `title` and the key as its payload, `""` for automatic (LED-R77); the Ledger appends it whenever the title "Signed as" picks isn't the one it last logged (LED-R157). The latest by entry time is the picked title. |
| `Pagle_Ledger` | `EquippedCrest(record)` | for a Ledger Module record: nil when it isn't the crest record, false when it equips Plain, else the equipped crest's good ID (`ledger.crest.<key>`, `core.crest.fish.<speciesID>`, or a crest bought in the Curio Shop). The crest record (#76 item 19) has kind `crest` and the good ID as its payload, `""` for Plain; the Ledger appends it whenever the crest its bookplate pins isn't the latest record's (LED-R156). The latest by entry time is the equipped crest. |
| `Pagle_Ledger`, `Pagle_Stats`, `Pagle_Hunts`, `Pagle_TackleBoard` | `JournalValues(state, sessionRows)` | the Angler page's Journal values the Module holds, keyed as pagle-backend's angler-page.md › Journal values; no key comes from two Modules. The Ledger's is `JournalValues(state, sessionRows, total)`, whose `total` its `level` and the level titles in `titles` count (LED-R37). The Ledger: `level`, `parts`, `titles`, `nextCatchMilestone`, `skillMilestones`, `characters` (from `Pagle.GetAngler().skill`), `zones`, `species`, `legends`, `trophies`, and `xp` (`{ ledger }`, its own XP all told, without Activity XP), `varieties` (every Species with varieties by ID, `{ species, caught }`, each caught one `{ id, position, rarity, first }`) and `crests` (the earned zone crests in the zone crest table's order, then the fish crests by Species ID, each `{ id, kind, zone \| species, earnedAt }`, zone crests by computed rank only) (LED-R155). Stats: `stats`, `sessions` (newest first, at most `sessionRows` of them) and `odds` (every zone fished, most Casts first, its place spread's rows read on STA-R41's side with the live skill unknown, numbers as `nice()` rounds them, STA-R44). Hunts: `hunts` and `sets` at `GetServerTime()`, the fold's time, and `ladder` (the Pagle Wagers ladder's marks in step order, each `{ step, earned }`, HNT-R178). The Tackle Board: `flies`. A nullable field is nil. |

## UI

None of its own. The only visible output is the optional unsaved-Casts chat line (LOG-R86), the dev-log chat line (LOG-R18), and the "updating" state each Module shows while its projection catches up (LOG-R74).

## Settings

| Option | Values | Default |
|---|---|---|
| Remind me to `/reload` when Casts are unsaved (`profile.reloadReminder`) | on/off | off |
| Length unit (`profile.lengthUnit`) | cm / in | in on region 1, else cm (LOG-R69) |

Both sit on the Settings root, in its Saving and Units sections (CORE-R40, SET-R10).

## Tunables

| Name | Value | Rules |
|---|---|---|
| Grace after the channel stops | 2 s | LOG-R6, LOG-R7 |
| Module record payload limit | 200 bytes | LOG-R40 |
| Session gap (`Pagle.SESSION_GAP`) | 300 s | LOG-R60–R64, LOG-R98 |
| `Pagle.SESSION_RULES_VERSION` | 2 | LOG-R61 |
| Synchronous catch-up limit | 500 entries | LOG-R71 |
| Catch-up and rebuild time budget per frame | 4 ms | LOG-R71, LOG-R72 |
| Runtime area index range | ids 1–40,000 | LOG-R23 |
| Lure poll | 5 s | LOG-R47 |
| Calendar poll | 60 s | LOG-R47 |
| `NextWindow` horizon | 400 days | LOG-R50 |
| Diagnostics: hover window before the channel | 60 s | LOG-R81 |
| Diagnostics: texts per Cast | 3 | LOG-R81 |
| Diagnostics: buffer size | 500 | LOG-R81 |
| Unsaved-Casts reminder step | 50 Casts | LOG-R86 |
| Realm UTC offset rounding | 15 min | LOG-R49 |
| A Legend's size multipliers of the typical length at each band edge (the ends frozen) | 0.55 / 0.75 / 1.10 / 1.30 / 1.55 / 1.80 | LOG-R67 |
| `Pagle.SIZE_RULES_VERSION` before 1.0 | 2 | LOG-R68 |

These are not tunables: they are frozen (LOG-R68, ADR 0014). The hash; the skill reach's 300 and the experience reach's 1,000, its square root and the place's exponent 3; the band edges as places in the full range (0.16 / 0.44 / 0.60 / 0.80); the full range's ends (0.55× and 1.80× the typical length); a Legend's cut points (0.15 / 0.70 / 0.93 / 0.995).

## Edge cases

- **LOG-R90 Module disabled, then enabled again.** Core keeps recording. The Module's projection catches up from its own `lastSeq` in `"replay"` mode (LOG-R71) and gets `info.replayed > 0` in `done`, where it raises a Write-up for anything that history earned. Nothing pops up. ADR 0004's "rebuilds from scratch" means it *can* be rebuilt from the log; a re-enabled Module catches up instead.
- **LOG-R91 Projection rebuild.** LOG-R72–R77: chunked, after login, up to the log's length at the start, with new entries queued behind it and the celebrated set untouched.
- **LOG-R92 First build over existing history.** LOG-R76: `info.firstBuild` is true only if at least one Cast was applied, so a fresh install doesn't get an empty Write-up.
- **LOG-R93 In combat.** Recording continues: a loot window that opens as combat starts is still recorded, and a channel cut by combat is interrupted (LOG-R7). Secret snapshot values are stored as the [Entry formats](#entry-formats) say (empty or `0`); secret calendar reads count as no events (LOG-R46). Catch-up and rebuild chunks keep running.
- **LOG-R94 Crash mid-Session.** LOG-R85: the Casts since the last save are lost, and so is any `lastEndedSession` update made after it, so a Session ended live but not saved is ended again at the next login (LOG-R63).
- **LOG-R95 Daily or weekly reset.** Nothing in this file depends on it. A Session that crosses realm midnight stays one Session.
- **LOG-R96 Uncharted or unconfirmed Catch.** An Uncharted item is recorded like any item (LOG-R8); `Pagle.GetItem` returns `nil` for it until a release classifies it, and the new content fingerprint then rebuilds every projection (LOG-R72), which credits it retroactively; if it is classified as a Species, its records gain a Simulated Size from then on (LOG-R65), the same one it would have had live. Unconfirmed catalogue facts carry `confirmed = false` and are recorded identically. Item `0` (a secret ID) is never credited.
- **LOG-R97 Two machines, one WoW account.** Each `PagleLog` is local, so two PCs keep two diverging logs with different `logId`s. Merging them is out of scope; entry IDs are unique, so a future backend can.
