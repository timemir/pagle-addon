# QoL

> Status: Done · Milestones: M1 (Fishing key: cast, reel, loot guard; the soft-interact lease; the conflict popup), Track Q (the rest of v1), M9 (launch re-verification) · Sources: [Define the QoL feature set](https://github.com/timemir/pagle-addon/issues/16#issuecomment-6113508077), [Beta probe: which QoL mechanisms work on Forever?](https://github.com/timemir/pagle-addon/issues/15#issuecomment-6110400978), [What does Angleur do, and which of it is allowed on Forever?](https://github.com/timemir/pagle-addon/issues/4#issuecomment-6109739552), [Prototype Pagle's sounds](https://github.com/timemir/pagle-addon/issues/23#issuecomment-6113915981), [Cut the MVP slice and roadmap](https://github.com/timemir/pagle-addon/issues/18#issuecomment-6113973068), [Prototype the Settings tree](https://github.com/timemir/pagle-addon/issues/32#issuecomment-6129969765), [Define the Core/Module contract](https://github.com/timemir/pagle-addon/issues/9#issuecomment-6112445901); ADR 0001. Evidence: [`docs/research/angleur-qol-feasibility.md`](../research/angleur-qol-feasibility.md), [`probes/qol/results/2026-10-11-build70338-report.md`](../../probes/qol/results/2026-10-11-build70338-report.md)

QoL is the `Pagle_QoL` addon: the Fishing key, the double-click cast, gear, lures and clams on a keypress, the client settings leased for a Fishing stretch, the next-action button and Nudges. Its one fixed rule: **each player keypress or click does at most one game action, and QoL never does a game action on its own.**

Terms are used as `CONTEXT.md` defines them. A **game action** is the character acting in the world: casting, using or applying an item, interacting with an object, equipping gear. Key bindings, CVars, equipment-set definitions (even though the game stores them on the server), frames and sounds are not game actions. Every user-facing string below goes through `ns.L` (CORE-R8).

## Purpose and boundary

**Owns:**
- the Fishing key and the "Pagle: Swap gear" binding
- the double-click cast and the Input setting
- choosing the next action (the ladder, QOL-R20) and arming it
- the fishing set and *Pagle Previous*
- lures on key, clam opening
- the Fishing stretch and the client settings leased for it (soft-interact, the audio mix, auto-loot), with their restore
- the next-action button
- Nudges
- the conflict note for Angleur and Fishing Buddy
- its own small item tables: lures and clams (QOL-R54, QOL-R57)

**Doesn't own:** recording anything (Core records every Cast whether or not QoL is on), Announcements (QoL raises none), Pagle Coins (QoL pays none, SHOP-R1), the Settings pages (Core's; QoL adds rows to Fishing).

**Uses from Core:** `RegisterModule`, the fishing events (`CastStarted`, `CastEnded`, `FishingStateChanged`), restriction state (`IsRestricted`, `RestrictionChanged`), `Pagle.RegisterEvent` / `RegisterUnitEvent` for every WoW event, `M:AddSetting` on the Fishing page, the compartment menu and `/pagle`.

