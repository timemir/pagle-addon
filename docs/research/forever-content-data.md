# Forever fishing content data: sources, shape, size, gaps

Research for issue #5 ("Where can Forever fishing content data come from?"). Researched 2026-10-11 against Forever beta build **1.60.1.70338**, the newest on wago.tools that day. Every number below was pulled or computed from a named source. Inferences are labelled as such.

## Answer in brief

- **No single source covers Forever fishing.** The Forever client's DB2 tables (via wago.tools) are authoritative for *what exists*: item IDs, names, quality, pool object IDs, spells, holidays and zones. They contain nothing about *where it is caught, when, or how often*. Loot tables, zone skill requirements and time/season gates are server-side and never ship to the client.
- **The best structured "where/when" data is a Classic baseline, not Forever data.** The VMaNGOS world database (GPL-2.0) has `fishing_loot_template` (360 area entries), `skill_fishing_base_level` (56 zones), pool loot and the day/night and season events. Wowhead's Forever zone fishing tabs are currently a verbatim copy of its Classic Looter data.
- **Forever has already changed Classic data.** It renamed fish, raised every Bloated container to uncommon, added new fish, pools, zones and camp buffs, and dropped some items from the client. Any Classic baseline must be overlaid with Forever deltas and then confirmed by in-game observation. The only source of real Forever catch data will be observation, ours or the community's.
- **Expected size for the Ledger:** about 29 regular fish species plus about 9 quest or rare fish; 36 trophy "pound" fish in 7 families; 12 Bloated containers; about 15 treasure containers; a handful of grey junk; 14 pool types. Across 56 Classic zones (360 area/subzone loot tables) plus 4 new Forever zones with unknown fishing.

## Sources, ranked by trust × Forever coverage

