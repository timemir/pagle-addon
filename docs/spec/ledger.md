# Ledger

> Status: Done · Milestones: M2 (projection, XP, Fresh Water, Angler Level, Skill Milestones, the Ledger's moments, Coins, the Write-up), M3 (the Fish Journal, Species Mastery, Zone Mastery, Sub-collections, Trophy Room, Uncharted list, Ledger completion, the Ledger's lore check), M4 (Legends, titles, Simulated Size records, Catch Milestones, Prestige, Journal bindings), Track V In-game views (the Following spread, LED-R151) · Sources: [Design the Ledger progression model](https://github.com/timemir/wow-fish/issues/11#issuecomment-6112531009), [Prototype the Fish Journal](https://github.com/timemir/wow-fish/issues/12#issuecomment-6112909660), [Prototype Catch feedback: toasts, sounds and cozy mode](https://github.com/timemir/wow-fish/issues/13#issuecomment-6113132854), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Curio Shop](https://github.com/timemir/wow-fish/issues/30#issuecomment-6125718197), [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372), [Decide who owns Announcements: a Core service or each Module](https://github.com/timemir/wow-fish/issues/22#issuecomment-6113769547), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441), [Prototype the Settings tree](https://github.com/timemir/wow-fish/issues/32#issuecomment-6129969765), [Design the /pagle report format and issue form](https://github.com/timemir/wow-fish/issues/26#issuecomment-6124884698), [Write the Core spec](https://github.com/timemir/wow-fish/issues/35#issuecomment-6130119859), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0002 (superseded), 0004, 0007, 0009, 0010 (superseded), 0014. Prototypes: `prototypes/fish-journal/` (variant E), `prototypes/catch-feedback/` (variant A), `prototypes/curio-shop/` (bindings)

The Ledger is the `Pagle_Ledger` Module: the Angler's identity as an angler. It turns the Catch log into **Angler Level** and **Prestige**, **Fresh Water**, **Skill Milestones** and **Catch Milestones**, **Species Mastery**, **Zone Mastery**, the **Sub-collections** and **Trophy Room**, **Legends**, **Ledger completion**, titles and **Simulated Size** records, and shows them in the **Fish Journal**, a leather-and-parchment book. It builds on the Core contracts in [`core/`](core/README.md) and uses terms as `CONTEXT.md` defines them.

## Purpose and boundary

**Owns:**
- every progression number above, derived from the Catch log and Core's catalogue as one stored projection (ADR 0004), and the celebrated set that keeps what was shown from being taken back or shown twice
- deciding when Prestige is allowed (Core only appends the entry, LOG-R38)
- per-Species Simulated Size records (Core computes each size, LOG-R65)
- the Ledger's moments, its Write-up section and its summary line
- the Coins it pays into Core's wallet (ADR 0009), and its earned bindings in Core's binding slot (ADR 0015)
- the Fish Journal view, and the Ledger's lore keys

**Doesn't own:**
- what bites where and when, sizes and their bands, condition matching and forecasts (Core's catalogue, LOG-R48–R69)
- how moments are shown, the Session summary and the Write-up card (Core, ADR 0007)
- the balance, the Curio Shop and bookplate crests (Core, ADR 0009)
- "catchable now" suggestions (Hunts). The Ledger takes no stars or anything else from Hunts, the Tackle Board or Stats, and never reads them (ADR 0001). The one thing that reaches it is their **Activity XP**, through Core's totals (LED-R37, ADR 0011, [core/activity-xp.md](core/activity-xp.md)).
- Field reports (Core); the Journal only opens the box (REP-R43)

**Uses from Core:** the calls listed under [Contracts](#pagle-api-used).

## Rules

### The Module

- **LED-R1** `Pagle_Ledger` registers with `def.name = "Ledger"`, `title = "Ledger"`, `order = 10`. From M3 it has one view, `{ id = "journal", label = "Fish Journal" }`, and one slash command, `/pagle journal` (help "Open or close the Fish Journal"); both toggle the Journal (any text after the command is ignored). It has no `settingsAction` (the Settings root shows "Open Fish Journal", CORE-R44), no extra menu entries and no settings rows: the Ledger has no settings page. In M2 it has no view and no slash command.
- **LED-R2** The Ledger keeps one projection (LOG-R70) in `PagleLedgerDB.global.projection` over every record `M:IterateCatches` yields. It applies caught and got-away Casts, Skill Readings, Prestiges and its own crest records (LED-R156), and ignores every other kind. The crest record is the one Module record it appends ([Data › Module records](#module-records)). Its `rulesVersion` is `LEDGER_RULES_VERSION × 100 + Pagle.SIZE_RULES_VERSION` (Tunables), because it stores lengths (LOG-R68); `SIZE_RULES_VERSION` stays below 100. `LEDGER_RULES_VERSION` rises whenever a rule or Tunable that changes the projection changes. It has no `extraFingerprint`, and it never reads Sessions (no `SESSION_RULES_VERSION`).
- **LED-R3** The projection's state is a pure function of the entries applied and the catalogue, the same in every mode. The fold lives in the Ledger's `logic/`, with Core's lookups and `MatchesConditions` passed in. Entries are applied in `seq` order and a Cast's Catches in item order. The celebrated set (LED-R90) and the in-memory scratch list (LED-R98) are the only things outside the projection, and the fold never reads either.
- **LED-R4** **Staging by milestone.** The fold, the moments and the Journal grow by milestone, and each milestone that changes the fold raises `LEDGER_RULES_VERSION`, so the projection rebuilds and what history newly earns arrives as summary-only moments (LED-R93):
  - **M2:** classification (LED-R5–R7) with no Legend class (a Legend item counts as its category until M4); XP rows Catch XP, new Species, Species in a zone, first Catch in a zone and Skill Milestones; Fresh Water; the climb without Prestige (no carried XP use, no `prestigeReady`); Skill Milestones; lifetime Catches as a count; Coins for level-ups and new Species; moments `levelUp`, `newSpecies`, `newInZone`, `skillMilestone`; the celebrated set, `done` and the summary line without completion.
  - **M3:** the world index, stars, Zone Mastery, the collections and the Uncharted list, completion, their XP, Coins and moments, and the Journal. The Journal leaves out every M4 element: Legends (contents line and spread), titles (the bookplate and brass plate show no title; "Lv {L} · Ledger {p}%"; the `zoneMaster` moment's text is just "{zone}"; no `completeTitle` moment), the zonemaster line of LED-R137, the Prestige emblems and button, "Signed As", "Bindings", the Catch Milestone part of LED-R146 (it reads "{lifetime} Catches"), and size text. It is drawn in the Field Leather look, whose tints the M3 Journal ticket picks, while no binding slot exists.
  - **M4:** Legends, titles, Simulated Size records (and size text), Catch Milestones, Prestige (with `prestigeReady`), the bindings, and every element M3 left out.

  `LEDGER_RULES_VERSION` is 1 in M2, 2 in M3 and 3 in M4, then rises by 1 per change: 4 when ★ moved from a Species' first Catch to its 5th (LED-R45); 5 for the full Prestige cost and Activity XP in the climb (LED-R30–R32, LED-R37, M8 Hunt Events); 6 for the varieties caught (VAR-R20); 7 for the second round's counts (LED-R118, LED-R119); 8 for the time a zone reached Master and a variety was first caught, and the crest record (LED-R155, LED-R156); 9 for the times the leaderboard measures last rose (LED-R158). In M2 the Settings root has no "Open Fish Journal" button, since the Ledger has no view yet (CORE-R44).

### Classifying a Catch

- **LED-R5** Each Catch (one item of a caught Cast, whatever its quantity) is classified by `Pagle.GetItem(itemID)`, first match wins:

  | Class | When | Counts toward |
  |---|---|---|
  | item `0` | `itemID` is 0 (secret, LOG-R8) | the **base** below only |
  | Uncharted | `GetItem` returns `nil` | the base, and the Uncharted list (LED-R64) |
  | Noise | `noise` is true | the base only |
  | Legend | `legend` is true | the base, and Legends (LED-R63) |
  | Species | category `fish` or `questFish` | the base, and the Species of its `species` ID |
  | trophy | category `trophy` | the base, and the Trophy Room: its `family` and `weight` |
  | curio | category `junk` (the **Junk Museum**) or `container` or `treasure` (**Treasures**) | the base, and that Sub-collection |
  | other | category `other` | the base only |

  The **base** is: lifetime Catches (LED-R42), Catch XP (LED-R20), Fresh Water (LED-R22), and the zone being **fished** (LED-R6). A Legend is never also counted as a Species, and no Catch is ever counted twice. A `removed` item is classified the same way (LED-R12); a Species counts as removed when its representative item is. A Species is shown and named by its Species ID's item (the representative item, DATA-R19): its name, icon and search key.
- **LED-R6** A Catch's **zone** is its Cast's `conditions.zone`. Every Catch of any class with a zone other than `0` makes that zone **fished**: it earns the first-Catch-in-a-zone XP, counts toward Visitor (LED-R50) and gives the zone a tile. Zone `0` (unresolved) gives no zone credit at all: no fished zone, no Species-in-a-zone XP, no Zone Mastery and no zone toward ★★. Everything else still counts.
- **LED-R7** Got-away Casts count toward nothing but the Casts total in the Write-up heading (LED-R93). They don't touch Fresh Water.

### The Ledger's world

- **LED-R10** At `OnInitialize` (the catalogue is ready by then, CORE-R10) the Ledger builds its **world index** in memory from the catalogue. It is never stored, and it changes only with the catalogue, whose new fingerprint rebuilds the projection (LOG-R72):
  - A zone's **zone list** is the entries of `Pagle.GetZoneCatches(zone)` whose item is a Species, trophy or curio item under LED-R5. Legends, Noise, `other` and items `GetItem` doesn't know are left out. An item listed in several of the zone's areas gives several entries.
  - The **charted zones** are the zones in `Pagle.GetZones()` whose `GetArea(zone).hasData` is true and whose zone list isn't empty.
  - The **listed Legends** are the Legend items in `GetZoneCatches` of any zone in `GetZones()` (they are kept out of zone lists, but not out of the Legends' world).
  - A Species is **on a zone's list** when any of its items is. It is **gated** in that zone when every entry of its items there has a `window` (LOG-R55), and **ungated** there otherwise; its **windows in the zone** are the distinct `window` IDs on those entries.
  - A Species' **listed zones** are the charted zones whose list it is on. Its **element windows** are the distinct `window` IDs of all its items' entries across every charted zone, but only when every one of those entries is gated; otherwise it has none. Each window's spec is any entry's `gate` for it: every entry gated by one window shares that window's spec (DATA-R78).
  - A zone's **skill base** is `GetArea(zone).skillBase`, if any.
  - A **trophy family's weights** are its trophy items on any zone list (each item is one weight, shown by its `weight`); its **heaviest** is the one with the greatest `weight` (lowest item ID on a tie).
  - A zone's **junk requirement** exists when its list has a `junk` item; its **treasure requirement** when it has a `container` or `treasure` item.
- **LED-R11** Each collection's **world** is what is listed plus what the Angler has caught: the Species on any zone list, together with every Species with a Catch in the projection; likewise every trophy and curio item, and every listed Legend plus every caught one. An item on no zone list (such as a fish only ever caught from pools, which reaches a list only through content data, DATA-R28) joins the world when first caught. Uncaught items that are on no list don't appear anywhere.
- **LED-R12** A **removed** item (`removed` true) is never on a list (DATA-R26). Its earlier Catches keep their credit (XP, stars, records), its page still shows with "No longer found in Forever's waters." (an uncaught one has no page and is in no index: not the Legends' nor any collection's), and it is left out of both sides of every "x of N" count and of Ledger completion (LED-R70, LED-R71).

### XP and Fresh Water

- **LED-R20** XP is earned at the entry that earns it, in log order:

  | Source | XP |
  |---|---|
  | every Catch (**Catch XP**) | 10, doubled while Fresh Water lasts (LED-R22) |
  | first Catch ever of a Species | 500 |
  | first Catch of a Species in a zone (each Species × zone pair, also on the Species' first Catch ever) | 100 |
  | first Catch ever in a zone (charted or not) | 200 |
  | first Catch of a curio item (by item ID) | 150 |
  | first Catch of a trophy item (a weight not landed before) | 100 |
  | each Zone Mastery rank reached (LED-R51) | 250 × rank |
  | each Skill Milestone (LED-R40) | 1,000 |
  | first Catch of a Legend item | 2,000 |

  A Catch earns every row that applies. Only Catch XP is ever doubled. Simulated Size, stars, titles, Catch Milestones and size records earn no XP. This table is the Ledger's own XP; other Modules' Activity XP comes through Core (LED-R37).
- **LED-R21** "First" always means first in the log, any character. Discovery XP is earned once per thing for the Angler's whole history, across Prestiges.
- **LED-R22** **Fresh Water** is a number `F`, equal to the cap before the Angler's first Catch. At each Catch, in log order, with `t` its Cast's time and `t0` the previous Catch's Cast time (any character): `F = min(cap, F + rate × max(0, t − t0) / 3,600)` (nothing is added at the first Catch ever); then, if `F ≥ 1`, that Catch's Catch XP is doubled and `F` drops by 1. The Catches of one Cast share `t`, so each spends one in turn. Rate and cap are Tunables.
- **LED-R23** Fresh Water shown now is `floor(min(cap, F + rate × max(0, GetServerTime() − tLast) / 3,600))`, with `tLast` the last Catch's time (the cap with no Catch yet). On the XP bar it is a shaded stretch, like rested XP, starting at the current XP and covering `shown × 10` XP, clipped at the bar's end. At level 60 it isn't drawn.

### Angler Level and Prestige

- **LED-R30** A **climb** is the Angler Level's run from level 1 to the cap. Going from level `L` to `L + 1` costs `(1,000 + 80 × L) × f`, with `f` the Prestige climb cost factor (Tunables), 1 in every climb: a climb after a Prestige costs what the first did ([#279](https://github.com/timemir/wow-fish/issues/279), #257). The level is 1 plus the number of steps the climb's XP covers, at most 60. XP beyond what reaching 60 costs is **carried XP**.
- **LED-R31** The climb's XP is the Ledger's own XP earned since the latest Prestige entry, plus the carried XP at that Prestige, plus the climb's Activity XP (LED-R37).
- **LED-R32** Applying a Prestige entry (any mode): the prestige rank becomes the entry's `rank`; a new climb starts at level 1 with the carried XP (0 if the climb hadn't reached 60, as after a rebalance). The ending climb's XP includes its Activity XP: the entry's `activityXP` minus the previous Prestige entry's (0 before the first), never below 0 (LED-R37). Carried XP has no cap, so the new climb may start above level 1; those level-ups belong to the Prestige entry (one `levelUp` moment without `cast`, with their Coins). Nothing unlocked is taken away (LED-R92).
- **LED-R33** **Prestiging** is the player's choice, from the Journal's button (LED-R146), shown only while the computed level of the climb is 60 and the projection isn't updating. The Journal's own confirm card asks, over the darkened book: kicker "Prestige", "Begin a new Ledger?", "Your Angler Level climbs again from 1. Nothing you've earned is taken away.", with "Prestige" and "Not yet" and the Prestige emblem of the rank to come (LED-R152), 64 units, pressed on. Confirming checks both conditions again and calls `M:RecordPrestige()` (LOG-R38) only if they hold, then turns the Angler page forward to the new rank; otherwise nothing happens. Closing the Journal hides the card. The Ledger is the only Module that calls it.
- **LED-R37** **Activity XP** (ADR 0011, [core/activity-xp.md](core/activity-xp.md)) counts toward the climb. The **current climb's Activity XP** is `max(0, Pagle.GetActivityXP().total − s)`, with `s` the `activityXP` of the latest Prestige entry (0 before the first, AXP-R5). An earlier climb's is the gap between its two Prestige entries' `activityXP`, never below 0 (LED-R32). The projection stores only the Ledger's own XP and the Prestige snapshots it has applied; the current climb's Activity XP is read from Core whenever the level is worked out, never stored, so another Module's total never rebuilds the Ledger. Activity XP is never doubled by Fresh Water and never counts as Catch or Discovery XP. Every read in `logic/` that works out the level from a state (the climb, the computed and peak level, Coins for levels, the level titles, and the backend's hooks `Measures`, `AnglerLevel`, `JournalValues`, `EarnedTitles`, `AutomaticTitle` and `CoinsEarned`) takes Core's total as an optional `total` argument. Without one it reads `Pagle.GetActivityXP().total` in game, through the source the adapter sets, and 0 in `logic/` alone, where none is set. Pagle's backend passes the sum of the paying Modules' `ActivityXPEarned` (AXP-R9, [#76](https://github.com/timemir/wow-fish/issues/76) item 15).
- **LED-R38** The computed level, carried XP, peak level and Coins for levels (LED-R88) are worked out from the climb's XP with the Activity XP included. A total recounted lower can lower the computed level; the shown level never drops (LED-R36), and the XP bar waits at "0 of {cost}" until the computed level catches up.
- **LED-R39** On `ActivityXPChanged(entry)` (AXP-R7) the Ledger works out the shown level again. A level it now reaches above the celebrated set raises the `levelUp` moment (LED-R97) with its Coins, carrying `cast` = `entry`'s ID when `entry` is a live Cast, so it merges with that Cast's Announcement (ANN-R10); with no `entry` (a report from another Module's `done`) it is raised `summaryOnly` (ANN-R63). It then reports its Coins (LED-R89) and refreshes level bindings (LED-R111) if the peak level passed a multiple of 10. While the Ledger's own projection is updating, it waits and does this from its `done`.
- **LED-R34** Prestige ranks 1–10 each give their own **Prestige frame** and **Prestige emblem** (I–X, LED-R154, LED-R152). From rank 11 on, each Prestige is a **Master Prestige**: the Master's frame and emblem, and one more star (rank − 10 stars) beside the emblem. Ranks 1, 5 and 10 also give a title (LED-R75).
- **LED-R35** The **peak level** is 60 once the prestige rank is above 0, else the current level. Level rewards (titles, bindings) follow the peak level, so a Prestige never takes them away.
- **LED-R36** The **shown level** is the higher of the computed level and the highest level celebrated in the current climb (LED-R90). Everything that displays a level (Journal, brass plate, summary line, Write-up) uses it. When it is above the computed level, the XP bar reads "0 of {cost of the shown level's step}" until the computed level catches up; the levels in between raise no moment again, and their Coins still count toward the total (they just ride on no moment).

### Skill and Catch Milestones

- **LED-R40** **Skill Milestones** are at 75, 150, 225 and 300. Each is credited once per Angler, at the first Skill Reading (any character) whose `rank` is at or above it; one reading can credit several. Each earns 1,000 XP and a moment. Skill is read at every login (LOG-R31), so a skill reached before install is credited at that character's first login after it.
- **LED-R41** The Journal shows each character's latest Skill Reading from `Pagle.GetAngler().skill`, not from the projection.
- **LED-R42** **Lifetime Catches** count every Catch (LED-R5 base). **Catch Milestones** are at 1,000, 5,000, 10,000, 25,000 and 50,000 lifetime Catches, each credited at the Catch that reaches it. They earn no XP and no Coins.

### Species Mastery

- **LED-R45** Each Species (not Legends) has three stars, earned independently:
  - ★ **Caught**: 5 Catches of it, counted as ★★★'s. Its first Catch still makes it caught (named, counted, its New Species XP, Coins and moment); only the ★ waits for the 5th.
  - ★★ **In its element**: if it has element windows (LED-R10), a Catch of it under each of them, in any zone, judged with `Pagle.MatchesConditions(gate, cast.conditions)` with that window's spec; otherwise Catches of it in `min(3, max(1, listed zones))` distinct zones, any zone other than `0` counting (LED-R6).
  - ★★★ **Regular**: 50 Catches of it.
- **LED-R46** Stars are counted from Catches only. A Simulated Size never counts.
- **LED-R47** Each trophy family has three stars, earned independently: ★ any of its trophy items landed; ★★ at least `ceil(n / 2)` of its `n` listed weights (LED-R10) landed; ★★★ its heaviest listed weight landed. ★★ and ★★★ need `n ≥ 1`; an unlisted weight counts only for ★. A family's `n` can grow with the data; a star already celebrated stays shown (LED-R92).
- **LED-R48** A Species or family shows the union of its computed and celebrated stars; each star is inked or blank on its own (★★★ without ★★ is possible).

### Zone Mastery

- **LED-R50** Each charted zone has a computed **rank**, from the Catches made in it (LED-R6). A Species counts as **caught there** when any of its items was caught in the zone; the junk requirement is met by any `junk` Catch in the zone, the treasure requirement by any `container` or `treasure` Catch in it, and a family by any of its trophy items caught in it. Each rank needs everything the one below needs:

  | Rank | Also needs |
  |---|---|
  | 1 Visitor | any Catch in the zone |
  | 2 Regular | `ceil(U / 2)` of its `U` ungated Species caught there |
  | 3 Local | all its ungated Species caught there |
  | 4 Expert | all its gated Species caught there (day, night, seasonal or event), plus its junk and treasure requirements if it has them |
  | 5 Master | a trophy of each family on its list, caught there |

  A requirement with nothing in it (no ungated Species, no family) is met. A Species not on this zone's list, caught there, counts for nothing here.
- **LED-R51** Within one build of the projection a zone's computed rank only rises. Each rank it passes earns its XP (LED-R20) and Coins (LED-R88) once, even when one Catch passes several.
- **LED-R52** The **shown rank** is the higher of the computed rank and the celebrated rank (LED-R90). When the shown rank is higher, the zone has **new to find**: the count of things missing for the shown rank's requirements, summed over every rank up to it: for Regular the shortfall to `ceil(U / 2)`, for Local each uncaught ungated Species beyond that, for Expert each uncaught gated Species plus 1 for each unmet junk or treasure requirement, for Master each family not landed there. It is shown as "N new to find" until the computed rank catches up.
- **LED-R53** A zone's **completion** is `floor(100 × done / needed)`, where `needed` counts its listed Species, its families, and 1 each for its junk and treasure requirements, and `done` counts those met in the zone. It is 100 exactly when the computed rank is Master.
- **LED-R54** A zone that isn't charted has no rank and no completion. Catches there still earn first-Catch-in-a-zone and Species-in-a-zone XP, and the Journal shows it once fished (LED-R131). A zone that stops being charted after a release shows as "uncharted waters" and leaves every zone count; a `zonemaster` title it earned stays (LED-R76), and its celebrated rank is kept in case it is charted again.

### Collections

- **LED-R60** The **Junk Museum** holds the `junk` items of the world (LED-R11), **Treasures** its `container` and `treasure` items, and the **Trophy Room** its trophy items, grouped by family. An item is collected at its first Catch, in any zone.
- **LED-R61** A trophy item's first Catch is a **new trophy weight**; the Trophy Room counts items, each shown by its `weight`. If the family already had an item landed and the new item's `weight` is greater than the greatest landed so far, the moment carries a ruler from that weight to the new one (LED-R97). A family's first item, or a lighter or equal one, has none.
- **LED-R62** The Trophy Room shows real weights only, labelled "pounds"; trophy items have no Simulated Size (LOG-R65).
- **LED-R63** **Legends:** the first Catch of each Legend item earns 2,000 XP, 100 Coins, a splash and its title (LED-R75). The counter is "x of N", N being the Legend items in the world (LED-R11) that aren't removed. Legends are outside zone lists, stars and Ledger completion.
- **LED-R64** **Uncharted:** for each item ID `GetItem` doesn't know (never item `0`), the projection keeps the Catch count, the first Catch (time, character, zone) and the count per zone caught in (zone `0` left out). Its first Catch raises a Nod. When a release classifies it, the rebuild credits it like any Catch (LOG-R96) and it leaves the list.

### Ledger completion

- **LED-R70** **Ledger completion** is `floor(100 × done / total)` over, for each, the world minus removed items:
  - every Species (done: caught)
  - every Species with varieties in the world (done: all ten caught, from the Ledger's own projection; VAR-R20): 35 parts at release, as two of the 37 are on no charted zone's list
  - every Sub-collection item: Junk Museum, Treasures and Trophy Room items (done: caught)
  - every charted zone (done: computed rank Master)

  Legends, Noise, `other`, Uncharted and item `0` are outside it. It shows 100 only when everything is done; with nothing in `total` it shows 0.
- **LED-R71** The Journal also shows each part on its own (the Angler page, LED-R146): Species "x of N", Varieties ("{fish complete} of {N}", VAR-R21), Junk Museum, Treasures, Trophy Room weights, and zones mastered (by computed rank). Each uses the same world, removed items left out of both sides.
- **LED-R72** When the data grows, totals grow and percentages may fall; titles and shown ranks already celebrated stay (LED-R92).

### Titles

- **LED-R75** Titles, each with a stable title ID:

  | Title ID | Earned when | Working name |
  |---|---|---|
  | `level1`, `level10`, `level20`, `level30`, `level40`, `level50`, `level60` | the peak level (LED-R35) reaches it | Minnow, Dabbler, Line-Caster, Fisher, Old Salt, Ledgerkeeper, Pagle's Peer |
  | `prestige1`, `prestige5`, `prestige10` | that prestige rank | Returning Tide, (lore pass), (lore pass) |
  | `zonemaster`, once per charted zone | that zone's shown rank reaches Master | Warden of {zone} Waters |
  | each Legend item | its first Catch | its `legend.<itemID>.title` |
  | `complete.ledger` | Ledger completion reaches 100 | Angler of Azeroth |
  | `complete.junk` | the Junk Museum's count reaches its total | Collector of Boots |
  | `complete.treasure` | the Treasures' count reaches its total | (lore pass) |
  | `complete.trophy` | the Trophy Room's weights reach their total | (lore pass) |
  | `complete.varieties` | every variety of every Species with varieties is caught (VAR-R22), meant to be the rarest | Keeper of Every Colour |

  The `complete.*` titles need a total above 0. `level1` is earned from the start and never raises a moment. A title is never "Master Angler" (Forever's own Extravaganza title), and "Angler" is never a ladder rung. Earned titles are listed in this table's order, `zonemaster` titles by zone areaID and Legend titles by item ID.
- **LED-R76** A **title key** names one earned title: `title:<titleID>`, `zonemaster:<zoneAreaID>` or `legend:<itemID>`. The earned titles are the ones the projection computes, plus every key in the celebrated set; a title is never taken away.
- **LED-R77** The **active title** is the player's pick in the Journal ("Signed as", LED-R146), stored as a title key in `PagleLedgerDB.profile.activeTitle`. `nil` means **automatic**: the highest level title earned. A stored key that isn't earned (after a new dev log empties the celebrated set, LED-R90) is treated as automatic and kept. Titles show only in the Journal: the bookplate, the brass plate and "Signed as". They are never Curio Shop goods (SHOP-R20).

### Simulated Size records

- **LED-R80** For each Species, and for each Legend item (kept on its `items` entry, never as a Species; Core sizes Legend Catches too, LOG-R65), the projection keeps the **record**: the Catch with the greatest `size.length` in millimetres (LOG-R65), the earliest on a tie, with its length, band, Catch ID, time, character and zone; and `since`, the number of Catches of that Species after it, sized or not (only setting or beating the record needs a size).
- **LED-R81** The first sized Catch of a Species sets the record silently. Its New Species or Legend moment shows the size as text, "{band} · {length}" (band name from `Pagle.SIZE_BANDS`, length from `Pagle.FormatLength`), with no Record stamp and no ruler.
- **LED-R82** A later Catch beats the record only when it is strictly longer in millimetres. Live, that raises a size record moment (LED-R97) with a ruler from the old length to the new. When the beaten record's `since` was 50 or more before this Catch, i.e. at least 50 Catches of the Species came between the two (the **rare-record flair**), the moment is raised at `toast` instead of `toast.low`, so the Interruption budget never steps it down (ANN-R31).
- **LED-R83** Reaching a Size band, Monster included, raises nothing. Records earn no XP, stars, Zone Mastery, completion or Coins.
- **LED-R84** Only live Catches raise record moments. A rebuild that changes records (a newly classified Species, retuned lengths) raises none, and records aren't in the celebrated set.
- **LED-R85** The length unit is Core's setting (LOG-R69); the Ledger compares millimetres only.

### Pagle Coins

- **LED-R88** The projection keeps the Ledger's **lifetime Coins earned**:

  | Source | Coins |
  |---|---|
  | each level-up, on every climb (levels 2–60) | 20 |
  | each Prestige | 100 |
  | first Catch of a Species | 10 |
  | first Catch of a curio item, and each new trophy weight | 5 |
  | each Zone Mastery rank reached (LED-R51) | 2 × rank |
  | first Catch of a Legend item | 100 |

  Nothing else pays: not Catches, Fresh Water, Species-in-a-zone, first Catches in a zone, stars, Skill or Catch Milestones, titles, size records or varieties (SHOP-R1, VAR-R25).
- **LED-R89** The Ledger reports the total with `M:ReportCoinsEarned` from its projection's `done` and after each live entry that changes it (SHOP-R2). Coins earned live ride on the moment that earned them as `coins` (ANN-R23).

### Celebrating

- **LED-R90** The **celebrated set** (LOG-R77) in `PagleLedgerDB.global.celebrated` records what has already been shown or written up: the highest level per climb (by prestige rank; a climb's level 60 also stands for its `prestigeReady`), the highest prestige rank, Species caught (New Species), which stars per Species and per family, Species × zone pairs, zones fished, shown ranks per zone, curio, trophy and Legend items, Uncharted item IDs, Skill and Catch Milestones, each Species' varieties and the Species with all of them (VAR-R25), earned title keys, the expansion's and the second round's earned goods once their rule held (LED-R116–R118), and `coins`, the lifetime Coins total, set after every live entry and every `done`. It also stores `logId`, the `PagleLog.logId` it belongs to. It only grows, except `coins`, which follows the total. In `done`, if its `logId` isn't `Pagle.GetAngler().logId` (a new log, LOG-R18), the set is emptied, given the new `logId`, and that `done` is handled as a first build.
- **LED-R91** While applying a `"live"` entry, every **achievement** (a row of the moments table, LED-R97) it earns that isn't in the celebrated set raises its moment and is added to the set. An achievement already celebrated raises nothing, even when a rebuild had dropped it and this entry earns it again.
- **LED-R92** Shown values never fall below the celebrated ones: the level in the current climb (LED-R36), Species and family stars, zone ranks (LED-R52), titles (LED-R76) and level bindings (LED-R111).
- **LED-R98** While applying entries in `"replay"` or `"rebuild"` mode, the fold also appends each achievement it earns, with the entry ID of the Cast that earned it (none for Skill Reading and Prestige entries) and its Coins, to a **scratch list** kept in memory outside the stored state, cleared by `reset` and after `done`. A rebuild cut short by a logout or `/reload` starts again from `seq` 0 (LOG-R72), so the list is rebuilt with it. `done` reads achievements from this list; the list never decides what the state holds.
- **LED-R93** In the projection's `done` (LOG-R76), in this order:
  - `info.firstBuild` (never true for a log with no Cast, LOG-R76): add every achievement in the state to the celebrated set (moments for them are never raised), and raise a Write-up section headed "Your Ledger was written up from {N} Casts" (N = caught and got-away Casts applied, with `BreakUpLargeNumbers`), lines as LED-R94.
  - else, `info.rebuilt`: for each achievement in the scratch list (LED-R98) not yet celebrated, raise its moment as it would be raised live (its `cast` and `coins`, LED-R97) with `summaryOnly = true` (ANN-R63), and add it; level-ups merge into one `levelUp` moment for the highest new level. Big batches come only from the pre-1.0 staging bumps (LED-R4); a data release credits a handful. Size records are never among them (LED-R84). This holds even when the rebuild covers entries recorded while the Module was disabled.
  - else, `info.replayed > 0`: if the scratch list holds any achievement not yet celebrated, raise a section headed "While the Ledger was off", lines as LED-R94 counting only those (a zone whose shown rank rose counts as ranked, one that newly reached Master as mastered), and add them. When none of them has a line in LED-R94 (only a Species new in a zone, say), they are added but no section is raised, so the player never sees a heading with nothing under it.
  - always: set `coins` in the celebrated set to the total, report Coins (LED-R89), call `M:RefreshGoods()` (LED-R111), set the summary line (LED-R95) and redraw the Journal if open.
- **LED-R94** Write-up lines, each only if non-zero, in this order: "Angler Level {L}" (with " · Prestige {R}" when the rank is above 0; for a catch-up, "Angler Level {old} to {new}" and only if it rose), "{n} Species", "{n} varieties · {m} fish in every colour" (varieties newly caught, and the Species with all of them; either part alone when the other is 0; VAR-R25, VAR-R91), "{n} zones ranked · {m} mastered" (zones with a shown rank, and those at Master), "{n} trophy weights", "{n} curios", "{n} Legends", "{n} Skill Milestones", "{n} Catches" (the highest Catch Milestone reached, if one is new), "Title: {title}" (one line per title in LED-R75 order, at most 3, then "+{k} more titles"), "Pagle Coins +{c}" (`c` = total minus the celebrated `coins` before this `done`). Stars and Uncharted items get no line. Every count anywhere in the Ledger has singular and plural forms in `ns.L`.
- **LED-R95** The summary line is `M:SetSummaryLine("ledger", text)` with "Ledger: Angler Level {L} · {p}% complete" ("Ledger: Prestige {R} · Angler Level {L} · {p}% complete" when the rank is above 0; before M3, without the completion part). It uses the shown level (LED-R36) and is set in `done` and after each live entry that changes the shown level, the prestige rank or completion.
- **LED-R96** All of a Cast's moments are raised while its `"live"` entry is applied, each with `cast` = the Cast's entry ID, so Core merges them into the Cast's Announcements (ANN-R10, ANN-R11): a level-up banner and a New Species toast show together, each with its own stamps. Moments of a Skill Reading or Prestige entry have no `cast`. An ordinary Catch raises nothing from the Ledger; Core shows its catch Nod (ANN-R13).
- **LED-R97** Moments (all text is `ns.L` interface text except names and titles; item names from `C_Item.GetItemNameByID`, zone names from `C_Map.GetAreaInfo`):

  | Achievement (`kind`) | Rung, `order` | `title` / `text` | `stamp` | `coins` | Also |
  |---|---|---|---|---|---|
  | Legend (`legend`) | `splash`, 100 | "Legend" / "{item} · {size text}. Title: {title}" | "Legend!" | 100 | `icon` the item |
  | Level-up (`levelUp`), one per entry however many levels, for levels above the celebrated one | `banner`, 100 | "Angler Level {L}" / "Title: {title}" for each title earned with it, else "+{n} levels" when more than one, else empty | "Level {L}" | 20 × levels raised by the moment | `seal` {L} |
  | Prestige ready (`prestigeReady`), when a climb reaches 60 | `banner`, 110 | "Prestige ready" / "Open the Fish Journal to begin a new Ledger." | "Prestige ready" | | `seal` `"book"` |
  | Prestige (`prestige`) | `banner`, 90 | "Prestige {I…X}" or "Master Prestige {rank − 10}" / "Title: {title}" when one is earned | | 100 | no `cast`; `seal` `"frame"`, `frameRank` the new prestige rank |
  | Zone Master (`zoneMaster`) | `banner`, 120 | "Zone Master" / "{zone}. Title: {zonemaster title}. Earned: {crest}", the Earned part only when the zone has a crest (its earned good `ledger.crest.<key>` in Core's crest slot, named as registered) | "Master" | 2 × each rank passed above the celebrated rank | replaces the zone's `zoneRank` moment; `seal` `"waves"` |
  | Catch Milestone (`catchMilestone`) | `banner`, 130 | "{N} Catches" / "" | "{N} Catches" | | `seal` {N} |
  | Every colour (`everyColour`), a Species' last variety (VAR-R25) | `banner`, 95 | "Every colour of {Species}" / "Earned: {crest}" (its fish crest's name, VAR-R12) | "Every colour" | | `seal` `"crest"` with `crest` its fish crest's icon (`core.crest.fish.<speciesID>`, `Pagle.GetGood`); without the good, the waves and no text |
  | Epic variety (`epicVariety`), first Catch of an Epic variety (VAR-R25) | `banner`, 97 | "Epic variety" / "{variety}" | | | `art` the variety's, on the seal's ribbon |
  | Completion title (`completeTitle`) | `banner`, 140 | "Title earned" / "{title}" | "Title: {title}" | | one per `complete.*` title; `seal` `"quill"` |
  | New Species (`newSpecies`) | `toast`, 100 | "New Species" / "{item} · {size text}" | "New!" | 10 | `icon` the item |
  | Rare variety (`rareVariety`), first Catch of a Rare variety (VAR-R25) | `toast`, 105 | "Rare variety" / "{variety}" | | | `art` the variety's, in the bezel cropped to the fish's head |
  | New trophy weight (`trophyWeight`) | `toast`, 110 | "Trophy weight" / "{item}" | "Trophy" | 5 | ruler `{ old, new, unit = "lb", label = "weight" }` when LED-R61 says |
  | Zone rank (`zoneRank`), Visitor to Expert, one per zone per entry | `toast`, 120 | "Zone rank: {rank}" / "{zone}" | "Rank up" | 2 × each rank passed above the celebrated rank | |
  | Skill Milestone (`skillMilestone`) | `toast`, 130 | "Skill Milestone" / "Fishing {threshold}" | | | no `cast` |
  | Size record (`sizeRecord`) | `toast.low`, 100 (`toast` with the rare-record flair) | "Size record" / "{item} · {size text}" | "Record" | | ruler `{ old, new, unit = "length", label = "length" }`, always (ANN-R22) |
  | New curio (`newCurio`) | `toast.low`, 110 | "New curio" / "{item}" | "New!" | 5 | |
  | New variety (`newVariety`), first Catch of a Common or Uncommon variety (VAR-R25) | `toast.low`, 120 | "New variety · {variety}" / none | "New variety" | | `art` the variety's; riding on the Cast's toast when it has one |
  | Species new to a zone (`newInZone`), not on the Species' first Catch ever | `nod`, 100 | "New here" / "{item} in {zone}" | "New here" | | |
  | ★ (`caughtStar`) | `nod`, 105 | "Caught" / "{item}" | "★" | | |
  | ★★ (`elementStar`) | `nod`, 110 | "In its element" / "{item}" | "★★" | | |
  | ★★★ (`regularStar`) | `nod`, 120 | "Regular" / "{item}" | "★★★" | | |
  | Family ★★ or ★★★ (`familyStar`) | `nod`, 130 | "Trophy family" / "{family} {stars}" | the stars | | |
  | Uncharted (`uncharted`), first Catch of each item ID | `nod`, 140 | "Unknown catch, logged" / "{item}" | "Logged" | | |

  `{item}` is the item's name, or "Item {id}" when the client doesn't have it yet. `{variety}` is the variety's name from `Pagle.GetVarieties` (VAR-R11), where it is first shown (VAR-R27); every variety moment's `icon` is the item caught, `art` (announcements.md › Contracts) the variety's art, and the last variety of all raises the `complete.varieties` title's `completeTitle` with them (VAR-R22). `{size text}` is LED-R81's, left out (with its separator) when the Catch has no size. `icon` is the item for every Catch moment; every other moment (level, Prestige, rank, Skill and Catch Milestone, completion title, family star) uses an in-client texture picked in the build ticket. Coins a live entry earns with no moment raised (an achievement already celebrated) count only in the total. A first Catch in a zone has no moment of its own: the New Species and Zone rank moments cover it. A title earned with a level-up, Prestige, Zone Master or Legend rides in that moment, never on its own. `seal` is what a banner's wax seal shows ([core/announcements.md › Contracts](core/announcements.md#contracts)): a number pressed into it, a pressed mark or the Prestige crest. Only the banners set one.

### Bindings

- **LED-R110** The Ledger registers no slot of its own: the binding every book wears is Core's (`core.binding`, SHOP-R25, ADR 0015), with Field Leather its default and every binding for sale. The Ledger registers its twenty earned bindings in it (SHOP-R23), in this order (IDs may be renamed before 1.0; names are lore, LED-R160):

  | Good | Kind | Working name |
  |---|---|---|
  | `ledger.binding.level10` … `ledger.binding.level60` (6 goods, one per 10 levels) | earned, `earnedText` "Angler Level {L}" | Tanned Hide, Tidewater Blue, Reed Green, Oxblood, Storm Grey, Nat's Own |
  | `ledger.binding.legend` | earned, `earnedText` "Land all three Legends" | Three Gilt Fish |
  | `ledger.binding.monster` | earned, `earnedText` "Land a Monster" | Monster Hide |
  | `ledger.binding.abyssal` | earned, `earnedText` "Prestige X" | Abyssal Black |
  | `ledger.binding.keeper` | earned, `earnedText` "Complete the Ledger" | Keeper's Gold |
  | `ledger.binding.iridescent` | earned, `earnedText` "Every fish in every colour" | Iridescent Scale |
  | `ledger.binding.wave` | earned (LED-R118), `earnedText` the count toward "300 catches at sea" | Breaking Wave |
  | `ledger.binding.logbook` | earned (LED-R118), `earnedText` the count toward "25 zones fished" | Captain's Logbook |
  | `ledger.binding.heartwood` | earned (LED-R118), `earnedText` the count toward "A catch after 10 got away" | Carved Heartwood |
  | `ledger.binding.stormglass` | earned (LED-R118), `earnedText` the count toward "Master in 10 zones" | Stormglass Reliquary |
  | `ledger.binding.lacquer` | earned (LED-R118), `earnedText` the count toward "30 days fished" | Black Lacquer Koi |
  | `ledger.binding.knit` | earned (LED-R118), `earnedText` the count toward "10,000 Casts" | Cable Knit |
  | `ledger.binding.flywallet` | earned (LED-R118), `earnedText` the count toward "5 different lures" | Fly Wallet |
  | `ledger.binding.carapace` | earned (LED-R118), `earnedText` the count toward "50 Big-mouth Clams" | Crab Carapace |
  | `ledger.binding.ember` | earned (LED-R118), `earnedText` the count toward "Prestige VII" | Ember Scale |

  A binding is a look only, and every binding's look and art are Core's, these twenty's too (SHOP-R25): Core draws them on the shop's stage with its slot's preview, so they have no `preview` of their own, and their icon is the ledger book of the level-up moment (LED-R97). The Ledger decides only when each is earned (LED-R111, LED-R116).

  The Curio Shop's second round adds ten bindings (the round-two kit's "Journal bindings · ten more" board). Nine are the Ledger's, the last nine rows above, each earned by LED-R118's rule with fallback tier 5 (SHOP-R28); their names and descriptions are its lore, `ledgergood.<goodID>` (LED-R160). The tenth, Shagreen and Bone, is Core's, `core.binding.shagreenbone`, for sale at tier 4 and in the Curio crate (SHOP-R25, SHOP-R50). Core ships all ten's art and draws them as it draws the rest (ADR 0015, [book-binding.md](core/book-binding.md)), each a whole book with its closed cover as its shop preview, and corner pieces, a clasp, a silk ribbon and a fillet colour of its own (BIND-R14 to BIND-R17).
- **LED-R111** A level binding's `isEarned()` is true when the higher of the peak level (LED-R35) and the highest level in the celebrated set is at least its level. The Ledger calls `M:RefreshGoods()` after a live entry that raises the peak level past a multiple of 10, and from `done` (SHOP-R31).
- **LED-R113** **Zone crests.** The Ledger registers fifty-three earned goods in Core's `core.crest` slot (SHOP-R23, SHOP-R25), `ledger.crest.<key>`, one per zone in its zone crest table (`logic/ZoneCrests.lua`: key, zone areaID and continent), named and described by lore (`crest.<key>.name`, `.description`, LED-R160) with the icon `Interface\AddOns\Pagle_Ledger\media\crests\<key>`. The table holds the two continents' outdoor zones (Blackrock Mountain, Lordamere Lake and The Veiled Sea among them), their capital cities and Forever's new zones; dungeons, raids and battlegrounds have none, and their Master earns the title alone. A zone that isn't charted (LED-R54) registers its crest anyway, shown as not yet charted until a release charts it. Crests register in continent order, Eastern Kingdoms (0), Kalimdor (1), then any other, each continent's in the order of its zones' names from `C_Map.GetAreaInfo`, and that is their order in Look and Feel's Crests dropdown (SET-R51). The Curio Shop doesn't list zone crests (SHOP-R25): they are earned (LED-R114), not sold, and equipped from Look and Feel; an equipped one stays on the Journal bookplate (LED-R112), and the Zone Master banner names it (LED-R97).

  | Continent | Keys |
  |---|---|
  | Eastern Kingdoms | `alterac` 36, `arathi` 45, `badlands` 3, `blackrock` 25, `blastedlands` 4, `burningsteppes` 46, `deadwind` 41, `dunmorogh` 1, `duskwood` 10, `easternplague` 139, `elwynn` 12, `hillsbrad` 267, `hinterlands` 47, `ironforge` 1537, `lochmodan` 38, `lordamere` 170, `redridge` 44, `riverglades` 16591, `searinggorge` 51, `silverpine` 130, `stormwind` 1519, `stranglethorn` 33, `swampofsorrows` 8, `tirisfal` 85, `undercity` 1497, `westernplague` 28, `westfall` 40, `wetlands` 11 |
  | Kalimdor | `ashenvale` 331, `azshara` 16, `barrens` 17, `darkshore` 148, `darnassus` 1657, `desolace` 405, `durotar` 14, `dustwallow` 15, `felwood` 361, `feralas` 357, `moonglade` 493, `hyjal` 616, `mulgore` 215, `orgrimmar` 1637, `shendralas` 16651, `silithus` 1377, `stonetalon` 406, `tanaris` 440, `teldrassil` 141, `thousandneedles` 400, `thunderbluff` 1638, `ungoro` 490, `veiledsea` 457, `winterspring` 618 |
  | Other (2991) | `zephras` 16593 |

- **LED-R114** A zone crest's `isEarned()` is true when its zone's shown rank (LED-R52) is Master. The shown rank never falls, so a crest is never lost: not when new data gives the zone more to find, and not when it stops being charted (LED-R54 keeps its celebrated rank). The Ledger calls `M:RefreshGoods()` after a live entry that raises a zone's shown rank to Master, and from `done` (SHOP-R31).
- **LED-R115** A zone crest's `earnedText` is a function (SHOP-R22) returning the row's tag and the stage's note, from the projection's last finished state (while it updates, the texts it gave last), which the Curio Shop, listing no earned crest (SHOP-R25), doesn't draw at present; `{zone}` is the zone's name (LED-R126), `{rank}` its shown rank, `{p}` its completion (LED-R53):

  | Zone | Row | Stage |
  |---|---|---|
  | charted, fished | "{rank} · {p}%" | "Earned when {zone} reaches Master in the Fish Journal. It is {rank}, {p}%. {next requirement}." (LED-R134, from Visitor up) |
  | charted, not fished | "Unfished" | "Earned when {zone} reaches Master in the Fish Journal. Catch anything there to begin." |
  | not charted | "Not yet charted" | "Earned when {zone} reaches Master in the Fish Journal, once its waters are charted." |

- **LED-R116** The Ledger's five other earned bindings (the Curio Shop expansion's) are owned when: Three Gilt Fish, every Legend item caught (LED-R63); Monster Hide, a sized Catch in the Monster band (`Pagle.SIZE_BANDS`, LED-R80); Abyssal Black, Prestige rank 10 or higher (LED-R34); Keeper's Gold, the `complete.ledger` title earned (LED-R75); Iridescent Scale, the `complete.varieties` title earned (VAR-R22). Each is checked against the projection and the celebrated set together (LED-R90), and once its rule holds it is noted in the celebrated set's `goods` (after a live entry and in `done`), so a binding once earned is never lost: not when a rebuild no longer holds what earned it (a Monster's Catch turned Uncharted, LED-R64), and not when a release adds to what its rule counts (a Legend more for "every Legend", LED-R72). The Ledger calls `M:RefreshGoods()` after a live entry that could earn one and from `done` (SHOP-R31).
- **LED-R117** The Ledger also registers four earned goods in Core's open slots (SHOP-R23, SHOP-R25), drawn and played by Core: `ledger.toaststyle.legend` (The Tall Tale), its first Legend caught (LED-R63), `earnedText` "Land a Legend"; `ledger.toaststyle.prestige` (Oxblood Vellum), Prestige rank 5 or higher (LED-R34), `earnedText` "Prestige V"; `ledger.soundset.concertina` (Old Salt's Concertina), Prestige rank 1 or higher (LED-R34), `earnedText` "Prestige I"; `ledger.soundset.choir` (Choir of the Deep), every Legend item caught (LED-R63), `earnedText` "Land all three Legends". Their names and descriptions are its lore, `ledgergood.<goodID>.name` and `.description` (LED-R160); each is kept once earned as LED-R116's bindings are, noted in the celebrated set's `goods`, and refreshing is as LED-R116.
- **LED-R118** **The second round's earned goods.** The Ledger registers seven more toast styles in Core's `core.toaststyle` slot (SHOP-R23, SHOP-R25), drawn by Core (ANN-R82), named and described as LED-R117's are (`ledgergood.<goodID>`, LED-R160), and nine bindings in Core's `core.binding` slot (LED-R110). Each has fallback tier 5 (SHOP-R28) and is owned when its count reaches its mark:
  - **Chapel Glass** (`ledger.toaststyle.glass`): twelve glass shards (LED-R119).
  - **The Deep Lure** (`ledger.toaststyle.deep`): 100 caught Casts between 00:00 and 03:59 realm time (the Cast's `minute` under 240; a Cast stored without one doesn't count).
  - **Ink and Koi** (`ledger.toaststyle.koi`): 25 **pairs**: a caught Cast with a Species among its Catches that was also among the Catches of the caught Cast before it, in log order on any character (got-away Casts between them don't break a pair, a caught Cast with no Species does; a run of three is two pairs).
  - **Mounted Trophy** (`ledger.toaststyle.trophy`): 25 size records beaten, a Species' or a Legend item's (LED-R82: a later Catch strictly longer than the record; the first sized Catch sets one and doesn't count).
  - **Fishmonger's Slate** (`ledger.toaststyle.slate`): 30 Species with a Catch (LED-R5's Species, not Legends).
  - **Through the Ice** (`ledger.toaststyle.ice`): 100 caught Casts in Dun Morogh, Alterac Mountains or Winterspring (zone 1, 36 or 618, Tunables).
  - **Cross-Stitch Sampler** (`ledger.toaststyle.stitch`): a Catch of each of the sampler's twenty Species (Tunables).
  - **Breaking Wave** (`ledger.binding.wave`): 300 caught Casts at sea: zone or subzone in the open-sea list (Tunables).
  - **Captain's Logbook** (`ledger.binding.logbook`): 25 zones fished (LED-R6).
  - **Carved Heartwood** (`ledger.binding.heartwood`): a caught Cast right after 10 or more got-away Casts in a row, in log order on any character.
  - **Stormglass Reliquary** (`ledger.binding.stormglass`): 10 zones at Master, the higher of the computed and the celebrated rank, as a zone crest is earned (LED-R52, LED-R114).
  - **Black Lacquer Koi** (`ledger.binding.lacquer`): 30 realm dates with a caught Cast (each Cast's realm date as LOG-R49 derives it).
  - **Cable Knit** (`ledger.binding.knit`): 10,000 Casts, caught and got away.
  - **Fly Wallet** (`ledger.binding.flywallet`): 5 different lures: distinct non-empty `lure` values on caught Casts.
  - **Crab Carapace** (`ledger.binding.carapace`): 50 Catches of the Big-mouth Clam (item 7973).
  - **Ember Scale** (`ledger.binding.ember`): Prestige rank 7 or higher (LED-R34), by the state or the highest celebrated rank.

  The counts the projection doesn't already hold (it holds the Casts, the Species, the zones fished and their ranks, and the prestige rank) are kept in its `counts` (Data), by the fold for every Cast, live or not; "in log order" means `seq` order, across the Angler's characters. Each good's `earnedText` is a function (SHOP-R22): the row's tag "{n} of {mark} {unit}" ("7 of 12 shards"; the plain earned text for Heartwood and Ember, whose mark is one step) from the projection's last finished state (while it updates, the tag it gave last), and the stage's note, the earned text in full ("12 glass shards"). Each is kept once earned as LED-R116's are: when its count reaches its mark it is noted in the celebrated set's `goods` (LED-R90) after the live entry or in `done`, and `isEarned()` is true when it is there or its count is at the mark, so a good once earned is never lost, not even when a rebuild counts lower (a newly classified Species, a retuned length). The Ledger calls `M:RefreshGoods()` after a live entry that notes one and from `done` (SHOP-R31). Reaching a mark raises no moment: the Curio Shop is where it shows.
- **LED-R119** **Glass shards** (Chapel Glass). A caught Cast with a zone (≠ 0) and a realm date (LOG-R49) earns one shard when it is the first caught Cast of its realm date in that zone and the zone had no caught Cast on any of the six realm dates before: a new water, or one left a week. Twelve shards earn the style. The projection keeps each zone's latest realm date with a caught Cast (as a day number) and the shard count; shards are never spent.
- **LED-R112** The Journal wears the binding every book wears, `Pagle.GetEquipped("core.binding")` (ADR 0015), drawn by Core's renderer (`Pagle.NewBookBinding`, [book-binding.md](core/book-binding.md)): its material, band, corner pieces and features, and the change of binding, which dips the open book with Core's one page-turn sound (BIND-R20, BIND-R21). The Journal draws none of the leather and plays no sound of its own for it. From the look Core hands it (BIND-R3) it inks its own parts: the crumbs in the look's `gilt` over its `giltShadow`, the fleurons between them toward that gilt, the brass plate silver where the look's `silver` says, and both pages' paper in its `paperTint`. Its bookplate shows `Pagle.GetEquipped("core.crest")`'s icon, pinned as the crest's shield (SHOP-R25, LED-R146), or no emblem while that is the slot's default, Plain ("No emblem, only the owner's name"). It redraws on `AppearanceChanged` for either slot.

### The Fish Journal

The Journal is a two-page book (UI). These rules say what it shows; [UI](#ui) says how it looks.

- **LED-R120** The Journal (global frame name `PagleLedgerJournal`) opens and closes from the compartment entry "Fish Journal", `/pagle journal` and the Settings root's "Open Fish Journal" button; each toggles it. Esc closes it (`UISpecialFrames`). It is a book on Core's shell (`Pagle.NewBook`, [book.md](core/book.md), ADR 0016), `ledger.journal`: it moves by dragging its leather, kept on the screen, and Core saves where it is left, so each opening shows it there (BOOK-R5; centred, lifted 40 units, until it is first dragged). The first opening after a login or `/reload` shows Home; later ones show the spread it was left on.
- **LED-R121** It creates no secure frames, so it opens and works normally while restricted. Its Curio Shop and Field report links then print Core's chat lines instead (SHOP-R41, CORE-R33).
- **LED-R122** While the projection is updating (LOG-R74), both pages show only, as the book's notice (BOOK-R22), "The Ledger is being written up from your Catch log." with the breadcrumbs and search hidden. It redraws when the update finishes.
- **LED-R123** When a live entry changes what the open spread shows, the spread redraws on the next frame, keeping its selection. Each page body scrolls vertically when its contents overflow. Lists with no order given here sort by ID ascending (item, family, zone areaID, character index).
- **LED-R124** **Never named until caught:** an uncaught Species, Legend or curio item is never named anywhere in the Journal (lists, entries, notes, search, tooltips), and its own icon is never shown: in its place the Journal draws the one unknown-fish medallion every uncaught thing shares, so it never hints which item it is. Uncaught trophy weights are shown, since they are only numbers.
- **LED-R125** **Navigation:** one spread at a time, each spread one of the book's pages (BOOK-R20). Gilt breadcrumbs on the leather above the pages, the shell's (BOOK-R12, BOOK-R24), a fleuron between each two, read Home » {continent tab label} » {zone} » {fish} (or Home » {collection} » …); each crumb opens its level. A fish spread opened from search or a note reads Home » {fish}; a collection spread Home » {collection}. The continent crumb opens Home on that continent's tab. Every spread but Home has a "« back" link on the left page that goes one crumb up (the shell's, BOOK-R13). The Journal picks how each move goes (BOOK-R34): another spread, or another subject on the left page but Home's (LED-R129), turns the page, forward when the crumbs go deeper; a change of the right page's subject alone (a fish picked) crossfades, with the pick's sound; a Legend's plate and everything else draw in place (BOOK-R30). A Prestige turns the page forward on the Angler page (LED-R33). A search box sits at the leather's right, a leather anchor (BOOK-R16), with the placeholder "Find a fish or a water…" (LED-R148).
- **LED-R126** **Names:** item names come from `C_Item.GetItemNameByID`; when it returns `nil`, the Ledger calls `C_Item.RequestLoadItemDataByID`, shows "..." (or "Item {id}" in the Uncharted list), and redraws on `GET_ITEM_INFO_RECEIVED` (registered with `Pagle.RegisterEvent`). Zone names come from `C_Map.GetAreaInfo`, the Eastern Kingdoms and Kalimdor tab labels from `C_Map.GetMapInfo` on the continent's uiMapID (Tunables); "Other waters" is interface text (LED-R130). Character names come from `Pagle.GetAngler().characters`. A name that can't be found shows "...". Dates are the Cast's realm date (`conditions.date`) as "{day} {month abbreviation}", with the year added when it isn't the current realm year. The **realm date** of a server time (LED-R127) is worked out live as LOG-R49 does: realm minute (`GetGameTime()`) minus the UTC minute of `GetServerTime()`, rounded to 15 minutes and taken in the range LOG-R49 gives (−10 h excluded to +14 h), gives the offset.
- **LED-R127** **Window labels and forecasts.** A window is labelled from its ID through `ns.L` (`day` "day", `night` "night", `spring`, `summer`, `autumn`, `winter`, `event.301` "Extravaganza", any other `event.<id>` "event"). Its **state** comes from `Pagle.NextWindow(spec, GetServerTime())`, recomputed when the spread is drawn: `openNow` → "biting now"; `opensAt` less than 48 h away → "back in {n} h" (hours rounded up, or "{n} min", rounded up, under an hour); `opensAt` further → "back in {month}" (the month of `opensAt`'s realm date); `nil` → no state. A window's `confirmed` flag isn't shown.
- **LED-R128** Catalogue `confirmed` flags change nothing in the Ledger and aren't shown in the Journal.
- **LED-R129** **Scroll:** each page keeps its scroll position while its **subject** stays the same, through every redraw (LED-R122, LED-R123, LED-R126) and every click on either page; it goes back to the top only when its subject changes. A page's subject is its spread and, on Home's left page, the continent tab; on the zone spread, the zone, and on its right page also the Species selected; on the fish spread, the Species; on the varieties spread, the Species, and on its right page also the variety selected; on the Trophy Room's right page, the family; on the Legends spread's right page, the Legend. So selecting a fish or a variety or opening a plain hint keeps the other page where it was, and opening another zone, tab or spread (from a tile, tab, crumb, back link, note or search) starts each page whose subject it changes at the top.

#### Home

- **LED-R130** **Left page:** kicker "The Waters", title "Where I've Fished", then up to three **continent tabs**, in this order: Eastern Kingdoms (`GetArea(zone).continent` 0), Kalimdor (1), and "Other waters" (every tile on any other ContinentID, or whose zone `GetArea` doesn't know). A tab with no tile isn't shown. Below them, the chosen tab's tiles in a grid, scrolling when they overflow. The first tab shown is chosen at first opening. Forever's new zones are tiles like any other, under the tab their `continent` gives; there is no separate group for them.
- **LED-R131** A **tile** stands for each charted zone and each zone the Angler has fished that isn't charted, sorted by `skillBase` (zones without one last), then by areaID. Every tile is the kit's one size, so the grid's rows stay even. A tile shows the zone's name, in at most two lines (a size smaller where a word is wider than its room, as beside the seal, or the name runs past two lines; cut even so, it ends in an ellipsis), then, always under the name's last line:
  - fished and charted: its shown rank and completion ("Local · 63%"), a thin ink bar of the completion, a wax seal at Master, and a red "{N} new!" note when it has new to find (LED-R52)
  - charted, never fished: faded, "unfished · skill ~{skillBase}" ("unfished · any skill" when the skill base is 0 or below, DATA-R30; just "unfished" without a skill base)
  - not charted: "uncharted waters"
  
  Clicking a tile opens its zone spread.
- **LED-R132** **Right page:** the **bookplate summary**: the Angler Level in large numerals with the Prestige emblem and stars beside it, the active title in handwriting, the ink XP bar (LED-R145) using the shown level (LED-R36), and a wax seal with Ledger completion %. Then **Notes to self** (LED-R133), then **In this Ledger**, a contents list with dotted leaders: "The Trophy Room" with weights x / N; "Curios: junk, treasure, uncharted" with collected x / N of both; "Legends" with x / N; "The Angler: hands, titles, bindings"; from Track V, last, "Following" with the number of Followed Anglers (LED-R151). Each opens its spread.
- **LED-R133** **Notes to self** are generated progress nudges, at most 3, in this order, each only if it applies. Each opens the spread it names.
  1. **Next rank:** of the fished charted zones with shown rank Visitor to Expert and no new to find, the one with the highest completion (ties: higher rank, then lower `skillBase`, then lower areaID): "{zone}: {rank}. {next requirement}" (LED-R134).
  2. **New to find:** the first zone in tile order with new to find: "{zone}: {N} new to find".
  3. **Next star:** the caught, not removed Species without a shown ★★★ (LED-R48) that has the most Catches (ties: lower Species ID): "{name}: {5 − n} to ★" while its ★ isn't shown, else "{name}: {50 − n} to ★★★".
  
  With none, one note reads "Go fishing!". Notes never say what is catchable now (that is Hunts').
- **LED-R134** The **next requirement** for a zone, from its shown rank: unfished "Catch anything here to become a Visitor"; Visitor "Regular: {k} more any-time Species"; Regular "Local: {k} more any-time Species"; Local "Expert: " then, joined with ", ", "{k} more day, night, seasonal or event catches", "a piece of junk", "a treasure" for each part still unmet; Expert "Master: a trophy from {k} more families"; Master "Master of these waters". `k` counts what the rank above the shown rank still needs beyond the shown rank's own requirements. With new to find, " · {N} new to find: the data grew, and your seal stays" is appended (for Master it replaces "Master of these waters").

#### Zone spread

- **LED-R135** **Left page (charted zone):** kicker its continent tab's label (LED-R130), title the zone's name, a wax seal with the shown rank ("unfished" if none), the rank ladder Visitor · Regular · Local · Expert · Master with ranks reached inked and the shown rank circled, "Next: {next requirement}", and "{N} new to find here! My seal stays." when it has new to find. Then the catches, in groups, each with a header "{group}" and "{caught here} / {total}" at its right, and left out when empty:
  - **Any time:** Species ungated here and not pool-associated
  - **Pools:** Species ungated here and **pool-associated** (`PagleItem.pool`, LOG-R55, true for any of its items on this zone's list), with the group note "open water and pools combined" before its count, as Stats groups them (STA-R18)
  - **Day and night:** gated here, with `day` or `night` among their windows here
  - **Seasonal:** gated here, with no `day` or `night` window and not only `event.*` windows
  - **Events:** gated here, with only `event.*` windows
  - **Trophies:** one line per family on the list, "a {family} trophy, any weight", ticked when one was landed here
  - **Curios:** "a piece of junk" and "a treasure", for each requirement the zone has, ticked when met
  - **Also caught here:** Species caught here but not on this zone's list (they count for nothing here), header "Also caught here" with {n} at its right, with "Not in Pagle's list for these waters yet." and a "Help chart the waters" link (`Pagle.OpenFieldReport()`)
  
  The groups show in that order; within a group, rows sort by Species ID. A gated pool-associated Species sits in its window's group. Groups only arrange the page: Any time and Pools together are the zone's ungated Species for Zone Mastery (LED-R50).
- **LED-R136** A Species row shows: its icon (the unknown-fish medallion if never caught, LED-R124); its name if caught anywhere (with "(caught elsewhere)" when not caught here), else "— unknown —"; in the margin, in handwriting, each of its windows here as "{label}, {state}" (LED-R127), and "pools" when it is pool-associated; and its stars when caught here. Clicking it selects it: the right page shows its entry and the breadcrumbs add it.
- **LED-R137** **Right page, nothing selected — "About these waters":** kicker the zone's name, title "About these waters", then "Skill ~{skillBase}" ("Any skill" when it is 0 or below, DATA-R30; left out without one); "{completion}% of these waters known: {a} of {b} fish, {c} of {d} trophy families"; "Trophies landed here", one line per family on the list with its stars and its overall "x / N" weights (opens it in the Trophy Room); and "Reward for mastery: each new seal earns XP. The Master seal earns the title {zonemaster title}." Then "Pick a fish on the left to read its page."
- **LED-R138** **A zone that isn't charted:** left page: kicker its continent tab's label, its name with an empty seal reading "uncharted", the lore line `line.unchartedwaters.text`, "Every catch here is still written down, and counted once Pagle's data catches up.", and a blank chart. Right page: kicker "Loose pages", title "What came up here", then under "Uncharted" its Uncharted items caught here ("{item}: {n}×", the count per zone, LED-R64), the group left out when it has none; then "Also caught here": each Species caught here (rows as LED-R136, no margin), and each trophy and curio item caught here, by name; or, with neither, "Nothing caught here yet."; then a "Help chart the waters" link. Every "Help chart the waters" link is drawn as a button beside "Seen something Pagle doesn't know?". Knowing which trophy and curio items were caught in a zone needs `items` per zone, kept in the zone's state (Data).

#### Species entries and the fish spread

- **LED-R140** **A caught Species' entry:** its icon drawn in sepia, large; its name; three stamps, Caught / In its element / Regular, inked when earned (LED-R92); "First landed {date} in {zone}, by {character}. {n} caught." (the zone part left out for zone `0`); for a Species with varieties, its varieties card (VAR-R23); its blurb (lore); "Found in {listed zones, joined with ', ' and ' and '}." (left out with none) plus " Only by {element window labels}." when it has element windows; "Largest I've landed: {band} · {length}" when it has a record; and "No longer found in Forever's waters." when removed.
- **LED-R141** **An uncaught Species' entry:** the unknown-fish medallion in place of its icon; "An unknown fish"; its riddle (lore) in quotes; and a "Read the plain hint »" link that replaces itself with the **plain hint** (DATA-R112), generated here: its element window labels joined with ", " (or "Any time"), then " · pools" when any of its items is pool-associated, then " · " and its first two listed zones by skill base (" +{n}" for the rest), then " · skill ~{lowest skill base among those two}" when either has one (" · any skill" when that is 0 or below, DATA-R30). With no listed zones, the hint is the window part alone. The hint stays open until the spread changes.
- **LED-R142** **The fish spread** (from search or a note; both only ever name caught Species): the left page is the entry; the right page has kicker "Where to find it", title "Its waters", its listed zones as tiles (as LED-R131, plus "caught ✓" where caught, at the right of the tile's rank line, so a long zone name never runs under it), "When" with each element window's "{label}, {state}", and for a caught Species, "☐/☑ Caught ({min(n, 5)}/5)", "☐/☑ In its element ({have}/{need})" and "☐/☑ Regular ({min(n, 50)}/50)". For ★★ by windows, `have`/`need` count windows; by zones, distinct zones. A tile opens that zone's spread with the fish selected. The way to its varieties is the card in the entry (LED-R140, VAR-R23).
- **LED-R151** **The varieties spread** (VAR-R24, VAR-R27; from the fish spread's "See all ten »"): its crumbs read Home » {fish} » Its colours, so « back opens the fish spread. The left page and the right page are VAR-R24's; the right page's kicker reads "A common colour", "An uncommon colour", "A rare colour" or "An epic colour", in the rarity's ink. A row opens its variety on the right page (`JournalPlace.varieties(species, position)`); with none asked for, the first caught is selected, or position 1. An uncaught variety is never named, nor its words or colours shown (VAR-R27): its row reads "Undiscovered" over its silhouette, the right page "Not yet discovered", and the foot "{10 − n} to go." names none of the rest. Search and Notes to self never name a variety (LED-R148, LED-R133), and an uncaught Species' varieties spread reads "An unknown fish" where its name would be (LED-R124).

#### Collections

- **LED-R143** **The Trophy Room:** left page kicker "A collection", "The Trophy Room", "{x} of {N} weights.", then under "Families" (with "weights" at its right) the family index, a row per family (family name from lore, stars, "x / N"), the chosen one marked. Right page, the chosen family (first one by default): kicker "A trophy family", its name, three stamps (Any weight / Half the weights / The heaviest), a measuring board with a mark per weight, inked where landed and the heaviest landed marked "heaviest" in the hand, "pounds", "Landed {x} of {N}. Heaviest so far: {w} lb." (or "Not one of this family yet."), a removed weight left out of both (LED-R12), and "Found in {zones whose list has the family}."
- **LED-R144** **Curios:** left page kicker "Junk", "The Junk Museum", "{x} of {N} exhibits", then a plinth per junk item: caught, its icon, name and plaque (lore); uncaught, the unknown-fish medallion, "An empty plinth" and the lore line `line.uncaughtjunk.text`. Right page kicker "Containers and treasure", "Treasures", "{x} of {N} opened", a line per container or treasure item: caught, its name and plaque; uncaught, the lore line `line.uncaughttreasure.text`. Then "Loose pages: Uncharted": one handwritten line per Uncharted item, by first Catch: "{item}: {n}× at {its zones' names joined with ', ', or 'unknown waters' when it has none}, first {date}. Unknown to Pagle. Logged.", or "None. Every catch is in the Ledger."; then "Help chart the waters" (`Pagle.OpenFieldReport()`).
- **LED-R145** **The ink XP bar:** the climb's progress to the next level, with Fresh Water (LED-R23), and under it "{xp} of {cost}." followed by " Fresh Water for {F} more Catches." in blue (" Fresh Water for 1 more Catch." when `F` is 1) when `F` is above 0 (LED-R36 for a shown level above the computed one). At a shown level of 60: a full bar, no Fresh Water, and "{carried} XP set aside for the next Prestige" (0 while the computed level is below 60). "Level 60" in LED-R23 means the shown level. Hovering the bar shows a tooltip, "Where this climb's XP came from", with the lines of LED-R150 for this climb.
- **LED-R146** **The Angler:** left page, the **bookplate**: the Prestige frame for the prestige rank (LED-R154) holding the Angler's likeness (the player's portrait), with the equipped crest pinned on it (LED-R112: the shield, 50 units wide, centred on the frame's pin point, turned 6° clockwise, a gilt pin through its top, with a soft shadow; nothing for Plain), "Ex Libris", "The Angler's Ledger", "kept since {firstDate}" (left out before the first Catch; when no Catch has a realm date, the first Catch's server time as a realm date at the offset now, LED-R126), the shown level with "Angler Level" and the active title in handwriting beside it, the Prestige emblem (LED-R152) and stars beside "Prestige {I…X}" or "Master Prestige {n}" (or "No Prestige yet", with no emblem), the ink XP bar, the **Begin a new Ledger (Prestige)** button when LED-R33 allows it, "The Ledger" with "{p}% of the Ledger complete ({done} of {total})" at its right, the parts of LED-R71 one per line, each part's name with "{x} of {N}" at the right ("Species", "Varieties", "Junk Museum", "Treasures", "Trophy Room weights", "Zones mastered"), and "{lifetime} Catches · next milestone {T}" (just "{lifetime} Catches" after the last). Right page: "Hands on the Rod", one line per character with a Skill Reading, by character index, its name with "skill {rank} / {max}" at the right; "Milestones" with ☑/☐ for 75, 150, 225 and 300; "Signed As", "Automatic" then the earned titles in LED-R75 order as a pick list of radios, the active pick's filled (clicking one sets the active title, LED-R77); "Bindings", every binding in Core's slot as the Curio Shop lists it (`Pagle.GetSlotGoods("core.binding")`: Field Leather, those for sale by tier, then the Modules' earned ones), its closed book (the Journal's own swatch of it; none for one whose swatch is the shop expansion's covers', the second round's covers' or that has none), its name and its state: "In use", a "Use" link (`Pagle.SetEquipped`) when owned, how the Ledger's own earned one is earned ("Angler Level {L}", its LED-R116 `earnedText`, or a second-round one's earned text in full, "25 zones fished", LED-R118) when it isn't yet, and "In the Curio Shop" (`Pagle.OpenShop(goodID)`) for any other not owned. The pick is the binding every book wears (ADR 0015).
- **LED-R150** **Where your XP came from** (the Angler page's right page, after "Bindings"; [#278](https://github.com/timemir/wow-fish/issues/278)): a heading, then one line per source with its XP at the right, for "This climb" and "All told" side by side: "Catches and discoveries" (the Ledger's own XP), then each source in `Pagle.GetActivityXP().bySource` by its Module's title ("Hunts", "Tackle Board"), in Core's Module order. A disabled source's line is greyed and struck through in red ink, as in the Curio Shop's purse ([wallet-and-shop.md › UI](core/wallet-and-shop.md#ui)), and still counts. "All told" is the Ledger's own lifetime XP and each source's total; "This climb" is the climb's own XP and the current climb's Activity XP (LED-R37), split by source in proportion to each source's rise since the latest Prestige snapshot. *Decided while writing the spec (#289): the snapshot stores one total, not one per source, so a climb's split by source is worked out from the totals' rises and is labelled approximate only in the tooltip ("by source, roughly").* *Decided in #295: each source's total at a Prestige comes from `PagleLedgerDB.global.prestigeSources`, which the confirm card writes as it calls `M:RecordPrestige()` (LED-R33): `Pagle.GetActivityXP().bySource`'s totals, with the entry's `rank` and `activityXP`. It is display only, outside the projection, and never rebuilt. A source's rise is its total now minus its saved total (0 when it wasn't saved, never below 0). With nothing saved for the latest Prestige (a Prestige made before #295, or a lost `PagleLedgerDB`), or no rise at all, the climb's Activity XP is split in proportion to each source's total now. The parts are rounded to sum to the whole. A disabled Module isn't registered, so the Ledger names each source in its own words (its `def.title`, in `ns.L`) and orders them by the roster's Module order; a source it doesn't know comes after them, by its `def.name`.*
- **LED-R147** **Legends:** left page kicker "Outside the hundred", "Legends", "{x} of {N}. These sit outside the Ledger's hundred.", then under "The index" the index: caught ones by name with their icon, uncaught ones as "an unwritten legend" with the unknown-fish medallion, in item ID order. Right page, the chosen Legend: caught, the Legend's own crest (LED-R153) with its icon in sepia, name, "{date}, {zone}, {character}", its blurb, "Title: {title}" and an **Open the plate** button; uncaught, the Unwritten crest with its own plain fish (never the Legend's crest or its icon, LED-R124) and the lore line `line.uncaughtlegend.text`. **The plate** is one page across the spread: kicker "A Legend of these waters", the Legend's crest (LED-R153) with its icon, name, the first Catch's date, zone and character, its record size text, and its title beside a wax seal reading "Title"; clicking anywhere returns. It is drawn by the Journal and is not an Announcement.
- **LED-R151** **Following** (from Track V; [#76](https://github.com/timemir/wow-fish/issues/76) item 11, variant A of pagle-backend's prototype, IGV-R81): a spread like Legends, drawn from `Pagle.GetFollowedAnglers()` alone (VIEW-R11), read each time the spread is shown. With the Ledger off there is no page, and the tooltip block (VIEW-R20) still shows.
  - **Getting there:** Home's "In this Ledger" line "Following" (LED-R132) shows the number of Followed Anglers in state `ok`, "0" in `none`, "—" in `expired`, and greys out as "no Companion" in `absent`. Every state opens the spread. Breadcrumbs as every other spread's (LED-R125): Home, then Following, with the back link.
  - **Left page:** kicker "In this Ledger", title "Following", then "{n} Anglers you follow. Follow and unfollow on the Pagle website." Then the index, one row per Followed Angler in `GetFollowedAnglers`' order (by name, IGV-R31): the name, an "HC" stamp for a Hardcore Angler, and on the right "Lv {L} · {roman} · {p}%", with no roman numeral at rank 0 and X from rank 11, and just before it the Angler's Prestige emblem at 22 (LED-R152), the Master's from rank 11. At rank 0 there is no emblem and no room kept for one: the row keeps its height, its name its place and its value its right edge, as every other row's. It scrolls (LED-R129), up to the followed cap. Clicking a row selects it; the first is selected when the spread opens.
  - **Right page,** the selected Angler's card: kicker "Hardcore Angler" when it applies; the name; "and {n} more characters" when `more` is above 0; the title in handwriting, left out when it is `""`; the Angler Level in large numerals with the Prestige under it as the bookplate writes it (LED-R146: "Prestige {I…X}", "Master Prestige {n}", or "No Prestige yet" at rank 0); a wax seal reading "Ledger {p}%"; ruled rows "Legends {n} of {N}", "Waters mastered {n}" and "Lifetime Catches {n}"; last, "As of {date}", the `asOf` UTC date in LED-R126's date format. No region.
  - **Empty states:** the left page keeps its kicker and title, and the right page is blank:
    - `none`: "You follow no one yet." / "Follow an Angler from their page on the Pagle website." / "The Companion brings them in within the hour; they show here after your next /reload."
    - `absent`: "The Companion keeps this page." / "Anglers you follow on the Pagle website are brought into the game by the Pagle Companion." / "Without it, this page stays empty. Pasting your log still updates your own Angler page."
    - `expired`: "These pages are more than a day old." / "Pagle has set them aside until the Companion brings fresh ones." / "Start the Companion, then /reload."
  
  *Decided while building (#342):* the count line and "and {n} more characters" take the singular for one ("1 Angler you follow.", "and 1 more character"), as the prototype does. A row selects by its place in `GetFollowedAnglers`' order, since two Anglers may share a name (IGV-R31); a place the file doesn't have selects the first. An empty state's first line is in the hand and its last faded. The "HC" stamp is red small capitals in a ruled red box after the name; the card's level is "Angler Level" in small capitals over the numerals with the Prestige's words under them and the seal at the right, all in the art kit's faces, inks and seal, with no new texture. *Decided with the emblems in lists:* a row's emblem sits 5 units before its value, not after the name, so the names and stamps line up down the index and the emblem reads with the numeral it shows; it is centred on the row's 25 units, so it needs no taller row.
- **LED-R148** **Search**, in the slip that is the book's leather anchor `search` (BOOK-R16; hidden while updating, LED-R122, and under a Legend's plate), matches, case-insensitively as a substring, the names of the zones that have a tile and of caught Species and caught Legends (never anything uncaught, LED-R124), on every text change from the first character, showing at most 4 zones then 6 fish in a dropdown, the zones under "Waters" each with its tile's line, the fish under "Fish" each with its icon, each part sorted by name; picking one opens its zone or fish spread (a Legend opens on the Legends spread with it chosen). A Species matches by its representative item's name (LED-R5). With no match: "Nothing by that name in the Ledger yet." Items whose names aren't loaded yet don't match.
- **LED-R149** **The brass plate** on the cover's lower left corner, the shell's nameplate (BOOK-R14), always shows "Lv {shown level} · {active title} · Ledger {p}%".

### Pagle's backend

- **LED-R155** **The backend's Journal values** ([#76](https://github.com/timemir/wow-fish/issues/76) items 5 and 18, pagle-backend's `angler-page.md` › Journal values, `journal.v` 3). Besides the values LOG-R79's hooks list, the Ledger's `JournalValues(state, sessionRows, total)` gives, from its state and the world index alone (CORE-R7), with the client's values for the same state:
  - `xp`: `{ ledger }`, the Ledger's own XP all told, every climb's, without Activity XP: the state's `lifetimeXP`, which "Where your XP came from" shows as "Catches and discoveries" under "All told" (LED-R150). `total` doesn't change it.
  - `varieties`: every Species of LED-R11's world with varieties (VAR-R2), by Species ID, each `{ species, caught }`, with `caught` its caught varieties in position order, each `{ id, position, rarity, first }`: the variety ID `<speciesID>.<key>` (its catalogue item's keys, VAR-R4), its position 1–10, its rarity (`common`, `uncommon`, `rare` or `epic`, VAR-R2, the Ledger's frozen copy of Core's positions, so it needs no `Pagle.GetVarieties`, which the driver doesn't host) and the server time of its first Catch. A Species with none caught has `caught = {}`. These are the varieties the Ledger counts (VAR-R20); Core's variety projection holds the same positions (VAR-R10).
  - `crests`: every crest the state earns, each `{ id, kind, zone | species, earnedAt }`: first the zone crests (`kind` `"zone"`, `zone` the areaID) in the zone crest table's order (`ns.ZONE_CRESTS`, LED-R113), each once its zone's **computed** rank is Master (LED-R50), never by the celebrated set's shown rank, which never leaves the client (LOG-R77, LED-R114 keeps it in game), `earnedAt` the time of the Cast that raised the computed rank to Master; then the fish crests (`kind` `"fish"`, `species` the Species ID) by Species ID, each once all its varieties are caught (VAR-R12, VAR-R20), `earnedAt` the latest of its varieties' first Catches, the Cast that completed it. `id` is the crest's good ID (`ledger.crest.<key>`, `core.crest.fish.<speciesID>`), as the web art's `index.json` keys them (DATA-R136).

  To keep the two times, the projection stores a zone's `masterAt` and each variety's first `time` ([Data](#projection-state-pagleledgerdbglobalprojectionprojection-log-r70)); `LEDGER_RULES_VERSION` 8 rebuilds it (LED-R4).
- **LED-R156** **The crest record** ([#76](https://github.com/timemir/wow-fish/issues/76) item 19, ADR 0008). The crest the bookplate pins (`Pagle.GetEquipped("core.crest")`, LED-R112) is a player's choice that `PagleDB.profile.appearance` keeps outside the log, so the Ledger logs it as its own Module record, kind `crest` (`ns.CREST_RECORD`), its payload the crest's good ID, or `""` for the slot's default, Plain. It appends one, the frame after the pinned crest changes (`AppearanceChanged` for `core.crest`, SHOP-R33) and the frame after its projection's `done` (from `done` itself `M:AppendRecord` raises, LOG-R40), whenever the pinned crest isn't the one the log's latest crest record names; a log without one names Plain. So it logs nothing for a Player who never leaves Plain, logs a crest already pinned when this rule ships once, at the next login, and never logs while the projection updates (`done` follows). A demo that equips a crest for show never logs to `PagleLog`: while `/pagle trailer` runs, the Ledger's `M:AppendRecord` writes to the trailer's disposable log (its `moduleRecords`, as the Tackle Board's does) and folds into the sample's state, and once the trailer puts the Angler's own crest and projection back, the check after it compares that crest with the real log's latest record, as at any other time, so the demo crest is never logged, then or at the next `done`. Its fold keeps the latest crest record by entry time as `crest = { good, time }`, the later in log order on equal time; nothing else reads it in game. Pagle's backend reads each crest record with `EquippedCrest(record)` (LOG-R79), takes the latest by entry time, and shows it only when its own fold earns that crest (LED-R155).
- **LED-R158** **The measures' rise times** ([#364](https://github.com/timemir/wow-fish/issues/364), [#76](https://github.com/timemir/wow-fish/issues/76) item 16, pagle-backend's PRJ-R8). The projection keeps `rises` ([Data](#projection-state-pagleledgerdbglobalprojectionprojection-log-r70)): Ledger completion's `done` and `total` (LED-R70), the Species caught and the Legends caught (LED-R71, LED-R63), and `at`, which holds, for Ledger completion, Species caught and Legends caught, by `Measures`' keys (`ledgerCompletion`, `speciesCaught`, `legendsCaught`), the entry `time` of the record whose apply last made that measure greater than it was just before it, Ledger completion by its percentage; nil while it never rose. These are the times the backend's driver got by reading `Measures` after every record; it reads them with `MeasureRises(state)` (LOG-R79) after `done` instead. Only a Cast raises them, and its apply works them out from the achievements it appended, never from Ledger completion over the whole world. A fresh state's `total` is the world's with nothing caught; then each achievement counts as LED-R70 counts, a removed item or Species on neither side (LED-R12):
  - `newSpecies`: a Species caught and a part done; for a Species on no zone list, one more part in `total`, and another for its varieties when it has some (VAR-R20);
  - `fishComplete`: a part done (the varieties');
  - `newCurio` and `trophyWeight`: a part done, with one more in `total` for an item on no zone list;
  - `zoneRank` reaching Master: a part done (LED-R50);
  - `legend`: a Legend caught.

  Then each of the three measures greater than before the Cast takes the Cast's time: one comparison each per Cast. Ledger completion's percentage can fall (LED-R72): a Species with varieties on no list adds two parts to `total` and one done, so 100% becomes 90% with 10 of 11. Its next rise takes that Cast's time, even when it only climbs back. The Angler Level has no rise time, since the climb's Activity XP (LED-R37) rises on Hunts and Tackle Board records that the Ledger never sees: the backend reads it after every record with LED-R159's hook. Nothing in game reads `rises`. `LEDGER_RULES_VERSION` 9 rebuilds the projection to keep it (LED-R4).
- **LED-R159** **The Angler Level alone** ([#364](https://github.com/timemir/wow-fish/issues/364)). `AnglerLevel(state, total)` (LOG-R79) gives `Measures`' `anglerLevel`, `{ prestige, level, xp }`: the prestige rank and the climb's level and XP (LED-R30–R32), its Activity XP from `total` included (AXP-R9, LED-R37). It works out no Ledger completion, so the backend's driver can read it after every record of any Module.

### Lore

- **LED-R152** **Prestige emblems**: one per rank I to X and the Master's, each its Prestige frame in miniature with its numeral on a centre disc, from Core's `media/prestige/Emblems` atlas (64 × 64 sprites, the numeral in the art, `Pagle.SetPrestigeEmblem`): drawn at 64 units on the Prestige confirm card (LED-R33), at 34 beside the Angler Level and the Prestige line (LED-R132, LED-R146), and at 22 in lists and tooltips (the Prestige frame's tooltip, LED-R154; the Following index's rows, LED-R151; and Core's Pagle block on a player's tooltip, VIEW-R21), where its shape and colour carry the rank. No Prestige has no emblem.
- **LED-R153** **Legend crests** (the Prestige frames kit's "Legend crests" board): each Legend item has a crest of its own, from Core's `media/legends/Legend<Key>` (Core's, since the Legend splash shows it too), keyed by item ID in Core's legend crest table (19803 racer, 19805 angelfish, 19806 queenfish): **The Racer’s Crest** for Brownell's Blue Striped Racer; **The Angel’s Crest** for Keefer's Angelfish; **The Queen’s Crest** for Dezian Queenfish. A crest is the kit's sprites in the same 260 × 280 box as a Prestige frame: what lies behind, the Legend's item icon in sepia masked round in the well, the crest, what crosses over it, the label plaque reading "Legend", and its motion sprites (each with the duration, easing and origin the kit lists; with Animations off they rest, as LED-R154). A Legend not yet caught shows the **Unwritten** crest with its own plain fish in the well, its plaque reading "Unwritten", so the crest never gives away which Legend is still out there (LED-R124); a caught Legend with no crest of its own (one added after 1.0) shows its icon in the Unwritten crest. The Journal draws a crest 150 units wide on the Legends page and 190 on the plate; the splash, at its full size (announcements.md › UI, Splash).
- **LED-R154** **Prestige frames** (the Prestige frames kit's "the voyage" board): one frame per prestige rank, the Angler's journey from the jetty out to sea, down into the deep and up to the stars. Each is its own object round the likeness, drawn by Core (`Pagle.NewPrestigeFrame`) from its `media/prestige/Frame<Key>` (Core's, since the Prestige banner shows it too, ANN-R83) as the kit's sprites: what lies behind the likeness, the likeness masked round in the frame's well, the frame itself, what crosses over it, its label plaque, and its motion sprites, at their offsets in the kit's 260 × 280 box. On the bookplate the box is drawn at 0.65 (169 × 182 units, the likeness 73 across).
  | Rank | Key | Frame | Motion |
  |---|---|---|---|
  | No Prestige | `none` | Unwritten | still |
  | I | `jetty` | The Jetty | still |
  | II | `castoff` | Casting Off | still |
  | III | `lighthouse` | The Lighthouse | still |
  | IV | `opensea` | The Open Sea | still |
  | V | `storm` | The Storm | The wheel rocks against the sea (rotation); every seven seconds lightning cracks out of the cloud and lights it (alpha). |
  | VI | `dive` | The Dive | Air bubbles rise from the gooseneck in two streams (translate and alpha). |
  | VII | `coral` | The Coral Gardens | Little fish circle the ring (one sprite, rotation); the sea fan sways in the current (rotation). |
  | VIII | `midnight` | The Midnight Zone | The jellyfish pulses (scale) and the lights in the glass breathe (alpha). |
  | IX | `leviathan` | The Leviathan | Now and then its eye catches the light (alpha). |
  | X | `starward` | The Starward Sea | The armillary bands rock on their pivots (rotation); the stars twinkle (alpha). |
  | Master | `constellation` | The Angler’s Constellation | The burst of gilt turns very slowly (rotation); the stars twinkle (alpha). |
  - **Label.** The plaque carries the rank's numeral ("I" … "X"), or "Master" with a star stamp for each Master Prestige (at most five, then "+{n}"); No Prestige has none. Its ink and face are the kit's, at the frame's scale.
  - **Motion** plays from V up with **Animations** on (SET-R30): on the bookplate while the Angler page is open, stopping when it closes or turns; on the banner while it holds (ANN-R83). Rotation, translation, scale and alpha keyframes, each sprite with its own duration, easing and origin as the kit lists them. Off, every sprite rests unmoved and opaque, and one that only flashes or rises into view (the lightning, the bubbles, the serpent's eye) doesn't show.
  - **Tooltip.** Hovering the bookplate's frame shows its name in gilt and its description, lore `prestigeframe.<key>.name` and `.description` (LED-R160), then its emblem at 22 (LED-R152) and "Prestige {I…X}" or "Master Prestige {n}" ("No Prestige yet" at rank 0).
  - Each frame's texture is loaded only while it is shown.
  - *Decided with the dev (Prestige redesign):* rank III keeps the name **The Lighthouse**, not the kit's "The Lamp Room"; "Lighthouse" is also a game subzone's name, so DATA-R3's check excuses this one lore key, `prestigeframe.lighthouse.name`, and no other line. "Prestige crest" is retired: the portrait frame is the **Prestige frame**, the small badge the **Prestige emblem**, and a crest is a zone, fish or Legend crest.
- **LED-R160** Display text the Ledger invents is lore, read through `ns.L` from `data/lore/ledger.toml` (DATA-R100–R112). Kinds belong to one addon (DATA-R102); the Ledger owns `species`, `legend`, `sub` and `family` (DATA-R103) and defines `title`, `crest`, `ledgergood`, `line` and `prestigeframe`, listed under `[ledger.title]`, `[ledger.crest]`, `[ledger.ledgergood]`, `[ledger.line]` and `[ledger.prestigeframe]` in `data/lore/manifest.toml`:

  | Key | For |
  |---|---|
  | `species.<speciesID>.blurb`, `.riddle` | every Species (DATA-R103) |
  | `legend.<itemID>.blurb`, `.title` | every Legend |
  | `sub.<itemID>.plaque` | every junk, container and treasure item |
  | `family.<familyID>.name` | every trophy family |
  | `title.<titleID>.text` | `level1`, `level10`, `level20`, `level30`, `level40`, `level50`, `level60`, `prestige1`, `prestige5`, `prestige10`, `zonemaster` (allows `{zone}`), `complete.ledger`, `complete.junk`, `complete.treasure`, `complete.trophy` |
  | `ledgergood.<goodID>.name`, `.description` | each of its earned bindings, `ledger.binding.<name>` (LED-R110), each of LED-R117's goods and LED-R118's toast styles. Core's bindings' are Core's lore, its kind `binding` (SHOP-R25) |
  | `prestigeframe.<key>.name`, `.description` | each Prestige frame (LED-R154) |
  | `crest.<key>.name`, `.description` | each zone crest `ledger.crest.<key>` (LED-R113): its name is the landmark on it, its description a word on the water there; neither names a place from the game (DATA-R3) |
  | `line.<id>.text` | `uncaughtlegend`, `uncaughtjunk`, `uncaughttreasure`, `unchartedwaters` |

- **LED-R161** `{zone}` in the `zonemaster` title is filled with the zone's name from `C_Map.GetAreaInfo` (DATA-R108). A key with no text (before the Ledger's lore check turns on) shows nothing: its line is left out.
- **LED-R162** The Ledger's lore check turns on in M3 (`ledger` in `data/checks.toml`'s `lore`, DATA-R66, DATA-R107), with the `line` IDs in the manifest; the `title` and `binding` IDs enter the manifest in M4, with the title and binding batch (DATA-R111), and the `crest` IDs with the zone crests, and the `ledgergood` IDs with the Curio Shop expansion (LED-R117). With Core's binding slot (ADR 0015) the bindings for sale moved to Core's lore, and the earned ones to `ledgergood`; the second round's `ledgergood` IDs enter with its goods (LED-R118); the `prestigeframe` IDs with the Prestige frames (LED-R154).

## Data

### Projection state (`PagleLedgerDB.global.projection.projection`, LOG-R70)

```lua
---@class LedgerState
---@field casts integer                 -- caught and got-away Casts applied (LED-R93)
---@field catches integer               -- lifetime Catches (LED-R42)
---@field xp integer                    -- the climb's own XP: the Ledger's own since the latest Prestige, plus the carried XP (LED-R31)
---@field lifetimeXP integer            -- the Ledger's own XP, all told (LED-R150)
---@field prestigeActivityXP integer    -- the latest Prestige entry's `activityXP`, 0 before the first (LED-R37)
---@field prestige integer              -- prestige rank
---@field fresh number                  -- Fresh Water F after the last Catch (LED-R22)
---@field lastCatch? integer            -- time of the last Catch
---@field firstDate? { year: integer, month: integer, day: integer }  -- realm date of the first Catch of any class that has one (bookplate)
---@field firstTime? integer           -- server time of the first Catch of any class (bookplate, when no Catch has a realm date)
---@field coins integer                 -- lifetime Coins earned (LED-R88)
---@field skill { [integer]: integer }  -- Skill Milestone threshold -> time credited
---@field milestones { [integer]: integer }  -- Catch Milestone -> time reached
---@field species { [integer]: LedgerSpecies }   -- by Species ID; Species Catches only, never Legends
---@field items { [integer]: LedgerFirst }       -- trophy, curio and Legend items: first Catch and count (Legends also keep record and since)
---@field uncharted { [integer]: LedgerFirst }   -- Uncharted item IDs, with zones
---@field zones { [integer]: LedgerZone }        -- every zone with a Catch (zone ≠ 0)
---@field varieties { [integer]: { [integer]: LedgerVariety } }  -- by Species ID, each variety caught by its position (VAR-R20)
---@field counts LedgerCounts            -- the second round's counts (LED-R118, LED-R119)
---@field crest? { good: string, time: integer }  -- the latest crest record: good ID ("" for Plain) and time (LED-R156)
---@field rises LedgerRises             -- when three leaderboard measures last rose (LED-R158)

---@class LedgerRises                   -- LED-R158: kept for the backend's MeasureRises; nothing in game reads it
---@field done integer                   -- Ledger completion's parts done (LED-R70)
---@field total integer                  -- and its parts in all, from the world's with nothing caught
---@field species integer                -- Species caught, removed ones left out (LED-R71)
---@field legends integer                -- Legends caught, removed ones left out (LED-R63)
---@field at { ledgerCompletion: integer?, speciesCaught: integer?, legendsCaught: integer? }  -- entry time of the Cast that last raised each (completion by its percentage); nil while it never rose

---@class LedgerCounts                  -- LED-R118, LED-R119
---@field shards integer                 -- glass shards (LED-R119)
---@field lastDay { [integer]: integer } -- zone -> day number of its latest caught Cast (LED-R119)
---@field deep integer                   -- caught Casts at realm minute < 240
---@field pairs integer                  -- caught Casts sharing a Species with the caught Cast before
---@field lastSpecies { [integer]: true } -- the Species among the last caught Cast's Catches (for pairs)
---@field records integer                -- size records beaten (LED-R82)
---@field ice integer                    -- caught Casts in the ice zones
---@field sea integer                    -- caught Casts at sea
---@field gotAwayRun integer             -- got-away Casts since the last caught one
---@field afterRun boolean               -- a caught Cast came after 10 or more got away
---@field days { [integer]: true }       -- day numbers with a caught Cast
---@field lures { [integer]: true }      -- lure IDs on caught Casts
---@field clams integer                  -- Big-mouth Clam Catches

---@class LedgerVariety                -- core/varieties.md › Data
---@field count integer                 -- Catches of the variety
---@field first { entryId: string, time: integer, date: { year: integer, month: integer, day: integer }?, zone: integer, char: integer }  -- its first Catch (VAR-R24; `time`, LED-R155)

---@class LedgerFirst
---@field n integer
---@field time integer
---@field char integer
---@field zone integer
---@field date { year: integer, month: integer, day: integer }  -- realm date of the first Catch
---@field zones? { [integer]: integer } -- Uncharted only: Catches per zone (≠ 0)
---@field record? LedgerRecord          -- Legend items only (LED-R80)
---@field since? integer

---@class LedgerSpecies              -- n = Catches of the Species; first Catch as in LedgerFirst
---@field n integer
---@field time integer
---@field char integer
---@field zone integer
---@field date { year: integer, month: integer, day: integer }
---@field zones { [integer]: true }     -- zones caught in (≠ 0)
---@field windowsMet { [string]: true } -- element windows met (LED-R45)
---@field record? LedgerRecord
---@field since integer                 -- Catches since the record (LED-R80)

---@class LedgerRecord
---@field length integer                -- mm
---@field band integer
---@field catchId string
---@field time integer
---@field char integer
---@field zone integer

---@class LedgerZone
---@field species { [integer]: true }   -- Species caught here
---@field families { [integer]: true }  -- trophy families landed here
---@field items { [integer]: true }     -- trophy and curio items caught here (LED-R138)
---@field junk boolean
---@field treasure boolean
---@field rank integer                  -- computed rank, 0 if not charted (LED-R50)
---@field masterAt? integer             -- time of the Cast that raised the computed rank to Master (LED-R155)
```

Stars, levels (the peak level too, LED-R35), completion and titles are computed from this state and the world index when needed; they aren't stored. `rises` keeps Ledger completion's counts only to time its rises for the backend (LED-R158); the Journal and every other read compute completion.

### Module records

Every record is `A1|<header>|Ledger|<kind>|<payload>` (LOG-R40, LOG-R11), replayed to the Ledger alone (LOG-R41). A new shape is a new `kind` (ADR 0008).

| Kind | Payload | Appended | Rules |
|---|---|---|---|
| `crest` | the good ID of the crest the bookplate pins (`[%w_.]+`), or empty for Plain | since `LEDGER_RULES_VERSION` 8 | LED-R156 |
| `title` | the picked title key, or empty for automatic | not yet: its reader, `PickedTitle`, is in place for the backend | LED-R77, [#76](https://github.com/timemir/wow-fish/issues/76) item 2 |

Examples: `A1|1|1791731747|0|Ledger|crest|ledger.crest.elwynn`; `A1|1|1791732000|0|Ledger|crest|` (Plain).

### `PagleLedgerDB` (AceDB, account-wide, one shared profile)

| Key | Contents | Default |
|---|---|---|
| `global.projection` | the projection table Core manages (LOG-R70): `projection`, `lastSeq`, `logId`, `fingerprint`, `rulesVersion` | |
| `global.celebrated` | `{ levels = { [prestigeRank] = level }, prestige, species = { [id] = true }, stars = { [speciesID] = { [1|2|3] = true } }, familyStars = { [familyID] = { [1|2|3] = true } }, speciesZones = { ["<speciesID>:<zone>"] = true }, zones = { [zone] = shownRank }, items = { [itemID] = true }, uncharted = { [itemID] = true }, skill = { [threshold] = true }, milestones = { [n] = true }, titles = { [titleKey] = true }, varieties = { [speciesID] = { [index] = true } }, fishComplete = { [speciesID] = true }, goods = { [goodID] = true }, coins, logId }` (LED-R90, VAR-R25; `goods`, each expansion good noted once its rule holds, LED-R116, LED-R117) | empty, `coins = 0` |
| `global.prestigeSources` | `{ rank, activityXP, totals = { [def.name] = total } }`: each Activity XP source's total at the latest Prestige the confirm card recorded, with that entry's `rank` and `activityXP`; display only, never rebuilt (LED-R150) | `nil` |
| `profile.activeTitle` | a title key, or `nil` for automatic (LED-R77) | `nil` |

A zone fished but not charted is in `celebrated.zones` with rank 0. The celebrated set only grows (except `coins`): a few keys per discovery, bounded by the size of the content data.

## Contracts

### Registration

```lua
Pagle.RegisterModule{
  name = "Ledger", title = "Ledger", order = 10,
  views = { { id = "journal", label = "Fish Journal", open = toggleJournal } },        -- from M3
  slash = { { name = "journal", fn = toggleJournal, help = "Open or close the Fish Journal" } },  -- from M3
}
```

### Pagle API used

| Call or event | For |
|---|---|
| `Pagle.RegisterModule` | LED-R1 |
| `M:IterateCatches`, `M:NewProjection` | LED-R2 |
| `M:AppendRecord` (the crest record), `Pagle.GetEquipped("core.crest")`, `Pagle.GetGood` (whether it is the default), event `AppearanceChanged` | LED-R156 |
| `M:RecordPrestige` | LED-R33 |
| `Pagle.GetActivityXP`, event `ActivityXPChanged` | LED-R37–R39, LED-R145, LED-R146, LED-R150 |
| `Pagle.GetFollowedAnglers` | LED-R132, LED-R151 |
| `Pagle.GetItem` (with `pool`), `GetZones`, `GetArea`, `GetZoneCatches` (with `window` and `gate`, LOG-R55) | LED-R5, LED-R10, LED-R135, LED-R141 |
| `Pagle.MatchesConditions`, `Pagle.NextWindow`, `Pagle.GetWindowSpec` | LED-R45, LED-R127 |
| Catch `size`, `Pagle.SIZE_BANDS`, `Pagle.SIZE_RULES_VERSION`, `Pagle.FormatLength` | LED-R2, LED-R80–R85 |
| Catch `variety`, `Pagle.GetItem(id).varieties`, `Pagle.GetVarieties`, `Pagle.GetGood` (a fish crest's name and icon) | VAR-R20–R25 |
| `Pagle.GetAngler` | LED-R41, LED-R126 |
| `M:RaiseMoment`, `M:RaiseWriteUp`, `M:SetSummaryLine` | LED-R93–R97 |
| `M:ReportCoinsEarned` | LED-R89 |
| `M:RegisterSlot`, `M:RegisterGood`, `M:RefreshGoods`, `Pagle.GetEquipped`, `Pagle.SetEquipped`, `Pagle.IsOwned`, `Pagle.GetGood` (the crest's icon), `Pagle.OpenShop`, event `AppearanceChanged` | LED-R110–R119, LED-R146 |
| `Pagle.OpenFieldReport` | LED-R135, LED-R138, LED-R144 (REP-R43) |
| `Pagle.RegisterEvent` (for `GET_ITEM_INFO_RECEIVED`) | LED-R126 |
| `Pagle.IsAnimationsOn`, `Pagle.Animate`, `Pagle.Cue`, `Pagle.StopMotion`, `Pagle.EASE`, `Pagle.Bezier`, `Pagle.WheelScroll` ([announcements.md › Contracts](core/announcements.md#contracts)) | UI › Motion |
| `Pagle.NewPrestigeFrame`, `Pagle.GetPrestigeFrame`, `Pagle.SetPrestigeEmblem`, `Pagle.PrestigeEmblemMarkup` ([core/README.md › Contracts](core/README.md#paglenewprestigeframeparent)) | LED-R146, LED-R151, LED-R152, LED-R154 (the bookplate's frame, the emblems, the Following index's) |
| `Pagle.FitToScreen` ([core/README.md › Contracts](core/README.md#paglefittoscreenframe-options)) | UI (it shrinks to fit the screen) |
| `Pagle.NewLegendCrest` ([core/README.md › Contracts](core/README.md#paglenewlegendcrestparent-width)) | LED-R147, LED-R153 (the Legends page's and the plate's crests) |
| `M:RegisterGuideStep`, `M:ShowMarginNote`, `M:RegisterFirstLook`, `M:ShowFirstLook`, `M:CompleteEveningItem`, `def.guideBlurb`, a moment's `firstNote`, each only where Core has it ([core/onboarding.md › Contracts](core/onboarding.md#contracts), ONB-R90) | ONB-R36, ONB-R52, ONB-R53, ONB-R56, ONB-R57, ONB-R59, ONB-R61, ONB-R91 |

WoW APIs for its own presentation: `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`, `C_Item.GetItemInfoInstant` (item icons), `C_Map.GetAreaInfo`, `C_Map.GetMapInfo`, `GetServerTime`, `GetGameTime`, `issecretvalue` (to leave out a secret realm clock, CORE-R31), `UISpecialFrames` (Esc, LED-R120), `C_Timer.After`, `BreakUpLargeNumbers`, `SetPortraitTexture` (the likeness, LED-R146), `GameTooltip` (the "?", ONB-R59, the ink XP bar's, LED-R145, and the Prestige frame's, LED-R154), and `PlaySound` (the Journal's sounds, UI).

### Coins paid

LED-R88: level-up 20, Prestige 100, new Species 10, new curio or trophy weight 5, Zone Mastery rank 2 × rank, Legend 100.

### Exposed

Nothing: no other Module can see the Ledger (ADR 0001).

## UI

- **The Fish Journal** (LED-R120–R149): an open book, the Ledger's exception to the native look, drawn in the Ledger art kit (the dev's `PagleArtLedger` probe, `/pagleledger`, a fork of the books kit's book shell, which the Hunts board and the Stats book share). Its book shell (the leather's grain, the parchment, the binding band, wax seal, wax close, brass plate, fleuron and gutter atlas) is Core's `Pagle/media/books`; its own parts (medallion rings and the unknown fish's, zone tiles, the ink bar, the stamps inked and in ghost ink, stars, the ladder's circles, checks and radios, page buttons, the Prestige emblem, plinths, the pencil, the magnifier, the quill, the blank chart, the search drop-down and the Prestige card), the twelve old Prestige crests (no longer drawn: Core draws the Prestige frames, LED-R154) and the Legend's, the ten binding swatches and the binding leathers are BLP textures (DXT5) in `Pagle_Ledger/media/journal`, their atlases in `data/JournalArt.lua`. Its fonts are Core's bundled OFL faces: IM Fell English for print and its italic for notes, IM Fell English SC (its real small capitals) for kickers, group headings, tabs and stamps, Caveat for the Angler's hand (Notes to self, "first landed", margins, the title), Marcellus for the gilt crumbs, wax and brass. A leather frame, 920 × 600 at UI scale 1, holds two parchment pages side by side, with the gilt breadcrumbs and the search slip on the leather above them and the brass plate on its lower corner; wax seals mark Zone Mastery and ink stamps mark stars. Item icons are round in a double ink ring, desaturated toward sepia. The ★, ☆, ☑, ☐ and ✓ in this file are notation: the client's fonts lack them, so the Ledger draws each as the kit's sprite (CORE-R9). Its window, pages, crumbs, back link, brass plate, wax close and "?", page turn and crossfade are Core's book shell (`Pagle.NewBook`, [book.md](core/book.md), ADR 0016): it opens where it was left (LED-R120), shrinks to fit a screen too small for it (BOOK-R3), and closes with Esc or its wax close button. A page's list scrolls with the mouse wheel under an ink scrollbar. It keeps the prototype's zone groups, Pools included (LED-R135), and Forever's new zones sit under their continent's tab (LED-R130). Where the kit's sample text differs from the rules above, the rules win; no line calls a length Pagle's own measure.
- **Motion** (the kit's MOTION.md, played on Core's one motion driver, `Pagle.Animate`; everything draws settled while Core's Animations setting is off, `Pagle.IsAnimationsOn()`): the book fades in as it opens (0.16 s) and out as it closes (0.12 s); turning to another spread (a tile, a contents line, a note, a crumb, « back, a search result) turns the page, deeper forward and back up backward (0.22 s lifting toward the spine, 0.28 s landing); picking a fish or a family or a Legend crossfades the right page (0.2 s); a wheel notch glides a third of the page body over 0.12 s, a notch during a glide adding to where it was going (Core's `Pagle.WheelScroll`); the quill sways while the Ledger is being written up; the search drop-down falls open (0.14 s). A spread drawn again on its own subject after a live entry plays the moments of change: a fish logged (its unknown medallion gives way to its own, a green wash, its name written in, the group's count rewritten), a rank up (the seal lifts away and the new one is pressed on, the ladder's circle settles on the new rank, "Next" rewritten), the XP bar's ink running on (0.6 s), a trophy weight landed (its mark inks and grows, "heaviest" moves to it, "The heaviest" is stamped in), an exhibit added (it drops onto its plinth); the Legend plate fades up as its crest rises and its Title seal is pressed on; the Prestige card drops in over the darkened book; changing binding dips the leather and changes it underneath (0.4 s).
- **Sounds** (the kit's SOUND.md): the client's own sound kits, by numeric id on the SFX channel, so the client's SFX volume and mute are their only switch, and never part of a sound set (the `core.soundset.*` goods own only an Announcement's arrival): opening and closing the book (IG_SPELLBOOK_OPEN 829, IG_SPELLBOOK_CLOSE 830), the page turn, a fish picked, the plate opening and a binding change (IG_ABILITY_PAGE_TURN 836), a fish logged and an exhibit added (IG_WRITE_QUEST 3093), a seal or stamp landing (PUT_DOWN_GEMS 1204), the Prestige card opening and closing (IG_MAINMENU_OPEN 850, _CLOSE 851) and its buttons (IG_MAINMENU_OPTION 852), and Prestige confirmed (UI_CHALLENGES_NEW_RECORD 33338). The beats tied to a motion (the page turn, a name written, a stamp, the Prestige's banner) play only while things move.
- **The varieties spread** (LED-R151, VAR-R24; the varieties kit's probe, `PagleArtVarieties/Varieties.lua`, and its "Fish Journal · the varieties spread" board): rows 38 units tall (the kit's 41, so the ten fit the left page under its head without scrolling), each with a dotted rule under it; the rarity pill 70 × 15, square-cornered, filled in the rarity's ink with its name in the parchment's light, or outlined in the ink with its name in it; the selected row on a pale band (`#fff0c8` at 60%). The fish crest sits at the right page's foot, over a thin rule, its shield 51 tall with its name in small capitals and the words in the hand beside it. Where the board names uncaught varieties (its rows, "3 to go: …"), VAR-R27 wins.
- **The Prestige confirm** (LED-R33): the Journal's own card over the book.
- **The plate** (LED-R147): drawn inside the book, one page across the spread.
- **Moments, the Write-up section and the summary line** are drawn by Core (ADR 0007); the catch-feedback prototype (variant A) shows them.
- **Entry points:** the compartment menu's "Fish Journal", `/pagle journal`, and the Settings root's "Open Fish Journal". The Journal opens the Curio Shop (bindings) and the Field report box.

## Settings

The Ledger adds no rows to any Settings page.

| Option | Where | Values | Default |
|---|---|---|---|
| Open Fish Journal | Settings root, Module status list (CORE-R44) | button | |
| Book binding (Core's, SHOP-R25) | Look and Feel (Core builds it from the slot, SHOP-R32), and the Journal's Angler page | owned bindings | `core.binding.field` |
| Active title | the Journal's Angler page only ("Signed As") | earned titles, or Automatic | Automatic |

## Tunables

| Name | Value | Rules |
|---|---|---|
| Catch XP | 10 | LED-R20 |
| Discovery XP: new Species / Species in a zone / first Catch in a zone / curio item / trophy weight / Legend | 500 / 100 / 200 / 150 / 100 / 2,000 | LED-R20 |
| Zone Mastery rank XP | 250 × rank | LED-R20 |
| Skill Milestone XP | 1,000 | LED-R40 |
| Fresh Water: multiplier / rate / cap (also its value before the first Catch) | ×2 / 10 per hour / 300 | LED-R22 |
| Level cap | 60 | LED-R30 |
| Level step cost | 1,000 + 80 × L | LED-R30 |
| Prestige climb cost factor | 1 in every climb (0.5 after any Prestige before #279, `LEDGER_RULES_VERSION` 5) | LED-R30 |
| Prestiges with a frame and emblem of their own | 10, then the Master's | LED-R34 |
| Prestige frame on the bookplate / emblem sizes | 0.65 of the kit's box / 64, 34 and 22 units | LED-R154, LED-R152 |
| Master stars on the frame's label | at most 5, then "+n" | LED-R154 |
| Legend crest table (Core's) | 19803 racer, 19805 angelfish, 19806 queenfish; every other Legend item: unwritten | LED-R153 |
| Skill Milestones | 75 / 150 / 225 / 300 | LED-R40 |
| Catch Milestones | 1,000 / 5,000 / 10,000 / 25,000 / 50,000 | LED-R42 |
| ★ Catches (`CAUGHT_STAR_CATCHES`) | 5 | LED-R45, LED-R133, LED-R142 |
| ★★ zones needed | 3 | LED-R45 |
| ★★★ Catches | 50 | LED-R45 |
| Regular share of ungated Species | half, rounded up | LED-R50 |
| Rare-record flair | beaten record stood 50+ Catches of the Species | LED-R82 |
| Coins | as LED-R88 | LED-R88 |
| Level titles | levels 1, 10, 20, 30, 40, 50, 60 | LED-R75 |
| Prestige titles | ranks 1, 5, 10 | LED-R75 |
| Level bindings | levels 10, 20, 30, 40, 50, 60 | LED-R110 |
| Second round's marks | Chapel Glass 12, The Deep Lure 100, Ink and Koi 25, Mounted Trophy 25, Fishmonger's Slate 30, Through the Ice 100, Cross-Stitch Sampler 20, Breaking Wave 300, Captain's Logbook 25, Carved Heartwood 1, Stormglass Reliquary 10, Black Lacquer Koi 30, Cable Knit 10,000, Fly Wallet 5, Crab Carapace 50, Ember Scale 7 | LED-R118, LED-R119 |
| Ice zones | 1, 36, 618 (Dun Morogh, Alterac Mountains, Winterspring) | LED-R118 |
| Open-sea list (zone or subzone) | 214, 308, 332, 457, 2317, 2318, 2319, 2320, 2321, 2322, 2323, 2324, 2325, 2326, 2338, 2339, 2364, 2365, 2397, 2398, 2399, 2400, 2401, 2402, 2403, 2477, 16361 (The Great Sea, The Veiled Sea, The Forbidding Sea, South Seas) | LED-R118 |
| The sampler's Species | 6291, 6289, 6303, 6308, 6317, 6358, 6359, 6361, 6362, 4603, 8365, 21071, 21153, 13422, 13754, 13758, 13759, 13760, 13889, 13888 | LED-R118 |
| Big-mouth Clam | item 7973 | LED-R118 |
| Deep Lure hours | realm minute 0–239 | LED-R118 |
| Heartwood run | 10 got away | LED-R118 |
| Shard: realm dates a zone must rest | 6 | LED-R119 |
| Second round's fallback: tier / days after release / release time | 5 / 90 / `nil` until the release that ships the goods sets it (`logic/EarnedCounts.lua`) | LED-R118, SHOP-R28 |
| Notes to self | at most 3 | LED-R133 |
| Search results | 4 zones, 6 fish | LED-R148 |
| Plain hint zones | 2 | LED-R141 |
| Forecast in hours up to | 48 h | LED-R127 |
| Write-up title lines | 3 | LED-R94 |
| Continent name map (continent ID → uiMapID) | 0 → 1415 (Eastern Kingdoms), 1 → 1414 (Kalimdor); every other ContinentID is "Other waters" | LED-R126, LED-R130 |
| `LEDGER_RULES_VERSION` | 9 (1 in M2, 2 in M3, 3 in M4, then +1 per change; 7 for the second round's counts, LED-R118; 8 for the crest times and record, LED-R155, LED-R156; 9 for the measures' rise times, LED-R158) | LED-R2, LED-R4 |

## Edge cases

- **LED-R190 Module disabled, then enabled again.** While disabled it raises and pays nothing; Core keeps recording. On re-enable the projection catches up (LOG-R71) without moments; `done` raises one "While the Ledger was off" Write-up section for what that history earned, then reports Coins (LED-R93). If a release arrived meanwhile, Core rebuilds instead and the new achievements arrive as summary-only moments.
- **LED-R191 Projection rebuild.** A new content fingerprint, `LEDGER_RULES_VERSION` or `SIZE_RULES_VERSION` rebuilds from `seq` 0 (LOG-R72). Numbers may shift; shown levels, ranks, stars and titles never fall below the celebrated ones (LED-R92), Coins follow the new total (SHOP-R4), and anything newly earned arrives as summary-only moments (LED-R93). Size records never raise a moment on a rebuild (LED-R84). A ★ celebrated at a first Catch, before `LEDGER_RULES_VERSION` 4, stays shown on a Species with fewer than 5 Catches (LED-R45, LED-R48).
- **LED-R192 First build over existing history.** Everything earned is marked celebrated and one Write-up section lists it (LED-R93, LED-R94); nothing pops up. A lost `PagleLedgerDB` is a first build too (LOG-R77).
- **LED-R193 In combat.** The projection keeps applying entries and raising moments, which Core holds (ANN-R35). The Journal stays usable (LED-R121).
- **LED-R194 Crash mid-Session.** Casts since the last save are lost, and so is the celebrated set's growth with them (both are written at the same save, LOG-R85), so whatever those Casts earned is earned and celebrated again when it next happens. A Prestige appended after the last save is lost; the climb is still at 60 and the button is back.
- **LED-R195 Daily or weekly reset.** Nothing in the Ledger depends on it. Fresh Water follows server time, and window states are read when drawn (LED-R127).
- **LED-R196 Uncharted or unconfirmed Catch.** An Uncharted Catch earns the base and a Nod on its item's first Catch (LED-R64); item `0` earns only the base. When a release classifies an item, the rebuild credits every earlier Catch of it (LOG-R96) through summary-only moments, and as a Species it gains Simulated Sizes and a record silently (LED-R84). Unconfirmed catalogue facts count exactly like confirmed ones (LED-R128).
- **LED-R197 New dev log.** Before 1.0 a log-format change starts a new, empty log (LOG-R18); the projection rebuilds from it and the celebrated set, tied to the old `logId`, is emptied (LED-R90), so the new log's achievements celebrate afresh.
- **LED-R198 Two machines, one WoW account.** Each `PagleLog` keeps its own Ledger (LOG-R97).
- **LED-R199 Activity XP arrives or is recounted.** A Hunts or Tackle Board report raises the computed level without any Ledger entry; the level-up rides on the Cast that earned it, or arrives summary-only from a `done` (LED-R39). A lower recount never lowers the shown level (LED-R38). A Module disabled keeps its total (AXP-R3), so the level never falls for it.
