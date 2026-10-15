# Ledger

> Status: Done · Milestones: M2 (projection, XP, Fresh Water, Angler Level, Skill Milestones, the Ledger's moments, Coins, the Write-up), M3 (the Fish Journal, Species Mastery, Zone Mastery, Sub-collections, Trophy Room, Uncharted list, Ledger completion, the Ledger's lore check), M4 (Legends, titles, Simulated Size records, Catch Milestones, Prestige, Journal bindings) · Sources: [Design the Ledger progression model](https://github.com/timemir/wow-fish/issues/11#issuecomment-6112531009), [Prototype the Fish Journal](https://github.com/timemir/wow-fish/issues/12#issuecomment-6112909660), [Prototype Catch feedback: toasts, sounds and cozy mode](https://github.com/timemir/wow-fish/issues/13#issuecomment-6113132854), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Curio Shop](https://github.com/timemir/wow-fish/issues/30#issuecomment-6125718197), [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372), [Decide who owns Announcements: a Core service or each Module](https://github.com/timemir/wow-fish/issues/22#issuecomment-6113769547), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441), [Prototype the Settings tree](https://github.com/timemir/wow-fish/issues/32#issuecomment-6129969765), [Design the /pagle report format and issue form](https://github.com/timemir/wow-fish/issues/26#issuecomment-6124884698), [Write the Core spec](https://github.com/timemir/wow-fish/issues/35#issuecomment-6130119859), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0002 (superseded), 0004, 0007, 0009, 0010. Prototypes: `prototypes/fish-journal/` (variant E), `prototypes/catch-feedback/` (variant A), `prototypes/curio-shop/` (bindings)

The Ledger is the `Pagle_Ledger` Module: the Angler's identity as an angler. It turns the Catch log into **Angler Level** and **Prestige**, **Fresh Water**, **Skill Milestones** and **Catch Milestones**, **Species Mastery**, **Zone Mastery**, the **Sub-collections** and **Trophy Room**, **Legends**, **Ledger completion**, titles and **Simulated Size** records, and shows them in the **Fish Journal**, a leather-and-parchment book. It builds on the Core contracts in [`core/`](core/README.md) and uses terms as `CONTEXT.md` defines them.

## Purpose and boundary

**Owns:**
- every progression number above, derived from the Catch log and Core's catalogue as one stored projection (ADR 0004), and the celebrated set that keeps what was shown from being taken back or shown twice
- deciding when Prestige is allowed (Core only appends the entry, LOG-R38)
- per-Species Simulated Size records (Core computes each size, LOG-R65)
- the Ledger's moments, its Write-up section and its summary line
- the Coins it pays into Core's wallet (ADR 0009), and its Journal binding goods
- the Fish Journal view, and the Ledger's lore keys

**Doesn't own:**
- what bites where and when, sizes and their bands, condition matching and forecasts (Core's catalogue, LOG-R48–R69)
- how moments are shown, the Session summary and the Write-up card (Core, ADR 0007)
- the balance, the Curio Shop and bookplate crests (Core, ADR 0009)
- "catchable now" suggestions (Hunts). The Ledger takes no XP, stars or anything else from Hunts, the Tackle Board or Stats (ADR 0001).
- Field reports (Core); the Journal only opens the box (REP-R43)

**Uses from Core:** the calls listed under [Contracts](#pagle-api-used).

## Rules

### The Module

- **LED-R1** `Pagle_Ledger` registers with `def.name = "Ledger"`, `title = "Ledger"`, `order = 10`. From M3 it has one view, `{ id = "journal", label = "Fish Journal" }`, and one slash command, `/pagle journal` (help "Open or close the Fish Journal"); both toggle the Journal (any text after the command is ignored). It has no `settingsAction` (the Settings root shows "Open Fish Journal", CORE-R44), no extra menu entries and no settings rows: the Ledger has no settings page. In M2 it has no view and no slash command.
- **LED-R2** The Ledger keeps one projection (LOG-R70) in `PagleLedgerDB.global.projection` over every record `M:IterateCatches` yields. It applies caught and got-away Casts, Skill Readings and Prestiges, and ignores every other kind. It appends no Module records. Its `rulesVersion` is `LEDGER_RULES_VERSION × 100 + Pagle.SIZE_RULES_VERSION` (Tunables), because it stores lengths (LOG-R68); `SIZE_RULES_VERSION` stays below 100. `LEDGER_RULES_VERSION` rises whenever a rule or Tunable that changes the projection changes. It has no `extraFingerprint`, and it never reads Sessions (no `SESSION_RULES_VERSION`).
- **LED-R3** The projection's state is a pure function of the entries applied and the catalogue, the same in every mode. The fold lives in the Ledger's `logic/`, with Core's lookups and `MatchesConditions` passed in. Entries are applied in `seq` order and a Cast's Catches in item order. The celebrated set (LED-R90) and the in-memory scratch list (LED-R98) are the only things outside the projection, and the fold never reads either.
- **LED-R4** **Staging by milestone.** The fold, the moments and the Journal grow by milestone, and each milestone that changes the fold raises `LEDGER_RULES_VERSION`, so the projection rebuilds and what history newly earns arrives as summary-only moments (LED-R93):
  - **M2:** classification (LED-R5–R7) with no Legend class (a Legend item counts as its category until M4); XP rows Catch XP, new Species, Species in a zone, first Catch in a zone and Skill Milestones; Fresh Water; the climb without Prestige (no carried XP use, no `prestigeReady`); Skill Milestones; lifetime Catches as a count; Coins for level-ups and new Species; moments `levelUp`, `newSpecies`, `newInZone`, `skillMilestone`; the celebrated set, `done` and the summary line without completion.
  - **M3:** the world index, stars, Zone Mastery, the collections and the Uncharted list, completion, their XP, Coins and moments, and the Journal. The Journal leaves out every M4 element: Legends (contents line and spread), titles (the bookplate and brass plate show no title; "Lv {L} · Ledger {p}%"; the `zoneMaster` moment's text is just "{zone}"; no `completeTitle` moment), the zonemaster line of LED-R137, the Prestige emblems and button, "Signed As", "Bindings", the Catch Milestone part of LED-R146 (it reads "{lifetime} Catches"), and size text. It is drawn in the Field Leather look, whose tints the M3 Journal ticket picks, while no binding slot exists.
  - **M4:** Legends, titles, Simulated Size records (and size text), Catch Milestones, Prestige (with `prestigeReady`), the bindings, and every element M3 left out.

  `LEDGER_RULES_VERSION` is 1 in M2, 2 in M3 and 3 in M4. In M2 the Settings root has no "Open Fish Journal" button, since the Ledger has no view yet (CORE-R44).

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

  A Catch earns every row that applies. Only Catch XP is ever doubled. Simulated Size, stars, titles, Catch Milestones and size records earn no XP, and nothing from another Module does (ADR 0001).
- **LED-R21** "First" always means first in the log, any character. Discovery XP is earned once per thing for the Angler's whole history, across Prestiges.
- **LED-R22** **Fresh Water** is a number `F`, equal to the cap before the Angler's first Catch. At each Catch, in log order, with `t` its Cast's time and `t0` the previous Catch's Cast time (any character): `F = min(cap, F + rate × max(0, t − t0) / 3,600)` (nothing is added at the first Catch ever); then, if `F ≥ 1`, that Catch's Catch XP is doubled and `F` drops by 1. The Catches of one Cast share `t`, so each spends one in turn. Rate and cap are Tunables.
- **LED-R23** Fresh Water shown now is `floor(min(cap, F + rate × max(0, GetServerTime() − tLast) / 3,600))`, with `tLast` the last Catch's time (the cap with no Catch yet). On the XP bar it is a shaded stretch, like rested XP, starting at the current XP and covering `shown × 10` XP, clipped at the bar's end. At level 60 it isn't drawn.

### Angler Level and Prestige

- **LED-R30** A **climb** is the Angler Level's run from level 1 to the cap. Going from level `L` to `L + 1` costs `(1,000 + 80 × L) × f`, with `f = 1` while the prestige rank is 0 and `f = 0.5` after any Prestige. The level is 1 plus the number of steps the climb's XP covers, at most 60. XP beyond what reaching 60 costs is **carried XP**.
- **LED-R31** The climb's XP is the XP earned since the latest Prestige entry, plus the carried XP at that Prestige.
- **LED-R32** Applying a Prestige entry (any mode): the prestige rank becomes the entry's `rank`; a new climb starts at level 1 with the carried XP (0 if the climb hadn't reached 60, as after a rebalance). Carried XP has no cap, so the new climb may start above level 1; those level-ups belong to the Prestige entry (one `levelUp` moment without `cast`, with their Coins). Nothing unlocked is taken away (LED-R92).
- **LED-R33** **Prestiging** is the player's choice, from the Journal's button (LED-R146), shown only while the computed level of the climb is 60 and the projection isn't updating. A StaticPopup asks "Begin a new Ledger? Your Angler Level starts again at 1, and climbs at half the cost. Nothing you've earned is taken away." with "Prestige" and "Not yet". Confirming checks both conditions again and calls `M:RecordPrestige()` (LOG-R38) only if they hold; otherwise nothing happens. Closing the Journal hides the popup. The Ledger is the only Module that calls it.
- **LED-R34** Prestige ranks 1–10 each give an emblem (I–X). From rank 11 on, each Prestige is a **Master Prestige**, shown as one more star (rank − 10 stars) beside emblem X. Ranks 1, 5 and 10 also give a title (LED-R75).
- **LED-R35** The **peak level** is 60 once the prestige rank is above 0, else the current level. Level rewards (titles, bindings) follow the peak level, so a Prestige never takes them away.
- **LED-R36** The **shown level** is the higher of the computed level and the highest level celebrated in the current climb (LED-R90). Everything that displays a level (Journal, brass plate, summary line, Write-up) uses it. When it is above the computed level, the XP bar reads "0 of {cost of the shown level's step}" until the computed level catches up; the levels in between raise no moment again, and their Coins still count toward the total (they just ride on no moment).

### Skill and Catch Milestones

- **LED-R40** **Skill Milestones** are at 75, 150, 225 and 300. Each is credited once per Angler, at the first Skill Reading (any character) whose `rank` is at or above it; one reading can credit several. Each earns 1,000 XP and a moment. Skill is read at every login (LOG-R31), so a skill reached before install is credited at that character's first login after it.
- **LED-R41** The Journal shows each character's latest Skill Reading from `Pagle.GetAngler().skill`, not from the projection.
- **LED-R42** **Lifetime Catches** count every Catch (LED-R5 base). **Catch Milestones** are at 1,000, 5,000, 10,000, 25,000 and 50,000 lifetime Catches, each credited at the Catch that reaches it. They earn no XP and no Coins.

### Species Mastery

- **LED-R45** Each Species (not Legends) has three stars, earned independently:
  - ★ **Caught**: its first Catch.
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
  - every Sub-collection item: Junk Museum, Treasures and Trophy Room items (done: caught)
  - every charted zone (done: computed rank Master)

  Legends, Noise, `other`, Uncharted and item `0` are outside it. It shows 100 only when everything is done; with nothing in `total` it shows 0.
- **LED-R71** The Journal also shows each part on its own (the Angler page, LED-R146): Species "x of N", Junk Museum, Treasures, Trophy Room weights, and zones mastered (by computed rank). Each uses the same world, removed items left out of both sides.
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

  Nothing else pays: not Catches, Fresh Water, Species-in-a-zone, first Catches in a zone, stars, Skill or Catch Milestones, titles or size records (SHOP-R1).
- **LED-R89** The Ledger reports the total with `M:ReportCoinsEarned` from its projection's `done` and after each live entry that changes it (SHOP-R2). Coins earned live ride on the moment that earned them as `coins` (ANN-R23).

### Celebrating

- **LED-R90** The **celebrated set** (LOG-R77) in `PagleLedgerDB.global.celebrated` records what has already been shown or written up: the highest level per climb (by prestige rank; a climb's level 60 also stands for its `prestigeReady`), the highest prestige rank, Species (★), which stars per Species and per family, Species × zone pairs, zones fished, shown ranks per zone, curio, trophy and Legend items, Uncharted item IDs, Skill and Catch Milestones, earned title keys, and `coins`, the lifetime Coins total, set after every live entry and every `done`. It also stores `logId`, the `PagleLog.logId` it belongs to. It only grows, except `coins`, which follows the total. In `done`, if its `logId` isn't `Pagle.GetAngler().logId` (a new log, LOG-R18), the set is emptied, given the new `logId`, and that `done` is handled as a first build.
- **LED-R91** While applying a `"live"` entry, every **achievement** (a row of the moments table, LED-R97) it earns that isn't in the celebrated set raises its moment and is added to the set. An achievement already celebrated raises nothing, even when a rebuild had dropped it and this entry earns it again.
- **LED-R92** Shown values never fall below the celebrated ones: the level in the current climb (LED-R36), Species and family stars, zone ranks (LED-R52), titles (LED-R76) and level bindings (LED-R111).
- **LED-R98** While applying entries in `"replay"` or `"rebuild"` mode, the fold also appends each achievement it earns, with the entry ID of the Cast that earned it (none for Skill Reading and Prestige entries) and its Coins, to a **scratch list** kept in memory outside the stored state, cleared by `reset` and after `done`. A rebuild cut short by a logout or `/reload` starts again from `seq` 0 (LOG-R72), so the list is rebuilt with it. `done` reads achievements from this list; the list never decides what the state holds.
- **LED-R93** In the projection's `done` (LOG-R76), in this order:
  - `info.firstBuild` (never true for a log with no Cast, LOG-R76): add every achievement in the state to the celebrated set (moments for them are never raised), and raise a Write-up section headed "Your Ledger was written up from {N} Casts" (N = caught and got-away Casts applied, with `BreakUpLargeNumbers`), lines as LED-R94.
  - else, `info.rebuilt`: for each achievement in the scratch list (LED-R98) not yet celebrated, raise its moment as it would be raised live (its `cast` and `coins`, LED-R97) with `summaryOnly = true` (ANN-R63), and add it; level-ups merge into one `levelUp` moment for the highest new level. Big batches come only from the pre-1.0 staging bumps (LED-R4); a data release credits a handful. Size records are never among them (LED-R84). This holds even when the rebuild covers entries recorded while the Module was disabled.
  - else, `info.replayed > 0`: if the scratch list holds any achievement not yet celebrated, raise a section headed "While the Ledger was off", lines as LED-R94 counting only those (a zone whose shown rank rose counts as ranked, one that newly reached Master as mastered), and add them. When none of them has a line in LED-R94 (only a Species new in a zone, say), they are added but no section is raised, so the player never sees a heading with nothing under it.
  - always: set `coins` in the celebrated set to the total, report Coins (LED-R89), call `M:RefreshGoods()` (LED-R111), set the summary line (LED-R95) and redraw the Journal if open.
- **LED-R94** Write-up lines, each only if non-zero, in this order: "Angler Level {L}" (with " · Prestige {R}" when the rank is above 0; for a catch-up, "Angler Level {old} to {new}" and only if it rose), "{n} Species", "{n} zones ranked · {m} mastered" (zones with a shown rank, and those at Master), "{n} trophy weights", "{n} curios", "{n} Legends", "{n} Skill Milestones", "{n} Catches" (the highest Catch Milestone reached, if one is new), "Title: {title}" (one line per title in LED-R75 order, at most 3, then "+{k} more titles"), "Pagle Coins +{c}" (`c` = total minus the celebrated `coins` before this `done`). Stars and Uncharted items get no line. Every count anywhere in the Ledger has singular and plural forms in `ns.L`.
- **LED-R95** The summary line is `M:SetSummaryLine("ledger", text)` with "Ledger: Angler Level {L} · {p}% complete" ("Ledger: Prestige {R} · Angler Level {L} · {p}% complete" when the rank is above 0; before M3, without the completion part). It uses the shown level (LED-R36) and is set in `done` and after each live entry that changes the shown level, the prestige rank or completion.
- **LED-R96** All of a Cast's moments are raised while its `"live"` entry is applied, each with `cast` = the Cast's entry ID, so Core merges them into the Cast's Announcements (ANN-R10, ANN-R11): a level-up banner and a New Species toast show together, each with its own stamps. Moments of a Skill Reading or Prestige entry have no `cast`. An ordinary Catch raises nothing from the Ledger; Core shows its catch Nod (ANN-R13).
- **LED-R97** Moments (all text is `ns.L` interface text except names and titles; item names from `C_Item.GetItemNameByID`, zone names from `C_Map.GetAreaInfo`):

  | Achievement (`kind`) | Rung, `order` | `title` / `text` | `stamp` | `coins` | Also |
  |---|---|---|---|---|---|
  | Legend (`legend`) | `splash`, 100 | "Legend" / "{item} · {size text}. Title: {title}" | "Legend!" | 100 | `icon` the item |
  | Level-up (`levelUp`), one per entry however many levels, for levels above the celebrated one | `banner`, 100 | "Angler Level {L}" / "Title: {title}" for each title earned with it, else "+{n} levels" when more than one, else empty | "Level {L}" | 20 × levels raised by the moment | |
  | Prestige ready (`prestigeReady`), when a climb reaches 60 | `banner`, 110 | "Prestige ready" / "Open the Fish Journal to begin a new Ledger." | "Prestige ready" | | |
  | Prestige (`prestige`) | `banner`, 90 | "Prestige {I…X}" or "Master Prestige {rank − 10}" / "Title: {title}" when one is earned | | 100 | no `cast` |
  | Zone Master (`zoneMaster`) | `banner`, 120 | "Zone Master" / "{zone}. Title: {zonemaster title}" | "Master" | 2 × each rank passed above the celebrated rank | replaces the zone's `zoneRank` moment |
  | Catch Milestone (`catchMilestone`) | `banner`, 130 | "{N} Catches" / "" | "{N} Catches" | | |
  | Completion title (`completeTitle`) | `banner`, 140 | "Title earned" / "{title}" | "Title: {title}" | | one per `complete.*` title |
  | New Species (`newSpecies`) | `toast`, 100 | "New Species" / "{item} · {size text}" | "New!" | 10 | `icon` the item |
  | New trophy weight (`trophyWeight`) | `toast`, 110 | "Trophy weight" / "{item}" | "Trophy" | 5 | ruler `{ old, new, unit = "lb", label = "weight" }` when LED-R61 says |
  | Zone rank (`zoneRank`), Visitor to Expert, one per zone per entry | `toast`, 120 | "Zone rank: {rank}" / "{zone}" | "Rank up" | 2 × each rank passed above the celebrated rank | |
  | Skill Milestone (`skillMilestone`) | `toast`, 130 | "Skill Milestone" / "Fishing {threshold}" | | | no `cast` |
  | Size record (`sizeRecord`) | `toast.low`, 100 (`toast` with the rare-record flair) | "Size record" / "{item} · {size text}" | "Record" | | ruler `{ old, new, unit = "length", label = "length" }`, always (ANN-R22) |
  | New curio (`newCurio`) | `toast.low`, 110 | "New curio" / "{item}" | "New!" | 5 | |
  | Species new to a zone (`newInZone`), not on the Species' first Catch ever | `nod`, 100 | "New here" / "{item} in {zone}" | "New here" | | |
  | ★★ (`elementStar`) | `nod`, 110 | "In its element" / "{item}" | "★★" | | |
  | ★★★ (`regularStar`) | `nod`, 120 | "Regular" / "{item}" | "★★★" | | |
  | Family ★★ or ★★★ (`familyStar`) | `nod`, 130 | "Trophy family" / "{family} {stars}" | the stars | | |
  | Uncharted (`uncharted`), first Catch of each item ID | `nod`, 140 | "Unknown catch, logged" / "{item}" | "Logged" | | |

  `{item}` is the item's name, or "Item {id}" when the client doesn't have it yet. `{size text}` is LED-R81's, left out (with its separator) when the Catch has no size. `icon` is the item for every Catch moment; every other moment (level, Prestige, rank, Skill and Catch Milestone, completion title, family star) uses an in-client texture picked in the build ticket. Coins a live entry earns with no moment raised (an achievement already celebrated) count only in the total. A first Catch in a zone and a ★ have no moment of their own: the New Species and Zone rank moments cover them. A title earned with a level-up, Prestige, Zone Master or Legend rides in that moment, never on its own.

### Journal bindings

- **LED-R110** The Ledger registers one slot, `ledger.binding` (label "Journal binding", category "Fish Journal"), and these goods (IDs may be renamed before 1.0; names are lore, LED-R160):

  | Good | Kind | Working name |
  |---|---|---|
  | `ledger.binding.field` | default | Field Leather |
  | `ledger.binding.level10` … `ledger.binding.level60` (6 goods, one per 10 levels) | earned, `earnedText` "Angler Level {L}" | Tanned Hide, Tidewater Blue, Reed Green, Oxblood, Storm Grey, Nat's Own |
  | `ledger.binding.birch` | tier 1 | Birch Bark |
  | `ledger.binding.buckram` | tier 2 | Sea-green Buckram |
  | `ledger.binding.sharkskin` | tier 3 | Sharkskin |

  A binding is a look only: a tint for the leather, one for the gilt (breadcrumbs, plate, rules) and one for the page paper, applied to in-client textures. The tint values are picked in the M4 build ticket against the prototype's swatches. Each good's `preview` draws a closed-book swatch: the leather rectangle in its tint with the gilt rules and brass plate (no pages).
- **LED-R111** A level binding's `isEarned()` is true when the higher of the peak level (LED-R35) and the highest level in the celebrated set is at least its level. The Ledger calls `M:RefreshGoods()` after a live entry that raises the peak level past a multiple of 10, and from `done` (SHOP-R31).
- **LED-R112** The Journal is drawn in `Pagle.GetEquipped("ledger.binding")`, and its bookplate shows `Pagle.GetEquipped("core.crest")`'s icon (SHOP-R25), or no emblem while that is the slot's default, Plain ("No emblem, only the owner's name"). It redraws on `AppearanceChanged` for either slot.

### The Fish Journal

The Journal is a two-page book (UI). These rules say what it shows; [UI](#ui) says how it looks.

- **LED-R120** The Journal (global frame name `PagleLedgerJournal`) opens and closes from the compartment entry "Fish Journal", `/pagle journal` and the Settings root's "Open Fish Journal" button; each toggles it. Esc closes it (`UISpecialFrames`). The first opening after a login or `/reload` shows Home; later ones show the spread it was left on.
- **LED-R121** It creates no secure frames, so it opens and works normally while restricted. Its Curio Shop and Field report links then print Core's chat lines instead (SHOP-R41, CORE-R33).
- **LED-R122** While the projection is updating (LOG-R74), both pages show only "The Ledger is being written up from your Catch log." with the breadcrumbs and search hidden. It redraws when the update finishes.
- **LED-R123** When a live entry changes what the open spread shows, the spread redraws on the next frame, keeping its selection. Each page body scrolls vertically when its contents overflow. Lists with no order given here sort by ID ascending (item, family, zone areaID, character index).
- **LED-R124** **Never named until caught:** an uncaught Species, Legend or curio item is never named anywhere in the Journal (lists, entries, notes, search, tooltips). Its icon, when shown, is drawn as a black silhouette. Uncaught trophy weights are shown, since they are only numbers.
- **LED-R125** **Navigation:** one spread at a time. Gilt breadcrumbs on the leather above the pages read Home » {continent tab label} » {zone} » {fish} (or Home » {collection} » …); each crumb opens its level. A fish spread opened from search or a note reads Home » {fish}; a collection spread Home » {collection}. The continent crumb opens Home on that continent's tab. Every spread but Home has a "« back" link on the left page that goes one crumb up. A search box sits at the leather's right (LED-R148).
- **LED-R126** **Names:** item names come from `C_Item.GetItemNameByID`; when it returns `nil`, the Ledger calls `C_Item.RequestLoadItemDataByID`, shows "..." (or "Item {id}" in the Uncharted list), and redraws on `GET_ITEM_INFO_RECEIVED` (registered with `Pagle.RegisterEvent`). Zone names come from `C_Map.GetAreaInfo`, the Eastern Kingdoms and Kalimdor tab labels from `C_Map.GetMapInfo` on the continent's uiMapID (Tunables); "Other waters" is interface text (LED-R130). Character names come from `Pagle.GetAngler().characters`. A name that can't be found shows "...". Dates are the Cast's realm date (`conditions.date`) as "{day} {month abbreviation}", with the year added when it isn't the current realm year. The **realm date** of a server time (LED-R127) is worked out live as LOG-R49 does: realm minute (`GetGameTime()`) minus the UTC minute of `GetServerTime()`, rounded to 15 minutes and taken in the range LOG-R49 gives (−10 h excluded to +14 h), gives the offset.
- **LED-R127** **Window labels and forecasts.** A window is labelled from its ID through `ns.L` (`day` "day", `night` "night", `spring`, `summer`, `autumn`, `winter`, `event.301` "Extravaganza", any other `event.<id>` "event"). Its **state** comes from `Pagle.NextWindow(spec, GetServerTime())`, recomputed when the spread is drawn: `openNow` → "biting now"; `opensAt` less than 48 h away → "back in {n} h" (hours rounded up, or "{n} min", rounded up, under an hour); `opensAt` further → "back in {month}" (the month of `opensAt`'s realm date); `nil` → no state. A window's `confirmed` flag isn't shown.
- **LED-R128** Catalogue `confirmed` flags change nothing in the Ledger and aren't shown in the Journal.
- **LED-R129** **Scroll:** each page keeps its scroll position while its **subject** stays the same, through every redraw (LED-R122, LED-R123, LED-R126) and every click on either page; it goes back to the top only when its subject changes. A page's subject is its spread and, on Home's left page, the continent tab; on the zone spread, the zone, and on its right page also the Species selected; on the fish spread, the Species; on the Trophy Room's right page, the family; on the Legends spread's right page, the Legend. So selecting a fish or opening its plain hint keeps the other page where it was, and opening another zone, tab or spread (from a tile, tab, crumb, back link, note or search) starts each page whose subject it changes at the top.

#### Home

- **LED-R130** **Left page:** kicker "The Waters", title "Where I've Fished", then up to three **continent tabs**, in this order: Eastern Kingdoms (`GetArea(zone).continent` 0), Kalimdor (1), and "Other waters" (every tile on any other ContinentID, or whose zone `GetArea` doesn't know). A tab with no tile isn't shown. Below them, the chosen tab's tiles in a grid, scrolling when they overflow. The first tab shown is chosen at first opening. Forever's new zones are tiles like any other, under the tab their `continent` gives; there is no separate group for them.
- **LED-R131** A **tile** stands for each charted zone and each zone the Angler has fished that isn't charted, sorted by `skillBase` (zones without one last), then by areaID. A tile shows the zone's name, then:
  - fished and charted: its shown rank and completion ("Local · 63%"), a thin ink bar of the completion, a wax seal at Master, and a red "{N} new!" note when it has new to find (LED-R52)
  - charted, never fished: faded, "unfished · skill ~{skillBase}" ("unfished · any skill" when the skill base is 0 or below, DATA-R30; just "unfished" without a skill base)
  - not charted: "uncharted waters"
  
  Clicking a tile opens its zone spread.
- **LED-R132** **Right page:** the **bookplate summary**: the Angler Level in large numerals with the Prestige emblem and stars beside it, the active title in handwriting, the ink XP bar (LED-R145) using the shown level (LED-R36), and a wax seal with Ledger completion %. Then **Notes to self** (LED-R133), then **In this Ledger**, a contents list with dotted leaders: "The Trophy Room" with weights x / N; "Curios: junk, treasure, uncharted" with collected x / N of both; "Legends" with x / N; "The Angler: hands, titles, bindings". Each opens its spread.
- **LED-R133** **Notes to self** are generated progress nudges, at most 3, in this order, each only if it applies. Each opens the spread it names.
  1. **Next rank:** of the fished charted zones with shown rank Visitor to Expert and no new to find, the one with the highest completion (ties: higher rank, then lower `skillBase`, then lower areaID): "{zone}: {rank}. {next requirement}" (LED-R134).
  2. **New to find:** the first zone in tile order with new to find: "{zone}: {N} new to find".
  3. **Next star:** the caught, not removed Species without a shown ★★★ (LED-R48) that has the most Catches (ties: lower Species ID): "{name}: {50 − n} to ★★★".
  
  With none, one note reads "Go fishing!". Notes never say what is catchable now (that is Hunts').
- **LED-R134** The **next requirement** for a zone, from its shown rank: unfished "Catch anything here to become a Visitor"; Visitor "Regular: {k} more any-time Species"; Regular "Local: {k} more any-time Species"; Local "Expert: " then, joined with ", ", "{k} more day, night, seasonal or event catches", "a piece of junk", "a treasure" for each part still unmet; Expert "Master: a trophy from {k} more families"; Master "Master of these waters". `k` counts what the rank above the shown rank still needs beyond the shown rank's own requirements. With new to find, " · {N} new to find: the data grew, and your seal stays" is appended (for Master it replaces "Master of these waters").

#### Zone spread

- **LED-R135** **Left page (charted zone):** kicker its continent tab's label (LED-R130), title the zone's name, a wax seal with the shown rank ("unfished" if none), the rank ladder Visitor · Regular · Local · Expert · Master with ranks reached inked and the shown rank circled, "Next: {next requirement}", and "{N} new to find here! My seal stays." when it has new to find. Then the catches, in groups, each with a header "{group} · {caught here} / {total}" and left out when empty:
  - **Any time:** Species ungated here and not pool-associated
  - **Pools:** Species ungated here and **pool-associated** (`PagleItem.pool`, LOG-R55, true for any of its items on this zone's list), with the group note "open water and pools combined", as Stats groups them (STA-R18)
  - **Day and night:** gated here, with `day` or `night` among their windows here
  - **Seasonal:** gated here, with no `day` or `night` window and not only `event.*` windows
  - **Events:** gated here, with only `event.*` windows
  - **Trophies:** one line per family on the list, "a {family} trophy, any weight", ticked when one was landed here
  - **Curios:** "a piece of junk" and "a treasure", for each requirement the zone has, ticked when met
  - **Also caught here:** Species caught here but not on this zone's list (they count for nothing here), header "Also caught here · {n}", with "Not in Pagle's list for these waters yet." and a "Help chart the waters" link (`Pagle.OpenFieldReport()`)
  
  The groups show in that order; within a group, rows sort by Species ID. A gated pool-associated Species sits in its window's group. Groups only arrange the page: Any time and Pools together are the zone's ungated Species for Zone Mastery (LED-R50).
- **LED-R136** A Species row shows: its icon (silhouette if never caught); its name if caught anywhere (with "(caught elsewhere)" when not caught here), else "— unknown —"; in the margin, in handwriting, each of its windows here as "{label}, {state}" (LED-R127), and "pools" when it is pool-associated; and its stars when caught here. Clicking it selects it: the right page shows its entry and the breadcrumbs add it.
- **LED-R137** **Right page, nothing selected — "About these waters":** "Skill ~{skillBase}" ("Any skill" when it is 0 or below, DATA-R30; left out without one); "{completion}% of these waters known: {a} of {b} fish, {c} of {d} trophy families"; "Trophies landed here", one line per family on the list with its stars and its overall "x / N" weights (opens it in the Trophy Room); and "Reward for mastery: each new seal earns XP. The Master seal earns the title {zonemaster title}." Then "Pick a fish on the left to read its page."
- **LED-R138** **A zone that isn't charted:** left page: its name, the lore line `line.unchartedwaters.text`, and "Every catch here is still written down, and counted once Pagle's data catches up." Right page: kicker "Loose pages", its Uncharted items caught here ("{item}: {n}×", the count per zone, LED-R64); then "Also caught here": each Species caught here (rows as LED-R136, no margin), and each trophy and curio item caught here, by name; or, with neither, "Nothing caught here yet."; then a "Help chart the waters" link. Knowing which trophy and curio items were caught in a zone needs `items` per zone, kept in the zone's state (Data).

#### Species entries and the fish spread

- **LED-R140** **A caught Species' entry:** its icon drawn in sepia, large; its name; three stamps, Caught / In its element / Regular, inked when earned (LED-R92); "First landed {date} in {zone}, by {character}. {n} caught." (the zone part left out for zone `0`); its blurb (lore); "Found in {listed zones, joined with ', ' and ' and '}." (left out with none) plus " Only by {element window labels}." when it has element windows; "Largest I've landed: {band} · {length}" when it has a record; and "No longer found in Forever's waters." when removed.
- **LED-R141** **An uncaught Species' entry:** its icon as a silhouette; "An unknown fish"; its riddle (lore) in quotes; and a "Read the plain hint »" link that replaces itself with the **plain hint** (DATA-R112), generated here: its element window labels joined with ", " (or "Any time"), then " · pools" when any of its items is pool-associated, then " · " and its first two listed zones by skill base (" +{n}" for the rest), then " · skill ~{lowest skill base among those two}" when either has one (" · any skill" when that is 0 or below, DATA-R30). With no listed zones, the hint is the window part alone. The hint stays open until the spread changes.
- **LED-R142** **The fish spread** (from search or a note; both only ever name caught Species): the left page is the entry; the right page has kicker "Where to find it", title "Its waters", its listed zones as tiles (as LED-R131, plus "caught ✓" where caught), "When" with each element window's "{label}, {state}", and for a caught Species, "☐/☑ In its element ({have}/{need})" and "☐/☑ Regular ({min(n, 50)}/50)". For ★★ by windows, `have`/`need` count windows; by zones, distinct zones. A tile opens that zone's spread with the fish selected.

#### Collections

- **LED-R143** **The Trophy Room:** left page "The Trophy Room", "{x} of {N} weights.", then the family index (family name from lore, stars, "x / N"). Right page, the chosen family (first one by default): its name, three stamps (Any weight / Half the weights / The heaviest), a measuring board with a tick per weight, ticked and inked where landed, "pounds", "Landed {x} of {N}. Heaviest so far: {w} lb." (or "Not one of this family yet."), a removed weight left out of both (LED-R12), and "Found in {zones whose list has the family}."
- **LED-R144** **Curios:** left page "The Junk Museum", "{x} of {N} exhibits", then a plinth per junk item: caught, its icon, name and plaque (lore); uncaught, a silhouette, "An empty plinth" and the lore line `line.uncaughtjunk.text`. Right page "Treasures", "{x} of {N} opened", a line per container or treasure item: caught, its name and plaque; uncaught, the lore line `line.uncaughttreasure.text`. Then "Loose pages: Uncharted": one handwritten line per Uncharted item, by first Catch: "{item}: {n}× at {its zones' names joined with ', ', or 'unknown waters' when it has none}, first {date}. Unknown to Pagle. Logged.", or "None. Every catch is in the Ledger."; then "Help chart the waters" (`Pagle.OpenFieldReport()`).
- **LED-R145** **The ink XP bar:** the climb's progress to the next level, with Fresh Water (LED-R23), and under it "{xp} of {cost}." followed by " Fresh Water for {F} more Catches." in blue (" Fresh Water for 1 more Catch." when `F` is 1) when `F` is above 0 (LED-R36 for a shown level above the computed one). At a shown level of 60: a full bar, no Fresh Water, and "{carried} XP set aside for the next Prestige" (0 while the computed level is below 60). "Level 60" in LED-R23 means the shown level.
- **LED-R146** **The Angler:** left page, the **bookplate**: the equipped crest, "Ex Libris", "The Angler's Ledger", "kept since {firstDate}" (left out before the first Catch; when no Catch has a realm date, the first Catch's server time as a realm date at the offset now, LED-R126), the shown level, the active title in handwriting, the ink XP bar, Prestige emblems and stars (or "No Prestige seals yet"), the **Begin a new Ledger (Prestige)** button when LED-R33 allows it, "{p}% of the Ledger complete ({done} of {total})", the parts of LED-R71 one per line ("Species {x} of {N}", "Junk Museum …", "Treasures …", "Trophy Room weights …", "Zones mastered …"), and "{lifetime} Catches · next milestone {T}" (just "{lifetime} Catches" after the last). Right page: "Hands on the Rod", one line per character with a Skill Reading, by character index, "{name}: skill {rank} / {max}"; "Milestones" with ☑/☐ for 75, 150, 225 and 300; "Signed As", "Automatic" then the earned titles in LED-R75 order as a pick list (clicking one sets the active title, LED-R77); "Bindings", every binding good in LED-R110 order with its state: "In use", a "Use" link (`Pagle.SetEquipped`) when owned, "Angler Level {L}" for an unearned level binding, and "In the Curio Shop" (`Pagle.OpenShop(goodID)`) for one for sale and not owned.
- **LED-R147** **Legends:** left page "Legends", "{x} of {N}. These sit outside the Ledger's hundred.", then the index: caught ones by name, uncaught ones as "an unwritten legend", in item ID order. Right page, the chosen Legend: caught, its icon in sepia, name, "{date}, {zone}, {character}", its blurb, "Title: {title}" and an **Open the plate** button; uncaught, a plain fish silhouette (never its icon) and the lore line `line.uncaughtlegend.text`. **The plate** fills both pages: the Legend's icon, name, the first Catch's date, zone and character, its record size text, and its title; clicking anywhere returns. It is drawn by the Journal and is not an Announcement.
- **LED-R148** **Search** matches, case-insensitively as a substring, the names of the zones that have a tile and of caught Species and caught Legends (never anything uncaught, LED-R124), on every text change from the first character, showing at most 4 zones then 6 fish in a dropdown, each part sorted by name; picking one opens its zone or fish spread (a Legend opens on the Legends spread with it chosen). A Species matches by its representative item's name (LED-R5). With no match: "Nothing by that name in the Ledger yet." Items whose names aren't loaded yet don't match.
- **LED-R149** **The brass plate** on the cover's corner always shows "Lv {shown level} · {active title} · Ledger {p}%".

### Lore

- **LED-R160** Display text the Ledger invents is lore, read through `ns.L` from `data/lore/ledger.toml` (DATA-R100–R112). Kinds belong to one addon (DATA-R102); the Ledger owns `species`, `legend`, `sub` and `family` (DATA-R103) and defines `title`, `binding` and `line`, listed under `[ledger.title]`, `[ledger.binding]` and `[ledger.line]` in `data/lore/manifest.toml`:

  | Key | For |
  |---|---|
  | `species.<speciesID>.blurb`, `.riddle` | every Species (DATA-R103) |
  | `legend.<itemID>.blurb`, `.title` | every Legend |
  | `sub.<itemID>.plaque` | every junk, container and treasure item |
  | `family.<familyID>.name` | every trophy family |
  | `title.<titleID>.text` | `level1`, `level10`, `level20`, `level30`, `level40`, `level50`, `level60`, `prestige1`, `prestige5`, `prestige10`, `zonemaster` (allows `{zone}`), `complete.ledger`, `complete.junk`, `complete.treasure`, `complete.trophy` |
  | `binding.<name>.name`, `.description` | each binding good `ledger.binding.<name>` (LED-R110) |
  | `line.<id>.text` | `uncaughtlegend`, `uncaughtjunk`, `uncaughttreasure`, `unchartedwaters` |

- **LED-R161** `{zone}` in the `zonemaster` title is filled with the zone's name from `C_Map.GetAreaInfo` (DATA-R108). A key with no text (before the Ledger's lore check turns on) shows nothing: its line is left out.
- **LED-R162** The Ledger's lore check turns on in M3 (`ledger` in `data/checks.toml`'s `lore`, DATA-R66, DATA-R107), with the `line` IDs in the manifest; the `title` and `binding` IDs enter the manifest in M4, with the title and binding batch (DATA-R111).

## Data

### Projection state (`PagleLedgerDB.global.projection.projection`, LOG-R70)

```lua
---@class LedgerState
---@field casts integer                 -- caught and got-away Casts applied (LED-R93)
---@field catches integer               -- lifetime Catches (LED-R42)
---@field xp integer                    -- the climb's XP (LED-R31)
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
```

Stars, levels (the peak level too, LED-R35), completion and titles are computed from this state and the world index when needed; they aren't stored.

### `PagleLedgerDB` (AceDB, account-wide, one shared profile)

| Key | Contents | Default |
|---|---|---|
| `global.projection` | the projection table Core manages (LOG-R70): `projection`, `lastSeq`, `logId`, `fingerprint`, `rulesVersion` | |
| `global.celebrated` | `{ levels = { [prestigeRank] = level }, prestige, species = { [id] = true }, stars = { [speciesID] = { [1|2|3] = true } }, familyStars = { [familyID] = { [1|2|3] = true } }, speciesZones = { ["<speciesID>:<zone>"] = true }, zones = { [zone] = shownRank }, items = { [itemID] = true }, uncharted = { [itemID] = true }, skill = { [threshold] = true }, milestones = { [n] = true }, titles = { [titleKey] = true }, coins, logId }` (LED-R90) | empty, `coins = 0` |
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
| `M:RecordPrestige` | LED-R33 |
| `Pagle.GetItem` (with `pool`), `GetZones`, `GetArea`, `GetZoneCatches` (with `window` and `gate`, LOG-R55) | LED-R5, LED-R10, LED-R135, LED-R141 |
| `Pagle.MatchesConditions`, `Pagle.NextWindow`, `Pagle.GetWindowSpec` | LED-R45, LED-R127 |
| Catch `size`, `Pagle.SIZE_BANDS`, `Pagle.SIZE_RULES_VERSION`, `Pagle.FormatLength` | LED-R2, LED-R80–R85 |
| `Pagle.GetAngler` | LED-R41, LED-R126 |
| `M:RaiseMoment`, `M:RaiseWriteUp`, `M:SetSummaryLine` | LED-R93–R97 |
| `M:ReportCoinsEarned` | LED-R89 |
| `M:RegisterSlot`, `M:RegisterGood`, `M:RefreshGoods`, `Pagle.GetEquipped`, `Pagle.SetEquipped`, `Pagle.IsOwned`, `Pagle.GetGood` (the crest's icon), `Pagle.OpenShop`, event `AppearanceChanged` | LED-R110–R112, LED-R146 |
| `Pagle.OpenFieldReport` | LED-R135, LED-R138, LED-R144 (REP-R43) |
| `Pagle.RegisterEvent` (for `GET_ITEM_INFO_RECEIVED`) | LED-R126 |

WoW APIs for its own presentation: `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`, `C_Item.GetItemInfoInstant` (item icons), `C_Map.GetAreaInfo`, `C_Map.GetMapInfo`, `GetServerTime`, `GetGameTime`, `issecretvalue` (to leave out a secret realm clock, CORE-R31), `StaticPopupDialogs`, `StaticPopup_Show`, `StaticPopup_Hide` (the Prestige confirm, LED-R33), `UISpecialFrames` (Esc, LED-R120), `C_Timer.After`, `BreakUpLargeNumbers`.

### Coins paid

LED-R88: level-up 20, Prestige 100, new Species 10, new curio or trophy weight 5, Zone Mastery rank 2 × rank, Legend 100.

### Exposed

Nothing: no other Module can see the Ledger (ADR 0001).

## UI

- **The Fish Journal** (LED-R120–R149): an open book, the Ledger's exception to the native look. A leather frame (tinted by the equipped binding) holds two parchment pages side by side, with the gilt breadcrumbs and search box on the leather above them and the brass plate on its lower corner. Printed text uses a serif text face; personal notes (Notes to self, "first landed", margins, the title) a handwriting face; wax seals mark Zone Mastery and ink stamps mark stars. For 1.0 it uses in-client textures and fonts and item icons tinted sepia; custom art comes after 1.0. The ★, ☆, ☑, ☐ and ✓ in this file are notation: the client's fonts lack them, so the Ledger draws each as an in-client texture (CORE-R9): a star is the raid-target star, a blank star the same star dimmed, a tick the check box's check, an empty box the empty check box. It opens centred, isn't movable, and closes with Esc or its close button. Look reference: `prototypes/fish-journal/` variant E (`?variant=E`); its zones, fish, numbers and lines are placeholders, and the text above wins where they differ. It keeps the prototype's zone groups, Pools included (LED-R135). It drops the prototype's "New in Forever" tab: Forever's new zones sit under their continent's tab (LED-R130).
- **The Prestige confirm** (LED-R33): a native StaticPopup.
- **The plate** (LED-R147): drawn inside the book.
- **Moments, the Write-up section and the summary line** are drawn by Core (ADR 0007); the catch-feedback prototype (variant A) shows them.
- **Entry points:** the compartment menu's "Fish Journal", `/pagle journal`, and the Settings root's "Open Fish Journal". The Journal opens the Curio Shop (bindings) and the Field report box.

## Settings

The Ledger adds no rows to any Settings page.

| Option | Where | Values | Default |
|---|---|---|---|
| Open Fish Journal | Settings root, Module status list (CORE-R44) | button | |
| Journal binding | Look and Feel (Core builds it from the slot, SHOP-R32), and the Journal's Angler page | owned bindings | `ledger.binding.field` |
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
| Prestige climb cost factor | 0.5 | LED-R30 |
| Prestiges with an emblem | 10 | LED-R34 |
| Skill Milestones | 75 / 150 / 225 / 300 | LED-R40 |
| Catch Milestones | 1,000 / 5,000 / 10,000 / 25,000 / 50,000 | LED-R42 |
| ★★ zones needed | 3 | LED-R45 |
| ★★★ Catches | 50 | LED-R45 |
| Regular share of ungated Species | half, rounded up | LED-R50 |
| Rare-record flair | beaten record stood 50+ Catches of the Species | LED-R82 |
| Coins | as LED-R88 | LED-R88 |
| Level titles | levels 1, 10, 20, 30, 40, 50, 60 | LED-R75 |
| Prestige titles | ranks 1, 5, 10 | LED-R75 |
| Level bindings | levels 10, 20, 30, 40, 50, 60 | LED-R110 |
| Binding tiers | Birch Bark 1, Sea-green Buckram 2, Sharkskin 3 | LED-R110 |
| Notes to self | at most 3 | LED-R133 |
| Search results | 4 zones, 6 fish | LED-R148 |
| Plain hint zones | 2 | LED-R141 |
| Forecast in hours up to | 48 h | LED-R127 |
| Write-up title lines | 3 | LED-R94 |
| Continent name map (continent ID → uiMapID) | 0 → 1415 (Eastern Kingdoms), 1 → 1414 (Kalimdor); every other ContinentID is "Other waters" | LED-R126, LED-R130 |
| `LEDGER_RULES_VERSION` | 1 in M2, 2 in M3, 3 in M4, then +1 per change | LED-R2, LED-R4 |

## Edge cases

- **LED-R190 Module disabled, then enabled again.** While disabled it raises and pays nothing; Core keeps recording. On re-enable the projection catches up (LOG-R71) without moments; `done` raises one "While the Ledger was off" Write-up section for what that history earned, then reports Coins (LED-R93). If a release arrived meanwhile, Core rebuilds instead and the new achievements arrive as summary-only moments.
- **LED-R191 Projection rebuild.** A new content fingerprint, `LEDGER_RULES_VERSION` or `SIZE_RULES_VERSION` rebuilds from `seq` 0 (LOG-R72). Numbers may shift; shown levels, ranks, stars and titles never fall below the celebrated ones (LED-R92), Coins follow the new total (SHOP-R4), and anything newly earned arrives as summary-only moments (LED-R93). Size records never raise a moment on a rebuild (LED-R84).
- **LED-R192 First build over existing history.** Everything earned is marked celebrated and one Write-up section lists it (LED-R93, LED-R94); nothing pops up. A lost `PagleLedgerDB` is a first build too (LOG-R77).
- **LED-R193 In combat.** The projection keeps applying entries and raising moments, which Core holds (ANN-R35). The Journal stays usable (LED-R121).
- **LED-R194 Crash mid-Session.** Casts since the last save are lost, and so is the celebrated set's growth with them (both are written at the same save, LOG-R85), so whatever those Casts earned is earned and celebrated again when it next happens. A Prestige appended after the last save is lost; the climb is still at 60 and the button is back.
- **LED-R195 Daily or weekly reset.** Nothing in the Ledger depends on it. Fresh Water follows server time, and window states are read when drawn (LED-R127).
- **LED-R196 Uncharted or unconfirmed Catch.** An Uncharted Catch earns the base and a Nod on its item's first Catch (LED-R64); item `0` earns only the base. When a release classifies an item, the rebuild credits every earlier Catch of it (LOG-R96) through summary-only moments, and as a Species it gains Simulated Sizes and a record silently (LED-R84). Unconfirmed catalogue facts count exactly like confirmed ones (LED-R128).
- **LED-R197 New dev log.** Before 1.0 a log-format change starts a new, empty log (LOG-R18); the projection rebuilds from it and the celebrated set, tied to the old `logId`, is emptied (LED-R90), so the new log's achievements celebrate afresh.
- **LED-R198 Two machines, one WoW account.** Each `PagleLog` keeps its own Ledger (LOG-R97).
