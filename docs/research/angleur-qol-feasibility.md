# Angleur QoL features: what they do and which are allowed on Forever

Research for issue #4 (child of map #1). Feeds the HITL task #15, "Beta probe: which QoL mechanisms work on Forever?".

**Question.** List every feature of Angleur, plus the QoL features of Fishing Buddy for comparison. For each one, give:

- its mechanism
- its policy status under Blizzard's rules and under our rule (**at most one game action per player keypress, and the addon never acts on its own**)
- whether it is likely to work on the Forever client
- what can only be verified in the beta

Researched 2026-10-11.

## Answer in brief

- **Angleur's core works within our rule.** It is a *context-sensitive key*. Out of combat, an `OnUpdate` loop (every 0.3 s) and spell, aura and loot events re-point one **priority override binding** on the player's chosen key to "the next sensible action". That action is cast Fishing, reel (interact), apply lure, use an extra item, or nothing. The game action happens only when the player presses the key, and each press does exactly one thing. Rebinding a key is not a game action. \[A1\]\[A3\]
- **Four features break "the addon never acts on its own":**
  - **Bobber Scanner** (Angleur, Classic/Forever only). It sweeps the camera by itself to find the bobber.
  - **Automatic equipment-set swap** (Angleur). It equips the fishing set when you wake Angleur or equip a pole, and unequips it on sleep.
  - **Timer-driven pet summon** (Fishing Buddy).
  - **User macros with several commands** (Angleur's extra-item slots, both a risk and a loophole).

  Each can be redesigned to fit the rule, except the Bobber Scanner, which should be **ruled out**.
- **Forever feasibility is good but author-claimed.** Angleur ships a dedicated Forever build (`Angleur_Camelot.toc`, interface 16001, branch `Forever-Beta`, last commit 2026-10-08). It uses only override bindings, a `SecureActionButtonTemplate` macro button, CVars and `C_EquipmentSet`, and **no secure snippets**. Nobody has independently confirmed that all of it works. **Fishing Buddy depends on a secure snippet** (`SecureHandlerWrapScript`), which threw on every Forever build before 1.60.1.70009. \[A2\]\[A4\]\[K1\]
- **The biggest Forever unknown is reeling.** Forever has Classic fishing on the Retail client. We don't know if soft-interact targets the bobber there, so we don't know if one key can reel without the mouse over the bobber. Angleur's Forever build uses the Classic code path: `INTERACTMOUSEOVER`, soft-interact **off** by default, and the Bobber Scanner as a fallback. That suggests the author does not trust soft-interact on Forever. This is verify-in-beta item **B1**.

## Definitions used in the verdicts

- **Game action**: anything the server sees that changes game state, such as casting, using or applying an item, interacting with an object, equipping gear, or summoning a pet. Key bindings, CVars, camera, sounds and UI are **not** game actions.
- **Policy verdict.** Blizzard's UI Add-On Development Policy says nothing about automation. Its rules cover being free, visible code, no harm to realms or players, no ads, no donations, no objectionable content, and ToS compliance. Rule 8 reserves Blizzard's right to "disable add-on functionality as it sees fit". \[P1\] The binding constraint is the EULA, which bans "bots; i.e. any code and/or software, not expressly authorized by Blizzard, that allows the automated control of a Game" (§1.C.ii.2). \[P2\] In practice, the protected-API system (casts and item use need secure code started by a hardware event) marks the line Blizzard enforces. \[W1\]\[W2\]\[W3\]
  - **OK**: sanctioned API, one action per press.
  - **Redesign**: allowed by Blizzard but breaks our rule.
  - **Out**: automation, so ToS-risky.
- **Forever verdict**:
  - **Likely**: shipped in a Forever build and uses no beta-broken API.
  - **Probably**: mechanism should work but is unproven on Forever.
  - **Unknown**: depends on something only the beta can show.
  - **N/A**: Retail-only content.

## Feature table: Angleur

Source: `LegolandoBloom/Angleur`, branch `Forever-Beta` @ `73610ff` (2026-10-08) \[A2\]. The CurseForge page lists "Forever" as a supported flavour, and the latest file is 2.9.78, dated 2026-10-08. \[A1\] The Forever build loads `AngleurForever.lua`, the Classic item tables, `extra_without` (no toy tab) and the bobber-scanner module. \[A2: `Angleur_Camelot.toc`, `modules/embeds_classic.xml`\]

| # | Feature | Mechanism (from source) | Policy | Our rule | Forever | Verify in beta |
|---|---|---|---|---|---|---|
| A1 | **One-Key cast + reel** | `SetOverrideBindingSpell(owner, true, key, PROFESSIONS_FISHING)` when idle. While the Fishing channel runs: `SetOverrideBinding(..., "INTERACTMOUSEOVER")` on Forever/Classic, `"INTERACTTARGET"` on Retail. Re-evaluated every 0.3 s and on events such as `UNIT_SPELLCAST_CHANNEL_START` and `PLAYER_SOFT_INTERACT_CHANGED`. Never rebinds while the key is held. Skipped in combat and under addon restrictions. \[A2: `AngleurForever.lua` `performAction`, `Angleur_ActionHandler`\] | OK. `SetOverrideBinding*` is `#nocombat` only, with no hardware-event rule. \[W4\] | **OK.** One press = one cast or one interact. | Likely (shipped in Forever build) | **Yes (B1, B2)** |
| A2 | **Double-Click mode** | `GLOBAL_MOUSE_UP` opens a short watch window. During it the same override logic binds `BUTTON1`/`BUTTON2`, so the second click fires the action. Uses `MouselookStart/Stop`. On Forever with soft-interact off, the double-click **always recasts**, because reeling is the game's own right-click on the bobber. \[A2: `modules/singular/doubleClick.lua`, `AngleurForever.lua` L459–466\] | OK | **OK** | Likely | Yes (B3) |
| A3 | **Soft-interact bobber reel** (Classic/Forever option, off by default) | During the channel, temporarily sets CVars `SoftTargetInteract`, `SoftTargetInteractRange` and `SoftTargetInteractRangeIsHard`. It reads `PLAYER_SOFT_INTERACT_CHANGED` for the bobber GUID (`GameObject-…-35591-`). If the bobber is out of range it shows an icon, plays an optional sound, and can optionally rebind the key to recast. \[A2: `AngleurForever.lua` L176–237; `init.lua` L81–94\] | OK (client settings) | **OK** | **Unknown** | **Yes (B1)** |
| A4 | **Bobber Scanner** (Classic/Forever only) | 0.2 s after the cast, if soft-interact has not found the bobber, the addon calls `CenterCamera`, raises the max-zoom CVar, then sweeps the camera in a grid with `MoveViewLeft/Right/Up/OutStart`. It stops when `CURSOR_CHANGED` shows the cursor is over the bobber, so the next press reels via mouseover. It comes with a photosensitivity warning. \[A2: `modules/bobberScanner/bobberScanner.lua` L400–575\] | **Out.** Unprotected APIs, but it automates the bot step "locate the bobber" with no input. EULA §1.C.ii.2 territory. \[P2\] | **Out** (acts on its own) | Probably works technically | No (ruled out) |
| A5 | **Auto lure / bait** | If `GetWeaponEnchantInfo()` shows no lure enchant (IDs 263–266, 3868, 4225) and the chosen lure is in the bags, the key is bound to the secure button `Angleur_ToyButton` with `macrotext = "/cast <lure>\n/use 16"`. \[A2: `AngleurForever.lua` L338–386, L481–487; `items/items_mists.lua`\] | OK | **OK.** One press = apply one lure. | Probably | Yes (B4, B5) |
| A6 | **Extra items / macros** (buff food, chum, hats, charms, clams, crates, any usable item or macro) | Up to N slots. A slot fires when its item is usable, off cooldown, its aura is inactive (with an optional "recast X s before expiry" offset) or its manual timer has run out, and its macro conditionals pass. The key is then bound to the secure button with `"/cast <item>"` or **the user's macro body**. \[A2: `items/items_base.lua` L683–724; `modules/singular/advancedAngling.lua`\] | OK. Clam opening must go through a key: `C_Container.UseContainerItem` is `#protected`. \[W5\] | **OK for single item or spell.** A user macro can chain several `/use` lines in one press. Our version should allow one item or spell per slot, not free macro text. | Probably | Yes (B4, B6, B7) |
| A7 | **Toys**: rafts, oversized bobber, crate bobbers, random toys, extra toys (Retail) | Secure macro `/cast <toy>`, gated on toy cooldown and aura. Raft logic re-casts when under 60 s remain or when swimming. \[A2: `Angleur.lua` L340–380, L450–548\] | OK | **OK** | **N/A as shipped.** The Forever build has no toy tab. | Yes (B8): are any fishing toys in Forever's Collections? |
| A8 | **Equipment-set swap** ("Angleur" set) | Creates and updates a Blizzard equipment set via `C_EquipmentSet.CreateEquipmentSet/SaveEquipmentSet`. **Automatically** calls `C_EquipmentSet.UseEquipmentSet` on wake or when a pole is equipped, and re-equips previous gear with `C_Item.EquipItemByName` on sleep. Tracks manual gear changes. \[A2: `eqMan/eqMan_base.lua` L194–330, L741–803\] | OK. `UseEquipmentSet` is `#nocombat` with no hardware-event rule. \[W6\] | **Redesign.** It is triggered by an event or toggle, not by a press. Make it "key press → one `/equipset` (one action, like Blizzard's own set button)". | Probably | **Yes (B9)** |
| A9 | **Sleep / Wake**, "Sleep without fishing rod" | Sleep clears the bindings and releases the temporary CVars. On Forever it auto-sleeps when slot 16 holds no pole, and auto-wakes and **equips the set** when a pole is equipped. \[A2: `AngleurForever.lua` L71–102, L515–544\] | OK | **OK for the toggle.** The auto-equip part falls under A8. | Likely | No |
| A10 | **Combat weapon-swap button** | A `SecureActionButtonTemplate` (type `macro`) appears near the Angleur icon. The player clicks it to re-equip weapons. \[A2: `eqMan_base.lua` L636–671; `angTemplates/.../ClassicTemplates.xml` L64\] | OK | **OK** (one click) | Probably | Yes (B10) |
| A11 | **Loot protection** | On `LOOT_OPENED`/`LOOT_READY` the key is bound to an empty macro for 2 s (auto-loot) or 4 s (manual), until `LOOT_CLOSED`. \[A2: `modules/singular/lootProtection.lua`\] | OK | **OK** (it suppresses actions) | Likely | No |
| A12 | **Ultra-Focus audio and auto-loot** | During the channel it temporarily sets CVars: `Sound_*` volume and enables (music, ambience, dialog off, SFX up, optional sound in background) and `autoLootDefault`. They are restored on channel stop or sleep. \[A2: `init.lua` L600–650; `AngleurForever.lua` L229–234\] | OK (client settings) | **OK** | Likely | Yes (B11): CVar names |
| A13 | **Recast reminder** | Plays a sound 2 s after the channel ends if you have not recast. \[A2: `modules/singular/audio.lua`\] | OK | **OK.** A notification, not an action. Keep it opt-in so it does not become an AFK alarm. | Likely | No |
| A14 | **Recast key** | A second key bound to Fishing during the channel. \[A2: `AngleurForever.lua` L391–393\] | OK | **OK** | Likely | No |
| A15 | **Dismount with key** | When mounted, the key still casts (the client auto-dismounts). Otherwise the key is cleared. \[A2: L475–479\] | OK | **OK** (one press) | Likely | No |
| A16 | **Gamepad support** | `SetGamePadCursorControl(true)` during the channel, so a gamepad can aim at the bobber. \[A2: L500–512\] | OK | **OK** | Probably | Low priority |
| A17 | **Void Finder** (Midnight) | Keybind to a secure macro `/tar <vortex>` plus a raid marker. \[A2: `modules/singular/midnight.lua`\] | OK | OK | **N/A** (Retail-only content) | No |
| A18 | **Plugins**: `Angleur_Underlight` (auto Aquatic Form for the Underlight Angler), `Angleur_NicheOptions` | Not examined. Underlight is Retail Legion content. \[A1\] | n/a | n/a | N/A | No |
| A19 | **UI**: visual icon, minimap, addon compartment, tutorial, Plater clash fix | UI only | OK | OK | Likely | No |

**Secret-value hygiene.** Angleur listens to `ADDON_RESTRICTION_STATE_CHANGED`. Every decision path returns early when a Combat, Encounter, ChallengeModes or PvPMatch restriction is active. Event payloads and API results are passed through `scrubsecretvalues`. \[A2: `secrets/secrets.lua`, `secrets/secretsExplanation.txt`\] We should copy this pattern.

**Forever detection.** Angleur treats `WOW_PROJECT_ID == 18` (`WOW_PROJECT_CAMELOT`) as Forever. So does `WOW_PROJECT_MAINLINE` combined with `LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_CLASSIC`. \[A2: `init.lua` L349–367\] This is useful for Core's version detection.

## Feature table: Fishing Buddy, for comparison

Source: `r-log/FishingBuddy` @ `fedacff` (2026-08-12). It is an unofficial Retail fork (interface 120007/120100) of Sutorix's Fishing Buddy 1.26, with `LibFishing-1.0` embedded \[F1\]. The two Forever ports are closed source (All Rights Reserved, no repo link):

- **Fishing Buddy Forever Fix** by Ezreth: v1.0.2, 2026-09-19, about 856 downloads. Its page says "Some features still need love to function properly". \[F2\]
- **Fishing Buddy (Forever) (Crusade)** by crediar: Forever v1.0.7, 2026-10-01, about 31.5K downloads. \[F3\]

Their mechanisms are inferred from upstream.

| # | Feature | Mechanism | Policy | Our rule | Forever | Verify in beta |
|---|---|---|---|---|---|---|
| F1 | **Double-click casting** ("EasyCast") | On `GLOBAL_MOUSE_DOWN`, if it is a double click, it sets attributes on the `SecureActionButtonTemplate` button (`spell`, `action`, `item` with `target-slot`, or `macro`). Then it calls `SetOverrideBindingClick(btn, true, "BUTTON2", btn)`, so this same mouse-down clicks the button. A **secure snippet** (`SecureHandlerWrapScript(btn, "PostClick", …, "self:ClearBindings()")`) clears the binding. \[F1: `FishingBuddy.lua` L513–525, L1383–1409; `LibFishing-1.0.lua` L2228–2402\] | OK | **OK** | **At risk.** Secure snippets threw before build 70009. \[K1\] | Yes (B12) |
| F2 | **Auto lure** | The double click applies the lure instead of casting: `type=item`, `target-slot=INVSLOT_FISHING_TOOL`. \[F1: `LibFishing` `InvokeLuring`\] | OK | **OK** | Probably | Yes (B4) |
| F3 | **Outfit switch** (`/fb switch`, Outfit Manager) | Equips a chosen outfit on command. | OK | **OK** if one command = one set swap | Probably. The Forever Fix page marks outfits as not yet working. \[F2\] | Yes (B9) |
| F4 | **Fishing pets** | `C_PetJournal.SummonPetByGUID` from a `C_Timer.After(3.0, …)` retry loop that waits for "a quiet moment between casts". \[F1: `FishingPlans/Pets.lua` L155–195\] | OK (cosmetic) | **Redesign/Out.** It acts on its own. Bind it to a key press or drop it. | Unknown | Yes (B13) |
| F5 | **Plans queue** (bobber toys, rafts, coins, items, baits) | Planners fill a queue. Each later double-click takes one entry. \[F1: `FishingPlans.lua` L98–112\] | OK | **OK** | Probably | Yes (B8) |
| F6 | **Sound enhancement, click-to-move off** | Changes CVars during fishing, for example `autoInteract` 0 while fishing. \[F1: `FishingBuddy.lua` L1471–1510\] | OK | **OK** | Likely | Yes (B11) |
| F7 | **Auto-open fish and containers** | Uses the item on the next double click. | OK | **OK** | Probably | Yes (B6) |
| F8 | **Fish Watcher, tracking, cycle fish, Extravaganza timer, style points** | Read-only events and UI. | OK | OK, but these belong to Ledger/Stats, not QoL | Likely | No |

## What this means for our QoL Module

- **Adopt Angleur's architecture, not Fishing Buddy's.** Use one owner frame with *priority override bindings* re-pointed out of combat, plus one pre-built `SecureActionButtonTemplate` for item, macro and equip actions. It needs **no secure snippets**, so the pre-70009 snippet bug cannot hit it. A Fishing Buddy-style double-click is possible without snippets, because Angleur's double-click works without them.
- **In scope (within the rule):**
  - cast/reel key (A1)
  - double-click mode (A2)
  - soft-interact assist (A3)
  - lure on key (A5)
  - single-item extra slots, including clams (A6)
  - equip set **on key press** (A8 redesigned)
  - combat weapon button (A10)
  - loot protection (A11)
  - audio focus and auto-loot CVars (A12)
  - opt-in recast reminder (A13)
  - recast key (A14)
  - sleep/wake (A9 without the auto-equip)
- **Out of scope:**
  - **Bobber Scanner** (A4): the addon moves the camera on its own to find the bobber.
  - Automatic set equip/unequip on events (A8 as shipped).
  - Timer-driven pet summons (F4).
  - Free-text multi-command macros in slots (A6 caveat).
- **Fallback if B1 fails** (no soft-interact on the bobber): reeling stays a *player* action, either by mouseover plus the key, or by the game's right-click on the bobber. A camera sweep is not an acceptable fallback. Given Forever's Classic fishing, the honest UX may be "key casts; you click the bobber". Measure this in the beta before promising one-key reel.
- **Beta-client hazards to design around:**
  - Don't ship a "Reload UI" button: `ReloadUI()` is protected on the beta. \[K1\] (Superseded: `ReloadUI()` is unprotected on build 1.60.1.70338, QOL-R102.)
  - Wrap every `RegisterEvent` in `pcall`, because unknown events throw. \[K1\]
  - Don't trust `SavedVariables` until B14 passes. \[K1\]

## Verify in beta (input for #15)

Each item says what to test and what result decides it.

1. **B1. Soft-interact on the bobber.** With `SoftTargetInteract=3`, cast Fishing on Forever.
   - Does `PLAYER_SOFT_INTERACT_CHANGED` fire with the bobber GUID (object 35591 or a Forever-specific ID)?
   - Do `INTERACTTARGET` and the Interact key reel it in?
   - Decides whether one key can reel without the mouse over the bobber.
2. **B2. Override bindings on Forever.** Out of combat, can `SetOverrideBindingSpell(owner, true, key, "Fishing")` and `SetOverrideBinding(owner, true, key, "INTERACTMOUSEOVER")` be set, re-pointed during the channel, and fired by a key press? Is the Fishing spell name `PROFESSIONS_FISHING` and are the spell IDs in Angleur's Vanilla table (7620, 7731, 7732, 18248, 33095, 51294, …) right?
3. **B3. `GLOBAL_MOUSE_DOWN`/`GLOBAL_MOUSE_UP`.** Do they exist and fire on Forever? Does an override set on the first mouse-down catch the second click (the double-click pattern)?
4. **B4. Applying a lure from a secure button.** Test both `macrotext "/use <lure>\n/use 16"` (Angleur) and `type=item` + `target-slot=16` (Fishing Buddy). Does `GetWeaponEnchantInfo()` return a **non-secret** enchant ID out of combat? What are the Forever lure enchant IDs, including any Fishing Rack lures?
5. **B5. Secret values out of combat.** Are `UNIT_SPELLCAST_*` payloads, `C_Item.GetItemCount` and `GetWeaponEnchantInfo` readable while fishing in the open world? Does `C_Secrets.ShouldAurasBeSecret()` ever turn true while fishing? It throws on aura reads. \[K1\]
6. **B6. Opening clams and containers.** Does a key press on the secure button (`/use <item>`) open a clam on Forever? Do the camp objects (Fish Bowl, Fishing Rack, Fishing Hut) place through a secure item button?
7. **B7. Aura reads for extra items.** Does `C_UnitAuras` return buff durations (food, lure buffs) out of combat without secrets?
8. **B8. Toys.** Do Forever's account-wide Collections include fishing toys (rafts, bobbers)? Does `type=toy` work?
9. **B9. Equipment manager.** Does Forever have equipment sets? Classic Era lacked a native one. Do `C_EquipmentSet.CreateEquipmentSet/UseEquipmentSet` and `/equipset` work out of combat?
10. **B10. In-combat weapon swap.** Does a pre-built secure macro button with `/equip` re-equip weapons during combat?
11. **B11. CVar names.** Do `SoftTargetInteract*`, `autoLootDefault`, `Sound_*` and `autoInteract` exist on Forever, and can addons set them?
12. **B12. Secure snippets on the current build.** Re-check that `SecureHandlerWrapScript` works (fixed in 70009 per \[K1\]). This only matters if we copy Fishing Buddy. Our design avoids snippets.
13. **B13. Pet summon.** Is `C_PetJournal.SummonPetByGUID` callable from addon code on Forever? This only matters if we keep a pet feature, on a key press.
14. **B14. Beta hygiene.**
    - Do SavedVariables now load? Angleur's commit of 2026-09-28 says "saved variables now work in Forever". \[A3\]
    - Is `ReloadUI()` still protected?
    - Does `ADDON_RESTRICTION_STATE_CHANGED` fire on Forever?

## Caveats

- Angleur's Forever support is the author's claim: a "compatible with Forever beta" image, a dedicated TOC and commits. No independent report confirms each feature on Forever.
- The Fishing Buddy Forever ports are closed source. Their Forever-specific changes are unknown, and their mechanisms are assumed from upstream `LibFishing-1.0`.
- The Blizzard policy and EULA do not name fishing helpers. The "OK" verdicts rest on the protected-API line, Angleur's and Fishing Buddy's long, unpunished history (Fishing Buddy for over a decade, Angleur with 1.56M downloads) \[A1\]\[F1\], and the community reading that "Blizzard's typical response to addons that cross into automation is to break the APIs" rather than punish users. That reading comes from players, not staff. \[C1\]
- Blizzard can disable any of these mechanisms at will (Policy rule 8). \[P1\] The QoL Module must degrade cleanly if bindings or secure buttons are restricted.

## Sources

- \[A1\] Angleur CurseForge page: https://www.curseforge.com/wow/addons/angleur. Features, flavours (Retail, Forever, MoP, Classic, TBC), latest file 2.9.78 (2026-10-08), source link.
- \[A2\] Angleur source, branch `Forever-Beta` @ `73610ffb22d7b201f723c37d167402672fe0f889`: https://github.com/LegolandoBloom/Angleur/tree/Forever-Beta. Files cited inline. `release` branch @ `4df482f` for comparison.
- \[A3\] Angleur `Forever-Beta` commit history (2026-09-18 to 2026-10-08): https://github.com/LegolandoBloom/Angleur/commits/Forever-Beta
- \[F1\] Fishing Buddy fork source @ `fedacff`: https://github.com/r-log/FishingBuddy. Upstream: https://www.curseforge.com/wow/addons/fishingbuddy, https://www.wowinterface.com/downloads/info4239.html
- \[F2\] Fishing Buddy Forever Fix: https://www.curseforge.com/wow/addons/fishing-buddy-forever-fix
- \[F3\] Fishing Buddy (Forever) (Crusade): https://www.curseforge.com/wow/addons/fishing-buddy-crusade
- \[P1\] Blizzard, UI Add-On Development Policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
- \[P2\] Blizzard End User License Agreement §1.C: https://www.blizzard.com/en-us/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement
- \[W1\] Warcraft Wiki, Secure Execution and Tainting: https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting
- \[W2\] Warcraft Wiki, API CastSpellByName (protected; use a SecureActionButton or `/cast`): https://warcraft.wiki.gg/wiki/API_CastSpellByName
- \[W3\] Warcraft Wiki, Interact key (patch 10.0.0, `SoftTargetInteract`): https://warcraft.wiki.gg/wiki/Interact_key
- \[W4\] Warcraft Wiki, API SetOverrideBindingSpell (restricted, `#nocombat`): https://warcraft.wiki.gg/wiki/API_SetOverrideBindingSpell
- \[W5\] Warcraft Wiki, API C_Container.UseContainerItem (`#protected`): https://warcraft.wiki.gg/wiki/API_C_Container.UseContainerItem
- \[W6\] Warcraft Wiki, API C_EquipmentSet.UseEquipmentSet (`#nocombat`): https://warcraft.wiki.gg/wiki/API_C_EquipmentSet.UseEquipmentSet
- \[K1\] Thunderz96/forever-addon-kit, Forever beta findings (build 1.60.1.69893; snippet fix in 70009; `ReloadUI` protected; unknown events throw; SavedVariables bug; secret auras): https://github.com/Thunderz96/forever-addon-kit
- \[C1\] Blizzard forums, "Addon development. Automated functions" (player replies, low trust): https://us.forums.blizzard.com/en/wow/t/addon-development-automated-functions/1496311
