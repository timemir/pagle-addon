# Multi-addon architecture: how Core and Modules are wired

Research for [#3](https://github.com/timemir/pagle-addon/issues/3). The question: how do established multi-addon packages structure an always-loaded Core and separately installable Modules on the Retail API, and what shape should Pagle use?

Researched 2026-10-11. All addon claims come from the addons' own source at the commits pinned below. TOC and API claims come from Warcraft Wiki (the community API reference that Blizzard UI developers maintain) and Blizzard's own FrameXML source. Anything I could not trace to a primary source is marked **unverified**.

## Sources and pinned versions

| Source | Version read | What it was used for |
|---|---|---|
| [DeadlyBossMods/DeadlyBossMods](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/31e47d6) | commit `31e47d6` | Core + LoD mod packs, mod discovery via TOC metadata, per-mod SavedVariables, callbacks |
| [BigWigsMods/BigWigs](https://github.com/BigWigsMods/BigWigs/tree/aee9c4f) | commit `aee9c4f` | Tiny always-loaded loader + LoD core/plugins/options, message bus, packaging |
| [tukui-org/ElvUI](https://github.com/tukui-org/ElvUI/tree/e133c05) | commit `e133c05` | Core + LoD options addon, plugin library, DB conversions, Forever TOC conditions |
| [WeakAuras/WeakAuras2](https://github.com/WeakAuras/WeakAuras2/tree/cbbdaac) | commit `cbbdaac` | LoD options addon, LoD "archive" data addon, per-record migrations |
| [r-log/FishingBuddy](https://github.com/r-log/FishingBuddy/tree/fedacff) (community fork of Sutorix's Fishing Buddy) | commit `fedacff` | Fishing-addon plugin API |
| [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Settings_Shared) (mirror of Blizzard FrameXML) | `live` @ `09b9db7`, build 12.1.0 (69933) | Settings API implementation and Blizzard's own implementation guide |
| Warcraft Wiki: [TOC format](https://warcraft.wiki.gg/wiki/TOC_format), [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process), [Saving variables](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions), [C_AddOns.LoadAddOn](https://warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn), [C_AddOns.GetAddOnInfo](https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnInfo), [C_AddOns.GetAddOnLocalTable](https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnLocalTable), [Using the AddOn namespace](https://warcraft.wiki.gg/wiki/Using_the_AddOn_namespace), [Settings API](https://warcraft.wiki.gg/wiki/Settings_API), [Addon Categories](https://warcraft.wiki.gg/wiki/Addon_Categories) | fetched 2026-10-11 | TOC directives, load order, SavedVariables rules |
| [TSM 4 release post](https://blog.tradeskillmaster.com/?p=372) (TSM team blog, 2018-07-28) | n/a | Why TSM merged its modules (TSM's source isn't public) |
| [Blizzard forum thread "UI/Addon settings wiped on client restart"](https://us.forums.blizzard.com/en/wow/t/2353992) (Forever Beta Discussion) | posts 2026-09-18 to 2026-09-25 | Forever beta SavedVariables bug |

**Version caveat.** Forever 1.60.1 "includes all Modern changes up to 12.1.5" ([TOC format, Patch changes › Forever](https://warcraft.wiki.gg/wiki/TOC_format#Patch_changes)). The Blizzard Settings source I read is 12.1.0. Small API drift between 12.1.0 and 12.1.5 is possible.

## TL;DR

- **Each established package is several addon folders shipped in one zip.** The Core is always loaded. Each Module declares `## Dependencies: <Core>` in its TOC. The client then refuses to load a Module whose Core is missing or disabled (`DEP_MISSING` / `DEP_DISABLED`), and a disabled Module never runs any code. That is the "leave nothing loaded" guarantee, and it comes free from the client.
- **Modules talk to Core through one public global table plus a callback bus.** Examples: `DBM`, `BigWigsLoader`, `ElvUI`, and Fishing Buddy's `FishingBuddyApi-1.0` LibStub library. Nobody in this set uses AceEvent/AceAddon messaging for the Core↔Module seam. DBM and BigWigs each hand-roll a roughly 40-line bus. Both run every listener through `securecall`/`securecallfunction`, so one Module's error can't break the others.
- **Each Module owns its own SavedVariables, declared in its own TOC.** DBM mod packs declare `DBM<Pack>_AllSavedVars`. WeakAuras keeps a separate `WeakAurasArchive` addon just to hold bulk data. Shared data lives in the Core's SavedVariables. Migrations are ordered `if version < N then … end` steps keyed on a stored version (WeakAuras `internalVersion`, ElvUI `dbConverted`).
- **None of DBM, BigWigs, ElvUI or WeakAuras builds its main options in Blizzard's Settings panel.** Each ships a load-on-demand options addon with its own window. The Settings API does support what we want: one root category plus a subcategory per Module, added later by `Settings.GetCategory(parentID)` + `Register*Subcategory`. Ace3's `AddToBlizOptions` does exactly this.
- **Recommendation for Pagle:**
  - `Pagle` (Core, always loaded) owns catch observation, the account-wide Catch log, the Angler, content data, the event bus, module registration and the root Settings category.
  - `Pagle_Ledger`, `Pagle_Hunts`, `Pagle_TackleBoard`, `Pagle_QoL` and `Pagle_Stats` are normally loaded addons with `## Dependencies: Pagle` and `## Group: Pagle`. Each owns its own `SavedVariables`, its own schema version and its own Settings subcategory.
  - Modules derive their state from Core's Catch log. Disabling and later re-enabling a Module therefore loses nothing.
- **Two Forever findings that affect other tickets.** (1) The Forever beta has had a client bug where SavedVariables are written but **not read back** on a fresh client start. It was unresolved in the last posts I could read (2026-09-25). (2) Forever character names are handled differently: ElvUI formats them as "First Last", and DBM re-reads the player name after load. Key per-character data by **GUID**, never by name-realm.

## 1. How each package is shaped

| Package | Always-loaded part | Separately installable parts | How parts are found and loaded |
|---|---|---|---|
| **DBM** | `DBM-Core` (`LoadOnDemand: 0`) plus `DBM-StatusBarTimers`, which Core requires ([DBM-Core.toc](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/DBM-Core.toc)) | `DBM-GUI` (LoD options), content packs like `DBM-Raids-Midnight` (`LoadOnDemand: 1`, `RequiredDeps: DBM-Core`) ([DBM-Raids-Midnight.toc](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Raids-Midnight/DBM-Raids-Midnight.toc)) | At login Core loops `C_AddOns.GetNumAddOns()`. It keeps addons that carry `X-DBM-Mod` metadata and are enabled for this character (`GetAddOnEnableState(i, playerGUID)`), then reads `X-DBM-Mod-MapID`, `X-DBM-Mod-MinCoreRevision` and so on. `DBM:LoadMod` later calls `C_AddOns.LoadAddOn` when you enter the zone ([DBM-Core.lua L1895–1947](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/DBM-Core.lua#L1895-L1947), [Loading.lua L250–292](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/modules/Loading.lua#L250-L292)) |
| **BigWigs** | `BigWigs`, a small loader with only libs, locales and `Loader.lua` (the released layout; the repo TOC also inlines everything for dev builds) | `BigWigs_Core`, `BigWigs_Plugins`, `BigWigs_Options` and one addon per raid, all `LoadOnDemand: 1` with `Dependencies: BigWigs` ([BigWigs_Plugins.toc](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/Plugins/BigWigs_Plugins.toc)) | The loader reads `X-BigWigs-LoadOn-CoreEnabled`, `-InstanceId`, `-Slash` and `X-BigWigs-Minimum` from each enabled addon's TOC ([Loader.lua L944–1010](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/Loader.lua#L944-L1010)). The packager's `move-folders` splits one repo into those folders ([.pkgmeta](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/.pkgmeta)) |
| **ElvUI** | `ElvUI` (`RequiredDeps: ElvUI_Libraries`) | `ElvUI_Options` (`LoadOnDemand: 1`, notes "Does not store any profile data") and third-party plugins registered through `LibElvUIPlugin-1.0` ([ElvUI.toc](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/ElvUI.toc), [ElvUI_Options.toc](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI_Options/ElvUI_Options.toc)) | Core loads Options on demand when you open config ([Config.lua L1627–1645](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/Game/Shared/General/Config.lua#L1627-L1645)). ElvUI's own modules are internal: they call `E:RegisterModule` inside the one addon ([Core.lua L1971](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/Game/Shared/General/Core.lua#L1971)) |
| **WeakAuras** | `WeakAuras` | `WeakAurasOptions`, `WeakAurasTemplates`, `WeakAurasModelPaths`, `WeakAurasArchive` (all LoD, `Dependencies: WeakAuras`) | Core calls `C_AddOns.LoadAddOn("WeakAurasArchive")` only when archived data is needed ([WeakAuras.lua L1210–1231](https://github.com/WeakAuras/WeakAuras2/blob/cbbdaac/WeakAuras/WeakAuras.lua#L1210-L1231)). **Note:** at this commit the repo ships only `_Vanilla/_TBC/_Wrath/_Cata/_Mists` TOCs, with no Mainline or Camelot TOC. WeakAuras does not load on Retail or Forever |
| **TSM** | n/a | n/a | TSM 4 deliberately **merged** its separate module addons into one: "merged all of the TSM modules in to one core addon… you no longer have to separately keep track of multiple addons and their different versions", for accessibility to new users ([TSM blog](https://blog.tradeskillmaster.com/?p=372)) |
| **Fishing Buddy** | `FishingBuddy` (single addon; the fork's TOC lists `Interface: 120007, 120100`, not 16001) | Separate plugin addons over the years (`FB_Broker`, `FB_TrackingFrame`, `FB_OutfitDisplayFrame`), per its changelog ([changes.txt](https://github.com/r-log/FishingBuddy/blob/fedacff/changes.txt)) | Plugins call a versioned LibStub library, `FishingBuddyApi-1.0` ([FishingBuddyAPI.lua](https://github.com/r-log/FishingBuddy/blob/fedacff/FishingBuddyAPI.lua)), and hook a custom event bus, `RegisterHandlers`/`RunHandlers` ([FishingBuddy.lua L1037–1058](https://github.com/r-log/FishingBuddy/blob/fedacff/FishingBuddy.lua#L1037-L1058)) |

What this means for us:

- DBM and BigWigs use LoD because they have dozens of content packs and only one is needed per zone. Our Modules are few and need to watch fishing from login, so plain `Dependencies` with normal load fits better.
- LoD still suits heavy UI that is only opened sometimes, following DBM-GUI, ElvUI_Options and WeakAurasOptions.
- TSM is the counter-example. More addons means more version skew and more setup friction for users. That cost is the reason for the min-Core-version guard below.

## 2. TOC dependencies, and what disabling does

From [TOC format](https://warcraft.wiki.gg/wiki/TOC_format):

- **`## Dependencies:`** (aliases `RequiredDeps`, any word starting `Dep`): "Addons that must load first."
- **`## OptionalDeps:`**: "Addons that must load first if available."
- **`## LoadOnDemand: 1`**: "delay loading until `C_AddOns.LoadAddOn` is called."
- **`## LoadWith:`**: "Addons that, once loaded, will trigger this one to load. Also causes this addon to behave as LoadOnDemand."
- **`## LoadManagers:`**: makes the addon LoD if a named manager is present.
- **`## DefaultState: disabled`**: the user must explicitly enable the addon.
- **`## Group:`** (11.1.0+): "Grouped addons are displayed in the AddOn List as indented sub-lists". The value must be the main addon's name. If omitted, the client auto-groups addons whose name has another addon's name as a prefix *and* that have a dependency relation with it. DBM sets `## Group: DBM-Core` on its parts.
- **`## Category:`** (11.1.0+): a collapsible header in the AddOn List. Use the translated names from [Addon Categories](https://warcraft.wiki.gg/wiki/Addon_Categories), which include `Professions`.
- **`## AllowLoadGameType:` / `## ExcludeLoadGameType:`**, plus inline `[AllowLoadGameType …]` on any line. Forever's game type is `camelot`, with `forever` as an alias suffix. The wiki warns: "If at least 1 game type is specified and none of the game types are recognized by the client, the condition will be satisfied", so pair Allow with Exclude. ElvUI does exactly this: `Game\load_forever.xml [AllowLoadGameType camelot][ExcludeLoadGameType standard, classic]` ([ElvUI.toc L40](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/ElvUI.toc#L40)).
- **`## LoadSavedVariablesFirst: 1`** (11.1.5+): SavedVariables load before the addon's files instead of after. BigWigs' loader uses it ([BigWigs.toc](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/BigWigs.toc)).
- **`## AllowAddOnTableAccess: 1`** (11.1.7+): lets other addons fetch this addon's private namespace via `C_AddOns.GetAddOnLocalTable(name)`.
- **`## AddonCompartmentFunc:`**: a global function called when the addon's minimap compartment entry is clicked. ElvUI uses it.
- **`Bootstrap`** inline directive (12.1.0+, listed for Forever): "Restricts the addon directive or file to the bootstrap process for LoadOnDemand addons." Its semantics aren't documented further, so don't rely on it.

**When a Module is disabled in the AddOn List:**

- The client doesn't load it. None of its files run, and none of its SavedVariables are loaded into memory.
- For an addon whose dependency is disabled or missing, `C_AddOns.GetAddOnInfo` reports `loadable = false` with reason `DEP_DISABLED` / `DEP_MISSING`. The full list of reason codes is on [GetAddOnInfo](https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnInfo).
- So a Module can't load without its Core if the TOC declares the dependency.
- Enable state is per character. BigWigs warns that `GetAddOnInfo`'s state "only works when disabled on ALL characters" and uses `GetAddOnEnableState(name, myGUID) == 2` instead ([Loader.lua L966](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/Loader.lua#L966)). DBM does the same with `playerGUID`.
- **Unverified:** I found no primary source stating that the client leaves a disabled addon's SavedVariables file untouched on disk. It is the widely relied-on behaviour, and the WTF layout puts one file per addon. Add it to the beta probe.

## 3. How Modules talk to Core

Patterns seen:

1. **One public global table as the API.** Examples: `DBM`, `BigWigsLoader`/`BigWigsAPI`, `ElvUI` (unpacked as `E, L`). Private state stays in the per-addon namespace, `local addonName, ns = ...` ([Using the AddOn namespace](https://warcraft.wiki.gg/wiki/Using_the_AddOn_namespace)).
   - The newer alternative is `AllowAddOnTableAccess` + `C_AddOns.GetAddOnLocalTable`. None of the studied addons use it, and it exposes the whole private table.
2. **A callback/message bus owned by Core.**
   - DBM: `DBM:RegisterCallback(event, f)` / `DBM:FireEvent(event, …)`. Each listener is called through `securecall(v, event, …)` ([DBM-Core.lua L2290–2339](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/DBM-Core.lua#L2290-L2339)).
   - BigWigs: `public.RegisterMessage(module, event, fn)` / `public:SendMessage(event, …)`, each listener run through `securecallfunction` ([Loader.lua L1648–1673](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/Loader.lua#L1648-L1673)).
   - Calling listeners this way means one listener's Lua error is reported but doesn't stop the loop.
   - Fishing Buddy's `RunHandlers` calls `func(...)` directly, so one plugin error aborts the rest ([FishingBuddy.lua L1052–1059](https://github.com/r-log/FishingBuddy/blob/fedacff/FishingBuddy.lua#L1052-L1059)).
3. **"When Core is ready" registration.** DBM exposes `DBM:RegisterOnLoadCallback(cb)`. It runs `cb` immediately if Core has finished `ADDON_LOADED`, and queues it otherwise ([DBM-Core.lua L1774–1781](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/DBM-Core.lua#L1774-L1781)). ElvUI's `E:RegisterModule(name, func)` does the same: it queues before `E.Initialized` and calls immediately after ([Core.lua L1969–1981](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/Game/Shared/General/Core.lua#L1969-L1981)). This makes Module code independent of exact load timing.
4. **Registration with a version contract.**
   - DBM mod packs declare `X-DBM-Mod-MinCoreRevision`. Core refuses to load a pack that is too new and prints a mismatch message ([Loading.lua L260–265](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/modules/Loading.lua#L260-L265)).
   - BigWigs reads `X-BigWigs-Minimum` and shows a popup plus a raid warning.
   - `LibElvUIPlugin:RegisterPlugin(name, optionsCallback, isLib, version)` returns early if the plugin addon isn't loaded. It calls the options callback when `ElvUI_Options` loads ([LibElvUIPlugin-1.0.lua L107–150](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI_Libraries/Game/Shared/LibElvUIPlugin-1.0/LibElvUIPlugin-1.0.lua#L107-L150)).
5. **A versioned library as a stable plugin surface.** Fishing Buddy publishes `LibStub:NewLibrary("FishingBuddyApi-1.0", minor)` so plugins depend on a frozen interface rather than internals.

## 4. SavedVariables

Rules ([Saving variables](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions), [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process)):

- `## SavedVariables` is per account: `WTF\Account\ACCOUNTNAME\SavedVariables\AddOnName.lua`. `## SavedVariablesPerCharacter` is per character, under the realm and character folders. Each addon gets its own file, named after the addon that declares the variable.
- SavedVariables load after the addon's last file (unless `LoadSavedVariablesFirst`), then `ADDON_LOADED(addonName)` fires. That is "the earliest time for an AddOn to read its saved variables."
- Only strings, numbers, booleans and tables are saved. Two variables that reference the same table come back as separate copies.
- Files are written on logout, reload and quit, not on a crash or Alt-F4. `PLAYER_LOGOUT` is the last chance to edit them.
- `SAVED_VARIABLES_TOO_LARGE` fires if the client runs out of memory while loading them.
- "Account" here is the WoW game account folder under WTF. Two WoW licences on one Battle.net login are separate folders.

Patterns seen:

- **SavedVariables per Module, declared in the Module's TOC.** DBM packs declare `DBMRaidsMidnight_AllSavedVars`. Core builds the name by convention (`modId:gsub("-", "") .. "_AllSavedVars"`) and reads and writes that global after `LoadAddOn` ([CoreOptions.lua L694–701](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/modules/objects/CoreOptions.lua#L694-L701)). The data lives in the pack's file, so a disabled pack's data is neither loaded nor written.
- **Shared and global settings live in Core's SavedVariables.** Examples: `DBM_AllSavedOptions`, `ElvDB`/`ElvPrivateDB`, `BigWigs3DB`, `WeakAurasSaved`.
- **The options addon stores nothing.** ElvUI_Options says so in its TOC Notes. WeakAurasOptions only keeps window state in `WeakAurasOptionsSaved`.
- **Bulk data goes in a separate LoD "archive" addon.** `WeakAurasArchive` exists only to hold the `WeakAurasArchive` SavedVariable, and is loaded on first access.
- **Migrations.**
  - WeakAuras stamps every record with `internalVersion`. `Private.Modernize` runs ordered `if data.internalVersion < N then … end` steps, then sets the current version ([Modernize.lua L14–35, L2502](https://github.com/WeakAuras/WeakAuras2/blob/cbbdaac/WeakAuras/Modernize.lua#L14-L35)).
  - ElvUI stamps the DB once per release: `if E.db.dbConverted ~= E.version then … E:DBConvert…() end` ([Core.lua L1995+](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/Game/Shared/General/Core.lua#L1995)).

## 5. One options UI across Modules (Settings API)

Facts from Blizzard's source ([Blizzard_Settings.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua), [Blizzard_ImplementationReadme.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua)):

- Root categories are created with `Settings.RegisterVerticalLayoutCategory(name)` (auto-laid-out controls) or `Settings.RegisterCanvasLayoutCategory(frame, name)` (your own frame). Both return `category, layout`.
- Subcategories are created with `Settings.RegisterVerticalLayoutSubcategory(parent, name)` or `Settings.RegisterCanvasLayoutSubcategory(parent, frame, name)`. Per the readme, "the parent category type is interchangeable", so you can mix vertical and canvas.
- `Settings.RegisterAddOnCategory(category)` adds a root to the AddOns tab.
- Settings are created with `Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type, name, default)`, which writes straight into your SavedVariables table, or `Settings.RegisterProxySetting(…, getValue, setValue)`. Controls are created with `Settings.CreateCheckbox` / `Settings.CreateSlider` and similar.
- `Settings.OpenToCategory(categoryID)` now forwards to `C_SettingsUtil.OpenSettingsPanel(categoryID, …)`, so pass `category:GetID()`. Ace3 notes that overriding the ID with a name string "is no longer possible" with the 12.0 API changes ([AceConfigDialog-3.0.lua L2185–2188](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI_Libraries/Game/Shared/Ace3/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua#L2185-L2188)).
- Registration goes through `SettingsInbound`, which forwards calls via a secure attribute delegate. It creates subcategories with `securecallfunction` "to avoid taint" ([Blizzard_SettingsInbound.lua L181–199](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsInbound.lua#L181-L199)). The public API is the taint-safe path. Hooking `SettingsPanel` internals, as ElvUI does for keybinds, is not.
- **Adding subcategories after the root is registered works.** Ace3's `AddToBlizOptions(app, name, parent)` looks up `Settings.GetCategory(parentID)` and calls `Settings.RegisterCanvasLayoutSubcategory` at whatever time a later addon calls it ([AceConfigDialog-3.0.lua L2171–2178](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI_Libraries/Game/Shared/Ace3/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua#L2171-L2178)). A disabled Module never runs, so its subcategory never appears.
- None of DBM, BigWigs, ElvUI or WeakAuras puts its real options in the Settings panel. They use their own windows, loaded on demand. That suits huge option trees. Our settings are small, and the map asks for a native Retail look, so the Settings panel is the right home. The journal, Hunts and Stats views are separate frames.

## 6. Pitfalls

- **Load order.**
  - Dependencies load first, but code at file scope in a Module must not read Core's SavedVariables. Core's `ADDON_LOADED` work, such as migrations and defaults, is the only safe gate. Use a DBM/ElvUI-style "run now or when ready" registration instead of assuming timing.
  - Calling `C_AddOns.LoadAddOn` inside an `ADDON_LOADED` handler "may result in the named addon never receiving its own ADDON_LOADED event" ([LoadAddOn](https://warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn)).
- **A Module without its Core.** The `Dependencies` directive makes the client refuse it. A cheap `if not Pagle then return end` guard at the top of each Module file still covers a broken install with a renamed folder.
- **A Module newer than its Core.** Version skew happens with separate installs (the TSM lesson). Use a TOC metadata minimum, like DBM's `X-DBM-Mod-MinCoreRevision`, and refuse with a clear chat message.
- **Don't re-enable what the user disabled.** BigWigs and ElvUI call `EnableAddOn` on their own required parts before `LoadAddOn` ([Loader.lua L827](https://github.com/BigWigsMods/BigWigs/blob/aee9c4f/Loader.lua#L827), [Config.lua L1637](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/Game/Shared/General/Config.lua#L1637)). Pagle must never do this to a Module, because the user disabling it is the feature.
- **Taint.**
  - Keep everything in `local`s plus one global API table, with no accidental globals.
  - Use only public Settings functions.
  - Don't create or modify secure frames in combat. ElvUI refuses to open options in combat and queues the open instead (`E:AlertCombat` → `E.ShowOptions = true`).
  - The QoL Module's secure action buttons must be built out of combat. That is fine at login, but not inside a lazily loaded Module.
- **Error isolation.** Dispatch Core events through `securecallfunction` so a bug in Stats can't stop Ledger from receiving a Catch.
- **Enable state is per character.** Use `C_AddOns.GetAddOnEnableState(name, UnitGUID("player"))`, not `GetAddOnInfo`'s state.

## 7. Forever-specific findings

- **Major addons already target Forever with a single TOC.**
  - DBM, BigWigs and ElvUI all list `16001` in a comma-separated `## Interface:`.
  - They use inline `[AllowLoadGameType …]` per file rather than a separate `_Camelot.toc`. BigWigs even loads `Init_[Game].lua`, which resolves to `Init_Camelot.lua` and sets `isForever = true`.
  - Detection is `WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)` ([GameVersion.lua L14](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/modules/objects/GameVersion.lua#L14); ElvUI `Initialize.lua` L110). This confirms the baseline's "don't detect by build number" warning.
- **Character names differ on Forever.**
  - ElvUI builds Forever names as `"First Last"` from `UnitNameUnmodified`'s second return, and comments `-- forever "First Last" otherwise "First"` ([Core.lua L70–71, L222–230](https://github.com/tukui-org/ElvUI/blob/e133c05/ElvUI/Game/Shared/General/Core.lua#L70-L71)).
  - DBM uses `GetUnitName("player")` on Forever and fires `DBM_PlayerNameChanged` when the name is reconciled after load ([GameVersion.lua L16–30](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/31e47d6/DBM-Core/modules/objects/GameVersion.lua#L16-L30)).
  - I haven't seen the exact semantics (surname? realm?) documented by Blizzard, so this is inferred from code. Either way: **key characters by GUID**.
- **Beta SavedVariables bug.**
  - On Forever beta build 1.60.1.69913, many players reported that SavedVariables are written to disk but "the client never reads any of those files back when the UI loads". `/reload` sometimes survives; a full client restart doesn't.
  - Reports were still coming in after a 2026-09-22 client patch ("No changes after yesterday's client patch. Still a bug.", 2026-09-23). No Blizzard reply was visible in the posts I read, which end on 2026-09-25 ([forum thread](https://us.forums.blizzard.com/en/wow/t/2353992)).
  - Workaround addons exist, for example [ForeverSVBridge](https://www.curseforge.com/wow/addons/foreversvbridge), "updated Sep 24, 2026".
  - If this persists to launch, account-wide progression can't persist across sessions. **Status on the current beta build is unknown.**

## 8. Recommendation: Pagle's Core + Modules shape

**Folders, all shipped in one zip from one repo** (the BigWigs/DBM `move-folders` approach; details belong to the Distribution ticket):

```
Pagle/                 Core, always loaded
Pagle_Ledger/          Module
Pagle_Hunts/           Module
Pagle_TackleBoard/     Module
Pagle_QoL/             Module
Pagle_Stats/           Module
```

**Core TOC** (`Pagle/Pagle.toc`):

```
## Interface: 16001
## AllowLoadGameType: camelot
## ExcludeLoadGameType: standard, classic
## Title: Pagle
## Category: Professions
## Group: Pagle
## SavedVariables: PagleDB
## AddonCompartmentFunc: Pagle_OnCompartmentClick
```

**Module TOC** (`Pagle_Ledger/Pagle_Ledger.toc`):

```
## Interface: 16001
## AllowLoadGameType: camelot
## ExcludeLoadGameType: standard, classic
## Title: Pagle - Ledger
## Category: Professions
## Group: Pagle
## Dependencies: Pagle
## SavedVariables: PagleLedgerDB
## X-Pagle-MinCore: 1
```

- No `LoadOnDemand` for Modules: they need to observe from login. Reserve LoD for a later heavy UI or a bulk "archive" addon, WeakAurasArchive-style, if the Catch log grows large.
- No `SavedVariablesPerCharacter`: progression is account-wide. Per-character facts go inside the account SavedVariables, keyed by GUID. This also gives a future companion app one folder to read.
- Verify the `AllowLoadGameType`/`ExcludeLoadGameType` pair in the beta probe. ElvUI uses exactly this pairing inline for its Forever file.

**What Core owns:**

- Catch observation: `LOOT_READY` + `IsFishingLoot()`, per the baseline.
- The **Catch log**, an append-only list of records in `PagleDB`. Each record has a stable id, a timestamp, the character GUID, the item ID, the zone `mapID` and conditions.
- The Angler profile.
- Static content data: fish, zones and Hunt definitions.
- The event bus, Module registration, the root Settings category, the compartment entry, and Forever detection.
- Migrations for `PagleDB`.

**What each Module owns:**

- Its code, its own `Pagle<Module>DB` SavedVariable with its own `schemaVersion`, and its Settings subcategory.
- Module state should be either (a) user intent that only the Module knows, such as chosen Hunts, Tackle Board goals or QoL keybind choices, or (b) a **projection** of Core's Catch log that can be rebuilt from it, such as Ledger levels and Stats aggregates.
- A disabled Module therefore misses nothing: on re-enable it replays the log from its last-seen Catch id. This is also the sync-ready property, because the log is the source of truth.

**Wiring, as a sketch with names to settle in the Core data-model ticket:**

```lua
-- Pagle/Core.lua
local _, ns = ...
Pagle = {}                         -- the only global: public API
local bus = {}                     -- event -> { fn, ... }
function Pagle.On(event, fn) ... end
local function emit(event, ...)
  for _, fn in ipairs(bus[event] or {}) do securecallfunction(fn, event, ...) end
end
local modules, ready = {}, false
function Pagle.RegisterModule(spec) -- { id, addon, schemaVersion, onReady(api), settings(parentCategory) }
  -- read C_AddOns.GetAddOnMetadata(spec.addon, "X-Pagle-MinCore"); refuse + chat message if too new
  modules[spec.id] = spec
  if ready then spec.onReady(Pagle) end   -- DBM RegisterOnLoadCallback / ElvUI RegisterModule pattern
end
-- On ADDON_LOADED("Pagle"): migrate PagleDB, create root Settings category, ready = true,
-- then call queued onReady(); emit("CATCH", record) for every new Catch.
```

```lua
-- Pagle_Ledger/Ledger.lua
if not Pagle then return end
Pagle.RegisterModule({
  id = "Ledger", addon = "Pagle_Ledger", schemaVersion = 1,
  onReady = function(api) --[[ migrate PagleLedgerDB, replay log since lastCatchId ]] api.On("CATCH", OnCatch) end,
  settings = function(root) local cat = Settings.RegisterVerticalLayoutSubcategory(root, "Ledger") --[[ ... ]] end,
})
```

- **Bus:** hand-rolled like DBM and BigWigs, with `securecallfunction`, and LuaLS `---@class`/`---@param` annotations as DBM uses. That gives the dev typed, testable tooling with no Ace3 dependency. CallbackHandler-1.0 is the off-the-shelf alternative if one is wanted.
- **Settings:** Core registers one vertical-layout root "Pagle" holding Core settings and calls `Settings.RegisterAddOnCategory` on it. Each Module adds one subcategory through its `settings(root)` callback. The compartment click calls `Settings.OpenToCategory(root:GetID())`, never in combat.
- **Migrations:** WeakAuras-style ordered `if db.schemaVersion < N then … end` steps, run once at `ADDON_LOADED`. Core migrates `PagleDB` before calling any Module's `onReady`. Each Module migrates its own DB first thing in `onReady`.

## Open items for the beta probe (HITL)

1. Does the current Forever build read SavedVariables back after a full client restart? (§7)
2. Is a disabled Module's SavedVariables file left untouched on disk across sessions? (§2, unverified)
3. Does a TOC with `AllowLoadGameType: camelot` + `ExcludeLoadGameType: standard, classic` load on Forever, and does `## Group: Pagle` nest the Modules?
4. What do `UnitName`, `UnitNameUnmodified`, `GetUnitName("player")` and `UnitGUID("player")` return on Forever? This decides character keys and display names.
5. On Forever, do subcategories registered from a dependent addon's `ADDON_LOADED` show under the Core's root category in the AddOns settings tab?
