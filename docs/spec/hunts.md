# Hunts

> Status: Draft (Hunt Events) · Milestones: M5, M8 Hunt Events (Hunt Events, runs, Activity XP, the Pagle Wagers board) · Sources: the map [Hunts redesigned around Hunt Events](https://github.com/timemir/pagle-addon/issues/277) and its tickets #278–#288, [Design Hunts and the Now/Soon board](https://github.com/timemir/pagle-addon/issues/14#issuecomment-6113353568), [Prototype the Hunts board](https://github.com/timemir/pagle-addon/issues/24#issuecomment-6114195571), [Design the Pagle currency and shop](https://github.com/timemir/pagle-addon/issues/28#issuecomment-6125331898), [Design the Simulated Size bands](https://github.com/timemir/pagle-addon/issues/33#issuecomment-6129722545), [Decide the lore pipeline](https://github.com/timemir/pagle-addon/issues/34#issuecomment-6129762441), [Define the Core/Module contract](https://github.com/timemir/pagle-addon/issues/9#issuecomment-6112445901), [Define the Core data model](https://github.com/timemir/pagle-addon/issues/10#issuecomment-6112707372), [Decide how the spec is assembled](https://github.com/timemir/pagle-addon/issues/31#issuecomment-6128960652); ADR 0001, 0004, 0005, 0007, 0008, 0009, 0011, 0012, 0013, 0014. Prototypes: `prototypes/hunts-board/` (variant E); Pagle Wagers on branch `prototype/hunts-wagers` (`prototypes/hunts-board/wagers/`, variants B and A, #284)

Hunts is the `Pagle_Hunts` Module. It judges every Catch in the Catch log against two kinds of Hunt: **Standing Hunts**, always there and grouped in Hunt sets, and the Hunts of **Hunt Events**, dateless definitions that count only during a **run** of about three days (ADR 0012). Players see Hunt Events as a whole under the name **Pagle Wagers**. Hunts keeps each Hunt's tiers, effort and set titles, each run's progress and the count of completed runs, pays Coins and Activity XP, and shows what is worth fishing for now, soon or later on the **Hunts board** (a notebook) and a HUD **tracker**.

Terms are used as `CONTEXT.md` defines them. "The Hunt list" is `ns.huntList`, which the content data generator emits into `addons/Pagle_Hunts/data/HuntList.lua` (DATA-R93); it holds the Standing Hunts. "The event pool" is `ns.eventList`, emitted into `addons/Pagle_Hunts/data/EventList.lua` (DATA-R98). Rules that say "a Hunt" apply to both kinds unless they say "a Standing Hunt" or "an event Hunt"; HNT-R140–R159 say where an event Hunt differs. "Now" means the current server time, `GetServerTime()`.

## Purpose and boundary

**Owns:**
- what each Hunt field means at runtime: which Catches qualify, tiers, completion, retirement
- set titles, effort counters and pins
- Hunt Events at runtime: runs, the fallback rotation, the run records it appends, the completed-run count and its titles
- the companion hint and its weekly Nod (HNT-R170–R172)
- the Hunts board, the Hunts tracker and `/pagle hunts`
- the moments Hunts raises, and the Pagle Coins, Activity XP and Refreshes it pays
- its Curio Shop goods (tracker frames, and its earned bindings in Core's binding slot) and its lore keys
- the Standing Hunt list (the contents of `data/hunts/hunts.toml`) and the 1.0 event pool (`data/hunts/events/`)

**Doesn't own:**
- the `hunts.toml` and `events/` formats, the tag list, the fixed and generated classes, the admission and rarity-cap checks, `HuntList.lua`, its fingerprint and `released.lock` (content data, DATA-R85–R96)
- the condition vocabulary, `MatchesConditions` and `NextWindow` (Core, LOG-R48–R50)
- the catalogue, windows and gates (Core and content data)
- presenting Announcements, the wallet and the Curio Shop (Core, ADR 0007, ADR 0009)
- reading and checking the companion's `Pagle_Content`, and the companion state (Core, [core/pushed-content.md](core/pushed-content.md))
- the Angler Level: Hunts pays Activity XP into Core only (ADR 0011); the Ledger turns it into levels
- odds or "due" claims (Stats). Hunts gives nothing to another Module directly: nothing for the Ledger or the Tackle Board (ADR 0001).

**Uses from Core:**
- `Pagle.RegisterModule` and the Module handle (CORE-R12)
- `M:NewProjection` with `:GetState()` and `:IsUpdating()` (LOG-R70–R76)
- the typed Cast records with `conditions` and per-item `size` (LOG-R65)
- the catalogue: `Pagle.GetItem`, `GetArea`, `GetZones`, `GetZoneOf`, `GetZoneCatches` (with each catch entry's `window`, LOG-R55), `GetWindowSpec`
- conditions and the Angler: `MatchesConditions`, `NextWindow`, `GetConditions`, `GetAngler`, `SIZE_BANDS`
- clock times: `Pagle.FormatClock`, and `Pagle.GetClockFormat` for the ruler's ticks (CORE-R87, HNT-R50, HNT-R62)
- events through `Pagle.RegisterCallback`: `ConditionsChanged`, `SkillChanged`, `RestrictionChanged`, `AppearanceChanged`, `ModulesChanged`, `ClockFormatChanged`; game events through `Pagle.RegisterEvent` and `Pagle.UnregisterEvent` (`PLAYER_ENTERING_WORLD`, `CALENDAR_UPDATE_EVENT_LIST`); and `Pagle.IsRestricted`
- moments: `M:RaiseMoment`, `M:RaiseWriteUp`, `M:SetSummaryLine`
- the wallet: `M:ReportCoinsEarned`, `M:RegisterSlot`, `M:RegisterGood`, `Pagle.GetEquipped`
- Activity XP: `M:ReportXPEarned` ([core/activity-xp.md](core/activity-xp.md))
- Refreshes: `M:ReportTicketsEarned` ([core/refresh.md](core/refresh.md))
- pushed content: `Pagle.GetCompanionState`, `Pagle.GetPushedContent`, event `PushedContentReady` ([core/pushed-content.md](core/pushed-content.md))
- the board's look: `Pagle.IsAnimationsOn`, Core's motion driver `Pagle.Animate`, `Cue`, `StopMotion`, `EASE`, `Bezier` ([core/announcements.md](core/announcements.md#contracts)), the timeline's wheel notch `Pagle.WheelScroll` (a third of the rows' height, gliding; same contracts), and `Pagle.FitToScreen` ([core/README.md](core/README.md#contracts))
- Module records: `M:AppendRecord`, and its own records through `M:IterateCatches` (LOG-R40, ADR 0008)
- surfaces: `M:RegisterTracker`, `M:AddSetting`

Hunts never cuts Sessions and doesn't read a record's `session` (LOG-R98).

## Rules

### The Hunt list at runtime

- **HNT-R1** The Hunt list is the only source of Standing Hunts, and Hunt Events come only from the event pool and the companion's pushed definitions (HNT-R140). Hunts reads its sets, Standing Hunts and classes from `ns.huntList` (DATA-R93) and their text from its own `ns.L` (`hunt.<id>.name`, `hunt.<id>.note`, `set.<id>.name`, `set.<id>.title`, `set.<id>.note`, DATA-R105). Display order is file order, for sets and for Hunts.
- **HNT-R2** A Standing Hunt **exists** at server time `t` when `since <= t` and it has no `retired`, or `t < retired`. A Hunt is **current** when it exists now. A Hunt whose `since` is still ahead (shipped early) isn't shown anywhere until then. An event Hunt exists only within a run of its event (HNT-R144).
- **HNT-R3** A **Retired Hunt** (one with `retired <= now`) is off the timeline, the tracker and the Now / Soon / Later / On demand groups. Its pin is removed as soon as Hunts sees it retired (HNT-R81). Its tiers, seal dates and the Coins it paid stay. It appears only on its set's page, under "Retired", and only if it is done. Clicking it there opens a **retired entry**: its name, target line, "Retired {date}", its seal, tier ladder and effort counter, with no window line, conditions line, chips or pin toggle.
- **HNT-R4** A **natural** Hunt (`kind = "natural"`) completes on the Catch alone (HNT-R10). Its `window` (a window ID) is read from the catalogue at runtime with `Pagle.GetWindowSpec(window)`, and is used only for the board, the tracker, the effort counter and where the Hunt bites. A wrong window never refuses a real Catch.
- **HNT-R5** An **imposed** Hunt (`kind = "imposed"`) counts a Catch only if its Cast matched the Hunt's own `conditions` (a condition spec, LOG-R48) when the Cast ended. It never refers to a catalogue window, so a corrected window never changes an imposed rule.
- **HNT-R6** A Hunt's **board spec** is the condition spec that drives the board: the window's spec for a natural Hunt, `conditions` for an imposed one. The **time fields** of a spec are `time`, `season` and `events`; `areas`, `auras`, `lure` and `skill` say what is needed, not when.
- **HNT-R7** If a natural Hunt's `window` has no spec (`Pagle.GetWindowSpec` returns `nil`, for example an event whose weekly rule was dropped), the Hunt has no board spec: it has no effort Casts, is never unconfirmed, groups as Later with "no date known", and draws no bars. Its Catches still qualify (HNT-R10).

### Which Catches qualify

- **HNT-R10** A Catch **qualifies** for a Hunt when all of these hold:
  1. its Cast ended caught, and the Hunt exists at the Cast's `time` (HNT-R2)
  2. its item ID isn't `0`, and its target matches:
     - a `species` target: `Pagle.GetItem(itemID)` is not `nil` and its `species` equals the Hunt's `species`, so every item of that Species counts (DATA-R19)
     - a `class` target: `ns.huntList.classes[class][itemID]` is true
  3. if the Hunt has `minBand`: the Catch has a `size` (LOG-R65) and `size.band >= minBand`. A Catch without a size never qualifies for such a Hunt.
  4. for an imposed Hunt: `Pagle.MatchesConditions(conditions, cast.conditions)` is true. Skill in `conditions` is effective skill at the Cast (rank + modifier, LOG-R48).
- **HNT-R11** Each qualifying Catch adds 1 to the Hunt's **count**, whatever its quantity. Several Catches of one Cast each count. One Catch may qualify for several Hunts.
- **HNT-R12** Class membership comes only from `ns.huntList.classes`. The generated classes `quality.uncommon`, `quality.rare` and `species.any` are defined by DATA-R91: the generator builds them from the catalogue's item records (the same `quality` and category that `Pagle.GetItem` carries, LOG-R55), Noise left out, and a released class never loses a member (ADR 0005). Hunts never reads item quality or class from `C_Item` or any other runtime API. "Uncommon-or-better" therefore never includes a Noise item.
- **HNT-R13** Only Casts recorded at or after a Hunt's `since` count toward it, including Casts recorded while Hunts was disabled (ADR 0005). Casts at or after its `retired` don't count.
- **HNT-R14** A Simulated Size band never changes for a logged Catch (LOG-R68, ADR 0014), so a `minBand` Hunt is never revoked by a rebuild. Monster (band 5) is never a `minBand` (DATA-R89); a Monster Catch still qualifies for any `minBand` from 2 to 4. A Hunt with a `minBand` must name a fish its players will have caught a lot of: a band needs the Angler's Reach, which grows with fishing skill and with earlier Catches of that fish (ADR 0014), so the same band is out of reach for an Angler new to the fish and easy for one who knows it well.

### Tiers and completion

- **HNT-R15** A Hunt's `tiers` are count thresholds. Tier `k` is **reached** when the count first reaches `tiers[k]`. Tier 1 is **completion**. Each reached tier stores the Catch that reached it: its Cast's `time`, its Catch ID, its item ID, the Cast's zone areaID and the Cast's realm date (`cast.conditions.date`, LOG-R49). A Cast's Catches are taken in loot-slot order (`items[n]`, ascending `n`), so with several qualifying Catches in one Cast, the first in slot order reaches a tier first.
- **HNT-R16** A Standing Hunt completes once; an event Hunt completes once per run (HNT-R145). After its last tier the count keeps rising and is still shown; nothing more is earned.
- **HNT-R17** A Hunt is **done** when tier 1 is reached, and **finished** when every tier is reached.
- **HNT-R18** Tier **trim**: tier 1 bronze, tier 2 silver, tier 3 and any later tier gold. A Hunt's icon wears the trim of its highest reached tier.

### Set titles

Set titles are Standing Hunts' only. Hunt Events have the completed-run titles instead (HNT-R148).

- **HNT-R20** A set's title is **earned** at the earliest server time `t` at which at least one of the set's Hunts exists and every Hunt of the set that exists at `t` is done, with tier 1 reached at or before `t` (ADR 0005). The candidate times are the tier-1 times of the set's Hunts and the `retired` dates of its Hunts, up to now. A title, once earned, is never lost: a Hunt added to the set later doesn't take it away.
- **HNT-R21** A title only needs tier 1 of each Hunt. Later tiers never count toward it.
- **HNT-R22** Titles are shown only in Hunts' own views (the nameplate, the set page and the Hunt entry). Hunts never gives them to another Module or to the game (ADR 0001).
- **HNT-R23** Hunts checks every set whose title isn't yet earned, against HNT-R20 with candidate times up to `t`:
  - in `apply`, after each Cast, with `t` = the Cast's `time`
  - in `done`, after every catch-up or rebuild, with `t` = now
  
  So a title that a retirement completes while the Angler is logged in is found at the next Cast or the next login. Projection state changes only in `apply` and `done`.
  
  A title is **from a Catch** when its earned time is the tier-1 time of the Cast just applied; otherwise (a retirement completed it) it is **from a retirement**, and its earned time is that `retired` date.

### Effort

- **HNT-R25** A Cast (caught or got away) is an **effort Cast** for a Hunt when the Hunt exists at its `time`, its conditions snapshot matches the Hunt's board spec (`Pagle.MatchesConditions`), and, if the Hunt has waters (HNT-R30), the Cast's subzone or zone is one of them. A natural Hunt matches its window spec here. An aura-only Hunt (Rack Hour, Hut Hour) counts every Cast made under its aura.
- **HNT-R26** The **effort counter** shows two numbers: the Hunt's effort Casts, and its effort Casts after the Cast of its latest qualifying Catch. A Cast that holds a qualifying Catch resets the second number to 0, after it has been counted. Before the first qualifying Catch, only the first number is shown.
- **HNT-R27** Effort is plain counts: no odds, no rates and no "due" wording. The entry notes that odds live in Stats, as plain text with no link (ADR 0001).

### Where a Hunt bites

- **HNT-R30** A Hunt's **waters** are areaIDs, worked out from the catalogue when the Module loads by walking every zone of `Pagle.GetZones()` through `Pagle.GetZoneCatches`:
  - a natural Hunt: the areas with a catch entry for an item of its target Species whose `window` is the Hunt's `window`
  - an imposed Hunt with a `species` or `fixed.*` class target and no `areas` in its conditions: the areas with a catch entry for any target item, gated or not
  - any other Hunt (one with `areas`, or a generated class target) has no waters. Its `areas`, if any, already constrain it through `MatchesConditions`.
  
  A natural Hunt with no waters (possible only if the data changed under it) has no effort Casts and no zone chip.
- **HNT-R31** A Hunt's **places** are its waters, or for a Hunt with `areas` in its conditions, those areas. Its **zones** are `Pagle.GetZoneOf(area)` for each place, without duplicates, in ascending ID order. A Hunt without places (a generated class with no `areas`) has no zones.
- **HNT-R32** A Hunt's **skill need** is the larger of:
  - the lowest skill base among its places, where an area's skill base is its own `skillBase` if set, else its zone's (LOG-R55); places with neither are skipped
  - `conditions.skill.min`, for an imposed Hunt that has it
  
  A Hunt with no places with a skill base and no `skill` condition, or whose need is 0 or less, has no skill need.
- **HNT-R33** The Hunt is **short of skill** when it has a skill need above the Angler's `bestBaseSkill` (`Pagle.GetAngler()`, the best base rank among all characters). When the gap is at most the lure reach (Tunables), the board adds "A lure gets me there."
- **HNT-R34** A natural Hunt is **unconfirmed** when its window's `confirmed` (from `GetWindowSpec`) is false, or none of the catch entries that made its waters has `gateConfirmed` true. Any Hunt is unconfirmed when its `NextWindow` result has `confirmed = false` (an unconfirmed weekly rule). Being unconfirmed changes only the display (HNT-R63); it never refuses a Catch.

### Hunt Events and runs

- **HNT-R140** A **Hunt Event** (ADR 0012) is a definition with no dates: an `id`, 1–2 `zones` (zone areaIDs), its Hunts (3–5), its `tags`, a skill range and `rotation`. Its name and note, and each of its Hunts' names, are lore. Events come from two places, and nothing else makes one:
  - **the pool:** `ns.eventList.events` (DATA-R98), shipped with the addon;
  - **pushed definitions:** the `huntEvent` items of `Pagle.GetPushedContent` ([core/pushed-content.md](core/pushed-content.md)), with IDs starting `p_`, and the definitions Hunts has logged (HNT-R154).
  
  A definition never changes once shipped or pushed (ADR 0005's note); a fix is a new event ID.
- **HNT-R141** An **event Hunt** is always imposed. It has no `set`, no `kind` field, no `since` and no `retired`. Its condition spec is its own `conditions` (any LOG-R48 fields, or none) with the event's `zones` added as `areas`, so a Catch counts only in the event's zones and their subzones (LOG-R48). Its own `conditions` can only narrow that; the generator refuses an `areas` field of its own (DATA-R99). Its target, `minBand` and `tiers` work as a Standing Hunt's (HNT-R10–R15).
- **HNT-R142** A **run** is `(event, start, end)`: exact server times (UTC), `start < end`, identified by its **run key** `<eventID>@<start>`. Whoever schedules it sets its length, 72 hours by default (Tunables). Two runs of the same event never overlap: Hunts ignores a run that overlaps a known run of the same event (HNT-R150). Any number of runs of different events may be on at once.
- **HNT-R143** A run is **on** at server time `t` when `start <= t < end`, **ahead** before, and **ended** after. An ended run leaves the board, the tracker and every list; nothing of it is shown again, and there is no list of past runs. **Ended** never means **Retired** (HNT-R3).
- **HNT-R144** An event Hunt **exists** at `t` when a known run of its event is on at `t`. A Catch qualifies for it (HNT-R10, with "exists" read this way) only within that run, judged by the Cast entry's `time`: the server's clock at the Cast's end, never the client's (LOG-R11). So a Cast that started before `end` and ended after it doesn't count, and at a back-to-back boundary a Cast belongs only to the run that starts there ([#287](https://github.com/timemir/pagle-addon/issues/287)). Effort (HNT-R25) counts the same way, per run.
- **HNT-R145** Each run keeps its own progress for each of its event's Hunts: count, effort and reached tiers (HNT-R15). A new run of the same event starts at 0 and pays again (HNT-R110, HNT-R114).
- **HNT-R146** A run is **completed** when every Hunt of its event has reached tier 1 within the run; later tiers aren't needed. Its completion time is the tier-1 time of the last of its Hunts to reach it.
- **HNT-R147** A run that ends uncompleted is simply over. Its progress stays in the projection (it counted, and paid for every tier it reached) but is never shown again.
- **HNT-R148** The **completed-run count** is the number of completed runs, across all events and repeats. Titles are earned when it reaches 25, 50 and 100 (Tunables): Bookmaker's Bane at 25, and the titles at 50 and 100 named in the lore pass (`ladder.<n>.title`, HNT-R130). A ladder title, once earned, is never lost. One completed run earns no title of its own.
- **HNT-R178** **The ladder for Pagle's backend** ([#76](https://github.com/timemir/pagle-addon/issues/76) item 5, pagle-backend's `angler-page.md` › Journal values, `journal.v` 2). Hunts' `JournalValues(state, sessionRows)` (LOG-R79) also gives `ladder`: the ladder's marks in step order (25, 50, 100, Tunables), each `{ step, earned }`, `earned` whether the state holds that step's title (`ladder[step]`, computed only, never the celebrated set's, LOG-R77). These are the marks the Pagle Wagers spread inks (HNT-R162). The completed-run count (`settled`) and each title's earned time (`ladder`) stay in the projection state the backend stores, and a title's text is lore's `ladder.<step>.title` (HNT-R130), so neither is repeated here.
- **HNT-R149** Casts folded after a run has ended still count for it. A catch-up, a rebuild or a re-enabled Module credits every Cast inside a known run; tiers, completions and ladder titles reached that way pay Coins and Activity XP, but arrive only as summary-only moments or Write-up lines (HNT-R111, HNT-R112). A run's record can come after Casts it must credit (a pushed run logged mid-run with its real `start`, HNT-R151; the slots a catch-up logs, HNT-R155): folding a `run` record walks the run's earlier Casts again with `M:IterateCatches`, from the first Cast at or after its `start` up to the record, and credits them in order as `apply` would, with no moments. The projection keeps an hour index (`hours`, [Projection state](#projection-state)) to find where to start, for the last 14 days of Casts (Tunables); a run older than that is credited from the index's start. A rebuild reads the log in the same order, so it folds to the same state as the live entries did. *Decided while building (#299): how a late record finds its Casts, which the spec didn't say.*

### Which runs Hunts knows: the run records

- **HNT-R150** Hunts **logs every run it uses** the first time it uses it, as its own Module record (ADR 0008, LOG-R40): kind `run`, payload `<eventID>|<start>|<end>|<source>`, with `source` `r` for the rotation or `p` for pushed. For a pushed event whose definition isn't in the pool, it first logs the definition (HNT-R154). A run is **known** once its record is in the log. The projection credits Casts only to known runs, so a rebuild reads runs from the log alone, never from the pool's current rotation or the companion's current file. When two known runs of the same event overlap, the one logged first wins and the other is ignored.
- **HNT-R151** **When Hunts logs a run:** in the live step after each regroup (HNT-R42), at login once `PushedContentReady` has fired, and after each catch-up or rebuild's `done` (HNT-R155). The step runs on a later frame, never during an apply or from `done` (LOG-R40), and does nothing while the projection is updating:
  - a **pushed** `huntRun` item whose event is known (pooled or pushed) is logged once `start <= now < end`, with its real `start`, so Casts before Hunts first saw it count. A pushed run already ended when first seen is ignored: nothing is logged or credited.
  - a **fallback** run (HNT-R152) is logged once it is on and no logged run covers its slot (HNT-R153).
  
  An ahead run is shown (HNT-R160) but not logged until it starts, so the backend can still withdraw it: a later snapshot simply no longer lists it. Once logged, a run is never changed or withdrawn.
- **HNT-R152** The **fallback rotation** (ADR 0012 and its note) runs back-to-back runs of 72 hours from the rotation's starting point (Tunables: 1.0's release day at 15:00 UTC; before 1.0 a placeholder in the past, so dogfooding has runs). Slot `k` covers `[origin + 72 h × k, origin + 72 h × (k + 1))`, and there is no fallback run before the origin.
  - **Bands:** the pool's events with `rotation = true` and no `retired` date at or before the slot's start (DATA-R98) are split by skill band (HNT-R156), each band in event-ID order.
  - **Order:** the slots cycle low → mid → high (slot `k`'s band is `k mod 3`). Band `b`'s `j`-th visit picks `perm_b,p[j mod n_b]`, where `n_b` is the band's size, `p = floor(j / n_b)` is the pass, and `perm_b,p` is a Fisher–Yates shuffle of the band seeded by the FNV-1a hash (LOG-R66 step 1) of `"<band>:<p>"`, so each pass through a band is shuffled anew. Slot `k` is band `k mod 3`'s visit `j = floor(k / 3)`.
  - **Shuffle:** `perm_b,p` starts from the band in event-ID order (0-based). With `x` the seed's hash, for each position `i` from `n_b − 1` down to 1, `x` takes one step of the 32-bit linear congruential generator `x = (1664525 × x + 1013904223) mod 2^32`, and position `i` swaps with position `floor(x × (i + 1) / 2^32)`. It is plain arithmetic, with no `math.random` and no `bit`: the product stays below 2^53 (1664525 × (2^32 − 1) < 2^53), so every client gets the same `x`. *Default chosen while building (#300): the spec named the seed but not the generator.*
  - **Worked slots,** over the 1.0 pool (`spec/Pagle_Hunts/data/Rotation_spec.lua` checks them):
    - slot 0, low, visit 0: the seed `"low:0"` hashes to 3703032707. Its first three steps are 2359655174, 1399887533 and 202672168. The shuffle orders the eight low events `duskwood_witching`, `tirisfal_silverpine_dusk`, `stranglethorn_coast`, `loch_modan_frenzy`, `barrens_oddities`, `alterac_dawn_trout`, `darkshore_moonlight`, `dustwallow_marsh_night`. The pick is `duskwood_witching`.
    - slot 1, mid, visit 0: the seed `"mid:0"` hashes to 973479943. The pick is `hinterlands_coast`.
    - slot 2, high, visit 0: the seed `"high:0"` hashes to 940069935. The pick is `winterspring_salmon`.
  - **Shared:** every Angler without the companion sees the same run in the same slot.
- **HNT-R153** **Precedence.** While the companion is `"connected"` (PUSH-R15), Hunts starts no new fallback run: the backend's schedule replaces the rotation. In any other state, the rotation fills every slot that no logged run covers. A run already logged always plays out, whatever the state becomes. When a slot's pick already has a run on, the rotation takes the next pick in its band. *Decided while writing the spec (#289): a slot is "covered" when any logged run of any source overlaps it; the rotation then leaves that slot empty rather than fitting a shorter run around it.* *Decided while building (#300):* a pick "has a run on" when a run of its event overlaps the slot: a logged one, or a pushed run of the snapshot still to come, which may start inside an uncovered slot. The next pick is the band's next visit's (`j + 1`, `j + 2`, …), each event once; with every pick taken, the slot stays empty.
- **HNT-R154** A pushed definition is logged before its first run, as records of kind `def` carrying the definition in the content grammar ([Contracts](#pushed-hunt-events-and-runs)), split into numbered parts that fit LOG-R40's 200-byte limit: payload `<eventID>|<part>/<parts>|<text>`. Hunts reassembles the parts in order when it applies them. A definition with a part missing is unknown, and its runs aren't credited. *Decided while writing the spec (#289): splitting into parts is how a definition fits the record limit.*
- **HNT-R155** **Catch-ups.** When Hunts replays Casts recorded while it was off (`"replay"`), no record can be appended during the replay (LOG-R40). So the fold notes the earliest and latest replayed Cast times, and the live step scheduled from `done` logs a run for each slot in that span that no logged run covers, by the current rotation rule (HNT-R150, HNT-R153). Folding each `run` record then credits its Casts (HNT-R149), and what they earn arrives only as summary-only moments or Write-up lines. If the pool changed in an update since then, those past runs follow the current rule; nobody saw them, so nothing that was shown changes. Pushed runs it never saw while off aren't credited. *Decided while building (#300): the span, noted in memory by the fold, replaces "first works out", since the replay can't append. While the companion is `"connected"` the catch-up logs no fallback run either (HNT-R153). A rebuild notes no span: it reads runs from the log alone (HNT-R150).*
- **HNT-R156** An event's **skill band** comes from its skill range's lower end: `low` up to 150, `mid` 151–275, `high` above 275 (Tunables, DATA-R97). *Decided while writing the spec (#289): these bounds follow the zone survey in #281.* An event is **short of skill** when its `skill` range's lower end is above the Angler's `bestBaseSkill` (as HNT-R33). It still runs and counts; the board labels it "needs skill {n}", that lower end, in pencil grey on its ticket, its ahead row and its entry (HNT-R162, HNT-R163): never in red, and never a warning. A skill below 0 is never shown: each shown bound is at least 0, and a range at or below 0 shows no requirement.

### Groups on the board

- **HNT-R40** Hunts groups every current Standing Hunt into exactly one of **Now**, **Soon**, **Later** or **On demand**, from `Pagle.NextWindow(boardSpec, now)` (LOG-R50) and the live `Pagle.GetConditions()`, in this order:
  1. no board spec (HNT-R7) or short of skill (HNT-R33): **Later**
  2. `onDemand` (the spec has `auras` and no time fields): **Now** while any of its auras is in the live snapshot's `auras`, otherwise **On demand**
  3. `always`: **Now**
  4. `openNow`: **Now**, except that a spec that also has `auras` is **On demand** while none of them is up
  5. `opensAt - now` at most the Soon horizon (Tunables): **Soon**
  6. otherwise, including a `nil` result: **Later**
  
  "Aura up" below means the Hunt is Now through rule 2, or through rule 4 with `auras`. Runs and their event Hunts aren't grouped: they have the WAGERS group (HNT-R161).
- **HNT-R41** The live calendar decides whether an event is open now; the shipped weekly rule decides Soon and Later. Both come from `NextWindow` (LOG-R46, LOG-R50); Hunts never reads `C_Calendar` to group.
- **HNT-R42** Hunts regroups when:
  - the earliest `opensAt`, `closesAt` or Soon-horizon crossing among current Hunts passes, by a `C_Timer` set to it
  - `ConditionsChanged` fires (area, auras, lure, events or skill)
  - `SkillChanged` fires
  - at every turn of the refresh interval (Tunables) in server time, the realm minute, while the board or the tracker is visible, for countdowns
  - a Hunt's `retired` or `since` date passes (a `C_Timer` set to the earliest one ahead)
  - a run's `start` or `end` passes, or a fallback slot turns (a `C_Timer` set to the earliest one ahead); then the live step logs what HNT-R151 says
  
  The first grouping runs at the first `PLAYER_ENTERING_WORLD` after login or reload. After every regroup, and after every live apply or `done` that changes the projection, Hunts redraws the board (if shown), the tracker and the summary line (HNT-R89).
- **HNT-R43** While `Pagle.IsRestricted()` is true, Hunts doesn't regroup: the board and tracker keep the grouping from before the restriction, because calendar reads can be secret (LOG-R46). Everything drawn from the grouping freezes with it: labels, countdowns, bars, the now line and the clock. The board's clock line adds "(paused in combat)". If the first grouping falls while restricted (a `/reload` in combat), it runs anyway, is marked paused the same way, and is redone at `RestrictionChanged(false)`. The next regroup after a restriction runs at `RestrictionChanged(false)`. Redraws for projection changes still happen while restricted.
- **HNT-R44** Within a group, rows sort by: pinned first; then, among unpinned rows, short of skill last; then by time: Now by `closesAt` ascending (Hunts with none last), Soon and Later by `opensAt` ascending (a `nil` result last), On demand none; then Hunt list order.

### Labels

- **HNT-R50** Every time a label shows is realm time. A server time `T` becomes a realm clock from one live `Pagle.GetConditions()`: realm minute of day = `(minute + floor((T - time) / 60)) mod 1440`, and the realm date is the snapshot's `date` moved by the whole days that adds.
  - **Durations**, rounded down to the minute: under an hour "37m"; under a day "2h" or "2h 10m"; a day or more "1d" or "1d 4h" (minutes dropped).
  - **Clock times**: in Core's clock format, `Pagle.FormatClock` (CORE-R87): 24-hour "06:00", or 12-hour "6:00 AM" when the Settings root's Clock row picks it or follows a game clock set to 12-hour. Every one Hunts shows goes through it: the board's realm clock ("11:41 · Thu 22 Oct · Winter", or "11:41 AM · …"), the labels and window lines (HNT-R51, HNT-R52), the conditions line's ranges and an event's weekly time ("Sundays 2:00 PM for 2h", HNT-R53), the Wagers slips and the window moments. The timeline ruler's hour ticks (HNT-R62) follow the format too, compact to fit 3 hours apart: "06", "18" in 24-hour, and "6a", "6p", midnight "12a", noon "12p" in 12-hour (`Pagle.GetClockFormat`). Durations ("2h", "ends in 3h") aren't clock times and don't change. When the format changes (`ClockFormatChanged`), every shown view redraws at once, ruler included.
  - **Days and dates**: a weekday "Sun", a short date "12 Oct", a full date "12 Oct 2026" (seals, nameplate tooltip, retired entry), a month "March". Weekday and month names are interface strings in `ns.L`.
  - A label is **same realm day** when the target's realm date equals today's.
- **HNT-R51** Each current Hunt has a **margin label** (board, red handwriting) and a **tracker label**:

  | Case | Margin label | Tracker label |
  |---|---|---|
  | short of skill | "need 225" | "needs 225" |
  | Now, aura up | "up now" | "up now" |
  | On demand | "on demand" | "on demand" |
  | Now, `always` | "any time" | "any time" |
  | Now, no `closesAt` | "while the event runs" | "now" |
  | Now, closes within 7 days | "until 06:00" (same realm day) or "until Sun 16:00" | "ends in 2h 10m" |
  | Now, closes later | "until September" | "until September" |
  | Soon | "in 37m" | "in 37m" |
  | Later, opens within 7 days | "21:00" (same realm day) or "Sun 14:00" | the same |
  | Later, opens later | "back in March" | the same |
  | Later, `nil` | "no date known" | the same |
- **HNT-R52** The selected Hunt's **window line** (right page, handwriting), by the same cases as HNT-R51, ignoring skill:

  | Case | Window line |
  |---|---|
  | aura up | "Up now." |
  | On demand | "Whenever I set up {aura name}." (the first aura in the spec, its spell name from `C_Spell.GetSpellName`) |
  | Now, `always` | "Open any time." |
  | Now, no `closesAt` | "Open while the event runs." |
  | Now, closes within 7 days | "Open now. Closes in 38m, at 06:00." (the time is "Sun 16:00" when not the same realm day) |
  | Now, closes later | "Open now, until September." |
  | Soon | "Opens in 37m, at 18:00." |
  | Later, opens within 7 days | "Opens at 21:00." (same realm day) or "Opens Sun 14:00." |
  | Later, opens later | "Back in March." |
  | Later, `nil` | "No date known." |

  When short of skill, the line adds "Needs 225; my best is 180." and, within the lure reach, "A lure gets me there."
- **HNT-R53** The **conditions line** lists the board spec's fields in plain words, in this order, joined by " · ". Several values within one field are joined with ", " for ranges and " or " for areas, events and auras. Times and dates come from the spec itself.
  - `time`: "Night {ranges}" when the board spec is the `night` window, "Day {ranges}" for `day`, otherwise "Realm time {ranges}", each range "22:00–04:00"
  - `season`: "{Season} ({ranges})" for a named season window, otherwise "{ranges}", each range "20 Mar – 19 Sep"
  - `events`: the event's name, then "{weekday}s {start} for {duration}" ("Sundays 14:00 for 2h"), taken from the next forecast opening: `NextWindow({ events = { id } }, now)`, or from its `closesAt` when it is open now, giving the weekday and realm clock of `opensAt` and the duration `closesAt - opensAt`. With no forecast (`nil`), only the name shows.
  - `areas`: "In {names}", localized names from `C_Map.GetAreaInfo`
  - `auras`: "While {aura name} is up"
  - `lure`: "With a lure on"
  - `skill`: "Skill {n} or more (lures count)"
  
  Window and season names (Day, Night, Spring, Summer, Autumn, Winter) are interface strings. No game name ships (DATA-R3), so an event's name is looked up at runtime, outside restriction:
  1. At the first `PLAYER_ENTERING_WORLD`, or at the first `RestrictionChanged(false)` if that falls while restricted, Hunts calls `C_Calendar.OpenCalendar()` and waits for one `CALENDAR_UPDATE_EVENT_LIST`.
  2. It then searches the calendar days of the current and next month (`C_Calendar.GetNumDayEvents` and `C_Calendar.GetDayEvent`) for each event ID in its Hunts' specs.
  3. Names are kept in memory for the login. A name not found reads "a calendar event".
- **HNT-R54** A Hunt's **target line**: a `species` target's item name (from the Species item, loaded with `Item:CreateFromItemID`); a fixed class's member names joined with " or "; `quality.uncommon` "Any uncommon-or-better Catch"; `quality.rare` "Any rare-or-better Catch"; `species.any` "Any fish". Until an item's name has loaded, it shows as "…". A `minBand` adds ", {band name} or better", the name from `Pagle.SIZE_BANDS[minBand]`.
- **HNT-R55** A Hunt's **icon**: a `species` target's Species item icon; a fixed class's first member's icon; a generated class's `Interface\Icons\Trade_Fishing`, tinted with `ITEM_QUALITY_COLORS[2]` for `quality.uncommon`, `[3]` for `quality.rare`, and untinted for `species.any`. On the board, item icons are sepia-tinted, like the Journal. In a moment (HNT-R86), the icon is the qualifying Catch's item ID, or `Trade_Fishing` untinted when there is none.

### The board

- **HNT-R60** The board is one frame, a two-page notebook in the Journal's book language: leather binding, parchment, ink bars, a serif text face, a handwriting face, wax seals and small-caps headings. It is about 920 × 600 px (Tunables), its timeline's page wider than the entry's (1.45 to 1). It is Core's book shell (`Pagle.NewBook`, core/book.md, ADR 0016), the book `hunts`: it opens centred (40 px above the middle, so the ribbons hanging under it stay on screen) until the Angler drags it by the leather, then where it was left, which it **saves** (`PagleDB.profile.books.hunts`, BOOK-R5); it closes with Esc or its wax close button (BOOK-R2, BOOK-R15). It never links to the Journal, and the Journal never links to it (ADR 0001).
  
  Its art is the books art kit (the dev's `PagleArtBooks` probe, which also draws the Stats book): bundled fonts in Core's media (IM Fell English and its italic for print, Caveat for handwriting, Marcellus for gilt) and BLP textures for the wax seal, paper chips and pill, ink strokes, the timeline's bars, item rings and tier marks. The book round the pages (the leather, the parchment and its gutter, the crumbs and fleurons, the wax close and "?", the brass nameplate and the grosgrain ribbons) is Core's book shell's, drawn in Core's media (BOOK-R10–R19); each tracker frame and the kit's parts only the board draws (the checklist's tick, Verdigris's gilt corner) are Hunts' own. The pointing hand, which the kit leaves out, stays an in-client texture. Marks are drawn as textures, never as font glyphs.

  Its fades, sounds, fit to the screen and page turn are the shell's (BOOK-R3, BOOK-R4, BOOK-R31, BOOK-R32): a ribbon or crumb that goes to another spread turns the page, forward to a later ribbon and back to an earlier one, even from one set's page to another's (BOOK-R34), the shell's fold over the turning page; on the same spread it draws in place. The board's own sounds play by the client's sound kit ids on the SFX channel (UI foley, never part of a sound set, with no setting of its own): "show completed" plays the checkbox's sounds, and a count's beat (HNT-R64) plays only while things move. With Core's Animations setting (`Pagle.IsAnimationsOn()`) off, everything draws settled.
- **HNT-R61** On the leather, above the pages (the shell lays the crumbs, the nameplate and the ribbons from the board's words, BOOK-R12, BOOK-R14, BOOK-R17–R19, BOOK-R24; the clock and the checkbox are leather anchors at the strip's right, BOOK-R16):
  - gilt breadcrumbs: "Hunts", then "{set}" (or "Pagle Wagers", HNT-R164), then "{Hunt}" (or the event), separated by a fleuron mark, each part clickable back up
  - the realm clock: time, short date with weekday ("Tue 14 Oct") and season, plus "(paused in combat)" under HNT-R43. The season is the first of the `summer`, `winter`, `spring` and `autumn` windows whose spec matches the live snapshot, or none. With the v1 data, summer and winter cover the whole year.
  - a "show completed" checkbox (HNT-R82)
  - beside the wax close button, the shell's **"?"** (ONB-R59, BOOK-R15): a plain seal of the same wax with a gilt "?", its tooltip "Show the notes for this page again". It shows the board's First look (ONB-R57) again, turning to the Board ribbon's spread first if another shows. *Defaults chosen while building (#333):* the First look shows as the board opens on the Board spread with a Now, Soon or Later heading in the list's view; opened on another spread, or with no Hunt out, the board opens without it and leaves it unseen for a later opening. Its notes point at the first such heading, the now line, the end of the entry's kicker ("Natural" or "Imposed"), the pin toggle and the Pagle Wagers ribbon, each read as Core asks, so they follow the list wherever the wager strip pushes it; the fifth note sits in the left margin, as the Pagle Wagers ribbon hangs second, not last as the canvas drew it. Opening the board on any spread ticks the First evening list's `hunts` item (ONB-R61).
  - a brass **nameplate** on the cover corner (silver under a binding that asks for it, HNT-R70): "{n} titles · {m} Hunts done" (titles earned; Hunts done, retired ones included), with a tooltip listing each earned title and its full date
  - **set ribbons** hanging from under the leather's foot from 176 px in, left to right, in the shell's one ribbon geometry (BOOK-R17), each tinted grosgrain with the set's full name, in its tooltip too (the chosen one hangs longer and brighter): "Board", then "Pagle Wagers" (HNT-R162), then one per Standing set that has a current Hunt, an earned title, or a done Retired Hunt, in Hunt list order
- **HNT-R62** The left page, "What's biting, and when", is a **timeline**:
  - a realm-time ruler from 2 hours before now to 22 hours after (Tunables), with hour ticks, every third one labelled with its hour in the clock format ("18", or "6p" in 12-hour, HNT-R50), and a red "now" line
  - a faint wash over the next 3 hours (Soon) and over the times the `night` window holds
  - the rows of the four groups in the order Now, Soon, Later, On demand, each under its heading ("Now: open right now", "Soon: opens within 3 hours", "Later: opens after that, or needs more skill", "On demand: starts when you do"; set as the group's dot, its name in small caps and its note in italic) with its row count; an empty group is left out
  - a legend under the list explaining the bar styles, each drawn in its own stroke beside its words: hatched "open", dashed "window unconfirmed", pencil "needs more skill", blue "your camp is up"
  
  The ruler stays fixed at the top of the page; the rows scroll under it when they overflow. The timeline is live: at every regroup (HNT-R42, each realm minute while it shows) the now line stays put while the hours, the washes and the bars move with the time, and the labels are rewritten. When a regroup moves a Hunt to another group, the groups restack and each row slides to its new place (0.4 s); a Hunt that has just moved into Now flashes green under its row and the board plays the Hunt-opens sound.
- **HNT-R63** Each row shows the Hunt's icon (with trim and a pin mark if pinned), its name, its bars on the ruler, and its margin label (HNT-R51). Bars:
  - **Spans:** the spans where the board spec's time fields hold. Hunts finds them by calling `NextWindow` with `fromTime` at the ruler's start, then at each returned `closesAt`, until a window opens after the ruler's end. A window open at the ruler's start draws from the ruler's start. These are forecasts from the weekly rules, so an event the live calendar shows as open with no forecast span at now draws from the now line to the ruler's end.
  - **Style:** hatched ink; dashed when the Hunt is unconfirmed (HNT-R34); a pencil outline when it is short of skill, which wins over dashed.
  - **Special rows:**
    - An always-open Hunt fills the ruler.
    - An On demand Hunt has no bar. While its aura is up, a blue bar runs from the now line to the aura's expiry, then to the ruler's end when the expiry is unknown. The expiry is `GetServerTime() + (expirationTime - GetTime())`, from `C_UnitAuras.GetPlayerAuraBySpellID(spellID)`, read for display only; it is unknown when the call or the aura is missing, or `expirationTime` is 0.
    - A Hunt whose spec has `season` and no span on the ruler shows "out of season" in place of bars.
    - A Hunt without a board spec (HNT-R7) has no bars.
- **HNT-R64** The right page shows the selected Hunt's **entry**:
  - the set name and the kind ("Natural" or "Imposed") in small caps, then the Hunt's name and its target line (HNT-R54)
  - a **wax seal**: "Hunted {full date of tier 1}" once done (pressed, its word, short date and year stacked), a dashed "not yet" before; and a pin toggle ("Pinned", or a faint "Pin")
  - the window line (HNT-R52), then the conditions line (HNT-R53)
  - **chips** (HNT-R65)
  - the **tier ladder**: one diamond per tier in its trim colour, filled when reached, with its threshold, the short date and zone name (`C_Map.GetAreaInfo`; none when the zone was 0) of the Catch that reached it ("not yet" before), and an ink bar with "{count} / {next threshold}" toward the next unreached tier; a finished Hunt shows its count instead ("52 caught")
  - the effort counter in handwriting: "96 Casts under these conditions, 11 since my last one." then "Odds live in Stats."
  - the set line: "{set}: {done} of {current} · earns {title}", or "· earned {title}"
- **HNT-R65** **Chips** on the entry, in this order, each shown only when it applies:
  - zone: up to 3 zone names (Tunables) from the Hunt's zones, the live zone first with a "you're here" badge, then "+N more" with a tooltip listing the rest
  - skill: "skill 225" when the Hunt has a skill need; "needs 225, best: 180" in red when short of skill
  - lure: "needs a lure" when the board spec has `lure`
  - notes: the Hunt's `note`, then its set's `note`
  - unconfirmed: "unconfirmed", with a tooltip: "This window is an estimate." when the window or weekly rule is unconfirmed, "Not yet seen biting only in this window." when only the gating is
- **HNT-R66** A **set's page** opens from its ribbon or its breadcrumb:
  - the left page is the timeline filtered to the set's current Hunts (the "show completed" filter still applies), headed "{set name}: earns {title}" or "{set name}: {title}" once earned
  - the right page shows the kicker "Hunt set" (the left page's too) and the set's name; a seal, the dashed "not yet" until its title is earned, then pressed with the full date it was earned; "Earns the title {title}", or "Earned: {title}"; an ink progress bar of done current Hunts out of current Hunts, "{done} of {current} done"; the line "The first tier of every Hunt earns the title."; the set's note
  - below that, under "Hunts in this set", a checklist of **all** its current Hunts, done or not and whatever the filter, each with the kit's tick once done, dotted leaders and its seal date (short date) or its tracker label; then, under "Retired", its done Retired Hunts, greyed
  - clicking a Hunt opens its entry (or retired entry, HNT-R3), with a pointing-hand mark and "back to {set}" above it
- **HNT-R67** When the board opens, it shows the Board ribbon and selects a Hunt:
  - normally the first Hunt under Now; if Now is empty, the first row. *Decided while writing the spec (#289): a WAGERS row is not selected by default, so the right page keeps showing a Hunt that is open now; the wager strip sits above it.*
  - if no row is visible, the right page reads "Every Hunt here is done. Tick \"show completed\" to see them again."
  - if no Hunt is current at all (before the first `since`), the left page reads "No Hunts yet." and the right page is empty
  
  Opening it on a given Hunt (from the tracker) shows the Board ribbon and selects that Hunt; a pinned Hunt is always on the Board (HNT-R80).
- **HNT-R68** The board opens from Core's compartment menu entry "Hunts", from `/pagle hunts` and from the Settings status button ("Open Hunts", CORE-R44). All three call the same view function, which toggles the board. It opens and stays open while restricted, as the shell's frame isn't secure (BOOK-R2); only regrouping pauses (HNT-R43).
- **HNT-R69** While the projection is updating (LOG-R74), the timeline still shows and groups as usual, but nothing is drawn from projection state: the filter hides nothing, icons show no trim, and seals, tier ladders, effort counters, set progress and the nameplate read "Updating from your Catch log…" until it finishes.
- **HNT-R70** The board's leather is the Angler's binding (ADR 0015): it wears `Pagle.GetEquipped("core.binding")` through Core's renderer, `Pagle.NewBookBinding` (core/book-binding.md, BIND-R1), which follows each change, dips an open board and plays the page turn once for every open book (BIND-R20, BIND-R21). The board draws no leather, dip or sound of its own. It inks its own parts from each look the renderer hands it (BIND-R3): the crumbs and the fleurons between them in the look's `gilt` and `giltShadow`, the brass nameplate toned silver when the look's `silver` is set, and its pages' paper tinted by `paperTint`. An open board inks them again at once; a closed one, at its next draw. The tour's binding stops (`hunts.binding.<key>`, after the board's and tracker's stops and before the tracker frames') pin the board to each of Hunts' three earned bindings in turn (HNT-R122) with `SetLook(goodID)` (BIND-R2), and each stop's hide puts back the binding the board wore before, following the equipped one again (CORE-R68).

### Pagle Wagers on the board

The board shows Hunt Events under the players' name, **Pagle Wagers**, in two places ([#284](https://github.com/timemir/pagle-addon/issues/284): variant B woven into the Board, plus variant A's ribbon and spread). Look reference: `prototypes/hunts-board/wagers/` on branch `prototype/hunts-wagers`.

- **HNT-R160** The runs the board shows are the **runs on** (known, HNT-R150) and the **runs ahead**: pushed `huntRun` items not yet started, and the next fallback slot's pick when the rotation fills it (HNT-R153). They are ordered by `end` ascending (on), then `start` ascending (ahead).
- **HNT-R161** **On the Board spread** (HNT-R62), above "What's biting, and when":
  - **The wager strip:** a one-line **wager ticket**, 38 high, the spread's ticket paper (HNT-R162) three-sliced to that height, naming the first run on:
    - in its perforated **stub**, the run's **time dial** (HNT-R167) without words;
    - its **event mark** (HNT-R166), 26 across;
    - the event's name, then its zones in italic;
    - at the right, one pip per Hunt, inked bronze once that Hunt reached tier 1, or the red **SETTLED** stamp once settled ("updating…" in their place while the projection updates, HNT-R69);
    - right of them, "closes in {duration}" (HNT-R50) in the hand, in the now line's red while the run, not settled, closes within the closing-note time (Tunables), else in the margin labels' red;
    - with more runs on, "+{n} more on the table" before the pips.

    When the line is short of room, the zones go first (cut short, then left out), then "+{n} more on the table", and only then is the name cut short. With none on, the first run ahead shows as the spread's dashed **row ahead** (HNT-R162), 38 high: its mark, name, zones and "needs skill {n}", and at the right "opens {weekday} {time}" over "for {length}". It shows the companion hint's line (HNT-R170) under it when the hint applies. Clicking the strip opens the Pagle Wagers spread (HNT-R162) on its run. Nothing on it moves (HNT-R167).
  - **The WAGERS group:** the timeline's first group, above Now, heading "Wagers: on for days, not hours", with one row per run on and per run ahead within the ruler. A row shows the run's **event mark** (HNT-R166), 22 across in the ring's place of a Hunt's icon, its name and a bar spanning the run's days, drawn across the whole ruler while on, with a ▸ mark at the ruler's end when the run outlasts it. Each event Hunt with a `time` condition hatches its window in red over the bar (by `NextWindow`, HNT-R63). The margin label is "until {weekday} {time}" (on) or "{weekday} {time}" (ahead), by HNT-R50. Clicking a row selects the run: the right page shows its run entry (HNT-R163).
  - The WAGERS group ignores "show completed" and pins; an empty group is left out.
  - An event's icon, where its moments show one (the Pagle Wagers moments below), is its first Hunt's (HNT-R55).

  *Decided with the dev from the prototype ([#375](https://github.com/timemir/pagle-addon/issues/375), the Pagle Wagers kit's offers in [#366](https://github.com/timemir/pagle-addon/issues/366)):* the strip is the kit's ticket on one line, version A2: its dial wordless, as "closes in …" says the time at its right, and no "Pagle Wagers" kicker, as the ticket's paper and mark name it. A run ahead takes the spread's dashed row, not a ticket. The WAGERS rows trade the first Hunt's icon for the event mark, and nothing else in them changes.
- **HNT-R162** **The Pagle Wagers ribbon** hangs second, after "Board", in oxblood with "{n} on" under its name when runs are on (the shell's ribbon `count`, BOOK-R19). Its spread (the Wagers redesign's variant A; look: the Pagle Wagers kit's `art.json`):
  - **left page,** kicker "Pagle Wagers", title "On the table", and a note that follows the table: "{n} wagers on. Land every Hunt's first mark before its wager closes." with two or more runs on, "One wager on. Land every Hunt's first mark before it closes." with one, "Nothing on just now. The next wager opens {weekday} {time}." with none on and one ahead, and "Nothing on the table, and nothing posted yet." with neither.
    - **The closing note:** while a run on that isn't settled closes within the closing-note time (Tunables), a margin note in red handwriting beside the title, "{event} closes in {duration}!" (the name up to its first comma), with a drawn arrow toward the tickets; the soonest such run's.
    - when the companion hint applies (HNT-R170), the **hint slip** under the note: dashed in oxblood, the companion's mark, the hint's lines in handwriting, and **Get it** and **Dismiss**;
    - **"On now {n}":** one **wager ticket** per run on (HNT-R160), 52 high: a perforated **stub** holding the run's **time dial** (HNT-R167) with the duration left in it ("42m", "2d 21h", in red within the closing-note time), the **event mark** (HNT-R166), the name (a holiday run adds its tag's name on a green tag after it, and the name is cut before the tag is), "{source mark} {zones} · until {weekday} {time}", and "needs skill {n}" when short of skill (HNT-R156); at the right, one pip per Hunt, inked bronze once that Hunt reached tier 1, over "{done} of {n} first marks". Once settled, a red **SETTLED** stamp takes the pips' place; the dial stays, in grey. A run that has just ended this session greys out, its name struck through, "closed" in its stub and "closed {weekday} {time}" in its line, until the board is closed. The chosen ticket has an oxblood rim and points to the entry. *Decided while writing the spec (#289): the just-ended ticket lives only until the board closes, so there is still no list of past runs.*
    - **"Ahead {n}",** captioned "posted, and may change before it opens": one **dashed row** per run ahead, 38 high: its mark, name, zones (and "needs skill {n}"), and at the right "opens {weekday} {time}" over "for {length}". A withdrawn run ahead simply drops from the list on the next refresh; the caption has said it may.
    - rows are laid top down until the next would reach the ladder; then "+{n} more on the table" takes the last row's place. Four tickets, two ahead rows and the ladder fit;
    - with no run on or ahead, a dashed box with a plain mark: "No wagers on the table, and none posted ahead. The rotation puts one on at the next turn."
    - at the foot, **the ladder:** "The ladder" and "{count} wagers settled · {n} more for {title}", over a rail with posts at 25, 50 and 100, each pressed in oxblood once reached, with its title under it, and the Angler's token on the rail at the count. The rail's share for a count is 0 at 0, ⅓ at 25, ⅔ at 50 and 1 at 100 and beyond, straight between within each step (a third of the rail to each step), with the posts at ⅓, ⅔ and 1; the website draws the same rail (pagle-backend's ANG-R77), so it changes only with it. The titles and the line's wording are the website's too (HNT-R178), so they don't change here.
  - **right page:** the selected run's entry (HNT-R163); the first ticket's run by default.

  *Defaults chosen while building (#303):* a holiday tag's name is interface text in `ns.L`, keyed by tag ID; past the last mark the ladder's line is "{count} wagers settled". A closed ticket can't be chosen, and when the run chosen closes the first open ticket's run shows. With no ticket chosen (the ribbon, or "Pagle Wagers" from the spread) the breadcrumbs stop at "Pagle Wagers"; from the Board, "Pagle Wagers" opens the spread on the run selected there. "Just ended this session" is a run seen on while the board was open in this showing (any spread) whose end has passed. The page turn counts the Pagle Wagers spread between the Board and the first set (BOOK-R34). In the shell's ribbon geometry the whole row (Board, Pagle Wagers and five sets) hangs under the board, so its fit to the screen counts the board itself (BOOK-R3).

  *Decided with the dev for the Wagers redesign:* the spread moves only with Animations on (SET-R30), in two ways, the kit's `art.json` › `motion`: when a run settles while its ticket shows, its SETTLED stamp is pressed (from 1.6 times its size and clear to its size, 0.22 s, easing in) and the ticket nudges a unit down and back (0.12 s); and when the settled count changes while the spread shows, the token and the rail's fill slide to the new share (0.45 s, easing out). The time dial never moves (HNT-R167). With Animations off, or with the spread drawn afresh, each settles at once, and every state reads from its words, inks and stamps alone.
- **HNT-R163** **A run's entry** (right page):
  - kicker, with its source mark: "From the rotation · {band} waters" or "Sent by the companion";
  - the event's name, large (up to three lines), and its **event mark** (HNT-R166) at the top right, with the wax seal pressed over the mark's lower right once settled: "Settled", then the short date;
  - the **time block:** the run's time dial (HNT-R167), then "closes in {duration}" in red handwriting ("settled, and still open" once settled) over "until {weekday} {time} · {length} in all"; for a run ahead the dashed dial, "opens {weekday} {time}" and "until {weekday} {time} · {length} on the table";
  - **chips:** each zone (the player's own zone with "you're here"), "needs skill {n}" in pencil when short of skill (HNT-R156), and a holiday run's tag's name on green;
  - the event's note in handwriting;
  - for each of its Hunts, in definition order: its **shape glyph** (inked oxblood once it has its first mark), its name and, at the right, "{count} / {next threshold}"; its shape and target line ("Timed · Darkshore Grouper, 22:00–04:00", HNT-R54 and HNT-R53) and its tier diamonds (HNT-R64), each in its trim once reached; an ink bar toward the next threshold (oxblood once it has its first mark); and for a Timed Hunt its window's state in italic, "open now, until {time}" in green or "opens at {time}, in {duration}";
  - "{n} Casts in these waters this run · {done} of {count} first marks";
  - two boxes: "Paid so far" with "+{xp} XP · {coins} Coins", and "Settle it" with "+250 XP · 25 Coins" (from Tunables), or "Settled" with "paid out" once settled. A box that pays Refreshes (HNT-R117) shows them as "+{n} Refresh" or "+{n} Refreshes" in red handwriting on the label's row, at the box's right: "Paid so far" the Refreshes the run has paid, "Settle it" the run's. A run ahead has neither line nor boxes;
  - the pay rule in small italic: "Each Hunt's first mark pays +150 XP and 8 Coins, each tier after it +100 XP and 5 Coins, and settling the wager +250 XP and 25 Coins more." (from Tunables), then "A Hunt's third mark also pays 1 Refresh, and settling the wager 1 more." (HNT-R117). When one of the two counts is 0 the sentence names only the other ("Settling the wager also pays 1 Refresh."), and when both are 0 it is left out.

  An event Hunt has no pin toggle and no set line. The entry never scrolls: with five Hunts the rows tighten and the window lines are left out (each window stays in its target line); and laid top down, while it would end more than half the page's bottom margin below its drawable area, it leaves out the pay rule first (its words become the boxes' tooltip), then the Casts line, then the window lines. A typical run of four Hunts with a Timed one keeps everything but the pay rule. While the projection is updating, "Updating from your Catch log…" heads the rows, which show faded; the Casts line and the two boxes wait until it is done, as their numbers aren't current yet; and the tickets read "updating…" for their marks. With no run at all: "Nothing to read yet" and "When a wager goes up it will be written here: its waters, its Hunts and what it pays.", then the pay rule.

  *Default chosen while building (#302):* an event Hunt's shape is read from its definition, the first that fits: "Timed" with a `time` condition, "Big ones" with `minBand`, "Quality" for `quality.uncommon` or `quality.rare`, "Haul" for `species.any`, else "Named fish". *Decided while building (#302):* "{n} Casts in these waters this run" is the most effort Casts any of the run's Hunts counted, as the projection keeps effort per Hunt and a Hunt with no condition beyond the event's zones counts every Cast there; The ▸ at a WAGERS row's end (HNT-R161) is the client's submenu arrow texture tinted oxblood, as the fonts lack the glyph (CORE-R9).
- **HNT-R164** The breadcrumbs read "Hunts › Pagle Wagers › {event name}". Opening the board on a run (from the tracker or the strip) turns to the Board ribbon with that run selected.
- **HNT-R165** The nameplate (HNT-R61) counts ladder titles with the set titles in "{n} titles". *Decided while writing the spec (#289): the completed-run count shows on the ladder, not the nameplate.*
- **HNT-R166** **The event mark.** Each event is marked by a roundel drawn from its tags alone (DATA-R97), so it needs no art of its own and a pushed event gets one too: its sky from the time tag (night, day or dusk; a plain sky with none), its water from the water tag (coast, lake, river or pool; open water with none), a brass ring, and for a holiday tag that holiday's charm at the ring's lower right. The layers and their order are the Pagle Wagers kit's (`art.json` › `mark`); the website draws the same mark from the same tags. It shows on the tickets (34), the ahead rows (24), the entry (66) and the empty box (54, faded), and on the Board on the wager strip (26) and the WAGERS group's rows (22, HNT-R161).
- **HNT-R167** **The time dial.** A run on shows the share of its length still to go as a ring that empties clockwise from the top, in 36 steps (the step is the share rounded up, at least 1 while the run is on): oxblood, red within the closing-note time (Tunables), grey once settled, empty once closed. A run ahead shows a dashed ring. The dial only repeats what its words say ("closes in …"), so nothing rests on it alone; it steps at each refresh (HNT-R42) and never animates.

### The companion hint

- **HNT-R170** The **companion hint** applies while the hint switch (Tunables) is on, the companion state (PUSH-R15) is `"missing"` or `"notRunning"`, and the player hasn't dismissed it (`PagleHuntsDB.profile.companionHint`). Its lines:
  - missing: "New wagers are out there. The Pagle companion brings them: more XP, more Coins, and the Sonar Scope toast style.", then "Installed it just now? Log out to character select once.";
  - not running: "The Pagle companion isn't running. Start it to get this week's wagers.";
  
  with **Get it**, which shows the companion's address in a copyable box (as the Field report's link, REP-R40), and **Dismiss**. It shows on the wager strip (HNT-R161) and as the hint slip on the Pagle Wagers spread (HNT-R162). Dismiss hides the hint and the Nod until Settings › Announcements turns "Remind me about the Pagle companion" back on (SET-R32).

  *Defaults chosen while building (#305):* the address is a placeholder Tunable until it is decided (#289). Get it opens a small slip over the board, "The Pagle companion", with the address selected in a read-only edit box and "Ctrl+C to copy"; whatever is typed is put back, and Esc, Enter or Close shuts it, as does closing the board. On the strip, Get it and Dismiss sit at the right of the hint's first line and its lines wrap beside them; on the hint slip, they sit at its foot.
- **HNT-R171** **The weekly Nod:** while the hint applies, at most once every 7 days (Tunables, `PagleHuntsDB.profile.lastHintNod`), at the first `PLAYER_ENTERING_WORLD` of a login once `PushedContentReady` has fired, Hunts raises a `nod` (`kind = "companionHint"`) with `text` the hint's first line (HNT-R170), except while the companion is missing, when the Nod has its own short line, "New wagers are out there. The Pagle companion brings them: more XP, more Coins." (the hint's first line is longer and names the Sonar Scope, which would not fit a Nod's one line), no `cast` and no Coins. Clicking it opens the board on the Pagle Wagers spread (the moment's `onClick`, ANN-R20). Its `pastText` is the same line.
- **HNT-R172** At 1.0 the hint switch is **on**: the hint, its Nod, the hint slip, the tracker's line and the Settings row (SET-R32) all show while the hint applies (HNT-R170). With the switch off there is no hint, no Nod, no hint slip, no tracker line and no Settings row; the state is still read, and pushed runs are still used if a file passes its check. *Decided for 1.0, once Core's reader was built and M8's tickets closed: [#288](https://github.com/timemir/pagle-addon/issues/288) had it off until `Pagle_Content` worked end to end. The switch stays a Tunable, so a release can turn it off again.*

### The Pagle Wagers tracker block

- **HNT-R175** The Hunts tracker (HNT-R75) shows, above its "Hunts" block, a **"Pagle Wagers"** block while any run is on: its collapsible header, then two lines per run on (at most 3, Tunables, then "+{n} more wagers on the table"): first the event's name and, at the right, "settled" or "ends in {duration}" (HNT-R51), the latter in red while the run, not settled, closes within the closing-note time (Tunables); second, its Hunts' progress as "{done} of {n} first marks" and the closest unfinished Hunt as "{Hunt}: {count} / {next threshold}". Clicking a run opens the board on it (HNT-R164).

  *Default chosen while building (#304):* the closest unfinished Hunt is the one without its first mark that has the largest share of it, ties in definition order (`RunProgress`), so its next threshold is its first mark. A settled run's second line reads "{n} of {n} first marks" alone. While the projection updates, the second line reads "updating…" and the label counts down (HNT-R78). "+{n} more wagers on the table" opens the Pagle Wagers spread. Both blocks sit on the one tracker frame's paper.

  *Decided with the dev from the prototype ([#375](https://github.com/timemir/pagle-addon/issues/375)):* in every tracker look, each run's first line has its **time dial** (HNT-R167), 14 across and without words, where a Hunt's line has its dot and centred on it, so the name doesn't move; it replaces the oxblood dot each run had. In a dark look (No frame, and the expansion's dark frames) the red of a closing run's label is a bright red that reads over the world; on paper, the now line's red.
- **HNT-R176** While the hint applies (HNT-R170) and no run is on, the block shows one line, "Pagle companion not running" or "New wagers with the Pagle companion", with "why?" opening the Pagle Wagers spread.

  *Default chosen while building (#305):* the line sits under the block's "Pagle Wagers" header, which folds it away as it folds the runs (HNT-R177), with "why?" at its right; it counts nothing down, so it asks for no refresh (HNT-R42).
- **HNT-R177** The block has its own collapsed state (`profile.tracker.wagersCollapsed`); it follows the tracker frame (HNT-R79) and the "Show the Hunts tracker" setting.

### The tracker

- **HNT-R75** Hunts docks one tracker with `M:RegisterTracker{ id = "hunts", order = 10, frame }` (CORE-R70): an objective-tracker-style block in the books art kit's type, with a collapsible "Hunts" header. It shows while its setting is on (default on), whether or not anything is pinned.
- **HNT-R76** It lists pinned current Hunts, sorted as on the board across groups (Now, Soon, Later, On demand), at most 6 Hunts (Tunables), then a "+N more" line. Each Hunt has two lines:
  - first: a dot in its group's colour (Now green, Soon amber, Later grey, On demand blue), the Hunt's name and, at the right, its tracker label (HNT-R51)
  - second: the target line, "you're here" when the live zone is one of its zones, and its tier progress, "{count} / {next unreached threshold}" ("0 / 1" before completion), or "all tiers" once finished
  
  With nothing pinned it reads "Pin a Hunt to keep it here."
- **HNT-R77** Clicking a Hunt's lines opens the board on that Hunt (HNT-R67); clicking "+N more" or the empty line ("Pin a Hunt to keep it here.") opens the board. Clicking the header collapses or expands it; the state is saved. A sample tracker (HNT-R121: the Curio Shop's and the Fish Journal Collection's previews) has none of these clicks and no mouse on any of its parts: a click on it reaches what is under it.
- **HNT-R78** While the projection is updating, progress reads "updating…". While restricted, the tracker keeps its last grouping (HNT-R43).
- **HNT-R79** The tracker's frame wears the equipped tracker frame (`Pagle.GetEquipped("hunts.trackerframe")`) and redraws on `AppearanceChanged` for that slot.

### Pins and the completed filter

- **HNT-R80** Any current Hunt can be pinned or unpinned from its entry. Pins have no limit. A pinned Hunt sits at the top of its group (HNT-R44), always shows on the board whatever the filter, and is listed on the tracker.
- **HNT-R81** Pins are a setting in `PagleHuntsDB.profile.pins`, not Module records: they decide nothing a rebuild needs. A pin on a Hunt that isn't current (retired, or no longer in the Hunt list) is removed when the Module loads and at the regroup that finds a Hunt retired (HNT-R42). A Hunt whose `since` is still ahead can't be pinned, because it isn't shown.
- **HNT-R82** With "show completed" off (the default), the board's groups leave out finished Hunts (every tier reached, HNT-R17) unless pinned. Done Hunts with tiers left always show. The set page's checklist ignores the filter. The filter state is saved.

### Moments

- **HNT-R85** Hunts raises moments only from a `"live"` apply (LOG-R73), from its regroup (HNT-R88), or as `summaryOnly` moments from `done` (HNT-R112). Each Hunt tier and each set title is raised at most once, guarded by the celebrated set (HNT-R90).
- **HNT-R86** The moments:

  | Moment | `rung` | `kind` | `title` | `text` | `stamp` | `icon` | `coins` | `seal` |
  |---|---|---|---|---|---|---|---|---|
  | Hunt completed (tier 1) | `toast.high` | `huntCompleted` | "Hunt complete" | the Hunt's name | "Hunt" | the item ID of the Catch that reached it | 30 | |
  | further tier | `toast.high` | `huntTier` | "{Trim} tier" ("Silver tier") | "{Hunt name} · {threshold} caught" | the trim ("Silver") | the item ID of the Catch that reached it | 15 | |
  | set title | `banner` | `huntSetTitle` | "Title earned" | the title | "Title" | `Trade_Fishing` | 100 | `"quill"` |
| event Hunt, tier 1 | `toast` | `wagerMark` | "Pagle Wagers" | "{Hunt name} · first mark" | "Mark" | the item ID of the Catch that reached it | 15 | |
| event Hunt, further tier | `toast.low` | `wagerTier` | "{Trim} mark" | "{Hunt name} · {threshold} caught" | the trim | the item ID of the Catch that reached it | 10 | |
| run completed | `toast.high` | `wagerSettled` | "Wager settled" | the event's name | "Settled" | the event's icon (HNT-R161) | 50 | |
| ladder title | `banner` | `wagerTitle` | "Title earned" | the title | "Title" | `Trade_Fishing` | | `"quill"` |
| companion hint | `nod` | `companionHint` | "Pagle Wagers" | HNT-R171 | | `Trade_Fishing` | | |

  Two wager moments carry a `tickets` count beside their Coins (HNT-R117): a further mark at tier 3, and a settled run. No other moment does.

  *Decided while writing the spec (#289): the rungs for the wager moments. A first mark is a `toast` and a later one `toast.low`, since runs repeat; a settled run is `toast.high`; a ladder title is a `banner`, like a set title.*

  A moment raised in a live apply for a Catch of the Cast being applied carries `cast` = that Cast's entry ID, so Core merges it with every other moment of that Cast (ANN-R10). A Catch that crosses several tiers or Hunts raises one moment for each. A `summaryOnly` moment carries no `cast`. `seal` is what the banner's wax seal shows ([core/announcements.md › Contracts](core/announcements.md#contracts)).
- **HNT-R87** A set title **from a Catch** (HNT-R23) rides on that Cast. A title **from a retirement** is stored with `fromRetirement = true` and is always raised with `summaryOnly = true`: right away when a live apply finds it, otherwise from the next `done` (HNT-R112). It never goes into a Write-up section, except at a first build, which marks everything celebrated (HNT-R111).
- **HNT-R88** **Window moments** are opt-in (setting off by default) and for pinned Hunts only.
  - **Baseline:** every regroup records, in memory, whether each current Hunt's `NextWindow` result is `openNow`, pinned or not.
  - **When:** a regroup finds a Hunt that is pinned now, `openNow` now, and recorded as not `openNow` at the previous regroup: its time window opened, or its event started on the live calendar.
  - **Not raised** for the first grouping after login (it only sets the baseline), for a Hunt with no previous record (it just became current), for an aura starting, for a skill change, or for a Hunt short of skill. Pinning a Hunt that is already open raises nothing. The first regroup after a restriction compares against the last regroup before it.
  - **The moment:** a `nod` with `kind = "huntWindow"`, `title` "{Hunt name} is open", `text` its tracker label, and the Hunt's icon. It has `expiresAt` = `closesAt`, none if unknown, and `pastText` "{Hunt name} window opened {from}–{to}" in realm clock, where `{from}` is when the regroup found it open; "–{to}" is left out when `closesAt` is unknown. It has no `cast` and no Coins.
- **HNT-R89** Hunts keeps one Session summary line, `M:SetSummaryLine("hunts", …)`, with lifetime numbers: "Hunts: {done} of {current} done · {n} titles", adding " · {r} wagers settled" once the completed-run count is above 0 (HNT-R148). {done} counts current Hunts that are done, {current} counts current Hunts, and {n} counts earned titles. It is set at the redraws of HNT-R42, which include the `since` and `retired` timers, but never while the projection is updating; the first time after login is from `done`.

### Celebrated set, Coins and the Write-up

- **HNT-R90** The **celebrated set** (LOG-R77), in `PagleHuntsDB.global.celebrated`, holds for each Standing Hunt the highest tier already shown and each set title already shown; for each run, by run key, each event Hunt's highest tier and whether its completion was shown (HNT-R92); each ladder title already shown; and each earned good once its rule held (HNT-R122). Core never touches it, and a rebuild never clears it.
- **HNT-R91** In a live apply, a newly reached tier or title above the celebrated set raises its moment (HNT-R86) and is added to it. One already celebrated raises nothing.
- **HNT-R92** The celebrated set's run entries grow by a few dozen bytes per run, so `done` drops the entries of runs that ended more than 30 days ago (Tunables). A rebuild raises nothing for a run that ended more than 30 days before now: what it earned counts in the totals only. *Decided while writing the spec (#289): the pruning age, so a content update's rebuild never floods the Session summary with old runs.*
- **HNT-R110** Hunts pays Coins: for a Standing Hunt, 30 when it completes and 15 for each further tier; 100 for each set title; for an event Hunt, 8 at tier 1 and 5 for each further tier, and 25 for each completed run, all paid again in every run (HNT-R145). Ladder titles pay no Coins. Its lifetime total is the projection's `coins`, the sum over every reached tier, completed run and earned title, Retired Hunts and ended runs included. It reports the total with `M:ReportCoinsEarned` from `done` after every catch-up or rebuild, and after each live entry that changes it (SHOP-R2).
- **HNT-R113** Hunts pays **Activity XP** (ADR 0011, [core/activity-xp.md](core/activity-xp.md)): a Standing Hunt pays 500 XP at tier 1 and 250 for each further tier, once each, Retired Hunts included. Set titles pay none.
- **HNT-R114** An event Hunt pays 150 XP at tier 1 and 100 for each further tier, and a completed run 250 more, all paid again in every run. Ladder titles pay none. Amounts are by tier position, from the Tunables, never per event, so a change is one row.
- **HNT-R115** The lifetime total is the projection's `xp`, the sum of HNT-R113 and HNT-R114 over everything reached. Hunts reports it with `M:ReportXPEarned` on the same timing as Coins (HNT-R110, AXP-R2), and its `logic/` gives the same total from the state alone as `ActivityXPEarned(state)`, for Pagle's backend (AXP-R9). No moment shows XP; a level-up it brings is the Ledger's (LED-R39).
- **HNT-R116** Hunts earns **Refreshes** (ADR 0017, [core/refresh.md](core/refresh.md)) from Pagle Wagers only: 1 when an event Hunt reaches tier 3 in a run (`TICKETS_TIER3`), once per Hunt per run, and 1 when a run completes (`TICKETS_RUN`, HNT-R146), once per run, both paid again in every run (HNT-R145). They are credited where the Coins and Activity XP of the same tier and run are, in `apply` (HNT-R137 step 2 and step 3) and in the credit of a run record's earlier Casts (HNT-R149), so a rebuild reproduces them. A Standing Hunt, of any tier, a set title and a ladder title earn none (REF-R1). The lifetime total is the projection's `tickets`, which Retired Hunts' and ended runs' count in; Hunts reports it with `M:ReportTicketsEarned` on the same timing as Coins (HNT-R110, REF-R2): from `done` after every catch-up or rebuild, even when unchanged, and after each live entry that changes it. Its `logic/` gives the same total from the state alone as `TicketsEarned(state)`, for Pagle's backend (REF-R9). The starting counts (1 and 1, up to 5 a run of 4 Hunts) are Tunables the calibration ticket ([#402](https://github.com/timemir/pagle-addon/issues/402)) sets, so a change is two constants and the rules version (HNT-R138). *Decided while building (#405): a Hunt "reaching tier 3" is its third tier, whatever its threshold, and a fourth or fifth tier pays none.*
- **HNT-R117** The Refreshes show where the run's Coins do. A settled run's moment (`wagerSettled`) carries `tickets = TICKETS_RUN` and a tier-3 mark's moment (`wagerTier` at tier 3) carries `tickets = TICKETS_TIER3` (HNT-R86), so Core sums them per Announcement into its "Refresh +N" stamp (REF-R7); a count of 0 leaves the field out. A first or further mark below tier 3, a ladder title and the Standing Hunts' moments carry none. A summary-only moment carries them too. The run's entry on the Pagle Wagers spread shows them in its pay boxes and its pay rule (HNT-R163). The Write-up and the Session summary have no Refresh line in 1.0 (REF-R7).
- **HNT-R111** In `done` (LOG-R76):
  - `info.firstBuild`: Hunts marks every reached tier and earned title as celebrated and raises one Write-up section headed "Your Hunts were written up from {n} Casts" ({n} = Casts applied), if anything was earned, with lines "{n} Hunts completed", "{n} further tiers", "{n} wagers settled", one "Title: {title}" per earned title, "Pagle Coins +{n}" and "Angler XP +{n}"
  - `info.replayed > 0`: the same lines for what the replayed entries earned that wasn't celebrated, under "While Hunts was off", and marks them celebrated; nothing if they earned nothing

  "{n} Hunts completed" and "{n} further tiers" count Standing Hunts only: an event Hunt's marks have no line of their own and show in the Coins and XP lines, so a section can hold only those two. A ladder title is a "Title: {title}" line after the set titles. A catch-up's section leaves out a run that ended more than 30 days before now (HNT-R92). *Decided while building (#301): how the wager lines fit the section, which the spec didn't say.*
- **HNT-R112** In `done` after a rebuild that isn't a first build (a new content fingerprint, Hunt list or rules version), every reached tier or earned title not yet celebrated is raised as its moment (HNT-R86) with `summaryOnly = true`, then marked celebrated. In `done` after a catch-up, every uncelebrated title with `fromRetirement` is raised the same way, and left out of the "While Hunts was off" section. A rebuild that runs because Hunts was re-enabled after a release raises these summary-only moments instead of a "While Hunts was off" section. Tiers the rebuild no longer finds (possible only before 1.0, when definitions change freely) leave the celebrated set alone and simply stop showing.

### Goods

- **HNT-R120** Hunts registers one slot (SHOP-R21), `hunts.trackerframe`, label "Hunts tracker frame", category "Trackers": the tracker's frame. The board's binding is Core's (`core.binding`, SHOP-R25, ADR 0015), which every book wears; Hunts adds only its earned bindings to it (HNT-R122).
- **HNT-R121** Its goods (tiers tunable, SHOP-R22):

  | Slot | Goods |
  |---|---|
  | `hunts.trackerframe` | `hunts.trackerframe.none` (default: the plain native block, no frame), `hunts.trackerframe.inkwash` (tier 1), `hunts.trackerframe.waxseal` (tier 2); `hunts.trackerframe.slate` (tier 1), `hunts.trackerframe.mapscrap` (tier 1), `hunts.trackerframe.bounty` (tier 2), `hunts.trackerframe.spyglass` (tier 3), `hunts.trackerframe.wagerribbon` (earned) |

  The tracker frames follow the Tackle Board's and Stats' (a free "No frame" and two for sale at tiers 1 and 2). Each good's name and description is lore (HNT-R130); the working names are No frame, Ink Wash and Wax Seal. Its `preview` draws a sample tracker with two fixed lines ("Night Run · in 37m", "Rack Hour · on demand") in that frame. A good's icon is its swatch. The notebook covers that Hunts sold are Core's bindings now (`core.binding.<key>`, SHOP-R25), and Saddle Leather is gone: Field Leather is every book's default. The tracker frames are the kit's: No frame is the block in the kit's type over the world, Ink Wash a paper sheet written in blue ink, Wax Seal a parchment with a red-edged margin and a wax seal, each in its own type and inks, and the papers grow with the tracker's lines. IDs may still be renamed before 1.0.
- **HNT-R122** Hunts registers its slots and goods in `OnInitialize`, right after `RegisterModule`. Its earned goods are owned when: Night Watch (`hunts.soundset.nightwatch`), every set’s title earned (HNT-R20), `earnedText` "Finish every Hunt set"; Pathfinder's Calf (`hunts.binding.pathfinder`), any set’s title earned (HNT-R20), `earnedText` "Finish a Hunt set"; Five-Set Seal (`hunts.binding.fiveseal`), every set’s title earned (HNT-R20), `earnedText` "Finish every Hunt set"; Winner's Brocade (`hunts.binding.wagersilk`), ten completed Hunt Event runs (the completed-run count, HNT-R148; a run counts once completed, HNT-R146, not merely joined), `earnedText` "10 Wager runs completed"; Winner's Ribbon (`hunts.trackerframe.wagerribbon`), ten completed Hunt Event runs (the completed-run count, HNT-R148; a run counts once completed, HNT-R146, not merely joined), `earnedText` "10 Wager runs completed"; and the epic toast styles (ANN-R85, #415), in Core's toast style slot, earned by the achievement alone, with no price: **Nightfin Tide** (`hunts.toaststyle.nightfin`), any three different Hunts, each at its last tier (tier 3) in some run, of the night Wager events `darkshore_moonlight`, `felwood_moonglade`, `dustwallow_marsh_night`, `deadwind_pass_night`, `eastern_plaguelands_night` and `tirisfal_silverpine_dusk` (two may come from one event; one Hunt that reached tier 3 in two runs counts once), `earnedText` "Tier 3 in three night Wager Hunts"; **The Deep Trench** (`hunts.toaststyle.trench`), one run of `azshara_lobster` in which every Hunt of the event reached tier 3 within that run (the Hunts of different runs don't add up), `earnedText` "Tier 3 in every Hunt of the lobster Wager"; **Nat's Study** (`hunts.toaststyle.study`), 100 completed Hunt Event runs (the completed-run count, HNT-R148), `earnedText` "100 Wager runs completed". A tier reads as the most of the projection's run and the celebrated set's run entry (HNT-R90), so a rebuild or a pruned run entry never lowers it. Each is checked against the projection and the celebrated set (HNT-R90) together, and once its rule holds it is noted in the celebrated set's `goods` (after a live entry that earns a set title or completes a run, and in `done`), so a good once earned is never lost, as the Ledger keeps its earned goods (LED-R116): not when a rebuild no longer earns it, and not when a release adds a set whose title isn't earned yet (Five-Set Seal and Night Watch). Hunts calls `M:RefreshGoods()` after a live entry that earns a set title, completes a run or reaches an event Hunt's last tier (tier 3, `ns.TOP_TIER`: the epic styles' rules read nothing lower) in a run, and from `done` (SHOP-R31); a mark found by a replay or rebuild calls nothing.
- **HNT-R123** Night Watch (`hunts.soundset.nightwatch`) is an earned good in Core's sound set slot (SHOP-R23, SHOP-R25); Core plays it (ANN-R72). Nightfin Tide, The Deep Trench and Nat's Study are earned goods in Core's toast style slot, registered after Night Watch; Core draws them from its own art (ANN-R85), so they have no `preview`, and each one's icon is a game icon (`Spell_Nature_Moonglow`, `Spell_Frost_SummonWaterElemental`, `INV_Misc_Book_09`). Pathfinder's Calf, Five-Set Seal and Winner's Brocade are earned goods in Core's binding slot, registered before Night Watch; Core draws them on every book and on the shop's stage, from its own art and look (ADR 0015, SHOP-R25), so they have no `preview`, and each one's icon is its material in Core's media (`Interface\AddOns\Pagle\media\books\bindings\<key>`). The expansion's tracker frames are the Curio Shop expansion kit's: each a three-slice panel in the `TrackerFrames2` atlas with its insets and inks.

### Lore

- **HNT-R130** Hunts' lore ID is `hunts` (DATA-R100). Its keys:
  - from `data/hunts/hunts.toml` (DATA-R105): `hunt.<id>.name` and `hunt.<id>.note` for every Standing Hunt, `set.<id>.name`, `set.<id>.title` and `set.<id>.note` for every set
  - from `data/hunts/events/` (DATA-R97): `event.<id>.name` and `event.<id>.note` for every pooled event, and `hunt.<id>.name` for each of its Hunts
  - from `data/lore/hunts.toml`: `ladder.<n>.title` for the completed-run titles at 25, 50 and 100 (HNT-R148; 25 is "Bookmaker's Bane")
  - a pushed definition carries its own `name`, `note` and Hunt names in its fields (HNT-R154), checked by the same limits (DATA-R99) before it is pushed
  - from `data/lore/hunts.toml` (Pagle_Hunts' lore file under DATA-R100's one-file-per-addon rule): `huntgood.<goodID>.name` and `huntgood.<goodID>.description` for every good of HNT-R121 (its eight tracker frames), its three earned bindings, Night Watch and its three toast styles, its goods in Core's slots (HNT-R123). Lore kinds belong to one addon (DATA-R102) and Core owns `good`, so Hunts uses its own kind `huntgood`, listed in `data/lore/manifest.toml` as `[hunts.huntgood] fields = ["name", "description"]` with those IDs (DATA-R106).
  
  The kinds `hunt`, `set`, `event`, `ladder` and `huntgood` are Hunts'. Pagle Wagers wording ("settled", "on the table", "the house pays out") goes to the lore pass's voice check against HNT-R27's no-odds rule ([#284](https://github.com/timemir/pagle-addon/issues/284)). The generator emits both sources into the one `addons/Pagle_Hunts/data/Lore.lua` (DATA-R104). The Hunts lore check (`hunts` in `data/checks.toml`'s `lore` list, DATA-R66) is switched on in M5. It runs DATA-R105's checks on the `hunt` and `set` keys, which aren't listed in the manifest (their IDs are the Hunts and sets in `hunts.toml`), and the full DATA-R107 checks on `huntgood`, with the `name` limit for names and no limit for descriptions. Every other Hunts string (labels, chips, headings, moment titles, weekday and month names) is interface text in `ns.L`, not lore.

### Registration and projection

- **HNT-R135** In `OnInitialize`, Hunts calls `Pagle.RegisterModule` with `name = "Hunts"`, `title = "Hunts"`, `order = 20`, one view `{ id = "board", label = "Hunts", open = <toggle the board> }` and one slash entry `{ name = "hunts", fn = <toggle the board>, help = "Open or close the Hunts board" }`. If it returns `nil` (CORE-R13), the Module stops.
- **HNT-R136** Hunts runs one projection with `M:NewProjection` (LOG-R70): `db = PagleHuntsDB.global.projection`, `rulesVersion` = the Hunts rules version (Tunables), `extraFingerprint` = `ns.huntList.fingerprint` joined with `ns.eventList.fingerprint` (DATA-R72, DATA-R98). Its `apply` reads Cast records and its own `run` and `def` Module records (HNT-R150, HNT-R154); every other kind is ignored. Hunts appends Module records only for runs and pushed definitions.
- **HNT-R137** For each Cast, `apply`:
  1. adds 1 to `casts`
  2. updates every Hunt that exists at the Cast's `time`, Standing Hunts and the event Hunts of each known run on at that `time` (HNT-R144): first the effort counter (HNT-R25, HNT-R26), then each qualifying Catch in loot-slot order (count, tiers, Coins, XP, HNT-R15)
  3. checks the set titles (HNT-R23), then each run on at that `time` for completion (HNT-R146) and the completed-run count for a ladder title (HNT-R148)
  4. in `"live"` mode only: raises the moments for what is newly reached (HNT-R91), then reports Coins, Activity XP and Refreshes if they changed (HNT-R110, HNT-R115, HNT-R116)

  A `run` record adds the run to `runs` (HNT-R150) unless it overlaps a known run of the same event; a `def` record adds a part to `defs` (HNT-R154). Neither counts as a Cast.

  Waters, classes, window specs and the Cast index (HNT-R139) are worked out once per load (HNT-R30); the catalogue and Hunt list can't change without a reload, and a change rebuilds the projection.
- **HNT-R138** The rules version rises whenever a rule here changes what the projection holds (qualifying, tiers, titles, runs, effort, Coins, XP, Refreshes).
- **HNT-R139** **The Cast index.** So that `apply` doesn't test every Standing Hunt on every Cast (HNT-R137 step 2), Hunts files each Hunt of the list under what a Cast must have for that Hunt to change it. It builds this index from the Hunt list, the Hunts' waters (HNT-R30) and the class members, the first time a Cast needs it after a load. The index is no rule: it never drops a Hunt that could match, so the projection holds exactly what it would hold if every Hunt were tested, and the rules version doesn't rise for it (HNT-R138).
  - An imposed Hunt whose conditions name `auras` (Rack Hour, Hut Hour) is filed under those auras, and one whose conditions name `areas` under those areas. Its conditions gate its effort (as its board spec, HNT-R6) and its Catches (HNT-R5) alike.
  - Any other Hunt is filed in two ways. For effort (HNT-R25), it goes under its waters, or, for an imposed Hunt without waters or `areas`, in an always-tested list. A Hunt with no board spec, and a natural Hunt with no waters, has no effort. For a qualifying Catch (HNT-R10), it goes under its target Species, or under each member of its target class.
  - A Cast is tested only against the always-tested Hunts and the Hunts filed under its zone, its subzone, an aura it was under, and, if it caught anything, each Catch's item or that item's Species. Those Hunts are tested in list order, as before.

## Data

### The Standing Hunt list

`data/hunts/hunts.toml` ships 16 Standing Hunts in 5 sets ([#286](https://github.com/timemir/pagle-addon/issues/286): House Wagers left the list and its four Hunts became pool events; [#430](https://github.com/timemir/pagle-addon/issues/430): Home Waters, a starter set, was added first), all with `since` = the pre-1.0 placeholder (DATA-R87) and no `retired`. Names, titles and notes are lore drafts for the M5 lore batch (DATA-R111). Every window opens daily or weekly, is a half-year season, or is player-started, and the only time field in Home Waters is Lantern Hours' 21:00–05:00 (a third of every day), so all pass the rarity cap (DATA-R92). No v1 Hunt has a `minBand`; the field is ready for later Hunts. Before the placeholder date no v1 Hunt is current: the board reads "No Hunts yet." and nothing counts. Tests inject their own Hunt list and `since` dates; in-game M5 checks run on or after the placeholder date.

| Set (`id`) · title | Hunt `id` | Name | Kind | Target | Window / conditions | Tiers |
|---|---|---|---|---|---|---|
| `home_waters` · the Dockhand; set note "Your first waters, close to home." | `home_waters` | Home Waters | imposed | class `species.any` | `areas` = the low zones | 1 / 25 / 100 |
| | `bloated_luck` | Bloated Luck | imposed | class `quality.uncommon` | `areas` = the low zones | 1 / 3 / 10 |
| | `mackerel_run` | Mackerel Run | imposed | species 6303 (Raw Slitherskin Mackerel) | `areas` = the low zones | 1 / 10 / 40 |
| | `lantern_hours` | Lantern Hours | imposed | class `species.any` | `areas` = the low zones, `time = { { 1260, 300 } }` (21:00–05:00) | 1 / 10 / 40 |
| `round_the_clock` · the Clockwatcher | `night_run` | Night Run | natural | species 13759 (Raw Nightfin Snapper) | `night` | 1 / 10 / 40 |
| | `first_light` | First Light | natural | species 13760 (Raw Sunscale Salmon) | `day` | 1 / 10 / 40 |
| | `live_wire` | Live Wire | natural | species 13757 (Lightning Eel) | `day` | 1 / 10 |
| | `armoured_after_dark` | Armoured After Dark | natural | species 13890 (Raw Plated Armorfish) | `night` | 1 / 5 |
| `turn_of_the_year` · of All Seasons | `summers_bass` | Summer's Bass | natural | species 13756 (Raw Summer Bass) | `summer` | 1 / 10 / 40 |
| | `winters_squid` | Winter's Squid | natural | species 13755 (Raw Winter Squid) | `winter` | 1 / 10 / 40 |
| `sunday_showdown` · the Tastyfish; set note "Extravaganza, requires level 60" | `tastyfish_haul` | Tastyfish Haul | natural | species 19807 (Speckled Tastyfish) | `event.301` | 1 / 10 / 40 |
| | `riggles_angelfish` | Riggle's Angelfish | natural | species 19805 (Keefer's Angelfish) | `event.301` | 1 |
| | `riggles_queenfish` | Riggle's Queenfish | natural | species 19806 (Dezian Queenfish) | `event.301` | 1 |
| | `riggles_racer` | Riggle's Racer | natural | species 19803 (Brownell's Blue Striped Racer) | `event.301` | 1 |
| `camp_hours` · the Hut Keeper | `rack_hour` | Rack Hour | imposed | class `quality.uncommon` | `auras = { 1280341 }` | 1 / 10 / 25 |
| | `hut_hour` | Hut Hour | imposed | class `species.any` | `auras = { 1280342 }` | 1 / 5 / 15 |

Home Waters is the starter set (#430): four Hunts a new character can finish at launch, with no skill need (HNT-R32). **The low zones** are the eleven zones whose skill base is −20 or less (the six starting zones and the five that follow them): 1 Dun Morogh, 12 Elwynn Forest, 14 Durotar, 141 Teldrassil, 215 Mulgore, 85 Tirisfal Glades, 40 Westfall, 38 Loch Modan, 148 Darkshore, 17 The Barrens and 130 Silverpine Forest. Each Hunt's `areas` is those eleven, and a subzone counts as its zone's (LOG-R48); each can be done by either faction in zones its own side can reach. The other 12 Hunts stay as they were; most are out of a new character's reach and show under "Later" with their skill need (HNT-R33).

The one fixed class: `fixed.oddity`, members 6522 (Deviate Fish) and 251524 (Whimsyfin), one for each faction's waters. It stays in `hunts.toml` for the pool's Barrens event (below).

The M5 build ticket checks every item and area ID above against `data/db2/` by its enUS name before the list is committed; the names in brackets are the intent, and a wrong ID is fixed in the table and the file together. The Camp Hunts use generated classes (item quality, or any fish) rather than an observed Rack or Hut catch list, so they work whatever the Rack and Hut turn out to add. Hut Hour targets `species.any`, not `quality.rare` (a spec decision, approved in #184): no catalogue item that isn't Noise is rare yet, so a `quality.rare` Hunt could never be done. If Live Wire or Armoured After Dark prove ungated on Forever, they fail admission (DATA-R92) and are retired (or, before 1.0, removed), keeping completions.

### The 1.0 event pool

`data/hunts/events/` ships **24 rotating Hunt Events**, 8 per skill band (HNT-R156), each one file (DATA-R97), so each comes round about every 72 days in the fallback rotation; seasonal events with `rotation = false` come on top, for the backend to schedule. Each has 3–5 Hunts in the shapes `propose-events.py` drafts (DATA-R99): a **Haul** (N of `species.any`), a **Named fish** (N of one listed Species), **Quality** (N of `quality.uncommon`), and an optional **Timed** one. There is no size shape: a Size band needs the Reach (ADR 0014), which an event's rotating players won't have built on its fish (HNT-R14). Tiers are suggested from the zone's loot shares so that, fishing there, tier 1 takes about 45 minutes, tier 2 about 2 hours and tier 3 about 4 (Tunables); a completed run then takes 2–3 hours over its 3 days. People curate every draft and write its lore; nothing uncurated ships ([#281](https://github.com/timemir/pagle-addon/issues/281)).

The first four are the old House Wagers, each the Timed Hunt of an event in its fish's waters ([#286](https://github.com/timemir/pagle-addon/issues/286)); their working names are the old Hunts', and their other Hunts and every tier come from the authoring step:

| Event `id` (working name) | Zones | Timed Hunt | Band |
|---|---|---|---|
| `darkshore_moonlight` (Grouper by Moonlight) | 148 (Darkshore) | species 12238 (Darkshore Grouper), `time = { { 1320, 240 } }` (22:00–04:00) | low |
| `duskwood_witching` (Witching Hour) | 10 (Duskwood) | class `species.any`, `time = { { 0, 180 } }` (00:00–03:00) | low |
| `barrens_oddities` (Oddity at Dusk) | 17 (The Barrens) | class `fixed.oddity`, `time = { { 1080, 1260 } }` (18:00–21:00) | low |
| `alterac_dawn_trout` (Dawn Trout) | 36 (Alterac Mountains, Mithril Head Trout's best share) | species 8365 (Mithril Head Trout), `time = { { 300, 480 } }` (05:00–08:00) | low |

All four fall in the low band, so the other 20 are 4 low, 8 mid and 8 high. Their lore (about 120 lines for 24 events, and the ladder titles at 50 and 100) is one batch, drafted from VOICE.md and signed off by the dev (DATA-R111, as #263 and #264 did).

### `PagleHuntsDB` (AceDB, account-wide, one shared `Default` profile)

| Key | Contents | Default |
|---|---|---|
| `profile.tracker.shown` | boolean | `true` |
| `profile.tracker.collapsed` | boolean | `false` |
| `profile.windowMoments` | boolean (HNT-R88) | `false` |
| `profile.showCompleted` | boolean (HNT-R82) | `false` |
| `profile.pins` | `{ [huntID] = true }` (HNT-R81) | `{}` |
| `profile.tracker.wagersCollapsed` | boolean (HNT-R177) | `false` |
| `profile.companionHint` | boolean: remind me about the companion (HNT-R170) | `true` |
| `profile.lastHintNod` | server time of the last companion Nod (HNT-R171) | `0` |
| `global.projection` | Core's projection table (LOG-R70) | |
| `global.celebrated` | `{ tiers = { [huntID] = highestTier }, sets = { [setID] = true }, runs = { [runKey] = { tiers = { [huntID] = highestTier }, settled = true?, endsAt } }, ladder = { [n] = true }, goods = { [goodID] = true } }` (HNT-R90, HNT-R92; `goods`, each earned good noted once its rule holds, made with the first, HNT-R122) | `{ tiers = {}, sets = {}, runs = {}, ladder = {} }` |
| `global.schemaVersion` | integer, for this DB's migrations | |

### Projection state

```lua
---@class HuntsState
---@field casts integer       -- Casts applied, for the Write-up heading
---@field coins integer       -- lifetime Pagle Coins earned (HNT-R110)
---@field xp integer          -- lifetime Activity XP earned (HNT-R115)
---@field tickets integer     -- lifetime Refreshes earned (HNT-R116)
---@field runs table<string, HuntRun>   -- by run key, every known run (HNT-R150)
---@field defs table<string, { parts: integer, texts: table<integer, string> }>  -- pushed definitions' parts by event ID: the count of parts the first record named, and each part's text, the first record of a part winning (HNT-R154)
---@field settled integer     -- the completed-run count (HNT-R148)
---@field ladder table<integer, integer>   -- ladder step (25, 50, 100) to the server time it was earned
---@field hunts table<string, HuntProgress>   -- by Hunt ID; absent until the Hunt has effort or a Catch
---@field sets table<string, { earnedAt: integer, date: { year: integer, month: integer, day: integer }, fromRetirement: boolean }>   -- by set ID, only once earned; date as HuntTier.date, or the retired date's UTC day (HNT-R23, HNT-R87)
---@field hours table<integer, integer>   -- server hour (time / 3600, rounded down) to the seq of the first Cast in it, for the last 14 days of Casts (HNT-R149)

---@class HuntRun
---@field event string
---@field start integer       -- server time
---@field end_ integer        -- server time (`end` in the record)
---@field source "r"|"p"
---@field hunts table<string, HuntProgress>   -- by the event's Hunt IDs, progress within this run, absent until the Hunt has effort or a Catch (HNT-R145)
---@field completedAt integer?  -- server time of completion (HNT-R146)

---@class HuntProgress
---@field count integer       -- qualifying Catches (HNT-R11)
---@field effort integer      -- effort Casts (HNT-R25)
---@field sinceLast integer   -- effort Casts after the latest qualifying Catch's Cast (HNT-R26)
---@field caught boolean      -- at least one qualifying Catch
---@field reached HuntTier[]   -- one per reached tier, in tier order

---@class HuntTier
---@field time integer        -- the Cast's server time
---@field catchId string
---@field itemID integer
---@field zone integer        -- the Cast's zone areaID (0 if unresolved)
---@field date { year: integer, month: integer, day: integer }   -- the Cast's realm date (cast.conditions.date)
```

Seal dates are the stored realm `date`, never a conversion through today's snapshot (HNT-R50 is for forecasts). A ladder title keeps the server time it was earned (`ladder`), with no realm date: pagle-backend reads it as server time (ANG-R27, ANG-R56, [#363](https://github.com/timemir/pagle-addon/issues/363)). A set's `date` is the realm date of the Cast whose tier earned it, or, for a title from a retirement, the UTC day of that `retired` date (DATA-R87).

## Contracts

**Exposes:** nothing. Modules never call Hunts (ADR 0001).

**Core API used:** listed under Purpose and boundary.

**Events consumed:** `ConditionsChanged`, `SkillChanged`, `RestrictionChanged` (HNT-R42, HNT-R43), `AppearanceChanged` (HNT-R79; the binding's is Core's renderer's, HNT-R70), `ClockFormatChanged` (HNT-R50), `ModulesChanged` (the equipped tracker frame is Core's by then, SHOP-R33); and, through `Pagle.RegisterEvent`, the first `PLAYER_ENTERING_WORLD` (HNT-R42, HNT-R53) and `CALENDAR_UPDATE_EVENT_LIST` (HNT-R53).

WoW APIs for its own presentation: `C_Calendar.OpenCalendar`, `C_Calendar.GetMonthInfo`, `C_Calendar.GetNumDayEvents`, `C_Calendar.GetDayEvent` and `C_DateAndTime.GetCurrentCalendarTime` (event names, HNT-R53), `C_UnitAuras.GetPlayerAuraBySpellID` with `GetTime` (the camp bar's expiry, read for display only, HNT-R63; ADR 0001's live game state for a Module's own presentation), `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID` and `Item:CreateFromItemID` (HNT-R54, HNT-R55), `C_Map.GetAreaInfo` (HNT-R53), `C_Spell.GetSpellName` (HNT-R52, HNT-R53), `ITEM_QUALITY_COLORS` (HNT-R55), `issecretvalue`, `GetServerTime`, `C_Timer` (HNT-R42), `BreakUpLargeNumbers` (HNT-R111), `GameTooltip`, `UISpecialFrames` (Esc, HNT-R60), `CreateFrame` and `CreateFont`.

**Module records appended** (LOG-R40, ADR 0008), read back by its own projection only:

| Kind | Payload | Rules |
|---|---|---|
| `run` | `<eventID>\|<start>\|<end>\|<source>`: server times in decimal, `source` `r` (rotation) or `p` (pushed) | HNT-R150, HNT-R151 |
| `def` | `<eventID>\|<part>/<parts>\|<text>`: one part of a pushed definition in the content grammar | HNT-R154 |

pagle-backend's fold reads these records with Hunts' own `logic/` (ADR 0013, pagle-backend #2).

### Pushed Hunt Events and runs

The `huntEvent` and `huntRun` items of Core's pushed content (PUSH-R21), version 1 each. Their fields, in the payload grammar of [core/pushed-content.md](core/pushed-content.md#the-payload):

```lua
{ kind = "huntEvent", v = 1,
  id = "p_hallows_hollow_tide",            -- [%w_]+, starting p_
  zones = { 85, 10 },                      -- 1-2 zone areaIDs
  tags = { "hallows_end", "night" },       -- from data/hunts/tags.toml (DATA-R97)
  skill = { 75, 150 },                     -- the skill range: two integers, low <= high, either may be negative (DATA-R97)
  rotation = false,                        -- pushed events never enter the fallback rotation
  name = "...", note = "...",              -- lore, DATA-R99's limits
  hunts = {
    { id = "p_hallows_hollow_tide_haul", name = "...",
      class = "species.any",               -- or species = <Species item ID>
      minBand = 3,                         -- optional, 2-4
      conditions = { time = { { 1260, 240 } } },   -- optional, LOG-R48 fields except areas
      tiers = { 20, 50, 100 } },
  } }

{ kind = "huntRun", v = 1,
  event = "p_hallows_hollow_tide",        -- a pooled or pushed event ID
  start = 1793714400, ["end"] = 1793973600 }   -- server times (UTC), start < end
```

A `huntRun` whose event is neither pooled nor delivered as a `huntEvent` in the same snapshot, or logged earlier, is ignored. A `huntEvent` item that fails DATA-R99's checks Hunts can run in game (known IDs, tiers, tags, field shapes) is ignored, with a dev diagnostic line.

**Moments raised:** HNT-R86 and HNT-R88. These match the Hunts rows of Core's rung table (announcements.md): completion and further tier `toast.high`, set title `banner`, window opened `nod` with `expiresAt`; and for Pagle Wagers a first mark `toast`, a further mark `toast.low`, a settled run `toast.high`, a ladder title `banner` and the companion hint `nod` (HNT-R86, HNT-R171).

**Coins paid:** 30 per Standing Hunt completed, 15 per further tier, 100 per set title; for event Hunts 8 at tier 1, 5 per further tier and 25 per completed run, every run (HNT-R110).

**Activity XP paid:** 500 per Standing Hunt completed and 250 per further tier; for event Hunts 150 at tier 1, 100 per further tier and 250 per completed run, every run (HNT-R113–R115).

**Refreshes earned:** for event Hunts only, 1 per Hunt reaching tier 3 and 1 per completed run, every run (HNT-R116); none for a Standing Hunt.

**Curio Shop goods registered:** HNT-R120, HNT-R121.

**Settings rows added:** under Settings below.

## UI

- **Hunts board:** HNT-R60–R70. Look reference: the books art kit (`PagleArtBooks`, `/paglebooks hunts`), after `prototypes/hunts-board/` variant E, whose `HuntsModel` script shows the grouping and labels (its skill numbers, zones and rates are placeholders). The text above wins where they differ. Item icons are sepia-tinted, round in the kit's rings. The kit v2 lays out a set's page (its "Set" board) with sample data; the board binds it to HNT-R66.
- **Pagle Wagers:** HNT-R160–R167 and the hint, HNT-R170–R172. Look reference: the spread, the Pagle Wagers kit (the Wagers redesign's variant A; its sources in `data/art/wagers/`: `art.json`, the `Wagers` atlas and the event mark's layers); the WAGERS timeline group's layout on the Board, `prototypes/hunts-board/wagers/` on branch `prototype/hunts-wagers` ([#284](https://github.com/timemir/pagle-addon/issues/284)), variant B; the wager strip, the WAGERS rows' event marks and the tracker's dials, the kit again, as [#375](https://github.com/timemir/pagle-addon/issues/375)'s prototype laid them (HNT-R161, HNT-R175). Variant C (fore-edge tickets) isn't taken.
- **Hunts tracker:** HNT-R75–R79 and the Pagle Wagers block, HNT-R175–R177, a block in Core's tracker dock, in the kit's three looks (`/paglebooks trackers`).
- **Entry points:** the compartment menu's "Hunts", `/pagle hunts`, the Settings status button "Open Hunts", and the tracker's lines (HNT-R68, HNT-R77).
- **Announcements:** drawn by Core from HNT-R86 and HNT-R88.

## Settings

| Option | Page | Values | Default |
|---|---|---|---|
| Show the Hunts tracker | Trackers | on/off | on |
| Hunts tracker frame | Trackers (Core adds it from the slot, CORE-R42) | owned frames | `hunts.trackerframe.none` |
| Tell me when a pinned Hunt's window opens | Announcements | on/off | off |
| Remind me about the Pagle companion | Announcements, after the window row (while the hint switch is on, as at 1.0, HNT-R172; SET-R32) | on/off | on |

"Show completed", pins and the tracker's collapsed state are set on the board and tracker themselves, not in Settings.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Soon horizon | 3 realm hours | HNT-R40, HNT-R62 |
| Timeline ruler | 2 h before now to 22 h after | HNT-R62 |
| Board size | about 920 × 600 px | HNT-R60 |
| Month wording beyond | 7 days | HNT-R51 |
| Lure reach | 100 skill | HNT-R33, HNT-R52 |
| Refresh while the board or tracker is visible | 60 s | HNT-R42 |
| Zone chips shown | 3 | HNT-R65 |
| Tracker lines shown | 6 | HNT-R76 |
| Coins: completed / further tier / set title | 30 / 15 / 100 | HNT-R110 |
| Coins, event Hunts: tier 1 / further tier / completed run | 8 / 5 / 25 | HNT-R110 |
| Activity XP, Standing Hunts: tier 1 / further tier | 500 / 250 | HNT-R113 |
| Activity XP, event Hunts: tier 1 / further tier / completed run | 150 / 100 / 250 | HNT-R114 |
| Refreshes, event Hunts: a Hunt reaching tier 3 / a completed run (`ns.TICKETS_TIER3`, `ns.TICKETS_RUN`) | 1 / 1 at the start, up to 5 a run of 4 Hunts; the calibration ticket ([#402](https://github.com/timemir/pagle-addon/issues/402)) sets the final ones | HNT-R116 |
| Run length (default, and every fallback run) | 72 h | HNT-R142, HNT-R152 |
| Rotation starting point | 1.0's release day 15:00 UTC; before 1.0 a placeholder in the past: Monday 19 October 2026 15:00 UTC, the Monday before #300 landed (`ns.ROTATION_ORIGIN`, set by #275's checklist) | HNT-R152 |
| Skill bands: low / mid / high | up to 150 / 151–275 / above 275 | HNT-R156 |
| Ladder steps | 25 / 50 / 100 completed runs | HNT-R148 |
| Epic styles: Nightfin Tide / The Deep Trench / Nat's Study | three different night-event Hunts at tier 3 (`ns.NIGHT_TIDE_HUNTS`, `ns.NIGHT_TIDE_EVENTS`) / every Hunt of `azshara_lobster` at tier 3 in one run (`ns.DEEP_TRENCH_EVENT`) / 100 completed runs (`ns.WAGER_STUDY_RUNS`) | HNT-R122 |
| Hour index for late run records | 14 days back from the latest Cast | HNT-R149 |
| Celebrated run entries kept | 30 days after a run ends | HNT-R92 |
| Companion hint switch | on at 1.0 (`ns.COMPANION_HINT_ON`) | HNT-R170–R172 |
| Companion address (Get it) | `https://pagle.app/download` (`ns.COMPANION_URL`) | HNT-R170 |
| Companion Nod interval | 7 days | HNT-R171 |
| Tracker runs shown | 3 | HNT-R175 |
| Closing note and red countdown: a run on closing within | 3 h | HNT-R161, HNT-R162, HNT-R167, HNT-R175 |
| Pool authoring tier times: tier 1 / 2 / 3 | about 45 min / 2 h / 4 h fishing in the zone | Data, DATA-R99 |
| Tier trims | bronze / silver / gold (tier 3 and up) | HNT-R18 |
| Tracker frame tiers | inkwash 1, waxseal 2; slate 1, mapscrap 1, bounty 2, spyglass 3 | HNT-R121 |
| Hunts rules version before 1.0 | 4 (3 before the Refreshes, 2 before the retuned Coins, 1 before Hunt Events) | HNT-R136, HNT-R138 |
| Module menu order, tracker order | 20, 10 (Core's tables) | HNT-R135, HNT-R75 |
| Standing Hunt tiers | per Hunt, in the Standing list | Data |

## Edge cases

- **HNT-R190 Module disabled, then enabled again.** While disabled, nothing of Hunts runs, its tracker leaves the dock, and its goods leave the shop (CORE-R17, SHOP-R35). Casts recorded meanwhile count (HNT-R13): on re-enable the projection catches up in `"replay"` mode, raises no pop-ups, and one Write-up section "While Hunts was off" lists what that history earned (HNT-R111). If a release changed a fingerprint meanwhile, it rebuilds instead, and what it newly earned goes to the Session summary (HNT-R112). Pins, the filter and the celebrated set are kept in `PagleHuntsDB`. No window moment is raised for windows that opened while it was off.
- **HNT-R191 Projection rebuild.** A new content fingerprint, Hunt list fingerprint or rules version rebuilds from `seq` 0 (LOG-R72). Released definitions and frozen bands give the same completions every time (ADR 0005, ADR 0014). Newly earned tiers and titles go to the summary only and are then marked celebrated (HNT-R112); the celebrated set is never cleared or lowered. Effort counts may shift when a window is corrected; they are display only.
- **HNT-R192 First build over existing history.** One Write-up section; everything already earned is marked celebrated and nothing pops up (HNT-R111). Only Casts at or after each Hunt's `since` count, so before 1.0 that is history since the placeholder date. A fresh install with no Casts raises no Write-up.
- **HNT-R193 In combat.** Core keeps recording, and Hunts' live apply runs as usual; Core holds every moment (ANN-R35). The board can open and stay open; the board and tracker stop regrouping until the restriction ends (HNT-R43). Hunts registers no secure frames and changes no bindings. Event names are looked up only outside restriction (HNT-R53).
- **HNT-R194 Crash mid-Session.** The Casts since the last save are lost from the log (LOG-R85), and so is any change to `PagleHuntsDB` made after it, celebrated set included. A tier reached only by a lost Catch isn't reached at the next login, and is celebrated again when it is reached for real.
- **HNT-R195 Daily or weekly reset.** No rule here depends on it. Windows are realm time; one that crosses realm midnight is one window (LOG-R48), and the Extravaganza's weekly rule is a forecast, not a reset.
- **HNT-R196 Uncharted or unconfirmed Catch.** An Uncharted Catch qualifies for nothing (`Pagle.GetItem` is `nil` and no class holds it). When a release classifies it, the new fingerprint rebuilds Hunts and credits it if its Cast is at or after the Hunt's `since`, through HNT-R112; if it becomes a Species, it gains a size then (LOG-R96). Item `0` never qualifies. A natural Hunt completes whether or not its window or gating is confirmed; the board only labels it (HNT-R34). A natural Catch outside its stated window still counts and is evidence for the Field report (REP).
- **HNT-R197 Hunt retired or added by a release.** A retiring Hunt leaves the board and tracker, loses its pin, and keeps its tiers and Coins (HNT-R3). A new Hunt counts only Casts from its `since` on, so it starts at 0 even for an Angler with years of history; it never takes away a set title already earned (HNT-R20). A set title that a retirement completes is found at the next Cast, catch-up or rebuild after the `retired` date, and raised summary-only (HNT-R23, HNT-R87).
- **HNT-R198 A Hunt's target data changes.** A window correction changes the board, waters and effort but never completions (HNT-R4). An item gaining a quality or joining a Species adds Catches on the next rebuild; a released class never loses a member (DATA-R91, DATA-R96).

- **HNT-R199 A Cast across a run's end, and back-to-back runs.** Judged by the Cast entry's server time alone (HNT-R144): a Cast landing at or after `end` doesn't count, and at a shared boundary it counts only for the run that starts there. The client's clock never matters.
- **HNT-R200 Logging in after a run ended.** Casts logged inside the run but not yet folded (Hunts was off, or a rebuild) still count, pay, and show only as summary-only moments or Write-up lines (HNT-R149). A pushed run that ended before Hunts first saw it is ignored entirely (HNT-R151).
- **HNT-R201 The companion goes quiet mid-run.** A logged run plays out whatever the state becomes (HNT-R153). Once the state isn't `"connected"`, the rotation fills the next slot no logged run covers.
- **HNT-R202 A pool change in an update.** Known runs come from the log, so past runs keep their events. The rotation from now on follows the new pool; a catch-up over a past stretch follows the current rule (HNT-R155). Removing an event from the pool is a release change like retiring a Hunt: its logged runs stay credited, it only stops being picked.
- **HNT-R203 Countdowns and dates.** Countdowns are server-time durations ("closes in 2d 4h"); dates and clock times are realm time (HNT-R50), so a 15:00 UTC end reads "until Sat 17:00" on a realm two hours ahead.
- **HNT-R204 Before the rotation's starting point.** No fallback run is on; the WAGERS group and the strip are left out unless a pushed run is on, and the Pagle Wagers ribbon's spread reads "No wagers on the table yet."
