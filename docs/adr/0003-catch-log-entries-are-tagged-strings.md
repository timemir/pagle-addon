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

## Note: compatibility starts at 1.0

Pagle publishes nothing before 1.0 ([Cut the MVP slice and roadmap](https://github.com/timemir/pagle-addon/issues/18)). Until then the entry format, the `PagleDB` migrations and every Module's state change freely, and dev logs are wiped whenever the format changes. At the 1.0 release the shape becomes `C1`/`S1`/`P1`/`B1` and the first `schemaVersion`, and from then on the rule above holds.

## Note: build entries

[Design the /pagle report format and issue form](https://github.com/timemir/pagle-addon/issues/26) adds a build entry kind, `B1|build|serverTime`, written on login whenever `GetBuildInfo()` differs from the last one logged. It lets every Cast be tied to the client build it was seen on, which Field reports and the content data's `confirmed` rule need. It is an observation like the others, so the rules above apply to it.

## Note: purchase entries

[ADR 0009](0009-core-holds-the-pagle-coins-wallet.md) ([Design the Pagle currency and shop](https://github.com/timemir/pagle-addon/issues/28)) adds a purchase entry kind, `U1|good|price|serverTime`, written when the Angler buys something in the Curio Shop. It is a player choice like a Prestige, and stores the price paid so a later price change never moves the balance. The 1.0 shape becomes `C1`/`S1`/`P1`/`B1`/`U1`.

## Note: canonical layout

The exact field layout of every entry kind lives in `docs/spec/core/catch-log.md` ([Write the Core spec](https://github.com/timemir/pagle-addon/issues/35)). Every kind, `B1` and `U1` included, starts with the same header (character index, server time, tie-break), so every entry has an entry ID; the sketches in the notes above leave it out.
