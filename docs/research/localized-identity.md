# Locale-independent identity for items, places and fishing pools

Research for issue #20 ("How can Pagle identify items and places independent of client language?"). Researched 2026-10-11 against Forever beta build **1.60.1.70338**, the newest on wago.tools that day, and the `forever` branch of BlizzardInterfaceResources (commit c5a49d3, 2026-10-11). Claims are tagged **[P]** for primary sources (client data, API dumps, addon or emulator source), **[S]** for secondary sources, and **[I]** for our own inference. Every [I] claim is on the confirm-in-beta list.

## Answer in brief

- **Items: use the item ID from the loot window. Never use a name.** On `LOOT_READY`/`LOOT_OPENED`, check `IsFishingLoot()` (still in the Forever API), then parse the ID from `GetLootSlotLink(slot)`. Names, icons and quality are resolved later for display with `C_Item.GetItemInfo` / `Item:ContinueOnItemLoad`. Do not parse `CHAT_MSG_LOOT`, because it is localized text.
- **Places: no API returns the player's AreaTable ID.** `C_Map.GetBestMapForUnit` returns a uiMapID, which identifies a zone only. Subzones come back only as localized strings (`GetZoneText`/`GetSubZoneText`). Pagle can still get **area IDs without per-locale data**:
  1. Ship a locale-free slice of AreaTable: `areaID → parentAreaID, mapID`.
  2. At runtime, ask the client for each area's localized name with `C_Map.GetAreaInfo(areaID)`.
  3. Build a reverse index keyed by `(instance mapID, zone text, subzone text)`.

  Questie, which already ships a Forever TOC, uses the same trick (`ZoneDB:GetAreaIdByName`). On Forever's AreaTable, that three-part key is ambiguous for only **3 of 1,373 areas**, and for **none of the 360 Classic fishing areas**.
- **Pools: key them by game-object entry ID.** After the catch, `GetLootSourceInfo(slot)` should return the pool's GameObject GUID, with the entry ID in field 6. Emulator source sends pool loot under the pool's GUID; Retail behaviour is unconfirmed. Before the cast, Retail tooltip data for world objects carries `data.id` (the idTip pattern). Established fishing addons (GatherMate2, FishingBuddy) match pools by **localized tooltip names**, which is what we want to avoid.
- **Forever uses Classic Era uiMapIDs (1411–1464), not Retail ones.** It adds six new ones: 2482 Mount Hyjal, 2521/2665 Zephras Isle, 2524 Darkspear Islands, 2548 Riverglades and 2652 Shen'dralas. Area IDs are stable: all 1,212 Era area IDs exist in Forever, and only 6 were renamed. **But Forever adds same-named duplicate areas** on other maps, such as a second "Elwynn Forest"/"Crystal Lake"/"Mirror Lake" set on map 2940 (`…Camelot`). So name matching must include the map ID, and the content pipeline needs an area-alias table.
- **Per-locale data to ship: none.** Every lookup goes from shipped IDs to client-localized strings at runtime. The one exception is display text for pools, because no API turns a GameObject ID into a name. Learn that name from the tooltip when a pool is seen and fall back to Pagle's own string. Pagle's own UI strings are normal addon localization and are out of scope here.
- **Locales:** the Forever client ships GlobalStrings for **11 locales**: enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN and zhTW. A Chinese Forever beta product (`wow_cn_beta` 1.60.1) also exists. Forever puts each ruleset on one mega-realm, so players with different client languages share a world. That is one more reason the Catch log and any shared data must hold IDs only.

## 1. Items

