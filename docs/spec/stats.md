# Stats

> Status: Done · Milestones: M6 · Sources: [Design Stats: session stats, honest odds and dry spells](https://github.com/timemir/wow-fish/issues/21#issuecomment-6113657288), [Prototype the Stats window and live tracker](https://github.com/timemir/wow-fish/issues/27#issuecomment-6125434287), [Prototype the Settings tree](https://github.com/timemir/wow-fish/issues/32#issuecomment-6129969765), [Write the Core spec](https://github.com/timemir/wow-fish/issues/35#issuecomment-6130119859), [Define the content data pipeline](https://github.com/timemir/wow-fish/issues/19#issuecomment-6113646946), [Decide who owns Announcements: a Core service or each Module](https://github.com/timemir/wow-fish/issues/22#issuecomment-6113769547), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Tackle Board](https://github.com/timemir/wow-fish/issues/29#issuecomment-6126015781), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0004, 0007, 0009. Prototype: `prototypes/stats-window/` (variant D, tracker T1)

Stats is the `Pagle_Stats` addon. It shows the Angler's own numbers on request: Sessions, lifetime totals, **Your odds** and **Dry spells**, in the Stats book and an optional live tracker. It announces nothing.

Terms are used as `CONTEXT.md` defines them. Core rules are cited by ID (`LOG-R60`) and not restated. Numbers live in [Tunables](#tunables).

## Purpose and boundary

**Owns:**
- the Stats projection: Cast and Catch counters per place, skill side and window, lifetime and per-character totals, got-away counts by skill margin, and a record of every Session
- Your odds, Dry spells and luck readings, all computed when shown
- the Stats book and the live tracker
- watched Dry spells
- the Stats tracker-frame slot and its goods

**Doesn't own:**
- cutting Sessions, or the Session summary and its numbers (Core: LOG-R60–R64, ANN-R53)
- which items bite where, windows and skill bases (content data, read through Core: LOG-R55)
- the Hunts Module's own Cast counts for its Hunts
- anything celebrated: Stats raises no moments

**Uses from Core:** the projection machinery (LOG-R70–R77), Session events and `Pagle.GetSession()`, `Pagle.GetConditions()`, `Pagle.MatchesConditions()`, the catalogue lookups, `Pagle.GetAngler()`, a Settings section on the Trackers page (`M:AddSetting`), a docked tracker (`M:RegisterTracker`), and one Curio Shop slot. The full list is under [Contracts](#contracts).

## Rules

### What Stats is

- **STA-R1** Stats reads only Core (ADR 0001). It reads no other Module's data, and nothing in it is visible to other Modules.
- **STA-R2** Stats celebrates nothing. It never calls `M:RaiseMoment`, `M:SetSummaryLine`, `M:RaiseWriteUp` or `M:ReportCoinsEarned`, and appends no Module records. A best Session, a long Dry spell or a Dry spell that ends shows only in the book and the tracker. It pays no Pagle Coins (SHOP-R1).
- **STA-R3** Every number Stats shows comes from the Angler's own Casts. Content data ships no rates (LOG-R55), so Stats has no baseline column and never presents a number as game data. If rates ever ship, using them is a new decision.
- **STA-R4** Stats registers with `Pagle.RegisterModule` (CORE-R12):

  ```lua
  { name = "Stats", title = "Stats", order = 30,
    views = { { id = "book", label = "Stats", open = toggleBook } },
    slash = { { name = "stats", fn = toggleBook, help = "Open or close the Stats book." } } }
  ```

  It sets no `settingsAction`, so its root button reads "Open Stats" (CORE-R44). Its compartment entry is "Stats" (CORE-R50).

### Places, skill sides and windows

- **STA-R10** A **place** is a zone or a subzone, by areaID. A Cast counts toward its zone (`conditions.zone`) and, when it isn't `0`, its subzone (`conditions.subzone`). A Cast with zone `0` counts toward no place, whatever its subzone, so it adds nothing to `places`, `scopes` or `hits`, only to lifetime, character and Session totals. The **current place** is the live `Pagle.GetConditions()` subzone, or its zone when the subzone is `0`; with zone `0` there is none.
- **STA-R11** A Cast's **effective skill** is `skillRank + (skillMod or 0)`, or unknown when `skillRank` is `nil`. The live effective skill reads the same fields from `Pagle.GetConditions()`.
- **STA-R12** A zone's **no-junk line** is its `Pagle.GetArea(zone).skillBase` plus the no-junk margin. A zone that is unknown or has no `skillBase` has no line. A subzone uses its zone's line; a subzone's own `skillBase` is ignored, so a Cast has one side in both of its places.
- **STA-R13** A Cast's **skill side** is `hi` when its effective skill is at or above its zone's line, `lo` when below, and `na` when the zone has no line or the skill is unknown.
- **STA-R14** An item's **window in a zone** comes from its entries in `Pagle.GetZoneCatches(zone)`. If every entry for the item carries the same `window` ID (LOG-R55), that is its window. If no entry has one, it has no window. If they differ, including some gated and some not, it has no window in that zone. An item on none of the zone's lists has no window there. Stats never compares condition specs; it works only with window IDs (LOG-R55).
- **STA-R15** A window is tested against a Cast with `Pagle.MatchesConditions(Pagle.GetWindowSpec(windowID), cast.conditions)`. Window IDs (`day`, `night`, `spring`, `summer`, `autumn`, `winter`, `event.<eventID>`) contain no `:` or `#`, so they go into scope keys as they are.
- **STA-R16** A zone's **windows** are the distinct window IDs on the entries of `Pagle.GetZoneCatches(zone)`, Noise and removed items included.
- **STA-R17** The **rows** of a place are the items its page lists:
  - a subzone: its own `catches` if non-empty, otherwise its zone's own `catches` (`Pagle.GetArea(zone).catches`); for a subzone the catalogue lacks, the zone is the one its `places[area].zone` holds (STA-R22)
  - a zone: every item in `Pagle.GetZoneCatches(zone)`, once each

  From that list, items whose `Pagle.GetItem` record has `noise` or `removed` set are dropped (Core already leaves removed items out, LOG-R55; the filter is kept as a guard). Then every item in the place's `places[area].items` (STA-R22) that the list lacks is added, except Noise and removed items. This covers Uncharted items and items the content data doesn't list there.
- **STA-R18** Rows are grouped, in this order on the page:
  1. *Any time*: on the list, no window, not pool-associated
  2. *Pools*: on the list, no window, pool-associated (`PagleItem.pool`, LOG-R55), noted "open water and pools combined"
  3. *In their window*: on the list, with a window in the zone, noted "only Casts in their window"
  4. *Also caught here*: added by STA-R17 because the list lacks them

  An empty group isn't shown. Within a group, rows sort by Your odds: known odds by `k/n` descending, then unseen, then learning; ties by item ID ascending (names may not be loaded yet).

### The projection

- **STA-R20** Stats keeps one projection (`M:NewProjection`, LOG-R70) in `PagleStatsDB.global.projection`, with `rulesVersion = 100 × STATS_RULES_VERSION + Pagle.SESSION_RULES_VERSION` (LOG-R61). `STATS_RULES_VERSION` rises with any change to what the fold counts or how: sides, windows, the no-junk margin, the margin buckets, the Session record. Display-time values (the Cast threshold, the bands, the wording, the range) never change it. A content data change rebuilds Stats through the fingerprint (LOG-R72), which re-reads lines, windows and lists.
- **STA-R21** The **fold** is what `apply` does to the state for one record. It folds records of kind `cast` and `skill` and ignores every other kind. The fold is the same in every mode (`live`, `replay`, `rebuild`), since Stats raises nothing. It lives in Stats' `logic/`, with Core's catalogue lookups and `MatchesConditions` passed in. `done` raises nothing (STA-R2); it only redraws the book and the tracker.
- **STA-R22** For each Cast, these counters each add 1 to `casts`, the number of entries in the Cast's `items` (item `0` included) to `catches`, and 1 to `gotAway` when the outcome is `gotAway`:
  - `totals`
  - `places[zone]` and `places[subzone]`, for each that isn't `0` (none when the zone is `0`, STA-R10)
  - `chars[char]`

  Each `places[area]` record also keeps `zone` (the Cast's zone: the area itself for a zone, its parent for a subzone, so Stats never needs the catalogue to tell them apart) and `items = { [itemID] = catches }`, adding 1 per entry in the Cast's `items` other than item `0`.
- **STA-R23** **Scope counts.** For each of the Cast's places (STA-R10), with its side (STA-R13):
  - `scopes["<area>:<side>"]` adds 1
  - for each of its zone's windows (STA-R16) that matches the Cast (STA-R15), `scopes["<area>:<side>:<windowID>"]` adds 1
- **STA-R24** **Hits.** For each distinct item ID in the Cast's `items` other than `0`, and each of the Cast's places, after the scope counts:
  - if the item has no window in the zone, the scope is `"<area>:<side>"`
  - if it has a window that matched this Cast, the scope is `"<area>:<side>:<windowID>"`
  - if it has a window that didn't match, no hit is recorded for that place

  `hits["<scope>#<itemID>"]` then adds 1 to `n`, sets `at` to that scope's count after this Cast, and sets `last` to the Cast's time. A hit counts Casts, not items: two slots of the same item in one Cast are one hit.
- **STA-R25** **Items.** For each entry in the Cast's `items` other than item `0`, `items[itemID]` adds 1 to `n`, sets `first` if unset, and sets `last` to the Cast's time.
- **STA-R26** **Skill margin.** When the Cast's zone has a line and its effective skill is known, the margin is effective skill minus line, and `margins[bucket]` adds 1 to `casts` (and to `gotAway` when it got away). Buckets: `lo50` (50 or more below), `lo1` (1–49 below), `hi0` (0–24 above), `hi25` (25 or more above).
- **STA-R27** **Skill Readings.** For a `skill` record of character `c` with rank `r`: if `lastRank[c]` is set, `r` is greater, and the reading belongs to the last Session record (STA-R31), that record's `skill` adds `r − lastRank[c]`. Then `lastRank[c] = r`. A character's first reading adds nothing. Two known inaccuracies are accepted: a skill-up whose Skill Reading lands before the first Cast of a new Session counts toward no Session, and a login reading taken inside an open Session credits that Session with skill gained elsewhere.

### Sessions

- **STA-R30** Stats keeps a record of every Session, oldest first, built in the fold. A Cast whose `session` (set by Core, LOG-R98) differs from the last record's `id` starts a new record; otherwise it adds to the last one. The record holds:
  - `id` (Core's Session ID), `startTime` (its first Cast's time) and `endTime` (its latest Cast's time)
  - `casts`, `catches`, `gotAway`, counted as in STA-R22
  - `chars = { [char] = casts }` and `zones = { [zoneAreaID] = casts }` (zone `0` left out)
  - `items = { [itemID] = catches }` (item `0` left out)
  - `skill`: skill gained (STA-R27)
- **STA-R31** A Skill Reading belongs to a Session when Core's record for it carries that Session's ID in `session` (a Skill Reading taken while the Session was open, LOG-R98). A Skill Reading with no `session`, such as one appended before the first Cast of a new Session, adds to no Session.
- **STA-R32** There is a **current Session** while `Pagle.GetSession()` isn't `nil`. Its record is the last one when the IDs match. When they don't (in practice only while the projection is updating), the book follows STA-R72 and the tracker STA-R85. With no current Session, the last record is "My last Session".
- **STA-R33** Computed when shown, never stored:
  - time fished: `endTime − startTime`; for the current Session, `GetServerTime() − startTime` ("so far")
  - Catches per hour: `catches × 3600 / max(time fished, 60)`, as a whole number
  - got-away rate: `gotAway / casts`, as a whole percentage
  - Catches by quality: `items` grouped by `Pagle.GetItem(id).quality`, or `C_Item.GetItemQualityByID` when Core has none (an Uncharted item; one whose quality isn't loaded yet is counted when it loads)
  - lifetime time at the water: the sum of every record's `endTime − startTime` (the current Session counts up to its latest Cast)
  - longest Session: the record with the most `endTime − startTime`, the current one included, earliest first on a tie
  - most Catches per hour: the best unrounded rate among records (the current one included) with at least the bests minimum of `endTime − startTime`, earliest first on a tie; not shown if there is none
  - the date of the first Cast: `sessions[1].startTime`

### Your odds

- **STA-R40** A **reading** is Your odds plus the Dry spell for one item in one place, on one skill side. (A Skill Reading and a luck reading are other things.)
- **STA-R41** The **reading side** is the current character's live effective skill against the place's zone line (STA-R13). When the live skill is unknown, it is whichever of `scopes["<area>:hi"]`, `scopes["<area>:lo"]` and `scopes["<area>:na"]` is largest, for the reading's own place (the page's place, or a watch's `area`), ties going `hi`, then `lo`, then `na`. With no line, it is `na`.
- **STA-R42** The **scope** of a reading is the Casts in the place, on the reading side, inside the item's window in the zone if it has one: the scope key `"<area>:<side>"` or `"<area>:<side>:<windowID>"`. A subzone reading uses the subzone's scope once that scope holds at least the Cast threshold; until then it uses its zone's scope with the same side and window, and says so (STA-R46).
- **STA-R43** With `n` the scope's Cast count and `k` the hit's `n` (0 if none), Your odds is in one of three states, checked in this order:
  - **learning**, while `n` is below the Cast threshold
  - **unseen**, when `k = 0`, with the rule-of-three bound "rarer than about 1 in {nice(n / 3)}"
  - **known**: "about 1 in {nice(n / k)}", with the 95% Wilson range (STA-R45)

  Short forms, used in rows, tiles, the tracker and the item page: "learning {n}/100", "not seen yet", "1 in {nice(n / k)}". The long forms are on the entry (UI, place spread).
- **STA-R44** Rounding. All rounding is half up (`floor(x + 0.5)`). `nice(x)` rounds for display: below 1.5 gives "1"; below 20, the nearest whole number; otherwise two significant figures, with thousands separators (`BreakUpLargeNumbers`). So 39.6 → "40", 212 → "210", 1,447 → "1,400".
- **STA-R45** The range is Wilson's score interval at z = 1.96 for `k` of `n`: with `p = k/n`, `d = 1 + z²/n`, `c = p + z²/(2n)`, `r = z·√(p(1−p)/n + z²/(4n²))`, the bounds are `lo = (c − r)/d` and `hi = (c + r)/d`. It reads "Likely between 1 in {nice(1/hi)} and 1 in {nice(1/lo)} (95%)." When both round to the same text, it reads "Within rounding of 1 in {nice(n/k)} (95%)."
- **STA-R46** Labelling. The item's entry and the tracker's hover carry the heading **Your odds**; the short forms in rows, tiles and lines sit under their page's own headings. Every number says what it rests on, in this **scope line**:

  "From {n} of my Casts {where}{ window}{, side}; {k} caught."

  - `where` is "here", or "across {zone}" when a subzone reading uses its zone (STA-R42)
  - `window` is the window's name (STA-R47), left out when there is none
  - `side` is "at or above {line} skill" or "below {line} skill", left out for `na`

  For example: "From 412 of my Casts here by night, at or above 300 skill; 9 caught." The scope line shows only in the known state; the learning and unseen states use the same `where`, `window` and `side` in their own sentences (UI, place spread). After that sentence, in every state, come each of these as its own sentence when it applies:
  - "Pagle hasn't confirmed it bites here yet." when every catch entry for the item behind the place's rows has `confirmed = false`: on a subzone, the entry in the list its rows come from (its own, or its zone's own, STA-R17); on a zone, every entry for it in `GetZoneCatches`. Items in *Also caught here* have no entry and get no such sentence.
  - "The window isn't confirmed yet." when any entry behind the item's window has `gateConfirmed = false`
  - "The no-junk line isn't confirmed yet." when the zone has a line and its `skillBaseConfirmed` is false
  - "Open water and pools combined: there is no pool data." for a pool-associated item
- **STA-R47** A window is named by its ID:
  - `day`, `night`: "by day", "by night"
  - `spring`, `summer`, `autumn`, `winter`: "in spring", "in summer", "in autumn", "in winter"
  - `event.<eventID>`: "during its event"
  - any other ID: "in its window"

### Dry spells

- **STA-R50** An item's **Dry spell** in a place is counted in the same scope as its odds (STA-R42): `n − at` Casts since the hit's `at`. When the item has never been caught in that scope, it is `n`, shown as a bare count: "412 Casts {where}, none yet." (`where` as in STA-R46).
- **STA-R51** A **luck reading** appears only when Your odds is known and the item has been caught in the scope: `P = (1 − k/n)^since`, the share of anglers with these odds who would wait at least this long.
- **STA-R52** **Bands** by `P`: **normal** at 1 in 100 or more (`P ≥ 0.01`), **unlucky** below 1 in 100, **very unlucky** below 1 in 10,000 (`P < 0.0001`).
- **STA-R53** The **luck wording** follows the Dry spell's first sentence: "{since} Casts since my last one, {time ago}." on an item's entry, and "{since} Casts since my last {item}." in the tracker's hover. It reads:
  - normal, `P ≥ 0.5`: "Nothing unusual."
  - normal, `P ≥ 0.05`: "About {round(P × 100)} anglers in 100 wait this long. Nothing unusual."
  - normal, below that: "Roughly 1 angler in {nice(1/P)} waits this long. A long wait, but well within normal luck."
  - unlucky: "Roughly 1 angler in {nice(1/P)} waits this long. Unlucky, not broken."
  - very unlucky: "Only about 1 angler in {nice(1/P)} waits this long. Very unlucky, and every Cast is still its own roll." Below one in a million, the first sentence reads "Fewer than 1 angler in a million waits this long."
- **STA-R54** A Dry spell of 0 reads "Caught one on my last Cast {where}." (short form "just now"), with no luck wording and no ruler, whatever the odds state; when Your odds is known its luck reading is still `P = 1`, normal (STA-R51, STA-R52), so the tracker dots it green and reads "normal" (STA-R82). Otherwise, while Your odds is learning (and the item has been caught in the scope), the Dry spell's first sentence shows with "A luck reading comes once Your odds have a number." and no ruler.
- **STA-R55** A Dry spell earns nothing, never pops up, and never ends with a message (STA-R2).

### Copy

- **STA-R58** No Stats string says or implies that a Catch is owed: never "due", "overdue", "soon", "pity", "guaranteed", "bound to" or "owed". The exceptions are two fixed lines, each saying that nothing is owed: the luck ruler's "Every Cast is its own roll; nothing is owed." and the First look's Dry spell note "A *Dry spell* is how long you’ve waited. Unlucky isn’t broken: nothing is owed." (ONB-R57, verbatim from the canvas). A unit test checks every value in Stats' string table (`ns.L`) and in `data/lore/stats.toml` for these words, case-insensitively and as whole words, allowing only those exact lines.
- **STA-R59** Voice and formats:
  - Handwriting is first person ("212 Casts since my last one"); printed headings use the glossary terms **Your odds**, **Dry spell** and **Session**. The book has no name of its own: its breadcrumb root is "Stats".
  - Times and dates show in the player's local clock, like the game's own timestamps: a time as `date`'s hour and minute in Core's clock format (`Pagle.FormatClock`, CORE-R87: "09:07", or "9:07 AM" in 12-hour), a date as "{day} {%b} {%Y}" ("5 Oct 2026"), a Session's heading as "{%A} {day} {%B}" ("Monday 5 October"), where `{day}` is the day of the month without a leading zero. Windows show in realm time, in the same clock format ("18:00" or "6:00 PM"). The book and the tracker redraw when the format changes (`ClockFormatChanged`).
  - Counts use `BreakUpLargeNumbers`. Every "{n} Casts", "{n} Catches", "{n} Sessions", "{n} waters" and "{n} anglers … wait" uses the singular when n is 1.
  - A character shows as its name and surname, as Core stores them ("Ada Brook"). An item shows its `C_Item` name and icon; until they load, "Item {id}" with a question-mark icon. An area shows its `C_Map.GetAreaInfo` name, or "Area {id}" if it has none.
  - Item qualities use the game's own names and colours (`ITEM_QUALITY<n>_DESC`, `ITEM_QUALITY_COLORS`). On the book's paper a colour too pale to read on it (Common's white) is drawn in the paper's ink, by one rule wherever a quality is coloured: a place's rows and a Session's *By quality*.
  - A duration under a minute reads "under 1m", under an hour "21m", otherwise "1h 05m" (hours unbounded).
  - Time ago: under a minute "just now", under an hour "21m ago", under a day "3h ago", otherwise "4d ago".

### Watching Dry spells

- **STA-R60** A **watch** is `{ item, area }`: an item and the place whose page it was watched from (a zone or a subzone). The Angler has at most 3, kept in `PagleStatsDB.profile.watched`, oldest first. The same item may be watched in different places. A watch stays until the player stops it, whatever a content update changes: its reading and entry still work even if the item has left that place's rows (STA-R17), and its entry opens from the watch.
- **STA-R61** The **watch** toggle on an item's entry (STA-R74) adds or removes the watch for that item and place. A 4th is refused: nothing changes, and the red UI error "You can watch up to 3 Dry spells. Stop watching one first." shows in `UIErrorsFrame`.
- **STA-R62** Watching while the live tracker is off turns it on and prints one chat line: "Pagle: live tracker turned on to show your watched Dry spells."
- **STA-R63** Stopping a watch (from the entry's toggle or the Settings row) never turns the tracker off.
- **STA-R64** A watched reading is computed like any reading (STA-R40–R54), on the reading side of the moment.

### The Stats book

- **STA-R70** The book (global frame name `PagleStatsBook`) opens and closes from the compartment entry "Stats", `/pagle stats` (any text after it is ignored), the root's "Open Stats" button and the tracker header; each toggles it. Esc closes it (it is in `UISpecialFrames`). The first opening after a login or `/reload` shows the home spread, but for the one that shows the book's First look (ONB-R57: an opening at the home spread while it is unseen and Margin notes is on), which shows Where I am with a fish's entry chosen, where its notes point; later openings show the page it was left on, with its chosen item, chosen Session and page number of the Sessions table. Each page body (left or right) scrolls vertically when its contents overflow; the Sessions ledgers page instead (UI).
- **STA-R71** The book is a plain, non-secure frame, so it opens and works in combat and while restricted. It is moved by dragging the leather; its position is saved in `PagleStatsDB.profile.window`, its offsets in UIParent's units, so a change of UI scale or of the fit never moves it.
- **STA-R72** While the projection is updating (LOG-R74), the nameplate and every page body show "Updating my records…" instead of their contents, search and the watch toggle are disabled, and the breadcrumbs and ribbons still work. The live line uses `Pagle.GetSession()` alone (as STA-R85).
- **STA-R73** While open, the book redraws its page on `CastEnded` (not `"interrupted"`), `SessionEnded`, `ConditionsChanged` (`area` or `skill`), `ClockFormatChanged` (STA-R59), when a watch changes, and when item data it asked for loads (`ITEM_DATA_LOAD_RESULT`, at most one redraw per frame). The book ticks on the live-line tick whenever it is open, Session or not: the live line (STA-R75) refreshes, and so does the whole home spread when it is showing (its day or night and Session lines).
- **STA-R74** Navigation:
  - breadcrumbs: the home spread is "Stats"; a place page is "Stats ❧ {zone}", then "❧ {subzone}" for a subzone, then "❧ {item}" while an item's entry is chosen on it (that last crumb is the page itself and does nothing); an item page is "Stats ❧ {item}"; a ribbon page is "Stats ❧ {its kicker}" ("This Session" or "My last Session", "Lifetime", "Sessions"). Each other crumb opens what it names.
  - the ribbons open *Where I am* (the current subzone's place page, or the zone's when the subzone is `0`, or the home spread when the zone is `0`), *This Session*, *Lifetime* and *Sessions*
  - a row on a place page chooses that item, whose entry fills the right page
  - search opens an item page or a place page
- **STA-R75** On the leather, during a current Session, a gilt **live line** reads "● Session: 51 Casts · 46 Catches · 21m" and opens *This Session*.
- **STA-R76** Search ("Find a fish or a water…") updates as the player types, from the first character, in a dropdown under the box; an empty box hides the dropdown. It matches, case-insensitively anywhere in the name:
  - items: every item in the rows (STA-R17) of any zone with my Casts, plus every item in `items`, by `C_Item.GetItemNameByID` (names not yet loaded are requested when the book opens, and match once loaded)
  - places: every zone and subzone in `places`, by `C_Map.GetAreaInfo`

  It shows up to 6 items, then up to 5 places, each list in alphabetical order, each result with a small label ("fish" for an item, "zone" for a zone, the zone's name for a subzone). Clicking a result opens it; Enter opens the first. With none: "Nothing by that name in my records."

### The live tracker

- **STA-R80** Stats docks its tracker with `M:RegisterTracker{ id = "stats", order = 20, frame }` (CORE-R70). The dock stacks and moves it (CORE-R71).
- **STA-R81** The tracker shows when "Show the live tracker" is on and there is a current Session or at least one watch. Otherwise it is hidden.
- **STA-R82** Its lines, top to bottom:
  - the header "Stats", with "Session · 21m" on the right during a current Session, else "no Session"
  - during a current Session: "38 Casts · 31 Catches · 7 got away", then "{per hour} per hour · skill +{skill gained}"
  - each watch, oldest first: a band dot (green normal, amber unlucky, red very unlucky, grey with no luck reading), the item's name and, on the right, its Dry spell count (the bare `n` when never caught in its scope, "just now" for 0); below it, the watched place's name (the subzone's or the zone's alone), the window name if any, and the band word, "normal" included (or the short odds text, "learning 37/100" or "not seen yet", when there is no band), joined by " · "

  The per-hour line always shows skill gained, "+0" included.
- **STA-R83** Clicking the header toggles the book. Hovering a watch shows a tooltip titled with the item's name: its Dry spell text (STA-R53's first sentence and luck wording, or STA-R50's or STA-R54's text), then the heading "Your odds" in gold over its Your odds sentence for its state (the scope line when known; the learning or unseen sentence from the entry otherwise) with STA-R46's extra sentences. While Stats is updating (STA-R85) it reads only "Updating my records…". Clicking a watch opens the book if it is closed and shows that item's entry on the watched place's page.
- **STA-R84** The tracker draws its frame from `Pagle.GetEquipped("stats.trackerframe")` and redraws on `AppearanceChanged` for that slot (CORE-R73, SHOP-R33).
- **STA-R85** While the projection is updating, the Session lines come from `Pagle.GetSession()` alone (Casts, Catches, got away; no per-hour or skill line), and each watch shows its name with "updating".
- **STA-R86** The tracker redraws on the events in STA-R73, on `AppearanceChanged` for `stats.trackerframe`, and on the live-line tick while a Session is current. It keeps working in combat; only the dock's movement waits (CORE-R71).

### Curio Shop goods

- **STA-R88** Stats registers one slot, `stats.trackerframe` (label "Stats tracker frame", category "Trackers"), and its goods with `M:RegisterSlot` and `M:RegisterGood` (SHOP-R21):

  | Good | Kind |
  |---|---|
  | `stats.trackerframe.none` | default: the plain native tracker look, no frame |
  | `stats.trackerframe.logbook` | tier 1 (150): ruled paper with a red margin line, its rulings repeated as it grows with its lines |
  | `stats.trackerframe.brass` | tier 2 (400): a dark plate in a thin brass rim with riveted corners |
  | `stats.trackerframe.greenbar` | tier 1 (150): tally paper banded in pale green, so a long column of numbers never loses its place |
  | `stats.trackerframe.chalkboard` | tier 1 (150): a green schoolroom board in a pine frame, with somebody’s tally marks still in the corner |
  | `stats.trackerframe.tidegauge` | tier 2 (400): sea-blue glass behind a brass tide staff, marked off so the numbers rise and fall like water |
  | `stats.trackerframe.abacus` | tier 2 (400): a counting frame with the beads pushed to the ends, and the sum written plainly between them |
  | `stats.trackerframe.astrolabe` | tier 3 (900): a star map in deep blue under brass rings, for an angler who reckons the odds by the sky |

  This follows the Tackle Board's frames (a free "No frame" and two for sale at tiers 1 and 2). Each good's name and description are lore in `data/lore/stats.toml`, as `statsgood.<goodID>.name` and `.description`, Stats' own kind (working names: No frame, Logbook, Brass), listed under `stats` in `data/lore/manifest.toml` (DATA-R106) and drafted and reviewed through the lore pipeline (DATA-R100–R107), whose lore check turns on for Stats when it first registers a good, in M6 (DATA-R107). A good's icon is its frame's swatch; "No frame"'s swatch is the plain native tracker. Each `preview` draws a sample tracker with the good's frame: "Session · 21m", "38 Casts · 31 Catches · 7 got away", "62 per hour · skill +3", then a normal watch (item 4603, area 35, count 40) and an unlucky one (item 13759, area 357, by night, count 212). The item and area names resolve at runtime (STA-R59), so no game text ships.

## Data

### `PagleStatsDB` (AceDB, account-wide, one shared profile)

| Key | Contents | Default |
|---|---|---|
| `profile.tracker` | "Show the live tracker" | `false` |
| `profile.watched` | `{ { item = itemID, area = areaID } }`, at most 3, oldest first (STA-R60) | `{}` |
| `profile.window` | the book's position `{ point, relativePoint, x, y }` | `nil` (centred, 40 px above the middle so the ribbons under it stay on screen) |
| `global.projection` | the projection table Core manages (LOG-R70): `projection`, `lastSeq`, `logId`, `fingerprint`, `rulesVersion` | |
| `global.schemaVersion` | integer for `if version < N` migrations of this DB | 1 |

Stats has no celebrated set (LOG-R77): it celebrates nothing.

### Projection state (`global.projection.projection`)

```lua
{
  totals  = { casts = 0, catches = 0, gotAway = 0 },
  places  = { [areaID] = { zone = zoneAreaID, casts = 0, catches = 0, gotAway = 0,
                           items = { [itemID] = catches } } },        -- zones and subzones (STA-R22)
  chars   = { [charIndex] = { casts = 0, catches = 0, gotAway = 0 } },
  scopes  = { ["357:hi"] = 1840, ["357:hi:night"] = 412 },        -- STA-R23
  hits    = { ["357:hi:night#13759"] = { n = 9, at = 200, last = 1791731747 } },   -- STA-R24
  items   = { [itemID] = { n = 0, first = 0, last = 0 } },            -- STA-R25
  margins = { lo50 = { casts = 0, gotAway = 0 }, lo1 = {…}, hi0 = {…}, hi25 = {…} },  -- STA-R26
  lastRank = { [charIndex] = rank },                                   -- STA-R27
  sessions = {                                                         -- STA-R30, oldest first
    { id = "Player-4618-0A1B2C3D-1791731747-0", startTime = 0, endTime = 0,
      casts = 0, catches = 0, gotAway = 0,
      chars = { [charIndex] = casts }, zones = { [zoneAreaID] = casts },
      items = { [itemID] = catches }, skill = 0 },
  },
}
```

Sides in keys are `hi`, `lo` and `na` (STA-R13). Odds, ranges, the Cast threshold, luck readings, bands and wording are never stored (STA-R20). About 3,000 Session records over years of play fit comfortably; nothing is pruned.

## Contracts

### Used from Core

| Call or event | For |
|---|---|
| `Pagle.RegisterModule(def)` | STA-R4 |
| `M:NewProjection(def)` | STA-R20–R27 |
| `M:AddSetting("trackers", …)` | [Settings](#settings) |
| `M:RegisterTracker{ id, order, frame }` | STA-R80 |
| `M:RegisterSlot`, `M:RegisterGood` | STA-R88 |
| `Pagle.GetEquipped("stats.trackerframe")`, event `AppearanceChanged` | STA-R84 |
| `PagleCast.session`, `PagleSkillReading.session` (LOG-R98); `PagleItem.pool` (LOG-R55) | STA-R18, STA-R30, STA-R31 |
| `Pagle.GetSession()`, events `SessionStarted`, `SessionEnded` | STA-R32, STA-R73, STA-R85 |
| `Pagle.SESSION_RULES_VERSION` | STA-R20 |
| `Pagle.SESSION_GAP` | the Sessions page's note (UI › Sessions) |
| `Pagle.GetConditions()`, event `ConditionsChanged` | STA-R11, STA-R41, STA-R73 |
| `Pagle.FormatClock`, event `ClockFormatChanged` | STA-R59, STA-R73 |
| `Pagle.MatchesConditions(spec, snapshot)` | STA-R23, STA-R24, the home spread's day or night |
| `Pagle.GetWindowSpec(id)`, catch entries' `window` (LOG-R55) | STA-R14–R16, STA-R47 |
| `Pagle.GetItem`, `GetArea`, `GetZoneOf`, `GetZoneCatches` | STA-R12–R18 |
| `Pagle.CONTENT_FINGERPRINT` | the place tables built from the catalogue, dropped when it changes (DATA-R70, LOG-R72) |
| `Pagle.GetAngler()` | character names (Lifetime, Session entries) |
| `Pagle.IsAnimationsOn()`, `Pagle.Animate`, `Cue`, `StopMotion`, `EASE`, `Bezier` (Core's one motion driver, announcements.md › Contracts) | UI › Motion and sound |
| `Pagle.WheelScroll` (a wheel notch, a third of a page body, gliding; announcements.md › Contracts) | STA-R70's page bodies |
| `Pagle.FitToScreen(frame, { keepPlace = true })` (core/README.md › Contracts) | the book's fit (UI), STA-R71 |
| event `CastEnded` | STA-R73 |
| event `ModulesChanged` | the tracker's first draw (CORE-R19, STA-R86) |
| `Pagle.RegisterCallback(owner, event, fn)` | every event above (CORE-R20) |
| WoW: `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID`, `C_Item.GetItemQualityByID`, `C_Item.RequestLoadItemDataByID`, event `ITEM_DATA_LOAD_RESULT` (through `Pagle.RegisterEvent`, CORE-R23); `C_Map.GetAreaInfo`; `UIErrorsFrame` | names, icons, quality, search, STA-R61, STA-R73 |
| WoW: `ITEM_QUALITY<n>_DESC`, `ITEM_QUALITY_COLORS` | STA-R59 |
| WoW: `BreakUpLargeNumbers`, `date`, `GetServerTime` | STA-R44, STA-R59 (numbers, dates and times) |
| WoW: `CreateFrame`, `CreateFont`, `GameTooltip`, `UISpecialFrames`, `C_Timer.After`, `Settings.CreateElementInitializer` | the book (STA-R70, STA-R73), the tracker's hover, the Watched Dry spells row ([Settings](#settings)) |

### Exposed

Nothing. Stats fires no events and offers no calls (STA-R1).

### Moments, Coins and goods

| | |
|---|---|
| Moments and rungs | none (STA-R2) |
| Session summary lines | none |
| Write-up sections | none |
| Pagle Coins paid | none (SHOP-R1) |
| Curio Shop goods | `stats.trackerframe` slot and its 8 goods (STA-R88) |

## UI

The **Stats book** is the third Pagle book, in the book language (below), drawn in the books art kit (the dev's `PagleArtBooks` probe, `/paglebooks stats`, a fork of the Fish Journal's book shell, which also draws the Hunts board): bundled fonts in Core's media (IM Fell English and its italic for print, Caveat for handwriting, Marcellus for gilt, ribbons and brass) and BLP textures for the leather with its binding band and brass corners, the parchment, the wax close button, the brass nameplate, grosgrain ribbons, the "watching" pill, ink strokes, item rings, the star, the fleuron and the luck ruler's "me" mark, and the kit v2's zone tiles, the dark tooltip slip and the pen before a watched Dry spell; item icons are sepia-tinted, round in the kit's rings. The book shell's textures are Core's media, which Hunts reads too; each tracker frame and the kit v2's tiles, slip and pen are Stats' own. The pointing hands, which the kit leaves out, stay in-client textures. The kit v2 lays out every spread (Home, Where I am, This Session, Lifetime, Every Session) with sample data; the book binds them to the rules here, which win where they differ. It is about 980 × 640 px, and shrinks to fit a smaller screen (never grows), re-fitting when the UI scale changes, keeping the place it was left (Core's `Pagle.FitToScreen`, STA-R71). Look reference: the books kit, after `prototypes/stats-window/` (variant D).

**Motion and sound** (the books kit v2's MOTION.md and SOUND.md). The book fades in as it opens (0.16 s) and out as it closes (0.12 s). Turning to another spread (a ribbon, a crumb, a link) is a page turn of half a second: the leaf lifts from one page toward the spine and lands on the other, forward to a later ribbon, backward to an earlier one or home, with a fold shade and a cast shadow; the crumbs change as it passes the spine, and the chosen ribbon's length eases (0.2 s). When a Cast changes the entry shown, each rewritten line's ink fades up from 30%, the "me" mark slides to the new reading (0.6 s), and a catch that resets the Dry spell fades the luck ruler out until the next Cast; a row's rewritten Dry spell and the live line fade up the same way. The live dot breathes while the book is open in a Session. Hovering a zone tile warms it. Everything moves on Core's one motion driver (`Pagle.Animate`), and with Core's Animations setting off, everything draws settled at once. The book plays the client's own UI sounds on the SFX channel: opening and closing (829, 830), a page turn (836) and a catch written in (3093), the last two only while things move. They are no sound set's, and Stats has no sound setting: the client's sound volume is the switch.

Words used below for its parts:
- **book language**: the look the Stats book shares with the Ledger Module's book view (the Fish Journal): a leather binding, parchment pages, ink, a serif text face, handwriting, small-caps headings and ribbons
- **leather**: the binding around the pages, holding the breadcrumbs and search on its strip above them, the nameplate and live line on its foot band below them, and the ribbons
- **spread**: the two facing parchment pages shown at once; **left page** and **right page**
- **ribbons**: the grosgrain bookmarks hanging from under the leather's foot
- **nameplate**: the brass plate on the leather's foot band, below the pages
- **kicker**: the small-caps line above a page's title
- **handwriting**: a script face for first-person notes; everything else is the printed serif face
- **fish** (player-facing copy only): any item with a row, junk and treasure included; rules call it an **item**
- **waters** (player-facing copy only): places; *Its waters* on a zone page means its subzones
- **entry** (an item's): the right-page view of one reading; never a Catch log entry
- **ruled ledger**: a lined table of Sessions; nothing to do with the Ledger Module
- **margin** (of a row): its right-hand edge, where the Dry spell is written; not the skill margin of STA-R26

Every string below is mechanical interface text in `ns.L` (STA-R58, STA-R59), not lore. Where an order isn't given, ties go by areaID, character index or item ID, ascending.

### On the leather

- On the strip above the pages, centred between its band and the pages: gilt breadcrumbs (STA-R74) and the search box (STA-R76), the Curio Shop's paper slip with its magnifier, edged in gilt that brightens while typing.
- Beside the wax close button at the top right, the **"?"** (ONB-R59): a plain seal of the same wax with a gilt "?", its tooltip "Show the notes for this page again" on the dark slip. It shows the book's First look again, turning to Where I am with a fish's entry chosen (a fish of the place page shown, when it is one) if another spread shows.
- On the foot band below them: the nameplate, "{lifetime Casts} Casts · {Sessions} Sessions · since {first Cast's date}", or "No Casts yet"; and, during a current Session, the live line at the right (STA-R75), its dot glowing green.
- Ribbons, left to right under the foot band, each in its own colour: *Where I am* (green), *This Session*, *Lifetime*, *Sessions*; the chosen one hangs longer and brighter.

### Home spread

- **Left page:** kicker "The waters", title "Where I've fished", the line "Your odds and Dry spells come only from my own Casts, never from game data.", then one tile per zone in `places` (a record whose `zone` is its own areaID), plus the current zone, ordered by my Casts there (most first; the current zone first if it has none). With no Casts at all, there are no tiles, only the line "Not fished anywhere yet." A tile shows the zone's name, "{Casts} Casts · {N} waters" (subzones in `places` whose `zone` is this zone) or "not fished yet", "I'm here", and "watching {N}" when watches have this zone or one of its subzones as their `area`. Clicking opens the zone's place page.
- **Right page:** kicker "Right now", then in handwriting:
  - "Fishing {subzone}, {zone}, by {day or night}." The subzone part is left out when it is `0`; "by night" when `Pagle.MatchesConditions(Pagle.GetWindowSpec("night"), Pagle.GetConditions())` is true, "by day" otherwise, and the phrase is left out when the realm minute is unknown. With zone `0`: "I can't tell where I am."
  - "Skill {effective}, past the no-junk line ({line})." when the side is `hi`; "Skill {effective}, below the no-junk line ({line})." when `lo`; left out for `na`.
  - "This Session: {Casts} Casts, {Catches} Catches, {got away} got away, {duration} so far." during a current Session; else "No Session right now. The last one ended {time ago}."; with no Sessions ever, "No Session yet."
  - heading *Dry spells I'm watching* (small: "also on the live tracker"), one line per watch, each opening its entry: "✎ {item}, {place}: {since} since the last." with ", unlucky" or ", very unlucky" before the full stop when it applies, "✎ {item}, {place}: caught on my last Cast." for 0, or "✎ {item}, {place}: {n} Casts, none yet." when never caught in its scope. With no watches: "Nothing yet. Watch a Dry spell from any fish's page."
  - heading *In this book*: "Where I am: {place}" ("Where I am: unknown" with zone `0`, opening the home spread), "This Session" (or "My last Session"), "Lifetime" with lifetime Casts, "Every Session" with the count; each opens its page.

### Place spread

- **Left page:**
  - kicker: the zone's name on a subzone page, "Waters" on a zone page; title: the place's name, with "I'm here" in green handwriting when I am in it
  - "{Casts} of my Casts here." Then, when the zone has a line: "No junk from {line}; at {skill} I'm past it, so only those Casts count." for side `hi`, "No junk from {line}; at {skill} I'm below it, so only my Casts below it count." for `lo`, and just "No junk from {line}." when the live skill is unknown.
  - when `Pagle.GetArea(area)` is `nil` or has `hasData = false`: "Pagle has no chart of these waters yet."
  - on a zone page, heading *Its waters* (small: "my Casts"): every subzone of the zone that has its own catch list in `Pagle.GetZoneCatches(zone)` or a `places` record whose `zone` is this zone, alphabetical, each with my Casts there ("—" for none) and "I'm here"; each opens its place page
  - the row groups (STA-R18), each under its heading with its small note ("Your odds · Dry spell" for *Any time*, STA-R18's notes for *Pools* and *In their window*, "not on Pagle's chart for these waters" for *Also caught here*). Each row: an ink icon, the name in its quality colour, ★ when watched, Your odds in short (STA-R43; "learning {n}/100" in handwriting, at the row's right edge when its margin is empty; a name too long for the room before the odds is cut short with an ellipsis), and in the margin, in handwriting, the Dry spell when the item has been caught in the scope: "{since} since", with ", unlucky" or ", very unlucky" in red when it applies, or "just now" for 0. Nothing shows in the margin when it has never been caught there.
  - under a subzone's rows, when any row uses its zone (STA-R42): "Fish with fewer than 100 Casts in {subzone} use all of {zone} until then."
- **Right page, no item chosen:** kicker "About these waters", the place's name, then "Casts", "Catches", and "Got away" as "{n} ({rate}%)", or "—" while the place has no Casts (no rate to give); then in handwriting "Pick a fish on the left for its odds and its Dry spell."
- **Right page, an item's entry:**
  - the **watch** toggle at the top right, reading "watch" or "watching" (STA-R61)
  - kicker "Your odds · {place}" plus ", {window name}" when it has a window; title: the icon and name
  - known: "about 1 in {N}" in large ink ("about" in the hand before the odds in large handwriting); below it the range (STA-R45), then the scope line (STA-R46)
  - learning: "Learning…" in large ink, an ink bar filled to `n / 100`, and "{n} of the 100 Casts I need {where}{ window}{, side} before Your odds show a number."
  - unseen: "not seen yet" in large ink, and "In {n} Casts {where}{ window}{, side}: rarer than about 1 in {nice(n / 3)}, if it bites here at all."
  - then, in every state, STA-R46's extra sentences
  - heading *Dry spell* (small: "counted like the odds above"): the first sentence (STA-R53), the luck wording and the **luck ruler** when there is a luck reading; otherwise STA-R50's or STA-R54's text
  - the luck ruler: a horizontal log scale of `P` from 1 (left, "all") to 10⁻⁶ (right, "1 in 1M"), ticked "all", "1 in 10", "1 in 100", "1 in 1k", "1 in 10k", "1 in 100k", "1 in 1M"; the unlucky and very unlucky ranges as two faint red washes, labelled "normal", "unlucky", "very unlucky" underneath; a red "me" mark at `P` (clamped to the ends); and the line "Every Cast is its own roll; nothing is owed." A filling bar is never used: it reads as "due".
  - heading *In my records*: "Caught in this count" (`k`), "Caught anywhere" (`items[item].n`, 0 if none), "First caught" and "Last caught" (dates, "—" if none)
  - "Every water it bites in ☛", opening the item page

### Item page

- **Left page:** kicker "A fish", the icon and name.
  - When it bites: the item's window (STA-R14) in the zone with the most of my Casts among the zones in `places` (plus the current zone) whose `GetZoneCatches` lists it. "Bites at any hour." with no window, or "Bites only {window name}", with " ({from}–{to} realm time)" when its spec (`Pagle.GetWindowSpec(id)`) has a `time` field (several ranges joined by ", "), then the full stop. When no such zone lists it (Uncharted, Noise, or not listed where I've fished), this line is left out.
  - A pool-associated item adds "Also in pools; with no pool data, both are counted together."
  - "Caught", "First caught", "Last caught" (with time ago).
  - When the item is in the current place's rows: heading *Where I am* (small: the place's name), then "{short odds}; {since} since the last." when caught in that scope, "{short odds}; caught on my last Cast." for 0, or "{short odds}; none yet." when never caught there; then "Open its page here ☛".
- **Right page:** kicker "Its waters", title "Where I've fished for it". Tiles, from places in `places` only, grouped by zone (zones by my Casts, most first): first the zone itself when the item is in the zone's rows (STA-R17), then each subzone in `places` whose rows include the item, alphabetical. Rows include items caught there, so Uncharted items get tiles too; Noise items never do. A tile shows the place, its zone (for a subzone), "I'm here", its short odds and, when its band is unlucky or very unlucky, "{since} since" in red. Clicking opens that place's page with the item chosen. With no tiles: "I haven't fished anywhere it bites."

### This Session

- **Left page, a Session's entry:** kicker "This Session" (or "My last Session", or "Session {n}" on the Sessions page, numbered from 1 for the oldest), title: the Session's date heading (STA-R59), then "{start} to {end, or now}, {duration} at the water." Then "Casts", "Catches", "Got away" as "{n} ({rate}%)", "Catches per hour", "Skill gained" as "+{n}"; heading *By quality*: one line per quality present, highest first, each in its colour with its count; heading *Where and who*: zones by Casts (most first), each opening its place page, then characters alphabetical by name, each with Casts.
- **Right page:** kicker "Before that", title "Earlier Sessions": a ruled ledger of the 10 Sessions before the one shown, newest first, with columns "Started" (date and time), "Where" (zone names by Casts, most first, joined by ", "), "Length", "Casts", "Catches". A row opens that Session on the Sessions page. Then "Every Session ☛".
- With no Sessions: both pages read "No Sessions yet."

### Lifetime

- **Left page:** kicker "Lifetime", title "Every Cast I've made": "Casts", "Catches", "Got away" as "{n} ({rate}%)", "Sessions", "Time at the water". Heading *Bests*: "Longest Session, {date}" with its duration; "Most Catches per hour, {date}" with its rate. Heading *Got away, by skill* (small: "against each water's no-junk line"): one line per bucket that has Casts, in the order "below by 50+", "below by 1–49", "0–24 over", "25+ over", each reading "{rate}% of {Casts} Casts". Heading *Characters*: each character with Casts, alphabetical by name, as "{Casts} Casts · {Catches} Catches · {got away} got away".
- **Right page:** kicker "The catch", title "Every fish", the note "How many I've caught. Hover for first and last; click for its waters.", then a two-column index of every item in `items` (Noise and Uncharted included; item `0` never appears), most caught first, ties by item ID, each with its count. Hovering shows "First {date}, last {date}"; clicking opens its item page.

### Sessions

- **Left page:** kicker "Sessions", title "{N} Sessions", the note "A Session ends after 5 minutes without a Cast." (Core's gap, `Pagle.SESSION_GAP / 60`, LOG-R60, LOG-R61), then the ledger (columns as on This Session), 16 per page, newest first, the chosen one highlighted, with "☚ later", "page X of Y" and "earlier ☛" (each arrow hidden at its end).
- **Right page:** the chosen Session's entry, as on This Session's left page; the newest by default.

### Live tracker

An objective-tracker-style block in Core's dock (CORE-R70, R73), about 250 px wide (the papers a little wider round the same words), laid out as STA-R82 in the books art kit's type and its three looks (`/paglebooks trackers`: No frame, Logbook, Brass). Look reference: the books kit, after tracker T1 in `prototypes/stats-window/`.

## Settings

Stats adds one section to the **Trackers** page with `M:AddSetting("trackers", …)`; it adds rows to no other page.

| Option | Values | Default |
|---|---|---|
| Show the live tracker (`checkbox`, id `tracker`) | on/off | off |
| ↳ Watched Dry spells (`custom`, parent `tracker`) | "{n} of 3"; one row per watch, "{item}, {place}" (the watched area's own name) with a "Stop watching" button; with none, "Watch a Dry spell from any fish's page in the Stats book." | none |
| Stats tracker frame (added by Core, not indented) | owned goods of `stats.trackerframe` | No frame |

Tooltips: "Show the live tracker": "Shows this Session and your watched Dry spells under the minimap. Watching a Dry spell turns it on." Watched Dry spells: "Watch or stop watching from any fish's page in the Stats book."

The frame dropdown is added by Core after Stats' rows (CORE-R42) and also appears on Look and Feel. The watched list is never greyed out, since watches also show in the book; its custom row redraws at once whenever a watch changes, within a fixed height for 3 watches (SET-R6: the row's frame is Stats' own, so it may redraw at once, keeping its size). The page's Defaults button turns the tracker off and leaves the watches alone. Watching from the book sets both the watches and the tracker (STA-R62).

## Tunables

| Name | Value | Rules |
|---|---|---|
| `STATS_RULES_VERSION` | 1 | STA-R20 |
| No-junk margin above `skillBase` | 95 | STA-R12 |
| Skill margin buckets | 50+ below / 1–49 below / 0–24 above / 25+ above | STA-R26 |
| Cast threshold for Your odds | 100 Casts | STA-R42, STA-R43 |
| Confidence for the range | 95% (z = 1.96) | STA-R45 |
| Never-caught bound | rule of three (3 / n) | STA-R43 |
| Band cut-offs | unlucky below 1 in 100; very unlucky below 1 in 10,000 | STA-R52 |
| Wording steps within normal | P ≥ ½; P ≥ 5% | STA-R53 |
| Floor for "fewer than 1 in a million" | P < 10⁻⁶ | STA-R53 |
| Minimum time for Catches per hour | 60 s | STA-R33 |
| Bests minimum for Catches per hour | 20 min | STA-R33 |
| Watches | 3 | STA-R60, STA-R61 |
| Search results | 6 fish, 5 places | STA-R76 |
| Earlier Sessions on This Session | 10 | UI |
| Sessions per ledger page | 16 | UI |
| Live-line tick | 30 s | STA-R73, STA-R86 |
| Book size | about 980 × 640 px | UI |
| Tracker width | about 250 px | UI |
| Tracker order in the dock | 20 | STA-R80 |
| Tracker frame tiers | logbook 1, brass 2; greenbar 1, chalkboard 1, tidegauge 2, abacus 2, astrolabe 3 | STA-R88 |

## Edge cases

- **STA-R90 Module disabled, then enabled again.** While disabled nothing of Stats loads: its tracker leaves the dock (CORE-R17) and its Settings rows vanish, while Core keeps recording. Enabled again, its projection catches up from `lastSeq` (LOG-R71), counting every Cast and Session recorded meanwhile. It raises no Write-up, since nothing was earned. Watches, the tracker setting and the book's position are in `PagleStatsDB` and come back as they were; so does the equipped frame (SHOP-R32).
- **STA-R91 Projection rebuild.** A new content fingerprint (an Uncharted item classified, a window, line or catch list changed) or a new rules version (Stats' or the Session rule) rebuilds from `seq` 0 (LOG-R72). The book and tracker show their updating states (STA-R72, STA-R85); afterwards numbers may shift, and nothing is announced.
- **STA-R92 First build over existing history.** Built like a rebuild, with the same updating states; no Write-up (ANN-R60 needs something earned). A lost `PagleStatsDB` is a first build, and its watches and settings return to their defaults.
- **STA-R93 In combat.** The book and the tracker keep working (STA-R71, STA-R86); the fold keeps running (LOG-R93). Secret values reach Stats as unknowns: a Cast with zone `0` counts toward no place (STA-R10), an unknown skill puts the Cast on side `na` (STA-R13), and an unknown live skill picks the reading side by Casts (STA-R41). "Right now" leaves out what it can't read.
- **STA-R94 Crash mid-Session.** The Casts since the last save are lost from the log (LOG-R85), and `PagleStatsDB` was saved at the same moment, so the projection matches the saved log. If it is ever ahead (`lastSeq` beyond the log's length), Core rebuilds it (LOG-R72). A Session cut short by the crash is simply shorter in its record.
- **STA-R95 Daily or weekly reset.** Nothing in Stats depends on it. A Session that crosses midnight is one record, dated by its start.
- **STA-R96 Uncharted or unconfirmed Catch.** An Uncharted item counts in every total, in `items` (the Lifetime index, named by `C_Item`), and in the rows of each place where it was caught, under *Also caught here*, with no window. When a release classifies it, the fingerprint rebuild (STA-R91) moves it to its group and applies its window. Item `0` counts as a Catch in the totals and Session records but never gets a row, an index entry or a hit. Unconfirmed catalogue facts (entries, windows, skill bases) are used as given and labelled (STA-R46).
- **STA-R97 No Casts yet.** With no Casts in the log, the nameplate reads "No Casts yet", the home spread's left page reads "Not fished anywhere yet." beside "Right now", *Where I am* opens the current place's page with every count at 0 (all rows learning), and This Session, Lifetime and Sessions read "No Sessions yet." The tracker shows only once a Session starts or a watch exists (STA-R81).
