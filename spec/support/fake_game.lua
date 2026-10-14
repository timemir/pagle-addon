-- The fake client's game side for QoL: key bindings and override bindings, keys held down, the player's casts and
-- channel, the main hand, CVars, the mount, and the frame loop. spec/support/addon.lua adds these stubs to every
-- load, so they answer as a character standing idle and unmounted with no key bound, nothing held and nothing in hand.
--
--   loaded.client.boundKeys.PAGLE_FISHING_KEY = { "F", "SHIFT-F" }  -- GetBindingKey's keys
--   loaded.client.overrideAction("F")                               -- "SPELL Fishing", as GetBindingAction reads it
--   loaded.client.keysDown.F = true                                 -- IsKeyDown("F")
--   loaded.client.channel = "Fishing"                               -- UnitChannelInfo("player")
--   loaded.client.update(0.5)                                       -- one frame, 0.5 s after the last
--   loaded.client.cvars.SoftTargetInteract = "1"                    -- GetCVar's value; SetCVar changes it
--   loaded.client.mounted = true                                    -- IsMounted()
--
-- Each override call fires UPDATE_BINDINGS at once, through client.fireGameEvent, as the client fires it after a
-- binding change; under FakePagle, fake.load points that at fake.fireGameEvent. Each one raises an error while the
-- load's InCombatLockdown() is true (set loaded.env.InCombatLockdown), as the client blocks it in lockdown.

---@class FakeClient
---@field boundKeys table<string, string[]> The keys bound to each binding command, as `GetBindingKey` returns them.
---@field keysDown table<string, true> The keys held down, by name without modifiers, as `IsKeyDown` takes them.
---@field channel string? The spell the player is channeling, by name; `UnitChannelInfo("player")` returns it.
---@field casting string? The spell the player is casting with a cast time; `UnitCastingInfo("player")` returns it.
---@field mainHand integer? The item ID in the main hand (slot 16).
---@field items table<integer, integer[]> `{ classID, subclassID }` per item ID, for `C_Item.GetItemInfoInstant`.
---@field itemNames table<integer, string> Each item's name, for `C_Item.GetItemNameByID` and `C_Item.GetItemInfo`.
--- Default none: no item cached.
---@field itemIcons table<integer, integer> Each item's icon file ID, for `C_Item.GetItemIconByID`. Default none.
---@field itemQualities table<integer, integer> Each item's quality once loaded, for `C_Item.GetItemQualityByID`.
--- Default none: nil, as the client gives for an item it hasn't loaded.
---@field itemRequests integer[] Each `C_Item.RequestLoadItemDataByID` call's item ID, in order. The client loads
--- nothing on its own: a spec sets `itemNames` and fires GET_ITEM_INFO_RECEIVED itself.
---@field bindingCalls string[] Each override call, in order: "set <key> <action>" or "clear".
---@field overrideAction fun(key: string): string? The priority override on `key`, as `GetBindingAction` reads it.
---@field fireGameEvent fun(event: string, ...) Fires a WoW event the game raises on its own. `client.fire` unless a
--- spec or FakePagle replaces it.
---@field update fun(elapsed: number) Runs one frame: each frame's OnUpdate script, given `elapsed` seconds.
---@field cvars table<string, string> Each CVar's value as `GetCVar` reads it. `SetCVar` stores `tostring(value)`; a
--- CVar not listed is one the client doesn't know (`GetCVar` returns nil).
---@field cvarCalls string[] Each `SetCVar` call, in order: "set <name> <value>".
---@field mounted boolean? Whether the player is mounted, as `IsMounted()` reads it.

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
	-- leases (QOL-R62), so a stretch leases nothing until a spec sets the player's own values.
	client.cvars = { SoftTargetInteract = "3", SoftTargetInteractRange = "60", SoftTargetInteractRangeIsHard = "0" }
	client.cvarCalls = {}
	-- A Fishing Pole (6256, as probe B1 read it) and a Worn Shortsword (25).
	client.items = { [6256] = { 2, 20 }, [25] = { 2, 7 } }
	client.itemNames = {}
	client.itemIcons = {}
	client.itemQualities = {}
	client.itemRequests = {}
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

	stubs.GetBindingKey = function(command)
		return unpack(client.boundKeys[command] or {})
	end
	stubs.SetOverrideBinding = function(owner, isPriority, key, command)
		setOverride(owner, isPriority, key, command)
	end
	stubs.SetOverrideBindingSpell = function(owner, isPriority, key, spell)
		setOverride(owner, isPriority, key, "SPELL " .. spell)
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
	-- The item's icon file ID; nil for one not in client.itemIcons (Stats' names, STA-R59).
	stubs.C_Item.GetItemIconByID = function(itemID)
		return client.itemIcons[itemID]
	end
	-- The item's quality; nil for one not in client.itemQualities, not loaded yet (Stats' Catches by quality, STA-R33).
	stubs.C_Item.GetItemQualityByID = function(itemID)
		return client.itemQualities[itemID]
	end
	-- The enUS client's quality names and colours (Stats' qualities, STA-R59): GlobalStrings' ITEM_QUALITY<n>_DESC,
	-- and ITEM_QUALITY_COLORS as Blizzard_Colors' ColorManager fills it, with no colour overrides.
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
	-- The client's local clock: the fake player sits at UTC, so `date` reads as os.date in UTC.
	stubs.date = function(format, time)
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
		return os.date("!" .. format, time)
	end
	stubs.GetCVar = function(name)
		return client.cvars[name]
	end
	stubs.SetCVar = function(name, value)
		client.cvarCalls[#client.cvarCalls + 1] = ("set %s %s"):format(name, tostring(value))
		client.cvars[name] = tostring(value)
	end
	stubs.IsMounted = function()
		return client.mounted == true
	end
	stubs.C_Spell = stubs.C_Spell or {}
	stubs.C_Spell.GetSpellName = function(spellID)
		return FISHING_SPELLS[spellID] and "Fishing" or nil
	end
end