| Need | API (all present in Forever's API dump [P][1]) | Notes |
|---|---|---|
| Is this loot from fishing? | `IsFishingLoot()` | "Returns true if the loot window is related to fishing." Listed for Forever 1.60.1 [P][2]. FishingBuddy's Retail fork claims "Modern WoW removed IsFishingLoot()" and uses a cast timer instead [P][10]. Forever's dump still has it, so it needs a beta check. |
| Item ID per slot | `GetLootSlotLink(slot)` → `|Hitem:<id>:…|h`, or `C_Item.GetItemInfoInstant(link)` → `itemID` | `GetItemInfoInstant` "only returns info that don't require a query to the server" and always answers for valid items [P][3]. Use `GetLootSlotType(slot) == Enum.LootSlotType.Item` (1) to skip money and currency [P][1]. |
| Name, icon, quality for display | `C_Item.GetItemInfo(id)` | Returns nil until cached. Name, type and subtype are **localized** [P][4]. For uncached items use `Item:CreateFromItemID(id):ContinueOnItemLoad(fn)` [P][4], or `C_Item.RequestLoadItemDataByID` plus `ITEM_DATA_LOAD_RESULT(itemID, success)`. Since 10.0.5 the server reports `success=false` for some IDs [P][5]. |
| Forever's streamed items | — | Forever's ItemSparse has about 5,000 fewer rows than Era's. Some fishing items, such as the Artisan Fishing book, are absent from client DB2 and may be streamed (see forever-content-data.md). Whether `GetItemInfoInstant` answers for an ID that is missing from DB2 is unknown **[I]**. Loot links do not depend on it. |

How FishingBuddy does it: on `LOOT_READY` it reads `GetLootSlotLink` and `GetLootSlotInfo` and parses `item:(%d+)` from the link. The name is only a cache value [P][10, FishingBuddy.lua L1780–1830]. Its log is keyed by item ID.

**Recommendation.** The Catch record stores `itemID`, plus `quantity` and `quality`, which are locale-free. Resolve names only in UI code, asynchronously. Do not use `CHAT_MSG_LOOT` or name matching anywhere.

## 2. Places

### 2.1 What the API gives

| API | Returns | Locale-free? |
|---|---|---|
| `C_Map.GetBestMapForUnit("player")` | uiMapID | Yes, but zone-level only. Forever has 51 zone maps and **no dungeon maps** (60 UiMap rows in total) [P][6]. |
| `C_Map.GetMapInfo(uiMapID)` | name, mapType, parentMapID… | ID yes, name no |
| `GetInstanceInfo()` (8th return) | instanceID = map ID, for a continent or an instance | Yes. Patch 5.0.4 added it "allowing addons to identify the current instance/continent without relying on localized names" [P][7]. |
| `GetZoneText()`, `GetRealZoneText()`, `GetSubZoneText()`, `GetMinimapZoneText()`, `GetAreaText()` | strings | **No.** "The returned zone name is localized to the game client's language" [P][8]. `GetSubZoneText` returns "" when not in a subzone [P][8]. |
| `C_Map.GetAreaInfo(areaID)` | the area's **localized name** | Takes an ID, so it can build a reverse index [P][9]. |
| `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapID, pos)` | `areaID[]` | The **only** API that returns AreaTable IDs for a position [P][9]. It is built on WorldMapOverlay hit rectangles, and only for explored overlays. In Forever, **88 of 298 Classic fishing subzones have no overlay**, including Menethil Bay, The Savage Coast, Mirror Lake and Bladefist Bay [P][6]. Too coarse to be the primary source. |

A grep of Forever's `GlobalAPI.lua` for `AreaID|GetArea|SubZone` finds nothing else that returns an area ID [P][1]. **No API returns the player's current AreaTable ID.**

### 2.2 How established addons map runtime data to places

| Addon (Forever TOC?) | Place key it stores | How it gets there | Per-locale data shipped |
|---|---|---|---|
| **Questie** (yes, `Questie_Camelot.toc`, Interface 16001) | AreaTable IDs | `uiMapIdToAreaId` and `areaIdToUiMapId` tables generated from wago.tools CSVs [P][11]. `ZoneDB:GetAreaIdByName(name)` builds `localizedName → areaID` at runtime by looping `C_Map.GetAreaInfo(areaId)`, and keeps the lower ID when names repeat. It is "built on first use, C_Map.GetAreaInfo needs a fully loaded client". `GetAreaIdByUiMapId` falls back to matching `C_Map.GetMapInfo(uiMapId).name` against `C_Map.GetAreaInfo` [P][11, zoneDB.lua L153–191] | Zone-name translations for its own UI, such as `ZephrasIsle.lua` with 10 locales [P][11] |
| **GatherMate2** (yes, Interface 16001) | uiMapID + coordinates, via HereBeDragons | `HBD:GetPlayerZonePosition()` [P][12, Collector.lua L244–270] | Node names per locale through the WoWAce localization app (`@localization(... namespace="Nodes")@`) [P][12] |
| **HandyNotes** (yes, Interface 16001) | `dbdata[uiMapID][coord]` | uiMapID + coordinates [P][13] | None for places |
| **FishingBuddy** (r-log Retail fork, Interface 120007/120100, **no Forever TOC**) | uiMapID + **English subzone name** | `GetSubZoneText()` mapped back to English through LibBabble-SubZone's reverse lookup (`FishLib:GetBaseSubZone`) [P][10, LibFishing-1.0.lua L1838–1880] | **LibBabble-SubZone-3.0**: about 8,200 names per locale in 11 locale files (enUS 360 KB, deDE 379 KB), plus an enUS `name → areaID` map (`MapData.AreaToID`, about 8,500 rows). Last updated in rev 258, 2022 [P][10]. It has no Forever subzones. |
| **LibTourist-3.0** (bundled in FishingBuddy) | uiMapID | Builds English↔localized zone names at runtime by looping `C_Map.GetMapInfo(1..10000)`. Its comment says it "replaces the abandoned LibBabble-Zone library", with errata tables where `GetMapInfo` returns an untranslated tag [P][10, LibTourist-3.0.lua L2376–2933, L3109] | Small errata per locale |

The trend: modern libraries keep **IDs in data and ask the client for localized names at runtime**, as Questie and LibTourist do. Shipping translation tables, as LibBabble did, has been abandoned and goes stale.

### 2.3 Forever's AreaTable and UiMap, measured

Method: wago.tools DB2 CSV exports of `AreaTable`, `UiMap`, `UiMapAssignment`, `WorldMapOverlay` and `Map` for Forever 1.60.1.70338, Classic Era 1.15.9.70003 and Retail 12.1.0.69933 [P][6]. The 360 Classic fishing areas are the `fishing_loot_template` entries in the VMaNGOS `db_latest` snapshot (2026-09-28) used in forever-content-data.md.

- **uiMapIDs match Classic Era, not Retail.** All 54 Era UiMap IDs exist in Forever with the same names: Azeroth 947, zones 1411–1458, battlegrounds 1459–1461, continents 1463/1464. Retail 12.1 has none of 1411–1464. Forever adds 2482 Mount Hyjal, 2521 and 2665 Zephras Isle (two maps for map 2991), 2524 Darkspear Islands (battleground type), 2548 Riverglades and 2652 Shen'dralas [P][6].
- **uiMapID → zone area ID is one-to-one.** Each zone UiMap has exactly one `UiMapAssignment` row with a non-zero `AreaID`, for example 1429 → 12 Elwynn Forest and 2548 → 16591 Riverglades. In enUS, every zone map's name equals its area name [P][6]. That gives a 60-row table, which is optional because the name index covers it.
- **Area IDs carried over from Classic are stable.** All 1,212 Era area IDs exist in Forever. 1,206 have the same name and 6 were renamed: 616 and 16004 "Hyjal" → "Mount Hyjal", 1216 "Timbermaw Hold" → "Blackmaw Hold", 1219 "Legash" → "Legashi Encampment", 474 → "Galak Camp", and 1221 had a trailing space removed. One area moved: 2657 Valley of Bones changed parent from Desolace (405) to Shen'dralas (16651). Forever adds 161 areas, with IDs from 16144 upward [P][6]. All 360 VMaNGOS fishing area IDs exist in Forever [P][6].
- **Hierarchy is two levels.** There are 183 top-level areas and 1,189 children; 1 row is nested deeper. That matches the `GetZoneText`/`GetSubZoneText` split.
- **Name collisions, the important finding:**
  - 176 names are used by more than one area across all maps. Many are new Forever copies on **other maps**: map 2940 (`ElwynnForestCamelot`, `StormwindCityCamelot`, `BurningSteppesCamelot`) duplicates Elwynn Forest, Crystal Lake, Mirror Lake, Stone Cairn Lake, Goldshire, Stormwind City and others. There is also City of Dalaran (2959), Warsong Gulch (Winter) (2996), Ruins of Lordaeron (2999) and new instance copies of Blackrock Depths and Blackrock Spire [P][6]. Map 2940 is not in the client `Map` table, so what it is (a phased world, a starting experience?) is unknown **[I]**.
  - With the key **(mapID, zone name, subzone name)**, only **3 keys** stay ambiguous: Darkwhisper Gorge in Winterspring (2256/16005), Stormrage Barrow Dens in Moonglade (2363/16916, an "InsideWMO" copy) and City of Dalaran on map 2959 (16544/16560). **None of the 360 Classic fishing areas is ambiguous** [P][6].
  - 4 open-world fishing areas are their own top-level "zones" with no UiMap: 170 Lordamere Lake, 457 The Veiled Sea, 25 Blackrock Mountain and 1477 The Temple of Atal'Hakkar [P][6]. There, `GetBestMapForUnit` returns a neighbouring zone map. The name index handles them if `GetZoneText()` returns the lake or sea name **[I]**.

### 2.4 Recommended place resolver

```lua
-- Shipped, locale-free: areas[areaID] = { parent = parentAreaID, map = mapID }  -- from AreaTable
-- Built once, lazily after PLAYER_ENTERING_WORLD (Questie: GetAreaInfo "needs a fully loaded client")
local function key(mapID, zone, sub) return mapID .. "\31" .. zone .. "\31" .. sub end
for id, a in pairs(areas) do
  local name = C_Map.GetAreaInfo(id)
  if name then
    local zoneID = a.parent ~= 0 and a.parent or id
    local zone   = C_Map.GetAreaInfo(zoneID)
    local k = key(a.map, zone, a.parent ~= 0 and name or "")
    index[k] = index[k] and math.min(index[k], id) or id   -- keep the lowest ID, as Questie does; log the collision
  end
end
-- At catch time
local mapID = select(8, GetInstanceInfo())
local areaID = index[key(mapID, GetZoneText(), GetSubZoneText())]
            or index[key(mapID, GetZoneText(), "")]          -- subzone unknown: fall back to the zone
```

- Store `areaID`, `uiMapID` (`C_Map.GetBestMapForUnit`) and `mapID` on each Catch. All three are cheap and locale-free.
- If the lookup misses, store the zone-level area ID and count the miss under the area ID in a diagnostics table. Do not put the localized text in the Catch log. Text tagged with `GetLocale()` may go into that separate diagnostics table, so we can add missing areas later.
- The index is about 1,400 `GetAreaInfo` calls. Rebuild it per session, because names can change between builds (see the renames above). Never persist it.
- Collisions are detected at build time and logged. Another locale could in principle merge two names that are distinct in enUS **[I]**.

## 3. Fishing pools

| Approach | Locale-free? | Evidence |
|---|---|---|
| **After the catch: `GetLootSourceInfo(slot)`** → `"GameObject-0-<server>-<instance>-<zoneUID>-<entryID>-<spawnUID>"` | Yes (entry ID = field 6) | The API returns "GameObject guids for objects like ore veins and herbs" [P][14]. GUID layout [P][15]. In both emulators, the bobber hands loot to the pool when one is within range: TrinityCore calls `fishingPool->Use(player)` and `new Loot(GetMap(), GetGUID(), LOOT_FISHINGHOLE, …)` with the **pool's** GUID [P][16, GameObject.cpp L3015–3033, L3252–3263]. VMaNGOS calls `player->SendLoot(GetObjectGuid(), LOOT_FISHINGHOLE)` [P][17, L1700–1706, L1872–1879]. **Whether Blizzard's server does the same is [I]**. Open-water casts should then show the bobber's GUID instead of a pool's. |
| **Before the cast: tooltip data** via `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, …)` → `data.id` | Yes | `Enum.TooltipDataType.Object = 4` exists in Forever [P][1]. idTip (Forever TOC) reads `data.id` for type 4 as "ObjectID" [P][18, idTip.lua L54–61, L275–297]. Warcraft Wiki lists `id` on TooltipData and `GetWorldCursor` as the source for Object tooltips [P][19]. |
| Tooltip text, as GatherMate2 does: `GameTooltipTextLeft1:GetText()` and `UNIT_SPELLCAST_SENT`'s `target` name matched against per-locale node names | No | [P][12, Collector.lua L213–239, L293]. GatherMate2 now guards both with `issecretvalue` checks [P][12]. |
| Tooltip text, as FishingBuddy does: lowercase substring match against a localized `SCHOOLS` list; bobber found by a per-locale bobber name | No | [P][10, LibFishing-1.0.lua L1468–1488, L1623, L2948] |

**Recommendation.** Identify pools by **GameObject entry ID**. Ship a locale-free `poolEntryID → poolType` map, because one pool type has several entries. VMaNGOS has 24 type-25 entries for 13 types, such as Oily Blackmouth School 180582/180664/180682/180750/180900. Forever adds School of Whimsyfin 572928 (forever-content-data.md). Forever's real entry IDs must be collected in beta, because pool templates are server data and are not in client DB2. Forever's `GameObjects` DB2 has no type-25 rows [P][6].

The Catch record stores `poolEntryID`: 0 means open water, confirmed by the bobber entry, and nil means unknown. Hunts and pool-only catches key off `poolType`. For display, learn each pool's localized name from tooltip `lines[1]` the first time its `data.id` is seen, and cache it per locale. Fall back to Pagle's own string.

## 4. Forever specifics

- **Locales.** The Forever `GlobalStrings` folder has deDE, enUS, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN and zhTW [P][1]. enGB uses enUS. wago.tools lists `wow_cn_beta` 1.60.1.x builds, which means a China Forever client exists [P][6]. Questie ships Forever-only Zephras Isle translations for 10 of these locales [P][11]. Blizzard's launch post says only "launches … globally" and names no languages [S][20]. Which locales are offered at launch in each region is not confirmed. The ID strategy does not depend on it.
- **Mega-realm.** Each ruleset and region shares one realm (data-export-paths.md, §2.3), so data from players with different locales mixes in groups, guilds and any future backend.
- **Midnight restrictions.** Secret values cover unit identity in combat, auras and casts, and "addon-restricted maps such as dungeons and raids" [P][21]. `C_Map.GetAreaInfo`, `GetItemInfoInstant`, `GetRealZoneText` and `GetExploredAreaIDsAtPosition` are only `AllowedWhenUntainted` for *secret arguments* [P][9][3][8]. That does not restrict normal calls. GatherMate2 and FishingBuddy already guard tooltip text against secrets, and FishingBuddy skips bobber tooltips in combat [P][10][12]. Fishing in dungeons such as Wailing Caverns, Blackfathom Deeps or Zul'Gurub is where restrictions could bite **[I]**.

## 5. What to ship

| Data | Size | Locale-specific? |
|---|---|---|
| Item IDs per Catch category (see forever-content-data.md) | small | No |
| AreaTable slice `areaID → parentAreaID, mapID`. All 1,373 rows, or the 1,044 open-world rows plus fishable instances. | about 15–20 KB of Lua | No |
| `uiMapID → zoneAreaID` (optional cross-check, 60 rows) | tiny | No |
| `poolEntryID → poolType` (13 Classic types + Whimsyfin, entries collected in beta) | tiny | No |
| **Area alias table** `areaID → canonical areaID`, for example 16521 Crystal Lake (map 2940) → 18 | tiny | No |
| Pool display names | learned at runtime and cached | per locale, but **not shipped** |

## 6. Confirm in beta

Ideally test with an enUS client and a deDE client.

1. `IsFishingLoot()` returns true for a fishing loot window and false for mob loot on Forever.
2. `GetLootSourceInfo(slot)` while fishing:
   - in a pool, it returns a `GameObject-…` GUID whose field 6 is the pool's entry ID;
   - in open water, it returns the bobber (entry 35591 in Classic data **[I]**).
   - Check whether it is ever secret or nil.
3. Mouseover of a pool fires a tooltip post call with `data.type == 4` and `data.id` equal to the pool entry. Also capture `lines[1].leftText` and check `issecretvalue`.
4. Record Forever's real pool entry IDs per type, including Whimsyfin 572928.
5. `GetZoneText()`/`GetSubZoneText()` equal `C_Map.GetAreaInfo(id)` for the same area, in enUS **and** deDE. Check several subzones, including one in a new zone (Riverglades), and watch for case or whitespace differences.
6. `GetZoneText()` and `C_Map.GetBestMapForUnit` on Lordamere Lake and The Veiled Sea. Is the zone text the lake or sea name? Which uiMapID comes back?
7. `select(8, GetInstanceInfo())` on Eastern Kingdoms, Kalimdor, Zephras Isle and one dungeon equals the AreaTable `ContinentID`, which is 0 / 1 / 2991 / map ID.
8. What map 2940 (`ElwynnForestCamelot` etc.) is. Can players fish there, and do they ever stand in areas 16510–16524 instead of 12/9/18/92?
9. Inside a fishable dungeon: `C_Map.GetBestMapForUnit` (expected nil, since Forever has no dungeon UiMaps), zone text and whether loot APIs are restricted.
10. `C_Item.GetItemInfoInstant(id)` for an item missing from Forever's ItemSparse (for example 16082), and `ITEM_DATA_LOAD_RESULT` for it.
11. The index-build self-check reports zero collisions for fishing areas in deDE.

## 7. Consequences for other tickets

- **Beta probe (#7):** add items 1–11 above. Items 2, 3 and 5 decide the design. The probe should dump `GetLootSourceInfo` and the tooltip `data` on every fishing loot window and pool mouseover.
- **Content data pipeline (#19):**
  - key zones by AreaTable ID and pools by `poolType`, with entry IDs as members;
  - emit the AreaTable slice from wago.tools for the current Forever build;
  - maintain an **area alias table** for Forever's duplicate-name areas;
  - re-diff AreaTable each build, because of the renames and reparenting (2657 Valley of Bones).
  - VMaNGOS area IDs map 1:1 onto Forever's for all 360 fishing areas.
- **Core data model (#10):** a Catch stores `itemID`, `areaID` (resolved, zone fallback), `uiMapID`, `mapID` and `poolEntryID` (0 = open water, nil = unknown). No localized strings go into the log. A separate diagnostics table may keep unresolved `(mapID, areaID-fallback, locale, text)` rows. That refines the "uiMapID and subzone/area IDs" line in data-export-paths.md §3 item 5.

## Sources

1. BlizzardInterfaceResources, `forever` branch, commit c5a49d3 (2026-10-11): `Resources/GlobalAPI.lua`, `Events.lua`, `LuaEnum.lua`, `GlobalStrings/*.lua`. https://github.com/Ketho/BlizzardInterfaceResources/tree/forever [P]
2. Warcraft Wiki, API IsFishingLoot. https://warcraft.wiki.gg/wiki/API_IsFishingLoot [P]
3. Warcraft Wiki, API C_Item.GetItemInfoInstant. https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfoInstant [P]
4. Warcraft Wiki, API C_Item.GetItemInfo. https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo [P]
5. Warcraft Wiki, ITEM_DATA_LOAD_RESULT. https://warcraft.wiki.gg/wiki/ITEM_DATA_LOAD_RESULT [P]
6. wago.tools DB2 CSV exports: `https://wago.tools/db2/{AreaTable,UiMap,UiMapAssignment,WorldMapOverlay,Map}/csv?build=1.60.1.70338`, and the same for 1.15.9.70003 and 12.1.0.69933. Builds list: https://wago.tools/api/builds [P]
7. Warcraft Wiki, API GetInstanceInfo. https://warcraft.wiki.gg/wiki/API_GetInstanceInfo [P]
8. Warcraft Wiki, API GetSubZoneText, API GetRealZoneText and API GetAreaText. https://warcraft.wiki.gg/wiki/API_GetSubZoneText, https://warcraft.wiki.gg/wiki/API_GetRealZoneText, https://warcraft.wiki.gg/wiki/API_GetAreaText [P]
9. Warcraft Wiki, API C_Map.GetAreaInfo and API C_MapExplorationInfo.GetExploredAreaIDsAtPosition. https://warcraft.wiki.gg/wiki/API_C_Map.GetAreaInfo, https://warcraft.wiki.gg/wiki/API_C_MapExplorationInfo.GetExploredAreaIDsAtPosition [P]
10. FishingBuddy Retail fork r-log/FishingBuddy, commit fedacff (2026-08-12): `FishingBuddy.lua`, `Libs/LibFishing-1.0/LibFishing-1.0.lua`, `Libs/LibBabble-SubZone-3.0/{Core,Locale}/*`, `Libs/LibTourist-3.0/LibTourist-3.0.lua`, `FishingBuddy.toc`. https://github.com/r-log/FishingBuddy/tree/fedacff1a0a8ec336c4effd3935a6447b0b82d39 [P]
11. Questie, commit d4938d9 (2026-10-11): `Database/Zones/zoneDB.lua`, `Questie_Camelot.toc`, `Localization/Translations/Zones/ZephrasIsle.lua`, `Localization/lookups/lookupZones.lua`, `ExternalScripts(DONOTINCLUDEINRELEASE)/zone_tables/README.md`. https://github.com/Questie/Questie/blob/d4938d9a185cbc6edaab86377c77101bd333d210/Database/Zones/zoneDB.lua#L153-L191 [P]
12. GatherMate2, commit fc55711 (2026-10-03): `Collector.lua`, `Constants.lua`, `Locales/GatherMate2-deDE.lua`, `GatherMate2.toc`. https://github.com/Nevcairiel/GatherMate2/blob/fc557118fdf36bbaa3362bba82a35dea39ac89ea/Collector.lua [P]
13. HandyNotes, commit 438a547 (2026-10-02): `HandyNotes_HandyNotes.lua`, `HandyNotes.toc`. https://github.com/Nevcairiel/HandyNotes/tree/438a54761c0bbf949abd6e60cac05967f47b15e4 [P]
14. Warcraft Wiki, API GetLootSourceInfo. https://warcraft.wiki.gg/wiki/API_GetLootSourceInfo [P]
15. Warcraft Wiki, GUID. https://warcraft.wiki.gg/wiki/GUID [P]
16. TrinityCore, commit 978e4f5 (2026-10-10): `src/server/game/Entities/GameObject/GameObject.cpp`. https://github.com/TrinityCore/TrinityCore/blob/978e4f5736d289e2d7d12a6a878dacc108fd5496/src/server/game/Entities/GameObject/GameObject.cpp#L3015-L3033 [P, emulator, so it shows likely behaviour rather than Blizzard's]
17. VMaNGOS core, commit 53d24d5 (2026-10-07): `src/game/Objects/GameObject.cpp`. https://github.com/vmangos/core/blob/53d24d5c748bef5e0cde7b1155bcb3d979af614c/src/game/Objects/GameObject.cpp#L1700-L1706 [P, emulator]
18. idTip, commit 4df162c (2026-10-01): `idTip.lua`, `idTip.toc` (Interface includes 16001). https://github.com/silverwind/idTip/blob/4df162c8dc82ad0223e3da79f6dcbc4753086bd6/idTip.lua#L270-L297 [P]
19. Warcraft Wiki, Struct TooltipData. https://warcraft.wiki.gg/wiki/Struct_TooltipData [P]
20. Blizzard, "Carve a New Path with World of Warcraft: Forever", via Wowhead blue tracker. https://www.wowhead.com/forever/blue-tracker/news/eu/24302093 [S]
21. Warcraft Wiki, Secret Values. https://warcraft.wiki.gg/wiki/Secret_Values [P]
