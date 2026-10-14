# Lua toolchain for a multi-addon package on WoW: Forever

Research for issue #2. Checked 2026-10-11 against beta build 1.60.1.70338.

**Question.** What toolchain should a Java backend developer who is new to Lua use to build a Core plus Modules addon package on the Retail/Mainline API that WoW: Forever runs?

## Recommended stack

| Concern | Pick | Forever status |
|---|---|---|
| Language target | Lua 5.1 (the WoW dialect) | Same as Retail |
| Editor | VS Code + LuaLS + Ketho's *WoW API* extension | Annotations are at Mainline 12.0.1. Forever-only APIs are missing. |
| Libraries | LibStub, CallbackHandler, AceAddon/AceEvent/AceDB (+ AceConfig if needed) | **Works.** Ace3 master supports Forever, but the last tagged release predates that support. |
| Minimap / broker | Addon Compartment (TOC directive). LibDBIcon + LibDataBroker only if you want a minimap button. | Compartment applies to Forever. LibDBIcon's TOC lists 16001. |
| Lint | luacheck, `std = "lua51"` plus a WoW globals list | n/a (offline) |
| Format | StyLua with Lua 5.1 syntax | n/a |
| Unit tests | busted on Lua 5.1, with hand-written WoW API stubs | n/a |
| Packaging | BigWigs packager (`BigWigsMods/packager@v2`) + `.pkgmeta` with `move-folders` | **Native Forever support** since 2026-09-17 |
| Publishing | CurseForge + Wago via the packager. Not WoWInterface. | CF and Wago both have a Forever game type. WoWI does not. |
| In-game errors | BugSack + !BugGrabber | TOC lists 16001 |

Each part is explained below. Sources are numbered and listed at the end.

## 1. The Lua environment, and what to unlearn from Java

- WoW runs a **Lua 5.1** environment. Ketho's extension describes its job as "Includes the WoW Lua 5.1 environment".[1] Write and test against 5.1: no `goto`, no integer division `//`, no `utf8` library. Bitwise operations go through WoW's `bit` global, as in BetterBags' `.luacheckrc`.[2]
- There is **no `require`**. The client loads the files listed in the `.toc`, in order. Every file receives `...` = `addonName, addonTable`. The table is "a private table shared between Lua files in the same addon".[3]
- **Consequence for the Core/Module contract:** a Module cannot see Core's private `addonTable`. Core must publish something on purpose, either a single global (for example `WowFish`) or a library registered with LibStub. Modules then reach Core through that one object. In Java terms, that object is Core's public API; everything else is package-private. Design it as an explicit interface.

## 2. Libraries

**Recommendation:** LibStub + CallbackHandler + AceAddon-3.0 + AceEvent-3.0 + AceDB-3.0. Add AceConfig/AceGUI only when Modules need options panels. Use AceDB rather than hand-rolling SavedVariables.

Evidence that they work on Forever:

- **Ace3** (`WoWUIDev/Ace3`, last push 2026-10-02). `Ace3.toc` lists interface `16001` among its versions.[4] Recent commits are Forever-specific:[5]
  - 2026-09-17 "AceDB-3.0: Compatibility with WoW Forever"
  - 2026-09-18 "Swap UnitName for UnitNameUnmodified. Fix compatibility with WoW Forever's latest beta update (once again includes the surname in the profile)"
  - 2026-09-25 "Remove `realmKey` from `charKey` in WoW Forever as names are unique across all rulesets (PvE/PvP/etc)"
  - 2026-10-02 "AceGUI-3.0: ColorPicker: Fix alpha being inverted in Forever"
