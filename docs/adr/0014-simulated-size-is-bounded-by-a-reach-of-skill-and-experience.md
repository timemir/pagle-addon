# A Simulated Size is bounded by a Reach of skill and experience, and its curves and band edges are frozen

Supersedes ADR 0010.

Under ADR 0010 a Simulated Size came from the Catch ID alone, so every Catch was an independent draw and the k-th Catch of a Species was a record with odds of 1 in k: about 3 records in the first 10 Catches, 5 in 100, 7.5 in 1,000. No shape of curve changes that, because it holds for any fixed distribution. A lucky early Catch, even at skill 1, could leave an Angler with nothing to chase for the rest of their play. Records spread over a long play only if what can be drawn grows, so a Species Catch is now bounded by a **Reach**: the lesser of a **skill reach** and an **experience reach**. Skill and experience don't make the fish bigger; they set how big a fish the Angler can land.

- **Skill reach** is the catching character's `skillRank` on the Cast ÷ 300, as a fraction of the Species' full range. Without a `skillRank`, it uses the character's latest Skill Reading before the Cast, else skill 1. The modifier (lures, gear) never counts.
- **Experience reach** is √(n ÷ 1,000), where n counts the Angler's earlier Catches of the same item ID, on any character, from the log alone, earlier slots of the same Cast included. The catalogue never enters the count, so a release that classifies an Uncharted item or moves an item between Species can't shift it; an Uncharted fish that gets classified gets the sizes it would have had live. The first Catch of a fish (n = 0) is always its smallest length.
- **The length** is `min + (Reach − min) × u^(1/3)` across the full range (0.55× to 1.80× the typical length), where `u` is ADR 0010's frozen hash of the Catch ID. Leaning toward the top keeps the best Catch near a slowly rising Reach, so records come every few Catches in small steps (simulated for a fish with a typical length of 30 cm: about 87 over its first 3,000 Catches, typically 4 mm each) until the Reach is full, and then thin out back toward 1 in k, where the rare-record flair marks them.
- **The Size band** reads the length's place in the full range, at the old multipliers' edges: Decent from 16%, Hefty from 44%, Whopper from 60%, Monster from 80%. A Monster takes high skill and a long history with that fish.
- **Legends** have no Reach: they keep ADR 0010's hash-only size over the full range, because a once-in-a-career Catch would otherwise always be a Tiddler.

Every input is in the log as recorded (the Catch ID, the Cast's skill, the earlier Catches by item ID), so a Catch's band still never changes on a rebuild, and Hunts and Notices are never revoked (ADR 0004, ADR 0005). The hash, the 300 and 1,000, both curves, the exponent and the band edges are therefore frozen once shipped. Typical lengths stay tunable, since they only rescale lengths.

## Considered Options

- **A record ladder:** each Catch drawn under the previous record plus a maximum step. Rejected: every size would depend on every earlier one, so a data fix early in a fish's history would ripple through every later size and band.
- **Counting Catches of the Species as the catalogue defines it.** Rejected: a release reclassifying an item would shift the count, and so the bands, of every later Catch.
- **The Angler Level as the driver.** Rejected: the Ledger owns it and Core computes sizes (ADR 0001), and a Prestige would shrink the Reach again.
- **Skill relative to the fish's zone skill from content data.** Rejected for ADR 0010's reason: a corrected data value would move sizes.
- **Shifting the whole distribution with skill** rather than bounding it. Rejected: it changes how every Catch feels rather than opening the range step by step.

## Consequences

- ADR 0010's objection that a skill-driven size reads as a claim that skill makes the game's fish bigger is met by the framing: the Reach is what the Angler can land, and lures, auras, conditions and place still never move a size. The Reach is never shown; it works as an RPG element without explanation.
- Pagle's experience starts at install: an Angler who installs at skill 300 starts every fish at its smallest length, as the Ledger counts nothing it didn't see.
- Core needs each item's earlier Catch count at every Cast, including when a Module reads from a later `seq`.
- The Tackle Board drops its `size` goal kind: under a Reach any band goal is impossible for a new Angler or trivial for a veteran, and a goal of size records stalls once the Reach is full. Hunts keep `minBand`, but a Hunt using it must name a fish its players will have caught a lot of.
- An Angler's alts share the account-wide experience but not the skill, so a low-skill alt lands small fish of a Species the main knows well.

## Note: "shipped" means released at 1.0 or later

As with ADR 0005 and ADR 0010, nothing was published before 1.0. Beta logs rebuild under these rules through `SIZE_RULES_VERSION`, with no migration.
