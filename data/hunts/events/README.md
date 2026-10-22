# The Hunt Event pool

One file per Hunt Event, `<event-id>.toml`, holding one `[event]` table and its 3-5 `[[hunt]]` tables (DATA-R97,
ADR 0012). `scripts/generate-data.py` reads every `*.toml` here, checks it (DATA-R99) and emits
`addons/Pagle_Hunts/data/EventList.lua` (DATA-R98); it ignores this README. The keys and the checks are in
`docs/spec/content-data.md`, what each field means in `docs/spec/hunts.md`, and the tags come from
`data/hunts/tags.toml`.

An event leaves the pool by `rotation = false` and a `retired` date, never by deleting its file (DATA-R98). The 1.0
pool is ticket #306's 24 rotating events, 8 per band, so `eventPool` in `data/checks.toml` is on (DATA-R66):
a band short of 8 rotating events fails the generator. Their names and notes are working text until the lore
batch (#307).