- **Caveat: tagged releases are stale.** The newest tag, `Release-r1403`, points at a commit dated 2026-08-12,[6] before all the Forever fixes above. Pull Ace3 from **trunk** in `.pkgmeta` (`https://repos.wowace.com/wow/ace3/trunk/...`), as BetterBags[2] and BugSack[7] do. Do not pin to the last tag.
- **Forever character identity differs from Retail.** AceDB's code now checks `RegionalUniqueNamesEnabled()`. When it returns true, the realm key becomes the ruleset ("Hardcore", "RP", "PvP" or "PvE") and the character key becomes `name .. " " .. surname`, with no realm.[8] Forever's API dump contains `RegionalUniqueNamesEnabled`.[9] Any code of ours that builds `"Name - Realm"` keys would be wrong on Forever. Using AceDB keeps us out of that trap.
- **LibDBIcon-1.0.** The WoWAce trunk TOC lists `16001`. The trunk bundles LibDataBroker-1.1, CallbackHandler and LibStub.[10] LibDataBroker itself (`tekkub/libdatabroker-1-1`) last changed in 2015. It is stable and still the ecosystem standard; DBM pulls it from that repo.[11]
- **Addon Compartment** is a TOC-level alternative to a minimap button and "applies to Midnight and Forever".[12] It needs no library.
- **CallbackHandler** is the standard way for Core to fire events that Modules subscribe to. It suits a DBM-style Core that publishes "catch recorded" style messages. DBM bundles it.[11]

Alternative: **no framework.** Raw `CreateFrame` + `RegisterEvent`, with SavedVariables handled by hand. This means fewer moving parts, but you must handle the Forever character-key and surname rules yourself, and you lose AceDB profiles. Not recommended for a beginner.

## 3. Editor support

- **LuaLS** (`LuaLS/lua-language-server` 3.19.1, 2026-08-13)[13] + **Ketho's WoW API extension** (`Ketho/vscode-wow-api` 0.22.3, 2026-02-24).[1][14] The extension loads automatically for any folder with a `.toc`. It ships Blizzard's generated API docs, Warcraft Wiki docs, widgets, events, enums and CVars.[1]
- **Coverage gap.** The extension's README badges say *mainline 12.0.1*, and its changelog's last entry is "Updated Types and Widget/ScriptObject APIs for 12.0.1".[1][14] It does not mention Forever, Camelot or 16001. The Warcraft Wiki says Forever 1.60.1 "includes all Modern changes up to 12.1.5".[12] So:
  - the 12.0.1 annotations cover most of what we call;
  - APIs added between 12.0.1 and 12.1.5 are missing, and so are Forever-only APIs.
- **Concrete gaps that matter to us.** Ketho's `forever` branch of BlizzardInterfaceResources (dump of 1.60.1 build 70338, 2026-10-11) lists `C_Weather.GetCurrentWeather`, which is **not** in the `live` (Retail) dump. It also lists `C_GameRules.GetForeverExperiencePreset`.[9][15] Neither is in the extension. Write a small local annotation file (`---@meta`) for the handful of Forever-only calls we use. The `forever` branch is the source of truth for whether a function exists.
- The Forever FrameXML source is mirrored at `Gethe/wow-ui-source`, branch `forever` (version `1.60.1.70338`).[16]
- **Alternative for an IntelliJ user:** `emmylua_ls` (EmmyLuaLs/emmylua-analyzer-rust). It speaks standard LSP to IntelliJ, VS Code and Neovim, supports Lua 5.1, and reads `.luarc.json` and LuaCATS annotations.[17] Ketho's annotations are LuaCATS-format, so this should work, but it is less trodden than VS Code + LuaLS. Untested here.

## 4. Linting and formatting

- **luacheck** (`lunarmodules/luacheck` v1.2.0, 2024-05-24; repo active 2026-07).[13] Use `std = "lua51"` ("globals of Lua 5.1 without deprecated ones").[18] luacheck knows nothing about WoW, so the `.luacheckrc` needs a `read_globals` list of WoW APIs. BetterBags maintains such a list by hand and ignores `212/self`.[2] LuaLS with the WoW extension already flags unknown globals in the editor, so luacheck mainly serves CI.
- **StyLua** (v2.6.0, 2026-10-10).[13] It formats "Lua 5.1, 5.2, 5.3, 5.4, LuaJIT, Luau". Release binaries enable all syntax variants by default. Select Lua 5.1 in `.stylua.toml` so it never accepts 5.2+ syntax that WoW would reject.[19]

