# Core: Refreshes

> Status: Done · Milestones: the coin-economy work, in 1.0.0 if merged by the tag and otherwise 1.0.1 · Sources: [Hunt-earned refresh ticket for the Tackle Board](https://github.com/timemir/pagle-addon/issues/398) (its resolution and follow-up), [Refresh tickets, part 1 of 3](https://github.com/timemir/pagle-addon/issues/404), map [Coin economy](https://github.com/timemir/pagle-addon/issues/393); ADR 0001, 0004, 0009, 0011, 0017

Part of [Core](README.md). Core holds the Angler's **Refreshes** (ADR 0017): a Refresh is earned by Pagle Wagers (Event Hunts) and spent on the Tackle Board to post one new goal into an empty slot, a Notice or an Expedition at the player's choice, never past the board's caps. It is not a reroll. Core only keeps and shows the count: each Module reports one lifetime total, as it does for Coins (SHOP-R2) and Activity XP (AXP-R2), and the Refreshes held are the earned total less the spent one.

"Refresh" is the working name ([CONTEXT.md](../../../CONTEXT.md)). The code, the `Pagle` API and `PagleDB` say "tickets" where they need a name, so a rename is a glossary and string change.

## Purpose and boundary

**Owns:** the stored earned and spent totals per Module, their tie to the log's `logId`, the count held, `Pagle.GetTickets()`, the `TicketsChanged` event, the moment field `tickets` and its stamp, and the overview of who earns and who spends.

**Doesn't own:** what earns a Refresh or how many (Hunts' spec: [hunts.md](../hunts.md)), what spends one, the goal it posts or the caps it respects (the Tackle Board's spec: [tackle-board.md](../tackle-board.md)), or the Tackle Board's record of the spend.

## Rules

### Reporting

- **REF-R1** Refreshes are earned by achievements only (a completed Pagle Wager run, a Hunt of the run reaching tier 3), never by raw volume. Core itself earns and spends none. The Ledger, Stats and QoL earn and spend none; Standing Hunts, which are one-time, earn none.
- **REF-R2** Hunts keeps its own **lifetime Refreshes earned** in its projection (ADR 0004) and reports it with `M:ReportTicketsEarned(total)`; the Tackle Board keeps its own **lifetime Refreshes spent** and reports it with `M:ReportTicketsSpent(total)`. Both report on SHOP-R2's timing: from the projection's `done` after every catch-up or rebuild (even when unchanged, so a lost `PagleDB` refills), and after each live entry that changes the total. Neither reports mid-rebuild. A total is a whole number, 0 or more; anything else raises a Lua error in the caller (`M:ReportTicketsEarned takes a whole number of Refreshes, 0 or more; got …`) and stores nothing. A Module may report either method, so Core stores earned and spent separately for every Module.
- **REF-R3** Core stores the last total each Module reported in `PagleDB.global.tickets.earned[<def.name>]` and `PagleDB.global.tickets.spent[<def.name>]`, with the `logId` they were reported under (`PagleDB.global.tickets.logId`). A Module that is disabled or uninstalled keeps its last totals. When `PagleLog.logId` differs from the stored `logId` (a new log, LOG-R18), Core empties both tables at `ADDON_LOADED` and takes the new `logId`, so a new log never inherits the old one's totals; each Module's report after its rebuild fills them in again (as SHOP-R3 and AXP-R3 do). A report takes the log's `logId` as it stores, so the first totals of a log whose `logId` PLAYER_LOGIN creates (LOG-R15) stay that log's.
- **REF-R4** A total reported lower than before (a rebalance or data fix) replaces the stored one. Nothing is refunded and nothing bought is taken back, and the count never goes below 0 (REF-R5).

### The count

- **REF-R5** **Refreshes held** = Σ earned − Σ spent over every Module's stored totals, shown as **0** when that is negative. There is no holding limit: the total supply is fixed by the Event runs, so holding only moves when a Refresh is used, and under reported totals Core cannot tell when one arrived over a limit (ADR 0017). While the count is held at 0 by an earned total below the spent one, new Refreshes fill that gap first.
- **REF-R6** `Pagle.GetTickets()` returns `{ tickets, earned, spent }`: `tickets` is REF-R5's count, `earned` and `spent` the two sums, a fresh table each call. When any of the three changes, Core fires `TicketsChanged(tickets)` once, after storing, with the same table shape. A report equal to the stored total fires nothing; a first report of 0 fires nothing either, since no field changes.

### Showing a Refresh

- **REF-R7** A moment may carry `tickets = N`, a whole number above 0, for the Refreshes its event earned. Core sums the `tickets` of the moments in each Announcement and shows them as one "Refresh +N" stamp (led by the Refresh ticket's icon, an inline texture of Core's own copy of the Tackle Board's art, #466), always shown: outside the 4-stamp limit and the "+N" for the rest, and never merged with another stamp (as the Coins stamp is, ANN-R23). It is the last stamp, after the "+N", and Nods, banners and the "While you were fighting" toast (which sums the toasts it holds) carry it too. A Cast's two Announcements each sum only their own moments, so no Refresh shows twice. A moment with no `tickets`, or 0, changes nothing, and an Announcement with none has no `tickets` field. A Refresh never makes an Announcement of its own (as SHOP-R5 says of Coins), and a report is silent. The Session summary and the Write-up have no Refresh line in 1.0; the Module whose projection earned a Refresh raises the moment that carries it (HNT rules).

### Who earns and spends

- **REF-R8** What each Module earns and spends, as designed so far (each Module's spec is authoritative; changing the numbers is one row in its Tunables plus its rules version):

  | Module | Refreshes |
  |---|---|
  | Hunts: a Pagle Wager run completed (every Hunt of the run at tier 1) | earns, paid again in every run |
  | Hunts: a Hunt of a run reaching tier 3 | earns, once per Hunt per run |
  | Hunts: a Standing Hunt | earns none |
  | Tackle Board: posting a goal into an empty slot | spends 1 |

  The starting counts, 1 for a completed run and 1 for each Hunt taken to tier 3 (up to 5 per run), come from the calibration ticket ([#402](https://github.com/timemir/pagle-addon/issues/402)) and are Hunts' Tunables.
- **REF-R9** Hunts' and the Tackle Board's `logic/` give their lifetime totals as pure functions of their projection state, `TicketsEarned(state)` and `TicketsSpent(state)`: the totals they report (REF-R2), read from the state alone, with no WoW API, frame or saved data beyond the state. They are for Pagle's backend, which rebuilds the totals from its own folds as it does Coins and Activity XP (LOG-R79, SHOP-R2, AXP-R9), and never reads a client-written total ([catch-log.md › The backend's hooks](catch-log.md#the-backends-hooks)). For the same log, the backend's `TicketsEarned` and `TicketsSpent` sums equal `Pagle.GetTickets().earned` and `.spent` once both Modules are enabled and have reported from their `done`.

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.tickets.earned` | `{ [def.name] = lifetimeTotal }`, the last Refreshes-earned report per Module (REF-R3); default `{}` |
| `PagleDB.global.tickets.spent` | `{ [def.name] = lifetimeTotal }`, the last Refreshes-spent report per Module (REF-R3); default `{}` |
| `PagleDB.global.tickets.logId` | the `PagleLog.logId` the totals belong to (REF-R3); no default |

The two tables are `PagleDB` defaults (`ns.PAGLEDB_DEFAULTS`, [catch-log.md › Data](catch-log.md#data)), so no schema step is needed: a `PagleDB` that never stored them reads them empty. Core writes no Catch log entry for a Refresh (ADR 0017): the Tackle Board's spend is its own Module record (ADR 0008) and Hunts' earnings are folded from the Casts.

## Contracts

| Function / event | Rules |
|---|---|
| `M:ReportTicketsEarned(total)` | REF-R2 |
| `M:ReportTicketsSpent(total)` | REF-R2 |
| `Pagle.GetTickets()` → `Tickets` | REF-R5, REF-R6 |
| event `TicketsChanged(tickets)` | REF-R6 |
| the `tickets` field of a moment ([announcements.md › Contracts](announcements.md#contracts)) | REF-R7 |
| `TicketsEarned(state)` → integer in Hunts' `logic/`; `TicketsSpent(state)` → integer in the Tackle Board's `logic/`, for the backend ([catch-log.md › The backend's hooks](catch-log.md#the-backends-hooks)) | REF-R9 |

```lua
---@class Tickets
---@field tickets integer  -- Refreshes held: max(0, earned - spent) (REF-R5)
---@field earned integer   -- the sum of every Module's last reported total earned
---@field spent integer    -- the sum of every Module's last reported total spent
```

## Settings

None.

## Tunables

Core has none: it stores totals and sums them. The counts a run earns are Hunts' Tunables, and the caps a posted goal respects are the Tackle Board's. There is no holding limit (REF-R5).

## Edge cases

- **REF-R90 A Module is disabled, then enabled again.** While it is off, its last totals still count (REF-R3), so the count is what it was. Re-enabled, it catches up and reports again; Refreshes earned meanwhile arrive at once with no stamps, and the Module words them in its Write-up section (ANN-R60). Disabling Hunts stops new Refreshes only; disabling the Tackle Board stops spending, and what it spent stays spent.
- **REF-R91 Projection rebuild, or `PagleDB` lost.** A Module's rebuild may change its total; the stored total follows its report and the count follows the totals, held at 0 if needed (REF-R4, REF-R5). If `PagleDB` is lost, the stored totals are gone until each Module reports again from its next `done`; a disabled Module's stay gone until it is enabled. A Refresh spent is recounted from the Tackle Board's own records, so it is never refunded by the loss.
- **REF-R92 First build over existing history.** A late-enabled Module reports its whole total at once (REF-R2); it shows as a line in its Write-up section, not as stamps (REF-R7).
- **REF-R93 In combat.** Reports and the count continue; a report is silent (REF-R7), so nothing is held or dropped.
- **REF-R94 Crash mid-Session.** A Refresh is not a log entry (ADR 0017): the Hunts progress that earned it and the Tackle Board's record of the spend are the Modules' own entries, lost with the session if unsaved, so a Refresh is never charged for a goal that is not in the log.
- **REF-R95 Daily or weekly reset.** No rule here depends on it.
- **REF-R96 Uncharted or unconfirmed Catch.** Not relevant: Refreshes come from Hunts' achievements, which credit an Uncharted Catch only once it is classified.