| # | Source | Trust | Forever coverage | What it gives | Terms |
|---|---|---|---|---|---|
| 1 | **Forever client DB2 via wago.tools** (product `wow_classic_beta`, builds 1.60.1.69876 → 1.60.1.70338) | Highest (it *is* the client) | Full for identity, **none** for loot, zone skill or conditions | Item ID, name, quality, class/subclass, stack size, description (ItemSparse, Item); spells and effect values (SpellName, Spell, SpellEffect); camp recipes (SkillLineAbility); holidays (Holidays/HolidayNames); zones and subzones (AreaTable) | Blizzard-owned game data. wago.tools publishes no terms on its front page. |
| 2 | **In-game observation** (our addon during beta and live, or community submissions) | Highest for Forever | Whatever gets observed | Real loot by zone, subzone and pool; time and season windows; Rack/Hut contents; skill thresholds | Ours |
| 3 | **VMaNGOS world DB** (`db_latest` snapshot, 2026-09-28) | Medium: emulator reconstruction of Classic 1.12 | Classic baseline only | `fishing_loot_template` (area → item, chance, condition), `skill_fishing_base_level`, `gameobject_loot_template` for pools, `game_event` for day/night and season windows | GPL-2.0 (repo license; the DB dump has no separate license statement) |
| 4 | **Wowhead Classic / Wowhead Forever** (`wowhead.com/classic/…`, `wowhead.com/forever/…`) | Medium-high for Classic rates (Looter sample counts); low for Forever loot right now | Forever *entity* pages exist and are tagged `envChange: new/changed/unchanged`. Forever zone *fishing tabs are inherited Classic data*. | Per-zone fished item counts (e.g. Stranglethorn 506,684 casts); player comments with early Forever finds | ToS page renders client-side and could not be read. Use as a manual cross-reference only; do not scrape or bulk-copy. |
| 5 | **Warcraft Wiki** | Medium | None (Retail/Classic pages) | Human-readable cross-checks (Nightfin 6 PM–6 AM; Summer Bass/Winter Squid zones). Its zone-skill page is Retail-era, flagged outdated. | CC BY-SA 4.0 |
| 6 | **foreverdb.net and Forever fan sites** (wow-professions.com, classicwowforever.com, zockify, mobalytics) | Low-medium, secondary | Partial, beta | foreverdb extracts from the client (build 70338) but labels quest data "Classic data until seen in Forever". Guides give skill ranges and the Nat Pagle quest. | No license stated |
| 7 | **Other Forever fishing addons** (Fishing's Fun, The Fishing Log, Zone Level: Forever) | Low (unknown method) | Crowdsourced, beta | Zone/fish logs, zone skill display | Unknown |

## What the Forever client data actually shows (build 1.60.1.70338)

Method: download DB2 CSVs from `https://wago.tools/db2/<Table>/csv?build=<build>` for Forever (1.60.1.70338) and Classic Era (1.15.9.70003), then diff them.

### Forever has already edited Classic fishing items
| Item ID | Classic Era name | Forever name | Other change |
|---|---|---|---|
| 13876–13880 | 40/47/53/59/68 Pound Grouper | 40/47/53/59/68 Pound **Yellowtail** | — |
| 13755 | Winter Squid | Raw Winter Squid | — |
| 13890 | Plated Armorfish (quest item) | **Raw** Plated Armorfish | New cooked item *Plated Armorfish* 286152 and *Recipe: Plated Armorfish* 286153, so it is now a cooking fish |
| 6643, 6645, 6647, 8366, 13881, 13891, 21162, 21163, 21164, 21243 | Bloated Smallfish/Mud Snapper/Catfish/Trout/Redgill/Salmon/Oily Blackmouth/Firefin/Rockscale Cod/Mightfish | Full fish names (e.g. "Bloated Bristle Whisker Catfish") | Quality **1 → 2 (uncommon)**, stack 20 → 1 |
| 6644, 6646 | Bloated Mackerel, Bloated Albacore | unchanged | still quality 1, stack 20 |

### New fishing content in Forever DB2
- **Whimsyfin** 251524 (Trade Goods 7/11, quality 1). Pool object **School of Whimsyfin** 572928 (type 25, Wowhead status `new`). *Savory Whimsyfin Delight* 251525 and its recipe 251526. Spell 1252566.
- **Camp crafting** ("Bait and Tackle", spell 1278067, on Fishing skill line 356): Fish Bowl (Tier 1), Fishing Rack (Tier 2), Fishing Hut (Tier 3). Items 279967/279965/279966; blueprints 273141 (Rack) and 273119 (Hut).
  - Rack tooltip (spell 1307247): "grants the ability to catch uncommon fish for $d, provides Fishing Skill lures". Aura 1280341 *Uncommon Fishing*: "Additional rewards while fishing".
  - Hut tooltip (spell 1307246): "grants the ability to catch rare fish". Aura 1280342 *Rare Fishing*: "Greater additional rewards while fishing".
  - Both auras are dummy auras (SpellEffect aura 4), so **what they unlock is server-side and not in client data.** Inference, not verified: the uncommon tier may be the newly uncommon Bloated containers.
- **Luremaster** (Legacy perk, spell 1225455): "While fishing with a Lure active, you have a $s1% chance to catch an extra fish", where SpellEffect base points = **50**. The baseline research (citing a fan site) says 25%. Build 70338 says 50%, which matches a Blizzard forum player report.
- **Fishing Hat Lure** 1265220: "+25 Fishing for 10 min" (the free-lure hat).
- **Prepare Fish** 1292332 ("Use on unique fish to prepare them in a special way") sits on **Chef's Knife** 273636. Its ItemSparse row carries 275/356, read as Fishing 275; this column reading is an inference. Related item: **Seasonal Fish Steaks** 273295 ("A refreshing preparation of seasonal fish"). The client does not say which fish count as "unique".
- **Stranglethorn Fishing Extravaganza**: Holidays ID 301, duration 2 h. *Extravagant Extravaganza Coin* 274026 ("Exchange for a prize of your choosing"), *Master Angler!* aura 1299323 (title while it lasts), *Bitter Baitling* 276275, *Master Angler's Fishing Hat* 276272, *Empty Fish Bucket* 276273, *Snacking on Tastyfish* 1299291. No other fishing holidays are in Forever's Holidays table.
- **Other fishing-flavoured items:** Primitive Fishing Pole 276203, Wide-Brimmed Fishing Hat 259846, Enchant Gloves - Fishing 273495. *Fishing Trip* 274800 ("invitation to a fishing challenge") starts quest 96561. Possible quest items: Lucky Lure 258530, Fresh Chum 271657, Naga Spinefin 286008, Half-Eaten Fish 286205, Sack of Fish 280426.
- **Fishing ranks:** the Classic rank spells 7620/7731/7732/18248 are present. The skill line also has new rank spells 1240948/1240959/1240970/1240983 (Apprentice → Artisan).
- **Not found by name** in build 70338: anything matching "Tackle Box", lava fishing or a lava rod. The baseline lists these as unverified, and they remain so.

### Absent from Forever ItemSparse (present in Era)
Artisan Fishing - The Way of the Lure 16082, Rockhide Strongfish 19808, Darkwood Fishing Pole 6366, The 1 Ring 8350, Nat Pagle's Fish Terminator / Broken Reel (19944/19947 and Season-of-Discovery copies), Fish Scale 6987. **Caveat:** Forever's ItemSparse has 19,248 rows against Era's 24,442. Retail-style clients can stream item records from the server, so absence from DB2 is *not* proof of removal. About 90 of the 259 items in the VMaNGOS fishing and pool loot, mostly world-drop greens, are missing the same way.

### New Forever zones (AreaTable diff vs Era)
New: **Riverglades**, **Shen'dralas**, **Ruins of Gilneas / Gilneas** and new **Mount Hyjal** subzones (Elderwild, Summit of Eternity, Shrine of Aviana, …). Plus new subzones inside old zones, including fishing-relevant names such as *Hayward Fishery* (Gilneas), *Shark-Infested Waters*, *The Forbidding Sea* (Riverglades) and *Stormwind Harbor*. No source has fishing data for any of them.

## The Classic baseline (VMaNGOS world DB, snapshot 2026-09-28)

- **Areas:** `fishing_loot_template` has **360 area entries** (zones *and* subzones) with 2,484 rows. `skill_fishing_base_level` has **56 zone entries** covering the vanilla zones, capitals and fishable instances. Values are base levels, from −70 (starter zones) to 330 (endgame). Warcraft Wiki's Retail-era "skill for 100% fish (no junk)" column equals base + 95: Duskwood 55 → 150, Stranglethorn 130 → 225. Warcraft Wiki lists 57 vanilla zone/instance names, which is consistent.
- **Items:** 252 distinct items in zone fishing loot, including reference tables. Pools add 7 more (259 total), and only about 100 of those matter for a collection. The rest are world-drop greens, potions and recipes that turn up rarely.
- **Pools** (`gameobject_template` type 25): Floating Debris, Floating Wreckage, Oil Spill, Oily Blackmouth School, Firefin Snapper School, Sagefish School, Greater Sagefish School, School of Deviate Fish, Stonescale Eel Swarm, School of Tastyfish, Patch of Elemental Water, School of Fish, Muddy Churning Waters (ZG). That is 13, plus Forever's School of Whimsyfin = **14**. Pool-only catches are Speckled Tastyfish, Brownell's Blue Striped Racer, Keefer's Angelfish, Dezian Queenfish, Zulian Mudskunk and Bloated Whitescale Salmon.
- **Condition-gated catches** (condition → game_event):

| Item | Gate in VMaNGOS | Areas | Classic reference |
|---|---|---|---|
| Raw Nightfin Snapper 13759 | event 48 "Nightfin Cycle", daily from 18:00, 18 h long | 71 | Warcraft Wiki: "between the times of 6 PM and 6 AM", best 12–6 AM |
| Raw Sunscale Salmon 13760 | event 47 "Sunscale Cycle", daily from 06:00, 18 h long | 73 | day counterpart |
| Lightning Eel 13757 | event 47 (day cycle) | 67 | not stated elsewhere; verify |
| Raw Plated Armorfish 13890 | event 48 (night cycle) | 22 | not stated elsewhere; verify |
| Raw Summer Bass 13756 | event 45, yearly from 20 Mar, 182.5 days | 27 | Warcraft Wiki: spring and summer, coastal Blasted Lands, Swamp of Sorrows, Badlands, EPL, Tanaris, Thousand Needles |
| Raw Winter Squid 13755 | event 46, yearly from 23 Sep, 182.5 days | 27 | Warcraft Wiki: winter, same zones |
| Speckled Tastyfish + 3 rare fish | School of Tastyfish pools during Extravaganza (events 14/15/40; tournament Sundays 14:00, 120 min) | STV | Forever Holidays 301 also lasts 2 h; foreverdb shows Sundays 14:00 realm time |

  The overlapping 18-hour windows are the emulator's approximation. Real Forever windows must be observed.

## Expected counts for the Ledger (Classic baseline plus known Forever deltas)

| Category | Count | Members (item IDs in the research data) |
|---|---|---|
| Regular fish species | **~29** | 18 Trade Goods/Meat raw fish (Smallfish, Mackerel, Mud Snapper, Loch Frenzy, Albacore, Catfish, Rockscale Cod, Mithril Head Trout, Spotted Yellowtail, Glossy Mightfish, Redgill, Nightfin, Sunscale, Whitescale Salmon, Summer Bass, Darkclaw Lobster, Sagefish, Greater Sagefish); 4 Trade Goods/Other fish (Oily Blackmouth, Firefin Snapper, Lightning Eel, Stonescale Eel); Winter Squid, Large Raw Mightfish, Deviate Fish, Darkshore Grouper, Sickly Looking Fish; Speckled Tastyfish; **Whimsyfin** (new) |
| Quest and rare fish | **~9–10** | Raw Plated Armorfish (now cookable), Spotted Sunfish (Redridge quest), Nat Pagle's 4 (Feralas Ahi, Sar'theris Striker, Savage Coast Blue Sailfin, Misty Reed Mahi Mahi), Riggle's 3 (Brownell's Blue Striped Racer, Keefer's Angelfish, Dezian Queenfish); plus Forever unknowns (Naga Spinefin?, Half-Eaten Fish?) |
| Trophy "pound" fish | **36 items, 7 families** | Mud Snapper 3, Catfish 5, Salmon 6, Lobster 7, Yellowtail (ex-Grouper) 5, Redgill 6, Mightfish 4. Only ~20 are direct zone catches in VMaNGOS; the rest presumably come from containers (unverified). Weight is in the name. |
| Bloated containers | **12** | 10 now uncommon in Forever |
| Treasure | **~15** | 4 crates, 6 chests, 4 trunks, Message in a Bottle |
| Junk (grey) | **~5** | Old Skull, Old Teamster's Skull, Old Wagonwheel, Acidic Slime, Rusted Engineering Parts |
| Other | — | Big-mouth Clam, Stranglekelp, 3 Rumsey Rums, water elementals (3) + Essence of Fire, ~11 potions, ~21 recipes, ~120 world-drop greens |
| Pool types | **14** | 13 Classic + School of Whimsyfin |
| Zones | **56 Classic + 4 new** | 360 area/subzone loot tables in the baseline |
| Condition-gated | **6 + event** | Nightfin, Sunscale (day/night); Summer Bass, Winter Squid (season); Lightning Eel, Plated Armorfish (cycle per VMaNGOS, unverified); Tastyfish + 3 rare fish (Extravaganza); Rack "uncommon" and Hut "rare" tiers (contents unknown) |