## 5. Unit testing outside the client

- **busted** (`lunarmodules/busted` v2.3.0, 2026-01-07) "Supports Lua >= 5.1, luajit >= 2.0.0".[13][20]
- **Run tests on Lua 5.1**, matching the client. Forever-addon-kit's ForeverCDM runs its tests on Lua 5.4,[21] but 5.4 accepts syntax WoW rejects.
- **There is no canonical WoW API mock library.** The working pattern, as in BetterBags, is a `spec/setup.lua` busted helper (`.busted` → `helper = "spec/setup.lua"`) that stubs `CreateFrame`, `C_*` tables and the WoW globals the code touches. CI uses `leafo/gh-actions-lua` (5.1) + `gh-actions-luarocks` + `luarocks install busted luacov`.[2] Note the related claim in a BetterBags summary: missing mocks should be written from Blizzard's UI source (an indexed copy, not checked first-hand).[22]
- **Design advice:** keep game-independent logic in plain functions that take inputs and return values. Examples: catch classification, hunt-condition evaluation, XP curves and record keeping. These test cleanly in busted. Keep a thin event/frame adapter that stays untested or is tested in-game. Java's hexagonal habits fit this well.
- In-game alternative: WoWUnit (Jaliborc/WoWUnit), which runs tests inside the client.[22] Useful for checking real API behaviour on the beta. Not a substitute for CI.

## 6. Packaging: BigWigs packager, `.pkgmeta`, TOC files

**The packager supports Forever natively.**
- Commit "Add WoW Forever support (#202)" landed 2026-09-17. "Allow Forever interface versions in `Mainline` toc files" followed on 2026-10-07.[23] The latest release is v2.6.1 (2026-09-18).[13]
- `release.sh` maps any interface `16???` to game type `forever`. It treats `camelot` as an alias of `forever`, and it recognises `_Camelot.toc` and `-Camelot.toc` suffixes.[24]

**TOC naming and loading (Warcraft Wiki).**[12]
- Forever's game types are `forever` and `camelot`, with suffixes `AddOnName_Forever.toc` and `AddOnName_Camelot.toc`. The wiki warns: "The Camelot value may be changed to Forever in the future."
- `_Mainline.toc` is a *family* suffix shared by Retail and Forever. It has lower priority than game-type suffixes. The client falls back to `AddOnName.toc`.
- Per-file inline conditions work, for example `File.lua [AllowLoadGameType camelot]`. A Forever-only example is in the packager README.[25] The wiki warns that an unrecognised game type still satisfies the condition, so pair it with `ExcludeLoadGameType`.[12]
- `## Interface:` accepts comma-separated values. The packager README's example ends in `120100, 16001`.[25] The wiki lists `16001` only for Forever **Beta**; no live value is published yet.[12] **Expect the interface number to change at or after launch on 2026-11-04.**

**Recommendation for us:**
- Use **one plain `<Addon>.toc` per addon** with `## Interface: 16001`. Add the Retail number later if we ship the Retail profile.
- Do **not** create `_Camelot.toc` files unless a Module needs a Forever-only file list. They double maintenance, and the suffix name may change. Inline `[AllowLoadGameType ...]` covers per-file differences.
- In Lua, detect Forever with `WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`. The wiki documents `WOW_PROJECT_CAMELOT = 18`.[26] Guard against nil, because the constant does not exist on other clients.
- **Never use interface or build thresholds** for detection. ForeverAddonKit documents that `select(4, GetBuildInfo()) >= 100000` fails on Forever, which reports 16001.[21]

**Multi-addon package: copy DBM.** DBM ships many addons from one repo and one zip:[11]
- `.pkgmeta` declares `package-as: DBM-Core`, shared `externals:` (libraries) and `move-folders:`, for example `DBM-Core/DBM-GUI: DBM-GUI`. Each sub-addon folder becomes a top-level folder in the zip.
- Each sub-addon TOC carries `## Category: DBM` and `## Group: DBM-Core`. The AddOns list then nests the Modules under Core. The wiki: "Grouped addons appear as indented sub-lists".[12]
- DBM's TOCs use a single plain `.toc` with `## Interface: 11509, 16001, 20506, ...`. There is no Camelot-suffixed TOC.[11]
- Modules declare `## Dependencies: <Core>`. Options-only or rarely used Modules can be `## LoadOnDemand: 1` or use `## LoadWith:`.[12]

