# Tackle Board

> Status: Done · Milestones: M7 · Sources: [Design the Tackle Board](https://github.com/timemir/wow-fish/issues/25#issuecomment-6124911363), [Prototype the Tackle Board](https://github.com/timemir/wow-fish/issues/29#issuecomment-6126015781), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441), [Prototype the Settings tree](https://github.com/timemir/wow-fish/issues/32#issuecomment-6129969765), [Write the Core spec](https://github.com/timemir/wow-fish/issues/35), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652); ADR 0001, 0004, 0007, 0008, 0009, 0010. Prototype: `prototypes/tackle-board/` (variant C)

The Tackle Board is the `Pagle_TackleBoard` Module: an opt-in cork board of **Notices** and **Expeditions** that never expire, a **Campfire** kept alight by **Kindling**, a **Fly Box**, and a tally with titles. It builds on the Core contracts in [`core/`](core/README.md) and uses terms as `CONTEXT.md` defines them.

## Purpose and boundary

**Owns:**
- starting the board, board days and refills, issuing and rerolling goals (as Module records, ADR 0008)
- the goal kinds, their generation and their progress
- completion rewards inside the Module: Pagle Coins paid into Core's wallet, the tally and its titles, the Fly Box, the Campfire and Kindling
- the cork board view, the HUD tracker, its tracker-frame goods, and its moments and summary line

**Doesn't own:**
- anything about *when* a fish bites: a goal never uses a time of day, season or calendar event (that is Hunts' ground). A goal never references a Hunt, and the Tackle Board pays no Ledger XP (ADR 0001).
- the balance, the shop or how a tracker frame is bought (Core, ADR 0009)
- how moments are shown (Core, ADR 0007), or the tracker dock (CORE-R70)
- Simulated Sizes (Core computes them, LOG-R65); the Tackle Board only reads the band

**Uses from Core:** the calls listed under [Contracts](#pagle-api-used).

## Rules

### The Module

- **TKB-R1** `Pagle_TackleBoard` registers with `def.name = "TackleBoard"`, `title = "Tackle Board"`, `order = 40`. It has one view, `{ id = "board", label = "Tackle Board" }`, which toggles the board, and one slash command, `/pagle board`, which does the same. Its `settingsAction` label is "Start my board" until the board is started, then "Open Tackle Board"; either one opens the board, and "Start my board" also starts it (TKB-R5) unless the projection is updating, in which case it only opens the board.
- **TKB-R2** The Module loads by default but stays empty and silent until the board is started: no records, no moments, no summary line, no tracker. Its projection still reads the whole log from the start (TKB-R81), so a board started late already knows which zones were fished recently and which items were ever caught.
- **TKB-R3** There is no way to stop a started board other than disabling the Module in the AddOns list.

### Starting the board

- **TKB-R5** Pressing **Start my board** (on the empty board or the Settings root) appends a `start` record (TKB-R80) with the current board day's and week's starts (TKB-R10, TKB-R11), then runs the live step (TKB-R13), which issues the first goals. The board's button is disabled while the projection is updating. A board that is already started has no Start button.
- **TKB-R6** The board counts as started from its `start` record on. Only the first `start` record counts; any later one is ignored. Board day 0 is the day of the `start` record. No goals are owed for any day before it.

### Board days and weeks

- **TKB-R10** A **board day** runs from one daily reset to the next, and a **board week** from one weekly reset to the next. Live, the current day and week start are `now + C_DateAndTime.GetSecondsUntilDailyReset() − 86,400` and `now + C_DateAndTime.GetSecondsUntilWeeklyReset() − 604,800`, with `now = GetServerTime()`.
- **TKB-R11** **Fallback:** each call falls back on its own when it is missing or returns `nil` or a value ≤ 0. The day then starts at the latest realm midnight (`now − (realm minute × 60) − (now mod 60)`, realm minute from `GetGameTime()`). The week then starts at realm midnight on the fallback reset weekday (Tunables) on or before today, compared with `C_DateAndTime.GetCurrentCalendarTime().weekday` (1 = Sunday). Both calls are on the launch re-verification list.
- **TKB-R12** Board days and weeks are **numbered from the board's start**, and every rule that needs one reads it from the log, never from the API, so live play, catch-up and rebuild agree. Write `round(x)` for `floor(x + 0.5)`.
  - The `start` record is day 0 and week 0. Each later `day` record's day is the previous boundary record's day plus `round((dayStart − previous dayStart) / 86,400)`, and its week is the previous week plus `round((weekStart − previous weekStart) / 604,800)`. Neither is ever lower than the previous record's number (a clock step back or a switch to or from the fallback can't number backwards).
  - A `start` or `day` record's own day and week are the numbers it was given. Any other entry at server time `t` has day `d + floor((t − dayStart) / 86,400)`, where `d` and `dayStart` belong to the latest `start` or `day` record with a lower `seq`. An entry before the `start` record has no day.
  - The start time of day `k` is `dayStart + (k − d) × 86,400`, and its week is `w + floor((that time − weekStart + 43,200) / 604,800)`, with `d`, `dayStart`, `w` and `weekStart` from the same latest boundary record. The 12 h slack keeps a weekly reset that coincides with a daily reset from being missed by a few seconds.
  - "Today", live, is `d + round((API day start − dayStart) / 86,400)` against the latest boundary record, so it is the number a `day` record written now would get.
  - Known, accepted error: when the reset time shifts by an hour (daylight saving) and no `day` record has been written since (the Module was disabled, or the Angler wasn't logged in that day), Casts within that hour of the reset are put on the neighbouring day. The next `day` record corrects it from then on. Live play, catch-up and rebuild still agree, because all of them use this rule.
- **TKB-R13** **The live step.** At login (on the first frame after the projection's `done` on which it isn't updating any more, never inside it: LOG-R40, LOG-R74), at each daily reset while logged in, and right after Start, the Module, if the board is started and the projection isn't updating:
  1. advances the projection to today (TKB-R14), which may raise a Campfire nod (TKB-R86)
  2. appends a `day` record if the latest `start` or `day` record isn't for today, with today's boundaries
  3. issues every goal owed (TKB-R21)
  4. updates the summary line (TKB-R87) and re-arms the reset timer (one `C_Timer.NewTicker(seconds, fn, 1)`, cancelling any earlier one) for `GetSecondsUntilDailyReset()`, or the time to the next fallback midnight, plus the reset timer delay (Tunables)
- **TKB-R14** **Advancing** the projection from its last processed day `p` to a later day `q` closes every day `p … q − 1` in order. Closing day `k`: the Campfire rule for a day without a goal done (TKB-R72) if day `k` wasn't lit; then the daily accrual into day `k + 1` (TKB-R20); then, if day `k + 1`'s week (TKB-R12) is higher than the projection's week, the projection's week rises to it. So Expeditions accrue at the first daily reset at or after the weekly reset. Applying a `start` or `day` record also raises the projection's week to the record's own week if that is higher. The projection's week only ever rises, and each rise by one is one weekly accrual (TKB-R20), whichever of the two raised it. The projection advances whenever it applies an entry with a later day than `p`, before applying that entry, and live in the live step. An entry whose day is lower than `p` (a clock step backwards) is treated as day `p` everywhere: for advancing, for the day a goal is done on and for lighting. The live step changes the projection's state table (`projection:GetState()`) directly; that is the only change made outside `apply`.

### Refilling and issuing

- **TKB-R20** The board owes goals. **At each daily reset** after day 0, `owedNotices += max(0, min(3, 6 − openNotices − owedNotices))`. **At each weekly reset** after week 0, `owedExpeditions += max(0, min(1, 2 − openExpeditions − owedExpeditions))`. The `start` record sets `owedNotices = 3` and `owedExpeditions = 1`. "Open" counts issued goals not yet completed; if a rebuild leaves more open than the cap (TKB-R101), the formula adds nothing until the count falls below it. So a slot freed by a completion refills at the next reset, missed days bank up to the cap, and only refills past the cap are lost. Nothing ever expires.
- **TKB-R21** **Issuing** happens only in the live step (TKB-R13) and on Start: while `owedExpeditions > 0`, issue one Expedition; then while `owedNotices > 0`, issue one Notice. Each is an `issue` record (TKB-R80), generated as TKB-R30–R36 say. Applying an `issue` record adds the goal as open and lowers the matching owed count by 1 (never below 0).
- **TKB-R22** An issued goal's definition (kind, target, need, pay) comes only from its record. A rebuild reads goals back from the log and never regenerates them, so a content-data or generator change never reshuffles past goals or the Coins they paid (ADR 0008). The generator, its weights and its needs can change freely for future goals.
- **TKB-R23** A goal's **ID** is the entry ID (LOG-R13) of the record that issued it (`issue` or `reroll`).

### Generating a goal

Generation runs live only, so it may use `math.random`; tests inject the random source into `logic/`.

- **TKB-R30** **Candidate zones** are the zones from `Pagle.GetZones()` whose `GetArea(zone)` has `hasData = true` and `skillBase` at or below the Angler's `bestBaseSkill` (a zone without `skillBase` is never a candidate). A candidate's **weight** is the recent-zone weight (Tunables) if the Angler has a Cast in that zone within the recent window (Tunables) before now, else 1. So zones never fished keep a regular chance.
- **TKB-R31** An **eligible Species entry** of a zone is a catch entry from `Pagle.GetZoneCatches(zone)` with no `gate`, whose item has category `fish`, `legend = false`, `noise = false` and `removed = false`. `confirmed` doesn't matter. A Species counts once per zone however many entries it has. Goals name a Species by a **representative item**: the lowest item ID among that Species' eligible entries in the zone. Its name is the Species' display name, and a Catch is of that Species when its item's `species` equals the representative item's `species`.
- **TKB-R32** **Picking the kind:** from the kinds the goal type allows (table below), drop kinds that aren't eligible, then drop kinds already open in the same type; if nothing is left, take back the open ones. On a reroll, the old goal's kind is always dropped. Then pick by weight.

  | Kind | Notice weight | Expedition weight | Eligible when |
  |---|---|---|---|
  | `haul` | 2 | 1 | at least one candidate zone |
  | `variety` | 2 | 1 | Notice: a candidate zone with ≥ 3 eligible Species. Expedition: a candidate zone with 4–12 eligible Species |
  | `wanderer` | 1 | 1 | Notice: always. Expedition: a continent with ≥ 5 candidate zones |
  | `quality` | 1 | 1 | always |
  | `size` | 1 | 1 | always |
  | `collector` | 1 | 1 | Notice: always. Expedition: at least 6 Sub-collection items (TKB-R46) the Angler has never caught appear in the catch lists of candidate zones, gated entries included |
  | `lure` | 1 | (none) | always |
  | `species` | 1 | (none) | a candidate zone with ≥ 1 eligible Species |
- **TKB-R33** **Picking the target:** a zone is drawn by weight from the candidates that make the kind eligible. A Species goal draws a zone with at least one eligible Species, then one of its eligible Species uniformly, and stores its representative item (TKB-R31). A Wanderer Expedition draws a continent uniformly from those eligible; only continents with a name in the continent name map (Tunables) are eligible. A Variety Expedition stores the representative item of every eligible Species of its zone at issue time. Before the draw, targets that an open goal of the same type and kind already has are removed from the candidates (for Species goals, compared by `species`, not by representative item); only if that leaves none are they put back. Taking back already-open kinds (TKB-R32) may therefore repeat a kind, but only repeats a target when no other exists.
- **TKB-R34** **Need, tier and pay.** A Notice draws its tier 1–3 uniformly unless the table fixes it, and pays 10 / 15 / 20 Coins for tier 1 / 2 / 3. An Expedition has tier 0 and pays 60.

  | Kind | Notice need by tier 1 / 2 / 3 | Expedition need |
  |---|---|---|
  | `haul` | 20 / 30 / 40 Catches in the zone | 150 Catches in the zone |
  | `variety` | 3 / 4 / 5 different Species in the zone; need is `min(drawn, eligible Species in the zone)` and the tier follows the need (3 → 1, 4 → 2, 5 → 3) | every stored Species, caught in the zone |
  | `wanderer` | 3 zones in one Session; tier fixed at 3 | 5 zones on the continent |
  | `quality` | 3 / 5 / 8 Catches of uncommon quality or better | 3 Catches of rare quality or better |
  | `size` | 3 / 6 / 10 Catches of the Hefty band or better | 1 Catch of the Whopper band or better |
  | `collector` | a junk item and a container in one Session (need 2); tier fixed at 2 | 3 Sub-collection items never caught before |
  | `lure` | 15 / 20 / 25 Catches with a lure on | (none) |
  | `species` | 5 / 10 / 15 Catches of the Species | (none) |
- **TKB-R35** A goal never targets the Monster band on its own (Hefty or Whopper are the minimums; a Monster still counts as better), never a Legend, and never a time of day, season, calendar event or Hunt.
- **TKB-R36** The goal's text is built at display time from its record, through `ns.L` templates (interface text, not lore): "30 Catches in Stranglethorn Vale", "4 different Species in Feralas", "Every Species of Feralas", "Catches in 3 zones in one Session", "Catches in 5 zones of Kalimdor", "5 uncommon-or-better Catches", "3 rare-or-better Catches", "3 Hefty-or-better Catches", "A Whopper-or-better Catch", "A junk item and a container in one Session", "3 Sub-collection items you don't have", "20 Catches with a lure on", "10 Oily Blackmouth". Zone names come from `C_Map.GetAreaInfo`; Species names from `C_Item.GetItemNameByID` on the representative item, shown as "…" until the client has it and redrawn on `GET_ITEM_INFO_RECEIVED` (registered with `Pagle.RegisterEvent`); continent names from `C_Map.GetMapInfo` on the continent's uiMapID (Tunables; `GetArea().continent` is the continent's instance map ID, 0 or 1); and band names from `Pagle.SIZE_BANDS`.

### Progress

- **TKB-R40** A goal counts only Catches from **caught** Casts with a higher `seq` than the record that issued it. Every Catch is one item (one loot slot), whatever its quantity. Got-away Casts count toward nothing; which Session a Cast belongs to is Core's tag (TKB-R41).
- **TKB-R41** **Session-bound** goals (the `wanderer` and `collector` Notices) count only Catches from Casts that share one Session. The Module never cuts Sessions itself (ADR 0001): it reads each Cast's `session` tag (LOG-R98). When a counted Cast's `session` differs from the Session a session-bound goal's progress belongs to, that goal's progress resets to 0 and belongs to the new Session before the Cast is counted. Because the stored progress is keyed by Core's Session IDs, `Pagle.SESSION_RULES_VERSION` is folded into the rules version (TKB-R81, LOG-R61).
- **TKB-R42** How each kind counts a Catch (all of these need a caught Cast after the goal, TKB-R40; "the zone" is the Cast's `conditions.zone`, and `0` never matches):

  | Kind | A Catch counts when | Progress |
  |---|---|---|
  | `haul` | the zone is the target | +1 per Catch |
  | `variety` (Notice) | the zone is the target and the item has a `species` and `noise = false` (gated Species, quest fish and Legends count too) | distinct Species |
  | `variety` (Expedition) | the zone is the target and the item's `species` is one of the stored representative items' Species | distinct stored Species |
  | `wanderer` (Notice) | the zone isn't `0` | distinct zones in the Session |
  | `wanderer` (Expedition) | `GetArea(zone).continent` is the target | distinct zones |
  | `quality` | the item has `noise = false` and a `quality` (LOG-R55; none means no count) at least the target (2 uncommon, 3 rare) | +1 per Catch |
  | `size` | the Catch has a `size` (LOG-R65) with `band` at least the target (3 Hefty, 4 Whopper) | +1 per Catch |
  | `collector` (Notice) | the item has `noise = false` and is category `junk` (counts as "junk") or `container` (counts as "container") | distinct of the two, in the Session |
  | `collector` (Expedition) | the item is a Sub-collection item (TKB-R46) the Angler had never caught before this Catch | distinct items |
  | `lure` | the Cast's `conditions.lure` is set | +1 per Catch |
  | `species` | the item's `species` is the representative item's, in any zone | +1 per Catch |
- **TKB-R43** Kinds that need the catalogue (`variety`, `quality`, `size`, `collector`, `species`) never count an Uncharted item or item `0`. `haul`, `lure` and `wanderer` count every Catch, Uncharted, item `0` and Noise included: their text promises Catches, and Noise still earns nothing on its own. Catalogue `confirmed` flags never matter for progress.
- **TKB-R44** A Variety Expedition leaves out of both its need and its progress any stored Species the catalogue now marks `removed`, or whose representative item no longer has a `species`, so a content fix never strands it. A goal is **stranded** when its target no longer resolves in the current catalogue: a Variety Expedition with no Species left, a Species goal whose representative item is Uncharted, has no `species` or is `removed`, or a zone or continent goal whose area `GetArea` no longer knows. A stranded goal stays open and never completes; the board marks it "no longer catchable", and it can be taken down even if it is re-posted.
- **TKB-R45** Progress is evaluated one Catch at a time, in the Cast's item order. Within one Catch, goals are evaluated in board order (TKB-R101). A goal **completes** at the Catch that brings its progress to its need; later Catches don't count for it.
- **TKB-R46** A **Sub-collection item** here is an item with category `junk`, `container`, `treasure` or `trophy`, with `noise = false` and `removed = false`. "Never caught before" means no earlier Catch in the whole log (any character, before or after the board started) has that item ID.

### Rerolling ("take it down")

- **TKB-R55** Each issued goal can be taken down **once**: the button shows on an open goal from an `issue` record (and on the stranded goal of TKB-R44) while the projection isn't updating. These conditions are checked again when the player confirms; if they no longer hold (the goal completed meanwhile, or an update started), nothing is appended. Taking it down appends one `reroll` record (TKB-R80) that names the old goal and carries a new definition of the same type, generated by TKB-R30–R36 with the old kind dropped. The new goal takes the old one's place on the board and its progress starts from the reroll record (TKB-R40). It is **re-posted**: it can't be taken down.
- **TKB-R56** Taking down a goal with progress above 0 (as displayed, TKB-R104) first asks in a native StaticPopup: "Take down this Notice? Its progress (12/30) is lost, and the new one can't be taken down." ("Expedition" for an Expedition), with "Take it down" and "Keep it". A goal with no progress comes down at once.
- **TKB-R57** Applying a `reroll` record whose old goal isn't open (already completed, or unknown) ignores the whole record, new goal included. A reroll of an open goal is applied even if that goal was re-posted: the record is the player's choice, and the "once" rule is enforced only by the button (TKB-R55).

### Completion and rewards

- **TKB-R60** When a goal completes (TKB-R45), the Module, in this order: marks it done on the Cast's board day, frees its pin (TKB-R101); adds 1 to the tally; adds its pay to lifetime Coins; ties a fly (TKB-R62); grants any tally title reached (TKB-R61); lights the day (TKB-R70), which may reach a Campfire milestone (TKB-R73); grants the Fly Box title if the box just filled. Completions earn no Ledger XP and nothing in Hunts (ADR 0001).
- **TKB-R61** The **tally** counts completed Notices and Expeditions separately, for life. Titles are earned when the combined count reaches 25, 100 and 500.
- **TKB-R62** **Tying a fly.** The Fly Box holds 30 patterns in a fixed order (Data): 24 common, then 6 rare. A Notice ties an untied common pattern; an Expedition ties an untied rare one, or an untied common one when every rare one is tied. When nothing in its pool is untied, the goal ties no fly. The pattern is `pool[(h mod #pool) + 1]`, with `pool` the untied candidates in pattern order and `h` the FNV-1a 32-bit hash (LOG-R66 step 1) of the goal's ID. A pattern is tied once and never again; every completion therefore ties a new one until its pool is empty. A rebuild that changes the order of completions (a content update reopening or completing a goal) can change which goal tied which pattern, and which days were lit; that is accepted (ADR 0004), and titles already shown stay (TKB-R64).
- **TKB-R63** Lifetime Coins earned = Σ pay of completed goals + Σ Coins of Campfire milestones reached. The Module reports it with `M:ReportCoinsEarned` from its projection's `done` and after each live entry that changes it (SHOP-R2), 0 from a `done` before Start, so after a new log (TKB-R197) the old log's total leaves the wallet. Nothing shows it (TKB-R2).
- **TKB-R64** Titles are display-only and shown only on the board (TKB-R106). A title earned once stays shown even if a later rebuild counts it unearned (the celebrated set, TKB-R83). They are never Curio Shop goods (SHOP-R20) and never reach another Module's title list (ADR 0001).

### The Campfire

- **TKB-R70** A board day is **lit** when at least one goal completes on it. The first completion on a day lights it: the Campfire count rises by 1, the longest Campfire becomes `max(longest, count)`, and if the count is now a multiple of 7, Kindling rises by 1, to at most 3.
- **TKB-R71** The Angler starts with 2 Kindling, set by the `start` record.
- **TKB-R72** Closing a day that wasn't lit (TKB-R14), with a count above 0: if Kindling is above 0, it drops by 1 and the count stays the same (that day is logged as "Kindling burned"); otherwise the fire **goes out**: the count becomes 0 and Kindling refills to 2 (logged as "went out"). With a count of 0, an unlit day changes nothing (logged as "not lit"). No player action is involved, and Kindling is never bought or chosen.
- **TKB-R73** **Milestones:** the first time the count reaches 7, 30, 100 and 365, the Angler earns 25, 75, 200 and 500 Coins and that milestone's title. Each pays once per Angler: a later fire reaching 7 again pays nothing. There is no multiplier: a long Campfire isn't worth more per goal.
- **TKB-R74** The longest Campfire is kept for good, whatever happens to the current one.

### Records and the projection

- **TKB-R80** The Module appends these Module records (LOG-R40), always from live code (TKB-R13, TKB-R5, TKB-R55), never during a catch-up or rebuild. Payload fields are separated by `;`. Formats are in [Data](#data).

  | Kind | Appended when |
  |---|---|
  | `start` | the player starts the board |
  | `day` | the live step finds no boundary record for today |
  | `issue` | a goal is issued |
  | `reroll` | the player takes a goal down |

  A record kind the Module doesn't know, or a payload it can't parse or whose values are out of range (an unknown `type` or `kind`, a tier outside 0–3, a non-positive need), is skipped. A changed shape gets a new kind (`issue2`), never an edit (ADR 0008).
- **TKB-R81** The Module keeps one projection (LOG-R70) over every entry `M:IterateCatches` yields: its own records, and every Cast from the first `seq` (for zone recency and the ever-caught set), whether or not the board was started then. Its `rulesVersion` is `TKB_RULES_VERSION × 1000 + Pagle.SESSION_RULES_VERSION` (Tunables). The Size band is frozen (LOG-R68) and the Module never reads a length, so `SIZE_RULES_VERSION` isn't folded. `TKB_RULES_VERSION` rises whenever a progress, Campfire, Fly Box or pattern-order rule changes; generation changes don't need it (TKB-R22).
- **TKB-R82** The projection's state at any moment is a pure function of the log entries applied, the catalogue, and the day it has been advanced to (TKB-R14). Advancing to today outside an apply (the live step) gives the same state a later rebuild reaches when it applies the next entry, because no completion happens without an entry.
- **TKB-R83** The **celebrated set** (LOG-R77), in `PagleTackleBoardDB.global.celebrated`, holds the IDs of completed goals and titles already shown. A goal or title is added when its live moment is raised, and in `done` as TKB-R84 says. A live completion of a goal, or a live earning of a title, already in it raises no moment; the goal still pays and ties its fly, and a milestone still pays its Coins, which then show only in the Coins total, not as a stamp. The set only grows (a few IDs a day).
- **TKB-R84** While applying entries in `"replay"` or `"rebuild"` mode, the Module tallies what they earned in a scratch field outside the stored state (cleared by `reset` and after `done`): goals completed by type, Coins, flies tied, titles earned, Kindling burned, and whether the fire went out. After a catch-up or rebuild, in `done`:
  - `info.firstBuild`: mark every completed goal and earned title as celebrated. If at least one goal is completed, raise a Write-up section, heading "Your Tackle Board was written up from {N} Casts" (N = caught and got-away Casts since the `start` record, formatted with `BreakUpLargeNumbers`), lines as TKB-R85.
  - `info.replayed > 0`: if the replayed entries completed a goal, earned a title or changed the Campfire, raise a Write-up section headed "While Tackle Board was off", lines as TKB-R85, and mark what they earned as celebrated.
  - any other rebuild (`info.rebuilt`, for example after a content update): for each completed goal and earned title not in the celebrated set, raise its moment as TKB-R86 would (same `cast` and `coins`) with `summaryOnly = true`, then mark it celebrated. This holds even when the rebuild also covers entries recorded while the Module was disabled. A goal a rebuild completes more than 28 board days back is pruned (Data) before `done` sees it, so it pays but raises no moment; that is accepted.
  - always: report Coins (TKB-R63), then schedule the live step (TKB-R13) for the next frame.
- **TKB-R85** Write-up lines, from the scratch tally, each only if non-zero: "{n} Notices and {m} Expeditions done", "Pagle Coins +{c}", "{f} flies tied for your Fly Box", "Title: {title}" (one line each), then one Campfire line from the state after the last entry applied: "Campfire {d} days" (adding "· {k} Kindling burned" if any burned), or "Your Campfire went out; your longest, {L} days, is kept" if it is out after having gone out in these entries, and no Campfire line when the count is 0 and the fire didn't go out in them. Every count has singular and plural forms in `ns.L` ("1 fly tied", "2 flies tied").

### Announcements

- **TKB-R86** Moments, raised only from live code (ANN-R4):

  | Moment (`kind`) | Rung | `cast` | `coins` | `title` / `text` |
  |---|---|---|---|---|
  | Notice completed (`noticeDone`) | `toast.low` | the Cast | the Notice's pay | "Notice complete" / "{goal text}. Tied for your Fly Box: {fly}" (the second sentence only if a fly was tied); `stamp` "Notice done"; `icon` the fly's icon, else the kind's |
  | Expedition completed (`expeditionDone`) | `toast` | the Cast | 60 | "Expedition complete" / as above; `stamp` "Expedition done" |
  | Campfire milestone (`campfireMilestone`, `order` 10) | `banner` | the Cast | the milestone's Coins | "Campfire: {n} days" / "Title: {title}" |
  | Tally title (`tallyTitle`, `order` 20) | `banner` | the Cast | | "{n} goals done" / "Title: {title}" |
  | Fly Box complete (`flyBoxComplete`, `order` 30) | `banner` | the Cast | | "Every pattern tied" / "Title: {title}" |
  | Kindling burned (`kindlingBurned`) | `nod` | | | at login (any advance from login until the login's first live step has finished): "Your Campfire kept burning while you were away: {k} Kindling used, still {d} days."; any other time: "A day went by without a goal: {k} Kindling used. Campfire still {d} days." |
  | Fire out (`fireOut`) | `nod` | | | "Your Campfire went out" (+ " while you were away" at login, as above) ". Your longest, {L} days, is kept for good. Any goal lights a new one, with 2 fresh Kindling." |
  | Board refilled | none | | | |

  One Cast's moments merge into at most two Announcements (ANN-R10, ANN-R11): a milestone banner shows together with the Notice's toast, and each one's Coins stamp sums its own moments (ANN-R23). Every **live** advance (TKB-R14) that burns Kindling or puts the fire out raises one Campfire nod, without `cast`: from the live step, or from a live apply when an entry crosses a reset before the live step's timer fires. It is `fireOut` if the fire went out, else `kindlingBurned`. An advance in `"replay"` or `"rebuild"` mode raises nothing (TKB-R84 covers it). Icons: the fly's icon, the goal kind's icon, a flame for Campfire moments, the tally plate for tally titles and the Fly Box for its title, all in-client textures picked in the M7 build ticket. All text is interface text in `ns.L`, except title and fly names, which are lore (TKB-R130). These rows match the Tackle Board rows of Core's rung table (announcements.md).
- **TKB-R87** Summary line (`M:SetSummaryLine("board", text)`), set once the board is started and updated after each live completion and each live step: "Tackle Board: {n} done today · Campfire {d} days", with "Campfire not lit" when the count is 0 and the first part left out when nothing is done today.

### The board view

- **TKB-R100** The board is a movable frame (opened centred, closed with Esc, position not saved): a wooden frame with a brass plaque reading "Tackle Board" around a cork board, with a ledge below. Unlike Pagle's native-looking frames, it is drawn in the materials of the Fish Journal, Hunts board and Stats books (parchment, ink, a serif text face for printed text, a handwriting face for notes, brass and wax), but it isn't a book. For 1.0 it uses in-client textures; custom art comes after 1.0. It opens and works normally while restricted: it creates no secure frames.
- **TKB-R101** **Board order and pins.** The top row has 2 Expedition pins, the two rows below 3 Notice pins each. A newly issued goal takes the first empty pin of its type; a re-posted goal takes its old goal's pin; a completed goal frees its pin. Pins are assigned in `apply` and kept in the projection, so the board looks the same after a reload or rebuild. If a rebuild reopens a goal and no pin of its type is empty, it hangs unpinned in an overflow strip under the Notice rows, ordered by `seq` after the pinned goals in board order (a goal re-posted in its place stays in the strip), until another goal's completion frees a pin of its type, which it takes before any new goal does. "Board order" (TKB-R45) is Expedition pins, then Notice pins, left to right and top to bottom.
- **TKB-R102** **A pinned goal.** An Expedition is a larger poster with a red top edge and a wax seal showing its pay ("60"). A Notice is a parchment slip, pinned with a brass tack at a slight tilt that straightens on hover. Each shows: its kind in small caps; the goal text (printed); handwritten progress over an ink bar ("12 of 30", or "1 of 2 this Session" for a session-bound goal); where it can be worked, in italics (the zone, the continent, "wherever it bites" for a Species goal, "anywhere" otherwise), replaced by a green handwritten "I'm here" when a goal tied to a place (`haul`, `variety`, `wanderer` Expedition, `species`) is workable here (TKB-R121); "pays N Coins"; and "take it down" unless it is re-posted, which is stamped **RE-POSTED** instead. Hovering shows the realm date and time it was posted (its record's `time`) and "Only my Catches since then count" (", all within one Session" for a session-bound goal); a Variety Expedition also lists its Species, caught ones ticked.
- **TKB-R103** **The spike.** Goals completed on the projection's current board day hang on a nail on the right, stacked, in completion order. Hovering one shows its Coins and the fly it tied. Underneath: "{n} done today. The fire's lit." or, when none, "Done ones go on the spike." The spike empties at the next reset.
- **TKB-R104** **Displayed progress** is the projection's progress, except that a session-bound goal shows 0 when `Pagle.GetSession()` is `nil` or its ID isn't the Session the progress belongs to.
- **TKB-R105** **Empty pins** show the cap: a dashed outline and a lone tack. The first 3 empty Notice pins read "A fresh Notice at reset (in 13h)", any further ones "More Notices at later resets". Empty Expedition pins read "Next Expedition at the weekly reset (Tue)", and a second one "Another at the weekly reset after". Times are read live from the API (TKB-R10, TKB-R11): whole hours rounded down ("13h") from one hour up, whole minutes rounded down ("45m") below, refreshed every 60 s while the board is open. The weekday is that of the realm date at the next weekly reset, abbreviated by `ns.L` (Sun–Sat). **Realm dates and times** on the board (this weekday, the posted time in TKB-R102, the Campfire card's days) convert server time with the realm's UTC offset, worked out live as LOG-R49 does: realm minute (`GetGameTime()`) minus the UTC minute of `GetServerTime()`, rounded to 15 minutes and taken in the range LOG-R49 gives (−10 h excluded to +14 h).
- **TKB-R106** **The ledge**, left to right:
  - **The Campfire:** a drawn flame with "{n} days" (or "Gone out" with embers when the count is 0 after a fire, or "Not lit yet" with bare logs when there has never been one), the Kindling as sticks, and "longest {L}". The flame steps up in size at 7, 30, 100 and 365 days of the current fire and brightens between steps. Clicking it opens the **Campfire card**, a pinned card with a four-week log (each of the last 28 board days, today included: lit, Kindling burned, went out, not lit, before the board, or for today while unlit, "today"), the milestones with their Coins and titles, the tally titles and the Fly Box title; titles not yet earned are greyed with what they need.
  - **The Fly Box:** a wooden box reading "{n} of 30 tied". Clicking it opens a drawer of felt compartments, 6 columns by 5 rows, filled in pattern order row by row (the rare six are the last row). A tied pattern shows its icon and name and, on hover, when and by which goal it was tied; an untied one reads "not tied yet". The six rare ones have a gilt edge and read "tied only by Expeditions".
  - **The brass tally plate:** "{n} Notices · {m} Expeditions" and the latest title earned (the highest board day in `titles`, ties broken by the order of the Titles table in Data; a title shown only through the celebrated set never counts as latest).
  - **"Coins go to the Curio Shop ☛"**, which calls `Pagle.OpenShop()`. The board never shows the balance (ADR 0009).
- **TKB-R107** **Empty state** (not started): bare cork with one pinned slip reading "Three Notices go up each day and an Expedition each week. Fish as you like: they fill in as you go. Nothing is ever taken down for being late.", and a wooden **Start my board** button below it (TKB-R5). The ledge is bare.
- **TKB-R108** **Updating:** while the projection is updating (LOG-R74) the board shows "Updating…" over the cork, and Start and every "take it down" are disabled. A started board stays started while it updates (TKB-R6): during a rebuild, whose state applies the `start` record again only partway (LOG-R72), the board, the Settings label (TKB-R1) and the Trackers checkbox (SET-R43) read the stored projection, so the board shows no empty slip and no Start, only "Updating…" over the bare cork, and closes the Campfire card and the Fly Box drawer.
- **TKB-R109** Opening the board with a goal ID (from the tracker, TKB-R123) highlights that goal's pin for 2 s. A goal ID that is no longer open opens the board with nothing highlighted.

### The tracker

- **TKB-R120** The Module docks one tracker with `M:RegisterTracker{ id = "tackleboard", order = 30, frame }` (CORE-R70). It is shown when the board is started, the projection has finished its first update this login, and the "Show goals workable here" setting is on (default on). Nothing shows before Start.
- **TKB-R121** A goal is **workable here** when: a `haul` or `variety` goal's zone is the current zone; a `wanderer` Expedition's continent is the current zone's continent; a `species` goal's Species has a catch entry in `Pagle.GetZoneCatches(current zone)`, gated or not; and always for every other kind. The current zone is `Pagle.GetConditions().zone`, re-read on `ConditionsChanged` with `"area"`. Zone `0` makes only the always-workable goals workable.
- **TKB-R122** The tracker is a native objective-tracker-style block (CORE-R73). Its header shows a small flame with the Campfire count and the number of open goals; clicking the header collapses or expands the block (saved). Under it, each workable goal in board order gets two lines: "Expedition: " (Expeditions only) plus its text with the count right-aligned ("12/30"); then where ("this Session · ", for a session-bound goal, then the zone, continent, "wherever it bites" or "anywhere", then " · here" for a goal tied to a place, TKB-R102). After them: "+N more on the board (elsewhere)" when N open goals aren't workable here, or "All done. Fresh Notices at reset." when nothing is open. There is no per-goal tracking: the tracker picks its lines itself.
- **TKB-R123** Clicking a goal line opens the board with that goal highlighted (TKB-R109). When a goal completes live, its line flashes green "Complete" for 3 s, then leaves.
- **TKB-R124** The tracker draws its frame from `Pagle.GetEquipped("tackleboard.trackerframe")` and redraws on `AppearanceChanged` for that slot. While the projection is updating it shows only its header and "Updating…".

### Curio Shop goods

- **TKB-R125** The Module registers one slot, `tackleboard.trackerframe` (label "Tackle Board tracker frame", category "Trackers"), and three goods: `tackleboard.trackerframe.none` (default), `tackleboard.trackerframe.corkboard` (tier 1) and `tackleboard.trackerframe.driftwood` (tier 2). Each good's `preview` draws a sample tracker with two fixed goal lines ("30 Catches in Elwynn Forest 12/30", "5 uncommon-or-better Catches 2/5") in that frame. The frames' art is in-client textures picked in the M7 build ticket. It registers no other goods: titles and flies are never goods (SHOP-R20).

### Lore

- **TKB-R130** Display text the Module invents is lore, read through `ns.L` from `data/lore/tackleboard.toml` by stable ID ([Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441)): each fly pattern's name, each title's text, and each good's name and description. Lore kinds belong to one addon (DATA-R102), so the Tackle Board uses its own kinds `fly`, `boardtitle` and `boardgood`, listed in `manifest.toml` under `[tackleboard.fly]`, `[tackleboard.boardtitle]` and `[tackleboard.boardgood]` (DATA-R106). IDs are in [Data](#data); the working names there are first drafts. The pipeline (emission into `ns.L`, the missing, orphan, length and placeholder checks) is the content data spec's (`docs/spec/content-data.md`); the Tackle Board's lore check turns on in M7.

## Data

### Module records

Every record is `A1|<header>|TackleBoard|<kind>|<payload>` (LOG-R40, LOG-R11). Payload fields are `;`-separated, numbers decimal, lists comma-separated and ascending.

| Kind | Payload |
|---|---|
| `start` | `dayStart;weekStart` (server times of the current board day's and week's start, TKB-R10/R11) |
| `day` | `dayStart;weekStart` |
| `issue` | `type;kind;tier;pay;need;target` |
| `reroll` | `oldGoalID;type;kind;tier;pay;need;target` (the new goal's definition; `oldGoalID` is an entry ID, TKB-R23) |

- `type`: `n` Notice, `e` Expedition. `kind`: `haul`, `variety`, `wanderer`, `quality`, `size`, `collector`, `lure`, `species`. `tier`: 1–3 for a Notice, 0 for an Expedition. `pay`: Coins.
- `target` by kind: `haul` zone areaID; `variety` Notice zone areaID, Expedition `zoneAreaID:itemID,itemID,…` (the representative items, TKB-R31); `wanderer` Notice empty, Expedition continent ID; `quality` minimum quality (2 or 3); `size` minimum band (3 or 4); `collector` empty; `lure` empty; `species` the representative item ID.
- The Variety Expedition's 12-Species ceiling (TKB-R32) keeps every payload under the 200-byte limit (LOG-R40).

Examples: `A1|1|1791731747|0|TackleBoard|issue|n;haul;2;15;30;33` (30 Catches in Stranglethorn Vale, pays 15); `A1|1|1791732000|0|TackleBoard|reroll|Player-4618-0A1B2C3D-1791731747-0;n;size;1;10;3;3`.

### Projection (`PagleTackleBoardDB.global.board`, LOG-R70)

```lua
---@class TackleBoardState
---@field started? { seq: integer, time: integer }
---@field boundary? { seq: integer, day: integer, week: integer, dayStart: integer, weekStart: integer }  -- latest start/day record
---@field day integer                 -- last processed board day (TKB-R14)
---@field week integer
---@field owed { notices: integer, expeditions: integer }
---@field pins { expeditions: (string|false)[], notices: (string|false)[] }   -- goal IDs per pin (TKB-R101)
---@field goals { [string]: TackleGoal }   -- open goals, and goals completed in the last 28 board days
---@field tally { notices: integer, expeditions: integer }
---@field coins integer               -- lifetime Coins earned (TKB-R63)
---@field flies { [string]: { day: integer, time: integer, goal: TackleGoal } }  -- tied patterns, with a copy of the goal that tied it (for the hover text)
---@field titles { [string]: { day: integer, cast: string } }  -- titleID -> board day and Cast entry ID it was earned on
---@field fire { count: integer, kindling: integer, longest: integer, milestones: { [integer]: { day: integer, cast: string } }, log: { [integer]: "lit"|"burned"|"out"|"unlit" } }  -- log keeps the last 28 days
---@field zones { [integer]: integer }   -- zone areaID -> time of the Angler's last Cast there
---@field caught { [integer]: true }     -- every item ID ever caught (TKB-R46)

---@class TackleGoal
---@field id string                   -- TKB-R23
---@field seq integer                 -- seq of the record that issued it
---@field type "n"|"e"
---@field kind string
---@field tier integer
---@field pay integer
---@field need integer
---@field target? integer           -- zone, continent, minimum quality or band, or representative item
---@field items? integer[]            -- Variety Expedition: representative items
---@field reposted boolean
---@field pin? integer                -- index in pins of its type; nil while in the overflow strip
---@field issuedDay integer
---@field time integer                -- server time of its record
---@field progress integer
---@field seen { [any]: true }        -- distinct keys for distinct-count kinds
---@field session? string             -- session-bound: the Session its progress belongs to
---@field doneDay? integer
---@field doneTime? integer
---@field doneCast? string           -- entry ID of the completing Cast (for TKB-R84's summary-only moments)
---@field fly? string                 -- pattern ID tied
```

Completed goals older than 28 board days are dropped from `goals`; the tally, flies and titles keep what the board needs from them.

### `PagleTackleBoardDB` (AceDB, account-wide)

| Key | Contents | Default |
|---|---|---|
| `global.board` | the projection table (owned by Core, LOG-R70) | |
| `global.celebrated` | `{ goals = { [goalID] = true }, titles = { [titleID] = true } }` (TKB-R83) | empty |
| `profile.tracker` | "Show goals workable here" | `true` |
| `profile.trackerCollapsed` | tracker block collapsed | `false` |

### Fly Box patterns

In pattern order (TKB-R62); IDs are lore IDs, names are first drafts.

| # | Pattern ID | Working name | | # | Pattern ID | Working name |
|---|---|---|---|---|---|---|
| 1 | `murloc_nymph` | Murloc Nymph | | 16 | `lakeshire_coachman` | Lakeshire Coachman |
| 2 | `westfall_wheatwing` | Westfall Wheatwing | | 17 | `bloodsail_streamer` | Bloodsail Streamer |
| 3 | `goldshire_gnat` | Goldshire Gnat | | 18 | `booty_bay_bucktail` | Booty Bay Bucktail |
| 4 | `duskwood_shadow` | Duskwood Shadow | | 19 | `desolace_drifter` | Desolace Drifter |
| 5 | `redridge_ember` | Redridge Ember | | 20 | `grimtotem_hackle` | Grimtotem Hackle |
| 6 | `barrens_dun` | Barrens Dun | | 21 | `needles_ant` | Needles Ant |
| 7 | `mudsnout_woolly` | Mudsnout Woolly | | 22 | `feralas_fern` | Feralas Fern |
| 8 | `gnomish_whirligig` | Gnomish Whirligig | | 23 | `tanaris_sandfly` | Tanaris Sandfly |
| 9 | `tarnished_spoon` | Tarnished Spoon | | 24 | `darkshore_dun` | Darkshore Dun |
| 10 | `ashenvale_olive` | Ashenvale Olive | | 25 | `nats_golden_doctor` | Nat's Golden Doctor (rare) |
| 11 | `kodo_hair_caddis` | Kodo-hair Caddis | | 26 | `kraken_ink_streamer` | Kraken Ink Streamer (rare) |
| 12 | `elwynn_royal` | Elwynn Royal | | 27 | `phoenix_hackle` | Phoenix Hackle (rare) |
| 13 | `swamp_midge` | Swamp Midge | | 28 | `moonwell_silverwing` | Moonwell Silverwing (rare) |
| 14 | `raptor_quill` | Raptor Quill | | 29 | `thunderhead_tiger` | Thunderhead Tiger (rare) |
| 15 | `silverpine_spinner` | Silverpine Spinner | | 30 | `deepwater_duchess` | Deepwater Duchess (rare) |

Each pattern's icon is an in-client icon texture picked in the M7 build ticket; custom fly art comes after 1.0.

### Titles

| Title ID | Earned by | Working name |
|---|---|---|
| `tally_25` | 25 goals done | the Dependable |
| `tally_100` | 100 goals done | the Tireless |
| `tally_500` | 500 goals done | Pillar of the Board |
| `campfire_7` | Campfire of 7 days | Kindler |
| `campfire_30` | Campfire of 30 days | Firekeeper |
| `campfire_100` | Campfire of 100 days | Hearthwarden |
| `campfire_365` | Campfire of 365 days | Keeper of the Long Fire |
| `flybox` | every Fly Box pattern tied | the Fly-Tier |

### Lore keys (`data/lore/tackleboard.toml`)

- `fly.<patternID>.name` for the 30 patterns (limit: `name`)
- `boardtitle.<titleID>.text` for the 8 titles (limit: title `text`)
- `boardgood.<goodID>.name` and `boardgood.<goodID>.description` for `tackleboard.trackerframe.none` (working name "No frame"), `.corkboard` ("Corkboard") and `.driftwood` ("Driftwood Plank")

## Contracts

### Registration

```lua
Pagle.RegisterModule{
  name = "TackleBoard", title = "Tackle Board", order = 40,
  settingsAction = { label = function() return started and L["Open Tackle Board"] or L["Start my board"] end, onClick = … },  -- TKB-R1
  views = { { id = "board", label = "Tackle Board", open = toggleBoard } },
  slash = { { name = "board", fn = toggleBoard, help = "Open or close the Tackle Board" } },
}
```

### Pagle API used

| Call or event | For |
|---|---|
| `Pagle.RegisterModule` | TKB-R1 |
| `M:IterateCatches`, `M:NewProjection` | TKB-R81 |
| `M:AppendRecord` | TKB-R80 |
| `Pagle.RegisterCallback` (for `ConditionsChanged`, `AppearanceChanged`), `Pagle.RegisterEvent` (for `GET_ITEM_INFO_RECEIVED`) | TKB-R36, TKB-R121, TKB-R124 |
| events `SessionStarted`, `SessionEnded` | TKB-R104 (the displayed progress of a session-bound goal) |
| event `ModulesChanged` | TKB-R120 (the tracker redraws in its equipped frame) |
| `Pagle.GetZones`, `GetArea`, `GetZoneCatches`, `GetItem`, `GetAngler` | generation (TKB-R30–R33), progress (TKB-R42) |
| `Pagle.SIZE_BANDS`, Catch `size` | TKB-R36, TKB-R42 |
| Cast `session` tag (LOG-R98), `Pagle.SESSION_RULES_VERSION`, `Pagle.GetSession` | TKB-R41, TKB-R81, TKB-R104 |
| `Pagle.GetConditions`, event `ConditionsChanged` | TKB-R121 |
| `M:RaiseMoment`, `M:SetSummaryLine`, `M:RaiseWriteUp` | TKB-R84–R87 |
| `M:ReportCoinsEarned` | TKB-R63 |
| `M:RegisterSlot`, `M:RegisterGood`, `Pagle.GetEquipped`, event `AppearanceChanged`, `Pagle.OpenShop` | TKB-R106, TKB-R124, TKB-R125 |
| `M:RegisterTracker` | TKB-R120 |
| `M:AddSetting` | [Settings](#settings) |

WoW APIs for its own logic and presentation: `C_DateAndTime.GetSecondsUntilDailyReset`, `GetSecondsUntilWeeklyReset`, `GetCurrentCalendarTime`, `GetGameTime`, `GetServerTime`, `issecretvalue` (the realm clock while it is secret), `C_Timer.After`, `C_Timer.NewTicker`, `C_Map.GetAreaInfo`, `C_Map.GetMapInfo`, `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`, `GetCurrentRegion`, `bit.bxor` (the Fly Box's hash, TKB-R62), `CreateFrame` (with the `UIPanelCloseButton` template), `CreateFont`, `UIParent`, `UISpecialFrames`, `GameTooltip`, `StaticPopupDialogs`, `StaticPopup_Show`, `BreakUpLargeNumbers`.

### Coins paid

| Source | Coins |
|---|---|
| Notice, tier 1 / 2 / 3 | 10 / 15 / 20 |
| Expedition | 60 |
| Campfire milestone 7 / 30 / 100 / 365 | 25 / 75 / 200 / 500 |

### Exposed

Nothing: no other Module can see the Tackle Board (ADR 0001).

## UI

- **The board** (TKB-R100–R109): look reference `prototypes/tackle-board/` variant C (open it with `?variant=C`). Zones, catch lists, fly names and title names in the prototype are placeholders; the text above wins where they differ.
- **The reroll confirm** (TKB-R56): a native StaticPopup.
- **The tracker** (TKB-R120–R124): a native objective-tracker-style block, third in the dock under the Hunts and Stats trackers; the prototype's tracker mode `?tracker=here` (K2).
- **Entry points:** the compartment menu's "Tackle Board", `/pagle board`, the Settings root's button (TKB-R1), and tracker lines.

## Settings

| Option | Where | Values | Default |
|---|---|---|---|
| Start my board / Open Tackle Board | Settings root, Module status list (CORE-R44) | button | |
| Show goals workable here | Trackers page (`M:AddSetting("trackers", { kind = "checkbox", id = "tracker", … })`) | on/off | on |
| Tackle Board tracker frame | Trackers page under the checkbox, and Look and Feel (Core builds both from the slot, CORE-R42) | owned frames | `tackleboard.trackerframe.none` |

Before the board is started, the checkbox is greyed out (`isEnabled` returns false). Its tooltip is always "Lists the goals you can work on where you are. Before your board is started, use Start my board on the Pagle page." The settingsAction label is a function, so it reads "Open Tackle Board" once the board is started. The row-by-row layout belongs to `docs/spec/settings.md`.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Notices per daily reset / Notice cap | 3 / 6 (the Notice pins, TKB-R101, match the cap) | TKB-R20 |
| Expeditions per weekly reset / Expedition cap | 1 / 2 (the Expedition pins match the cap; the poster's seal shows the Expedition pay) | TKB-R20 |
| Goals owed at Start | 3 Notices, 1 Expedition | TKB-R20 |
| Notice pay by tier | 10 / 15 / 20 | TKB-R34 |
| Expedition pay | 60 | TKB-R34 |
| Kind weights | as TKB-R32 | TKB-R32 |
| Needs by kind and tier | as TKB-R34 | TKB-R34 |
| Variety Notice: Species in the zone at least | 3 | TKB-R32 |
| Variety Expedition: Species in the zone | 4–12 | TKB-R32 |
| Wanderer Expedition: candidate zones on the continent at least | 5 | TKB-R32 |
| Collector Expedition: uncaught Sub-collection items in candidate zones at least | 6 | TKB-R32 |
| Quality targets | uncommon (2) for Notices, rare (3) for Expeditions | TKB-R34 |
| Size targets | Hefty (3) for Notices, Whopper (4) for Expeditions | TKB-R34 |
| Recent-zone weight / other candidate zones | 8 / 1 | TKB-R30 |
| Recent window | 14 days | TKB-R30 |
| Kindling at Start and after a fire goes out | 2 | TKB-R71, TKB-R72 |
| Kindling earned | +1 per 7 lit days of the current fire | TKB-R70 |
| Kindling cap | 3 | TKB-R70 |
| Campfire milestones | 7 / 30 / 100 / 365 days | TKB-R73 |
| Campfire milestone Coins | 25 / 75 / 200 / 500 | TKB-R73 |
| Tally titles | 25 / 100 / 500 goals | TKB-R61 |
| Fly Box | 24 common + 6 rare | TKB-R62 |
| Fallback weekly reset weekday (`weekday`, 1 = Sunday) | 3 Tuesday on `GetCurrentRegion()` = 1; 5 Thursday on 2, 4 and 5; 4 Wednesday otherwise, including when the call is missing | TKB-R11 |
| Reset timer delay | 2 s | TKB-R13 |
| Day and week length | 86,400 s / 604,800 s | TKB-R10, TKB-R12 |
| Kept history (four-week log, completed goals) | 28 board days | TKB-R106, Data |
| Highlight on open | 2 s | TKB-R109 |
| "Complete" flash on the tracker | 3 s | TKB-R123 |
| Continent name maps (continent ID → uiMapID) | 0 → 1415 (Eastern Kingdoms), 1 → 1414 (Kalimdor) | TKB-R36 |
| Week slack | 43,200 s | TKB-R12 |
| `TKB_RULES_VERSION` before 1.0 | 1 | TKB-R81 |

## Edge cases

- **TKB-R190 Module disabled, then enabled again.** While disabled it writes no records and raises nothing; Core keeps logging Casts. On re-enable, its projection catches up (LOG-R71): open goals progress and may complete on the Casts made meanwhile, unlit days burn Kindling or put the fire out, and goals fall owed at each reset passed (TKB-R20). `done` raises one Write-up section (TKB-R84) and reports Coins; the live step then issues what is owed: 3 Notices per reset passed and 1 Expedition per weekly reset, up to the caps. If a content update arrived while it was off, Core rebuilds instead of catching up, and what was earned arrives as summary-only moments (TKB-R84). Campfire changes from the replayed days appear only in the Write-up; days closed by the live step after it raise the usual nod.
- **TKB-R191 Projection rebuild.** Goals are read back from their records (TKB-R22) and progress is recounted from the log with the current catalogue, so a content update can complete a goal (credited as a summary-only moment, TKB-R84) or, rarely, reopen one; Coins follow (SHOP-R4). Celebrated goals and titles never pop up again (TKB-R83). Rerolls and Start are never lost, because they are records.
- **TKB-R192 First build over existing history.** Without a `start` record, nothing is shown or written; the projection just learns zone recency and the ever-caught set. With one (the Module's DB was lost), the board is rebuilt from its records, everything is marked celebrated, and one Write-up section lists it (TKB-R84).
- **TKB-R193 In combat.** Progress, records, the live step and the reset timer all keep running. Moments are held by Core (ANN-R35). The board, the reroll confirm and the tracker stay usable: none of them is secure. The board's Curio Shop link prints Core's chat line instead (SHOP-R41), and the Settings root can't open (CORE-R33).
- **TKB-R194 Crash mid-Session.** Records and Casts since the last save are lost together (LOG-R85): a lost `issue` leaves the goal owed, so the next live step issues a new one; a lost `reroll` brings the old goal back, still rerollable; a lost `start` leaves the board unstarted. Completions lost with their Casts never paid.
- **TKB-R195 Daily or weekly reset.** TKB-R10–R14 and TKB-R20: the live step runs at each reset while logged in, and at login for resets passed while away; a missed day burns Kindling only when that day is closed. A reset during a loading screen is caught by the timer firing late or by the next live step; the day numbering doesn't depend on when it runs.
- **TKB-R196 Uncharted or unconfirmed Catch.** An Uncharted item or item `0` counts for Haul, Lure and Wanderer only (TKB-R43). Once a release classifies it, the rebuild credits it to any goal issued before it was caught (TKB-R191). `confirmed` never matters (TKB-R31, TKB-R43).
- **TKB-R197 New dev log.** Before 1.0 a log-format change starts a new, empty log (LOG-R18): the board is unstarted again, and the old celebrated IDs simply never match.
- **TKB-R198 Two machines, one WoW account.** Each `PagleLog` keeps its own board (LOG-R97).