**Not in 1.0:**
- **Recast reminder** (after 1.0): opt-in, a quiet wooden double knock on the SFX channel when no new fishing channel starts within 2 s of one ending. It's a QoL sound, not an Announcement (ANN-R75), and gets its own spec rules when it is scheduled.
- **Combat weapon-swap button:** dropped because it failed on build 70338 (probe B10). It is re-tested in M9 (QOL-R101); a pass opens a new ticket, not a rule here.
- **Never:** a camera sweep or any bobber finding (Angleur's Bobber Scanner), gear swaps triggered by events, timer-driven pet summons, item slots with free macro text, generic extra-item slots, toys, rafts and pets (none on Forever), a gamepad cursor and a separate recast key.

## Rules

### Packaging and attaching

- **QOL-R1** `Pagle_QoL` follows CORE-R1–R3 and CORE-R11, with `## X-Pagle-API: 3` (from 1.6, as every Module, CORE-R15; 2 from 1.1, for `Pagle.GetLanguage`, CORE-R8; 1 in 1.0). Its SavedVariable is `PagleQoLDB` (AceDB, account-wide, one shared profile; see [Data](#data)). It ships a `Bindings.xml` with the two bindings in QOL-R10 and QOL-R46 under the header "Pagle" (`category="ADDONS"`, with `BINDING_HEADER_PAGLE` and the `BINDING_NAME_*` globals defined), so a disabled QoL leaves no binding entries behind.
- **QOL-R2** In `OnInitialize`, QoL calls `Pagle.RegisterModule` with:

  ```lua
  {
    name = "QoL", title = "QoL", order = 50,
    settingsAction = { label = "Fishing settings »", onClick = function() Pagle.OpenSettings("fishing") end },
    menu = { { label = function() return "Input: " .. inputLabel() end, onClick = cycleInput } },   -- QOL-R16
    slash = { { name = "qol", fn = qolSlash, help = "input key|click|both: choose how you cast" } }, -- QOL-R17
  }
  ```

  The help text doesn't repeat "qol": `/pagle help` already prints it as `/pagle qol: …` (CORE-R60). It has no views. It adds its settings with `M:AddSetting("fishing", …)` before `ModulesChanged` (CORE-R42; rows under [Settings](#settings)).
- **QOL-R3** QoL keeps no projection, appends no Module records, raises no moments, sets no summary line, pays no Coins, registers no goods, slots or tracker. It never reads the Catch log.
- **QOL-R4** Core alone observes Casts and Catches (ADR 0001). QoL reads the live game state it needs to choose and arm its next action (the main-hand item, bag counts, the pole's lure enchant, mount state, open loot windows, the end of the player's channel, equipment sets, key bindings) and uses it for nothing else: it records, counts and publishes none of it.
- **QOL-R5** Everything QoL does on its own (on an event, a timer or a setting change) changes only bindings, CVars, equipment-set definitions and frames, never game state. Every game action QoL makes possible is the target of one press (QOL-R24).
- **QOL-R6** QoL uses no secure snippets (`SecureHandlerWrapScript` and the like) and no macro text with more than one command. It calls `ReloadUI()` only from a click on a button that says it reloads (the Reload now note, QOL-R83), never on its own: not at load, on an event, a timer or a restriction change.

### Inputs

- **QOL-R10** The **Fishing key** is the binding `PAGLE_FISHING_KEY`, listed as "Pagle: Fishing key" in Key Bindings › AddOns. The player binds it like any key; QoL never borrows another binding for it (the double-click's short-lived `BUTTON2` override, QOL-R13, is the only override on a key the player didn't give Pagle). Its own body (what runs when QoL has not armed it) does nothing.
- **QOL-R11** To **arm** the Fishing key, QoL sets a priority override binding (`SetOverrideBinding*(owner, true, key, …)`, one owner frame) on every key `GetBindingKey("PAGLE_FISHING_KEY")` returns (up to two), pointing at the next action's target (QOL-R24). To **disarm** it, QoL clears that owner's override bindings (`ClearOverrideBindings(owner)`). With no key bound, there is nothing to arm, and the next-action button shows no hotkey.
- **QOL-R12** **Input** is *Fishing key*, *Double-click* or *Both* (default *Both*). The Fishing key is armed only under *Fishing key* or *Both*; the double-click is live only under *Double-click* or *Both*.
- **QOL-R13** The **double-click** is a right double-click on the game world:
  - A **qualifying click** is a `"RightButton"` `GLOBAL_MOUSE_DOWN` followed by its `GLOBAL_MOUSE_UP` within the click hold limit, so a right-drag that turns the camera never counts. It counts only when it lands on the game world: at the mouse-up, `GetMouseFoci()` (or `GetMouseFocus()` where that is missing) returns only `WorldFrame`, or nothing.
  - On a qualifying click's mouse-up, when the double-click is live (QOL-R14) and no window is open, QoL opens the **double-click window**: it sets a priority override binding on `BUTTON2` (its own owner frame, separate from the Fishing key's) to the next action's target, evaluated now without the gear step (QOL-R20 step 3).
  - The window closes, and the `BUTTON2` override is cleared, on the frame after the next `"RightButton"` `GLOBAL_MOUSE_UP` (so a click that fires on key-up still reaches it) or after the double-click window time, whichever comes first. While the window is open, every re-evaluation (QOL-R25) re-points `BUTTON2` too; if the target becomes *nothing* (for example a loot window opened because the first click reeled the bobber), the window closes at once. The mouse-up that closes a window never opens a new one, so a triple click is one double-click and one ignored click.
  - The second right-click's press inside the window does the action. A single right-click still turns the camera and does nothing else.
- **QOL-R14** The double-click is live only while all of these hold: Input allows it, QoL is armed (QOL-R30), a fishing pole is in hand (QOL-R21), and the next action isn't *nothing*.
- **QOL-R15** The double-click never equips the fishing set (QOL-R20 step 3 is skipped), so a double-click with no pole in hand does nothing.
- **QOL-R16** The compartment entry's label is "Input: Fishing key", "Input: Double-click" or "Input: Both". Clicking it cycles *Both* → *Fishing key* → *Double-click* → *Both*.
- **QOL-R17** `/pagle qol input key|click|both` sets Input and prints "Pagle: cast with the Fishing key." / "Pagle: cast with a double right-click." / "Pagle: cast with the Fishing key or a double right-click.". `/pagle qol` with no argument opens the Fishing page (`Pagle.OpenSettings("fishing")`). Anything else prints the usage line "Pagle: /pagle qol input key|click|both".
- **QOL-R18** A change to Input, from any of the three places, takes effect at once (QOL-R25), or when restriction ends if it is made in combat (QOL-R32).

### The next action


- **QOL-R20** On each evaluation QoL picks the **next action** by checking these in order; the first that holds wins, so a press is always one game action:
  1. QoL is disarmed (QOL-R30), a loot window is open (QOL-R28), or the player is casting a spell with a cast time (`UnitCastingInfo("player")` isn't `nil`, such as a lure going on) → **nothing**
  2. The player is channeling Fishing (QOL-R22) → **reel**, unless the reel didn't take (QOL-R35), then **cast**
  3. The gear step is ready (QOL-R43; with no fishing set chosen, from 1.7, QOL-R48) → **equip the fishing set**, or with no set **the best pole from the bags** (Fishing key only; the double-click skips this step)
  4. Lures aren't *Off*, a pole is in hand, the pole has no lure on (`GetWeaponEnchantInfo()` returns `false` for the main hand), and a lure is available (QOL-R51) → **apply that lure**
  5. *Open clams between Casts* is on and a clam is available (QOL-R55) → **open one clam**
  6. Otherwise → **cast**

  The lure goes on before a cast, never mid-channel. Clams open between Casts, one per press, wherever the player is.
- **QOL-R21** A **fishing pole is in hand** when the main-hand slot (16) holds an item whose `C_Item.GetItemInfoInstant` class is Weapon (2) and subclass Fishing Pole (20). The same test decides whether an item is a fishing pole anywhere else in this file.
- **QOL-R22** **Channeling Fishing** starts at Core's `CastStarted` and ends at the player's `UNIT_SPELLCAST_CHANNEL_STOP`, which QoL registers with `Pagle.RegisterUnitEvent(…, "player", …)` only to re-point its key (QOL-R4). It doesn't wait for Core's grace time (LOG-R7), so a press right after the bobber is lost already casts again. When QoL arms after a load, it also counts as channeling if `UnitChannelInfo("player")` returns the Fishing spell's name (QOL-R24), so a `/reload` mid-channel still reels.
- **QOL-R23** With no pole in hand and no gear step ready (from 1.7, with no fishing set chosen, that is with no usable pole in the bags either, QOL-R48), the ladder still runs: a clam opens if one is available, otherwise the key casts and the game's own error says a pole is needed. Being mounted changes nothing in the ladder (it only ends a Fishing stretch, QOL-R61): a press while mounted does what the ladder says, and the game dismounts or refuses as its own settings decide.
- **QOL-R24** Each next action has exactly one target, and each target is one game action. The Fishing spell is named by `C_Spell.GetSpellName(7620)` (every rank shares the name, and the binding casts the highest one known). Checked on build 1.60.1.70790 on 2026-11-05 (the launch probe, #272): 7620 and Forever's four rank spells 1240948, 1240959, 1240970 and 1240983 are all named "Fishing".

  | Next action | Fishing key override | Double-click override (`BUTTON2`) | Evidence |
  |---|---|---|---|
  | cast | `SetOverrideBindingSpell(owner, true, key, fishingName)` | the same on `BUTTON2` | key: probe B1, B2. Double-click: QOL-R105 (both values) |
  | reel | `SetOverrideBinding(owner, true, key, "INTERACTTARGET")` (soft-interact, QOL-R62) | `INTERACTTARGET` on `BUTTON2` at `ActionButtonUseKeyDown` 1; at 0, no target, and the game's right-click on the bobber reels | key: probe B1. `BUTTON2`: QOL-R105 |
  | equip the fishing set | `SetOverrideBindingClick(owner, true, key, "PagleQoLGearButton")` | never | B9 proved `UseEquipmentSet` from addon code on a keypress |
  | equip the best pole (no fishing set, from 1.7, QOL-R48) | the same click | never | **unverified**: `C_Item.EquipItemByName` from the button's `OnClick` on a keypress is first seen in production (no in-game test before 1.7.0, the dev's decision of 11 Nov 2026) |
  | apply a lure | `SetOverrideBindingClick(owner, true, key, "PagleQoLActionButton")`, the button set to `type = "item"`, `item = "item:<lureID>"`, `target-slot = 16` (QOL-R52) | the same on `BUTTON2` | probe B4; `target-slot`: the exit check (#147) |
  | open a clam | the same button, `item = "item:<clamID>"`, no `target-slot` | the same on `BUTTON2` | same mechanism as B4; re-verified in M9 (QOL-R100) |
  | nothing | no override (disarmed) | no override | |

  `PagleQoLActionButton` is one `SecureActionButtonTemplate` button. `PagleQoLGearButton` is a plain `Button` whose `OnClick` runs QOL-R44. Neither is ever shown.
- **QOL-R25** QoL re-evaluates the next action:
  - on Core's `CastStarted`, `CastEnded`, `FishingStateChanged`, `RestrictionChanged`
  - on `UNIT_SPELLCAST_CHANNEL_STOP`, `UNIT_SPELLCAST_START` and `UNIT_SPELLCAST_STOP` (player), `LOOT_READY`, `LOOT_CLOSED`, `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED` (player), `PLAYER_MOUNT_DISPLAY_CHANGED`, `EQUIPMENT_SETS_CHANGED`, `UPDATE_BINDINGS`, and `CVAR_UPDATE` for `ActionButtonUseKeyDown` (so an open double-click window drops its reel at once at 0, QOL-R105)
  - on any QoL setting change
  - every 0.5 s while armed, which catches a lure expiring between events

  It re-points its overrides (the Fishing key's and an open double-click window's) only when the pair (bound keys, target) differs from what is set now, so the `UPDATE_BINDINGS` its own override calls may fire never loops. It reads the Fishing key's bound keys with `GetBindingKey("PAGLE_FISHING_KEY")` and caches them, refreshing the cache only on `UPDATE_BINDINGS`.

  Beyond this tick and the per-frame key checks (QOL-R26, QOL-R35), QoL runs no tick at rest: the motion of its frames (the conflict note's and the Nudge's fades) holds a per-frame update only while something animates, and drops it when the last one settles.
- **QOL-R26** When a re-point is due while a Fishing key is held down (`IsKeyDown` on the key's last part, the key without its modifiers), QoL checks again every frame and re-points on the first frame it is up, so a held key never fires two actions.
- **QOL-R27** `PagleQoLActionButton` and `PagleQoLGearButton` fire once per press: they register for clicks on key-down when the `ActionButtonUseKeyDown` CVar is `1`, otherwise on key-up (`RegisterForClicks("AnyDown")` or `("AnyUp")`), re-read whenever QoL arms (sets overrides, QOL-R11) and on `CVAR_UPDATE` for `ActionButtonUseKeyDown`.
- **QOL-R28** **Loot guard:** a loot window is open from `LOOT_READY` until `LOOT_CLOSED`, for fishing loot or any other loot (a clam's, a mob's). While it is open the next action is *nothing*, so a press can't close it with a recast.
- **QOL-R29** **Waiting for a press's result.** Some results arrive after the press, so QoL holds the step back meanwhile:
  - After a swap, to the fishing set (QOL-R44) or back (QOL-R45), the gear step isn't ready (QOL-R43), and Swap gear does nothing, until `EQUIPMENT_SWAP_FINISHED` or the result wait, whichever comes first. Either swap can leave a half-swapped outfit meanwhile.
  - *From 1.7,* with no fishing set chosen: after a pole goes on (QOL-R48) or a swap back (QOL-R49), the same, until `PLAYER_EQUIPMENT_CHANGED` for the main hand (16) or the off hand (17), or the result wait. A failed equip (bags too full for the off hand a two-handed pole sends to them, a level the character lacks) is never skipped for the session as a lure is: the game says why, and the next press tries again.
  - After a lure's use finishes casting (`UNIT_SPELLCAST_SUCCEEDED` for the player), the pole counts as lured until `GetWeaponEnchantInfo()` shows the lure or the result wait passes.
  - If a lure's use fails (`UNIT_SPELLCAST_FAILED` for the player while that lure was the target), or the result wait passes with no lure on, that lure ID is skipped by QOL-R51 until the next login or `/reload`, or until fishing skill changes (`SKILL_LINES_CHANGED`). So a lure the game won't apply never blocks the key.
- **QOL-R35** **The reel didn't take.** A bobber beyond the game's interact range can't be reeled: `INTERACTTARGET` does nothing and the channel runs on. So a reel that changes nothing turns the next press into a cast:
  - A **reel press** is a Fishing key going down while its override is the reel (QOL-R24). The override reports no press to addon code, so QoL looks: every frame while armed, it checks each bound key with `IsKeyDown` on the key without its modifiers (as QOL-R26), and a key down on this frame and up on the one before is one press. Probe B1's key watcher saw every `INTERACTTARGET` press this way. A press shorter than a frame can go unseen; the next one is seen.
  - When the reel wait has passed since a reel press and the player is still channeling Fishing with no loot window opened since, **the reel didn't take**: QoL re-evaluates at once (QOL-R25, R26), the next action is *cast* (QOL-R20 step 2), and the next press casts again. That cast ends the old Cast, which Core records as interrupted (LOG-R7).
  - A waiting reel press is dropped, and the reel didn't take is cleared, when the channel stops (QOL-R22), a new channel starts (Core's `CastStarted`), a loot window opens (QOL-R28) or QoL is disarmed (QOL-R30: restriction, standing down). Another reel press while one waits changes nothing.
  - Only the Fishing key's presses are watched. The double-click reads the same ladder (QOL-R13), so once the reel didn't take its window casts too, but its second click never counts as a reel press: at `ActionButtonUseKeyDown` 0 its reel is the game's own right-click (QOL-R105), which QoL can't tell from a camera click.
  - QoL can't see why a reel failed, so this is a guess on purpose. It never looks for the bobber, and there is no separate recast key (see "Never").

### Arming, combat and restriction

- **QOL-R30** QoL is **armed** while all of these hold: it registered with Core, it is logged in (from `PLAYER_LOGIN`, QOL-R33, until `PLAYER_LOGOUT`), it isn't standing down (QOL-R82), and `Pagle.IsRestricted()` is false. Otherwise it is disarmed: no override bindings, no double-click, and the next action is *nothing*. From `PLAYER_LOGOUT` on, QoL evaluates nothing (QOL-R25) and reads no setting: AceDB-3.0 may already have stripped `PagleQoLDB`'s defaults, and each restore's `SetCVar` fires `CVAR_UPDATE` (QOL-R61, QOL-R63). It makes no binding call either; the overrides set go with the session.
- **QOL-R31** **Restriction starts:** on `PLAYER_REGEN_DISABLED` (which runs before combat lockdown starts) and on `RestrictionChanged(true)`, whichever comes first, if `InCombatLockdown()` is still false QoL disarms (clears both owners' override bindings). It does this even though `Pagle.IsRestricted()` may already be true; it never arms there. In the same handler it ends the Fishing stretch (QOL-R61), restoring every leased CVar it can (QOL-R63). If `InCombatLockdown()` is already true, the overrides stay until restriction ends, the stretch still ends, and the restores wait (QOL-R66).
- **QOL-R32** **Leaving restriction:** on `RestrictionChanged(false)` QoL re-evaluates (QOL-R25) and re-arms. Every arm, override change or secure-frame change that falls due while restricted is skipped, and that re-evaluation does it (CORE-R32); QoL keeps no queue of its own.
- **QOL-R33** QoL creates its owner frames and buttons in `OnInitialize`. After a `/reload` in combat, it creates them at `RestrictionChanged(false)`, and stays disarmed until then. It first arms at `PLAYER_LOGIN`, right after the conflict check (QOL-R80), so it never arms and then stands down.
- **QOL-R34** Combat never swaps gear: the pole stays in hand, and swapping back is up to the player.

### Gear

- **QOL-R40** The **fishing set** is one of the character's own equipment sets, chosen per character (keyed by character GUID). The choice is stored as the set's ID and name; if no set has that ID with that name any more, no set is chosen. *Pagle Previous* can't be chosen. Set IDs are looked up with `C_EquipmentSet.GetEquipmentSetID(name)`, since `CreateEquipmentSet` returns none.
- **QOL-R41** "Save what I'm wearing as my fishing set" saves the gear worn now, with no ignored slots (`C_EquipmentSet.ClearIgnoredSlotsForSave()` first), into a set named *Pagle Fishing* (`C_EquipmentSet.CreateEquipmentSet(name, icon)` if it doesn't exist, with the main-hand item's icon if it is a fishing pole, else the Fishing spell's; `SaveEquipmentSet` if it does) and chooses it (QOL-R42). It is disabled while restricted, and so is the Fishing set dropdown.
- **QOL-R42** Choosing a fishing set also creates *Pagle Previous* from the gear worn now if it doesn't exist, so its slot is taken up front. *Pagle Previous* is never saved from gear with a fishing pole in hand (QOL-R21), so with one in hand the choice creates no *Pagle Previous*: the slot check below is then all that reserves its slot, and the first swap to the fishing set creates it (QOL-R44). Before creating anything, QoL counts the free slots (`MAX_EQUIPMENT_SETS_PER_PLAYER` minus `C_EquipmentSet.GetNumEquipmentSets()`) against the sets it would create (*Pagle Fishing* for QOL-R41, *Pagle Previous* while it doesn't exist, counted with a pole in hand too). If there are too few, it creates nothing, keeps the previous choice (the dropdown re-reads it and shows that), and prints "Pagle: needs a free equipment set slot for Pagle Previous." (or "…two free equipment set slots…" when both are needed). The set names *Pagle Fishing* and *Pagle Previous* are lookup keys, never translated.
- **QOL-R43** The **gear step is ready** when a fishing set is chosen, no fishing pole is in hand, the set's main-hand item (`C_EquipmentSet.GetItemIDs(setID)[16]`) is a fishing pole, and none of the set's items is missing (`GetEquipmentSetInfo`'s `numLost` is 0), and no swap is still settling (QOL-R29). So a set without a pole, or with its pole in the bank, never offers the step, and pressing again can't overwrite *Pagle Previous* with a half-swapped outfit.
- **QOL-R44** A **swap to the fishing set** (the Fishing key's gear step, or Swap gear) first saves the gear worn now into *Pagle Previous*, with no ignored slots (`SaveEquipmentSet`, or `CreateEquipmentSet` with the main-hand item's icon if it doesn't exist and a slot is free), then calls `C_EquipmentSet.UseEquipmentSet(fishingSetID)` once. With a fishing pole in hand (a swap that ended half done, or a fishing item put on by hand), it saves nothing, since *Pagle Previous* is never saved from gear with a pole in hand: it only calls `UseEquipmentSet(fishingSetID)`. If *Pagle Previous* is missing and can't be created, the swap still happens and there is nothing to swap back to. Saving a set definition isn't a game action; the swap is one, like Blizzard's own set button.
- **QOL-R45** A **swap back** calls `C_EquipmentSet.UseEquipmentSet(previousSetID)` once.
- **QOL-R46** **Swap gear** is the binding `PAGLE_SWAP_GEAR`, listed as "Pagle: Swap gear". Its body: if QoL isn't armed (QOL-R30), nothing. *From 1.7,* with no fishing set chosen: with no fishing pole in hand, the best pole goes on (QOL-R48) if there is one; with one in hand, the swap back (QOL-R49) while it has an equip to make; otherwise nothing, and nothing while an equip settles (QOL-R29). (Before 1.7, with no fishing set chosen it did nothing.) With a fishing set chosen: Otherwise, if the fishing set is fully worn (`GetEquipmentSetInfo`'s `isEquipped`), a swap back if *Pagle Previous* is there, else nothing; otherwise, if none of the fishing set's items is missing, a swap to the fishing set; else nothing. *Pagle Previous* is there when it exists and its main-hand item (`C_EquipmentSet.GetItemIDs(previousSetID)[16]`) isn't a fishing pole. One whose main hand is a pole counts as absent, so there is no swap back into it; the next swap to the fishing set without a pole in hand saves over it (QOL-R44).
- **QOL-R47** QoL never swaps gear without a press. When a Fishing stretch ends with the fishing set still worn, it shows the swap-back Nudge (QOL-R77).
- **QOL-R48** *From 1.7 (pagle-2026k; the dev's decision, 11 Nov 2026).* **No fishing set: the pole from the bags.** With no fishing set chosen (QOL-R40), QoL equips a fishing pole from the bags in place of a set:
  - A pole is **available** when it is in the bags (bags 0–4, read with `C_Container.GetContainerItemID`), it is a fishing pole (QOL-R21), and `C_Item.IsUsableItem` says the character can use it (which covers a required level). The **best pole** is the available one with the highest Fishing bonus in the pole table, ties to the lower item ID, as *Best I have* picks a lure (QOL-R51). Unlike a lure, a pole the table doesn't list is still a candidate, counted with no bonus, so a pole Forever adds is still put on.
  - The **gear step is ready** with no fishing set when no fishing pole is in hand, a pole is available, and no equip is settling (QOL-R29).
  - **Putting the pole on** (the Fishing key's gear step, or Swap gear): QoL first remembers the main-hand and off-hand items worn now (slots 16 and 17, each by item ID and link, `GetInventoryItemID` and `GetInventoryItemLink`; an empty slot as none) in `PagleQoLDB.global.poleSwap[guid]`, the character's own, replacing what it held: the pole goes on only with no pole in hand, so what is worn then is always what to come back to. Then it calls `C_Item.EquipItemByName(poleID, 16)` once: one game action, from `PagleQoLGearButton`'s `OnClick` as the set's swap is (QOL-R24). No equipment set is made, used or saved, and *Pagle Previous* isn't touched. A pole that binds when equipped shows the game's own confirm; QoL never confirms it.
  - The **pole table** is QoL's own, in `addons/Pagle_QoL/data/poles.lua`: `{ itemID, bonus }` per pole, the Classic poles, each bonus read from Forever 1.60.1.70862's DB2 (the "Fishing Skill +N" spells):

    | Item | itemID | Bonus |
    |---|---|---|
    | Fishing Pole | 6256 | 0 |
    | Blump Family Fishing Pole | 12225 | 3 |
    | Strong Fishing Pole | 6365 | 5 |
    | Darkwood Fishing Pole | 6366 | 15 |
    | Big Iron Fishing Pole | 6367 | 20 |
    | Nat Pagle's Extreme Angler FC-5000 | 19022 | 25 |
    | Arcanite Fishing Pole | 19970 | 35 |
- **QOL-R49** *From 1.7.* **Swapping back with no fishing set.** With no fishing set chosen and a fishing pole in hand, Swap gear puts the remembered weapons back (QOL-R48), in one press:
  - The remembered main-hand item goes into slot 16 (`C_Item.EquipItemByName(link, 16)`) when it is in the bags; then the remembered off-hand item into 17, only when the main hand will hold a one-handed item that isn't a fishing pole (the one going on, or the one already there) and the off-hand item is in the bags. So a two-hander coming back leaves the off hand in the bags, and a main-hand item no longer in the bags leaves the pole on, the off hand with it.
  - An entry whose item is already worn in its slot is spent; one whose item is in neither the bags nor its slot is dropped, as is an off hand a two-hander leaves out. When the swap back has no equip to make, Swap gear does nothing and the pole stays.
  - The remembered weapons are cleared one by one: on `PLAYER_EQUIPMENT_CHANGED` for slot 16 or 17, with no fishing pole in hand, each entry whose item is worn in its slot again is spent, whatever put it on (the swap back, or the player by hand). With a pole in hand nothing is spent, so the press that put the pole on keeps what it remembered. They survive a `/reload` or relog until then, and if a swap back didn't take (the result wait passes with the pole still in hand), the next press tries again.
  - Choosing a fishing set keeps them; with a set chosen, Swap gear and the gear step follow QOL-R43–R46 and never read them, and they are used again once the set is back to None.
  - **Unverified:** two equips in one press, one into each hand, are first seen in production (QOL-R24's table).


### Lures

- **QOL-R50** **Lures** is *Off*, *Best I have* (default) or *Only this one*, with a chosen lure for *Only this one* (default Shiny Bauble).
- **QOL-R51** A lure is **available** when it is in the bags (`C_Item.GetItemCount > 0`) and `C_Item.IsUsableItem` says it can be used, and it isn't being skipped after a failed use (QOL-R29). Under *Best I have*, the next lure is the available one with the highest bonus in the lure table (QOL-R54), ties to the lower item ID. Under *Only this one*, it is the chosen lure if available, else none.
- **QOL-R52** The lure is applied by item use on the secure button (QOL-R24), with `target-slot` 16 (the main hand, `INVSLOT_MAINHAND`), so it goes on the pole in hand in one press; no macro is needed. After its item action, the secure button applies a use that is targeting an item to its `target-slot` (forever's `SecureTemplates.lua`, `OnActionButtonClick`). Any other item use on the button, a clam's, has no `target-slot`. Found in the Track Q exit check (Forever beta 1.60.1.70338, 2026-10-13, #147): with no `target-slot`, the use alone starts targeting, and the lure goes on only when the player clicks the pole on the character sheet.
- **QOL-R53** **Out-of-lures Nudge:** when the pole's lure goes from on to off during a Fishing stretch, Lures isn't *Off*, and no lure is available, QoL shows "Your lure is gone and there are none left in your bags." (under *Best I have*) or "Your lure is gone and there's no {lure name} left in your bags." (under *Only this one*). At most once per Fishing stretch. There is no "running low" Nudge: the key re-applies lures by itself.
- **QOL-R54** The **lure table** is QoL's own, in `addons/Pagle_QoL/data/lures.lua`: `{ itemID, enchantID, bonus }` per lure, from the Classic baseline:

  | Item | itemID | enchantID | Bonus |
  |---|---|---|---|
  | Shiny Bauble | 6529 | 263 | 25 |
  | Nightcrawlers | 6530 | 264 | 50 |
  | Aquadynamic Fish Lens | 6811 | 264 | 50 |
  | Bright Baubles | 6532 | 265 | 75 |
  | Flesh Eating Worm | 7307 | 265 | 75 |
  | Aquadynamic Fish Attractor | 6533 | 266 | 100 |

  Only 6529 → 263 is proven on Forever (probe B4). The table, and any lure Forever adds (such as the Fishing Rack's), is re-verified in M9 (QOL-R100). Names come from `C_Item` at runtime.

### Clams

- **QOL-R55** A clam is **available** when one of the clam table's items is in the bags (`C_Item.GetItemCount > 0`). `C_Item.IsUsableItem` isn't read: on Forever it is `false` for a clam in the bags (beta 1.60.1.70338, 2026-10-13, #147). The lowest item ID in the bags opens first.
- **QOL-R56** *Open clams between Casts* is on by default. A clam opens only between Casts (QOL-R20 puts *reel* above it) and one per press.
- **QOL-R57** The **clam table** is QoL's own, in `addons/Pagle_QoL/data/clams.lua`: Small Barnacled Clam (5523), Thick-shelled Clam (5524), Big-mouth Clam (7973). It holds only containers that open with a plain item use; locked boxes and other treasure aren't clams. Forever additions are found in M9 (QOL-R100).

### The Fishing stretch and leased client settings

- **QOL-R61** A **Fishing stretch** starts at Core's `CastStarted` while none is running and QoL is armed (QOL-R30), so never while restricted or standing down. It ends at the first of:
  - the pole comes off (QOL-R21 stops holding, on `PLAYER_EQUIPMENT_CHANGED`)
  - the player mounts (`IsMounted()` true, on `PLAYER_MOUNT_DISPLAY_CHANGED`)
  - restriction starts (QOL-R31)
  - 60 s pass since Core's last `CastEnded` (any outcome) with no fishing channel since
  - logout or `/reload` (`PLAYER_LOGOUT`)

  It is QoL's own live state, separate from the Session (LOG-R60). In `CONTEXT.md` terms, it starts with the first Cast's channel.
- **QOL-R62** For a stretch, QoL **leases** these CVars, each only if its feature is on:

  | Feature | CVars set for the stretch | On by default |
  |---|---|---|
  | Soft-interact (for the reel; can't be turned off) | `SoftTargetInteract` = 3; `SoftTargetInteractRange` = 15, only if the player's value is below 15; `SoftTargetInteractRangeIsHard` = 0 | always |
  | Fishing audio mix | each channel by its setting, below, then the output device (QOL-R68); `Sound_EnableAllSound` untouched. Under the defaults (master unticked; effects ticked at 100%; music, ambience and dialog ticked at 0%, Off; device Don't change) that is `Sound_EnableSFX` = 1, `Sound_SFXVolume` = 1.0, `Sound_EnableMusic` = 0, `Sound_EnableAmbience` = 0, `Sound_EnableDialog` = 0, in that order, with master untouched: 1.1's mix | on |
  | ↳ Keep sound in the background (only while the audio mix is on) | `Sound_EnableSoundWhenGameIsInBG` = 1 | off |
  | Auto-loot while fishing | `autoLootDefault` = 1 | on |

  A CVar that already holds the leased value (compared as numbers) isn't leased, so auto-loot is skipped if the player already has it on.

  *From 1.2.0,* the audio mix leases each channel by its Settings row, a box with a volume slider beside it, in this order:

  | Channel | Volume CVar | Switch CVar |
  |---|---|---|
  | Master | `Sound_MasterVolume` | none |
  | Effects | `Sound_SFXVolume` | `Sound_EnableSFX` |
  | Music | `Sound_MusicVolume` | `Sound_EnableMusic` |
  | Ambience | `Sound_AmbienceVolume` | `Sound_EnableAmbience` |
  | Dialog | `Sound_DialogVolume` | `Sound_EnableDialog` |

  - **Unticked** (Don't change): neither CVar is leased, whatever the slider says.
  - **Ticked at 0%** (Off): the switch = 0; the volume isn't leased.
  - **Ticked at *n*%** (5–100, in steps of 5): the switch = 1, then the volume = *n*/100, written with at least one decimal (`1.0`, `0.5`, `0.35`).
  - **Master** has no switch, so it has no Off: ticked, it leases only `Sound_MasterVolume` = *n*/100, its slider running from 10% to 100% and a lower stored value read as 10%, so the bobber's splash stays audible. `Sound_EnableAllSound` is never leased.
- **QOL-R63** **Lease and restore:**
  1. Before changing a CVar, QoL writes `{ name, orig }` (the player's value, as `GetCVar` returns it) into `PagleQoLDB.global.lease`.
  2. It sets the CVar with `SetCVar`, then stores what `GetCVar` reads back as `set` in the same entry. *From 1.2.0:* if `GetCVar` reads back nothing, as the output device may while the sound system restarts (QOL-R68), `set` is the value it set.
  3. When the stretch ends, it restores each leased CVar to `orig` **only if it still reads `set`** (compared as numbers when both parse as numbers, else as strings): a value the player changed during the stretch is theirs and stays. Then the entry is removed. An entry whose restore must wait (QOL-R66) stays until it is restored.
- **QOL-R64** **Leftover restore:** at `ADDON_LOADED`, before anything else, QoL restores every entry left in `global.lease` under the same "still reads `set`" test and removes each entry it restored. If `InCombatLockdown()` is true at load (a `/reload` in combat), these wait as in QOL-R66.
- **QOL-R65** Turning the audio mix, its background option or auto-loot off during a stretch restores its CVars at once (turning the audio mix off restores the background CVar and the output device too); turning one on leases them at once. *From 1.2.0,* ticking or unticking a channel, moving its slider or changing the output device during a stretch does the same CVar by CVar: a CVar the new setting no longer leases is restored at once, one it newly leases is leased at once, and one it leases at a new value (effects from 100% to 50%, another device) is set to that value at once, each step of a slider being a change. While that CVar still reads its entry's `set`, the entry keeps its `orig` and takes the new `set`, so the restore at the end still puts back the player's own value (QOL-R63); a CVar the player changed since is leased afresh from their value.
- **QOL-R66** A CVar restore that falls due while `InCombatLockdown()` is true waits for `RestrictionChanged(false)`.
- **QOL-R67** **After a crash.** SavedVariables are written only at logout or `/reload` (LOG-R85), and QoL restores at `PLAYER_LOGOUT`, so a crash leaves no lease in `PagleQoLDB` to restore; QOL-R64 only catches restores that were deferred or failed. QoL makes no promise about a crash. Whether leased CVars stay changed after one is checked in M1 dogfooding: kill the client mid-stretch, log in, and read the leased CVars. If they stayed changed, a follow-up ticket designs a fix; until then this rule stands.
- **QOL-R68** *From 1.2.0.* **The output device.** The audio mix's Output device row names a device by the name the client gives it, or Don't change. At each lease QoL lists the client's devices (`Sound_GameSystem_GetNumOutputDrivers()` and `Sound_GameSystem_GetOutputDriverNameByIndex(index)`, indices from 0, as Game › Sound lists them) and, if the chosen name is among them, leases `Sound_OutputDriverIndex` = its index (the first, if two share the name), after the channels, under QOL-R62–R66 like every other CVar: only away from its value, restored only while it still reads `set`, waiting out lockdown, restored at load if left over, and never leased while standing down (QOL-R82). *From 1.2.4 (#597):* the client gives a device's name in the Windows code page, not UTF-8 ("Kopfh\xF6rer"), so the row shows each name readable: a byte outside a valid UTF-8 sequence is read as Windows-1252 (an undefined one as "?"), valid UTF-8 is left byte for byte, in each device's label and the "{device} (not found)" one. The option's value, what is saved and matched, stays the client's bytes.
  - The lease entry also keeps `origName`, the name of the player's own device at `orig`'s index when it was leased. Each restore first looks that name up in the client's list as it is then and, if it is there, restores its index now, so devices reordered in between (a headset unplugged, then a `/reload`) don't put back whatever took the old index. If the name is gone, the raw `orig` index is restored, as for any CVar. The "still reads `set`" test is unchanged.
  - A device that isn't listed (an unplugged headset), or a client without those calls, leases no device; the rest of the mix is leased as usual, and nothing errors. The row keeps the choice and lists it as "{device} (not found)"; the next stretch with the device back leases it.
  - Whenever a lease or a restore (at a stretch's start or end, a change mid-stretch, the leftover restore, the restore after lockdown) leaves `Sound_OutputDriverIndex` reading a different value from before it, QoL then calls `Sound_GameSystem_RestartSoundSystem()` once, so the sound moves to that device at once. One that leaves it as it was (Don't change, the chosen device already playing, a restore the player overruled) restarts nothing, and neither does the restore at `PLAYER_LOGOUT`: the client loads its sound from the CVars again after a logout or `/reload`.
  - The restart drops the game's sound for a moment, at a stretch's start and end; the row's tooltip says so.

### The next-action button

- **QOL-R70** The **next-action button** is a small, movable frame in the field art kit's look (see [UI](#ui)): the next action's icon, round (36 px) in a 52 px brass bezel; the Fishing key's first bound key on a brass key cap over the bezel's top left, in the short form action bars use (`GetBindingText(key, true)`; no key cap under Input *Double-click*, or with no key bound); and a one-word label on a slip of paper tucked under the bezel.
- **QOL-R71** Icon and label per next action: cast and reel show the Fishing spell's icon (`C_Spell.GetSpellTexture(7620)`) labelled "Cast" or "Reel"; equip shows the fishing set's icon, "Gear"; a lure shows its item icon, "Lure"; a clam its item icon, "Clam"; *nothing* keeps the last icon shown (the Fishing icon if none was shown yet), desaturated and greyed with the bezel, with no label. Checked on build 1.60.1.70790 on 2026-11-05 (the launch probe, #272): Forever's four rank spells have icon 134071, not 7620's 136245. The key and the Guide keep 7620's icon on purpose (the dev's call, 5 Nov 2026), so check 21's icon verdict is expected to fail.
- **QOL-R72** It is visible only while the setting is on, QoL isn't standing down, and a Fishing stretch is running, a fishing pole is in hand, or the gear step is ready (QOL-R43). The gear step with no fishing set (a pole in the bags, QOL-R48, from 1.7) doesn't count, so the button doesn't show for everyone who carries a pole: it shows once the pole is in hand. With *Hide until a fishing pole is in hand* on (from 1.2.0), the gear step alone doesn't show it: it waits for a Fishing stretch or a pole in hand, while the Fishing key still puts the fishing set on (QOL-R20). In combat it shows *nothing* (desaturated).
- **QOL-R73** It is display only: clicking it does nothing, and it isn't a secure frame. Shift-drag moves it (never while restricted); the position is saved in `PagleQoLDB.profile.indicator.point`. The Reset row puts it back at the default: bottom centre of the screen, 230 px up (above the main action bar).
- **QOL-R74** Hovering it shows a tooltip of its own to its right (the kit's lacquer tooltip: gilt words on a dark ground in a gilt hairline, not `GameTooltip`) naming the next action: "Cast", "Reel in", "Put on {set name}" (or, with no fishing set, "Put on {pole name}", QOL-R48), "Apply {lure name}", "Open {clam name}", or "Nothing to do". Item names come from `C_Item`, waiting for the item to load (`Item:ContinueOnItemLoad`) when it isn't cached.

### Nudges

- **QOL-R75** A **Nudge** is one line of text QoL draws itself in its own frame at the top centre of the screen, 4 px below the game's error text (`UIErrorsFrame`), on the field art kit's strip of paper (see [UI](#ui)), sized to the line, in the Angler's hand; a key in it sits on a brass key cap and a binding's name is printed in red. It shows for 3 s, then fades out over 0.5 s; with Core's Animations setting off, it goes at once after its 3 s. A new Nudge replaces the one showing.
- **QOL-R76** Nudges are silent, aren't Announcements (they don't go through Core, the Interruption budget or the Session summary), and still show in Cozy mode and in combat.
- **QOL-R77** **Swap-back Nudge:** when a Fishing stretch ends for any reason but restriction or logout, and Swap gear would swap back (the fishing set is fully worn and *Pagle Previous* is there, its main hand no fishing pole, QOL-R46; or, from 1.7, with no fishing set, the swap back to the remembered weapons has an equip to make, QOL-R49), QoL shows "Still holding your pole. Press *X* to swap back.", with *X* the first key bound to Swap gear, on its key cap. If Swap gear isn't bound, it reads "Still holding your pole. Bind Pagle: Swap gear to swap back in one press.", with "Pagle: Swap gear" in red.
- **QOL-R78** QoL has exactly two Nudges: the swap-back Nudge and the out-of-lures Nudge (QOL-R53).

### Coexisting with Angleur and Fishing Buddy

- **QOL-R80** At `PLAYER_LOGIN` (which also fires after a `/reload`), QoL looks for an **other fishing-key addon**: one whose folder name is in the conflict list (see [Tunables](#tunables)) and which is loaded (`C_AddOns.IsAddOnLoaded(name)`).
- **QOL-R81** If one or more is found, QoL shows the **conflict note**, a dialog of its own (a note pinned with wax, see [UI](#ui)) reading "Two addons want your fishing key." with two choices: "Use Pagle" and "Use {other}", where {other} is the other addon's title, or "Use the others" when there are several. Esc must not count as either choice: each choice runs only from a click on its own button, and Esc hides the note (it is in `UISpecialFrames`) without running either. Enter does nothing. The note is a real dialog, not a Nudge. While it, or the Reload now note in its place (QOL-R83), shows, QoL tells Core with `M:SetDialogOpen` (ONB-R100), so Core's Letter waits.
- **QOL-R82** From the moment a conflict is found until a login without one, QoL **stands down**: it is disarmed, Swap gear does nothing, no Fishing stretch starts, it binds nothing and leases no CVars. Its settings rows and compartment entry stay, and changes to them are saved. The leftover restore (QOL-R64) still runs.
- **QOL-R83** "Use Pagle" calls `C_AddOns.DisableAddOn(name)` for each other addon found (all characters), then prints "Pagle: turned off {other}. Type /reload to finish.", with {other} the titles joined by ", ". "Use {other}" calls `C_AddOns.DisableAddOn("Pagle_QoL")` (all characters) and prints "Pagle: turned off Pagle QoL. Type /reload to finish. Pagle keeps recording your Catches." Core and the other Modules are untouched. After either choice, the conflict note closes and QoL shows a second note in its place, the **Reload now note**, "Reload the interface now to finish?", with "Reload now" (calls `ReloadUI()`, QOL-R6) and "Later". "Later" and Esc close it without reloading, and the chat line still says to type /reload, for a player who closes it. *From 1.1 (#520):* the titles in that chat line, and in the Fishing step's resting line (QOL-R82), are joined by `ns.L.TITLES_JOIN` (", " in English), not by a literal.
- **QOL-R84** Closing the conflict note with Esc chooses nothing; QoL stands down for this session and asks again at the next login or `/reload`. There is no "don't ask again": whenever both are loaded at a login, the note returns.

### Launch re-verification

Checked on the live build in M9 (each failure retires or changes only the rule it names):

- **QOL-R100** Clam opening through the secure button (QOL-R24, R55–R57); the lure table's items and enchant IDs and any Forever lures (QOL-R54); any Forever clams (QOL-R57). If clams can't open by item use, clam opening is cut: QOL-R55, R56, R57 are retired and QOL-R20 step 5 removed.
- **QOL-R101** In-combat weapon swap through a secure button (dropped; a pass opens a new ticket).
- **QOL-R102** `C_AddOns.DisableAddOn` from addon code, and that `ReloadUI()` is still unprotected (QOL-R6, QOL-R83). Checked on build 1.60.1.70338 on 2026-10-13: a plain addon button whose `OnClick` calls `ReloadUI()` reloads the UI (Thunderz96/forever-addon-kit had found it protected on build 69893, `docs/research/angleur-qol-feasibility.md` [K1]). The Reload now note's button is such a plain button. If it is protected again at launch, the Reload now note is dropped and the chat line's /reload is the only way to finish.
- **QOL-R103** The equipment-set limit, with *Pagle Previous* taking a slot (QOL-R42). Checked on build 1.60.1.70790 on 2026-11-05 (the launch probe, #272): `MAX_EQUIPMENT_SETS_PER_PLAYER` is 10, so *Pagle Previous* takes one of 10.
- **QOL-R104** The conflict list's folder names, including the two Forever Fishing Buddy ports (QOL-R80).
- **QOL-R105** Checked earlier, while building the double-click (Track Q), with `ActionButtonUseKeyDown` at both 1 and 0: a direct `SetOverrideBindingSpell` on `BUTTON2` casts, and `INTERACTTARGET` on `BUTTON2` reels. If either fails, the double-click's target for that action becomes a click on a secure button (`type = "spell"`, as probe B3 proved) or, for the reel, the double-click doesn't reel and the game's own right-click on the bobber does. Result (Forever beta 1.60.1.70338, 2026-10-13; at water, pole in hand, `SoftTargetInteract` 3, right-clicking the world): at 1, the spell override casts and `INTERACTTARGET` reels; at 0, the spell override casts and `INTERACTTARGET` doesn't reel. So the cast stays a spell override at both values, and at 0 the double-click has no reel target (QOL-R24).

## Data

### `PagleQoLDB` (AceDB, one shared `Default` profile)

| Key | Type | Default |
|---|---|---|
| `global.schemaVersion` | integer; ordered migration steps on load | `1` |
| `global.gear` | `{ [characterGUID] = { setID = integer, name = string } }`, the chosen fishing set (QOL-R40) | `{}` |
| `global.poleSwap` | *From 1.7:* `{ [characterGUID] = { mainHand = { itemID, link }?, offHand = { itemID, link }? } }`, the weapons a pole from the bags replaced (QOL-R48, QOL-R49); no migration, as AceDB fills it | `{}` |
| `global.lease` | `{ { name = string, orig = string, set = string, origName = string? } }`, CVars currently leased, `set` as read back (QOL-R63); `origName` on the output device's entry only, the player's device by name (from 1.2.0, QOL-R68) | `{}` |
| `profile.input` | `"key"`, `"click"`, `"both"` | `"both"` |
| `profile.lures` | `{ mode = "off"|"best"|"one", item = itemID }` | `{ mode = "best", item = 6529 }` |
| `profile.clams` | boolean | `true` |
| `profile.audio` | `{ on = boolean, background = boolean, master, effects, music, ambience, dialog = { on = boolean, volume = number }, device = string }`: each channel whether the mix changes it (its box) and its volume in percent (its slider), 0 being Off, and the output device's name, `""` for Don't change (the channels and device from 1.2.0, QOL-R62, QOL-R68) | `{ on = true, background = false, master = { on = false, volume = 100 }, effects = { on = true, volume = 100 }, music = { on = true, volume = 0 }, ambience = { on = true, volume = 0 }, dialog = { on = true, volume = 0 }, device = "" }` |
| `profile.autoLoot` | boolean | `true` |
| `profile.indicator` | `{ shown = boolean, untilPole = boolean, point = { point, relativeTo = "UIParent", relativePoint, x, y } or nil }`; `untilPole` is Hide until a fishing pole is in hand (QOL-R72, from 1.2.0), which AceDB's default gives a profile that has none | `{ shown = true, untilPole = false, point = nil }` |

The 1.2.0 keys in `profile.audio` need no migration step: AceDB fills a key a saved profile lacks from these defaults, a channel's `on` or `volume` too, so a profile saved by 1.1 leases 1.1's mix until the player changes a row. `global.lease` entries are unchanged; the output device's entry is one like any other.

QoL writes nothing to `PagleLog` or `PagleDB`. It has no projection, so a content-fingerprint or rules change never touches it.

### Shipped tables

`addons/Pagle_QoL/data/lures.lua` (QOL-R54), `addons/Pagle_QoL/data/clams.lua` (QOL-R57) and, from 1.7, `addons/Pagle_QoL/data/poles.lua` (QOL-R48), hand-kept item IDs only, outside the content data pipeline (only QoL reads them).

## Contracts

### `Pagle` API used

| Call or event | For |
|---|---|
| `Pagle.RegisterModule(def)` | QOL-R2 |
| `M:AddSetting("fishing", …)` | [Settings](#settings) |
| `Pagle.OpenSettings("fishing")` | `settingsAction`, `/pagle qol` |
| `Pagle.IsRestricted()`, `RestrictionChanged` | QOL-R30–R33 |
| `CastStarted`, `CastEnded`, `FishingStateChanged` | QOL-R22, R25, R61 |
| `Pagle.RegisterEvent`, `Pagle.RegisterUnitEvent` | every WoW event in QOL-R13, R22, R25, R31, R61, R80 (CORE-R23) |
| `Pagle.IsAnimationsOn()` | the pinned notes' motion ([UI](#ui)) |
| `M:RegisterGuideStep(step)` and the step's `nav` (`ChoiceCard`, `BindingField`, `Note`, `Part`, `Panel`) | the Field guide's Casting and Fishing clothes steps (ONB-R21, ONB-R32, ONB-R33), only `if M.RegisterGuideStep then` (ONB-R90) |
| `M:ShowMarginNote(note)` | `qol.lure`, the first time the next-action button shows Lure (ONB-R52), only `if M.ShowMarginNote then` |
| `def.guideBlurb` | QoL's line on the guide's What's in the box step (ONB-R91) |

### Exposed

Nothing: QoL fires no events, raises no moments, writes no records, pays no Coins and registers no Curio Shop goods.

### Bindings (`Bindings.xml`)

| Binding | Shown as | Body |
|---|---|---|
| `PAGLE_FISHING_KEY` | Pagle: Fishing key | nothing (QOL-R10); QoL arms it with overrides |
| `PAGLE_SWAP_GEAR` | Pagle: Swap gear | QOL-R46 |

## UI

The look is the QoL and Field report art kit (`PagleArtField`, post-1.0 art): its Field atlas is Core's `Pagle/media/field/Field.blp`, its fonts Core's `Pagle/media/fonts/` (QoL needs Core, so both are always there; QoL keeps a copy of the atlas's table in `data/FieldArt.lua`). Every frame is QoL's own, made the first time it shows, so the texture and fonts load only then.

- **Next-action button** (QOL-R70–R74): one plain frame, the 52 px brass bezel with the icon round inside it and a gloss over it; the key cap, 18 px high and as wide as its key with 4 px either side (at least 18), over the bezel's top left; the label, in the Angler's hand on a slip of paper as wide as the word with 10 px either side, its top 6 px under the bezel. *Nothing* greys the bezel with the icon. Its tooltip is a dark lacquer box with a gilt hairline and the line in gilt Marcellus, 12 px to the bezel's right.
- **Nudges** (QOL-R75–R78): the kit's paper strip, 40 px high, three-sliced to the line: 30 px of paper either side, its pieces 8 px apart, each set 8 px past the right end of the one before as it draws (so a strip drawn smaller, as the Field guide's sample, keeps its gaps); words in Caveat at 24, a key on a brass cap as wide as the key with 6 px either side (at least 26), a binding's name in red IM Fell English at 19, near the hand's height so it sits on the line.
- **Conflict note** (QOL-R81), followed after a choice by the **Reload now note** (QOL-R83): a 440 × 200 note pinned with wax at the top centre (where the game's popups show, 135 px down), above the world: the question in IM Fell English, and both choices on one line, the first on the kit's leather button, the second on its outlined one. A row too wide for the note (a long addon title) shrinks to fit it. Each is a named frame in `UISpecialFrames`, so Esc hides it and chooses nothing. Its motion and sounds are the kit's (`MOTION.md`, `SOUND.md`): as a note appears it plays `IG_MAINMENU_OPEN` (sound kit 850) and fades in over 0.2 s (ease-out), and its wax is pressed on as it lands, from 1.8 times its size to 0.95 by 0.29 s, settling at its own by 0.38 s (cubic-bezier(.3, 1.5, .5, 1)), fading in with it. A click on a choice plays `IG_MAINMENU_OPTION` (852), then `IG_MAINMENU_CLOSE` (851) as the note fades out over 0.15 s (ease-in) and hides; the choice runs at the click, and the fading note takes no second one. Esc hides it at once, with the close sound. With Core's Animations setting off (`Pagle.IsAnimationsOn()`) a note shows and goes at once; the sounds still play, as UI foley on the SFX channel (`PlaySound(id, "SFX")`). The notes move on Core's one motion driver (`Pagle.Animate`, announcements.md › Contracts), which settles a note hidden with the whole UI as it fades: a closing note still ends closed.
- **Tour stops** (CORE-R65): `qol.settings` (the Fishing page), `qol.nudge` (a sample swap-back Nudge, key G) and `qol.notes` (samples of both notes, whose choices only close them).
- **Fishing settings page:** QoL's rows on Core's Fishing page. Look reference: `prototypes/settings-tree/` (variant B); the row layout belongs to `docs/spec/settings.md`.

## Settings

All on the **Fishing** page (`M:AddSetting("fishing", …)`), in this order. Each Section is a `header` row, so QoL's first row is a header and Core leaves out the "QoL" Module header (CORE-R42).

| Section | Option | Values | Default |
|---|---|---|---|
| Casting | Cast with | Fishing key / Double right-click / Both | Both |
| | ↳ Fishing key | keybinding `PAGLE_FISHING_KEY`; greyed out under Double right-click | unbound |
| Gear | Fishing set | None (a pole from your bags) / the character's own sets, except *Pagle Previous* | None |
| | ↳ Save what I'm wearing as my fishing set | button (QOL-R41) | |
| | ↳ Swap gear | keybinding `PAGLE_SWAP_GEAR` (from 1.7 never greyed out: it works with no set too, QOL-R48) | unbound |
| Lures and clams | Lures | Off / Best I have / Only this one | Best I have |
| | ↳ Lure | the lure table's items; live only for Only this one | Shiny Bauble |
| | Open clams between Casts | on/off | on |
| While you fish | Fishing audio mix | on/off | on |
| | ↳ Master volume | box and slider (as Game › Sound's), 10% to 100% in steps of 5, the slider greyed while unticked; *from 1.2.4,* shown and live while the audio mix is off (SET-R31) | unticked, 100% |
| | ↳ Effects | box and slider, 0% (shown as Off) to 100% in steps of 5, the slider greyed while unticked; *from 1.2.4,* shown and live while the audio mix is off (SET-R31) | ticked, 100% |
| | ↳ Music | as Effects | ticked, 0% (Off) |
| | ↳ Ambience | as Effects | ticked, 0% (Off) |
| | ↳ Dialog | as Effects | ticked, 0% (Off) |
| | ↳ Output device | Don't change / each device the client lists when the menu opens, a chosen one that isn't there listed as "{device} (not found)" (QOL-R68); greyed out while the audio mix is off | Don't change |
| | ↳ Keep sound in the background | on/off; greyed out while the audio mix is off | off |
| | Auto-loot while fishing | on/off | on |
| | Show the next-action button | on/off | on |
| | ↳ Hide until a fishing pole is in hand | on/off; greyed out while Show the next-action button is off | off |
| | ↳ Button position | Reset; greyed out while Show the next-action button is off | |

Tooltips:
- **Cast with:** "Also on the compartment menu and /pagle qol input."
- **Fishing key:** "Each press does the next single thing: cast, reel, or a lure, gear or clam when needed."
- **Fishing set:** "The Fishing key puts it on when no pole is in hand. With None, it takes the best pole from your bags, and Swap gear puts your weapons back. Double-click skips this."
- **Swap gear:** "Swaps between your fishing set and what you wore before (saved as Pagle Previous). With no set, between your best pole and your weapons."
- **Lures:** "A press before a cast applies a lure when none is on."
- **Open clams between Casts:** "One clam per press, never during a cast."
- **Fishing audio mix:** "While you fish: each channel and the output device as set below. Put back afterwards." (1.1: "While you fish: effects at full; music, ambience and dialog muted; master untouched. Put back afterwards.")
- **Master volume:** "Ticked, sets the master volume while you fish. It has no Off and goes no lower than 10%, so you still hear the splash."
- **Effects, Music, Ambience, Dialog:** "Ticked, sets this channel while you fish: at 0% it's off. Unticked, leaves it as it is."
- **Output device:** "Plays the game's sound here while you fish. The sound drops out for a moment as it switches, at the start and at the end."
- **Keep sound in the background:** "While you fish, the sound keeps playing when the game is in the background." (from 1.2.0; the label was "Keep sound when the game is in the background" in 1.1, too wide for its row)
- **Auto-loot while fishing:** "Only while you fish. Skipped if you already have auto-loot on."
- **Show the next-action button:** "Shows what your next press will do. Shift-drag to move."
- **Hide until a fishing pole is in hand:** "Keeps the button hidden while you're out of your fishing gear. It shows once a pole is in hand or you're fishing."

The Fishing set dropdown reads and writes the current character's choice (`global.gear[guid]`); every other row is account-wide. The page's Defaults button restores the defaults above and leaves the fishing set, the key bindings and the button's position alone.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Fishing stretch idle end | 60 s after the last `CastEnded` | QOL-R61 |
| Double-click window | 0.4 s (probe B3) | QOL-R13 |
| Click hold limit | 0.3 s from mouse-down to mouse-up | QOL-R13 |
| Re-evaluation tick while armed | 0.5 s | QOL-R25 |
| Soft-interact lease | `SoftTargetInteract` 3, `SoftTargetInteractRange` at least 15, `SoftTargetInteractRangeIsHard` 0 (probe B1) | QOL-R62 |
| Audio mix defaults | master unticked (at 100%); effects ticked at 100% (SFX on at 1.0); music, ambience, dialog ticked at 0% (off); device Don't change: 1.1's mix | QOL-R62, QOL-R68 |
| Audio mix sliders | 0% to 100% in steps of 5 (Game › Sound's step); master from 10% | QOL-R62 |
| Nudge display | 3 s, then a 0.5 s fade; 4 px below `UIErrorsFrame`; a 40 px strip, 30 px of paper either side of the line | QOL-R75 |
| Result wait (gear swap, lure) | 2 s | QOL-R29 |
| Reel wait (the reel didn't take) | 0.5 s after a reel press | QOL-R35 |
| Next-action button size | a 36 px icon in a 52 px bezel | QOL-R70 |
| Next-action button default position | bottom centre, 230 px up | QOL-R73 |
| Lure table | 6 Classic lures | QOL-R54 |
| Clam table | 5523, 5524, 7973 | QOL-R57 |
| Conflict list (folder names) | `Angleur` and `FishingBuddy`. Both Forever ports (Fishing Buddy Forever Fix 1.0.2, Fishing Buddy (Forever) (Crusade) 1.0.7) install into `FishingBuddy` too, as their published zips show; each name's source is in `logic/Conflict.lua` | QOL-R80 |
| Default chosen lure | Shiny Bauble (6529) | QOL-R50 |
| Fishing spell used for its name and icon | 7620 | QOL-R24, R71 |

## Edge cases

- **QOL-R90 Module disabled, then enabled again.** A disabled QoL runs no code (CORE-R17): its bindings vanish from Key Bindings, its rows from Fishing (the page disappears), and nothing is leased. Re-enabled, it restores any lease left over (QOL-R64) and arms as usual. It has no history to catch up and raises no Write-up. A lease left over while QoL is disabled stays in effect until QoL next loads. The player's own bindings to `PAGLE_FISHING_KEY` and `PAGLE_SWAP_GEAR` are the game's to keep; if the client dropped them while QoL was off, the keybinding rows show them unbound and the player binds them again.
- **QOL-R91 Projection rebuild.** QoL has no projection (QOL-R3); nothing happens.
- **QOL-R92 First build over existing history.** Nothing: QoL derives nothing from the Catch log and has no Write-up.
- **QOL-R93 In combat.** QOL-R30–R34: disarmed before lockdown, CVars restored, the stretch ended, no gear swap, re-armed when restriction ends. The next-action button shows *nothing*; Nudges still show.
- **QOL-R94 Crash mid-Session.** QOL-R67. Chosen settings are whatever was last saved; a fishing set or *Pagle Previous* saved in the game since then is kept by the game. Recording is Core's (LOG-R85).
- **QOL-R95 Daily or weekly reset.** No rule in this file depends on it.
- **QOL-R96 Uncharted or unconfirmed Catch.** QoL doesn't read Catches. A clam or lure that isn't in QoL's own tables is never used by the key.
- **QOL-R97 Standing down.** While the conflict note is unanswered or a choice waits for `/reload`, QoL changes no binding or CVar (QOL-R82); the other addon works as if QoL weren't there.
- **QOL-R98 Bindings changed while armed.** `UPDATE_BINDINGS` re-arms on the new keys (QOL-R25); overrides on a key no longer bound to the Fishing key are cleared first.
- **QOL-R99 Gear with no fishing set** (from 1.7). In combat QoL is disarmed, so the key and Swap gear do nothing and the pole stays (QOL-R34). A remembered weapon sold, banked or destroyed is dropped at the next swap back (QOL-R49). A swap back whose main hand went on while its off hand didn't leaves the off hand for the player: with no pole in hand the next Swap gear puts the pole on again, remembering the hands as they are then.
