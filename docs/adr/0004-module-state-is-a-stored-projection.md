# Module state is a stored projection, rebuilt only when versions change

Supersedes ADR 0002.

Every Module's derived state (the Ledger's XP, levels, mastery and records, and likewise for Stats, Hunts and the Tackle Board) is stored in the Module's own DB together with the last log `seq` it has applied. On load the Module applies only the entries after that `seq`. It rebuilds from the whole Catch log only when the content-data version or its own rules version changes, or when the projection is missing or corrupt, and that rebuild runs a chunk at a time across frames after login, never on the load screen. The rule is that derived state must *always be rebuildable* from the log, not that it is *rebuilt* on every load.

ADR 0002 recomputed everything on each load, which would cost every player a growing load-screen delay (decoding tens of thousands of entries per Module) to support rebalances that happen a few times a year. This keeps everything ADR 0002 was for: the log is the single source of truth, Uncharted catches are credited retroactively when content data changes, rules can be tuned without migrations, and a Module disabled and re-enabled rebuilds from scratch. The high-water mark of what's already been celebrated (titles, level-ups, ranks, Legends) stays, so a rebuild never takes back or re-fires a celebration.

## Considered Options

- **Recompute on every load (ADR 0002).** Rejected for the load cost above.
- **Recompute on load, with an optional per-Module cache.** Rejected: each Module would solve the same problem its own way, and one that skipped the cache would pay the full cost.
- **Store increments, never rebuild.** Still rejected, as in ADR 0002: no retroactive credit, and every rule change needs a migration.

## Consequences

- A displayed number can still shift after a balance patch or data fix, at the moment of the rebuild. Patch notes say so.
- Anything random must still be reproducible from the log: a Simulated Size is computed from the Catch ID. Fresh Water is still computed from Cast timestamps.
- While a rebuild runs, the Module shows that it's updating and queues new Casts behind it.

## Note: a re-enabled Module catches up

"A Module disabled and re-enabled rebuilds from scratch" means it *can* be rebuilt from the log, not that it is. Decided while writing the Core spec ([Write the Core spec](https://github.com/timemir/pagle-addon/issues/35)): a re-enabled Module catches up from its stored `seq`, raises no pop-ups for that history, and shows one Write-up section for anything it earned meanwhile. It still rebuilds when its projection is missing or a version changes.
