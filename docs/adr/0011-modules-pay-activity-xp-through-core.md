# Modules pay Activity XP through Core

Any Module other than the Ledger may pay **Activity XP** toward the Angler Level, the way it pays Pagle Coins into Core's wallet (ADR 0009). A paying Module keeps its own lifetime Activity XP total in its projection. It reports that total to Core with `M:ReportXPEarned(total)`, on the same timing rules as `M:ReportCoinsEarned` (SHOP-R2). Core stores the last total per Module, tied to the log's `logId`, and a disabled Module keeps its last total.

The Ledger still owns the Angler Level, its curve and Prestige. The open problem was which **climb** Activity XP belongs to. To settle it, Core writes its Activity XP total into every Prestige entry it records (`M:RecordPrestige()`, LOG-R38):
- a climb's Activity XP is the total now minus the snapshot in the latest Prestige entry, never below 0;
- each earlier climb's Activity XP is the gap between two snapshots.

The Ledger's projection stores only its own XP and works out the level from both whenever it needs it. So another Module's total never makes the Ledger rebuild, and the answer is the same on every rebuild, because the snapshots are in the log.

Decided in [Core XP income: how any Module awards Angler Level XP](https://github.com/timemir/wow-fish/issues/278), on the map [Hunts redesigned around Hunt Events](https://github.com/timemir/wow-fish/issues/277). It follows the note added to ADR 0001 on 18 Oct.

## Considered Options

- **Dated awards:** each award reported with the position in the log of the entry that earned it, which the Ledger merges with its own XP in log order. Rejected:
  - it puts climb placement exactly where it belongs, but the interface is much larger;
  - Core must store a list that only grows;
  - every Module replays its awards on each rebuild;
  - the only difference it would make is where a recounted total lands.
- **The Angler Level moves into Core, with the Ledger as one more source.** Rejected: the curve, Fresh Water, Prestige and the Journal are all Ledger rules, and Core would stop being a simple ledger of totals.
- **One central table in Core of what pays.** Rejected: Core would have to know each Module's own concepts (a Hunt's tiers, a Notice). Each Module keeps its pay in its own Tunables, and a Core spec keeps an overview table of every source, as it does for Coins.

## Consequences

- **Core's interface:** `M:ReportXPEarned(total)`, `Pagle.GetActivityXP()` (returning `{ total, bySource = { [module] = { total, enabled } } }`), the event `ActivityXPChanged(entry)`, and one new field in the Prestige entry. Only the Ledger reads them.
- **A live report carries its entry,** so a level-up it causes rides on that Cast's announcement (ANN-R10, ANN-R11). Totals reported during a catch-up or rebuild bring their level-ups only as summary-only moments.
- **The level can't fall:**
  - a total that is recounted lower makes a climb's Activity XP smaller, never below 0;
  - the shown level never drops (LED-R36).
- **No Fresh Water doubling,** since Activity XP isn't Catch XP. Beyond level 60 it carries into the next climb like any other XP (LED-R30, LED-R32).
- **Disabling a paying Module never lowers the level,** but it slows what's still to come. The Angler page and the XP bar's tooltip show XP by source, with a disabled Module's line greyed, so that cost stays visible.
- **Stored totals are tied to the `logId`,** for Coins as well as Activity XP, so a new log never inherits the old log's totals.
- **The backend's fold** (pagle-backend ADR 0003) runs every paying Module's `logic/` before the Ledger's, then works out the level from their totals and the Prestige snapshots.
