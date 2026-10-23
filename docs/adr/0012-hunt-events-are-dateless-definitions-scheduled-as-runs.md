# Hunt Events are dateless definitions scheduled as runs

A **Hunt Event** is defined without dates. It is one or two zones, its Hunts and their tiers, its lore, `tags`, a skill range and whether the addon's own rotation may pick it. The addon ships a pool of them, one file each in `data/hunts/events/<event-id>.toml`, and the backend can push new ones (IDs starting `p_`).

When and how often an event is on is decided apart from the definition, as **runs**. A run is `(event, start, end)` in exact UTC moments, 3 days by default, identified by the event ID plus its start:
- **Who decides:** the backend's schedule, delivered by the companion. It may pick at random, by hand or for a game holiday, with no limit on how many runs are on at once.
- **Without the companion:** the addon's **fallback rotation**. Back-to-back 72-hour runs from 1.0's release day at 15:00 UTC, each picked by a seeded shuffle of the shipped pool, so every Angler without the companion sees the same event.

An event Hunt is always imposed: it counts a Catch only in its event's zones and during the run. Each run starts fresh and pays again, and its completed count feeds the titles at 25, 50 and 100.

Decided in [The Hunt Event definition and the shipped calendar](https://github.com/timemir/pagle-addon/issues/280), on the map [Hunts redesigned around Hunt Events](https://github.com/timemir/pagle-addon/issues/277).

## Considered Options

- **A calendar shipped with each release, dated events in month files.** Rejected:
  - the dev wants one big pool, with the order decided by the backend (random, hand-picked, or for Hallow's End or the Winter Veil);
  - a calendar ties each event to a date at authoring time, and runs out between releases.
- **A cap of one main event plus at most one pushed event.** Rejected: the backend decides what is on, and the board handles any number.
- **A fallback rotation that picks for each Angler's skill.** Rejected: Anglers without the companion would no longer share an event. The skill range is only shown on the board, and the pool keeps enough low-skill events.

## Consequences

- **Logging:** Hunts logs every run it uses the first time it sees it, fallback runs included, along with the definition when it was pushed. So a rebuild never depends on the companion's current file, a later pool, or a changed rotation rule (ADR 0002, ADR 0004). The record format belongs to the pushed-content contract.
- **No changes after start:** a run can be withdrawn only before it starts. Once started it can't be shortened, lengthened or cancelled.
- **No overlap with itself:** two runs of the same Hunt Event never overlap. A pushed run of an event already on is ignored, and the rotation skips an event a pushed run has on.
- **Ended, not retired:** a run past its end has **ended**. It leaves the board with nothing kept, so there is no list of past events. **Retired** still means a Hunt replaced because it was wrong (ADR 0005).
- **Who wins:** a connected companion's schedule replaces the rotation. Runs already started always play out, and the rotation only fills time no run covers.
- **Immutable definitions:** a definition never changes once it has shipped or been pushed (ADR 0005's note). Its Hunts' hashes go into `released.lock`.

## Note: the rotation is banded

Decided in [Authoring enough Hunt Events: templates, generator and volume](https://github.com/timemir/pagle-addon/issues/281). The fallback rotation's seeded shuffle is **banded**, so an Angler of any skill has an event in reach at least every 9 days:
- the rotating pool is split into low, mid and high bands, by each event's skill range;
- the runs cycle low → mid → high, shuffled within each band by the same seeded rule;
- the rotation is still the same for every Angler.

1.0 ships 24 rotating events, 8 per band.
