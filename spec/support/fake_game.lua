-- The fake client's game side for QoL: key bindings and override bindings, keys held down, the player's casts and
-- channel, the main hand and its lure, the bags, CVars, the mount, equipment sets, and the frame loop.
-- spec/support/addon.lua adds these stubs to every load, so they answer as a character standing idle and unmounted
-- with no key bound, nothing held, nothing in hand, nothing in the bags and no equipment set.
--
--   loaded.client.boundKeys.PAGLE_FISHING_KEY = { "F", "SHIFT-F" }  -- GetBindingKey's keys
--   loaded.client.overrideAction("F")                               -- "SPELL Fishing", as GetBindingAction reads it
--   loaded.client.bindingNames.ASSISTTARGET = "Assist Target"       -- GetBindingName("ASSISTTARGET")
--   loaded.client.keysDown.F = true                                 -- IsKeyDown("F")
--   loaded.client.channel = "Fishing"                               -- UnitChannelInfo("player")
--   loaded.client.update(0.5)                                       -- one frame, 0.5 s after the last
--   loaded.client.cvars.SoftTargetInteract = "1"                    -- GetCVar's value; SetCVar changes it
--   loaded.client.mounted = true                                    -- IsMounted()
--   loaded.client.bags[6529] = 5                                    -- C_Item.GetItemCount(6529)
--   loaded.client.mainHandEnchant = 263                             -- GetWeaponEnchantInfo(): a lure on
--   loaded.client.equipmentSets[3] = { name = "Fishing", items = { [16] = 6256 } } -- a C_EquipmentSet set
--   loaded.client.wearSet(3)                                        -- the set's items go on, as a swap ends
--   loaded.client.click("RightButton", 0.1)                         -- a mouse click, held 0.1 s
--   loaded.client.mouseFoci = { someButton }                        -- GetMouseFoci(): the mouse is over a UI frame
--   loaded.client.nextFrame(0.016)                                   -- the clock moves on, then one frame runs
--   loaded.client.keysDown.SHIFT = true                              -- IsShiftKeyDown()
--   loaded.client.loadItem(6529, "Shiny Bauble")                     -- an uncached item's data arrives
--   loaded.client.pressKey("F")                                      -- F's click override clicks its button
--   loaded.client.itemUses                                           -- { "use 6529 on 16" }: what the presses used
--
-- Each override call fires UPDATE_BINDINGS at once, through client.fireGameEvent, as the client fires it after a
-- binding change; under FakePagle, fake.load points that at fake.fireGameEvent. Each one raises an error while the
-- load's InCombatLockdown() is true (set loaded.env.InCombatLockdown), as the client blocks it in lockdown.

