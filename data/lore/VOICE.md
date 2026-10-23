# Pagle's lore voice

> Status: approved by the dev in ticket #130 (2026-10-14). The 1.0 lore gate audited every batch against it (#263), and the dev signed the lore off for 1.0 in #264 (2026-10-18).

This is the guide every lore batch is written from (DATA-R110, DATA-R111). Lore is every name and line of flavour Pagle invents (CONTEXT.md › Lore): it never changes what anything counts for (DATA-R109), and interface text and the game's own names are not lore. It is written for the agent drafting a batch as much as for the dev reviewing it.

Samples cite the Journal prototype, whose lines are the voice's first samples, by line: P309 is line 309 of `prototypes/fish-journal/index.html`.

## The voice

An experienced angler's field notes, written in Azeroth, light and dry. One plain observation, then at most one dry turn:

- "Stubborn on the line, sweet on the plate." (P314)
- "The head really does shine. No, it isn't mithril. Stop asking the smith." (P318)

The angler has fished everywhere, is impressed by little, and likes fish more than people. The wit comes from understatement, not from jokes.

- **Never parody.** Not of the game, its quests, its heroes or fishing addons. The hobby is taken seriously; the fish less so.
- **In-world only.** No real-world references, brands, memes, slang or internet speech, and nothing about patches, expansions or other versions of the game.
- **No words in Nat Pagle's mouth.** Never quote him, paraphrase him or claim his opinion. Pagle is named after him; it doesn't speak for him.
- **Not the addon talking.** Lore never mentions Pagle, its systems or its numbers: no XP, levels, stars, Coins, Ledger, Hunts, Notices or Sessions, and none of Pagle's capitalised terms (write "fish", "catch", "angler").
  - The one exception, approved in #184, is gone: the wagers set's note (`set.pagles_wagers.note`) called them "Pagle's own wagers" until the 1.0 sign-off (#264) made them "The house's own wagers", and the set itself left the Hunt list in #286.
  - **"Pagle Wagers"** is the name players see for Hunt Events as a whole, and it's allowed (the dev, 18 Oct 2026, [Review the Standing Hunts](https://github.com/timemir/pagle-addon/issues/286)). It reads as **Nat Pagle's wagers**, an in-world name with an in-world owner, as "the house" was. It is a name only: lore under it still never makes the addon talk ("Pagle bets you…"), and never puts words, bets or opinions in Nat Pagle's mouth.
- **No size is Pagle's own.** No line says or hints that a length is Pagle's own measure rather than the game's (the dev, 15 Oct 2026). A fish is as big as it is; lore never explains how a size was worked out.
- **Short.** A riddle, name or title is one phrase; a blurb, plaque or line one to three short sentences. Fragments are fine. No exclamation marks.
- **No "I".** The Journal's handwritten notes ("Largest I've landed", LED-R140) are the player's own, so printed lore doesn't speak as "I". "You" for a fellow angler is fine, sparingly.
- **British spelling** in invented words ("colours", "armourers"); the game's own names keep theirs ("Plated Armorfish").
- **Faction-neutral.** Every line reads the same to an Alliance and a Horde angler.

## Hard rules

