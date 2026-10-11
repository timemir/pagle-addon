# Ledger progression is derived from the Catch log, with a high-water mark

Every number the Ledger shows (XP, Angler Level, Fresh Water, Zone and Species Mastery, Ledger completion, titles) is recomputed on load as a pure function of Core's Catch log plus the shipped content data. Nothing the Ledger awards is stored as a running total. The one exception is a small set of what the player has already been shown: titles, level-ups, ranks and Legends. With that set, a rebalance or a content-data fix never takes back something already celebrated, and never fires the same toast twice.

We accept that a displayed number can shift after a balance patch or a data correction, and say so in the patch notes. In return we get three things. Retroactive credit works: an Uncharted catch becomes a Species later. Rules can be tuned after launch without migrations. And the Ledger stays rebuildable from the log, which a disabled-then-re-enabled Module and a future backend both rely on.

## Considered Options

- **Pure derivation with no high-water mark.** Rejected: a title or level could visibly vanish after an update, which reads as a loss mechanic.
- **Store increments, never recompute.** Rejected: no retroactive credit for late-classified catches, every rule change needs a migration, and the Ledger could drift from the log.

## Consequences

- Player actions that aren't Catches but change progression, such as a Prestige, must be recorded as events in the log too. Otherwise derivation can't see them.
- Anything random must be reproducible from the log. A Simulated Size is computed from the Catch's unique ID, not rolled at Catch time.
- Fresh Water is computed from the gaps between Catch timestamps, so it needs no stored state of its own.
