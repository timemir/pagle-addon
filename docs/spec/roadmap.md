# Roadmap

> Status: Done · Milestones: M0–M9 (with M8.5), Track Q · Sources: [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652) (its body holds the launch re-verification list), [Choose the toolchain and libraries](https://github.com/timemir/wow-fish/issues/8#issuecomment-6112249259), [Write the QoL spec](https://github.com/timemir/wow-fish/issues/37#issuecomment-6130705093), [Beta probe: which fishing signals can the Forever client see?](https://github.com/timemir/wow-fish/issues/7#issuecomment-6110508010), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372), [Define the QoL feature set](https://github.com/timemir/wow-fish/issues/16#issuecomment-6113508077), [Design the Tackle Board](https://github.com/timemir/wow-fish/issues/25#issuecomment-6124911363), [Write the Tackle Board spec](https://github.com/timemir/wow-fish/issues/43), [Write the Stats spec](https://github.com/timemir/wow-fish/issues/42), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Move the prototypes to main](https://github.com/timemir/wow-fish/issues/36#issuecomment-6129511014), [Write the Settings spec](https://github.com/timemir/wow-fish/issues/44); ADR 0003, 0005 (notes: compatibility starts at 1.0)

This file sets the order in which Pagle is built. It assigns spec rules to milestones; the rules themselves live in the other spec files. Terms are used as `CONTEXT.md` defines them.

## How the roadmap works

- **Nothing is published before 1.0.** 1.0 means every Module is implemented (Core, QoL, Ledger, Hunts, Stats, Tackle Board) and M9 is done. There are no target dates: work continues straight through, and scope is cut rather than quality.
- **No backward compatibility before 1.0.** The log format, every `PagleDB` / `Pagle<Module>DB` shape, Module state and Hunt definitions change freely; a dev log whose format is outdated is replaced by a new one (LOG-R18). The freezes start at 1.0: LOG-R17, CORE-R15, DATA-R73, DATA-R95.
- **One version for the whole package, and no git tags before 1.0.** The packager publishes only on a tag push, so nothing reaches CurseForge or Wago by accident.
- **Milestones.** Each milestone below is one GitHub Milestone with the same name. Every build ticket belongs to exactly one. Milestones set the order of work, not dates: the riskiest and most shared Core pieces come first, and leaf work runs in parallel. **Track Q** runs in parallel from the end of M1, **Track V** alongside M8 onward, and **Track P** alongside M9; 1.0 doesn't wait for Track V, and waits for Track P.
- **Rules per milestone.** A rule listed under a milestone is built in it. A rule listed "for" or "without" something is built only in that part; the rest of it is listed where it lands. Every milestone and Track Q lists its rules file by file, and every rule ID in the spec is listed somewhere below. The Milestones line in each spec file's header summarises the same split; where the two differ, this file wins and the header is fixed.
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
- The vendored libraries of CORE-R6, each at a recorded upstream commit (Ace3, and LibDeflate 1.0.2 for the Paste string), updated only by a script (`scripts/update-ace3.sh`, `scripts/update-libdeflate.sh`).
- `scripts/check.sh`, which reports the first failing stage in this order:
  1. format: `stylua --check`, StyLua defaults (tabs, 120 columns), Lua 5.1 syntax
  2. lint: luacheck with `std = "lua51"`, the per-path `std` of CORE-R7, and a hand-kept `read_globals` list in which each WoW API is added on purpose. That list is the inventory of WoW APIs Pagle uses, and M9 re-checks it.
  3. API presence: a script fails if any `read_globals` entry is missing from the pinned Ketho BlizzardInterfaceResources `forever` dump
  4. types: `lua-language-server --check` with zero warnings, against Ketho's `vscode-wow-api` annotations at a pinned commit. Each suppression is an inline `---@diagnostic disable-next-line: <code>` with a reason.
  5. tests: busted on real Lua 5.1 (not LuaJIT). The busted helper loads each addon's files from its real `.toc`, in order, with a shared `ns`, so TOC and load-order mistakes fail tests. luacov reports coverage and doesn't gate.
  6. from M1, the generator's check and tests (DATA-R61)
- Tool versions are pinned in one place and installed by a setup script. `check.sh` runs locally in WSL.
- GitHub Actions (Ubuntu, Lua 5.1) runs `check.sh` on pushes to `main` and on pull requests. Required checks run every spec without coverage, in two concurrent shards. A manual Check run with `coverage` enabled also runs a separate, non-blocking coverage report. Gate-regression cases run when gate machinery changes, with focused integration specs for the passing baseline and each planted mistake. Generator data rules run through the real CLI in the Python suite; gate cases retain generator exit propagation and stale-output checks.
- A release workflow runs `BigWigsMods/packager` (pinned to a commit) on a tag push, uploading to CurseForge and Wago (never WoWInterface). `.pkgmeta` has `package-as: Pagle`. The project IDs and upload secrets are added in M9, with the tag's GitHub Release (CORE-R74).
- A PowerShell dev-loop script junctions (`mklink /J`) each `addons/*` folder into the beta's `Interface/AddOns/`, so edits go live after `/reload`.

**Exit check:**
1. `scripts/check.sh` passes in WSL and in GitHub Actions on `main`.
2. A local packager run with uploads off builds one zip holding the `Pagle` folder.
3. In the game, with the folder junctioned in: the AddOns list shows Pagle under Professions, the game loads it, and no Lua error appears (BugSack installed). `/dump Pagle.API_VERSION` prints `1`.

## M1 Dogfood

**Goal:** the MVP slice. Core records every Cast to the Catch log, and QoL's Fishing key casts and reels. The dev fishes with Pagle from here on, so the log fills with real data to build the later milestones against. With no other Module installed, Core shows nothing but its Settings root and records silently.

**Core rules:**
- CORE-R3, CORE-R5, CORE-R10–R14, CORE-R16–R23, CORE-R30–R33
- CORE-R40 without the "Help chart the waters" button (M3). Core's options are the Saving section's LOG-R86 reminder; the Units section's length unit (LOG-R69) comes in M4. Only the Fishing page has rows in M1, so it's the only topic page registered (CORE-R42).
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
- DATA-R8 for the baseline, `data/forever/` and `data/db2/` layers (`data/observed/` comes in M2 with `dev.toml`, and its imported reports in M3)
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
7. **Conflict popup (QOL-R80–R84):** enable Angleur's Forever build and log in. The popup appears; "Use Pagle" turns Angleur off and shows the Reload now popup; clicking Reload now reloads, Angleur stays off and the Fishing key works.
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

**Added after the M1 exit check (#114):** QOL-R20 step 2's "unless the reel didn't take" and QOL-R35, recasting when a reel didn't take. It has no settings row and is checked before the exit check. In-game check: cast so the bobber lands beyond interact range, and press once: nothing reels, and from half a second later the next-action button shows Cast; the next press casts a new bobber, and a press on it in range reels.

**Exit check** (after step 6), on one character with a fishing set chosen, lures and exactly one clam in the bags, standing at water with no pole in hand, Input *Both*, using only the Fishing key: presses equip the set, apply the best lure and cast; a press reels; after the loot, a press opens a clam, the next casts. A double right-click casts. The music stays muted until the stretch ends; mounting ends it, restores every leased CVar and shows the swap-back Nudge, and Swap gear swaps back. Every rule of `qol.md` is now built except QOL-R100–R104 (M9).

## M2 Ledger core

Content data pipeline v1, projection machinery and Sessions, Core Announcements (policy, toasts, banner, splash, sounds, Session summary, Write-up), the wallet, and Ledger slice 1 (Angler Level, XP, Fresh Water, Skill Milestones).

**Core rules:**
- CORE-R50's Curio Shop entry (shown disabled, with the balance, until M4), CORE-R51
- CORE-R80, CORE-R81
- LOG-R1 step 3; LOG-R9 steps 3 and 4
- LOG-R42 for `M:IterateCatches` (Module records join it in M7)
- LOG-R55–R57 for the full catalogue: items, catch lists with `window` and `gate`, pools, windows and `GetWindowSpec` (`typicalLength` comes in M4)
- LOG-R60–R64, LOG-R98 (Sessions, and the `session` tag on records)
- LOG-R70–R77 (projections), LOG-R90–R92, LOG-R95
- every rule in `announcements.md`: ANN-R1–R4, ANN-R10–R13, ANN-R20–R25, ANN-R30–R32, ANN-R35–R37, ANN-R40–R42, ANN-R45, ANN-R50–R56, ANN-R60–R63, ANN-R70–R75, ANN-R80, ANN-R90–R96. Only Driftwood and Timber are in use: Gilded and the other toast styles are Curio Shop goods (M4), and size rulers come with Simulated Size (M4).
- SHOP-R1–R5 (earning), SHOP-R12 for the balance (nothing is spent before M4; the held line shows in the shop), `Pagle.GetBalance` and `BalanceChanged`, SHOP-R90–R96 for earning

**Content data rules:**
- DATA-R8 for `data/observed/`, with `dev.toml` (imported reports come in M3)
- DATA-R10 for the rest of `data/forever/`: `items.toml`, `species.toml`, `families.toml`, `areas.toml`, `windows.toml`, `pools.toml`
- DATA-R11 and DATA-R12 for `items.csv`
- DATA-R15–R19, DATA-R21–R24 (DATA-R20's typical lengths come in M4)
- DATA-R26–R31, DATA-R33–R37, DATA-R38's `event.301` window, DATA-R40
- DATA-R43, DATA-R44
- DATA-R45–R57; until Field report intake (M3), dev facts are the only observations
- DATA-R60's `--min-build` and `--explain` modes; DATA-R63 and DATA-R64 in full except the Hunt checks (M5) and the lore checks (M3); DATA-R65, DATA-R66 (both switches off)
- DATA-R70 over the full catalogue, DATA-R71, DATA-R77, DATA-R78 (DATA-R79 no longer applies)
- DATA-R128–R130 (the DB2 watch)
- DATA-R190–R197 (their Field report parts take effect in M3)

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

**Core rules:**
- CORE-R40's "Help chart the waters" button, CORE-R50's "Help chart the waters" entry, CORE-R61's `report`
- CORE-R9 (the characters the client's fonts have, #248), which every later milestone keeps
- LOG-R78 for the Field report projection
- LOG-R50 (`Pagle.NextWindow`), for LED-R127's window states
- every rule in `field-report.md`: REP-R1–R5, REP-R10–R12, REP-R20–R23, REP-R25, REP-R26, REP-R30–R33, REP-R35–R37, REP-R40–R47, REP-R90–R96

**Content data rules:**
- DATA-R8 for `data/observed/reports/`; DATA-R115–R123 (Field report intake: the issue form, the parser, the triage Action, the importer, `pooltext.toml`)
- DATA-R75 for `Lore.lua`; DATA-R100–R104 and DATA-R106–R112 for the `ledger` lore ID, with `VOICE.md` and the manifest, `ledger` switched on in `data/checks.toml` (DATA-R66)

**Ledger rules** (each Journal rule without the M4 elements LED-R4 lists):
- LED-R1's view and `/pagle journal`; LED-R4 (its M3 stage)
- LED-R5's Uncharted class; LED-R10–R12
- LED-R20 for curio items, trophy weights and Zone Mastery ranks; LED-R23's bar
- LED-R41, LED-R45–R48, LED-R50–R54, LED-R60–R62, LED-R64, LED-R70–R72
- LED-R88 for curio items, trophy weights and Zone Mastery ranks
- LED-R95's completion part
- LED-R97 for `zoneMaster`, `trophyWeight`, `zoneRank`, `newCurio`, `elementStar`, `regularStar`, `familyStar` and `uncharted`
- LED-R120–R136, LED-R137 without its zonemaster line, LED-R138, LED-R140 without its size line, LED-R141–R145
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

**Core rules:**
- CORE-R40's Units section, CORE-R50's Curio Shop entry enabled, CORE-R61's `shop`
- LOG-R16 for `P1` and `U1`; LOG-R38, LOG-R39
- LOG-R55's `typicalLength`; LOG-R65–R69 (Simulated Size and the length unit); LOG-R100 (the earlier Catch counts behind the Reach, ADR 0014)
- LOG-R78 for the wallet projection
- ANN-R22's size ruler, ANN-R72's Gilded set and ANN-R80's other toast styles, as Core's goods (SHOP-R25)
- SHOP-R10, SHOP-R11, SHOP-R12's held line, SHOP-R13, SHOP-R20–R26, SHOP-R30–R35, SHOP-R40, SHOP-R41, SHOP-R90–R96 in full

**Content data rules:**
- DATA-R20, with `typicalLength = true` in `data/checks.toml` (DATA-R66)
- DATA-R107 for the `core` lore ID (switched on), and for the Ledger's `title` and `binding` IDs, which enter the manifest (DATA-R106, DATA-R111)

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

**Goal:** the Hunts Module, the Now/Soon board and its tracker, Core's tracker dock (built with its first tracker), the Hunt list and its lock tooling, and Hunts lore with its check on.

**Core rules:**
- CORE-R70–R73 (the tracker dock), with the Trackers page's "Tracker position" row and its Reset button (SET-R40). The Trackers page is registered from here on, since Hunts gives it rows (CORE-R42).

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
1. `scripts/generate-data.py --check` passes with the v1 Hunt list. Breaking a Hunt on purpose (a natural Hunt without a gated catch entry, or an imposed Hunt open one hour a year) makes it fail with the admission or rarity-cap error.
2. With the full package enabled, `/pagle hunts` and the compartment entry toggle the board. It groups the 16 Hunts by realm time: Night Run is Now at night and not in the afternoon, Winter's Squid reads "back in September" in summer, and Rack Hour is On demand.
3. Pin Night Run and Dawn Trout: the tracker docks under the minimap above any other tracker and lists both with live labels. Shift-drag moves the dock; Reset puts it back.
4. Catch a Raw Nightfin Snapper (any time of day): Night Run completes with a "Hunt complete" toast whose Coins stamp includes its 30, its seal shows the date, and the tracker shows "1 / 10".
5. Disable Pagle_Hunts, fish a qualifying Catch, then re-enable it: no toast pops up, and a Write-up section "While Hunts was off" lists it.
6. Change the Hunt list (for example, a tier threshold) and `/reload`: Hunts rebuilds, earlier completions stay, and nothing pops up.
7. With "Tell me when a pinned Hunt's window opens" on and a pinned Hunt about to open, a Nod appears when it opens; with Cozy mode on, it goes to the Session summary instead.
8. Enter combat with the board open: it stays open, the clock reads "(paused in combat)", and it regroups after combat.

## M6 Stats

**Goal:** the Stats Module: its projection, Your odds and Dry spells, the Stats book, the live tracker with watched Dry spells, and its tracker frames with their lore and lore check. Stats needs nothing new from Core: Sessions and the `session` tag (M2), `PagleItem.pool` and catch entries' `window` (M2) and the tracker dock (M5) are already there.

**Content data rules:**
- DATA-R107 for the `stats` lore ID, switched on in `data/checks.toml` with the M6 lore batch (DATA-R111), when Stats first registers its goods

**Stats rules:** every rule in `stats.md`:
- STA-R1–R4, STA-R10–R18, STA-R20–R27, STA-R30–R33
- STA-R40–R47, STA-R50–R55, STA-R58, STA-R59, STA-R60–R64
- STA-R70–R76, STA-R80–R86, STA-R88
- STA-R90–R97
- Settings: "Show the live tracker" and its Watched Dry spells row on Trackers; Core adds the frame dropdown. That is SET-R42, SET-R44, SET-R45 for Stats, and SET-R11's "Open Stats"

**Exit check:**
1. With a log from earlier milestones, enable Pagle_Stats and log in: no Write-up and nothing pops up. `/pagle stats` and the compartment entry toggle the book; the nameplate reads "{n} Casts · {m} Sessions · since {date}", and the home spread has a tile per fished zone.
2. Open *Where I am*: rows are grouped Any time, Pools, In their window and Also caught here. An item with under 100 Casts in its scope reads "learning {n}/100"; a known one reads "about 1 in N" with its range and a scope line naming the Casts it rests on, on the right skill side.
3. With the live tracker off, watch a Dry spell: the tracker turns on with one chat line and docks below the Hunts tracker. A 4th watch is refused with the UI error. Catch the watched item: its count reads "just now".
4. Stop fishing for 5 minutes, then cast again: a new Session starts, and the Sessions page lists both. Nothing pops up at any point.
5. Change a window or a catch list in content data and `/reload`: the book and tracker show their updating states, the numbers follow the new data, and nothing is announced.
6. `scripts/check.sh` passes with `stats` in `data/checks.toml`'s `lore`, including the copy test that finds no "due" wording (STA-R58).

## M7 Tackle Board

**Goal:** the Tackle Board Module: its Module records, board days and refills, the eight goal kinds, rerolls, the Campfire and Kindling, the Fly Box and titles, the cork board, its tracker and frames, and its lore with its lore check.

**Core rules:**
- LOG-R16 for `A1`; LOG-R40, LOG-R41 (Module records; the Tackle Board is the first Module to write them)
- LOG-R42's Module records in `M:IterateCatches`

**Content data rules:**
- DATA-R107 for the `tackleboard` lore ID, switched on in `data/checks.toml` with the M7 lore batch (DATA-R111)

**Tackle Board rules:** every rule in `tackle-board.md`:
- TKB-R1–R3, TKB-R5, TKB-R6, TKB-R10–R14, TKB-R20–R23
- TKB-R30–R36, TKB-R40–R46, TKB-R55–R57
- TKB-R60–R64, TKB-R70–R74, TKB-R80–R87
- TKB-R100–R109, TKB-R120–R125, TKB-R130
- TKB-R190–R198
- Settings: "Show goals workable here" on Trackers; Core adds the frame dropdown. That is SET-R43, SET-R44, SET-R45 for the Tackle Board, and SET-R11's "Start my board" / "Open Tackle Board"

**Exit check:**
1. Enable Pagle_TackleBoard: nothing shows and nothing is written; the Settings root's button reads "Start my board", and the Trackers checkbox is greyed out.
2. Press Start my board: 3 Notices and 1 Expedition are pinned, the tracker lists the goals workable here, and after `/reload` `PagleLog` holds one `start` and four `issue` records.
3. Complete a Notice: a "Notice complete" toast with its Coins stamp; the slip goes on the spike, the Fly Box reads "1 of 30 tied", and the Campfire is lit.
4. Take down a Notice that has progress: the confirm asks once, and its replacement is stamped RE-POSTED with no "take it down". `/reload`: the board looks the same.
5. Let a board day pass without a goal done (or use a test log): at the next login a Nod says Kindling was used, the Campfire count is unchanged, and the Notice pins have refilled, up to 6.
6. Disable Pagle_TackleBoard, complete an open goal's need, re-enable: a "While Tackle Board was off" Write-up section lists it, and nothing pops up.
7. `scripts/check.sh` passes with `tackleboard` in `data/checks.toml`'s `lore`.

## M8 Hunt Events

**Goal:** Hunts redesigned around **Hunt Events** (shown as Pagle Wagers), with **Activity XP** from any Module and Core's **pushed-content** reader, as the map [Hunts redesigned around Hunt Events](https://github.com/timemir/wow-fish/issues/277) decided (ADR 0011–0013). 1.0 waits for it, with no hard date. It ships with the fallback rotation, pushed Hunt Events whenever the companion's `Pagle_Content` passes Core's check (pagle-backend #2, pagle-companion #36), and the companion hint switched on (HNT-R172). *[#288](https://github.com/timemir/wow-fish/issues/288) kept the hint off until `Pagle_Content` worked end to end; with the reader built and M8's tickets closed, the dev turned it on for 1.0.*

**Before it starts:** finish review fix A (one Core motion and fit API, `fix/review-a-motion-api`); land fixes A, B and C and the 1.0 changelog through `integ/review-fixes` onto `main` with one full gate; land the CI fix (test-check in its own job). The redesign rewrites the Hunts board, which A and B both touch.

**Build order,** each step one or more build tickets:
1. Core: Activity XP and the Prestige snapshot; the pushed-content reader with its RSA check.
2. Ledger: the full Prestige cost, Activity XP in the climb, XP by source.
3. Tackle Board: Activity XP.
4. Content data: `data/hunts/events/`, `tags.toml`, `EventList.lua`, the event checks, `propose-events.py`, `check-event.py`.
5. The Hunts fold: runs and their records, the banded rotation, Coins and XP for events, the ladder.
6. The board: the wager strip and the WAGERS group on the Board, the Pagle Wagers ribbon and spread, the run entry.
7. The tracker's Pagle Wagers block, the companion hint and its Nod (behind the hint switch, on at 1.0).
8. The 24-event pool and its lore batch (with the ladder titles at 50 and 100).
9. The exit check.

**Core rules:**
- AXP-R1–R8, AXP-R90–R92 ([core/activity-xp.md](core/activity-xp.md))
- PUSH-R1, PUSH-R2, PUSH-R10–R16, PUSH-R20–R23, PUSH-R90–R93 ([core/pushed-content.md](core/pushed-content.md))
- LOG-R38 for the `activityXP` field of `P1`; SHOP-R3 for the totals' `logId`

**Content data rules:**
- DATA-R97–R99; DATA-R94–R96 for event Hunts' hashes
- DATA-R107 for the `event` and `ladder` lore keys, with the event pool's lore batch (DATA-R111)

**Ledger rules:** LED-R2 and LED-R4 for `LEDGER_RULES_VERSION` 5; LED-R30–R33 for the full Prestige cost, the climb's Activity XP and the confirm card's text; LED-R37–R39; LED-R145 for its tooltip; LED-R150; LED-R199

**Tackle Board rules:** TKB-R60 and TKB-R65 (Activity XP), TKB-R84 and TKB-R85 for its Write-up line, `TKB_RULES_VERSION` 2

**Hunts rules:**
- HNT-R1, HNT-R2 and HNT-R16 for event Hunts; HNT-R40 and HNT-R42 for runs; HNT-R61 and HNT-R67 for the Pagle Wagers ribbon and breadcrumbs
- HNT-R86's wager rows, HNT-R89's settled count, HNT-R90 and HNT-R92, HNT-R110 for events, HNT-R111's new lines, HNT-R113–R115
- HNT-R130 for the `event` and `ladder` keys, HNT-R136–R138 for runs and the rules version 2
- HNT-R140–R156, HNT-R160–R165, HNT-R170–R172, HNT-R175–R177
- HNT-R199–R204
- Settings: "Remind me about the Pagle companion" on Announcements, under Hunts' header (SET-R32), while the hint switch is on, as at 1.0 (HNT-R172)

**Exit check:**
1. With the rotation's starting point in the past: `/pagle hunts` shows the wager strip above "What's biting", a WAGERS row whose bar spans the ruler with ▸ at its end, and the Pagle Wagers ribbon reading "1 on". The ribbon's spread lists the slip with its countdown and the ladder at 0 of 25.
2. Fish in the run's zone until one Hunt reaches tier 1: a "Pagle Wagers · first mark" toast with its Coins stamp; the pip inks in; the Angler page's "Where your XP came from" shows Hunts +150. `/reload`: `PagleLog` holds one `run` record for that slot (read-wtf).
3. Reach every Hunt's tier 1: a "Wager settled" toast; the slip and the entry's seal read settled; the ladder reads 1 of 25.
4. Complete a Tackle Board Notice: its XP shows under Tackle Board on the Angler page, and a level it brings raises the Ledger's level-up with the Notice's toast.
5. Prestige with a test log at level 60 (#262's tooling): the confirm card reads "climbs again from 1"; after `/reload` the `P1` entry carries `activityXP`.
6. Without `Pagle_Content` (the switch on, HNT-R172): the hint's line shows under the wager strip and in the tracker, a Nod comes at most once a week, Get it shows `https://pagle.app/download`, and Announcements has "Remind me about the Pagle companion" under Hunts' header. With a hand-made, unsigned `Pagle_Content`: `/pagle dev content` reports it absent and why.
7. Wait past the run's end (or use a test log): the run leaves the board and tracker, the next slot's event is on, and nothing lists the old one.
8. `scripts/check.sh` passes with the pool's 24 events and the `hunts` lore check on.

## M8.5 Onboarding

**Goal:** a new Angler is welcomed and taught by fishing: the Letter, the eight-page Field guide, Margin notes on first moments, a First look on each window with a "?" to see it again, and the First evening list ([core/onboarding.md](core/onboarding.md)), plus Pagle's minimap icon ([#290](https://github.com/timemir/wow-fish/issues/290)), as [the onboarding kit, grilled with the dev](https://github.com/timemir/wow-fish/issues/260#issuecomment-6335904394) decided. 1.0 waits for it: shipped after 1.0, every launch player's Catch log would already hold Casts, so none would see the Letter (ONB-R2).

**Runs alongside M8.** Only the Hunts First look waits for M8's board (its Pagle Wagers note points at the ribbon, ONB-R57); every other ticket starts now. M9's Settings UX pass (#266) and store screenshots (#270) wait for this milestone's exit check.

**Build order,** each step one or more build tickets:
1. Core: the onboarding state, `/pagle guide`, the dev commands and read-wtf's Onboarding section; Announcement hold reasons and the budget default; the binding field's shared key capture; the minimap icon.
2. Core: the guide's book and step registry, then Core's four steps, the Letter, Margin notes, First looks with the coach bar and the "?", and the First evening list.
3. The Modules' parts: QoL's Casting and Fishing clothes steps; the Ledger's step, Journal First look and notes; the Tackle Board's step and First look; Stats' First look; Hunts' First look (after M8's board).
4. The copy review, then the exit check.

**Core rules:**
- ONB-R1–R3, ONB-R10–R14, ONB-R20–R27, ONB-R30, ONB-R31, ONB-R34, ONB-R35, ONB-R38, ONB-R40–R44, ONB-R50–R53, ONB-R55–R59, ONB-R60–R64, ONB-R70, ONB-R71, ONB-R80–R84, ONB-R90–R93, ONB-R100–R109 ([core/onboarding.md](core/onboarding.md))
- CORE-R40 for Getting started and the Pagle menu section; CORE-R53–R56; CORE-R61 for `guide`; CORE-R70 for the First evening list's order
- ANN-R31 for the default of 20 per 5 min; ANN-R38; ANN-R64; `PagleMoment.firstNote`

**Module rules** (each Module builds its parts of onboarding's rules):
- QoL: ONB-R32, ONB-R33 and the `qol.lure` note (ONB-R52)
- Ledger: ONB-R36, the Fish Journal's First look (ONB-R57) and "?" (ONB-R59), the `ledger.fresh` note, the `journal` item (ONB-R61), `newSpecies`'s `firstNote` (ONB-R53), its `guideBlurb` (ONB-R91)
- Tackle Board: ONB-R37, its First look and "?", its `guideBlurb`
- Stats: its First look and "?", its `guideBlurb`
- Hunts: its First look and "?", the `hunts` item, its `guideBlurb`

**Settings rules:** SET-R10 rows 4–6 (Getting started) and 10 (Show the minimap icon); SET-R30 for the Interruptions slider's 1–30 range and its default

**Exit check:** [core/onboarding.md › In-game exit check](core/onboarding.md#in-game-exit-check), steps 1–14, then:
15. The minimap icon shows the favicon; dragging moves it round the minimap and the place survives `/reload`; a left click opens the Pagle menu; its tooltip and the compartment entry's read "A letter for you" while the Letter shows; Show the minimap icon hides and shows it.
16. `scripts/check.sh` passes.

## Track V: In-game views

**Goal:** Published Anglers in game, from the two data addons the Companion writes ([#76](https://github.com/timemir/wow-fish/issues/76) items 9–11, pagle-backend's [in-game-views.md](https://github.com/timemir/pagle-backend/blob/main/docs/spec/in-game-views.md)): Core reads `Pagle_Following` and `Pagle_Anglers`, adds the Pagle block to player tooltips, and the Ledger draws the Following spread. Without the Companion's files nothing shows, so it ships in 1.0 if it is merged by the tag and in a patch otherwise; M9 doesn't wait for it. pagle-backend's B4 exit check and pagle-companion #34 wait for it.

**Build order:** 1. Core's reads (VIEW-R1–R4, VIEW-R10–R12). 2. The tooltip block and its Settings row, and the Following spread, in parallel.

**Core rules:** VIEW-R1–R4, VIEW-R10–R13, VIEW-R20–R22, VIEW-R30; edge cases VIEW-R90–R95 ([core/anglers-in-game.md](core/anglers-in-game.md))

**Module rules:** Ledger: LED-R132 for its "Following" line, LED-R151

**Settings rules:** SET-R10 row 11 (Show other Anglers on player tooltips)

**Exit check,** with the Pagle Companion linked and running, following one Published Angler whose character is nearby:
1. Before the Companion's folders exist: no block on any player tooltip; Home's "Following" greys out as "no Companion"; the spread shows the absent state; `/pagle dev views` reports both files absent.
2. After logging out to character select and back in: hovering the followed character shows the block with "Following", its title, Angler Level, Ledger % and Legends, and no region; hovering another Published Angler's character shows the block without "Following"; hovering a player who isn't Published adds nothing.
3. The first hover in combat finds only the Followed Angler; out of combat the next hover loads `Pagle_Anglers` (`/pagle dev views` says it loaded).
4. Turning "Show other Anglers on player tooltips" off removes the block; on again, it comes back.
5. The Following spread lists the Followed Angler with its card; with the Ledger turned off the tooltip still shows.
6. With the Companion closed for 24 h, the block goes and the spread shows the expired state.
7. `scripts/check.sh` passes.

## Track S: Curio Shop expansion

**Goal:** the shop expansion kit's 80 goods and a sting per Legend: price tiers 4 and 5, Core's toast style and sound set slots open to earned goods, twelve toast styles and twelve sound sets for sale in Core, twenty bindings, fifteen covers and fifteen tracker frames in the Modules, sixteen earned goods, and every set and sting rendered by `render-sounds.py`. Built after the zone crests kit (#339), from the kit's media and `goods.json`; tiers 4–5 are a long-term chase (wallet-and-shop.md Tunables). 1.0 ships it if it is merged by the tag.

**Build order:** Core and the sound pipeline first or alongside; the Ledger's, Hunts', Stats' and the Tackle Board's goods in parallel, each against Core's open slots.

**Core rules:** SHOP-R20 for art text, SHOP-R22 for tiers 4 and 5, SHOP-R23 for `core.toaststyle` and `core.soundset`, SHOP-R25 for the new goods; ANN-R70, ANN-R72 and ANN-R74 for the sets and a sting per Legend; ANN-R80, ANN-R81

**Module rules:** Ledger: LED-R110 for the new bindings, LED-R116, LED-R117, LED-R160 for `ledgergood`. Hunts: HNT-R121 for the new covers and frames, HNT-R122, HNT-R123. Stats: STA-R88 for the new frames. Tackle Board: TKB-R125 for the new frames, TKB-R126

**Exit check:** the Curio Shop lists every new good at its tier's price, with the earned ones showing their `earnedText`; buying and equipping a tier 4 toast style, a sound set, a binding, a cover and a frame of each tracker shows each look; catching each Legend plays its own sting; an earned Module good in a Core slot equips and plays like Core's own, and is put away with its Module off; `scripts/render-sounds.py` reproduces every committed set and sting; `scripts/check.sh` passes.

## Track P: Paste string

**Goal:** the no-install way onto the Pagle website ([#361](https://github.com/timemir/wow-fish/issues/361), from [#76](https://github.com/timemir/wow-fish/issues/76) items 3 and 4): Core builds Paste strings from `PagleLog` exactly as pagle-backend's [upload.md](https://github.com/timemir/pagle-backend/blob/main/docs/spec/upload.md) has them (UPL-R50–R52), cut into parts, in an export window with "New since last export" and "Everything", and keeps the last exported seq per `logId`. LibDeflate 1.0.2 is vendored for it (CORE-R6). It ships in 1.0, before the backend opens (day L), so 1.0 waits for it.

**Build order:** 1. LibDeflate vendored and pinned (CORE-R6). 2. The upload document, parts and Paste string in `logic/` (PST-R10–R33), checked against upload.md's grammar and decoded by pagle-backend's decoder. 3. The export window, its entry points, the mark and the copy test (PST-R40, PST-R41, PST-R50–R53, PST-R60).

**Core rules:** CORE-R6 for LibDeflate, CORE-R33 for the export window, CORE-R61 for `export`, CORE-R68 for its tour stop; PST-R1, PST-R2, PST-R10–R15, PST-R20–R23, PST-R30–R33, PST-R40, PST-R41, PST-R50–R53, PST-R60; edge cases PST-R90–R99 ([core/paste-string.md](core/paste-string.md))

**Settings rules:** SET-R10 row 12 (Catch log), SET-R12 for its button

**Exit check,** on the live Forever client with a log of more than 5,000 entries:
1. `/pagle export` opens the window on "New since last export" at "Part 1 of k"; each part's string pastes on the website's Paste upload page and is applied in order; a part pasted out of order is refused as a gap.
2. After copying every part, `/pagle export` says "Nothing new since your last export."; after a few more Casts and a `/reload`, it shows one part of just those, which the website applies.
3. "Everything" shows every part from entry 1 again; the website takes them as unchanged.
4. In combat, `/pagle export` prints its line and opens nothing.
5. The copy test (launch re-verification check 25) passes, or its sizes are reported to pagle-backend.
6. `scripts/check.sh` passes.

## M9 Release

Launch re-verification on the live build, the 1.0 gates (lore, Settings UX, Simulated Size), the CurseForge and Wago projects, then the 1.0 tag. Named M8 Release until the Hunts redesign took M8 ([#288](https://github.com/timemir/wow-fish/issues/288)). The Settings UX pass (#266), the store screenshots (#270), the tag's preparation (#275) and the exit check (#276) wait for M8 Hunt Events and M8.5 Onboarding; launch re-verification (#272–#274) and the store projects (#271) don't.

**Rules:** QOL-R100–R104 (QoL's launch re-verification), DATA-R57 for check 24, DATA-R73, DATA-R87 and DATA-R95 at the tag (Before the tag), and CORE-R74 (the tag's GitHub Release, [#362](https://github.com/timemir/wow-fish/issues/362)). Every other check below names the rules it may change.

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
| 15 | `C_AddOns.DisableAddOn` from addon code, and that `ReloadUI()` is still unprotected (it was on build 70338) | QOL-R102, QOL-R6, QOL-R83 |
| 16 | The equipment-set limit, with *Pagle Previous* taking a slot | QOL-R103 |
| 17 | The conflict list's folder names, including the two Forever Fishing Buddy ports | QOL-R104 |
| 18 | `C_DateAndTime.GetSecondsUntilDailyReset` and `GetSecondsUntilWeeklyReset` exist (realm midnight is the fallback) | TKB-R10, TKB-R11 (the fallback) |
| 19 | `GetCurrentRegion()` exists | LOG-R69 (the default length unit) |
| 20 | The `bit` library exists | LOG-R66 (the Simulated Size hash) |
| 21 | The spell IDs a fishing channel reports, and that every rank shares spell 7620's name and icon | DATA-R39, LOG-R2, QOL-R22, QOL-R24, QOL-R71 |
| 23 | Got-away detection: `ERR_FISH_ESCAPED` arrives as LOG-R6 expects (first checked on the beta in M1) | LOG-R6 |
| 24 | Which catalogue facts rest on beta builds only (`scripts/generate-data.py --min-build <first live build>`) | DATA-R46, DATA-R57 (may raise the minimum confirming build) |
| 25 | The Paste string's copy test: `/pagle dev pastetest 64`, then 128, 256 and 512, each copied out of the export window with Ctrl+C and pasted into a text editor; it survives when its length is that many KB × 1,024 and its last run reads that length less 16 (PST-R60). Report the largest that survives to pagle-backend, whose roadmap raises the Paste part cap only then | PST-R22, PST-R23 (the part size never exceeds the Paste part cap, UPL-R51) |

There is no check 22: it looked for a per-character Self-Found call, and the character table dropped its `selfFound` field ([#363](https://github.com/timemir/wow-fish/issues/363), LOG-R26), so `/pagle dev probe` no longer reads `C_GameRules`. The other checks keep their numbers, which the launch tickets cite.

### Before the tag

1. Set every Standing Hunt's `since` to the release day (DATA-R87), and the fallback rotation's starting point to the release day at 15:00 UTC (HNT-R152). The companion hint switch is on, and Get it's address is `https://pagle.app/download` (HNT-R170, HNT-R172).
2. Run `scripts/generate-data.py --lock` for the first `released.lock`, in the release commit (DATA-R73, DATA-R95).
3. From the tag on, the entry formats (LOG-R17), the `Pagle` API (CORE-R15: Activity XP, pushed content and fix A's motion API included) and each DB's first `schemaVersion` are frozen.

## After 1.0

On the roadmap but not specified: custom Journal art (1.0 uses in-client textures, shared with the Hunts board and the Stats window), translations (1.0 is enUS only, with every string in `ns.L` from M0), QoL's recast reminder, and the post-launch Hunts (the Fishing Trip quest, Chef's Knife, the Rack and Hut contents), each with its own `since` date.
