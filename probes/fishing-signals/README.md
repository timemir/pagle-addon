# PagleProbe: which fishing signals can the Forever client see?

A throwaway diagnostic addon for [issue #7](https://github.com/timemir/wow-fish/issues/7). You install it in the **WoW: Forever beta**, play through the checklist below, and paste the report back into the issue.

**It is read-only.** It never casts, clicks the bobber, applies lures, loots or takes any other game action. You do all the fishing yourself. The addon only watches and writes notes into its own saved-data file. It also does nothing heavy in combat.

There are two addon folders. Testing the packaging is part of the job:

| Folder | Role |
|---|---|
| `PagleProbe` | The "Core": records everything and owns the report |
| `PagleProbe_Module` | A tiny test "Module" that depends on the Core. You will disable it once. |

Total time: about 60–90 minutes, plus an optional 15 minutes for the load-time test at the end. Skip any step that doesn't fit and say so when you paste the results.

---

## 1. Install

### 1.1 Find the Forever beta folder

The folder name is unconfirmed (reports say `_classic_beta_`), so check where yours is:

1. Open the **Battle.net app** and select **WoW: Forever** with the beta/test version chosen in the version drop-down.
2. Click the **gear icon** next to the Play button and choose **Show in Explorer**.
3. Explorer opens the game folder (for example `C:\Program Files (x86)\World of Warcraft\`). Inside, find the sub-folder that contains **`WowB.exe`** (or whichever `.exe` the beta launches). Its name starts and ends with an underscore, for example `_classic_beta_`. **Write the exact name down; it is one of the answers we need.**
4. Inside that folder, open `Interface\AddOns`. If `Interface` or `AddOns` doesn't exist, create them, spelled exactly like that.

### 1.2 Copy the addon

Copy both folders from `probes/fishing-signals/` into `AddOns`, so you end up with:

```
<beta folder>\Interface\AddOns\PagleProbe\PagleProbe.toc
<beta folder>\Interface\AddOns\PagleProbe_Module\PagleProbe_Module.toc
```

Copy the folders themselves, not their contents, and don't nest them one level deeper (watch out for this when unzipping).

### 1.3 Check the AddOns list (before logging in)

1. Start the beta. At the **character selection** screen, click **AddOns** (bottom left).
2. Check, and write down:
   - Is **PagleProbe** listed? Is **PagleProbe - Module** shown *nested/indented under* PagleProbe (a collapsible group)?
   - If they show as "out of date", tick **Load out of date AddOns**.
3. Make sure both are ticked (enabled).

**If PagleProbe is not in the list at all:** quit the game, open both `.toc` files in Notepad, delete the line `## ExcludeLoadGameType: standard, classic` in each, save, and start the game again. If it still doesn't show, also delete `## AllowLoadGameType: camelot`. **Tell us which lines you had to remove.** That is a test result too.

---

## 2. In-game checklist

Type all commands in the chat box. `/pprobe` on its own always shows the status and the command list.

### Step 1: First login

1. Log in with your fishing character. Within a few seconds the chat shows:
   `PagleProbe: loaded (session 1). Saved data: NOTHING READ BACK (fresh). Module: loaded, data first run.`
   "Fresh" is expected the very first time.
2. **Wait 20 seconds** (item checks run in the background).
3. Open the in-game **calendar** once (the calendar/clock button by the minimap), close it, then type `/pprobe env`. This makes sure calendar events are captured.
4. If you ever see a red Lua error popup, take a screenshot. The probe should never cause one.

### Step 2: Settings

1. Press **Esc → Options → AddOns** tab.
2. Check: is there a **PagleProbe** entry with **Module** underneath it? Write down yes or no.
3. Open **Module** and **tick** "Module test checkbox". This checks that a Module setting is saved.

### Step 3: Open water, no lure

1. Equip your fishing pole. Make sure **no lure** is applied.
2. Fish **open water** (not a pool) for about **10 casts**. Loot normally. Each loot prints a chat line such as `Catch #3 recorded - IsFishingLoot: true - ...`.
3. Once, **let a fish get away** on purpose: don't click the bobber.
4. Do about 5 of these casts with **auto-loot on** and 5 with it **off**. The setting is under Options → Controls → Auto Loot; holding **Shift** while clicking the bobber also flips it.

### Step 4: Open water, with a lure

Apply a lure yourself (Shiny Bauble or any other lure), then fish about **10 more casts** in open water. If your character has **Luremaster**, say so.

### Step 5: Pools

1. Find a fishing **pool** (a school of fish, floating debris, an oil spill and so on).
2. **Before casting, hover the mouse over the pool** until its name tooltip appears. This lets the probe record the pool's ID.
3. Cast into the pool and catch about **5 fish**, hovering over the pool before each cast.
4. If possible, repeat with a **second, different pool type**. A School of Whimsyfin (Redridge, east of Lake Everstill) would be ideal.

### Step 6 (optional): Soft-target interact

1. Type `/pprobe report`, scroll to "CVars" and note the value of `SoftTargetInteract`. Close the window.
2. Type `/console SoftTargetInteract 3`, then fish **3 casts** at a pool and 3 in open water.
3. Put it back with `/console SoftTargetInteract <the value you noted>`.

### Step 7: Things that are not fishing

1. **Kill a mob and loot it** once. We want to see the "fishing loot" check return false for it.
2. If you have a **clam, crate, trunk or "Bloated" fish** from fishing, open it once.

### Step 8: Day and night (if feasible)

Fishing windows are tied to **realm time**, which the report records. If you can, do a few casts during realm daytime (06:00–18:00) and a few at night (18:00–06:00). If not, just say when you fished.

### Step 9: Weather and places

1. Visit **3–4 different zones**. In each, stand still for about a minute, then type `/pprobe weather`. The probe also samples weather every minute on its own.
2. Where convenient, stand at each of these places (fishing one cast is a bonus) and type `/pprobe where <name of the place>`:
   - **Lordamere Lake** (between Alterac Mountains, Hillsbrad and Silverpine): `/pprobe where Lordamere Lake`
   - **The Veiled Sea** (open sea off Darkshore or Azshara): `/pprobe where Veiled Sea`
   - a **new Forever zone** such as Riverglades, Zephras Isle or Gilneas
   - **inside a dungeon** you can fish in (Wailing Caverns, Blackfathom Deeps, The Deadmines…). Try one cast there too, and tell us whether anything odd happened.
   - If you ever find yourself in what looks like a **copy of Elwynn Forest, Crystal Lake, Mirror Lake or Stormwind** (a special "Camelot" map), type `/pprobe where Camelot copy?` there.

### Step 10: Saved data round-trips

Do these in order. **Each time, type the `mark` command first**, then do the action. After the next login, the chat line should say **"Saved data: read back, round-trip ok"**. Write down what it says each time.

1. **Reload:** `/pprobe mark reload`, then `/reload`.
2. **Relog:** `/pprobe mark relog`, then Esc → **Log Out**, and log back in with the same character.
3. **Full restart:** `/pprobe mark restart`, then Esc → **Exit Game**. Wait until the game is fully closed, then start it again from Battle.net and log in.
4. **Settings check:** Esc → Options → AddOns → PagleProbe → Module. Is the test checkbox still ticked?

### Step 11: Disable the Module

1. Open Explorer at `<beta folder>\WTF\Account\<YOUR ACCOUNT>\SavedVariables\` and note the **Date modified** of `PagleProbe_Module.lua`.
2. In game: `/pprobe mark module-off`, then Esc → **Log Out**.
3. At character select: **AddOns** → **untick** "PagleProbe - Module" (leave PagleProbe ticked) → Okay.
4. **Exit the game fully and start it again**, then log in. The chat should say `Module: not loaded`.
5. Check `PagleProbe_Module.lua` in Explorer again. **Did its Date modified change?** It should not.
6. `/pprobe mark module-on`, log out, **tick** the Module again, log in. The chat should say `Module: loaded, data intact`.

### Step 12 (optional): What a crash loses

1. Catch 2–3 fish, then `/reload`.
2. Catch 2–3 more fish. Type `/pprobe` and **write down** the number after "Loot windows".
3. Open **Task Manager** (Ctrl+Shift+Esc), find the WoW beta process, and click **End task**. This simulates a crash.
4. Start the game again and log in. Type `/pprobe` and **write down** "Loot windows" again.

### Step 13: Copy the report

1. Type `/pprobe report`. A window opens.
2. Click **Select all**, press **Ctrl+C**, and paste into a new comment on issue #7.
   The report is about 20,000 characters, which fits in one GitHub comment.
3. Close the window with the X or Esc.

### Step 14 (optional, do it LAST): Load time with big saved data

This adds fake data to `PagleProbe.lua` to see how big files slow down loading. **Do Step 13 first**, in case a huge file breaks something.

1. `/pprobe bulk 5`, then `/pprobe mark bulk5`. Exit the game fully.
2. Look at `PagleProbe.lua` in the SavedVariables folder and write down its **size**.
3. Start the game and **time the loading screen** after you pick your character (phone stopwatch is fine). Type `/pprobe` and write down the **"SV load … ms"** number.
4. Repeat with `/pprobe bulk 20` and `/pprobe mark bulk20`.
5. Clean up: `/pprobe bulk off`, then `/reload`.
6. `/pprobe report` again and paste it as a second comment. Only section 3 is new.

### When you're done

Delete the two addon folders from `Interface\AddOns`. You can also delete `PagleProbe.lua` and `PagleProbe_Module.lua` from the SavedVariables folders.

---

## 3. What to paste back into issue #7

1. The **`/pprobe report` output** (and the second one if you did Step 14).
2. The **beta folder name** (Step 1.1) and the **full paths** of the saved-data files. They are normally:
   - `<beta folder>\WTF\Account\<ACCOUNT>\SavedVariables\PagleProbe.lua`
   - `<beta folder>\WTF\Account\<ACCOUNT>\SavedVariables\PagleProbe_Module.lua`
   - `<beta folder>\WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\PagleProbe.lua` (the per-character file)
   - Say whether `.lua.bak` files sit next to them.
3. Answers you saw by eye:
   - Was the Module nested under PagleProbe in the AddOns list? Did you have to remove any `.toc` lines?
   - Was "Module" shown under "PagleProbe" in Options → AddOns? Did the test checkbox stay ticked after the restart?
   - What the chat said after each reload, relog and restart (Step 10).
   - Did `PagleProbe_Module.lua`'s Date modified change while the Module was disabled (Step 11)?
   - Crash test numbers (Step 12), and loading times and file sizes (Step 14), if done.
   - Any red Lua error popups (screenshots welcome).
4. Your **game language** (for example English or German). The report also records it.

**Privacy:** the report contains your character name, realm and character GUID. Your battleTag is masked. Edit anything you don't want public before posting. The saved-data files stay on your PC; we only need their paths, not their contents, unless we ask.

---

## Commands

| Command | What it does |
|---|---|
| `/pprobe` | Status and help |
| `/pprobe report` | Open the copyable report |
| `/pprobe mark <what>` | Label the next load (`reload`, `relog`, `restart`, `module-off`, …) |
| `/pprobe where <note>` | Log where you are (zone texts, map IDs, area IDs) |
| `/pprobe weather` | Sample the weather now |
| `/pprobe env` | Redo the environment checks |
| `/pprobe verbose` | Turn the chat line per Catch on or off |
| `/pprobe settings` | Open the PagleProbe settings page |
| `/pprobe bulk 5` / `20` / `off` | Fake saved data for the load-time test |
| `/pprobe reset` | Clear the fishing log (keeps the persistence counters) |

## What the probe records (for the developer)

- **Client:** `GetBuildInfo`, `WOW_PROJECT_ID`/`WOW_PROJECT_CAMELOT`, locale, region, `RegionalUniqueNamesEnabled`, `C_GameRules`, and the contents of the `C_Weather`/`C_GameRules` tables.
- **Names:** `UnitName`, `UnitNameUnmodified`, `GetUnitName`, `UnitFullName`, `UnitGUID`, `BNGetInfo` (battleTag masked in the report).
- **Every loot window** (a Catch when `IsFishingLoot()` is true): the `LOOT_READY`/`LOOT_OPENED` order and auto-loot flags; per slot the item ID, name, count and quality (`GetLootSlotInfo`/`GetLootSlotLink`), item class, and `GetLootSourceInfo` (GUID, parsed GameObject entry ID, secret or nil).
- **Catch context:** realm time, zone/subzone/minimap texts, `GetInstanceInfo` map ID, `C_Map.GetBestMapForUnit` uiMapID, position, explored area IDs, the text→area-ID matches, locale, `C_Weather`, fishing skill (three APIs), lure (`GetWeaponEnchantInfo`), buffs (Rack/Hut/hat lure/Extravaganza), the fishing channel spell and duration, the cast target, hover hints (tooltip post-call `data.id` for Objects, tooltip text, soft target) and today's calendar events.
- **Session log:** channel start/stop, casts, lure changes, zone changes, skill-up messages, loot chat lines, restriction changes and errors.
- **Persistence:** logout-write counters, a round-trip value, a per-character counter, Module check-ins (data intact after being disabled), the time from the first file to `ADDON_LOADED` (SavedVariables load time) and Lua memory.
- **Existence checks:** Nat Pagle's items and quest fish, Artisan Fishing, Rockhide Strongfish, Darkwood Fishing Pole, new Forever camp items and controls (`DoesItemExistByID`, `GetItemInfoInstant`, server replies), quests 6607/8193/96561, and the fishing spell IDs.
- Secret values are never stored. They become nil and are listed as "(secret -> nil)".
