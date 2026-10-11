# Pagle is GPL because it ships VMaNGOS-derived data

Pagle is licensed **GPL-3.0-or-later**, the whole repo, because its shipped content data is derived from the VMaNGOS world database. No other source says where and when Classic fish are caught: loot tables, zone skill and time and season gates are server-side and never reach the client, and Forever has no observed loot data yet. VMaNGOS code is GPL-2.0-or-later (its source headers say "or any later version"), which GPLv3 may combine with. Its world-DB dump carries no separate licence statement, so we treat it as covered by the repo's. A `NOTICE` file credits VMaNGOS and states that game IDs and names belong to Blizzard. Pagle ships IDs only, never Blizzard text.

Wowhead and other fan sites are **leads only**. Anyone may read them to learn where to look, but a fact enters the content data only once it is seen in-game, by us or through a reviewed `/pagle report`. Wowhead's terms (the ZAM EULA) forbid datamining and derivative works, and its Forever fishing tabs were still a copy of Classic data when this was decided. We may ask ZAM for permission, but nothing waits on the answer.

## Considered Options

- **Use VMaNGOS only as a research seed and ship only observed or restated facts, under a permissive licence (MIT).** Rejected: launch-day zone lists would be nearly empty, which guts the Ledger's Zone Mastery and completion.
- **GPL-2.0-or-later.** Equally valid, matching VMaNGOS and GatherMate2 exactly. GPL-3.0-or-later was chosen as the modern default; the difference barely matters for an addon.
- **Copy Wowhead's data, as GatherMate2_Data does.** Rejected: against the terms we read.

## Consequences

- Anyone may fork Pagle, code and data, under the same licence.
- Relicensing later means removing every VMaNGOS-derived record and getting every contributor's consent.
- The four new Forever zones ship with no catch data. Their Catches are logged as Uncharted and credited once observations arrive.
