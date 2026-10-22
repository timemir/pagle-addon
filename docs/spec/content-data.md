# Content data

> Status: Done · Milestones: M0 (licence and `NOTICE`), M1 (generator skeleton, the baseline extraction, the AreaTable slice, aliases, spell, aura and event lists), M2 (pipeline v1: every layer, items, catch lists, windows, `confirmed`, the content fingerprint, the DB2 watch), M3 (Field report intake, the Ledger's lore check, `VOICE.md`), M4 (typical lengths, Core's and the Ledger's title lore), M5 (the Hunt list, its lock, Hunts lore), M6 (Stats lore), M7 (Tackle Board lore), the varieties release (fish varieties, their lock and lore, [#338](https://github.com/timemir/wow-fish/issues/338)), M9 (the first lock at 1.0, build re-verification) · Sources: [Define the content data pipeline](https://github.com/timemir/wow-fish/issues/19#issuecomment-6113646946), [Where can Forever fishing content data come from?](https://github.com/timemir/wow-fish/issues/5#issuecomment-6109765263), [How can Pagle identify items and places independent of client language?](https://github.com/timemir/wow-fish/issues/20#issuecomment-6110081122), [Design the /pagle report format and issue form](https://github.com/timemir/wow-fish/issues/26#issuecomment-6124884698), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Design Hunts and the Now/Soon board](https://github.com/timemir/wow-fish/issues/14#issuecomment-6113353568), [Design the Ledger progression model](https://github.com/timemir/wow-fish/issues/11#issuecomment-6112531009), [Design Stats: session stats, honest odds and dry spells](https://github.com/timemir/wow-fish/issues/21#issuecomment-6113657288), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372), [Beta probe: which fishing signals can the Forever client see?](https://github.com/timemir/wow-fish/issues/7#issuecomment-6110508010), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); the varieties kit and the dev's grilling of it ([core/varieties.md](core/varieties.md)); ADR 0001, 0003, 0004, 0005, 0006. Research: `docs/research/forever-content-data.md`, `docs/research/localized-identity.md`

This file covers how Pagle's **content data** is sourced, checked, generated and kept current: the source layers in `data/`, the Python generator, the Lua it emits into Core (the catalogue), Pagle_Hunts (the Hunt list) and every addon (lore), the `confirmed` rules, the content fingerprint, and the path from a pasted **Field report** to `data/observed/`. How Core reads the catalogue at runtime is in [core/catch-log.md](core/catch-log.md#the-content-catalogue) (LOG-R55–R57); the in-game side of the Field report is in [core/field-report.md](core/field-report.md).

Terms are used as `CONTEXT.md` defines them. "The catalogue" is what the generator emits into Core; "the Hunt list" is what it emits into Pagle_Hunts.

## Purpose and boundary

**Owns:**
- the layers in `data/` and who may edit each
- the generator (`scripts/generate-data.py` and its Python package), its checks and its outputs
- every value in the catalogue, the Hunt list and the generated lore files, and their exact Lua shape
- the `confirmed` rules, the two-reporter rule and the content fingerprint
- the Hunt definition format, `data/hunts/released.lock` and the Hunt list fingerprint
- the lore pipeline: `data/lore/`, the key grammar, the checks and the length limits
- Field report intake: the issue form, the shared parser, the triage Action and the importer
- the DB2 watch Action, the licence and `NOTICE`

**Doesn't own:**
- the runtime accessors over the catalogue, the condition evaluator and the area index (Core, `core/catch-log.md`)
- what a Field report contains and its text format (Core, `core/field-report.md`; this file only accepts it)
- what any Module does with the data: which items count toward what, how Hunts complete, which lore keys a Module needs (each Module's spec)
- the meaning of each Hunt field and the v1 Hunt list (`hunts.md`); this file fixes the file format and the checks

**Uses from Core:** the catalogue contract (LOG-R55, LOG-R56), the condition spec (LOG-R48), the `PAGLE-REPORT 1` format and reporter key (REP-R20–R36), `ns.L` (CORE-R8) and the TOC rules (CORE-R2).

## Rules

### Sources and licence

- **DATA-R1** The whole repo is licensed **GPL-3.0-or-later** (ADR 0006): a `LICENSE` file at the root holds the GPLv3 text. A `NOTICE` file credits VMaNGOS (with the baseline snapshot of DATA-R9) and states that game IDs and names belong to Blizzard Entertainment.
- **DATA-R2** A where/when fact (which item bites in which area, a window, a skill base, a removal) enters `data/` only from the VMaNGOS baseline or from an in-game observation on a Forever build (`data/observed/`). Identity facts (which items, areas and spells exist, item class and quality, area parents) come only from the Forever client's DB2 tables. Wowhead, foreverdb and other fan sites are **leads only**: reading them to learn where to look is fine, copying a fact from them is not.
- **DATA-R3** Everything Pagle ships is IDs, numbers and Pagle's own text. No item, area, spell or pool name from the game ships, in any locale; names and icons resolve at runtime (LOG-R56). Item quality ships as a number on the item record (DATA-R77), so Modules that count by quality rebuild the same way every time. The source layers may keep enUS names for review; the generator never emits them.
- **DATA-R4** No drop rates ship. The baseline's chances stay in `data/baseline/` and are never emitted; Your odds come only from the Angler's own Casts.
- **DATA-R5** Data ships only inside normal addon releases, in Core and the Modules; there is no separate data addon. A data fix is a patch release.
- **DATA-R6** Every generated file starts with a comment naming the generator and the source layers, saying it must not be edited by hand, and that it is GPL-3.0-or-later and contains VMaNGOS-derived data.

### The layers

- **DATA-R8** The generator reads six source directories under `data/`. Four are content layers, merged in this order; for any one fact, **a later layer wins**, and the fact's provenance is the layer that won (kept in the sources, never shipped):

  | Order | Layer | Holds | Edited by |
  |---|---|---|---|
  | 1 | `data/baseline/` | VMaNGOS: area loot, reference loot, pool loot and pool spawn events, zone skill bases, the day/night, season and Extravaganza events | nobody: extracted once, frozen (DATA-R9) |
  | 2 | `data/forever/` | hand overrides and additions: categories, Species, trophy families and weights, Legend and Noise flags, removals, typical lengths, area edits and gates, aliases, windows, the event, aura and fishing-spell lists, pool types | by hand, reviewed as PR diffs |
  | 3 | `data/db2/` | the Forever client's DB2 slice: items (class, subclass, quality) and the AreaTable | only by `scripts/update-db2.py` (DATA-R12) |
  | 4 | `data/observed/` | what was seen in-game: imported Field reports and the dev's own facts | only by `scripts/import-field-report.py`, plus the dev's hand edits to `dev.toml` and `rejected` marks (DATA-R50) |

  The other two are not content layers: `data/hunts/` (the Hunt definitions, DATA-R85) and `data/lore/` (lore, DATA-R100). `data/checks.toml` switches milestone-gated checks on (DATA-R66).
- **DATA-R9** `data/baseline/` is extracted once, in M1, from the VMaNGOS `db_latest` snapshot of 2026-09-28 by `scripts/extract-baseline.py <dump>`, kept for audit. Where VMaNGOS rows carry a patch range, only rows valid for the baseline patch (Tunables) are extracted. It holds these CSV files (header row, one row per line) and `source.toml` with the snapshot tag (`tag`), its date (`date`), the dump it was extracted from (its release asset URL `url` and that file's SHA-256 `dumpSha256`, which the extractor checks before reading it) and the SHA-256 of each CSV (`[sha256]`, keyed by file name; keys under [Data](#other-files)). The dump itself is not committed; the dev's audit archive keeps it:

  | File | Columns | From |
  |---|---|---|
  | `area_loot.csv` | `area`, `item`, `chance`, `ref`, `event`, `condition` | `fishing_loot_template`: `ref` is the reference table ID when the row is a reference (then `item` is empty); `event` and `condition` as below |
  | `reference_loot.csv` | `ref`, `item`, `chance` | `reference_loot_template`, every table `area_loot.csv` or `pool_loot.csv` references, flattened through nested references |
  | `pools.csv` | `entry`, `name`, `event` | `gameobject_template` rows of type 25 (fishing pools); `event` is the `game_event_gameobject` event its spawns belong to, if any |
  | `pool_loot.csv` | `entry`, `item`, `chance`, `ref` | `gameobject_loot_template` for those pool entries; as in `area_loot.csv`, a reference row has `ref` and no `item` |
  | `skill.csv` | `area`, `skillBase` | `skill_fishing_base_level` |
  | `events.csv` | `event`, `start`, `occurrence`, `length`, `description` | `game_event` rows 14, 15, 40, 45, 46, 47, 48 (`start` as `YYYY-MM-DD HH:MM`, `occurrence` and `length` in minutes) |

  The generator fails if any CSV's hash differs from `source.toml`: the baseline is never hand-edited, and VMaNGOS errors are fixed in `data/forever/`.

  A loot row's condition is extracted as `event = E` when it is exactly "game event E is active" for one of the events in `events.csv`. Any other condition, compound or negated, leaves `event` empty and puts the condition's text in `condition`; the generator treats such a row as ungated and prints it as a warning, so the dev decides its gate in `areas.toml`.
- **DATA-R10** `data/forever/` is TOML, one file per table: `items.toml`, `species.toml`, `families.toml`, `areas.toml`, `aliases.toml`, `windows.toml`, `events.toml`, `lists.toml`, `pools.toml`. The keys of each are under [Data](#data). A `why` string (the evidence, an issue number, or the VMaNGOS error it fixes) is required on every entry of `areas.toml`, `aliases.toml`, `windows.toml` and `pools.toml`, and on an `items.toml` entry that sets `removed`, `category = "uncharted"` or `noise`. The generator fails on one without it.
- **DATA-R11** `data/db2/` holds `build.toml` (`build`, the build number; `version`, the version string; `products`, the wago.tools products searched, DATA-R128), `items.csv` (ID, ClassID, SubclassID, Quality, enUS name) for every item in the **item universe** (DATA-R15), and `areas.csv` (ID, ParentAreaID, ContinentID, enUS name) for every AreaTable row. It describes exactly one Forever build; history is git's.
- **DATA-R12** `scripts/update-db2.py <build>` downloads the DB2 CSVs for that build from wago.tools (`https://wago.tools/db2/<Table>/csv?build=<build>`) and rewrites `data/db2/`: `items.csv` from `ItemSparse` (ID, enUS name, quality) joined with `Item` (ClassID, SubclassID), `areas.csv` from `AreaTable`. It is run by hand, in a PR, after a DB2 watch issue (DATA-R128); data edits that follow from the diff are made by hand.
- **DATA-R13** A fact in no layer is unknown. Where/when facts never come from the DB2 layer. Identity facts never come from the baseline: they come from the DB2 layer, or, for an item DB2 lacks, from `items.toml` (DATA-R24).

### Items

- **DATA-R15** The **item universe** is every item ID that appears in the baseline's area, reference or pool loot, in any file under `data/forever/` (items, catch edits, pool edits), in a fixed Hunt class (DATA-R90), in a dev fact, or in a non-rejected `I` row in `data/observed/`. Every item in it either ships in the catalogue or is deliberately deferred (`category = "uncharted"`, DATA-R18). An item outside the universe is Uncharted at runtime.
- **DATA-R16** An item is **Noise by rule** when it is reachable in the baseline only through reference loot tables, or when its DB2 ClassID is one of the Noise classes (Tunables). `items.toml` may set `noise = true` or `noise = false` to override the rule either way. A Noise item ships as `{ category = "other", noise = true, legend = false, removed = <as set>, pool = false }`. `items.toml` may still write `category = "other"` for it. The generator fails if a Noise item is given any other category or `legend = true`; to count it as something, set `noise = false`.
- **DATA-R17** Every item in the universe that isn't Noise must have a `category` in `items.toml`: `fish`, `questFish`, `trophy`, `container`, `treasure`, `junk` or `other`. **The generator fails** on any non-Noise item without one, listing them. A thing fished up for a quest that isn't a fish is `junk`, not `questFish`: Gaffer Jack (6717) and Electropeller (6718) are a lost gadget's parts, so they are junk, with a Junk Museum plaque each and no Species, typical length or varieties (core/varieties.md › Data).
- **DATA-R18** `category = "uncharted"` keeps a known item out of the catalogue on purpose, so it stays Uncharted in-game (for example, a new item from a Field report the dev can't classify yet). It needs a `why`. It never ships: it leaves every catch list and pool list, and the generator fails if a fixed Hunt class names it.
- **DATA-R19** A non-Noise `fish` or `questFish` item is a **Species item**. Its `species` is its own item ID unless `items.toml` sets `species = <itemID>` to fold it into another Species item's Species; the target must be a Species item whose own `species` is itself. The **Species ID** is that representative item's ID.
- **DATA-R20** Every Species carries a **typical length**: `species.toml` sets `[species.<speciesID>] typicalLength` in whole millimetres, at least 1, emitted on every item of the Species as `typicalLength` (LOG-R55, LOG-R67). While the `typicalLength` check is on (DATA-R66) the generator fails if any Species, removed ones included, lacks one; before that, a Species without one ships without the field. A typical length is part of the catalogue, so changing one changes `CONTENT_FINGERPRINT` (DATA-R70).
- **DATA-R21** A `trophy` item must have a `family` and a `weight`. `family` is an integer family ID declared in `families.toml`; family IDs are never reused. `weight` is a whole number of pounds, taken from the item's enUS DB2 name by the weight pattern (Tunables) unless `items.toml` sets it; the generator fails if neither gives one. A family's label is lore (`family.<id>.name`, DATA-R103), never in `data/forever/`.
- **DATA-R22** `legend = true` in `items.toml` makes an item a Legend. The first list is the three Extravaganza rares (Keefer's Angelfish, Dezian Queenfish, Brownell's Blue Striped Racer); Nat Pagle's quest fish join only if quest 6607 is confirmed at launch re-verification, and Fishing Hut rare catches once observed.
- **DATA-R23** `removed = true` (with `why` naming the proof, and `removedFrom`, the first build it is proven gone on) marks an item **proven gone** from Forever. Absence from DB2 is not proof: the client streams item records. A removed item keeps its item record (`removed = true`) and its lore, and leaves every area catch list and pool list. The generator fails if a non-rejected observation of a removed item exists on a build at or above `removedFrom`, so the dev either un-removes it or rejects the row; observations from earlier builds are fine.
- **DATA-R24** For an item missing from `data/db2/items.csv`, `items.toml` may give `class` and `quality`; DB2 wins as soon as it has the item. An item with no known quality is in no quality class (DATA-R91).

### Areas and catch lists

- **DATA-R25** The catalogue's **areas** are every row of `data/db2/areas.csv`: `parent` (`0` for a zone), `continent` (ContinentID). Areas are keyed by AreaTable ID; the baseline's IDs map onto Forever's 1:1. The catalogue ships no area names; Core builds its name index at runtime (LOG-R23).
- **DATA-R26** An area's **catch list** is built per area (zone or subzone), never inherited:
  1. the baseline's area-loot items for that area, items from its referenced tables included, Noise left out (so a reference item with `noise = false` is in)
  2. then `areas.toml` edits: `clearBaseline = true` empties step 1 for the area; a `[[catch]]` with `op = "add"` adds the item, or, if it is already listed, keeps it and sets its gate when `gate` is given; `op = "drop"` removes it and takes no `gate`
  3. then observed pairs (DATA-R47), which win over a `drop`
  4. then removed, Noise and `uncharted` items leave the list
  
  Entries are sorted by item ID; an item appears at most once per area. The Ledger takes a zone's full list as the union of the zone's and its subzones' lists (`Pagle.GetZoneCatches`).
- **DATA-R27** The VMaNGOS errors known today are fixed in step 2: Elwynn Forest's Thieves Camp (area 53) and Durotar's Echo Isles carry other zones' tables, and both get `clearBaseline = true`.
- **DATA-R28** Pool-only catches join an area's list only through `areas.toml` or observation. The v1 `areas.toml` adds the four Extravaganza fish (Speckled Tastyfish and the three rares) to Stranglethorn Vale (area 33), gated by `event.301`.
- **DATA-R29** Each catch entry may carry a **gate**: exactly one window ID (DATA-R35). The baseline gives a gate when the item's area-loot rows for that area all have `event`s that map to the same window (DATA-R36); if any of its rows there has no `event`, it is ungated; if they map to different windows, the generator fails until an `areas.toml` `add` for that item sets its gate. `areas.toml` sets one with `gate = "<windowID>"` on an `add`, or removes one with `gate = "none"`. An observed pair takes a gate only as DATA-R47 says. The catalogue emits the window ID as the entry's `window` and the window's condition spec as its `gate` (LOG-R55).
- **DATA-R30** A zone's **skill base** comes from the baseline's `skill.csv`, overridden by `[[area]] skillBase` in `areas.toml`. Subzones have none of their own unless `areas.toml` sets one. Values may be negative. No no-junk skill ships: consumers derive it from `skillBase` (Stats does).
- **DATA-R31** An alias source (DATA-R32) ships with `hasData = false` and no catches; Core never stores it in a Cast (LOG-R22 maps it to its target). `hasData` is true for a zone when the zone or any of its subzones has a non-empty catch list; a subzone takes its zone's value. The four new Forever zones (Riverglades, Shen'dralas, Gilneas, Mount Hyjal) therefore ship with `hasData = false` until observations list a catch there.
- **DATA-R32** An **alias** maps an area on another map to the baseline fishing area it stands for (Forever's map 2940 duplicates, e.g. 16521 → 18). `scripts/generate-data.py --propose-aliases` prints candidates: an area with no catch list whose enUS name and parent's enUS name equal a baseline fishing area's, on a different ContinentID. A proposal takes effect only when committed to `aliases.toml`. The generator fails if an alias's target has no baseline catch list, its source has a catch list of its own, a target is itself an alias source, or source equals target.
- **DATA-R33** An area seen in `data/observed/` but missing from `data/db2/areas.csv` is kept in the sources and left out of the catalogue; the generator prints it as a warning ("update the DB2 slice").
- **DATA-R34** The generator maps every area ID in `data/observed/` through the alias table before using it, so a report from a client with an older catalogue lands on the baseline area, never on an alias source.

### Windows, events, auras and fishing spells

- **DATA-R35** A **window** is a named condition spec (LOG-R48) using only `time`, `season` and `events`. The window IDs are `day`, `night`, `spring`, `summer`, `autumn`, `winter`, and `event.<eventID>` for every event in the event list that has a weekly rule. The six named windows come from the baseline seeds and `windows.toml` (DATA-R36); the `event.<eventID>` windows are made by the generator from the event list (DATA-R37) and are never written in `windows.toml`. The generator fails if any of the six is missing after the merge, if `windows.toml` defines any other ID, if a gate names an unknown ID, or if a spec is invalid under LOG-R48. Gates on auras are not modelled in 1.0; Casts under fishing auras reach the dev through `aura=` rows (REP-R20).
- **DATA-R36** The baseline seeds four windows from VMaNGOS's events: `day` from event 47, `night` from event 48, `summer` from event 45, `winter` from event 46. An event with `occurrence` 1440 is daily: starting at minute of day `M` and lasting `L` minutes, it becomes `time = {{ M, (M + L) % 1440 }}`. An event with `occurrence` 525600 is yearly: starting on month/day `S` and lasting `L` minutes, it becomes `season = {{ from = S, to = <the month/day of the minute before S + L, in a non-leap year> }}`, both days inclusive (LOG-R48). VMaNGOS's Extravaganza events (14, 15, 40) map to `event.301`, for area-loot rows and for pools whose `event` is one of them. `windows.toml` overrides any of these and defines `spring` and `autumn` (Tunables), which no baseline gate uses.
- **DATA-R37** `event.301`'s spec is `{ events = { 301 } }`. Every event window's spec is its event ID alone; the weekly rule only forecasts it (LOG-R50).
- **DATA-R38** `events.toml` is the **event list**: fishing-relevant calendar event IDs, each with an optional weekly rule `{ weekday (1 = Sunday), start (realm minute), duration (minutes) }`. The v1 list is the Extravaganza, 301, Sundays 14:00 for 120 minutes.
- **DATA-R39** `lists.toml` holds the **fishing-aura list** (seeded with the beta probe's 1280341 Rack, 1280342 Hut, 1265220 hat lure, 1299323 Master Angler!) and the **fishing-spell list** (the spell IDs whose channel is a fishing Cast, LOG-R2), seeded with the Classic rank spells 7620, 7731, 7732, 18248 and Forever's rank spells 1240948, 1240959, 1240970, 1240983. M1 dogfooding confirms which ID the channel reports and corrects the list; launch re-verification checks it again.
- **DATA-R40** The DB2 watch (DATA-R128) flags new spells and events that may belong on these lists; adding one is a hand edit.

### Pools

- **DATA-R43** `pools.toml` names each **pool type** with a stable string ID (`[%w_]+`), the GameObject entry IDs it groups (`entries`, the `entry` of `pools.csv`), and optional `add`/`drop` item lists. Its catches are the baseline's pool loot for those entries, then the edits, with Noise, removed and `uncharted` items left out, ascending. A pool type new in Forever lists its entries with no baseline loot and gets its catches from `add`: School of Whimsyfin is `entries = [572928]`, `add = [251524]`.
- **DATA-R44** The catalogue ships `poolType → catches` for display only (LOG-R56). No `poolEntryID → poolType` map ships: pools have no runtime ID. Localized pool text from Field reports is kept in `data/observed/pooltext.toml` (DATA-R118) for the tooling and for later use; none of it ships in 1.0.

### Observations and `confirmed`

- **DATA-R45** An **observation** is one of:
  - a **catch row**: a non-rejected `I` row of an imported Field report (item, area, build, auras, events, optional time bucket `t` and month `m`, count)
  - a **skill row**: a non-rejected `K` row (area, build, casts, away, optional `land` and `lost`)
  - a **dev fact**: a `[[fact]]` in `data/observed/dev.toml` asserting one catalogue fact on a build, with a `note` (DATA-R122). A `pair` fact counts exactly like a catch row from `dev` for that item and area, so it can also create an observed pair.
  
  `P` rows are kept (DATA-R118) but are not observations of any catalogue fact.
- **DATA-R46** Each observation has a **reporter**: its report's reporter key (REP-R36), except that every key listed in `dev.toml`'s `keys`, and every dev fact, count as one reporter, `dev`. Only observations on builds at or above the **minimum confirming build** (Tunables) count for confirming, for contradicting and for an observed pair joining a list (DATA-R47); observations from every build bring items into the universe (DATA-R15).
- **DATA-R47** A catch row evidences a **pair** (item, area) the way REP-R10 picks a catch entry: the entry for the item in the row's area's list if there is one, else in its zone's list. Both lists are taken after steps 1 and 2 of DATA-R26, so an item an `areas.toml` `drop` removed can come back as an observed pair. When neither list has the item, the item is known (ships, DATA-R15) and not Noise, the row is an **observed pair** at the row's area. An observed pair joins that area's catch list (DATA-R26 step 3) once rows from the required number of reporters (DATA-R49) exist for it, and joins it confirmed. It takes a gate only when at least one other area lists the item and every area that lists it carries the same gate; then that gate applies and is judged by DATA-R52. Otherwise it has no gate, and when the item is gated somewhere the generator prints a warning for the dev.
- **DATA-R48** A catch entry is **confirmed** when pair evidence for it comes from the required number of reporters. Nothing contradicts a pair: an item not being seen is not evidence.
- **DATA-R49** The **required reporters** for a fact is 1, or 2 for a **big fact**:
  - any pair or gate of a Legend
  - any pair of a **new Species**: a Species item absent from the baseline's loot
  - a **new window**: a gate (item, window) that the baseline never gives that item, either through its area-loot rows or through the `event` of a pool whose loot holds it (DATA-R36)
  
  The dev counts as one reporter (DATA-R46). This is the only place the two-reporter rule is enforced.
- **DATA-R50** A row in `data/observed/reports/` with `rejected = "<why>"` is ignored by the generator. The dev marks rows rejected by hand (a client bug, a known fluke); the importer keeps the mark when it updates the row (DATA-R121).
- **DATA-R51** A catch row is **inside** a window when every time-based field of the window holds for the whole of the row's span, **outside** when some field fails for the whole span, and neither otherwise. The span is the row's 15-minute bucket `[t, t+15)` for `time`, its realm month for `season`, and its `event=` list for `events` (no `event=` means no listed event was active). A row without `t` and `m` (its reporter's catalogue had no gate for it, or its realm time was unknown, REP-R20) is neither for `time` and `season` fields.
- **DATA-R52** A **gate** (item, window) is judged over every catch row of the item that evidences (by DATA-R47's mapping, so a subzone row can evidence its zone's entry) an entry carrying that gate:
  - **contradicted** when any reporter has an outside row
  - otherwise **confirmed** when inside rows come from the required reporters, or a dev fact confirms it
  
  A catch entry's `gateConfirmed` is true only when its gate is confirmed and not contradicted. A contradiction lasts until the data changes so that the row is no longer outside (the gate is fixed or removed) or the row is rejected; that is how "demoted until the data is fixed" works.
- **DATA-R53** A **window** is confirmed (`confirmed` on `GetWindowSpec`) when a dev fact confirms it, or when at least one gate on it is confirmed and none is contradicted. An event window takes its event's weekly-rule confirmation instead (DATA-R54).
- **DATA-R54** A **weekly rule** is confirmed when a dev fact confirms it (Field reports carry no weekday), and is contradicted, so unconfirmed, by any catch row with that event in its `event=` list whose bucket lies wholly outside the rule's daily span `[start, start + duration)`. A row without `t` can't contradict it.
- **DATA-R55** A skill row's area is the area whose skill base the reporter's Core used (REP-R21), and the row is judged against that area's skill base only. A **skill base** is **contradicted** when a skill row for that area has `land` below it, and otherwise **confirmed** when a skill row from at least one reporter has a `land` value, or a dev fact confirms it. A contradicted skill base ships unconfirmed until it is lowered to the evidence or the row is rejected. `casts`, `away` and `lost` are kept for the dev's review and play no part in confirmation.
- **DATA-R56** Nothing is confirmed by default: before any observation every `confirmed`, `gateConfirmed` and `skillBaseConfirmed` is false.
- **DATA-R57** `scripts/generate-data.py --min-build <n>` reports, without writing anything, which facts would lose confirmation if only builds ≥ `n` counted. Launch re-verification (M9) uses it to see which facts rest on beta builds only, and may then raise the minimum confirming build.

### The generator

- **DATA-R60** The generator is a typed Python 3 package under `scripts/pagle_data/`, tested with pytest and run from WSL. `scripts/generate-data.py` is its command line. With no flags it reads `data/` and rewrites every generated file (DATA-R75); `--check` writes nothing and fails if any generated file would change; `--propose-aliases`, `--min-build <n>`, `--explain <itemID|areaID>` (prints every layer's value for that fact and which won) and `--lock` (DATA-R95, DATA-R133) are the other modes.
- **DATA-R61** `scripts/check.sh` runs `scripts/generate-data.py --check` and the generator's pytest suite. A stale generated file fails the gate, so generated files are always committed together with the `data/` change that produced them.
- **DATA-R62** Output is deterministic: the same `data/` always gives byte-identical files. Map keys are written in ascending order (numbers numerically, strings by byte), lists in the order this file states, integers without decimals.
- **DATA-R63** The generator fails, writing nothing and listing every problem found, on:
  - a baseline hash mismatch (DATA-R9), a missing CSV or one `source.toml` doesn't list, or a `source.toml` key other than `tag`, `date`, `url`, `dumpSha256` and `[sha256]`
  - a non-Noise item with no category (DATA-R17), or a bad `species`, `family` or `weight` (DATA-R19, DATA-R21)
  - a missing typical length while that check is on (DATA-R20)
  - any varieties check (DATA-R132, DATA-R133), the varieties' lore cover once Core's lore check is on (DATA-R134), and a game name in variety or fish crest lore (DATA-R135)
  - an entry without a required `why` (DATA-R10)
  - an item with conflicting baseline gates (DATA-R29), or a Noise item with a category other than `other`, or a Legend flag (DATA-R16)
  - a missing or invalid window, or a gate naming an unknown one (DATA-R35)
  - a bad alias (DATA-R32)
  - an observation of a removed item (DATA-R23)
  - an unknown key or a wrong type in any TOML file under `data/`
  - any Hunt check (DATA-R92, DATA-R96), or any event check (DATA-R97, DATA-R99)
  - any lore check of a Module whose check is on (DATA-R107)
- **DATA-R64** Warnings (printed, not failing): baseline rows with a condition that isn't a single event (DATA-R9), observed areas missing from the slice (DATA-R33), observed pairs without a consistent gate (DATA-R47), and alias proposals not yet committed. Those proposals are one summary line with their count, "<n> uncommitted alias proposals; run scripts/generate-data.py --propose-aliases to list them", and nothing when there are none; `--propose-aliases` lists each in full (DATA-R32).
- **DATA-R65** The generator emits only items that ship (DATA-R15, DATA-R18), only gates by window, and nothing from `data/observed/` but the catalogue facts it implies.
- **DATA-R66** `data/checks.toml` switches milestone-gated checks on: `typicalLength = true` from M4 (with Simulated Size), and `lore = [<lore ID>, …]`, listing the addons whose lore check is on (DATA-R100, DATA-R107), and `eventPool = true` from the 1.0 event pool ([#306](https://github.com/timemir/wow-fish/issues/306)), the pool minimum (DATA-R99); left out, `eventPool` is off; and `varieties = true` from the varieties release, every sized, non-Legend Species needing its ten varieties (DATA-R132); left out, it is off. Before a switch is on, its check is skipped and the data is still emitted.

### The content fingerprint and releases

- **DATA-R70** `CONTENT_FINGERPRINT` is the first 16 lowercase hex characters of the SHA-256 of the catalogue's **canonical JSON**: the catalogue table without its `fingerprint` field, as Python's `json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)` writes it, encoded as UTF-8. Integer map keys become decimal strings. Fields that are lists (`catches`, pool catches, `fishingSpells`, `auras`, `tiers`, the lists inside a condition spec) are JSON arrays, even when empty; every other table is a JSON object, even when empty. A gate's shared window spec is written out in full wherever it is used. Every catalogue value counts, `confirmed` flags, typical lengths and item quality included; lore is not in the catalogue, so it never counts.
- **DATA-R71** A changed fingerprint makes every projection rebuild (LOG-R72). That is how Uncharted Catches are credited retroactively once a release classifies them (LOG-R96), and why nobody has to remember a version bump.
- **DATA-R72** The Hunt list has its own fingerprint, computed the same way over the Hunt list without its `fingerprint` and without lore (DATA-R94). Pagle_Hunts passes it as `extraFingerprint` (LOG-R70), so a Hunt list change rebuilds only Hunts.
- **DATA-R73** Before 1.0 the data changes freely, and `released.lock` and `varieties.lock` are empty (DATA-R95, DATA-R133). From 1.0, every tagged release ships whatever `data/` holds at the tag, with both locks updated in the same commit.

### What ships

- **DATA-R75** The generator writes:

  | File | Addon | Holds |
  |---|---|---|
  | `addons/Pagle/data/Catalogue.lua` | Core | the catalogue (DATA-R76) |
  | `addons/Pagle_Hunts/data/HuntList.lua` | Pagle_Hunts | the Hunt list (DATA-R93) |
  | `addons/Pagle_Hunts/data/EventList.lua` | Pagle_Hunts | the event list (DATA-R98) |
  | `addons/<Addon>/data/Lore.lua` | each addon with lore | its lore as `ns.L` entries (DATA-R104) |

  Each addon's TOC lists its generated files; `Lore.lua` comes after the file that creates `ns.L`.
- **DATA-R76** `Catalogue.lua` sets `ns.catalogue` to this table (shape under [Contracts](#contracts)): `fingerprint`; `items`; `areas`; `aliases`; `pools`; `windows`; `events`; `fishingSpells`; `auras`. Core's accessors (LOG-R55) read it; nothing else does.
- **DATA-R77** Each item record has exactly the fields `Pagle.GetItem` returns: `category`, `legend`, `noise`, `removed` and `pool` always, where `pool` is true when the item is in any pool type's catches (DATA-R43); `quality` when known (the DB2 quality, or `items.toml`'s under DATA-R24; 0 poor … 5 legendary); `species` and (when known, DATA-R20) `typicalLength` for Species items, and `varieties` (the Species' ten keys in order, DATA-R131) for the items of a Species that has them; `family` and `weight` for trophies. Booleans are written out, never left `nil`.
- **DATA-R78** Each area record has `parent`, `continent`, `hasData`, `skillBaseConfirmed` and `catches` always, and `skillBase` when it has one. Each catch entry is `{ itemID, confirmed }`, plus `window` (the window ID), `gate` and `gateConfirmed` when gated; `gate` refers to the shared spec table of its window (one Lua table per window, emitted once). `catches` is an empty table for an area without a list.
- **DATA-R79** Before M2 (LOG-R57) the catalogue holds only `fingerprint`, `areas` (with `parent`, `continent`, `hasData = false`, `skillBaseConfirmed = false`, empty `catches`), `aliases`, `events`, `fishingSpells` and `auras`; `items`, `pools` and `windows` are empty tables. The event list already carries the Extravaganza's weekly rule (DATA-R38), but no window exists yet, `event.301` included: the generator makes windows (DATA-R35) from M2.
- **DATA-R80** The catalogue is read-only at runtime and is not copied into SavedVariables.

### The Hunt list

- **DATA-R85** Hunt definitions live in `data/hunts/hunts.toml`: `[[set]]`, `[[class]]` and `[[hunt]]` tables, keys under [Data](#data). What each field means is `hunts.md`'s; this file fixes the format, the checks and the emitted shape. A Hunt's and a set's text (`name`, `title`, `note`) is lore that stays in this file (DATA-R105).
- **DATA-R86** A Hunt is **natural** or **imposed** (`kind`). A natural Hunt has a `species` target and a `window` (one window ID, DATA-R35), read from the catalogue at runtime, so correcting a window never changes the Hunt. An imposed Hunt has a `species` or `class` target and its own `conditions`: a condition spec (LOG-R48) written in the definition, never naming a window.
- **DATA-R87** `since` and the optional `retired` are dates (TOML `YYYY-MM-DD`), meaning 00:00 UTC on that day, emitted as server times. Before 1.0 every v1 Hunt's `since` is the pre-1.0 placeholder (Tunables), so dogfooding Casts count; the M9 checklist sets it to the real release day.
- **DATA-R88** `tiers` is a list of strictly ascending positive integers; the first is completion.
- **DATA-R89** `minBand` (optional, species targets only) is the lowest Simulated Size band (LOG-R67) that counts, 2 to 4. Monster (5) is never a target.
- **DATA-R90** A `[[class]]` defines a **fixed class**: `id = "fixed.<name>"` with `<name>` matching `[%w_]+`, and `members`, a list of item IDs that must all ship (e.g. `fixed.oddity` = Deviate Fish and Whimsyfin).
- **DATA-R91** The generator also defines the **generated classes**, computed over every catalogue item that isn't Noise, removed items included: `quality.uncommon` (quality 2 or more), `quality.rare` (3 or more) and `species.any` (every Species item). A generated class targeted by a released Hunt also keeps every member the lock records for it, whatever has changed since (a new Noise flag, a quality change), so it never loses one (ADR 0005). Members are emitted as item ID sets.
- **DATA-R92** The generator fails on a Hunt list where:
  - a Hunt or set ID doesn't match `[%w_]+`, a class ID breaks DATA-R90, an ID repeats among Hunts, sets or classes, or a Hunt names an unknown set or class
  - a `species` target isn't a Species item, or `minBand` breaks DATA-R89
  - a natural Hunt lacks a `window`, has `conditions`, or targets a class; an imposed Hunt lacks `conditions` or has a `window`
  - a `conditions` spec is invalid (LOG-R48), or names an aura or event not on the lists (DATA-R38, DATA-R39)
  - `tiers` breaks DATA-R88, or `retired` is before `since`
  - a natural Hunt that isn't retired fails **admission**: no catch entry of any item of its target Species, in any area, carries its `window` as gate (contradicted gates still count). So a Hunt whose gating is dropped from the data must be retired.
  - a Hunt that isn't retired fails the **rarity cap**: evaluate its time-based fields (the window's spec for a natural Hunt, `time`, `season` and `events` for an imposed one, events forecast from their weekly rules) at every 15-minute step of the rarity-cap span (Tunables), in realm time on the real calendar, ignoring every other field. It passes if it has `auras`, or is open at 1/7 or more of the steps, or its longest run of closed steps (not wrapping) is at most 7 days. An event without a weekly rule counts as never open.
- **DATA-R93** `HuntList.lua` sets `ns.huntList` to `{ fingerprint, sets, hunts, classes }`: sets as `{ id }` in file order; Hunts in file order, each with `id`, `set`, `kind`, `since`, `retired?`, `species?`, `class?`, `minBand?`, `window?`, `conditions?`, `tiers`; classes as `{ [classID] = { [itemID] = true } }`, generated and fixed. Retired Hunts stay in it forever.
- **DATA-R94** A Hunt's **hash** is the lowercase hex SHA-256 of the canonical JSON (DATA-R70) of its emitted record (DATA-R93: `since` as a server time) without `retired`; absent optional fields are left out. Lore is never in the record.
- **DATA-R95** `data/hunts/released.lock` (TOML) records `[hunt.<id>]` with `hash` and, if retired, `retired` (a date) for each released Hunt, and `[class."<classID>"]` with `members` (ascending item IDs) for each class targeted by a released Hunt. `scripts/generate-data.py --lock` rewrites it from the current data; it is run when a release is tagged, from 1.0 on, and never before (ADR 0005).
- **DATA-R96** The generator fails (ADR 0005) when, against the lock: a locked Hunt is missing (deleted instead of retired); its hash differs; a locked `retired` date changed or was removed; a locked fixed class lost a member (generated classes can't, DATA-R91). A fix ships as a new Hunt plus a `retired` date on the old one.

- **DATA-R97** **Hunt Events** (ADR 0012) live in `data/hunts/events/`, one file per event, `<event-id>.toml`, holding one `[event]` table and its `[[hunt]]` tables (keys under [Data](#data)). An event's `id` matches its file name and `[%w_]+`, never starting `p_` (kept for pushed events). Its `zones` are 1–2 zone areaIDs; its `skill` is `[low, high]`, the lowest and highest skill base among its zones (LOG-R55), worked out by the generator when left out; its **band** follows from `low` (`low` up to 150, `mid` 151–275, `high` above 275, Tunables) and is added to its tags as `low`, `mid` or `high`. `tags` come from `data/hunts/tags.toml`, a closed list: holidays (`hallows_end`, `winter_veil`, `lunar_festival`, `noblegarden`, `midsummer`, `harvest_festival`, `stv_extravaganza`), time (`night`, `day`, `dusk`), water (`coast`, `lake`, `river`, `pool`) and band (`low`, `mid`, `high`). `rotation` (default `true`) says whether the fallback rotation may pick it. An event's `name` and `note`, and each Hunt's `name`, are lore that stays in the file, as DATA-R105 does for `hunts.toml`, emitted as `event.<id>.name`, `event.<id>.note` and `hunt.<id>.name`.
- **DATA-R98** `addons/Pagle_Hunts/data/EventList.lua` sets `ns.eventList` to `{ fingerprint, events }`: events in event-ID order, each with `id`, `zones`, `tags` (as given, then the band unless given), `skill`, `band`, `rotation`, `retired?` (a server time, as DATA-R87's) and `hunts`, each Hunt in file order with `id`, `species?` or `class?`, `minBand?`, `conditions?` (its own, without the event's `areas`) and `tiers`. Its classes are `ns.huntList.classes` (DATA-R93), so `[[class]]` tables stay in `hunts.toml`. The fingerprint is computed as DATA-R72's over the event list without lore; Pagle_Hunts joins it with the Hunt list's for `extraFingerprint` (HNT-R136). Pagle_Hunts' TOC lists `EventList.lua` right after `HuntList.lua`. An event Hunt's hash (DATA-R94) is over its emitted record plus its event's `id` and `zones`, the canonical JSON of the record with `event` (the event's `id`) and `zones` added, and goes into `released.lock` under `[hunt.<id>]` like any Hunt; a locked event that is missing, or one of whose Hunts' hashes differs, fails the generator (DATA-R96). Removing an event from the pool is done by setting `rotation = false` and `retired = <date>` on its `[event]` (it then never runs again), never by deleting the file. *Decided while writing the spec (#289): how an event leaves the pool after 1.0.*
- **DATA-R99** **The event checks.** The generator fails on an event that:
  - breaks DATA-R97 (IDs, file name, zone count, an area that isn't a zone, a zone without a skill base when `skill` is left out, an unknown tag or a band tag other than its band, a `p_` prefix) or has fewer than 3 or more than 5 Hunts;
  - has a Hunt breaking DATA-R92's Hunt checks (targets, `minBand`, `tiers`, IDs), or with an `areas` condition of its own (the event's zones supply it);
  - has a Hunt that can't complete in its zones: a `species` target or every member of a `fixed.*` target not listed in any of the event's zones and their subzones, a `species.any` or quality class with no qualifying item listed there, or a time-based condition that keeps it closed for more than half of a 72-hour run (Tunables). That last is its longest closed stretch over a week of 15-minute steps, read as `MatchesConditions` reads them, wrapping across realm midnight and the week's end: its `time`, and its `events` forecast from their weekly rules (DATA-R38), an event without one never open; a run's dates aren't known, so `season` isn't read. DATA-R92's rarity cap doesn't apply to event Hunts. A retired event never runs again and never changes (ADR 0005), so, as a retired Hunt needs no admission, it is held to the other checks but not to completing in its zones;
  - has lore over DATA-R107's limits (`name` limit for event and Hunt names, no limit for the note), or missing names once the `hunts` lore check is on (DATA-R66);
  
  and the pool fails when a band has fewer rotating events than the minimum per band (Tunables, 8 at 1.0).
  
  `scripts/propose-events.py --zone <areaID> [--zone <areaID>] [--out <dir>]` drafts candidate event files from a zone (or two zones of one band) × its listed Species × the five Hunt shapes (Haul, Named fish, Big ones, Quality, Timed, HNT Data), with tiers suggested from the zones' loot shares so that, at the catch rate Tunable, tier 1 takes about 45 minutes, tier 2 about 2 hours and tier 3 about 4; it writes drafts outside `data/` and never commits. `scripts/check-event.py <file>` runs these checks on one event file or one pushed `huntEvent` item (as JSON) against the committed catalogue, so pagle-backend can check a `p_` definition before it pushes it (pagle-backend #2); it exits 0 when the event passes and prints each failure otherwise.

### Lore

- **DATA-R100** **Lore** lives in `data/lore/`: one TOML file per owning addon, named by its **lore ID**: `core.toml` (`addons/Pagle`), `ledger.toml` (`addons/Pagle_Ledger`), `hunts.toml` (`addons/Pagle_Hunts`: its goods' `huntgood` keys, HNT-R130), `tackleboard.toml` (`addons/Pagle_TackleBoard`), `stats.toml` (`addons/Pagle_Stats`). QoL has none. Also in `data/lore/`: `manifest.toml` (DATA-R106) and `VOICE.md` (DATA-R110). The one exception to one file per addon is the text of Hunts and Hunt sets, which stays beside their definitions in `data/hunts/hunts.toml` (DATA-R105); those `hunt` and `set` keys get DATA-R105's checks and are not listed in `manifest.toml`, so the orphan check doesn't apply to them. The generator emits both of Pagle_Hunts' sources into its one `Lore.lua`. The spec holds stable IDs and rules; display text lives only in these files.
- **DATA-R101** A lore **key** is `<kind>.<id>.<field>`: `kind` is lowercase letters, `field` is the last dot-separated segment, and `id` is everything between (good IDs contain dots). In TOML a key is a table per `<kind>.<id>` holding its fields, e.g. `[species.6362]` with `blurb` and `riddle`, or `[good."core.toaststyle.page"]` with `name` and `description`. Keys are never derived from English text.
- **DATA-R102** Each kind belongs to one addon, and a lore file holds only its addon's kinds. Each Module's spec lists the keys it needs.
- **DATA-R103** The kinds keyed by catalogue IDs, all the Ledger's:

  | Kind | ID | Fields | Needed for |
  |---|---|---|---|
  | `species` | Species ID | `blurb`, `riddle` | every Species, removed ones included |
  | `legend` | item ID | `blurb`, `title` | every Legend |
  | `sub` | item ID | `plaque` | every non-Noise `junk`, `container` and `treasure` item, removed ones included |
  | `family` | family ID | `name` | every family in `families.toml` |

  Every other kind (titles, bindings, flies, goods, shared lines) is keyed by an ID its Module's spec defines and lists in `manifest.toml`.
- **DATA-R104** The generator emits each addon's lore into `addons/<Addon>/data/Lore.lua` as plain assignments to `ns.L` by key (`L["species.6362.riddle"] = "…"`), enUS only, apart from the hand-written interface strings. A translation after 1.0 adds one table per addon. Lore is emitted whether or not its check is on.
- **DATA-R105** A Hunt's `name` and `note` and a set's `name`, `title` and `note` in `hunts.toml` are emitted into Pagle_Hunts' `Lore.lua` as `hunt.<id>.name`, `hunt.<id>.note`, `set.<id>.name`, `set.<id>.title`, `set.<id>.note`. They are left out of the Hunt hash and the Hunt list fingerprint, so a wording fix needs no new Hunt. The format always requires a Hunt's `name` and a set's `name` and `title` (an absent one fails as a wrong TOML shape, DATA-R63); `note` is optional. The Hunts lore check adds the length, newline and placeholder checks, and fails on an empty value.
- **DATA-R106** `manifest.toml` lists, per lore ID, each Module-defined kind with its required fields and the IDs that need them, for example `[ledger.title] fields = ["text"]`, `ids = [...]`. An ID entry may allow placeholders: `{ id = "<zone master title ID>", placeholders = ["zone"] }`, or a fish crest's `{ id = "core.crest.fish.<speciesID>", placeholders = ["fish"] }` (DATA-R134).
- **DATA-R107** For each lore ID in `data/checks.toml`'s `lore` list, the generator fails on:
  - **missing:** a needed key (DATA-R103, DATA-R106) with no text, or an empty one
  - **orphan:** text for an ID that doesn't exist or isn't that kind of thing (a `species` ID that isn't a Species, a `legend` that isn't a Legend, an ID not in the manifest), or a kind the file's addon doesn't own
  - **length:** a field over its limit (Tunables), counted in Unicode code points
  - **newline:** any field containing a line break
  - **placeholder:** any `{` or `}` except an allowed placeholder (`{zone}`, `{fish}`) in a key whose manifest entry allows it

  Whether or not a lore ID's check is on, the generator also fails on a **glyph**: a character in any lore text outside CORE-R9's set (ASCII, Latin-1, the en and em dashes, curly quotes, the bullet and the ellipsis), named by its code point, since the client's fonts draw it as a box.
  
  The checks turn on with the milestone that builds the screen: Ledger in M3, Core in M4, Hunts in M5, Stats in M6 (when it first registers its goods, STA-R88), Tackle Board in M7. The Ledger's title and binding IDs enter the manifest in M4 (LED-R162), so they are checked from then.
- **DATA-R108** `{zone}` is filled at runtime with the game's localized zone name. `{fish}`, from the varieties release, is filled with a Species' item name as the client resolves it, and only a fish crest's name holds it (VAR-R12, DATA-R134). They are the only placeholders.
- **DATA-R109** Lore never changes what anything counts for, is never in the content fingerprint, and Modules read only their own lore and Core's catalogue (ADR 0001).
- **DATA-R110** `data/lore/VOICE.md` is the voice guide: tone, the length limits, dos and don'ts and sample lines taken from the Journal prototype. The voice is an experienced angler's in-world field notes, light and dry; never parody, no real-world references or memes, no words put in Nat Pagle's mouth. Riddles hint at a kind of place or time ("dwarf country", "lazy rivers"), never an exact zone, hour or skill. Uncaught Legends share one line, with no per-Legend riddle.
- **DATA-R111** An agent drafts each lore batch from `VOICE.md` and the dev reviews it as a PR diff. One batch per Module, in its screen's milestone: M3 Ledger Species, Legends and Sub-collections with `VOICE.md`; M4 Core goods and Ledger titles and bindings; M5 Hunts; M6 Stats' tracker frames; M7 Tackle Board. After that, any PR that adds a Species or item (for example from a Field report) includes its lore. The working names (Timber, Ripple, Lantern Glow, Driftwood and the rest) were the first drafts; the dev signed the lore off for 1.0 in [#264](https://github.com/timemir/wow-fish/issues/264).
- **DATA-R112** The plain hint on an uncaught Journal page is not lore: the Ledger generates it at display time from the catalogue.

### Field report intake

- **DATA-R115** `.github/ISSUE_TEMPLATE/field-report.yml` is the issue form at the URL in REP-R46: title "Field report", labels `field-report` and `needs-triage`, and these fields:
  - `report`: a required textarea rendered as a code block, for one part of the paste
  - `notes`: "Anything you noticed?", optional
  - `public`: a required checkbox, "I understand this is posted publicly"
  
  Its description says that a report in several parts is filed as one issue per part.
- **DATA-R116** One **parser module** in `scripts/pagle_data/` reads the `PAGLE-REPORT` format exactly as REP-R30–R33 define it, and is the only parser: the triage Action, the importer and the generator all use it. Its pytest suite holds example reports, REP-R30's included. It fails a part on: a first line other than `PAGLE-REPORT 1`; a malformed header; a missing `END` (a truncated paste), or text after it; a row with missing, extra or non-integer fields; a known key given twice; a value out of its bounds (an ID, `count` or `casts` below 1, a `build` or `away` below 0, `m` outside 1–12); `t` without `m` or `m` without `t`; a `t` that isn't a 15-minute bucket's start; a `P` row whose text is unquoted or empty, whose locale isn't a client locale, or that lists an item twice; a bad quote escape; and two rows with the same key. These mirror what `data/observed/` reads (DATA-R121), so every part that parses can be imported. It ignores comments, unknown `key=value` keys and unknown row letters (REP-R31). Parts of one report share the header except `part` and are joined in order; a report with a part missing is incomplete.
- **DATA-R117** The **triage Action** (`.github/workflows/field-report-triage.yml`) runs when an issue labelled `field-report` is opened or edited. It parses the paste and posts one comment, edited in place on later runs (found by a hidden marker), with:
  - parse errors, if any; then it adds `needs-info`
  - for a multi-part report, which parts are present
  - Uncharted items, with their enUS names from the `ItemSparse` table of the build in `data/db2/build.toml`, downloaded from wago.tools by the Action, pairs this report would add or confirm, gates, windows and skill bases it would confirm or contradict, and new pool texts, computed by running the generator's `confirmed` rules with the report merged in, without writing
  - any earlier issue with the same reporter key but a different **report identity** (the header without `part`: addon, `data`, locale, reporter, part count), open or already imported per `data/observed/reports/`, which this paste supersedes. Open issues with the same identity are the report's other parts, and "which parts are present" counts across them.
  - "stale addon" when the header's `data` differs from the first 8 characters of the fingerprint in the default branch's `Catalogue.lua`
- **DATA-R118** `data/observed/pooltext.toml` maps (locale, hovered text) to a pool type ID, or to `bobber`, or to `other`; the dev keeps it by hand from `P` rows. The triage Action lists only texts not in it, so bobber text and known pool names drop out there (Core sends every text, REP-R22).
- **DATA-R119** `scripts/import-field-report.py <issue> [<issue> …]` fetches the issues with `gh`, takes the `report` field, parses it, and requires every part of the report. It then writes the rows into `data/observed/reports/<reporterKey>.toml` (DATA-R121), runs the generator, and prints what changed in the catalogue: new or confirmed pairs, gates, windows, weekly rules and skill bases; contradicted gates, weekly rules and skill bases, and each fact that is no longer confirmed because of one; and items now needing a category (which make the generator fail until categorised or deferred, DATA-R17, DATA-R18).
- **DATA-R120** The dev commits the observed file, any `data/forever/` and lore edits, and the regenerated files in one PR whose message closes the imported issues. A release then ships it, and the fingerprint change credits it retroactively (DATA-R71).
- **DATA-R121** A reporter's file keeps one row per row key: `I` by (item, area, build, auras, events, `t`, `m`), `K` by (area, build), `P` by (area, locale, text). An import **upserts**: a row in the new report replaces the stored row with the same key (keeping its `rejected` mark); stored rows the new report lacks are kept, because reports leave out what a release already confirmed (REP-R2) and the diagnostics buffer rolls over. Several reports in one import are upserted in ascending issue-number order, so a reporter's newer report wins. The file also records every imported issue number and the latest header (addon version, `data`, locale).
- **DATA-R122** `data/observed/dev.toml` holds `keys` (the reporter keys of the dev's own logs, which change whenever a pre-1.0 log is restarted, LOG-R18) and the dev's `[[fact]]` entries, each with `kind`, `build`, `note` and the IDs its kind needs: `pair` (`item`, `area`), `gate` (`item`, `window`: confirms that gate in every area), `window` (`window`), `weekly` (`event`), `skillBase` (`area`).
- **DATA-R123** Field reports go through GitHub only for 1.0. A report posted elsewhere is pasted into an issue by the dev and imported the same way.

### The DB2 watch

- **DATA-R128** The **DB2 watch** (`.github/workflows/db2-watch.yml`) runs weekly and on manual dispatch. It reads the wago.tools builds API (`https://wago.tools/api/builds`) for the products in `data/db2/build.toml` (seeded with `wow_classic_beta`, where Forever's beta builds sit; the dev updates the list by hand when the live product appears) and, when a build on the recorded build's version line (the major and minor of `build.toml`'s `version`, 1.60 today; a product may also list other games' builds, such as MoP Classic's 5.5.0 under `wow_classic_beta`) has a higher build number than the recorded one, downloads the newest such build's tables, diffs them against `data/db2/`, and opens one issue titled "Forever build <version>: DB2 changes" with labels `db2-diff` and `needs-triage`, unless an issue with that title exists.
- **DATA-R129** The diff lists: new items in the item universe or whose enUS name matches a watch keyword (Tunables); renamed items and class or quality changes in the universe; new areas, renamed areas, and areas whose parent or continent moved; new spells and calendar events whose enUS name matches a watch keyword. For what `data/db2/` doesn't keep (spells, events, and which items outside the universe are new), the watch downloads `SpellName`, `HolidayNames` and `ItemSparse` for both the recorded build and the new one. A keyword matches a whole word, ignoring case ("Pool" doesn't match "Whirlpool").
- **DATA-R130** The watch never edits `data/`. The dev refreshes the slice with `scripts/update-db2.py` (DATA-R12) and makes any follow-up edits by hand.

### Fish varieties

From the varieties release ([core/varieties.md](core/varieties.md), [#338](https://github.com/timemir/wow-fish/issues/338)).

- **DATA-R131** `data/forever/varieties.toml` holds `[varieties.<speciesID>] keys = [<ten keys>]` for each Species that has varieties: a sized Species (one with a typical length, DATA-R20) whose item isn't a Legend (VAR-R1). The order is frozen and sets each one's rarity (VAR-R2). A key is lowercase letters and digits joined by single hyphens, so a variety's ID `<speciesID>.<key>` is one lore ID. The generator emits the ten keys, in order, as `varieties` on every item of the Species, as it does the typical length (VAR-R4); they are part of the catalogue, so a change changes `CONTENT_FINGERPRINT` (DATA-R70). 37 Species at release.
- **DATA-R132** **The generator fails**, naming the Species, on an entry for anything that isn't a sized, non-Legend Species, an entry with other than ten keys, a key repeated within a Species or a key of the wrong shape; and, while the `varieties` check is on (DATA-R66), a sized, non-Legend Species with no entry, removed ones included (VAR-R5: a removed Species keeps its ten).
- **DATA-R133** `data/forever/varieties.lock` records the shipped keys, `[varieties.<speciesID>] keys = [...]` in varieties.toml's shape, by ascending Species ID. `scripts/generate-data.py --lock` rewrites it from `varieties.toml` together with `released.lock` (DATA-R95), when a release is tagged, from 1.0 on, and never before (DATA-R73); an absent or empty lock checks nothing. The generator fails when, against the lock, a locked Species' entry is gone, or a key at a locked position differs (renamed, moved or removed): a variety's key and position never change once shipped, while its name, description and art may (VAR-R5).
- **DATA-R134** Core's lore kind `variety` (`[variety."<speciesID>.<key>"]` in `core.toml`, fields `name` and `description`) and the fish crests, Core's goods `good."core.crest.fish.<speciesID>"` (VAR-R11, VAR-R12). With Core's lore check on, the generator fails unless `manifest.toml`'s `[core.variety]` lists exactly the variety IDs of `varieties.toml` and `[core.good]` a fish crest for exactly its Species, each allowing `{fish}`, which no other manifest entry allows. Every fish crest's `name` is the one pattern `"{fish} Crest"` (Core fills `{fish}` with the Species' item name at runtime), and no description holds `{fish}`. The variety and fish crest names, descriptions and keys are lore (DATA-R109): a renamed key before release is renamed in all three places.
- **DATA-R135** **No game name ships through a variety's or a fish crest's lore** (DATA-R3). Whether or not a lore check is on, the generator fails, naming the key and the name, on a variety's or fish crest's text that holds the enUS name of any area in `data/db2/areas.csv` (zones and subzones alike; whole words, with its capitals, so plain words like "mine shaft" pass) or of any Species item (its `items.csv` name and that name without a leading "Raw "; whole words, ignoring case). `{fish}` is left out of the match. A name made from part of a game name (a lake's first word, a fish's own word) isn't caught and is the lore review's to catch (DATA-R111).

## Data

### `data/forever/` keys

| File | Table | Keys |
|---|---|---|
| `items.toml` | `[item.<itemID>]` | `category` (optional for a Noise item), `species?`, `family?`, `weight?`, `legend?`, `noise?`, `removed?`, `removedFrom?` (with `removed`), `class?`, `quality?`, `why?` (required with `removed`, `category = "uncharted"` or `noise`) |
| `species.toml` | `[species.<speciesID>]` | `typicalLength` (mm) |
| `varieties.toml` | `[varieties.<speciesID>]` | `keys` (ten, frozen order) (DATA-R131) |
| `families.toml` | `[family.<n>]` | none (declares the ID) |
| `areas.toml` | `[[area]]` | `id`, `clearBaseline?`, `skillBase?`, `why` |
| `areas.toml` | `[[catch]]` | `area`, `item`, `op` (`add` / `drop`), `gate?` (window ID or `none`; `add` only), `why` |
| `aliases.toml` | `[[alias]]` | `from`, `to`, `why` |
| `windows.toml` | `[window.<id>]` | `time?` (`[[from, to], …]` realm minutes), `season?` (`[{ from = [month, day], to = [month, day] }, …]`, both inclusive), `events?` (`[id, …]`), `why` |
| `events.toml` | `[event.<eventID>]` | `weekday?`, `start?`, `duration?` (all three or none) |
| `lists.toml` | | `auras`, `fishingSpells` |
| `pools.toml` | `[pool.<poolType>]` | `entries`, `add?`, `drop?`, `why` |

### `data/hunts/hunts.toml` keys

| Table | Keys |
|---|---|
| `[[set]]` | `id`, `name`, `title`, `note?` |
| `[[class]]` | `id` (`fixed.<name>`), `members` |
| `[[hunt]]` | `id`, `set`, `kind` (`natural` / `imposed`), `since`, `retired?`, `species?` or `class?`, `minBand?`, `window?` (natural) or `conditions?` (imposed), `tiers`, `name`, `note?` |

### `data/hunts/events/<event-id>.toml` keys

| Table | Keys |
|---|---|
| `[event]` | `id`, `zones` (1–2 zone areaIDs), `tags` (DATA-R97), `skill?` (`[low, high]`), `rotation?` (default `true`), `retired?` (a date, DATA-R98), `name`, `note` |
| `[[hunt]]` | `id`, `species?` or `class?`, `minBand?`, `conditions?` (LOG-R48 fields except `areas`), `tiers`, `name` |

`data/hunts/tags.toml` holds one `[[tag]]` per tag: `id` and `kind` (`holiday`, `time`, `water`, `band`). A repeated ID, an unknown kind, or band tags other than exactly `low`, `mid` and `high` fail the generator (DATA-R97, DATA-R63). The generator reads every `*.toml` in `data/hunts/events/` and ignores anything else there (its README).

An imposed Hunt's `conditions` is an inline table with any of the LOG-R48 fields: `areas = [areaID, …]`, `time = [[from, to], …]` (realm minutes), `season = [{ from = [month, day], to = [month, day] }, …]`, `events = [eventID, …]`, `auras = [spellID, …]`, `lure = true` or `lure = [enchantID, …]`, `skill = { min = n }`. It is emitted as the same Lua condition spec.

### `data/observed/`

| File | Contents |
|---|---|
| `reports/<reporterKey>.toml` | `issues`, `header`, then `[[i]]`, `[[k]]` and `[[p]]` rows with their REP-R20–R22 fields and an optional `rejected` |
| `dev.toml` | `keys`, `[[fact]]` (DATA-R122) |
| `pooltext.toml` | `[[text]]` with `locale`, `text`, `pool` (pool type ID, `bobber` or `other`) |

### Other files

| File | Contents |
|---|---|
| `data/baseline/source.toml` | `tag` (the VMaNGOS snapshot tag, e.g. `"db_latest@4641790"`), `date` (`YYYY-MM-DD`), `url` (the dump's release asset URL), `dumpSha256` (the dump's SHA-256, lowercase hex), `[sha256]` with one `"<file>.csv" = "<lowercase hex>"` per CSV (DATA-R9) |
| `data/db2/build.toml` | `build` (integer), `version` (e.g. `"1.60.1"`), `products` (list of wago.tools product names, e.g. `["wow_classic_beta"]`) (DATA-R11, DATA-R128) |
| `data/checks.toml` | `typicalLength` (boolean), `lore` (list of lore IDs: `core`, `ledger`, `hunts`, `stats`, `tackleboard`), `eventPool?` and `varieties?` (booleans, off when left out) (DATA-R66) |
| `data/hunts/released.lock` | DATA-R95, DATA-R98 (event Hunts' hashes) |
| `data/forever/varieties.lock` | DATA-R133 |
| `data/hunts/tags.toml` | DATA-R97 |
| `data/lore/*.toml`, `manifest.toml`, `VOICE.md` | DATA-R100–R111 |

Nothing here is a SavedVariable: the shipped data is read-only Lua (DATA-R80).

## Contracts

### The catalogue (`ns.catalogue`, Core only)

```lua
ns.catalogue = {
  fingerprint = "3f9a2c1e7b0d4a65",           -- DATA-R70
  items = {
    [13759] = { category = "fish", species = 13759, typicalLength = 300, quality = 1,
                legend = false, noise = false, removed = false, pool = false,
                varieties = { "starfeeder", "dusk", … } },   -- ten keys, frozen order (DATA-R131)
    [13876] = { category = "trophy", family = 5, weight = 40, quality = 1,
                legend = false, noise = false, removed = false, pool = false },
  },
  areas = {
    [148] = { parent = 0, continent = 1, skillBase = 20, skillBaseConfirmed = false, hasData = true,
              catches = { { itemID = 6358, confirmed = true },
                          { itemID = 13759, confirmed = false, window = "night", gate = W.night, gateConfirmed = false } } },
  },
  aliases = { [16521] = 18 },                  -- areaID → baseline areaID
  pools = { oilyBlackmouthSchool = { 6358 } }, -- poolType → item IDs, ascending
  windows = { night = { spec = W.night, confirmed = false } },   -- one per window ID (DATA-R35)
  events = { [301] = { weekday = 1, start = 840, duration = 120, confirmed = false } },  -- {} when no weekly rule
  fishingSpells = { … },                       -- ascending
  auras = { 1265220, 1280341, 1280342, 1299323 },
}
```

`W` is a local table of window specs, emitted once before `ns.catalogue`. Core's accessors and their returns are LOG-R55 and LOG-R56; `GetWindowSpec(id)` returns a copy of `windows[id].spec` that carries `confirmed` as a field (the spec itself is shared with the gates, so it stays as it is).

### The Hunt list (`ns.huntList`, Pagle_Hunts only)

DATA-R93. Its `fingerprint` goes to `def.extraFingerprint` (LOG-R70), joined with the event list's.

### The event list (`ns.eventList`, Pagle_Hunts only)

DATA-R98.

### Lore (`ns.L`)

DATA-R104, DATA-R105. Keys follow DATA-R101.

### The Field report

The parser accepts exactly the `PAGLE-REPORT 1` format (REP-R30–R33). Core and the parser change together; a changed meaning bumps the version.

### Scripts

| Command | Rules |
|---|---|
| `scripts/generate-data.py [--check \| --propose-aliases \| --min-build <n> \| --explain <id> \| --lock]` | DATA-R60–R66, DATA-R57, DATA-R95, DATA-R133 |
| `scripts/import-field-report.py <issue> …` | DATA-R119–R121 |
| `scripts/triage-field-report.py --event <file> --open-issues <file> --comments <file> --out <dir>` (the triage Action's) | DATA-R117, DATA-R118 |
| `scripts/update-db2.py <build>` | DATA-R12 |
| `scripts/db2-watch.py --out <dir> [--issues <file>]` | DATA-R128–R130 |
| `scripts/extract-baseline.py <dump>` | DATA-R9 (run once) |
| `scripts/propose-events.py --zone <areaID> [--zone <areaID>] [--out <dir>]` | DATA-R99 |
| `scripts/check-event.py <file>` | DATA-R99 (also pagle-backend's check before a push) |

The two event scripts (DATA-R99) share the generator's readers and checks. *Decided while building them (#298):*
- **`propose-events.py`** reads the baseline's chances for its tier suggestions and nothing else does, so no chance reaches a generated file (DATA-R4). An area's shares follow VMaNGOS's loot rules: a positive chance is a percentage, rows at 0 split what is left, quest (negative) chances never count. Only items on the area's catch list count; a gated one is scaled by its window's open share of a run, and a season-gated one counts for nothing. A Hunt's share is its mean over the zones' areas that have a loot share. The drafts are for the top 3 Species, each with a Haul, its Named fish, Quality when uncommon items reach a 45-minute tier, and a Timed Hunt. The Timed spans rotate: the `night` window, the `day` window, then 18:00–21:00 (`dusk`), each adding its time tag. No draft has a `minBand`. Lore is written as `{TODO …}`, which the Hunts lore check fails as a placeholder (DATA-R107) until people write it. The default `--out` is `pagle-event-drafts-<date-time>` in the system temp directory; a folder under `data/` is refused.
- **`check-event.py`** takes a `.toml` file as an event file and a `.json` file as one pushed `huntEvent` item. A pushed item must have exactly the Contracts fields, `kind = "huntEvent"`, `v = 1`, an `id` starting `p_` and `rotation = false`, and it always gets the Hunts lore check. A file in `data/hunts/events/` is judged by the generator's own run, and only its problems are printed. Any other event must have an event ID and Hunt IDs that are new to the pool and `hunts.toml`. Exit 0: the event passes; 1: it fails, each failure on its own line; 2: the committed data itself fails the generator.

## UI

Nothing in-game. The player-facing surfaces are the GitHub issue form (DATA-R115) and the triage comment (DATA-R117); the dev's are the DB2 watch issues (DATA-R128) and the scripts' output.

## Settings

None.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Baseline snapshot | VMaNGOS `db_latest`, 2026-09-28 | DATA-R9 |
| Baseline patch | 1.12, the last Classic patch (VMaNGOS's highest patch index) | DATA-R9 |
| Noise DB2 classes | 0 Consumable, 2 Weapon, 4 Armor, 9 Recipe | DATA-R16 |
| Trophy weight pattern (enUS name) | `^(%d+) Pound ` | DATA-R21 |
| `spring` window | 20 Mar – 20 Jun | DATA-R36 |
| `autumn` window | 23 Sep – 20 Dec | DATA-R36 |
| Required reporters: ordinary / big fact | 1 / 2 | DATA-R47–R49 |
| Minimum confirming build | 0 (every Forever build) | DATA-R46, DATA-R57 |
| Rarity cap: open share / longest closed run / step | ≥ 1/7 / ≤ 7 days / 15 min | DATA-R92 |
| Rarity cap span | 2026-01-01 00:00 to 2027-12-31 23:45, realm time | DATA-R92 |
| `minBand` range | 2–4 | DATA-R89 |
| Event skill bands: low / mid / high | up to 150 / 151–275 / above 275 | DATA-R97 |
| Rotating events per band, minimum | 8 (1.0) | DATA-R99 |
| Event Hunts per event | 3–5 | DATA-R99 |
| Draft tier times: tier 1 / 2 / 3 | about 45 min / 2 h / 4 h fishing in the zones | DATA-R99 |
| Draft catch rate | 180 Catches an hour (#279's baseline) | DATA-R99 |
| An event Hunt's longest closed share of a run | half of 72 h (36 h), over a week of 15-minute steps | DATA-R99 |
| Pre-1.0 `since` placeholder | 2026-11-04 (Forever's launch day) | DATA-R87 |
| Fingerprint length | 16 hex characters of SHA-256 | DATA-R70, DATA-R72 |
| Lore limits | `riddle` 80, `blurb` 200, `plaque` 100, `name` 28, `title` and the `text` of a title 32, a variety's `description` 200; other fields unlimited | DATA-R107, DATA-R134 |
| DB2 watch schedule | weekly, Monday 06:00 UTC, plus manual | DATA-R128 |
| DB2 watch keywords | Fish, Fishing, Lure, Bait, Angler, Pool, School, Extravaganza | DATA-R129 |

## Edge cases

- **DATA-R190 Module disabled, then enabled again.** The catalogue is Core's and always loaded; a disabled Module's lore isn't loaded with it, and nothing else here depends on which Modules run. A Module that catches up after a release with a new fingerprint rebuilds instead (LOG-R72).
- **DATA-R191 Projection rebuild.** Every release that changes the catalogue changes the fingerprint and rebuilds every projection (DATA-R71); a Hunt list change rebuilds only Hunts (DATA-R72). A lore-only release rebuilds nothing.
- **DATA-R192 First build over existing history.** A release that classifies many Uncharted items rebuilds projections that already exist; that is not a first build, so it raises no Write-up. What each Module shows for newly credited history is its spec's.
- **DATA-R193 In combat.** Nothing here runs in-game beyond reading static tables.
- **DATA-R194 Crash mid-Session.** Casts lost in a crash never reach a Field report, so they are simply not evidence.
- **DATA-R195 Daily or weekly reset.** Nothing here depends on it. The Extravaganza's weekly rule is a realm-time forecast (DATA-R38), not a reset.
- **DATA-R196 Uncharted or unconfirmed Catch.** An Uncharted item is outside the universe (DATA-R15) until a Field report brings it in; then the generator fails until it is categorised or deferred (DATA-R17, DATA-R18), and the release that classifies it credits it retroactively. Unconfirmed facts ship with `confirmed = false` and become confirmed by DATA-R47–R55; a contradiction demotes a fact until the data is fixed (DATA-R52).
- **DATA-R197 Item removed after release.** A removed item leaves every list, so zone denominators shrink; what was already celebrated stays celebrated (ADR 0004). Its item record and lore remain, so caught pages still show it.