---@class FakeClient
---@field boundKeys table<string, string[]> The keys bound to each binding command, as `GetBindingKey` returns them.
---@field keysDown table<string, true> The keys held down, by name without modifiers, as `IsKeyDown` takes them;
--- `SHIFT` is what `IsShiftKeyDown()` reads.
---@field channel string? The spell the player is channeling, by name; `UnitChannelInfo("player")` returns it.
---@field casting string? The spell the player is casting with a cast time; `UnitCastingInfo("player")` returns it.
---@field mainHand integer? The item ID in the main hand (slot 16).
---@field items table<integer, integer[]> `{ classID, subclassID }` per item ID, for `C_Item.GetItemInfoInstant`.
---@field itemQualities table<integer, integer> Each loaded item's quality (Enum.ItemQuality), as
--- `C_Item.GetItemQualityByID` reads it; nil for one not loaded yet.
---@field itemLoads table<integer, function[]> The `Item:CreateFromItemID(id):ContinueOnItemLoad` callbacks waiting
--- for each item not in `itemNames`, in order, until `loadItem` runs them.
---@field bindingCalls string[] Each override call, in order: "set <key> <action>" or "clear".
---@field overrideAction fun(key: string): string? The priority override on `key`, as `GetBindingAction` reads it.
---@field fireGameEvent fun(event: string, ...) Fires a WoW event the game raises on its own. `client.fire` unless a
--- spec or FakePagle replaces it.
---@field update fun(elapsed: number) Runs one frame: each frame's OnUpdate script, given `elapsed` seconds.
---@field cvars table<string, string> Each CVar's value as `GetCVar` reads it. `SetCVar` stores `tostring(value)`
--- and fires `CVAR_UPDATE(name, value)` through `fireGameEvent` before it returns; a CVar not listed is one the
--- client doesn't know (`GetCVar` returns nil).
---@field cvarCalls string[] Each `SetCVar` call, in order: "set <name> <value>".
---@field mounted boolean? Whether the player is mounted, as `IsMounted()` reads it.
---@field uiErrors { text: string, r: number?, g: number?, b: number? }[] Each `UIErrorsFrame:AddMessage` call, in
--- order: the game's error text at the top of the screen.
---@field bags table<integer, integer> How many of each item ID are in the bags, as `C_Item.GetItemCount` reads it.
---@field unusable table<integer, true> Item IDs `C_Item.IsUsableItem` says can't be used; every other can. The
--- clam table's items are, as on Forever (#147).
---@field targetsItem table<integer, true> Item IDs whose use targets an item, the lure table's: their use alone leaves
--- the cursor targeting (`SpellIsTargeting()`), until the secure button's `target-slot` names the slot (#147).
---@field targeting integer? The item whose use is waiting for a target, as the glowing hand; nil when none is.
---@field itemUses string[] Each item use PagleQoLActionButton's press made, in order: "use <itemID>", or
--- "use <itemID> on <slot>" for one applied to an equipped slot.
---@field pressKey fun(key: string) A press of `key`: a shown keyboard-enabled frame takes it first (its OnKeyDown,
--- the frame made last on top), and then no binding sees it unless that OnKeyDown let it through
--- (SetPropagateKeyboardInput(true)). Otherwise it reaches its override: for a click override
--- ("CLICK name:…"), the named button's click, with the secure item action of FrameXML's SecureActionButtonTemplate
--- for a secure one. No other override is faked.
---@field savedBindings integer[] Each SaveBindings call's binding set, in order. SetBinding changes `boundKeys`.
---@field mainHandEnchant integer? The enchant ID on the main hand (a lure), as `GetWeaponEnchantInfo()` reads it.
---@field itemSpells table<integer, { [1]: string, [2]: integer }> The spell each item's use casts, by item ID, as
--- `C_Item.GetItemSpell` returns it: name, spell ID.
---@field itemNames table<integer, string> Each item's name, by item ID, as `C_Item.GetItemNameByID` and
--- `C_Item.GetItemInfo` return it once the item is cached; an item not listed isn't cached. Default: the lure and
--- clam tables' items only.
---@field itemRequests integer[] Each `C_Item.RequestLoadItemDataByID` call's item ID, in order. The client loads
--- nothing on its own: a spec sets `itemNames` and fires GET_ITEM_INFO_RECEIVED itself, or calls `loadItem`.
---@field itemIcons table<integer, integer> Each item's icon file ID, by item ID, as `GetInventoryItemTexture` reads
--- it for a worn item and `C_Item.GetItemIconByID` for any.
---@field loadItem fun(itemID: integer, name: string) An item's data arrives: its name is cached as `name`, and each
--- `Item:CreateFromItemID(itemID):ContinueOnItemLoad` callback waiting for it runs.
---@field worn table<integer, integer> The item ID worn in each slot but the main hand, by slot; the main hand (16)
--- is `mainHand`.
---@field equipmentSets table<integer, FakeEquipmentSet> The character's equipment sets by set ID, as C_EquipmentSet
--- reads them. Specs add sets; CreateEquipmentSet adds one at the lowest free ID, from 0.
---@field equipmentSetCalls string[] Each C_EquipmentSet call that changes something, in order: "clear ignored",
--- "create <name> <icon>", "save <setID>" or "use <setID>".
---@field wearSet fun(setID: integer) Puts the set's items on (slot 16 into `mainHand`, the rest into `worn`), as
--- the end of a swap does. It fires no event.
---@field bindingNames table<string, string> Each binding command's name in Key Bindings, as `GetBindingName` returns
--- it; a command not listed reads as itself. Default: Assist Target and Move Forward.
---@field bindingTexts table<string, string> Short key texts `GetBindingText(key, true)` returns, by key; a key not
--- listed reads as itself with SHIFT-, CTRL- and ALT- shortened to s-, c- and a-.
---@field mouseFoci table[] The frames under the mouse, topmost first, as `GetMouseFoci()` returns them. Default
--- `{ WorldFrame }`: the mouse is over the game world.
---@field click fun(button: string, hold: number?) A mouse click: `GLOBAL_MOUSE_DOWN(button)`, the clock moving on
--- `hold` seconds (default 0.1), then `GLOBAL_MOUSE_UP(button)`, each through `client.fireGameEvent`, as the
--- client fires them for any click, on a frame or on the world.
---@field nextFrame fun(seconds: number?) The next frame: the clock moves on `seconds` (default 1/60), running the
--- timers due, then each frame's OnUpdate runs with that elapsed time, as GetTime() holds one value per frame.

