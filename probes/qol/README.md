# Pagle QoL probe: beta checklist for issue #15

`PagleQoLProbe` is a throwaway diagnostic addon. It checks which QoL mechanisms work on the **WoW: Forever beta**. Each check matches one item, B1 to B14, from `docs/research/angleur-qol-feasibility.md`. You press keys and click buttons, the probe records what happened, and you paste one report back.

**What the probe does and doesn't do**
- **It never plays for you.** Every game action, such as a cast, a lure, opening a clam or equipping gear, happens only when you press the probe key or click a button, and each press does one thing.
- **It turns itself off in combat.** The only exception is the green B10 button, which you click yourself.

## 1. Install

1. Find the Forever beta game folder. The folder name is not confirmed yet (it may be `_classic_beta_`).
   1. Open the Battle.net app and select **World of Warcraft**.
   2. In the version drop-down above the Play button, pick the **Forever beta**.
   3. Click the gear icon next to Play, then **Show in Explorer**.
   4. Explorer opens the `World of Warcraft` folder. It contains one sub-folder per game version, for example `_retail_`, `_classic_era_` and `_classic_beta_`. The right one holds the beta's `.exe`, which may be `WowB.exe`. If you're unsure, check which folder has the newest `.exe`.
2. Inside that folder, open `Interface\AddOns\`. If the folders don't exist, create them.
3. Copy the whole `PagleQoLProbe` folder (from `probes/qol/` in this repo) into `Interface\AddOns\`. The result must look like this, with no extra folder in between:
   ```
   <beta folder>\Interface\AddOns\PagleQoLProbe\PagleQoLProbe.toc
   <beta folder>\Interface\AddOns\PagleQoLProbe\Core.lua
   <beta folder>\Interface\AddOns\PagleQoLProbe\Tests.lua
   <beta folder>\Interface\AddOns\PagleQoLProbe\UI.lua
   ```
4. Start the beta. At character select, click **AddOns**:
   - Make sure **Pagle QoL Probe (throwaway)** is ticked.
   - If it says *Out of date*, tick **Load out of date AddOns** at the top.
   - If it is missing or says *Incompatible*, stop and report that, with the folder path you used.
5. Log in. Chat should say `[QoL probe] loaded. Type /qprobe ...`.

**Write down the exact folder path you installed into.** It settles the unconfirmed folder name.

## 2. What to have on the character

- Fishing trained and a **fishing pole**, plus your **normal weapon** in your bags.
- One or two **lures** (Shiny Bauble, Nightcrawlers, Bright Baubles, Aquadynamic Fish Attractor, ...).
- One or two **clams** (Small Barnacled Clam, Thick-shelled Clam, ...), or any other item you can right-click to open. Clams come from fishing, so you may get some during B1/B2.
- **Food or any buff** for B7.
- A **companion pet** in the Pet Journal, if Forever has one, for B13.
- A **fishing toy**, if Forever has any, for B8.
- A spot with **fishable water** and **low-level mobs nearby**, for the combat test B10.

## 3. How the probe works

- `/qprobe` opens the **test panel** and prints the help and checklist in chat.
- Each panel button is one test:
  - **B1, B2, B3, B4, B6, B8, B9 /equipset key and B12** arm the **probe key**. The probe key is **F9** by default; change it with `/qprobe key G` or similar.
  - The other buttons do their one thing on the click.
- When you click a test, its steps appear in the panel and in chat.
- After each test, give your verdict:
  `/qprobe yes B1`, `/qprobe no B1`, or `/qprobe partial B1 <short note>`.
  `yes` = works, `no` = doesn't work, `partial` = works only partly (say how in the note).
- **Disarm** stops the armed test. Testing in combat is disabled.
- If a test needs an item the probe can't find, set it by typing the command and then shift-clicking the item into the chat line: `/qprobe lure <item>`, `/qprobe clam <item>`, `/qprobe toy <item>`, `/qprobe weapon <item>`.

## 4. The tests, in order

Do them at the water, out of combat, unless a step says otherwise.

1. **B1: soft-interact reel (most important).**
   1. Equip the pole and click **B1 soft-interact**.
   2. Press **F9**: it casts Fishing.
   3. While the bobber is out, move the mouse **away** from the bobber and press **F9** again. Did it reel in or pick up the bobber?
   4. Do at least 3 casts: press after the splash, and once before it.
   5. If you have your own key bound to *Interact With Target*, try it too.
   6. Answer `/qprobe yes|no|partial B1 <what happened>`.
2. **B2: key cast + mouseover reel.**
   1. Click **B2 key cast+reel**.
   2. Press **F9** to cast.
   3. Put the mouse pointer **on** the bobber and press **F9** again. Do 3 casts.
   4. Answer for B2.
3. **B5: secret values.** Cast Fishing (B2 is still armed), and while the bobber is out click **B5 secrets**. Answer for B5: `yes` if the report shows no `<secret>` values.
4. **B3: double-click cast.**
   1. Click **B3 double-click**.
   2. Point the mouse at open water (not at a window) and **double-click the right mouse button** quickly. The second click should cast. Try 3 times.
   3. Check that a single right-click still turns the camera normally.
   4. Answer for B3.
5. **B4: lure.**
   1. Equip the pole and click **B4 lure (macro)**.
   2. Press **F9 once**. Is the lure on the pole? Hover the pole in the character pane to check.
   3. Click **B4 lure (item)** and press **F9 once**. If the game asks to replace the lure, click Yes.
   4. Answer for B4, and say which of the two ways worked.
6. **B6: clam.**
   1. Click **B6 clam** and press **F9 once**. Did it open?
   2. If you own a Forever camp object (Fish Bowl, Fishing Rack, Fishing Hut), set it with `/qprobe clam <item>`, click **B6 clam** again and press **F9 once**.
   3. Answer for B6, including the camp objects.
7. **B7: buffs.** Eat food or get any buff, then click **B7 auras**. Answer for B7: `yes` if names and durations are readable.
8. **B8: toys.**
   1. Click **B8 toys**.
   2. Open Collections > Toy Box and search for `fish`, `raft` and `bobber`.
   3. If you own a fishing toy, type `/qprobe toy <item>`, click **B8 toys** again and press **F9 once**.
   4. Answer for B8 and list the toys you saw.
9. **B9: equipment sets (important).**
   1. Wear your gear with the pole equipped and click **B9 save set**.
   2. Open the character pane (C). Is there an Equipment Manager or sets button?
   3. Drag the pole into your bags. Click **B9 /equipset key** and press **F9 once**. Is the pole back on?
   4. Drag the pole off again and click **B9 API equip** once. Is it back on?
   5. Answer for B9.
   6. Finally click **B9 delete set** to remove the test set.
10. **B11: CVars.** Click **B11 CVars** once. You may hear a short sound blip. Answer for B11.
11. **B12: secure snippet.** Click **B12 snippet** and press **F9 once**. Nothing happens in the game; that is expected. Answer for B12: `yes` if the report's B12 log shows `snippet count 1` and an empty key binding.
12. **B13: pet.** Click **B13 pet** once. Did a pet appear or get dismissed? A "blocked" message is also a result. Answer for B13.
13. **B10: weapon swap in combat.**
    1. Equip your **normal weapon** and click **B10 combat swap**. A green button appears at the top of the screen.
    2. Equip the **pole**.
    3. Attack a low-level mob. **In combat**, click the green button **once**. Is your weapon back?
    4. After the fight, click **Disarm** to hide the green button.
    5. Answer for B10.
14. **B14: saving and reloading.**
    1. Click **B14 hygiene**.
    2. Type `/reload`, then `/qprobe report`. Are your answers still there?
    3. Optional: type `/run ReloadUI()` in chat. Does the UI reload, or does a message say it is blocked?
    4. Answer for B14, describing what happened.
    5. Do the full-restart check in section 6.

## 5. Put your settings back

The probe avoids lasting changes:
- **Keybinds:** the probe key is a temporary override and disappears on `/reload` or logout. **Your keybinds are not changed.** If you changed the probe key with `/qprobe key`, that is only stored for the probe.
- **CVars (game settings):** B1 turns on soft-interact while it is armed. The probe restores it on Disarm, in combat, on logout and at the next login. B11 changes each setting for one moment and puts it straight back. To be safe, type `/qprobe restore` at the end. Check the report line "CVars still waiting to be restored: none".

You must undo these yourself:
- Delete the test equipment set: **B9 delete set**, or delete `PagleProbe` in the Equipment Manager.
- Re-equip the gear you want, and dismiss the pet if one was summoned.
- Lures and clams used in the tests are consumed.
- When you are done, delete the `PagleQoLProbe` folder from `Interface\AddOns\`. Its saved file is `WTF\Account\<ACCOUNT>\SavedVariables\PagleQoLProbe.lua`.

## 6. What to paste back

1. Type `/qprobe report`, click **Select all**, press **Ctrl+C** and paste it somewhere safe.
2. **Full restart check (B14):** quit the game completely, start it again, log in, type `/qprobe report` and copy it again. If this second report has lost your answers, SavedVariables don't load on this build. That is an important result, so keep the first report.
3. Paste back:
   - **both reports** (before and after the restart)
   - the **folder path** you installed into
   - anything odd you saw, such as red error windows, "AddOn blocked" pop-ups, or a test that did nothing at all

If the report window won't copy, send the file `WTF\Account\<ACCOUNT>\SavedVariables\PagleQoLProbe.lua` from the beta folder instead. It has the same data, written when you log out or `/reload`.