## Shape of the data we can build

Join three layers on item ID and area ID. Ship IDs and resolve names, icons and quality at runtime with `C_Item.GetItemInfo`, so localisation comes free and Blizzard text isn't redistributed.

- **Catch** (species record): `itemID`, `category` (fish / quest fish / trophy / container / treasure / junk / event / other), `family` (trophy family and parsed weight), `quality` (DB2), `isNewInForever` / `changedInForever` (DB2 diff), `pools[]` (object IDs), `conditions[]` (`time: day|night`, `season: summer|winter`, `holiday: 301`, `campBuff: rack|hut`, `poolOnly`), `provenance` (`db2@build`, `vmangos@snapshot`, `observed@build`, `confidence`).
- **Zone**: `areaID` (AreaTable), `parentAreaID`, `skillBase` and derived `noJunkSkill` (= base + 95 in the Classic baseline), `catches[]` with optional `rate` and `sampleSize`, `pools[]`.
- **Pool**: `objectID`, `name`, `catches[]`.
- Note: loot is keyed by **area ID**. At runtime the addon gets subzone text and a `uiMapID`, not an area ID. A runtime area-ID mapping (or name matching per locale) is needed. That is a feasibility question for the API ticket, not a data question.

## Gaps that need beta or live observation

1. **Forever loot tables per zone and subzone.** No source has them. Wowhead's Forever zone tabs equal the Classic numbers (Stranglethorn 506,684 casts, Redridge 39,438 casts on both `/classic/` and `/forever/`), and Whimsyfin is missing from Forever Redridge's tab.
2. **What the Fishing Rack ("uncommon fish") and Fishing Hut ("rare fish") unlock**, and whether the uncommon tier is the Bloated containers.
3. **Whimsyfin:** so far only seen at School of Whimsyfin pools east of Lake Everstill, Redridge (Wowhead comments: ~150 skill for no fails, 10 spawn points, 2 active). Open water and other zones are unknown.
4. **Fishing in the 4 new zones** (Riverglades, Shen'dralas, Gilneas, Mount Hyjal) and new subzones (Hayward Fishery, Shark-Infested Waters): skill and catches.
5. **Exact Forever windows** for Nightfin/Sunscale and Summer Bass/Winter Squid, and whether Lightning Eel and Plated Armorfish are really gated. #175 kept the 18-hour cycles in the table above (day 06:00–24:00, night 18:00–12:00, overlapping 06–12 and 18–24) in `data/forever/windows.toml`, both unconfirmed until observed catches settle them.
6. **Zone skill gates.** A forum player says "zones may require a minimum level to fish in them". Is that a hard minimum (vanilla-style) or a junk curve? Do Classic base levels hold?
7. **Extravaganza** loot, rare fish and the 50-winner rule. It needs level 60, above the beta cap, so it is untested (foreverdb).
8. **"Unique fish" for Prepare Fish/Chef's Knife** and what feeds Seasonal Fish Steaks.
9. **Items missing from DB2** (Artisan Fishing book, Rockhide Strongfish, Darkwood pole): are they removed or just streamed?
10. Lava fishing, Tackle Box and fishing dailies: nothing in DB2 yet.

## Licensing and attribution for shipping derived data

- **Blizzard data** (IDs, names): addons routinely ship IDs and names under the UI Add-On Development Policy (free, no ads). Prefer shipping IDs and resolving text at runtime.
- **VMaNGOS** is GPL-2.0 (CMaNGOS classic-db is GPL-3.0). Copying its tables, especially chance values, verbatim into the addon is safest only if the addon is GPL-compatible. Otherwise use it as a research seed and ship our own observed catalogue. Not legal advice; decide this in the packaging/licence ticket.
- **Warcraft Wiki** text is CC BY-SA 4.0: attribution and share-alike apply to copied text. Facts can be restated.
- **Wowhead:** the ToS could not be read (client-rendered). Do not scrape. Use it for manual cross-checks and leads.
- **foreverdb.net and fan sites:** no license stated. Use as leads only.

## Sources

- wago.tools builds API: https://wago.tools/api/builds (Forever builds under `wow_classic_beta` and `wow_cn_beta`, 1.60.1.x)
- wago.tools DB2 CSV exports, build 1.60.1.70338 and 1.15.9.70003: `https://wago.tools/db2/{ItemSparse,Item,ItemEffect,ItemXItemEffect,SpellName,Spell,SpellEffect,SkillLine,SkillLineAbility,Holidays,HolidayNames,AreaTable,GameObjects}/csv?build=…`
- VMaNGOS core (GPL-2.0) and `db_latest` snapshot 2026-09-28: https://github.com/vmangos/core, https://github.com/vmangos/core/releases/tag/db_latest
- CMaNGOS classic-db license (GPL-3.0): https://github.com/cmangos/classic-db
- Wowhead Forever: https://www.wowhead.com/forever/item=251524/whimsyfin, https://www.wowhead.com/forever/zone=44/redridge-mountains, https://www.wowhead.com/forever/zone=33/stranglethorn-vale, https://www.wowhead.com/forever/objects/fishing-pools
- Wowhead Classic: https://www.wowhead.com/classic/zone=33/stranglethorn-vale, https://www.wowhead.com/classic/zone=44/redridge-mountains
- Warcraft Wiki: https://warcraft.wiki.gg/wiki/Fishing_skill_requirements_by_zone, https://warcraft.wiki.gg/wiki/Raw_Nightfin_Snapper, https://warcraft.wiki.gg/wiki/Raw_Summer_Bass, https://warcraft.wiki.gg/wiki/Warcraft_Wiki:Copyrights
- foreverdb.net: https://foreverdb.net/events/stranglethorn-fishing-extravaganza
- Blizzard forum, "Fishing in WoW: Forever" (Qerach, 2026-10-04): https://us.forums.blizzard.com/en/wow/t/fishing-in-wow-forever/2371569
- wow-professions.com Forever fishing guide: https://www.wow-professions.com/forever/fishing-leveling-guide
- Icy Veins on Whimsyfin: https://www.icy-veins.com/wow-forever/news/wow-forever-just-gave-us-an-ogre-and-murloc-version-of-savory-deviate-delight/
