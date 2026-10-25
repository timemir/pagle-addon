# Core holds the Refresh purse from reported totals

Amends ADR 0001 and ADR 0009.

A **Refresh** is earned by Pagle Wagers (Event Hunts) and spent on the Tackle Board to post one new goal into an empty slot (a Notice or an Expedition, the player's choice), never past the caps. Hunts produces it and the Tackle Board consumes it, so by ADR 0001 the count has to live in Core, like the wallet (ADR 0009). It is the fourth cross-Module effect, after Pagle Coins (ADR 0009), Activity XP (ADR 0011) and pushed content (ADR 0013).

Core's **Refresh purse** is a pair of reported totals and nothing else:
- Hunts reports its lifetime Refreshes earned with `M:ReportTicketsEarned(total)`, the Tackle Board its lifetime Refreshes spent with `M:ReportTicketsSpent(total)`. Both are whole numbers, 0 or more, on the timing of `M:ReportCoinsEarned` (SHOP-R2): from the projection's `done`, even when unchanged, and after each live entry that changes the total.
- Core stores the last total each Module reported in `PagleDB.global.tickets`, tied to the log's `logId` like the Coins and Activity XP totals (SHOP-R3, AXP-R3). A disabled Module keeps its last totals.
- The Refreshes held are the sum earned minus the sum spent, shown as 0 when that is negative (`Pagle.GetTickets()`).
- A moment can carry `tickets = N`, which Core sums per Announcement into a "Refresh +N" stamp, as it does for `coins` (ANN-R23). A Refresh makes no toast of its own.

"Refresh" is the working name: the final name is a glossary-only change. The code and the spec say "tickets" where a name is needed.

Decided in [Hunt-earned refresh ticket for the Tackle Board](https://github.com/timemir/pagle-addon/issues/398), on the map [Coin economy](https://github.com/timemir/pagle-addon/issues/393). The specification is `docs/spec/core/refresh.md`.

## Considered Options

- **A Core-owned ticket ledger with its own log entry** (a grant entry written by Core when Hunts earns one, a spend entry when the Tackle Board spends one). Rejected for 1.0.0:
  - it needs a new entry kind and codec in the Catch log (ADR 0003), which the tag cannot absorb;
  - a spend would be a Core entry written beside the Tackle Board's own record of the goal it posted, with a gap between the two appends. A crash between them either charges a Refresh for no goal or posts a goal for free, and neither can be repaired from a log that is never rewritten.
- **Report-only totals**, chosen. Each Module derives its own total from its own projection (ADR 0004), so a rebuild reproduces it, and the Tackle Board's spend is the same Module record (ADR 0008) as the goal it paid for. Core stores only the last report, as it does for Coins, so there is nothing to keep atomic.

## No holding limit

The dev first set a limit of 5 held Refreshes, then dropped it. Under report-only totals Core cannot tell when a Refresh arrived over a limit: it sees the latest earned and spent totals, not the order in which they happened, so a Refresh earned over the limit looks the same as one earned under it. Total supply is also fixed by the Event runs, so hoarding only moves the timing of the extra goals and never raises the total.

## Consequences

- **Core's interface:** `M:ReportTicketsEarned(total)`, `M:ReportTicketsSpent(total)`, `Pagle.GetTickets()` (returning `{ tickets, earned, spent }`), the event `TicketsChanged(tickets)` and the moment field `tickets`. Core spends nothing and pays nothing itself.
- **ADR 0001 now allows four cross-Module effects:** Coins paid into Core's wallet (ADR 0009), Activity XP reported toward the Angler Level (ADR 0011), content pushed by the companion (ADR 0013) and Refreshes (this ADR). Modules still never call, read or listen to each other, and a Module's reward is still never another Module's call.
- **The same floor as Coins:** if a rebalance or data fix recounts a Module's total lower, the stored total follows the latest report and the count never goes below 0. A spent Refresh is never refunded.
- **Disabling a Module** keeps the totals it reported. Disabling Hunts stops new Refreshes only. Disabling the Tackle Board stops spending, and what it spent stays spent. Disabling is not a loss, because nothing already earned is taken away.
- **A lost `PagleDB`** loses the stored totals until each Module reports again from its next `done`. A disabled Module's totals stay lost until it is enabled.
- **Totals are client-written,** as Coins are. A future backend that needs to trust them folds the pure `TicketsEarned(state)` (Hunts) and `TicketsSpent(state)` (the Tackle Board) from the Catch log (LOG-R79), and validates them on the server.
- **No new Catch log entry kind and no schema step:** `PagleDB.global.tickets` is a default key (`{ earned = {}, spent = {} }`), and the `logId` tie empties both totals for a new log, as for Coins.