Mapped onto us:
- the repo root holds `WowFish_Core/`, `WowFish_Ledger/`, `WowFish_Hunts/`, …;
- `.pkgmeta` has `move-folders` entries for each;
- libraries are embedded once, in Core, via `externals:`;
- Modules do not re-embed libraries; they get them through LibStub after Core loads.

## 7. Publishing to CurseForge / Wago

- Put `## X-Curse-Project-ID:` and `## X-Wago-ID:` in the TOC. Set `CF_API_TOKEN` and `WAGO_API_TOKEN` as GitHub secrets. Run `BigWigsMods/packager@v2` on tag push.[25]
- **CurseForge:** the packager maps `forever` to CurseForge game-version type `88568`.[24]
- **Wago:** Wago's public game API lists a `forever` flavor with patch `1.60.1`, and it accepts `-Camelot`, `_Camelot`, `-Forever` and `_Forever` TOC suffixes.[27]
- **WoWInterface:** the packager prints "No WoWInterface game type match … \"forever\" is not supported, ignoring".[24] Skip WoWI.
- ForeverAddonKit's 09-24 note that "no addon site has a Forever flavour yet"[21] is now **out of date**.

## 8. Dev loop against the beta client

- **Install path:** the beta uses the `_classic_beta_` product folder and `WowB.exe`.[21] Symlink each addon folder from the repo into `_classic_beta_/Interface/AddOns/` (Windows `mklink /J`) so edits are live.
- **Reload:** type `/reload`. `ReloadUI()` is protected on Forever, so you cannot bind it from addon code.[21] (Superseded: `ReloadUI()` is unprotected on build 1.60.1.70338, QOL-R102.) Changes to `.toc` files need a full client restart; Lua and XML changes need only `/reload`. (Standard client behaviour, not verified on Forever.)
- **Errors:** BugSack + !BugGrabber (BugSack v12.1.5, 2026-10-10; its TOC lists 16001).[7][13]
- **Error cap:** after 100 Lua errors in a session, the client stops sending them to handlers, so fix error floods first.[21]
- **Unknown events throw:** "Registering an unknown event throws; wrap registration in `pcall`".[21] This matters when sharing code with Retail.
- **API presence check:** diff the addon against the Forever dump (BIR `forever` branch,[15] or ForeverAddonKit's `api_scan.py`[21]) before in-game testing.
- **SavedVariables beta bug (open risk).** From mid-September, the beta wrote SavedVariables on exit but did not read them back at login:
  - Blizzard forum thread, 2026-09-18, reproduced with no addons on build 69913.[28]
  - ForeverAddonKit documents the bug and a "seeds" workaround.[21]
  - ForeverSVFix's README now says "It seems that Blizzard have fixed the issue", with no build cited.[29] A third-party guide dated 10-04 still calls it broken.

  **Verify on the current build first thing.** Until it is confirmed fixed, any persistence test in the dev loop is unreliable across full restarts. It works across `/reload`.

## Forever-specific summary

1. Forever is game type `forever` / `camelot` and `WOW_PROJECT_ID` 18. It shares the `Mainline` family with Retail. Its interface is 16001 (beta), and the number may change at launch.
2. The packager, Ace3 trunk, LibDBIcon trunk, BugSack, DBM, CurseForge and Wago all handle Forever as of October 2026. WoWInterface does not. Ace3's *tagged* release predates its Forever fixes.
3. Character identity on Forever is region-unique name + surname, keyed by ruleset rather than realm. Do not build `Name - Realm` keys.
4. Editor annotations lag. Forever-only APIs such as `C_Weather.GetCurrentWeather` exist in the client but not in the VS Code extension.
5. The SavedVariables-not-loaded beta bug may or may not be fixed. Check before relying on persistence.

## Sources

1. Ketho/vscode-wow-api README — https://github.com/Ketho/vscode-wow-api (raw `master/README.md`)
2. Cidan/BetterBags `.busted`, `.luacheckrc`, `.pkgmeta`, `.github/workflows/test.yml`, `release.yml` — https://github.com/Cidan/BetterBags
3. Warcraft Wiki, Using the AddOn namespace — https://warcraft.wiki.gg/wiki/Using_the_AddOn_namespace
4. WoWUIDev/Ace3 `Ace3.toc` — https://github.com/WoWUIDev/Ace3/blob/master/Ace3.toc
5. WoWUIDev/Ace3 commit history — https://github.com/WoWUIDev/Ace3/commits/master
6. WoWUIDev/Ace3 tag `Release-r1403` → commit d295b12 (2026-08-12)
7. funkydude/BugSack `BugSack.toc`, `.pkgmeta`, release v12.1.5 — https://github.com/funkydude/BugSack
8. Ace3 `AceDB-3.0/AceDB-3.0.lua` key generation (lines ~255–290) — https://github.com/WoWUIDev/Ace3/blob/master/AceDB-3.0/AceDB-3.0.lua
9. Ketho/BlizzardInterfaceResources `forever` branch `Resources/GlobalAPI.lua` — https://github.com/Ketho/BlizzardInterfaceResources/tree/forever
10. WoWAce SVN `libdbicon-1-0/trunk` and `LibDBIcon-1.0.toc` — https://repos.wowace.com/wow/libdbicon-1-0/trunk/
11. DeadlyBossMods/DeadlyBossMods `.pkgmeta`, `DBM-Core/DBM-Core.toc`, `DBM-GUI/DBM-GUI.toc` — https://github.com/DeadlyBossMods/DeadlyBossMods
12. Warcraft Wiki, TOC format — https://warcraft.wiki.gg/wiki/TOC_format
13. GitHub repo/release metadata (api.github.com) for LuaLS, luacheck, StyLua, busted, BigWigsMods/packager, BugSack, vscode-wow-api, fetched 2026-10-11
14. Ketho/vscode-wow-api CHANGELOG.md
15. Ketho/BlizzardInterfaceResources `live` branch `Resources/GlobalAPI.lua` (compared against `forever`); `forever` head commit "1.60.1 (70338)", 2026-10-11
16. Gethe/wow-ui-source branch `forever`, `version.txt` = `1.60.1.70338`
17. EmmyLuaLs/emmylua-analyzer-rust README — https://github.com/EmmyLuaLs/emmylua-analyzer-rust
18. lunarmodules/luacheck `docsrc/cli.rst` (`--std` values)
19. JohnnyMorganz/StyLua README (syntax selection) — https://github.com/JohnnyMorganz/StyLua
20. lunarmodules/busted README — https://github.com/lunarmodules/busted
21. Thunderz96/forever-addon-kit README (build 1.60.1.69893, updated 2026-09-24) — https://github.com/Thunderz96/forever-addon-kit
22. Jaliborc/WoWUnit — https://github.com/Jaliborc/WoWUnit ; BetterBags guidance as indexed at https://tomevault.io/tome/Cidan/BetterBags (secondary)
23. BigWigsMods/packager commit history — https://github.com/BigWigsMods/packager/commits/master
24. BigWigsMods/packager `release.sh` (game_flavor map, `toc_to_type`, CurseForge `game_id=88568`, WoWI forever skip) — https://github.com/BigWigsMods/packager/blob/master/release.sh
25. BigWigsMods/packager README — https://github.com/BigWigsMods/packager
26. Warcraft Wiki, WOW_PROJECT_ID — https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
27. Wago Addons game data API — https://addons.wago.io/api/data/game
28. Blizzard forums, "UI/Addon settings wiped on client restart" — https://us.forums.blizzard.com/en/wow/t/2353992
29. nobewayo/ForeverSVFix README — https://github.com/nobewayo/ForeverSVFix
