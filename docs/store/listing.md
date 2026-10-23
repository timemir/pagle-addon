# Pagle's store listing

> Status: Draft, for the dev's review · Ticket: [#269](https://github.com/timemir/wow-fish/issues/269) · Used by: #270 (screenshots), #271 (the CurseForge and Wago projects)

The text of Pagle's CurseForge and Wago project pages, one source for both sites. Paste each part into its field as written. The description is Markdown, which both sites take.

The words follow `CONTEXT.md`'s terms, with none of its *Avoid* words, and promise nothing that isn't built for 1.0 (nothing under [roadmap.md › After 1.0](../spec/roadmap.md#after-10)). A Catch's length is described as the Journal shows it, never as Pagle's own or as anything worked out (the dev, 15 Oct). [Where each claim comes from](#where-each-claim-comes-from) maps every claim to its spec rule. When `NOTICE` changes, the licence and credits section changes with it.

## Name

```text
Pagle
```

## Summary

One line for both sites' summary fields (135 characters).

```text
Fishing progression and collection for World of Warcraft: Forever, from a Fish Journal to a cork Tackle Board. It never fishes for you.
```

## Description

````markdown
**Pagle** is a fishing addon for World of Warcraft: Forever, named after Nat Pagle and meant to be the only fishing addon you need. Progression and collection come first, with optional quality-of-life touches beside them. It watches what you catch and rewards it. It never fishes for you.

Every Cast you make is written into one log, shared by every character on your account, and everything Pagle shows is read from it. Open any of it from Pagle's entry in the addon compartment by the minimap, or with `/pagle`.

## The Fish Journal

The Ledger keeps your life as an angler in the Fish Journal, a leather-bound book of parchment pages. Every Catch earns XP toward your Angler Level, doubled by Fresh Water after a break from fishing, and at the top you can Prestige for an emblem and climb again. Each Species earns up to three stars, each zone a Zone Mastery rank from Visitor to Master, and the Junk Museum, Treasures and the Trophy Room fill in as you go.

Fish you haven't caught stay nameless. A riddle sets the scene, and a plain hint is there when you'd rather just know. Legends, the named catches you won't land on an ordinary day, arrive with a splash and a title to sign the Journal with. Your longest of each Species is kept as well, from Tiddler to Monster.

## Hunts

Hunts are the catches worth planning for: a fish that bites by night, in one season or during an event, or a catch that only counts under conditions of its own, such as a grouper by moonlight. The Hunts board, a leather notebook, lays them out on a timeline of what's biting now, what opens soon and what comes later. Each Hunt completes in bronze, some go on to silver and gold, and finishing a themed set earns its title. The board counts your Casts at each Hunt without pretending to know the odds, and the Hunts you pin follow you in a tracker under the minimap.

## Stats

Stats keeps your own numbers in the Stats book: every Session, your lifetime totals, and what bites in each water you've fished. Your odds for each fish come only from your own Casts, and always say how many Casts they rest on. A Dry spell counts the Casts since you last caught something and says plainly when the wait is unusual. Every Cast is its own roll; nothing is owed. Watch up to three Dry spells on the live tracker. Stats shows numbers when you ask, and announces nothing.

## The Tackle Board

The Tackle Board is opt-in: a cork board where three Notices go up each day and an Expedition each week, such as "4 different Species in Feralas". Fish where you like, and they fill in as you go. They never expire, so a missed day banks rather than vanishes, and each one can be taken down once for a fresh one of another kind. Each day with a goal done keeps your Campfire burning, Kindling carries it through a day you couldn't make, and your longest Campfire is kept for good. Every goal done ties a new fly in your Fly Box.

## QoL

QoL gives you a Fishing key. Bind it, and each press does the next sensible thing: put on your fishing set, apply a lure, cast, reel, or open a clam between Casts. A double right-click casts too. While you fish it can turn the music and ambience down so you hear the splash, and switch auto-loot on, and it puts your settings back when you stop. A small button shows what the next press will do, and a quiet line tells you when your lures run out. One press is one action, and QoL never acts on its own.

## Announcements, Coins and the Curio Shop

When you earn something, Pagle says so in the moment. A toast rises and writes the fish's name out in ink while its stamps come down, a banner drops its seal for a new Angler Level, and a Legend gets the whole screen. The Interruption budget keeps it from talking over your fishing, Cozy mode holds everything for the end of the Session, and the Animations setting stills the motion if you'd rather it kept still. A Session that earned something ends with a summary card.

Pagle Coins are paid for things achieved, never for sheer volume, and buy looks in the Curio Shop: toast styles, sound sets, Journal bindings, notebook covers and tracker frames. The stock never rotates, and nothing in it buys a title or a star.

## How it looks

Pagle's own windows are things an angler would keep. The Fish Journal, the Hunts board and the Stats book are leather-bound, with parchment pages, brass and wax seals. The Tackle Board is cork in a leather frame, with a Campfire whose flames flicker and pins that lift under your mouse. The Field report is a sea chart.

## Take only what you want

Pagle is one download of six addons: Pagle itself and five Modules (Ledger, Hunts, Stats, Tackle Board and QoL). Turn any Module off in the AddOns list and nothing of it loads. Pagle keeps recording your Catches either way, so a Module you turn back on catches up on everything it missed, in one card.

If Angleur or Fishing Buddy is loaded too, QoL asks which one should keep your fishing key, and turns the other off. The rest of Pagle carries on whichever you pick.

## Good to know

- Pagle runs on World of Warcraft: Forever only.
- 1.0 is in English only.
- Seen something Pagle doesn't know yet, such as a fish in new waters or outside its usual hours? Type `/pagle report` and post the Field report it gives you at https://github.com/timemir/wow-fish/issues/new?template=field-report.yml. It never names your characters.

## Licence and credits

**Pagle.** Copyright (C) 2026 the Pagle contributors.

Pagle is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See [LICENSE](https://github.com/timemir/wow-fish/blob/main/LICENSE).

**VMaNGOS.** Pagle's content data (where and when fish are caught) is derived from the VMaNGOS world database, https://github.com/vmangos/core, licensed under the GNU General Public License version 2 or later. Thanks to the VMaNGOS contributors. The snapshot used is VMaNGOS's db_latest release of 2026-09-28 (tag db_latest@4641790).

**Blizzard Entertainment.** World of Warcraft, and the game IDs and names Pagle refers to (items, areas, spells and the like), belong to Blizzard Entertainment, Inc. Pagle ships IDs only, never Blizzard's text. Pagle is not affiliated with or endorsed by Blizzard Entertainment.

Pagle also bundles libraries from Ace3, LibDeflate (zlib License) and fonts under the SIL Open Font License; [NOTICE](https://github.com/timemir/wow-fish/blob/main/NOTICE) lists them.

## Links

- Source: https://github.com/timemir/wow-fish
- Issues and Field reports: https://github.com/timemir/wow-fish/issues
````

## Categories and tags

| | CurseForge | Wago |
|---|---|---|
| Main category | Professions | Professions |
| Other categories | none | none |
| Game version | Forever | Forever |
| Licence | GNU General Public License version 3 (GPLv3); the "or later" is in the description and `NOTICE` | GPL-3.0 (the same) |
| Tags, where the site takes them | fishing, angling, collection, progression, journal, Nat Pagle, Forever | the same |

Professions is the main category because every TOC says `## Category: Professions` (CORE-R2). Forever is the only game version because every TOC loads on Forever alone (`## AllowLoadGameType: camelot`, CORE-R2, CORE-R4). Ticket #271 picks the closest match where a site names a field differently.

## Screenshot captions

Ticket #270 fills this list: one line per screenshot, its file and its caption.

## Where each claim comes from

Every claim in the description, in its order, with the rule or spec section it rests on. Paths are under `docs/spec/` unless they say otherwise.

| Claim | Rests on |
|---|---|
| A fishing addon for Forever, the only one you need; progression and collection first, optional QoL; observes and rewards, never plays for you | `CONTEXT.md` intro; README.md › Standing product rules; QOL-R5 |
| Every Cast in one log, shared by every character on the account; everything shown is read from it | `CONTEXT.md` › Angler, Catch log; LOG-R10–R18; README.md › The Catch log and projections; CORE-R5 |
| The addon compartment entry and `/pagle` | CORE-R50; LED-R120, HNT-R68, STA-R70, TKB-R1 |
| The Fish Journal, a leather-bound book of parchment pages | ledger.md › UI (the Fish Journal); LED-R120 |
| XP on every Catch, Angler Level, doubled by Fresh Water after a break | LED-R20, LED-R22, LED-R23, LED-R30 |
| Prestige at the top for an emblem, and climb again | LED-R33, LED-R34, LED-R32 |
| Up to three stars per Species | LED-R45 |
| Zone Mastery from Visitor to Master | LED-R50 |
| Junk Museum, Treasures, Trophy Room | LED-R60, LED-R61, LED-R143, LED-R144 |
| Uncaught fish stay nameless; a riddle and a plain hint | LED-R124, LED-R141 |
| Legends: a splash and a title to sign with | `CONTEXT.md` › Legend; LED-R63, LED-R75, LED-R77, LED-R97 |
| Your longest of each Species, from Tiddler to Monster | LED-R80–R82, LED-R140; `CONTEXT.md` › Size band |
| Hunts by night, season or event, or under conditions of their own (the grouper by moonlight) | `CONTEXT.md` › Natural Hunt, Imposed Hunt; HNT-R4, HNT-R5; `data/hunts/events/darkshore_moonlight.toml` (`darkshore_moonlight_grouper`) |
| The Hunts board, a leather notebook, with a timeline of now, soon and later | HNT-R40, HNT-R60, HNT-R62 |
| Completes in bronze, then silver and gold; set titles | HNT-R15, HNT-R16, HNT-R18, HNT-R20 |
| Counts your Casts without odds | HNT-R25–R27 |
| Pinned Hunts in a tracker under the minimap | HNT-R75, HNT-R76, HNT-R80; CORE-R70 |
| The Stats book: every Session, lifetime totals, each water | STA-R20–R25, STA-R30; stats.md › UI |
| Your odds only from your own Casts, with the Casts they rest on | `CONTEXT.md` › Your odds; STA-R3, STA-R43, STA-R46 |
| Dry spells, said plainly when unusual; "Every Cast is its own roll; nothing is owed." | STA-R50–R53, STA-R58 |
| Up to three watched Dry spells on the live tracker | STA-R60, STA-R61, STA-R81, STA-R82 |
| Stats announces nothing | STA-R2 |
| The Tackle Board is opt-in | TKB-R2, TKB-R5 |
| Three Notices a day, an Expedition a week; the example goal | TKB-R20, TKB-R36 |
| Fish where you like, and they fill in | TKB-R40, TKB-R107 |
| Never expire; a missed day banks | `CONTEXT.md` › Tackle Board, Notice; TKB-R20 |
| Taken down once for a fresh one of another kind | TKB-R32, TKB-R55 |
| Campfire, Kindling, the longest Campfire kept | TKB-R70–R74 |
| A fly tied for every goal done | TKB-R62 |
| The Fishing key: fishing set, lure, cast, reel, clam | QOL-R10, QOL-R20 |
| A double right-click casts | QOL-R12, QOL-R13 |
| Music and ambience down, auto-loot on, settings put back | QOL-R61–R63 |
| The next-action button; the out-of-lures line | QOL-R70–R74; QOL-R53, QOL-R75–R78 |
| One press, one action; never on its own | QOL-R5, QOL-R20 |
| Toasts rise and write the name out; stamps come down; a banner drops its seal; a Legend's splash takes the screen | announcements.md › UI, › Motion; ANN-R20 |
| Interruption budget, Cozy mode, Animations setting | ANN-R30, ANN-R31, ANN-R40, ANN-R41; announcements.md › Settings, › Motion |
| A summary card for a Session that earned something | `CONTEXT.md` › Session summary; ANN-R53 |
| Coins for things achieved, never volume | SHOP-R1 |
| Looks in the Curio Shop: toast styles, sound sets, Journal bindings, notebook covers, tracker frames | SHOP-R20, SHOP-R25, LED-R110, HNT-R120, STA-R88; tackle-board.md › Contracts |
| Stock never rotates; no titles or stars for sale | SHOP-R20, SHOP-R24 |
| The books leather-bound, with parchment, brass and wax seals | ledger.md › UI; HNT-R60; stats.md › UI |
| The cork board, its leather frame, the Campfire's flicker and the pins that lift | TKB-R100; tackle-board.md › UI (the board, Motion) |
| The Field report as a sea chart | REP-R40; field-report.md › UI |
| Six addons; a Module turned off loads nothing | CORE-R1, CORE-R17 |
| Recording continues; a Module turned back on catches up in one card | core/README.md › Purpose ("With no Module enabled, Core records silently"); LOG-R71; ANN-R60; QOL-R83 |
| Angleur or Fishing Buddy: QoL asks, and turns the other off | QOL-R80–R84 |
| Forever only | CORE-R2, CORE-R4 |
| English only in 1.0 | CORE-R8; roadmap.md › After 1.0 (translations) |
| `/pagle report`, the GitHub URL, never names your characters | REP-R1, REP-R40, REP-R46 |
| Licence, VMaNGOS and Blizzard | `NOTICE`, word for word; ADR 0006 |
