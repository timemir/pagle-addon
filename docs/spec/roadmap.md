# Roadmap

> Status: Done · Milestones: M0–M8, Track Q · Sources: [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652) (its body holds the launch re-verification list), [Choose the toolchain and libraries](https://github.com/timemir/wow-fish/issues/8#issuecomment-6112249259), [Write the QoL spec](https://github.com/timemir/wow-fish/issues/37#issuecomment-6130705093), [Beta probe: which fishing signals can the Forever client see?](https://github.com/timemir/wow-fish/issues/7#issuecomment-6110508010), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372), [Define the QoL feature set](https://github.com/timemir/wow-fish/issues/16#issuecomment-6113508077), [Design the Tackle Board](https://github.com/timemir/wow-fish/issues/25#issuecomment-6124911363), [Write the Tackle Board spec](https://github.com/timemir/wow-fish/issues/43), [Write the Stats spec](https://github.com/timemir/wow-fish/issues/42), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Move the prototypes to main](https://github.com/timemir/wow-fish/issues/36#issuecomment-6129511014), [Write the Settings spec](https://github.com/timemir/wow-fish/issues/44); ADR 0003, 0005 (notes: compatibility starts at 1.0)

This file sets the order in which Pagle is built. It assigns spec rules to milestones; the rules themselves live in the other spec files. Terms are used as `CONTEXT.md` defines them.

## How the roadmap works

- **Nothing is published before 1.0.** 1.0 means every Module is implemented (Core, QoL, Ledger, Hunts, Stats, Tackle Board) and M8 is done. There are no target dates: work continues straight through, and scope is cut rather than quality.
- **No backward compatibility before 1.0.** The log format, every `PagleDB` / `Pagle<Module>DB` shape, Module state and Hunt definitions change freely; a dev log whose format is outdated is replaced by a new one (LOG-R18). The freezes start at 1.0: LOG-R17, CORE-R15, DATA-R73, DATA-R95.
- **One version for the whole package, and no git tags before 1.0.** The packager publishes only on a tag push, so nothing reaches CurseForge or Wago by accident.
- **Milestones.** Each milestone below is one GitHub Milestone with the same name. Every build ticket belongs to exactly one. Milestones set the order of work, not dates: the riskiest and most shared Core pieces come first, and leaf work runs in parallel. **Track Q** runs in parallel from the end of M1.
- **Rules per milestone.** A rule listed under a milestone is built in it. A rule listed "for" or "without" something is built only in that part; the rest of it is listed where it lands. M0, M1 and Track Q are listed in full. M2–M8 are one-line scope notes for now: each later spec PR adds its own rule list to the milestones it covers. Until then, the Milestones line in each spec file's header says what that file contributes to each milestone.
- **Rules that name later features.** A rule listed in full is built for what exists in its milestone; the parts that name a later feature (a Curio Shop row in CORE-R33, the next-action button in QOL-R93, a rebuild in LOG-R18) take effect when that feature lands, without being listed again. Edge-case rules (the "Edge cases" block of each file) are listed where their main feature lands and hold from then on.
- **Exit checks.** A milestone is done when its tickets are closed and its exit check passes in the game. Exit checks run on the Forever beta until it launches (Nov 4, 2026), and on the live build after that.

## M0 Foundation

**Goal:** an empty Core that loads on Forever, behind the one check gate every later ticket must pass. Nothing is published.

**Rules:**
- CORE-R1 for the `addons/Pagle/` folder and the `.pkgmeta` (each Module's folder and `move-folders` entry arrive with that Module's first milestone)
- CORE-R2, CORE-R4, CORE-R6, CORE-R7, CORE-R8
- CORE-R15 (`Pagle.API_VERSION` is `1` before 1.0)
- DATA-R1 (`LICENSE` and `NOTICE`)

**Toolchain** (no spec file owns it; [Choose the toolchain and libraries](https://github.com/timemir/wow-fish/issues/8#issuecomment-6112249259) has the decisions):
- Plain Lua 5.1 with LuaCATS annotations. Core's public API and every domain type are fully annotated.
- The repo layout: `addons/<Addon>/` for code, `spec/` for busted tests mirroring it.
- `.luarc.json` (Lua 5.1 runtime, library paths for the vendored Ace3 and `types/`), and `types/` with `---@meta` stubs for Forever-only APIs that Ketho's annotations lack. No editor-specific files.
- The vendored libraries of CORE-R6, at a recorded Ace3 commit, updated only by a script.
- `scripts/check.sh`, which runs, in this order:
  1. format: `stylua --check`, StyLua defaults (tabs, 120 columns), Lua 5.1 syntax
  2. lint: luacheck with `std = "lua51"`, the per-path `std` of CORE-R7, and a hand-kept `read_globals` list in which each WoW API is added on purpose. That list is the inventory of WoW APIs Pagle uses, and M8 re-checks it.
  3. API presence: a script fails if any `read_globals` entry is missing from the pinned Ketho BlizzardInterfaceResources `forever` dump
  4. types: `lua-language-server --check` with zero warnings, against Ketho's `vscode-wow-api` annotations at a pinned commit. Each suppression is an inline `---@diagnostic disable-next-line: <code>` with a reason.
  5. tests: busted on real Lua 5.1 (not LuaJIT). The busted helper loads each addon's files from its real `.toc`, in order, with a shared `ns`, so TOC and load-order mistakes fail tests. luacov reports coverage and doesn't gate.
  6. from M1, the generator's check and tests (DATA-R61)
- Tool versions are pinned in one place and installed by a setup script. `check.sh` runs locally in WSL.
- GitHub Actions (Ubuntu, Lua 5.1) runs `check.sh` on every push and pull request.
- A release workflow runs `BigWigsMods/packager@v2` on a tag push, uploading to CurseForge and Wago (never WoWInterface). `.pkgmeta` has `package-as: Pagle`. The project IDs and upload secrets are added in M8.
- A PowerShell dev-loop script junctions (`mklink /J`) each `addons/*` folder into the beta's `Interface/AddOns/`, so edits go live after `/reload`.

**Exit check:**
1. `scripts/check.sh` passes in WSL and in GitHub Actions on `main`.
2. A local packager run with uploads off builds one zip holding the `Pagle` folder.
3. In the game, with the folder junctioned in: the AddOns list shows Pagle under Professions, the game loads it, and no Lua error appears (BugSack installed). `/dump Pagle.API_VERSION` prints `1`.

## M1 Dogfood

**Goal:** the MVP slice. Core records every Cast to the Catch log, and QoL's Fishing key casts and reels. The dev fishes with Pagle from here on, so the log fills with real data to build the later milestones against. With no other Module installed, Core shows nothing but its Settings root and records silently.

**Core rules:**
- CORE-R3, CORE-R5, CORE-R10–R14, CORE-R16–R23, CORE-R30–R33
- CORE-R40 without the "Help chart the waters" button (M3). Core's saving option is the LOG-R86 reminder; the length unit (LOG-R69) comes in M4. Only the Fishing page has rows in M1, so it's the only topic page registered (CORE-R42).
- CORE-R41–R44
- CORE-R50 with only the Module entries and "Settings" (the Curio Shop entry comes in M2, "Help chart the waters" in M3), and CORE-R52. Until QoL's Input entry and `/pagle qol` arrive (Track Q step 3), CORE-R52 and the Module part of CORE-R62 are exercised by tests only.
- CORE-R60–R62. `shop` and `report` are reserved from M1; until their surfaces exist (M4, M3) each prints the help list, as an unknown subcommand does.
- CORE-R82–R86
- LOG-R1 steps 1, 2 and 4 (step 3, the projections, comes in M2)
- LOG-R2–R8
- LOG-R9 without steps 3 and 4 (Session events and projections come in M2)
- LOG-R10–R15
- LOG-R16 for the kinds M1 writes: `C1`, `S1` and `B1` (each other kind comes with its writer: `A1` with Module records, `P1` with Prestige, `U1` with the Curio Shop)
- LOG-R18, LOG-R20–R23, LOG-R25–R27, LOG-R30–R32, LOG-R36
- LOG-R42 for `Pagle.IterateCatches` (`M:IterateCatches` comes with Module records), LOG-R43. Records carry no `session` tag until Sessions arrive in M2 (LOG-R98).
- LOG-R45–R49 (the conditions snapshot, the condition spec, and the realm date of a Cast that `MatchesConditions` derives)
- LOG-R55–R57 for the catalogue LOG-R57 allows: no items, pools or windows yet
- LOG-R80–R82, LOG-R85, LOG-R86, LOG-R93, LOG-R94, LOG-R96, LOG-R97

**Content data rules:**
- DATA-R2–R6, DATA-R9, DATA-R13
- DATA-R8 for the baseline, `data/forever/` and `data/db2/` layers (`data/observed/` comes in M3)
- DATA-R10 for `aliases.toml`, `events.toml` and `lists.toml`
- DATA-R11 and DATA-R12 for `build.toml` and `areas.csv` (`items.csv` comes with items in M2)
- DATA-R25
- DATA-R32, where an area's "catch list" means its rows in the baseline's `area_loot.csv` until catch lists exist (DATA-R26, M2)
- DATA-R38 for the event list; its `event.301` window waits for M2, since DATA-R79 keeps `windows` empty
- DATA-R39
- DATA-R60 with no flag, `--check` and `--propose-aliases` (each other mode comes with the rule it serves), DATA-R61, DATA-R62
- DATA-R63 for the baseline hash, `why`, aliases, and TOML keys and types; DATA-R64 for uncommitted alias proposals
- DATA-R70, for the `fingerprint` field DATA-R79 requires (nothing reads it until the projections in M2)
- DATA-R75 and DATA-R76 for `Catalogue.lua`, DATA-R79, DATA-R80

**QoL rules:**
- QOL-R1 without the Swap gear binding, which comes with Track Q step 2
- QOL-R2 without its `menu` and `slash` entries, which come with Input in Track Q (QOL-R16, QOL-R17)
- QOL-R3–R6, QOL-R10, QOL-R11
- QOL-R20 steps 1, 2 and 6 (nothing, reel, cast)
- QOL-R21, QOL-R22
- QOL-R23 without its gear and clam parts
- QOL-R24 for the cast, reel and nothing rows, Fishing key column
- QOL-R25, QOL-R26, QOL-R28 (the loot guard)
- QOL-R30–R34
- QOL-R61, QOL-R62 for the soft-interact row only, QOL-R63, QOL-R64, QOL-R66, QOL-R67
- QOL-R80–R84 (the conflict popup), QOL-R90–R98
- Settings: the Casting header and the Fishing key row on the Fishing page

**Settings rules:**
- SET-R1–R5; SET-R10 without its Help chart the waters (M3) and Units (M4) sections; SET-R11 for QoL's button; SET-R12, SET-R13
- SET-R20 for the Casting header and the Fishing key row; SET-R21
- SET-R60–R62, SET-R70, SET-R75, SET-R90–R96

Input isn't built yet, so the Fishing key is always armed (as under *Both*), and there is no double-click.

**Exit check** (on the beta, or live once Forever launches):
1. **Fishing spell (DATA-R39, QOL-R22, QOL-R24) first:** with `/etrace` open, cast once and note the spell ID `UNIT_SPELLCAST_CHANNEL_START` reports. If it isn't on the fishing-spell list, correct the list before the other steps, or no Cast is seen. Check that `C_Spell.GetSpellName(7620)` matches the channel's name.
2. With only Pagle and Pagle_QoL enabled and the Fishing key bound, fish for 30 minutes using only that key to cast and reel. Count every Cast that ends caught or got away, and include at least one interrupted Cast (move during the channel) and one press while a loot window is open, with the game's auto-loot off for that Cast (the press must do nothing, QOL-R28).
3. `/reload`, then log out and read `PagleLog`: the number of `C1` entries equals the count, each Cast is there once, the zones fished have non-zero zone areaIDs, a `B1` and an `S1` entry exist, and `PagleDB.global.decodeErrors` is 0.
4. **Got away (LOG-R6):** at least one counted Cast ended got away and was logged with outcome `g`. If Forever reports it differently, LOG-R6 is updated.
5. **Combat (QOL-R31, QOL-R32):** get into combat mid-stretch. The key does nothing and `SoftTargetInteract` is back to the player's value; after combat the key casts again.
6. **Crash (QOL-R67):** mid-stretch, kill the client from the task manager, log in, and read the leased CVars. The dev records the result on the build ticket that holds QOL-R67; if the CVars stayed changed, a follow-up ticket designs a fix.
7. **Conflict popup (QOL-R80–R84):** enable Angleur's Forever build and log in. The popup appears; "Use Pagle" turns Angleur off, and after `/reload` the Fishing key works.
8. **QoL off (CORE-R17):** disable Pagle_QoL and fish a few Casts. They're still recorded, and the Fishing page and the QoL bindings are gone.

## Track Q: QoL v1

**Goal:** the rest of QoL v1, one feature at a time, in parallel with M2 onward. Each step is its own build ticket and ships in this order; clams come last because they need launch re-verification.

| Step | Rules | Settings rows (Fishing page) | In-game check |
|---|---|---|---|
| 1. Lures | QOL-R20 step 4, QOL-R24 "apply a lure" row (Fishing key column), QOL-R27, QOL-R29 (its lure parts), QOL-R50–R54, QOL-R75, QOL-R76, QOL-R78 | Lures and clams header, Lures, ↳ Lure | With no lure on and Shiny Baubles in the bags, a press applies one, the next casts. With the last bauble gone, the out-of-lures Nudge shows once. |
| 2. Gear and swap-back | QOL-R1's Swap gear binding, QOL-R20 step 3, QOL-R23 (its gear part), QOL-R24 "equip the fishing set" row, QOL-R29 (its gear part), QOL-R40–R47, QOL-R77 | Gear header, Fishing set, ↳ Save what I'm wearing as my fishing set, ↳ Swap gear | With no pole in hand, a press puts on the fishing set and *Pagle Previous* holds the old gear. After a Cast, mounting shows the swap-back Nudge; Swap gear swaps back. |
| 3. Double-click and Input | QOL-R2's `menu` and `slash` entries, QOL-R12–R18, QOL-R24 `BUTTON2` column; QOL-R105 is checked first | Cast with (the Fishing key row now hangs under it) | QOL-R105 at `ActionButtonUseKeyDown` 1 and 0. A double right-click on the world casts, the next one reels; a right-drag turns the camera. The compartment entry cycles Input. |
| 4. Audio mix and auto-loot leases | QOL-R62 for the audio mix, background and auto-loot rows, QOL-R65 | While you fish header, Fishing audio mix, ↳ Keep sound when the game is in the background, Auto-loot while fishing | During a stretch music is muted and loot is taken automatically; 60 s after the last Cast ends, both are back to the player's values. |
| 5. Next-action button | QOL-R70–R74 | Show the next-action button, ↳ Button position | The button shows Gear, Lure, Cast and Reel as each becomes the next action, and is desaturated in combat. Shift-drag moves it; Reset puts it back. |
| 6. Clams | QOL-R20 step 5, QOL-R23 (its clam part), QOL-R24 "open a clam" row, QOL-R55–R57 | Open clams between Casts | With a clam in the bags and the bobber not out, a press opens one clam and the next-action button shows Clam; while channeling, a press reels. |

Each step's rows take their place in SET-R20's order.

**Exit check** (after step 6), on one character with a fishing set chosen, lures and exactly one clam in the bags, standing at water with no pole in hand, Input *Both*, using only the Fishing key: presses equip the set, apply the best lure and cast; a press reels; after the loot, a press opens a clam, the next casts. A double right-click casts. The music stays muted until the stretch ends; mounting ends it, restores every leased CVar and shows the swap-back Nudge, and Swap gear swaps back. Every rule of `qol.md` is now built except QOL-R100–R104 (M8).

## M2 Ledger core

Content data pipeline v1, projection machinery and Sessions, Core Announcements (policy, toasts, banner, splash, sounds, Session summary, Write-up), the wallet, and Ledger slice 1 (Angler Level, XP, Fresh Water, Skill Milestones).

**Ledger rules** (LED-R4 lists what each Ledger milestone stages):
- LED-R1 without the view and `/pagle journal` (M3)
- LED-R2, LED-R3, LED-R4 (its M2 stage)
- LED-R5 without the Legend class (M4: a Legend item counts as its category until then) and the Uncharted list (M3); LED-R6, LED-R7
- LED-R20 for Catch XP, new Species, Species in a zone, first Catch in a zone and Skill Milestones; LED-R21, LED-R22
- LED-R23 for the number (its bar comes with the Journal in M3)
- LED-R30 and LED-R31 for the first climb (the Prestige factor and carried XP come in M4), LED-R35 for the current level, LED-R36
- LED-R40; LED-R42 for lifetime Catches as a count (the Catch Milestones come in M4)
- LED-R88 for level-ups and new Species, LED-R89
- LED-R90–R94, LED-R96, LED-R98; LED-R95 without the completion part (M3)
- LED-R97 for `levelUp`, `newSpecies` (without size text, M4), `newInZone` and `skillMilestone`
- LED-R190–R195, LED-R197, LED-R198; LED-R196 for Uncharted and item `0` Catches earning the base only

**Settings rules:** SET-R30 without the Toast style and Sound set rows (M4), SET-R31, SET-R33. The Ledger's status row has no button yet (SET-R11).

**Ledger exit check:**
1. With a log from M1 dogfooding, enable Pagle_Ledger and log in: one Write-up card shows "Your Ledger was written up from {N} Casts" with an Angler Level, a Species count and a Pagle Coins line, and nothing pops up. The compartment menu's Curio Shop entry shows that balance.
2. Fish a new Species: one toast "New Species" with the "+10" Coins stamp. Fish a known Species in a zone new for it: a Nod "New here". An ordinary Catch raises nothing.
3. Reach a new Angler Level: a banner, "+20" Coins. Log in an alt whose fishing skill is past an uncredited Skill Milestone: a "Skill Milestone" toast.
4. Disable Pagle_Ledger, fish a new Species, re-enable: a "While the Ledger was off" Write-up section lists it; no toast. `/reload`: nothing shows again.
5. The Session summary card carries "Ledger: Angler Level {L}".

**Sounds:** M2 moves the sounds prototype's shipping assets from the `prototype/sounds` branch into the addon source: `prototypes/sounds/render.py` goes into the build tooling and renders both sets, and its output is committed under `addons/Pagle/media/sounds/` as ANN-R74 lays out. The branch's rejected CC0 pack doesn't move. After this, the branch has nothing left to keep ([Move the prototypes to main](https://github.com/timemir/wow-fish/issues/36#issuecomment-6129511014)).

## M3 Fish Journal

Ledger slice 2: the Journal book (Species, Zone Mastery, Sub-collections, Trophy Room, Ledger completion) on in-client textures; `/pagle report` and Field report intake; `VOICE.md`, the Ledger's first lore batch, and its lore check on.

**Ledger rules** (each Journal rule without the M4 elements LED-R4 lists):
- LED-R1's view and `/pagle journal`; LED-R4 (its M3 stage)
- LED-R5's Uncharted class; LED-R10–R12
- LED-R20 for curio items, trophy weights and Zone Mastery ranks; LED-R23's bar
- LED-R41, LED-R45–R48, LED-R50–R54, LED-R60–R62, LED-R64, LED-R70–R72
- LED-R88 for curio items, trophy weights and Zone Mastery ranks
- LED-R95's completion part
- LED-R97 for `zoneMaster`, `trophyWeight`, `zoneRank`, `newCurio`, `elementStar`, `regularStar`, `familyStar` and `uncharted`
- LED-R120–R128, LED-R130–R136, LED-R137 without its zonemaster line, LED-R138, LED-R140 without its size line, LED-R141–R145
- LED-R146 for the bookplate without title, Prestige and the Catch Milestone part, and for "Hands on the Rod" and "Milestones"
- LED-R148 for zones and Species, LED-R149 without the title
- LED-R160 for the `species`, `legend`, `sub`, `family` and `line` keys (the M3 lore batch), LED-R161, LED-R162 (its M3 part)
- LED-R196 in full

**Settings rules:** SET-R10's Help chart the waters section; SET-R11's "Open Fish Journal".

**Ledger exit check:**
1. `/pagle journal` opens the book on Home: tiles for every charted zone of the chosen continent, fished ones with a rank and %, unfished ones faded with their skill, and a fished zone without data reading "uncharted waters".
2. A fished zone's spread shows its groups and ladder; an uncaught Species reads "— unknown —", and its entry shows a silhouette, a riddle and a plain hint that names no fish. Searching for that Species' name finds nothing; searching for a caught one opens its fish spread.
3. Reach a new Zone Mastery rank: a "Zone rank" toast with "+{2 × rank}" Coins; the zone's tile and seal update while the book is open.
4. Catch a new junk item: a "New curio" toast and its plinth in Curios. An Uncharted Catch (fished in one of the new Forever zones, or from a test log) adds a loose page and a Nod; "Help chart the waters" opens the Field report box.
5. `data/checks.toml` lists `ledger` in `lore`, and `scripts/check.sh` passes.

## M4 Ledger complete

Legends, titles, Simulated Size with the typical-length check on, Catch Milestones, then Prestige; the Curio Shop and Look and Feel; Core's goods and the Ledger's titles in lore, with Core's lore check on.

**Ledger rules:**
- LED-R4 (its M4 stage, which brings back every Journal element M3 left out)
- LED-R5's Legend class; LED-R20 for Legends
- LED-R30 and LED-R31 for Prestige climbs and carried XP; LED-R32–R34; LED-R35 with Prestige
- LED-R42 for the Catch Milestones; LED-R63
- LED-R75–R77, LED-R80–R85
- LED-R88 for Prestige and Legends
- LED-R97 for `legend`, `prestigeReady`, `prestige`, `catchMilestone`, `completeTitle` and `sizeRecord`, and the size text in `newSpecies`
- LED-R110–R112
- LED-R137's zonemaster line, LED-R140's size line, LED-R146 in full, LED-R147, LED-R148 for Legends, LED-R149's title
- LED-R160 for the `title` and `binding` keys (the M4 lore batch), LED-R162 (its M4 part)

**Settings rules:** SET-R10's Units section, SET-R30's Toast style and Sound set rows, SET-R50–R53.

**Ledger exit check:**
1. A new Species toast shows "{band} · {length}" in the Angler's unit, with no Record stamp. A later, strictly longer Catch of it shows a "Size record" toast with the ruler; its entry in the Journal shows the new record.
2. Reach Angler Level 10: the level-up banner names the title, and the Angler page offers it under "Signed As" and the Tanned Hide binding as "Use"; using it reskins the book, and Look and Feel shows the same pick.
3. With a test log at level 60: "Prestige ready" shows; the Journal's Prestige button asks once, then a "Prestige I" banner with "+100" Coins; the climb restarts at level 1 with carried XP, and every level title and binding stays.
4. A Legend Catch (or a test log with one) shows Core's splash with "+100" Coins; the Legends spread names it with "Open the plate", and the uncaught ones show only the shared line.
5. A log passing 1,000 Catches shows the "1,000 Catches" banner.

## M5 Hunts

**Goal:** the Hunts Module, the Now/Soon board and its tracker, Core's tracker dock (built with its first tracker), `NextWindow`, the Hunt list and its lock tooling, and Hunts lore with its check on.

**Core rules:**
- CORE-R70–R73 (the tracker dock), with the Trackers page's "Reset tracker dock position" row. The Trackers page is registered from here on, since Hunts gives it rows (CORE-R42).
- LOG-R50 (`Pagle.NextWindow`)

**Content data rules:**
- DATA-R72, DATA-R75 for `HuntList.lua`
- DATA-R85–R94 (the Hunt list format, classes, the generator's Hunt checks and the emitted shape)
- DATA-R95 and DATA-R96 as tooling only: `--lock` exists and is tested, but `released.lock` stays empty until the 1.0 tag
- DATA-R60's `--lock` mode, DATA-R63 for the Hunt checks
- DATA-R105, and DATA-R107 for the `hunts` lore ID (switched on in `data/checks.toml`), with `data/lore/hunts.toml` and its `[hunts.huntgood]` manifest entry

**Hunts rules:** every rule in `hunts.md`:
- HNT-R1–R7, HNT-R10–R18, HNT-R20–R23, HNT-R25–R27, HNT-R30–R34
- HNT-R40–R44, HNT-R50–R55, HNT-R60–R70, HNT-R75–R82
- HNT-R85–R91, HNT-R110–R112, HNT-R120–R122, HNT-R130, HNT-R135–R138
- HNT-R190–R198
- the v1 Hunt list (`hunts.md` Data), with its item and area IDs checked against `data/db2/`
- Settings: "Show the Hunts tracker" on Trackers, "Tell me when a pinned Hunt's window opens" on Announcements; Core adds the two slots' dropdowns. That is SET-R32, SET-R40, SET-R41, SET-R44, SET-R45 for Hunts, and SET-R11's "Open Hunts"

**Exit check:**
1. `scripts/generate-data.py --check` passes with the v1 Hunt list. Breaking a Hunt on purpose (a natural Hunt without a gated catch entry, or a 1-hour weekly window) makes it fail with the admission or rarity-cap error.
2. With the full package enabled, `/pagle hunts` and the compartment entry toggle the board. It groups the 16 Hunts by realm time: Night Run is Now at night and not in the afternoon, Winter's Squid reads "back in September" in summer, and Rack Hour is On demand.
3. Pin Night Run and Dawn Trout: the tracker docks under the minimap above any other tracker and lists both with live labels. Shift-drag moves the dock; Reset puts it back.
4. Catch a Raw Nightfin Snapper (any time of day): Night Run completes with a "Hunt complete" toast whose Coins stamp includes its 30, its seal shows the date, and the tracker shows "1 / 10".
5. Disable Pagle_Hunts, fish a qualifying Catch, then re-enable it: no toast pops up, and a Write-up section "While Hunts was off" lists it.
6. Change the Hunt list (for example, a tier threshold) and `/reload`: Hunts rebuilds, earlier completions stay, and nothing pops up.
7. With "Tell me when a pinned Hunt's window opens" on and a pinned Hunt about to open, a Nod appears when it opens; with Cozy mode on, it goes to the Session summary instead.
8. Enter combat with the board open: it stays open, the clock reads "(paused in combat)", and it regroups after combat.

## M6 Stats

The Stats Module, window and live tracker, with Stats' lore check switched on in `data/checks.toml` when it registers its first good (DATA-R107). Settings: SET-R42, SET-R45 for Stats, and SET-R11's "Open Stats".

## M7 Tackle Board

The Tackle Board Module, its board and tracker, with its Module records, its lore and its lore check. Settings: SET-R43, SET-R45 for the Tackle Board, and SET-R11's "Start my board" / "Open Tackle Board".

## M8 Release

Launch re-verification on the live build, the 1.0 gates (lore, Settings UX, Simulated Size), the CurseForge and Wago projects, then the 1.0 tag.

### Launch re-verification checklist

Run on the live Forever build before tagging 1.0. Beta facts may change at launch, so some probes are re-run. Each failure changes or retires only the rule it names; a fix too big for that becomes its own ticket.

| # | Check | Rules it affects |
|---|---|---|
| 1 | Disabling a Module in the AddOns list leaves nothing of it loaded, Core's status list shows it as Off, and the AddOns list nests the Modules under Pagle | CORE-R2, CORE-R16, CORE-R17, CORE-R41 |
| 2 | Login and `/reload` time with a 5 MB and a 20 MB `PagleLog` | LOG-R14 (no compaction; a problem becomes its own ticket) |
| 3 | `C_Weather.GetCurrentWeather()` while it rains (the beta gave only zeros) | LOG-R21 (weather may become a new Cast field) |
| 4 | Night realm time: Casts at night carry the right realm minute | LOG-R20, LOG-R49, the `night` window (DATA-R36) |
| 5 | A second pool type, and School of Whimsyfin: hovered pool text reaches the diagnostics buffer and the Field report | LOG-R80, LOG-R81, REP-R22, DATA-R43 |
| 6 | Zone and subzone resolution in Lordamere Lake, the Veiled Sea, the new Forever zones, dungeons and map 2940 | LOG-R22, DATA-R31, DATA-R32 |
| 7 | deDE text matching: zone and subzone text resolve through the runtime area index on a deDE client | LOG-R22, LOG-R23 |
| 8 | Quest 6607 ("Nat Pagle, Angler Extreme") exists | DATA-R22 (Nat Pagle's quest fish become Legends only if it does) |
| 9 | What survives killing the client mid-Session, and whether QoL's leased CVars stay changed (first checked in M1) | LOG-R85, LOG-R86, LOG-R94, QOL-R67 |
| 10 | How long a full projection rebuild of a large log takes | LOG-R71, LOG-R72 (the per-frame time budget and the synchronous catch-up limit) |
| 11 | Every entry in luacheck's `read_globals` list exists on the live build (refresh the pinned Forever dump, then check in the game) | each rule that uses a missing API; event registrations fail softly under CORE-R23 |
| 12 | The live interface number and `WOW_PROJECT_CAMELOT`: if the interface number changed, bump it in every TOC | CORE-R2, CORE-R4 |
| 13 | Clam opening through the secure button; the lure table's items and enchant IDs; any Forever lures and clams | QOL-R100 |
| 14 | In-combat weapon swap through a secure button | QOL-R101 |
| 15 | `C_AddOns.DisableAddOn` from addon code, and whether `ReloadUI()` is still protected | QOL-R102 |
| 16 | The equipment-set limit, with *Pagle Previous* taking a slot | QOL-R103 |
| 17 | The conflict list's folder names, including the two Forever Fishing Buddy ports | QOL-R104 |
| 18 | `C_DateAndTime.GetSecondsUntilDailyReset` and `GetSecondsUntilWeeklyReset` exist (realm midnight is the fallback) | TKB-R10, TKB-R11 (the fallback) |
| 19 | `GetCurrentRegion()` exists | LOG-R69 (the default length unit) |
| 20 | The `bit` library exists | LOG-R66 (the Simulated Size hash) |
| 21 | The spell IDs a fishing channel reports, and that every rank shares spell 7620's name and icon | DATA-R39, LOG-R2, QOL-R22, QOL-R24, QOL-R71 |
| 22 | A per-character Self-Found call exists | LOG-R26 (`selfFound` stays `nil` until one is named) |
| 23 | Got-away detection: `ERR_FISH_ESCAPED` arrives as LOG-R6 expects (first checked on the beta in M1) | LOG-R6 |
| 24 | Which catalogue facts rest on beta builds only (`scripts/generate-data.py --min-build <first live build>`) | DATA-R46, DATA-R57 (may raise the minimum confirming build) |

### Before the tag

1. Set every v1 Hunt's `since` to the release day (DATA-R87).
2. Run `scripts/generate-data.py --lock` for the first `released.lock`, in the release commit (DATA-R73, DATA-R95).
3. From the tag on, the entry formats (LOG-R17), the `Pagle` API (CORE-R15) and each DB's first `schemaVersion` are frozen.

## After 1.0

On the roadmap but not specified: custom Journal art (1.0 uses in-client textures, shared with the Hunts board and the Stats window), translations (1.0 is enUS only, with every string in `ns.L` from M0), the export/backup string, QoL's recast reminder, and the post-launch Hunts (the Fishing Trip quest, Chef's Knife, the Rack and Hut contents), each with its own `since` date.
