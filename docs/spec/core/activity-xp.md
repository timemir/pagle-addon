# Core: Activity XP

> Status: Draft · Milestones: M8 Hunt Events · Sources: [Core XP income: how any Module awards Angler Level XP](https://github.com/timemir/wow-fish/issues/278), [XP amounts per activity, and the Prestige cost](https://github.com/timemir/wow-fish/issues/279), map [Hunts redesigned around Hunt Events](https://github.com/timemir/wow-fish/issues/277); ADR 0001 (its note of 18 Oct), ADR 0009, ADR 0011

Part of [Core](README.md). Core holds each Module's lifetime **Activity XP**, the XP a Module other than the Ledger pays toward the Angler Level for something achieved there (ADR 0011). It works like the Coins wallet: each paying Module reports one lifetime total, and Core only keeps and shows the totals. The Ledger alone reads them and owns the Angler Level, its curve and Prestige ([ledger.md](../ledger.md)).

## Purpose and boundary

**Owns:** the stored totals per Module, their tie to the log's `logId`, the snapshot written into each Prestige entry, `Pagle.GetActivityXP()`, the `ActivityXPChanged` event, and the overview table of every source.

**Doesn't own:** what a Module pays for or how much (each Module's spec and Tunables), the Angler Level, the climb arithmetic and the level-up moments (the Ledger, LED-R37–R39), or how the totals are shown on the Angler page (LED-R146).

## Rules

- **AXP-R1** Activity XP rewards achievements only, never raw volume (as SHOP-R1 does for Coins). Core itself pays none. The Ledger never reports Activity XP: its own XP is its own fold (LED-R20). Stats and QoL pay none.
- **AXP-R2** A paying Module keeps its own **lifetime Activity XP** in its projection (ADR 0004) and reports it with `M:ReportXPEarned(total)`, on SHOP-R2's timing: from its projection's `done` after every catch-up or rebuild (even when unchanged), and after each live entry that changes it. It never reports mid-rebuild. A total is a non-negative integer; anything else raises a Lua error in the caller.
- **AXP-R3** Core stores the last total each Module reported in `PagleDB.global.activityXP.earned[<def.name>]`, with the `logId` it was reported under (`PagleDB.global.activityXP.logId`). A Module that is disabled or uninstalled keeps its last total, so disabling it never lowers the Angler Level. When `PagleLog.logId` differs from the stored `logId` (a new log, LOG-R18), Core empties the stored totals at `ADDON_LOADED` and takes the new `logId`, so a new log never inherits the old one's totals; each Module's report after its rebuild fills them in again.
- **AXP-R4** A total that is reported lower than before (a rebalance or data fix) replaces the stored one. The Ledger floors each climb's Activity XP at 0 and never lowers a shown level (LED-R36, LED-R38).
- **AXP-R5** `M:RecordPrestige()` (LOG-R38) writes Core's Activity XP total at that moment (the sum of the stored totals, AXP-R3) into the Prestige entry it appends, as its `activityXP` field. The Ledger can't pass it or change it.
- **AXP-R6** `Pagle.GetActivityXP()` returns `{ total, bySource = { [def.name] = { total, enabled } } }`: `total` is the sum of the stored totals, and `enabled` is false for a Module that is disabled or not loaded (CORE-R41). Sources are listed only once they have reported.
- **AXP-R7** When a stored total changes, Core fires `ActivityXPChanged(entry)` once, after storing it. `entry` is the live entry whose apply led to the report (the Cast or Module record), or `nil` for a report from `done`. So a level-up it causes can ride on that entry's Announcement (ANN-R10, LED-R39).
- **AXP-R8** Activity XP is never doubled by Fresh Water (LED-R22) and never counts as Catch XP or Discovery XP. Beyond level 60 it carries into the next climb like any other XP (LED-R30, LED-R32).

### What each Module pays

As designed so far; each Module's spec is authoritative. Changing what pays is one row in that Module's Tunables plus its rules version.

| Source | Activity XP |
|---|---|
| Tackle Board: Notice, tier 1 / 2 / 3 | 100 / 150 / 200 (TKB-R65) |
| Tackle Board: Expedition | 600 (TKB-R65) |
| Hunts: a Hunt Event Hunt's tier 1 / each later tier | 150 / 100, paid again in every run (HNT-R114) |
| Hunts: a completed run (every Hunt of the run at tier 1) | 250 (HNT-R114) |
| Hunts: a Standing Hunt's tier 1 / each later tier | 500 / 250, once each (HNT-R113) |

Nothing else pays: not Campfire milestones, titles, Size records, Stats or QoL. The balance aims at about 20% on top of a typical Angler's fishing XP for one who does their Notices and every fallback run ([#279](https://github.com/timemir/wow-fish/issues/279)).

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.activityXP.earned` | `{ [def.name] = lifetimeTotal }`, the last report per Module (AXP-R3) |
| `PagleDB.global.activityXP.logId` | the `PagleLog.logId` the totals belong to (AXP-R3) |
| Catch log | `P1` entries carry `activityXP` (AXP-R5, [catch-log.md](catch-log.md#entry-formats)) |

## Contracts

| Function / event | Rules |
|---|---|
| `M:ReportXPEarned(total)` | AXP-R2 |
| `Pagle.GetActivityXP()` → `{ total, bySource }` | AXP-R6 |
| event `ActivityXPChanged(entry)` (callback `PagleActivityXPChanged`) | AXP-R7 |
| the `activityXP` field of a `P1` entry | AXP-R5 |

```lua
---@class ActivityXP
---@field total integer
---@field bySource table<string, { total: integer, enabled: boolean }>
```

## Edge cases

- **AXP-R90 A paying Module is disabled.** Its last total still counts and is shown greyed on the Angler page (LED-R146). Re-enabled, it catches up and reports again; anything it earned meanwhile arrives in the current climb.
- **AXP-R91 `PagleDB` is lost.** The stored totals are gone until each Module reports again from its next `done`; a disabled Module's stays gone until it is enabled. The Prestige snapshots are in the log and survive, so earlier climbs are unchanged.
- **AXP-R92 A Prestige while a Module is updating.** The snapshot holds the stored totals as they stand. A total that rises later lands in the new climb. Prestige needs the Ledger's projection idle (LED-R33), not every Module's.