--- One equipment set: its name, icon, items by slot, and how many of them are missing (in the bank, say).
---@class FakeEquipmentSet
---@field name string
---@field icon integer?
---@field items table<integer, integer> item IDs by slot
---@field lost integer? `GetEquipmentSetInfo`'s numLost. Default 0.

-- The spells named Fishing: the generated catalogue's fishing-spell list (LOG-R2, data/forever/lists.toml), since
-- every rank of Fishing has this name (probe B2).
local FISHING_SPELLS = {}
do
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile("addons/Pagle/data/Catalogue.lua"))
	local ns = {}
	chunk("Pagle", ns)
	for _, spellID in ipairs(ns.catalogue.fishingSpells) do
		FISHING_SPELLS[spellID] = true
	end
end

---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	client.boundKeys, client.keysDown, client.bindingCalls = {}, {}, {}
	-- The soft-interact CVars as probe B11 read them on the dev's client (build 70338), all at or above what QoL
	-- leases (QOL-R62), so a stretch leases nothing until a spec sets the player's own values. ActionButtonUseKeyDown
	-- too: probe B11 read it as 1.
	client.cvars = {
		SoftTargetInteract = "3",
		SoftTargetInteractRange = "60",
		SoftTargetInteractRangeIsHard = "0",
		ActionButtonUseKeyDown = "1",
	}
	client.cvarCalls = {}
	-- A Fishing Pole (6256, as probe B1 read it) and a Worn Shortsword (25).
	client.items = { [6256] = { 2, 20 }, [25] = { 2, 7 } }
	-- On Forever `C_Item.IsUsableItem` is false for a clam in the bags: the dev's `/dump` read 5523 so (build 70338,
	-- #147). The other two clams are taken to be the same.
	client.bags, client.unusable = {}, { [5523] = true, [5524] = true, [7973] = true }
	-- The lure table's items: using one alone starts targeting on Forever (build 70338, #147).
	client.targetsItem = { [6529] = true, [6530] = true, [6811] = true, [6532] = true, [7307] = true, [6533] = true }
	client.itemUses = {}
	-- Shiny Bauble's use casts 8087 (probe B4); the other lures' spells are a spec's to add.
	client.itemSpells = { [6529] = { "Shiny Bauble", 8087 } }
	-- The lure table's and the clam table's items by their enUS names, all cached.
	client.itemNames = {
		[6529] = "Shiny Bauble",
		[6530] = "Nightcrawlers",
		[6811] = "Aquadynamic Fish Lens",
		[6532] = "Bright Baubles",
		[7307] = "Flesh Eating Worm",
		[6533] = "Aquadynamic Fish Attractor",
		[5523] = "Small Barnacled Clam",
		[5524] = "Thick-shelled Clam",
		[7973] = "Big-mouth Clam",
	}
	client.itemQualities = {}
	client.itemRequests = {}
	client.itemLoads = {}
	client.fireGameEvent = client.fire

	-- Override calls are protected: in combat lockdown the client blocks them (ADDON_ACTION_BLOCKED). Here they
	-- raise, so a spec fails on any override call made under the load's InCombatLockdown (QOL-R31, CORE-R32).
	local function unlessLockedDown(call)
		if stubs.InCombatLockdown() then
			error(("FakeClient: %s blocked in combat lockdown"):format(call), 3)
		end
	end

	local overrides = {} -- owner -> key -> action, priority overrides only
	local function setOverride(owner, isPriority, key, action)
		unlessLockedDown("SetOverrideBinding")
		assert(isPriority == true, "FakeClient: only priority override bindings are faked")
		overrides[owner] = overrides[owner] or {}
		overrides[owner][key] = action
		client.bindingCalls[#client.bindingCalls + 1] = ("set %s %s"):format(key, tostring(action))
		client.fireGameEvent("UPDATE_BINDINGS")
	end

	function client.overrideAction(key)
		for _, keys in pairs(overrides) do
			if keys[key] then
				return keys[key]
			end
		end
		return nil
	end

	function client.update(elapsed)
		for _, frame in ipairs({ unpack(client.frames) }) do
			local onUpdate = frame.scripts.OnUpdate
			if onUpdate then
				onUpdate(frame, elapsed)
			end
		end
	end

	-- The mouse, for QoL's double-click (QOL-R13). GLOBAL_MOUSE_DOWN and _UP carry the button's name ("RightButton").
	client.mouseFoci = { stubs.WorldFrame }
	function client.click(button, hold)
		client.fireGameEvent("GLOBAL_MOUSE_DOWN", button)
		client.advance(hold or 0.1)
		client.fireGameEvent("GLOBAL_MOUSE_UP", button)
	end
	function client.nextFrame(seconds)
		seconds = seconds or (1 / 60)
		client.advance(seconds)
		client.update(seconds)
	end
	stubs.GetMouseFoci = function()
		return { unpack(client.mouseFoci) }
	end

	stubs.GetBindingKey = function(command)
		return unpack(client.boundKeys[command] or {})
	end
	-- The player's own bindings (SET-R20): SetBinding(key, command) takes `key` from whatever command had it and, with
	-- a command, adds it as that command's last key, as GetBindingKey then lists it; it fires UPDATE_BINDINGS, and is
	-- blocked in lockdown (warcraft.wiki.gg API SetBinding: "nocombat"). SaveBindings(which) records `which` in
	-- client.savedBindings; GetCurrentBindingSet() is 1, the account set.
	client.savedBindings = {}
	stubs.SetBinding = function(key, command)
		unlessLockedDown("SetBinding")
		for _, keys in pairs(client.boundKeys) do
			for i = #keys, 1, -1 do
				if keys[i] == key then
					table.remove(keys, i)
				end
			end
		end
		if command then
			client.boundKeys[command] = client.boundKeys[command] or {}
			table.insert(client.boundKeys[command], key)
		end
		client.fireGameEvent("UPDATE_BINDINGS")
		return true
	end
	stubs.SaveBindings = function(which)
		client.savedBindings[#client.savedBindings + 1] = which
	end
	stubs.GetCurrentBindingSet = function()
		return 1
	end
	-- What a key does (ONB-R42, ONB-R43): GetBindingAction(key) is the player's binding command on `key`, or "" with
	-- none; with `checkOverride` a priority override on it comes first (warcraft.wiki.gg, API GetBindingAction).
	-- GetBindingName(command) is its name in Key Bindings: client.bindingNames', else the command itself, as the client
	-- returns a command with no BINDING_NAME_ global (FrameXML, Blizzard_SharedXML/BindingUtil.lua).
	client.bindingNames = { ASSISTTARGET = "Assist Target", MOVEFORWARD = "Move Forward" }
	stubs.GetBindingAction = function(key, checkOverride)
		if checkOverride and client.overrideAction(key) then
			return client.overrideAction(key)
		end
		for command, keys in pairs(client.boundKeys) do
			for _, bound in ipairs(keys) do
				if bound == key then
					return command
				end
			end
		end
		return ""
	end
	stubs.GetBindingName = function(command)
		return client.bindingNames[command] or command
	end
	-- FrameXML's binding helpers, as Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
	-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/BindingUtil.lua defines them, for the mouse buttons and
	-- modifiers Pagle's specs press.
	local MOUSE_BUTTONS = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }
	for i = 4, 31 do
		MOUSE_BUTTONS["Button" .. i] = "BUTTON" .. i
	end
	local META_KEYS = { LALT = 1, RALT = 2, LCTRL = 3, RCTRL = 4, LSHIFT = 5, RSHIFT = 6, LMETA = 7, RMETA = 8 }
	for i, key in ipairs({ "ALT", "CTRL", "SHIFT", "META" }) do
		META_KEYS[key] = 8 + i
	end
	stubs.GetConvertedKeyOrButton = function(keyOrButton)
		return MOUSE_BUTTONS[keyOrButton] or keyOrButton
	end
	stubs.IsKeyPressIgnoredForBinding = function(key)
		return META_KEYS[key] ~= nil or key == "UNKNOWN" or key == "BUTTON1" or key == "BUTTON2"
	end
	stubs.CreateKeyChordStringUsingMetaKeyState = function(key)
		local chord = {}
		for _, meta in ipairs({ "ALT", "CTRL", "SHIFT", "META" }) do
			if client.keysDown[meta] then
				chord[#chord + 1] = meta
			end
		end
		if not META_KEYS[key] then
			chord[#chord + 1] = key
		end
		return table.concat(chord, "-")
	end
	stubs.SetOverrideBinding = function(owner, isPriority, key, command)
		setOverride(owner, isPriority, key, command)
	end
	stubs.SetOverrideBindingSpell = function(owner, isPriority, key, spell)
		setOverride(owner, isPriority, key, "SPELL " .. spell)
	end
	-- As GetBindingAction reads a click binding (probe B4): "CLICK PagleQoLProbeActionButton:LeftButton".
	stubs.SetOverrideBindingClick = function(owner, isPriority, key, buttonName, mouseButton)
		setOverride(owner, isPriority, key, ("CLICK %s:%s"):format(buttonName, mouseButton or "LeftButton"))
	end
	stubs.ClearOverrideBindings = function(owner)
		unlessLockedDown("ClearOverrideBindings")
		overrides[owner] = nil
		client.bindingCalls[#client.bindingCalls + 1] = "clear"
		client.fireGameEvent("UPDATE_BINDINGS")
	end
	stubs.IsKeyDown = function(key)
		return client.keysDown[key] == true
	end
	stubs.IsShiftKeyDown = function()
		return client.keysDown.SHIFT == true
	end
	stubs.UnitChannelInfo = function(unit)
		if unit == "player" then
			return client.channel
		end
	end
	stubs.UnitCastingInfo = function(unit)
		if unit == "player" then
			return client.casting
		end
	end
	stubs.GetInventoryItemID = function(unit, slot)
		if unit == "player" and slot == 16 then
			return client.mainHand
		end
	end
	stubs.C_Item = stubs.C_Item or {}
	-- itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID; nil for an item it doesn't know.
	stubs.C_Item.GetItemInfoInstant = function(itemID)
		local item = client.items[itemID]
		if item then
			return itemID, "", "", "", 0, item[1], item[2]
		end
	end
	stubs.C_Item.GetItemCount = function(itemID)
		return client.bags[itemID] or 0
	end
	-- usable, noMana
	stubs.C_Item.IsUsableItem = function(itemID)
		return not client.unusable[itemID], false
	end
	stubs.C_Item.GetItemSpell = function(itemID)
		local spell = client.itemSpells[itemID]
		if spell then
			return spell[1], spell[2]
		end
	end
	-- The item's name once the client has it cached; nil for one it doesn't know (the Ledger falls back, LED-R97).
	stubs.C_Item.GetItemNameByID = function(itemID)
		return client.itemNames[itemID]
	end
	stubs.C_Item.RequestLoadItemDataByID = function(itemID)
		client.itemRequests[#client.itemRequests + 1] = itemID
	end
	-- The item's name first, as GetItemInfo returns it once the client has the item cached (the Field report's
	-- comments, REP-R30); nothing for one it doesn't know.
	stubs.C_Item.GetItemInfo = function(itemID)
		return client.itemNames[itemID]
	end
	-- An item's icon by item ID, from client.itemIcons, whether or not its name is cached (HNT-R55, QOL-R71).
	stubs.C_Item.GetItemIconByID = function(itemID)
		return client.itemIcons[itemID]
	end
	-- FrameXML's Item (Blizzard_ObjectAPI/Mainline/Item.lua), as far as waiting for an item's data: ContinueOnItemLoad
	-- runs its callback at once if the item's name is cached, else when client.loadItem loads it; the callbacks
	-- waiting meanwhile are in client.itemLoads (HNT-R54).
	-- The item's quality; nil for one not in client.itemQualities, not loaded yet (Stats' Catches by quality, STA-R33).
	stubs.C_Item.GetItemQualityByID = function(itemID)
		return client.itemQualities[itemID]
	end
	stubs.Item = {
		CreateFromItemID = function(_, itemID)
			return {
				ContinueOnItemLoad = function(_, callback)
					if client.itemNames[itemID] then
						callback()
					else
						client.itemLoads[itemID] = client.itemLoads[itemID] or {}
						table.insert(client.itemLoads[itemID], callback)
					end
				end,
			}
		end,
	}
	function client.loadItem(itemID, name)
		client.itemNames[itemID] = name
		local callbacks = client.itemLoads[itemID] or {}
		client.itemLoads[itemID] = nil
		for _, callback in ipairs(callbacks) do
			callback()
		end
	end
	-- The enUS client's quality names and colours (Stats' qualities, STA-R59; a quality class's icon tint, HNT-R55):
	-- GlobalStrings' ITEM_QUALITY<n>_DESC, and ITEM_QUALITY_COLORS as Blizzard_Colors' ColorManager fills it, with no
	-- colour overrides.
	for quality, name in pairs({
		[0] = "Poor",
		"Common",
		"Uncommon",
		"Rare",
		"Epic",
		"Legendary",
		"Artifact",
		"Heirloom",
	}) do
		stubs["ITEM_QUALITY" .. quality .. "_DESC"] = name
	end
	stubs.ITEM_QUALITY_COLORS = {}
	for quality, rgb in pairs({
		[0] = { 0.62, 0.62, 0.62, "9d9d9d" },
		{ 1, 1, 1, "ffffff" },
		{ 0.12, 1, 0, "1eff00" },
		{ 0, 0.44, 0.87, "0070dd" },
		{ 0.64, 0.21, 0.93, "a335ee" },
		{ 1, 0.5, 0, "ff8000" },
		{ 0.9, 0.8, 0.5, "e6cc80" },
		{ 0, 0.8, 1, "00ccff" },
	}) do
		stubs.ITEM_QUALITY_COLORS[quality] = { r = rgb[1], g = rgb[2], b = rgb[3], hex = "|cff" .. rgb[4] }
	end
	-- hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, then the off hand's and the ranged
	-- slot's, as probe B4 read them: true, 600000, 0, 263, false, nil, … with Shiny Bauble's lure on.
	stubs.GetWeaponEnchantInfo = function()
		local lure = client.mainHandEnchant
		if lure then
			return true, 600000, 0, lure, false, nil, nil, nil, false, nil, nil, nil
		end
		return false, nil, nil, nil, false, nil, nil, nil, false, nil, nil, nil
	end
	stubs.GetCVar = function(name)
		return client.cvars[name]
	end
	-- Each call fires CVAR_UPDATE(name, value) at once, through client.fireGameEvent, before SetCVar returns.
	stubs.SetCVar = function(name, value)
		client.cvarCalls[#client.cvarCalls + 1] = ("set %s %s"):format(name, tostring(value))
		client.cvars[name] = tostring(value)
		client.fireGameEvent("CVAR_UPDATE", name, tostring(value))
	end
	stubs.IsMounted = function()
		return client.mounted == true
	end
	-- The game's error text at the top of the screen (FrameXML UIErrorsFrame, a ScrollingMessageFrame; the client's
	-- widget, spec/support/client.lua): each message it's given goes into client.uiErrors.
	client.uiErrors = {}
	function stubs.UIErrorsFrame.AddMessage(_, text, r, g, b)
		client.uiErrors[#client.uiErrors + 1] = { text = text, r = r, g = g, b = b }
	end
	stubs.C_Spell = stubs.C_Spell or {}
	stubs.C_Spell.GetSpellName = function(spellID)
		return FISHING_SPELLS[spellID] and "Fishing" or nil
	end

	-- Equipment sets (C_EquipmentSet), the icons a new set takes, and short key texts. The character has no set.
	-- The Fishing Pole's and the Worn Shortsword's icons; the Fishing spell's is 136245.
	client.itemIcons = { [6256] = 132932, [25] = 135274 }
	client.worn, client.equipmentSets, client.equipmentSetCalls, client.bindingTexts = {}, {}, {}, {}

	-- The item worn in a slot.
	local function wornIn(slot)
		if slot == 16 then
			return client.mainHand
		end
		return client.worn[slot]
	end

	-- The gear worn now, by slot, as a new or saved set holds it.
	local function wornNow()
		local items = {}
		for slot, itemID in pairs(client.worn) do
			items[slot] = itemID
		end
		items[16] = client.mainHand
		return items
	end

	local function record(call)
		client.equipmentSetCalls[#client.equipmentSetCalls + 1] = call
	end

	-- A secure button's click, as SECURE_ACTIONS.item and OnActionButtonClick run it (Gethe/wow-ui-source branch
	-- forever at 943764493e6b16d63ded3ab304150d1f05e58b57, "1.60.1 (70338)":
	-- Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua, lines 418–439 and 759–785): the button's item is used;
	-- then, if that use is targeting an item, `target-slot` with no `target-bag` applies it to that equipped slot
	-- (UseInventoryItem). Only `type = "item"` with `item = "item:<id>"`, used from the bags, is faked. An applied
	-- lure's use casts its spell at once (UNIT_SPELLCAST_START, _SUCCEEDED, _STOP); its enchant is a spec's to put on,
	-- as the game shows it a moment later.
	local function secureClick(button)
		if button:GetAttribute("type") ~= "item" then
			return
		end
		local itemID = tonumber((button:GetAttribute("item") or ""):match("^item:(%d+)$"))
		if not itemID or (client.bags[itemID] or 0) == 0 then
			return
		end
		if not client.targetsItem[itemID] then
			client.itemUses[#client.itemUses + 1] = "use " .. itemID
			return
		end
		client.targeting = itemID
		local slot = tonumber(button:GetAttribute("target-slot"))
		if not slot or button:GetAttribute("target-bag") or not wornIn(slot) then
			return
		end
		client.targeting = nil
		client.itemUses[#client.itemUses + 1] = ("use %d on %d"):format(itemID, slot)
		local spell = client.itemSpells[itemID] or {}
		client.casting = spell[1]
		client.fireGameEvent("UNIT_SPELLCAST_START", "player", "Cast-Item", spell[2])
		client.casting = nil
		client.fireGameEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-Item", spell[2])
		client.fireGameEvent("UNIT_SPELLCAST_STOP", "player", "Cast-Item", spell[2])
	end

	-- Whether `widget` and every frame it hangs from are shown.
	local function visible(widget)
		while widget do
			if not widget.shown then
				return false
			end
			widget = widget.parent
		end
		return true
	end

	function client.pressKey(key)
		-- A shown keyboard-enabled frame takes the press first, the one made last on top, and keeps it from the
		-- bindings (Frame:EnableKeyboard) unless its OnKeyDown lets it through (SetPropagateKeyboardInput(true)).
		for i = #client.frames, 1, -1 do
			local frame = client.frames[i]
			if frame.keyboardEnabled and visible(frame) then
				local onKeyDown = frame.scripts.OnKeyDown
				if onKeyDown then
					onKeyDown(frame, key)
				end
				if not frame.propagatesKeys then
					return
				end
				break
			end
		end
		local action = client.overrideAction(key)
		local name = action and action:match("^CLICK ([^:]+):")
		assert(name, ("FakeClient: only a click override is pressed, not %s"):format(tostring(action)))
		local button = assert(stubs[name], "FakeClient: no button named " .. name)
		if button.template == "SecureActionButtonTemplate" then
			secureClick(button)
		else
			button:Click()
		end
	end
	stubs.SpellIsTargeting = function()
		return client.targeting ~= nil
	end

	function client.wearSet(setID)
		for slot, itemID in pairs(client.equipmentSets[setID].items) do
			if slot == 16 then
				client.mainHand = itemID
			else
				client.worn[slot] = itemID
			end
		end
	end

	-- FrameXML's limit: Gethe/wow-ui-source branch forever, Blizzard_FrameXMLBase/Constants.lua.
	stubs.MAX_EQUIPMENT_SETS_PER_PLAYER = 10
	stubs.C_EquipmentSet = {
		GetEquipmentSetID = function(name)
			for setID, set in pairs(client.equipmentSets) do
				if set.name == name then
					return setID
				end
			end
			return nil
		end,
		GetEquipmentSetIDs = function()
			local ids = {}
			for setID in pairs(client.equipmentSets) do
				ids[#ids + 1] = setID
			end
			table.sort(ids)
			return ids
		end,
		GetNumEquipmentSets = function()
			local count = 0
			for _ in pairs(client.equipmentSets) do
				count = count + 1
			end
			return count
		end,
		-- name, iconFileID, setID, isEquipped, numItems, numEquipped, numInInventory, numLost, numIgnored
		GetEquipmentSetInfo = function(setID)
			local set = client.equipmentSets[setID]
			if not set then
				return nil
			end
			local numItems, numEquipped = 0, 0
			for slot, itemID in pairs(set.items) do
				numItems = numItems + 1
				if wornIn(slot) == itemID then
					numEquipped = numEquipped + 1
				end
			end
			local lost = set.lost or 0
			return set.name,
				set.icon,
				setID,
				numEquipped == numItems,
				numItems,
				numEquipped,
				numItems - numEquipped - lost,
				lost,
				0
		end,
		GetItemIDs = function(setID)
			local items = {}
			for slot, itemID in pairs(client.equipmentSets[setID].items) do
				items[slot] = itemID
			end
			return items
		end,
		ClearIgnoredSlotsForSave = function()
			record("clear ignored")
		end,
		-- As probe B9 saw: no return value, and EQUIPMENT_SETS_CHANGED during the call. The client refuses a name in
		-- use or a set past the limit; here that raises, so a spec fails on it.
		CreateEquipmentSet = function(name, icon)
			assert(not stubs.C_EquipmentSet.GetEquipmentSetID(name), "FakeClient: a set named " .. name .. " exists")
			assert(
				stubs.C_EquipmentSet.GetNumEquipmentSets() < stubs.MAX_EQUIPMENT_SETS_PER_PLAYER,
				"FakeClient: no free set slot"
			)
			local setID = 0
			while client.equipmentSets[setID] do
				setID = setID + 1
			end
			client.equipmentSets[setID] = { name = name, icon = icon, items = wornNow() }
			record(("create %s %s"):format(name, tostring(icon)))
			client.fireGameEvent("EQUIPMENT_SETS_CHANGED")
		end,
		SaveEquipmentSet = function(setID, icon)
			local set = assert(client.equipmentSets[setID], "FakeClient: no set " .. tostring(setID))
			set.items, set.icon = wornNow(), icon or set.icon
			record("save " .. setID)
			client.fireGameEvent("EQUIPMENT_SETS_CHANGED")
		end,
		-- The swap itself ends later: a spec calls client.wearSet and fires EQUIPMENT_SWAP_FINISHED.
		UseEquipmentSet = function(setID)
			record("use " .. setID)
			return client.equipmentSets[setID] ~= nil
		end,
	}
	stubs.GetInventoryItemTexture = function(unit, slot)
		local itemID = unit == "player" and wornIn(slot)
		return itemID and client.itemIcons[itemID] or nil
	end
	stubs.C_Spell.GetSpellTexture = function(spellID)
		if FISHING_SPELLS[spellID] then
			return 136245, 136245
		end
	end
	-- The key's text in Key Bindings, or with `abbreviate` its short form, as action bars show it.
	stubs.GetBindingText = function(key, abbreviate)
		if not abbreviate then
			return key
		end
		return client.bindingTexts[key] or (key:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("ALT%-", "a-"))
	end
end