The generator fails a batch that breaks these (DATA-R107; ticket #128 builds the check). Lengths count Unicode code points (Tunables › Lore limits).

| Field | Kinds | Limit |
|---|---|---|
| `riddle` | `species` | 80 |
| `blurb` | `species`, `legend` | 200 |
| `plaque` | `sub` | 100 |
| `name` | every kind's `name`: `family` in the M3 batch; goods, Hunts and sets later | 28 |
| `title` | `legend` | 32 |
| `text` | `title`, the Ledger's titles (from M4, LED-R162) | 32 |
| `text` | `line` | none (keep it under 100, like a plaque) |

Changed (M3 review): the `title` text row is added, and `name`'s 28 applies to every kind's `name`, as Tunables › Lore limits says.

- **No line breaks** in any field.
- **Only characters the game's fonts have:** ASCII, Latin-1 (é, ×, ·), the en and em dashes (– —), curly quotes (‘ ’ “ ”), the bullet (•) and the ellipsis (…). Arrows, stars, ticks and emoji draw as boxes, so the generator fails them in any lore file, whether or not its check is on (CORE-R9, DATA-R107).

  Changed (#248, 2026-10-15): curly quotes and `…` are now allowed: `/pagle dev glyphs` showed every font Pagle uses drawing them. Straight ones (`'`, `"`, `...`) stay fine too.
- **No `{` or `}`**, except `{zone}` in a key whose manifest entry allows it (DATA-R107, DATA-R108). In 1.0 that's only the `zonemaster` title, which isn't in the M3 batch.
- **Never named until caught** (LED-R124): a riddle and a shared line show only for things not yet caught, so they never name the fish, Legend or item, nor use a word from its name.

These aren't checked, but break the Journal or the game's text:

- No quote marks around a riddle: the Journal adds them (LED-R141).
- No `|`: WoW reads it as the start of an escape code.

## Each kind

Each kind below has its rules and samples. **Source** is the prototype line; "changed" marks a prototype line edited here, with the reason; "new" marks a line written for this guide. **Chars** is the length in code points.

In `data/lore/ledger.toml` each key is a table per `<kind>.<id>` (DATA-R101). Species, Legend and Sub-collection IDs are item IDs, family IDs are `families.toml`'s, and a shared line's ID is its name:

```toml
[species.6317] # Raw Loch Frenzy
blurb = "Named by dwarves, who name everything after how it behaves when you try to hold it."
riddle = "Cold highland lake water, in dwarf country."

[line.uncaughtjunk]
text = "Something odd is still out there."
```

### Species riddle (`species.<id>.riddle`, 80)

Shown on an uncaught Species' page, in quotes, above a "Read the plain hint »" link (LED-R141). The plain hint is generated from the catalogue and gives the facts (DATA-R112), so the riddle only sets the scene: a **kind** of place or time, never an exact zone, hour or skill.

- Place: a kind of water and a kind of land. "lazy rivers", "cold, rocky coasts", "dwarf country", "the lands where heroes begin", "warm southern seas".
- Time, matching the Species' windows: day "while the sun is up"; night "after the sun goes down"; summer "the warm half of the year"; winter "once the year turns cold"; the Extravaganza "while the jungle's great contest is on".
- Pools, when it's pool-associated: "schools", "a slick", "swirling".
- Each riddle stands on its own; never "the same shores as…".
- Never wrong about the kind: a fish of two continents isn't "in the far south".

| Species | Line | Chars | Source |
|---|---|---|---|
| Raw Longjaw Mud Snapper (6289) | Lazy rivers in the lands where heroes begin. | 44 | P309 |
| Raw Loch Frenzy (6317) | Cold highland lake water, in dwarf country. | 43 | P312, changed (M3 review): "a great dammed lake" pinned Loch Modan (open choice 15) |
| Raw Sunscale Salmon (13760) | Far rivers and lakes, warm or cold, while the sun is up. | 56 | P322, changed (M3 review): "Southern waters", but about half its zones in the catalogue are northern (the Plaguelands, the Hinterlands, Winterspring) |
| Raw Summer Bass (13756) | Warm shores in the warm half of the year. | 41 | P325 |
| Speckled Tastyfish (19807) | Only while the jungle's great contest is on. | 44 | P335 |
| Raw Bristle Whisker Catfish (6308) | Murky rivers on both sides of the sea. | 38 | P313, changed: named Redridge and the Barrens |
| Raw Winter Squid (13755) | Warm shores, once the year turns cold. | 38 | P326, changed: "The same shores" leaned on the Summer Bass riddle |
| Deviate Fish (6522) | Strange schools out on the dry plains, where the water itself seems unwell. | 75 | P332, changed: named the Barrens; changed (M3 review): "a cave of bad dreams" pinned the Wailing Caverns (open choice 15) |

### Species blurb (`species.<id>.blurb`, 200)

Shown on a caught Species' page, between "First landed {date} in {zone}, by {character}. {n} caught." and "Found in {zones}." (LED-R140). The page already prints where, when, how many and how big, so the blurb is about the fish itself: its looks, its temper, its table, what anglers say about it. A removed Species' page adds "No longer found in Forever's waters." itself; the blurb never mentions it.

| Species | Line | Chars | Source |
|---|---|---|---|
| Raw Longjaw Mud Snapper (6289) | It bites anything, including, once, a gnome's boot. | 51 | P309 |
| Raw Loch Frenzy (6317) | Named by dwarves, who name everything after how it behaves when you try to hold it. | 83 | P312 |
| Raw Rockscale Cod (6362) | Stubborn on the line, sweet on the plate. | 41 | P314 |
| Raw Mithril Head Trout (8365) | The head really does shine. No, it isn't mithril. Stop asking the smith. | 72 | P318 |
| Lightning Eel (13757) | Tingles. Don't lick it. | 23 | P331 |
| Raw Brilliant Smallfish (6291) | Small, bright and everywhere. Every angler's book starts here, and nobody admits how many they threw back. | 106 | P308, changed: "ledger" is the Module's name |
| Deviate Fish (6522) | Eat one at your own risk. No two anglers who did tell the same story about the hour after. | 90 | P332, changed: "Pagle accepts no liability" was the addon talking |

### Legend blurb (`legend.<id>.blurb`, 200) and title (`legend.<id>.title`, 32)

A Legend is a real, named catch (CONTEXT.md › Legend). The blurb shows only once it's caught, under "{date}, {zone}, {character}" (LED-R147), so it can be a little grander than a Species blurb, never louder. It says nothing about how to catch one. The prototype has no Legend blurbs, so all of these are new.

The title is an epithet the Angler signs with ("Signed as", LED-R77), like the working names "Old Salt" and "Line-Caster" (LED-R75): a short noun phrase, capitalised, no "the" in front. Never "Master Angler" (Forever's own title), and never plain "Angler".

| Legend | Field | Line | Chars | Source |
|---|---|---|---|---|
| Brownell's Blue Striped Racer (19803) | blurb | Most anglers only ever see its wake. This one slowed down long enough to be landed. | 83 | new |
| Keefer's Angelfish (19805) | blurb | Far too handsome for a contest table, and it seems to know it. | 62 | new |
| Dezian Queenfish (19806) | blurb | Carries itself like royalty, and fights as if it had a crown to lose. | 69 | new |
| Brownell's Blue Striped Racer (19803) | title | Racer-Chaser | 12 | P361 |
| Keefer's Angelfish (19805) | title | Keefer's Rival | 14 | P362 |
| Dezian Queenfish (19806) | title | Queen-Catcher | 13 | P363 |

### Sub-collection plaque (`sub.<id>.plaque`, 100)

Shown beside a caught junk, container or treasure item's name (LED-R144). Junk plaques are museum labels, written by a curator who has seen worse. Container and treasure plaques are about who lost it or what's left of it. A plaque never says where the item was found: the same skull comes up in many waters.

| Item | Line | Chars | Source |
|---|---|---|---|
| Old Teamster's Skull (6301) | Belonged to someone who drove wagons. Still looks like it's waiting for one. | 76 | P349 |
| Old Wagonwheel (6455) | Where the wagon went is still under investigation. | 50 | P350 |
| Acidic Slime (6456) | Please do not touch the exhibit. | 32 | P351 |
| Rusted Engineering Parts (6457) | A gnome would call this 'nearly working'. | 41 | P352 |
| Old Skull (6297) | Donated by the water. Owner unknown, and preferably staying that way. | 69 | P348, changed: "Donated by the Wetlands" claimed where it was found |
| Message in a Bottle (6307) | The ink ran long ago. The cork, to its credit, held. | 52 | new |
| Battered Chest (6356) | Someone locked it, someone sank it, and neither came back for it. | 65 | new |
| Waterlogged Crate (6352) | Packed for a dry voyage. It did not get one. | 44 | new |

### Trophy family name (`family.<id>.name`, 28)

Shown in the Trophy Room's index and as the chosen family's heading (LED-R143). It is the fish's plain name, singular, as the game's trophy items spell it ("15 Pound Mud Snapper"), so the player can match one to the other. No flourish: the family's weights are real, and so is its name.

| Family | Line | Chars | Source |
|---|---|---|---|
| 1 (Mud Snapper weights) | Mud Snapper | 11 | P340 |
| 2 (Catfish weights) | Catfish | 7 | P341 |
| 3 (Yellowtail weights) | Yellowtail | 10 | P344 |
| 4 (Redgill weights) | Redgill | 7 | P345 |
| 5 (Salmon weights) | Salmon | 6 | P342 |
| 6 (Lobster weight) | Lobster | 7 | P343 |
| 7 (Mightfish weight) | Mightfish | 9 | P346 |

### Shared lines (`line.<id>.text`)

One line each, shown in place of anything not yet caught (LED-R138, LED-R144, LED-R147). They're shared, so they never hint at which one is missing. Uncaught Legends share `uncaughtlegend`; no Legend has a riddle of its own. The first line of each pair is the prototype's, the second a new alternative for the dev to choose between.

| ID | Shown | Line | Chars | Source |
|---|---|---|---|---|
| `uncaughtlegend` | an uncaught Legend's page, under a plain silhouette | Some fish are only caught once in a long while. This page waits for one. | 72 | P656 |
| `uncaughtlegend` | | A page kept blank on purpose. Some fish are worth the wait. | 59 | new |
| `uncaughtjunk` | under "An empty plinth" in the Junk Museum | Something odd is still out there. | 33 | P508 |
| `uncaughtjunk` | | The plinth is dusted and ready. The exhibit is late. | 52 | new |
| `uncaughttreasure` | a Treasures row not yet opened | Something sealed, not yet found. | 32 | P620, changed: capitalised, with a full stop |
| `uncaughttreasure` | | Still locked, still somewhere under the water. | 46 | new |
| `unchartedwaters` | a zone Pagle has no data for, before "Every catch here is still written down…" | Uncharted waters. No map of these yet. | 38 | P643 |
| `unchartedwaters` | | Nobody has charted what bites here yet. | 39 | new |

## Dos and don'ts

| Don't | Do |
|---|---|
| Parody: "Congratulations, hero! Azeroth will sing of this fish." | Understate: "Pinches first, asks questions never." (P327) |
| Real-world references and memes: "Just keep swimming." "Pairs nicely with a Chardonnay." | Keep it in Azeroth: "Fries up better than it has any right to." (P310) |
| Words in Nat Pagle's mouth: "Nat Pagle swears this is the tastiest fish in Kalimdor." | Speak for anglers in general: "Anglers who want it learn to like the dark." (P323) |
| The addon talking: "Pagle accepts no liability for what you turn into." (P332) "Worth a star and 50 XP." | The angler talking: "Eat one at your own risk." |
| An exact zone, hour or skill in a riddle: "Coastal shallows of Feralas and the swamp." (P321) "Past skill 200, between six and nine." | A kind of place or time: "Cold, rocky coasts of the middle lands." (P314) |
| The fish's own name in its riddle: "A bass for the summer shores." | Around it: "Warm shores in the warm half of the year." (P325) |
| Restating the page: "Found in Feralas, and only by day." | Something the page can't say: "Gills like embers. Bites like it means it." (P321) |
| The game's history: "Back from the old days, and still not worth cooking." | The fish as it is now: "Looks bad, smells worse." (P334, changed: trimmed; the prototype goes on ", cooks into something a raptor would eat.") |
| A race joke in every other line. The prototype has four gnome or dwarf jokes in some sixty-five lines; that's the ceiling. | Vary the turn: the table, the weather, the angler's patience. |
| Taking a side: "The Horde can keep this one." | A line both factions read the same way: "Slippery enough to earn the name." (P310) |

## How a batch is made and reviewed

1. **Draft.** An agent drafts one Module's batch from this file into `data/lore/<lore ID>.toml`: every key the manifest and DATA-R103 need, one PR, with the regenerated `Lore.lua` committed beside it (DATA-R61). The batches are: M3, the Ledger's Species, Legends, Sub-collections, families and shared lines; M4, Core's goods and the Ledger's titles and bindings; M5, Hunts; M6, Stats' tracker frames; M7, the Tackle Board (DATA-R111).
2. **Check.** `scripts/check.sh` runs the generator, which fails on a missing, orphan, overlong, multi-line or wrongly braced field once that addon's check is on (DATA-R107). The agent fixes those before asking for review.
3. **Review.** The dev reads the batch as a PR diff, for voice: tone, the riddles' hints, anything that breaks the rules above. Edits land in the same PR.
4. **Afterwards.** Any later PR that adds a Species or item, for example from a Field report, carries its lore in the same PR, drafted from this file (DATA-R111).

The specs' working names (Timber, Ripple, Lantern Glow, Driftwood and the rest) were first drafts: each batch kept or replaced them, and the 1.0 sign-off (#264) renamed Timber to Torn Page.

## Open choices

Choices this draft made that the specs don't settle. Ticket #130 confirms or changes each.

1. **Shared lines' length.** Tunables gives `line.*.text` no limit. This guide asks for under 100, like a plaque; the check won't enforce it.
2. **One of each shared line.** Each has the prototype's line and a new one; pick one per ID.
3. **No "I" in printed lore**, so it never muddles with the player's own handwritten notes. "You" stays allowed.
4. **Nat Pagle's name.** This draft forbids quoting him but allows naming him; it could forbid the name in lore altogether.
5. **Family names are the game's plain fish names** ("Mud Snapper"), not flavour names ("The Mud Snappers", "Muddy Jaws").
6. **Legend titles are bare epithets** ("Racer-Chaser"), like the level titles; the prototype's "the Ahi-Hunter" and "of the Savage Coast" forms are out.
7. **Race jokes capped** at the prototype's rate, about one in fifteen lines.
8. **British spelling** in invented words, following CONTEXT.md and the prototype.
9. **The prototype's riddle for Darkshore Grouper** ("Only off the shore it's named for.", P333) isn't used: it pins one zone through the fish's name. Allow word-play riddles like it, or not?
10. **Edited prototype lines** (marked "changed" above): Bristle Whisker Catfish, Winter Squid and Deviate Fish riddles; Brilliant Smallfish and Deviate Fish blurbs; the Old Skull plaque; the `uncaughttreasure` line's capital and full stop. The M3 review adds the Loch Frenzy and Sunscale Salmon riddles, and marks P334 ("Looks bad, smells worse.") as trimmed.

Added after the M3 review: rules this draft makes that DATA-R110 doesn't have (11–14), how close a riddle may get (15), what the review changed here (16), and the day and night windows' overlap (17).

11. **Nothing about patches, expansions or other versions of the game** ("In-world only"). DATA-R110 forbids only real-world references and memes.
12. **Not the addon talking**: no Pagle, its systems or its capitalised terms in lore. DATA-R110 doesn't say it, and it clashes with LED-R75's working level titles "Ledgerkeeper" (level 50) and "Pagle's Peer" (level 60), which name the Ledger and Pagle, while this guide lets their batch (M4) keep the working names. Either titles are an exception, or the M4 batch renames those two.
13. **No exclamation marks.** Not in DATA-R110.
14. **Faction-neutral.** Not in DATA-R110.
15. **How close a riddle may get** (with 9). "Never an exact zone" (DATA-R110) can't hold for a Species listed in one zone: Loch Frenzy lives only in Loch Modan, so any true riddle narrows to it. The review softened the two samples that pinned a zone through a landmark, Loch Frenzy's "a great dammed lake" (Loch Modan's dam) and Deviate Fish's "a cave of bad dreams" (the Wailing Caverns), to the lines the Ledger's batch (#131) ships. Allow a landmark, or only a kind of land and water? The second M3 review softened seven more of the batch's riddles that pinned a zone through a landmark or a zone's name in plain words (Spotted Sunfish's gnolls, Whimsyfin's "red hills", Feralas Ahi's giants, Sar'theris Striker's centaur clans, Misty Reed Mahi Mahi's tall grass, Zulian Mudskunk's troll ruins, Large Raw Mightfish's drowned ruins) to a kind of land and water, and `scripts/tests/test_repo_lore.py` now fails a riddle with any of those landmark words.
16. **What the M3 review changed, and where these samples still differ from the Ledger's batch** (#131, drafted from this draft before #130).
    - Changed: Hard rules' `title` text row and `name` for every kind; the Sunscale Salmon, Loch Frenzy and Deviate Fish riddles, now the batch's lines (Loch Frenzy's in the TOML example too); the "changed: trimmed" mark on P334; choices 11–16.
    - Still different: the batch ships the new `uncaughtjunk` line (the TOML example above shows the prototype's) and the prototype's line for the other three (choice 2); its Sickly Looking Fish blurb is P334 in full; and it doesn't use P314's "Cold, rocky coasts of the middle lands." for Rockscale Cod (the Do example under Dos and don'ts, and "cold, rocky coasts" under the riddle's places), since the catalogue lists it on warm coasts too and "rocky" echoes its name.
17. **"Day" and "night" wording under-describes the windows** (#175). The day window runs 06:00–24:00 and the night window 18:00–12:00, so they overlap from 18:00 to 24:00 and from 06:00 to 12:00: a day fish also bites after dark, and a night fish in the morning. The riddle phrases above ("while the sun is up", "after the sun goes down") stay as a kind of time, but no line may say a fish bites *only* by day or *only* at night; the second M3 review dropped "only" from the Lightning Eel riddle and the Sunscale Salmon blurb, and `scripts/tests/test_repo_lore.py` fails such a line. Keep the sun-and-dark phrases, or name the long windows ("from sunrise into the late evening")?
