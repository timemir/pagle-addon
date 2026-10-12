# Modules append opaque records to the Catch log

Amends the Core data model (ADR 0003, ADR 0004).

A Module can ask Core to append a **Module record** to the Catch log: `Pagle.AppendRecord(kind, payload)` writes an `A1|<module>|<kind>|<payload>` entry with the usual entry ID, server time and `seq`. Core never reads the payload; it only stores it and hands it back, as a typed record tagged with its Module, to that Module's `IterateCatches` replay. A Module uses it for facts its projection needs that the log can't otherwise rebuild: a player's choice (a Tackle Board reroll) or a random draw that must not change later (a Notice being issued).

The Tackle Board forced the question. Its Notices pay a currency, and a reroll is a player choice. A Notice regenerated from a seed during a rebuild could point somewhere else after a content-data update, and the currency it paid could then change, or fall below what was already spent. ADR 0004 requires every Module's state to be rebuildable from the log, so both the issued Notice and the reroll have to be in the log.

## Considered Options

- **Kind-specific entries in Core** (`R1|…` for rerolls, like `P1|…` for Prestige). Rejected: every new Module feature would need a Core release, and Core's codec would learn one Module's internals.
- **Keep them in the Module's own DB, outside the projection.** Rejected: it breaks ADR 0004, because a corrupt DB or a rebuild silently loses rerolls and reshuffles Notices.
- **Regenerate Notices from a deterministic seed.** Rejected: stable only until the first content-data or generator change.

## Consequences

- ADR 0001 still holds: a Module replays only its own records. Records from a disabled or uninstalled Module stay in the log and are skipped.
- A record's payload follows the same rule as every entry: never rewritten, with a new `kind` for a new shape. A shipped record is as immutable as a shipped Hunt (ADR 0005).
- Records are small and rare, a few a day, so they barely touch the log's size budget. They must never be used as a cache of derived state.
- Prestige could have been a Module record. It stays `P1` for now, and because nothing ships before 1.0, folding it in later costs nothing.
- Records are client-written, like everything in the log. A future backend that needs to trust rerolls, purchases or currency must validate them on the server. That belongs to the backend effort, which is out of scope for now.
