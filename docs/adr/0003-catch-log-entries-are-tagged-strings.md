# Catch log entries are tagged strings that are never rewritten

Each entry in Core's Catch log is stored as one compact string with a kind-and-version tag (`C1|…` for a Cast, `S1|…` for a Skill Reading, `P1|…` for a Prestige), not as a Lua table. A versioned codec in Core's `logic/` decodes them, and Modules only ever see the typed records `IterateCatches` hands them. WoW writes SavedVariables one field per line with indentation, so a keyed table costs about 250 bytes per Catch (~15 MB for 60k Catches, about a year of heavy fishing) against about 60 bytes as a string (~4 MB). The whole file is parsed on every load, so size is load time for every player.

Once written, an entry is never rewritten or migrated. A new shape gets a new tag (`C2`), and the codec reads every tag forever. A future backend deduplicates entries by their ID (character GUID + `GetServerTime()` + a tie-break counter), so an entry that changed after upload would leave two versions under one ID. The same reason rules out compaction: the log is the Angler's full history.

## Considered Options

- **Keyed tables.** Readable and easy to type with LuaCATS, but about four times the size.
- **Positional arrays.** No smaller on disk (the client writes a `-- [n]` comment per value) and the least readable.
- **Rolling old Casts up into per-day counts.** Rejected: it breaks Fresh Water, retroactive Uncharted credit, Simulated Size and backend upload, all of which need individual entries.

## Consequences

- The SavedVariables file isn't self-explanatory to a companion app. The format is documented in the spec, and the codec's busted tests serve as reference examples.
- Migrations exist only for settings and Module state (`PagleDB`, `Pagle<Module>DB`), never for `PagleLog`.
