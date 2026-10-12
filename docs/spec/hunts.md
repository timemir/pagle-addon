# Hunts

> Status: Done · Milestones: M5 · Sources: [Design Hunts and the Now/Soon board](https://github.com/timemir/wow-fish/issues/14#issuecomment-6113353568), [Prototype the Hunts board](https://github.com/timemir/wow-fish/issues/24#issuecomment-6114195571), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441), [Define the Core/Module contract](https://github.com/timemir/wow-fish/issues/9#issuecomment-6112445901), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0004, 0005, 0007, 0009, 0010. Prototype: `prototypes/hunts-board/` (variant E)

Hunts is the `Pagle_Hunts` Module. It judges every Catch in the Catch log against the shipped Hunt list, keeps each Hunt's tiers, effort and set titles, and shows what is worth fishing for now, soon or later on the **Hunts board** (a notebook) and a HUD **tracker** of pinned Hunts.

Terms are used as `CONTEXT.md` defines them. "The Hunt list" is `ns.huntList`, which the content data generator emits into `addons/Pagle_Hunts/data/HuntList.lua` (DATA-R93). "Now" means the current server time, `GetServerTime()`.

## Purpose and boundary

**Owns:**
- what each Hunt field means at runtime: which Catches qualify, tiers, completion, retirement
- set titles, effort counters and pins
- the Hunts board, the Hunts tracker and `/pagle hunts`
- the moments Hunts raises and the Pagle Coins it pays
- its Curio Shop goods (notebook covers, tracker frames) and its lore keys
- the v1 Hunt list (the contents of `data/hunts/hunts.toml`)

**Doesn't own:**
- the `hunts.toml` format, the fixed and generated classes, the admission and rarity-cap checks, `HuntList.lua`, its fingerprint and `released.lock` (content data, DATA-R85–R96)
- the condition vocabulary, `MatchesConditions` and `NextWindow` (Core, LOG-R48–R50)
- the catalogue, windows and gates (Core and content data)
- presenting Announcements, the wallet and the Curio Shop (Core, ADR 0007, ADR 0009)
- odds or "due" claims (Stats). Hunts rewards nothing in another Module: no Ledger XP, nothing for the Tackle Board (ADR 0001).

**Uses from Core:**
- `Pagle.RegisterModule` and the Module handle (CORE-R12)
- `M:NewProjection` with `:GetState()` and `:IsUpdating()` (LOG-R70–R76)
- the typed Cast records with `conditions` and per-item `size` (LOG-R65)
- the catalogue: `Pagle.GetItem`, `GetArea`, `GetZones`, `GetZoneOf`, `GetZoneCatches` (with each catch entry's `window`, LOG-R55), `GetWindowSpec`
- conditions and the Angler: `MatchesConditions`, `NextWindow`, `GetConditions`, `GetAngler`, `SIZE_BANDS`
- events through `Pagle.RegisterCallback`: `ConditionsChanged`, `SkillChanged`, `RestrictionChanged`, `AppearanceChanged`; and `Pagle.IsRestricted`
- moments: `M:RaiseMoment`, `M:RaiseWriteUp`, `M:SetSummaryLine`
- the wallet: `M:ReportCoinsEarned`, `M:RegisterSlot`, `M:RegisterGood`, `Pagle.GetEquipped`
- surfaces: `M:RegisterTracker`, `M:AddSetting`

Hunts never cuts Sessions and doesn't read a record's `session` (LOG-R98).

## Rules

### The Hunt list at runtime

- **HNT-R1** The Hunt list is the only source of Hunts. Hunts reads its sets, Hunts and classes from `ns.huntList` (DATA-R93) and their text from its own `ns.L` (`hunt.<id>.name`, `hunt.<id>.note`, `set.<id>.name`, `set.<id>.title`, `set.<id>.note`, DATA-R105). Display order is file order, for sets and for Hunts.
- **HNT-R2** A Hunt **exists** at server time `t` when `since <= t` and it has no `retired`, or `t < retired`. A Hunt is **current** when it exists now. A Hunt whose `since` is still ahead (shipped early) isn't shown anywhere until then.
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
- **HNT-R14** A Simulated Size band never changes for a logged Catch (LOG-R68, ADR 0010), so a `minBand` Hunt is never revoked by a rebuild. Monster (band 5) is never a `minBand` (DATA-R89); a Monster Catch still qualifies for any `minBand` from 2 to 4.

### Tiers and completion

- **HNT-R15** A Hunt's `tiers` are count thresholds. Tier `k` is **reached** when the count first reaches `tiers[k]`. Tier 1 is **completion**. Each reached tier stores the Catch that reached it: its Cast's `time`, its Catch ID, its item ID, the Cast's zone areaID and the Cast's realm date (`cast.conditions.date`, LOG-R49). A Cast's Catches are taken in loot-slot order (`items[n]`, ascending `n`), so with several qualifying Catches in one Cast, the first in slot order reaches a tier first.
- **HNT-R16** A Hunt completes once. After its last tier the count keeps rising and is still shown; nothing more is earned.
- **HNT-R17** A Hunt is **done** when tier 1 is reached, and **finished** when every tier is reached.
- **HNT-R18** Tier **trim**: tier 1 bronze, tier 2 silver, tier 3 and any later tier gold. A Hunt's icon wears the trim of its highest reached tier.

### Set titles

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

### Groups on the board

- **HNT-R40** Hunts groups every current Hunt into exactly one of **Now**, **Soon**, **Later** or **On demand**, from `Pagle.NextWindow(boardSpec, now)` (LOG-R50) and the live `Pagle.GetConditions()`, in this order:
  1. no board spec (HNT-R7) or short of skill (HNT-R33): **Later**
  2. `onDemand` (the spec has `auras` and no time fields): **Now** while any of its auras is in the live snapshot's `auras`, otherwise **On demand**
  3. `always`: **Now**
  4. `openNow`: **Now**, except that a spec that also has `auras` is **On demand** while none of them is up
  5. `opensAt - now` at most the Soon horizon (Tunables): **Soon**
  6. otherwise, including a `nil` result: **Later**
  
  "Aura up" below means the Hunt is Now through rule 2, or through rule 4 with `auras`.
- **HNT-R41** The live calendar decides whether an event is open now; the shipped weekly rule decides Soon and Later. Both come from `NextWindow` (LOG-R46, LOG-R50); Hunts never reads `C_Calendar` to group.
- **HNT-R42** Hunts regroups when:
  - the earliest `opensAt`, `closesAt` or Soon-horizon crossing among current Hunts passes, by a `C_Timer` set to it
  - `ConditionsChanged` fires (area, auras, lure, events or skill)
  - `SkillChanged` fires
  - every refresh interval (Tunables) while the board or the tracker is visible, for countdowns
  - a Hunt's `retired` or `since` date passes (a `C_Timer` set to the earliest one ahead)
  
  The first grouping runs at the first `PLAYER_ENTERING_WORLD` after login or reload. After every regroup, and after every live apply or `done` that changes the projection, Hunts redraws the board (if shown), the tracker and the summary line (HNT-R89).
- **HNT-R43** While `Pagle.IsRestricted()` is true, Hunts doesn't regroup: the board and tracker keep the grouping from before the restriction, because calendar reads can be secret (LOG-R46). Everything drawn from the grouping freezes with it: labels, countdowns, bars, the now line and the clock. The board's clock line adds "(paused in combat)". If the first grouping falls while restricted (a `/reload` in combat), it runs anyway, is marked paused the same way, and is redone at `RestrictionChanged(false)`. The next regroup after a restriction runs at `RestrictionChanged(false)`. Redraws for projection changes still happen while restricted.
- **HNT-R44** Within a group, rows sort by: pinned first; then, among unpinned rows, short of skill last; then by time: Now by `closesAt` ascending (Hunts with none last), Soon and Later by `opensAt` ascending (a `nil` result last), On demand none; then Hunt list order.

### Labels

- **HNT-R50** Every time a label shows is realm time. A server time `T` becomes a realm clock from one live `Pagle.GetConditions()`: realm minute of day = `(minute + floor((T - time) / 60)) mod 1440`, and the realm date is the snapshot's `date` moved by the whole days that adds.
  - **Durations**, rounded down to the minute: under an hour "37m"; under a day "2h" or "2h 10m"; a day or more "1d" or "1d 4h" (minutes dropped).
  - **Clock times**: 24-hour "06:00".
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

- **HNT-R60** The board is one frame, a two-page notebook in the Journal's book language: leather binding, parchment, ink bars, a serif text face, a handwriting face, wax seals and small-caps headings. It is about 920 × 600 px (Tunables), opens centred, moves by dragging the leather, doesn't save its position, and closes with Esc or its close button. It never links to the Journal, and the Journal never links to it (ADR 0001).
  
  Its art, fonts and colours are in-client textures and fonts picked in the build ticket to match the Fish Journal, with `prototypes/hunts-board/` variant E as the reference. That includes the leather, parchment, ribbons, seal, hatched bar, trim and group-dot colours, and the fleuron and pointing-hand marks, which are drawn as textures, never as font glyphs.
- **HNT-R61** On the leather, above the pages:
  - gilt breadcrumbs: "Hunts", then "{set}", then "{Hunt}", separated by a fleuron mark, each part clickable back up
  - the realm clock: time, short date with weekday ("Tue 14 Oct") and season, plus "(paused in combat)" under HNT-R43. The season is the first of the `summer`, `winter`, `spring` and `autumn` windows whose spec matches the live snapshot, or none. With the v1 data, summer and winter cover the whole year.
  - a "show completed" checkbox (HNT-R82)
  - a gold **nameplate** on the cover corner: "{n} titles · {m} Hunts done" (titles earned; Hunts done, retired ones included), with a tooltip listing each earned title and its full date
  - **set ribbons** on the right edge: "Board", then one per set that has a current Hunt, an earned title, or a done Retired Hunt, in Hunt list order
- **HNT-R62** The left page, "What's biting, and when", is a **timeline**:
  - a realm-time ruler from 2 hours before now to 22 hours after (Tunables), with hour ticks and a red "now" line
  - a faint wash over the next 3 hours (Soon) and over the times the `night` window holds
  - the rows of the four groups in the order Now, Soon, Later, On demand, each under its heading ("Now: open right now", "Soon: opens within 3 hours", "Later: opens after that, or needs more skill", "On demand: starts when you do") with its row count; an empty group is left out
  - a line under the list explaining the bar styles: "Hatched: open · Dashed: window unconfirmed · Pencil: needs more skill · Blue: your camp is up"
  
  The ruler stays fixed at the top of the page; the rows scroll under it when they overflow.
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
  - a **wax seal**: "Hunted {full date of tier 1}" once done, a dashed "not yet" before; and a pin toggle
  - the window line (HNT-R52), then the conditions line (HNT-R53)
  - **chips** (HNT-R65)
  - the **tier ladder**: one diamond per tier in its trim colour, filled when reached, with its threshold, the short date and zone name (`C_Map.GetAreaInfo`; none when the zone was 0) of the Catch that reached it, and an ink bar with "{count} / {next threshold}" toward the next unreached tier; a finished Hunt shows its count instead ("52 caught")
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
  - the right page shows the set's name; "Earns the title {title}", or "Earned: {title}" with a seal and the full date it was earned; an ink progress bar of done current Hunts out of current Hunts; the line "The first tier of every Hunt earns the title."; the set's note
  - below that, a checklist of **all** its current Hunts, done or not and whatever the filter, each with dotted leaders and its seal date (short date) or its tracker label; then, under "Retired", its done Retired Hunts, greyed
  - clicking a Hunt opens its entry (or retired entry, HNT-R3), with a pointing-hand mark and "back to {set}" above it
- **HNT-R67** When the board opens, it shows the Board ribbon and selects a Hunt:
  - normally the first Hunt under Now; if Now is empty, the first row
  - if no row is visible, the right page reads "Every Hunt here is done. Tick \"show completed\" to see them again."
  - if no Hunt is current at all (before the first `since`), the left page reads "No Hunts yet." and the right page is empty
  
  Opening it on a given Hunt (from the tracker) shows the Board ribbon and selects that Hunt; a pinned Hunt is always on the Board (HNT-R80).
- **HNT-R68** The board opens from Core's compartment menu entry "Hunts", from `/pagle hunts` and from the Settings status button ("Open Hunts", CORE-R44). All three call the same view function, which toggles the board. It opens and stays open while restricted; only regrouping pauses (HNT-R43).
- **HNT-R69** While the projection is updating (LOG-R74), the timeline still shows and groups as usual, but nothing is drawn from projection state: the filter hides nothing, icons show no trim, and seals, tier ladders, effort counters, set progress and the nameplate read "Updating from your Catch log…" until it finishes.
- **HNT-R70** The board's leather wears the equipped notebook cover (`Pagle.GetEquipped("hunts.notebookcover")`) and redraws on `AppearanceChanged` for that slot.

### The tracker

- **HNT-R75** Hunts docks one tracker with `M:RegisterTracker{ id = "hunts", order = 10, frame }` (CORE-R70): a native objective-tracker-style block with a collapsible "Hunts" header. It shows while its setting is on (default on), whether or not anything is pinned.
- **HNT-R76** It lists pinned current Hunts, sorted as on the board across groups (Now, Soon, Later, On demand), at most 6 Hunts (Tunables), then a "+N more" line. Each Hunt has two lines:
  - first: a dot in its group's colour (Now green, Soon amber, Later grey, On demand blue), the Hunt's name and its tracker label (HNT-R51)
  - second: the target line, "you're here" when the live zone is one of its zones, and its tier progress, "{count} / {next unreached threshold}" ("0 / 1" before completion), or "all tiers" once finished
  
  With nothing pinned it reads "Pin a Hunt to keep it here."
- **HNT-R77** Clicking a Hunt's lines opens the board on that Hunt (HNT-R67); clicking "+N more" opens the board. Clicking the header collapses or expands it; the state is saved.
- **HNT-R78** While the projection is updating, progress reads "updating…". While restricted, the tracker keeps its last grouping (HNT-R43).
- **HNT-R79** The tracker's frame wears the equipped tracker frame (`Pagle.GetEquipped("hunts.trackerframe")`) and redraws on `AppearanceChanged` for that slot.

### Pins and the completed filter

- **HNT-R80** Any current Hunt can be pinned or unpinned from its entry. Pins have no limit. A pinned Hunt sits at the top of its group (HNT-R44), always shows on the board whatever the filter, and is listed on the tracker.
- **HNT-R81** Pins are a setting in `PagleHuntsDB.profile.pins`, not Module records: they decide nothing a rebuild needs. A pin on a Hunt that isn't current (retired, or no longer in the Hunt list) is removed when the Module loads and at the regroup that finds a Hunt retired (HNT-R42). A Hunt whose `since` is still ahead can't be pinned, because it isn't shown.
- **HNT-R82** With "show completed" off (the default), the board's groups leave out finished Hunts (every tier reached, HNT-R17) unless pinned. Done Hunts with tiers left always show. The set page's checklist ignores the filter. The filter state is saved.

### Moments

- **HNT-R85** Hunts raises moments only from a `"live"` apply (LOG-R73), from its regroup (HNT-R88), or as `summaryOnly` moments from `done` (HNT-R112). Each Hunt tier and each set title is raised at most once, guarded by the celebrated set (HNT-R90).
- **HNT-R86** The moments:

  | Moment | `rung` | `kind` | `title` | `text` | `stamp` | `icon` | `coins` |
  |---|---|---|---|---|---|---|---|
  | Hunt completed (tier 1) | `toast.high` | `huntCompleted` | "Hunt complete" | the Hunt's name | "Hunt" | the item ID of the Catch that reached it | 30 |
  | further tier | `toast.high` | `huntTier` | "{Trim} tier" ("Silver tier") | "{Hunt name} · {threshold} caught" | the trim ("Silver") | the item ID of the Catch that reached it | 15 |
  | set title | `banner` | `huntSetTitle` | "Title earned" | the title | "Title" | `Trade_Fishing` | 100 |

  A moment raised in a live apply for a Catch of the Cast being applied carries `cast` = that Cast's entry ID, so Core merges it with every other moment of that Cast (ANN-R10). A Catch that crosses several tiers or Hunts raises one moment for each. A `summaryOnly` moment carries no `cast`.
- **HNT-R87** A set title **from a Catch** (HNT-R23) rides on that Cast. A title **from a retirement** is stored with `fromRetirement = true` and is always raised with `summaryOnly = true`: right away when a live apply finds it, otherwise from the next `done` (HNT-R112). It never goes into a Write-up section, except at a first build, which marks everything celebrated (HNT-R111).
- **HNT-R88** **Window moments** are opt-in (setting off by default) and for pinned Hunts only.
  - **Baseline:** every regroup records, in memory, whether each current Hunt's `NextWindow` result is `openNow`, pinned or not.
  - **When:** a regroup finds a Hunt that is pinned now, `openNow` now, and recorded as not `openNow` at the previous regroup: its time window opened, or its event started on the live calendar.
  - **Not raised** for the first grouping after login (it only sets the baseline), for a Hunt with no previous record (it just became current), for an aura starting, for a skill change, or for a Hunt short of skill. Pinning a Hunt that is already open raises nothing. The first regroup after a restriction compares against the last regroup before it.
  - **The moment:** a `nod` with `kind = "huntWindow"`, `title` "{Hunt name} is open", `text` its tracker label, and the Hunt's icon. It has `expiresAt` = `closesAt`, none if unknown, and `pastText` "{Hunt name} window opened {from}–{to}" in realm clock, where `{from}` is when the regroup found it open; "–{to}" is left out when `closesAt` is unknown. It has no `cast` and no Coins.
- **HNT-R89** Hunts keeps one Session summary line, `M:SetSummaryLine("hunts", …)`, with lifetime numbers: "Hunts: {done} of {current} done · {n} titles". {done} counts current Hunts that are done, {current} counts current Hunts, and {n} counts earned titles. It is set at the redraws of HNT-R42, which include the `since` and `retired` timers, but never while the projection is updating; the first time after login is from `done`.

### Celebrated set, Coins and the Write-up

- **HNT-R90** The **celebrated set** (LOG-R77), in `PagleHuntsDB.global.celebrated`, holds for each Hunt the highest tier already shown and each set title already shown. Core never touches it, and a rebuild never clears it.
- **HNT-R91** In a live apply, a newly reached tier or title above the celebrated set raises its moment (HNT-R86) and is added to it. One already celebrated raises nothing.
- **HNT-R110** Hunts pays Coins: 30 when a Hunt completes, 15 for each further tier, 100 for each set title. Its lifetime total is the projection's `coins`, the sum over every reached tier and earned title, Retired Hunts included. It reports the total with `M:ReportCoinsEarned` from `done` after every catch-up or rebuild, and after each live entry that changes it (SHOP-R2).
- **HNT-R111** In `done` (LOG-R76):
  - `info.firstBuild`: Hunts marks every reached tier and earned title as celebrated and raises one Write-up section headed "Your Hunts were written up from {n} Casts" ({n} = Casts applied), if anything was earned, with lines "{n} Hunts completed", "{n} further tiers", one "Title: {title}" per earned title, and "Pagle Coins +{n}"
  - `info.replayed > 0`: the same lines for what the replayed entries earned that wasn't celebrated, under "While Hunts was off", and marks them celebrated; nothing if they earned nothing
- **HNT-R112** In `done` after a rebuild that isn't a first build (a new content fingerprint, Hunt list or rules version), every reached tier or earned title not yet celebrated is raised as its moment (HNT-R86) with `summaryOnly = true`, then marked celebrated. In `done` after a catch-up, every uncelebrated title with `fromRetirement` is raised the same way, and left out of the "While Hunts was off" section. A rebuild that runs because Hunts was re-enabled after a release raises these summary-only moments instead of a "While Hunts was off" section. Tiers the rebuild no longer finds (possible only before 1.0, when definitions change freely) leave the celebrated set alone and simply stop showing.

### Goods

- **HNT-R120** Hunts registers two slots (SHOP-R21):
  - `hunts.notebookcover`, label "Notebook cover", category "Hunts": the board's leather
  - `hunts.trackerframe`, label "Hunts tracker frame", category "Trackers": the tracker's frame
- **HNT-R121** Its goods (tiers tunable, SHOP-R22):

  | Slot | Goods |
  |---|---|
  | `hunts.notebookcover` | `hunts.notebookcover.leather` (default), `hunts.notebookcover.oilcloth` (tier 1), `hunts.notebookcover.tooled` (tier 2), `hunts.notebookcover.verdigris` (tier 3) |
  | `hunts.trackerframe` | `hunts.trackerframe.none` (default: the plain native block, no frame), `hunts.trackerframe.inkwash` (tier 1), `hunts.trackerframe.waxseal` (tier 2) |

  The tracker frames follow the Tackle Board's and Stats' (a free "No frame" and two for sale at tiers 1 and 2). Each good's name and description is lore (HNT-R130); the working names are Leather, Oilcloth, Tooled Leather, Verdigris, No frame, Ink Wash and Wax Seal. Its `preview` draws the closed notebook in that cover, or a sample tracker with two fixed lines ("Night Run · in 37m", "Rack Hour · on demand") in that frame. A good's icon is its swatch. The art is in-client textures, picked in the build ticket. IDs may still be renamed before 1.0.
- **HNT-R122** Hunts registers its slots and goods in `OnInitialize`, right after `RegisterModule`. It has no earned goods.

### Lore

- **HNT-R130** Hunts' lore ID is `hunts` (DATA-R100). Its keys:
  - from `data/hunts/hunts.toml` (DATA-R105): `hunt.<id>.name` and `hunt.<id>.note` for every Hunt, `set.<id>.name`, `set.<id>.title` and `set.<id>.note` for every set
  - from `data/lore/hunts.toml` (Pagle_Hunts' lore file under DATA-R100's one-file-per-addon rule): `huntgood.<goodID>.name` and `huntgood.<goodID>.description` for the seven goods of HNT-R121. Lore kinds belong to one addon (DATA-R102) and Core owns `good`, so Hunts uses its own kind `huntgood`, listed in `data/lore/manifest.toml` as `[hunts.huntgood] fields = ["name", "description"]` with those IDs (DATA-R106).
  
  The kinds `hunt`, `set` and `huntgood` are Hunts'. The generator emits both sources into the one `addons/Pagle_Hunts/data/Lore.lua` (DATA-R104). The Hunts lore check (`hunts` in `data/checks.toml`'s `lore` list, DATA-R66) is switched on in M5. It runs DATA-R105's checks on the `hunt` and `set` keys, which aren't listed in the manifest (their IDs are the Hunts and sets in `hunts.toml`), and the full DATA-R107 checks on `huntgood`, with the `name` limit for names and no limit for descriptions. Every other Hunts string (labels, chips, headings, moment titles, weekday and month names) is interface text in `ns.L`, not lore.

### Registration and projection

- **HNT-R135** In `OnInitialize`, Hunts calls `Pagle.RegisterModule` with `name = "Hunts"`, `title = "Hunts"`, `order = 20`, one view `{ id = "board", label = "Hunts", open = <toggle the board> }` and one slash entry `{ name = "hunts", fn = <toggle the board>, help = "Open or close the Hunts board" }`. If it returns `nil` (CORE-R13), the Module stops.
- **HNT-R136** Hunts runs one projection with `M:NewProjection` (LOG-R70): `db = PagleHuntsDB.global.projection`, `rulesVersion` = the Hunts rules version (Tunables), `extraFingerprint = ns.huntList.fingerprint` (DATA-R72). Its `apply` reads only Cast records; every other kind is ignored. Hunts appends no Module records.
- **HNT-R137** For each Cast, `apply`:
  1. adds 1 to `casts`
  2. updates every Hunt that exists at the Cast's `time`: first the effort counter (HNT-R25, HNT-R26), then each qualifying Catch in loot-slot order (count, tiers, Coins, HNT-R15)
  3. checks the set titles (HNT-R23)
  4. in `"live"` mode only: raises the moments for what is newly reached (HNT-R91), then reports Coins if they changed (HNT-R110)

  Waters, classes and window specs are worked out once per load (HNT-R30); the catalogue and Hunt list can't change without a reload, and a change rebuilds the projection.
- **HNT-R138** The rules version rises whenever a rule here changes what the projection holds (qualifying, tiers, titles, effort, Coins).

## Data

### The v1 Hunt list

`data/hunts/hunts.toml` ships 16 Hunts in 5 sets, all with `since` = the pre-1.0 placeholder (DATA-R87) and no `retired`. Names, titles and notes are lore drafts for the M5 lore batch (DATA-R111). Every window opens daily or weekly, is a half-year season, or is player-started, so all pass the rarity cap (DATA-R92). No v1 Hunt has a `minBand`; the field is ready for later Hunts. Before the placeholder date no v1 Hunt is current: the board reads "No Hunts yet." and nothing counts. Tests inject their own Hunt list and `since` dates; in-game M5 checks run on or after the placeholder date.

| Set (`id`) · title | Hunt `id` | Name | Kind | Target | Window / conditions | Tiers |
|---|---|---|---|---|---|---|
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
| | `hut_hour` | Hut Hour | imposed | class `quality.rare` | `auras = { 1280342 }` | 1 / 5 / 15 |
| `pagles_wagers` · Pagle's Apprentice; set note says these are Pagle's own wagers | `grouper_by_moonlight` | Grouper by Moonlight | imposed | species 12238 (Darkshore Grouper) | `areas = { 148 }`, `time = { { 1320, 240 } }` (Darkshore, 22:00–04:00) | 1 / 5 / 20 |
| | `oddity_at_dusk` | Oddity at Dusk | imposed | class `fixed.oddity` | `time = { { 1080, 1260 } }` (18:00–21:00) | 1 / 10 / 25 |
| | `witching_hour` | Witching Hour | imposed | class `species.any` | `areas = { 10 }`, `time = { { 0, 180 } }` (Duskwood, 00:00–03:00) | 1 / 10 / 30 |
| | `dawn_trout` | Dawn Trout | imposed | species 8365 (Mithril Head Trout) | `time = { { 300, 480 } }` (05:00–08:00) | 1 / 10 / 25 |

The one fixed class: `fixed.oddity`, members 6522 (Deviate Fish) and 251524 (Whimsyfin), one for each faction's waters.

The M5 build ticket checks every item and area ID above against `data/db2/` by its enUS name before the list is committed; the names in brackets are the intent, and a wrong ID is fixed in the table and the file together. The Camp Hunts use item quality rather than an observed Rack or Hut catch list, so they work whatever the Rack and Hut turn out to add. If Live Wire or Armoured After Dark prove ungated on Forever, they fail admission (DATA-R92) and are retired (or, before 1.0, removed), keeping completions.

### `PagleHuntsDB` (AceDB, account-wide, one shared `Default` profile)

| Key | Contents | Default |
|---|---|---|
| `profile.tracker.shown` | boolean | `true` |
| `profile.tracker.collapsed` | boolean | `false` |
| `profile.windowMoments` | boolean (HNT-R88) | `false` |
| `profile.showCompleted` | boolean (HNT-R82) | `false` |
| `profile.pins` | `{ [huntID] = true }` (HNT-R81) | `{}` |
| `global.projection` | Core's projection table (LOG-R70) | |
| `global.celebrated` | `{ tiers = { [huntID] = highestTier }, sets = { [setID] = true } }` (HNT-R90) | `{ tiers = {}, sets = {} }` |
| `global.schemaVersion` | integer, for this DB's migrations | |

### Projection state

```lua
---@class HuntsState
---@field casts integer       -- Casts applied, for the Write-up heading
---@field coins integer       -- lifetime Pagle Coins earned (HNT-R110)
---@field hunts table<string, HuntProgress>   -- by Hunt ID; absent until the Hunt has effort or a Catch
---@field sets table<string, { earnedAt: integer, date: { year: integer, month: integer, day: integer }, fromRetirement: boolean }>   -- by set ID, only once earned; date as HuntTier.date, or the retired date's UTC day (HNT-R23, HNT-R87)

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

Seal and ladder dates are the stored realm `date`, never a conversion through today's snapshot (HNT-R50 is for forecasts). A set's `date` is the realm date of the Cast whose tier earned it, or, for a title from a retirement, the UTC day of that `retired` date (DATA-R87).

## Contracts

**Exposes:** nothing. Modules never call Hunts (ADR 0001).

**Core API used:** listed under Purpose and boundary.

**Events consumed:** `ConditionsChanged`, `SkillChanged`, `RestrictionChanged` (HNT-R42, HNT-R43), `AppearanceChanged` (HNT-R70, HNT-R79).

**Moments raised:** HNT-R86 and HNT-R88. These match the Hunts rows of Core's rung table (announcements.md): completion and further tier `toast.high`, set title `banner`, window opened `nod` with `expiresAt`.

**Coins paid:** 30 per Hunt completed, 15 per further tier, 100 per set title (HNT-R110).

**Curio Shop goods registered:** HNT-R120, HNT-R121.

**Settings rows added:** under Settings below.

## UI

- **Hunts board:** HNT-R60–R70. Look reference: `prototypes/hunts-board/` variant E, whose `HuntsModel` script shows the grouping and labels (its skill numbers, zones and rates are placeholders). The text above wins where they differ. Art for 1.0 is in-client textures and sepia-tinted item icons, shared with the Journal; the set ribbons and the hatched ink bar are the only new pieces.
- **Hunts tracker:** HNT-R75–R79, a native block in Core's tracker dock.
- **Entry points:** the compartment menu's "Hunts", `/pagle hunts`, the Settings status button "Open Hunts", and the tracker's lines (HNT-R68, HNT-R77).
- **Announcements:** drawn by Core from HNT-R86 and HNT-R88.

## Settings

| Option | Page | Values | Default |
|---|---|---|---|
| Show the Hunts tracker | Trackers | on/off | on |
| Hunts tracker frame | Trackers (Core adds it from the slot, CORE-R42) | owned frames | `hunts.trackerframe.none` |
| Tell me when a pinned Hunt's window opens | Announcements | on/off | off |
| Notebook cover | Look and Feel (Core, from the slot) | owned covers | `hunts.notebookcover.leather` |

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
| Tier trims | bronze / silver / gold (tier 3 and up) | HNT-R18 |
| Notebook cover tiers | oilcloth 1, tooled 2, verdigris 3 | HNT-R121 |
| Tracker frame tiers | inkwash 1, waxseal 2 | HNT-R121 |
| Hunts rules version before 1.0 | 1 | HNT-R136, HNT-R138 |
| Module menu order, tracker order | 20, 10 (Core's tables) | HNT-R135, HNT-R75 |
| v1 tiers | per Hunt, in the v1 list | Data |

## Edge cases

- **HNT-R190 Module disabled, then enabled again.** While disabled, nothing of Hunts runs, its tracker leaves the dock, and its goods leave the shop (CORE-R17, SHOP-R35). Casts recorded meanwhile count (HNT-R13): on re-enable the projection catches up in `"replay"` mode, raises no pop-ups, and one Write-up section "While Hunts was off" lists what that history earned (HNT-R111). If a release changed a fingerprint meanwhile, it rebuilds instead, and what it newly earned goes to the Session summary (HNT-R112). Pins, the filter and the celebrated set are kept in `PagleHuntsDB`. No window moment is raised for windows that opened while it was off.
- **HNT-R191 Projection rebuild.** A new content fingerprint, Hunt list fingerprint or rules version rebuilds from `seq` 0 (LOG-R72). Released definitions and frozen bands give the same completions every time (ADR 0005, ADR 0010). Newly earned tiers and titles go to the summary only and are then marked celebrated (HNT-R112); the celebrated set is never cleared or lowered. Effort counts may shift when a window is corrected; they are display only.
- **HNT-R192 First build over existing history.** One Write-up section; everything already earned is marked celebrated and nothing pops up (HNT-R111). Only Casts at or after each Hunt's `since` count, so before 1.0 that is history since the placeholder date. A fresh install with no Casts raises no Write-up.
- **HNT-R193 In combat.** Core keeps recording, and Hunts' live apply runs as usual; Core holds every moment (ANN-R35). The board can open and stay open; the board and tracker stop regrouping until the restriction ends (HNT-R43). Hunts registers no secure frames and changes no bindings. Event names are looked up only outside restriction (HNT-R53).
- **HNT-R194 Crash mid-Session.** The Casts since the last save are lost from the log (LOG-R85), and so is any change to `PagleHuntsDB` made after it, celebrated set included. A tier reached only by a lost Catch isn't reached at the next login, and is celebrated again when it is reached for real.
- **HNT-R195 Daily or weekly reset.** No rule here depends on it. Windows are realm time; one that crosses realm midnight is one window (LOG-R48), and the Extravaganza's weekly rule is a forecast, not a reset.
- **HNT-R196 Uncharted or unconfirmed Catch.** An Uncharted Catch qualifies for nothing (`Pagle.GetItem` is `nil` and no class holds it). When a release classifies it, the new fingerprint rebuilds Hunts and credits it if its Cast is at or after the Hunt's `since`, through HNT-R112; if it becomes a Species, it gains a size then (LOG-R96). Item `0` never qualifies. A natural Hunt completes whether or not its window or gating is confirmed; the board only labels it (HNT-R34). A natural Catch outside its stated window still counts and is evidence for the Field report (REP).
- **HNT-R197 Hunt retired or added by a release.** A retiring Hunt leaves the board and tracker, loses its pin, and keeps its tiers and Coins (HNT-R3). A new Hunt counts only Casts from its `since` on, so it starts at 0 even for an Angler with years of history; it never takes away a set title already earned (HNT-R20). A set title that a retirement completes is found at the next Cast, catch-up or rebuild after the `retired` date, and raised summary-only (HNT-R23, HNT-R87).
- **HNT-R198 A Hunt's target data changes.** A window correction changes the board, waters and effort but never completions (HNT-R4). An item gaining a quality or joining a Species adds Catches on the next rebuild; a released class never loses a member (DATA-R91, DATA-R96).
