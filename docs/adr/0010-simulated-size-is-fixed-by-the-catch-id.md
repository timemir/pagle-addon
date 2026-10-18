# A Simulated Size is fixed by the Catch ID, and its band cut points are frozen

Core gives every Species Catch a Simulated Size computed from its Catch ID alone: a frozen hash turns the ID into a percentile, the percentile picks the **Size band** through fixed cut points (Tiddler, Decent, Hefty, Whopper, Monster at 15 / 70 / 93 / 99.5), and the Species' typical length scales the shared curve into a length. Nothing the player does (lure, skill, conditions, place) moves it. Hunts and Tackle Board Notices may target a minimum Size band, and they are rebuilt from the Catch log (ADR 0004), so a Catch's band must never change after it is logged: if it could, a rebuild could revoke a completed Hunt (the problem ADR 0005 exists to prevent). The hash and the cut points are therefore frozen once shipped. The typical lengths and the length multipliers stay tunable: since length rises with the percentile within a Species, retuning changes the numbers shown but never which band a Catch is in, nor which Catch holds a Species record.

## Considered Options

- **Context shifts the size curve** (lure on, auras, skill above the zone's base, caught "in its element"). Rejected: it would read as a claim that lures or skill make the game's fish bigger, which is false, and the glossary says a Simulated Size is never presented as game data. It would also push record-chasers into lures and high-skill water, a forced choice, and anything read from content data (a zone's skill base, a Species window) would move sizes whenever the data is corrected.
- **Bands by fixed lengths per Species.** Rejected: retuning a Species' lengths would move Catches between bands and could revoke completions.
- **Rolling at Catch time and storing the result.** Rejected: the log stores observations only (ADR 0003), and a stored roll adds bytes to every Catch for something the ID already determines.

## Consequences

- Records fall as for any independent draw: the k-th Catch of a Species is a record with odds of 1 in k, so records are frequent early and rare late. The Ledger's rare-record flair rewards the late ones.
- A change to how bands are drawn ships as new bands with new IDs, never by editing the old ones, mirroring ADR 0005.
- Sizes cost no stored bytes and are the same live, replayed and rebuilt.

## Note: "shipped" means released at 1.0 or later

As with ADR 0005, nothing is published before 1.0, so the cut points and the hash can still change until then.
