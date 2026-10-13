if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Lures on the Fishing key (QOL-R29, QOL-R50–R53): which lure is next, the wait for a lure's result, the lures
-- skipped after a failed use, and when the out-of-lures Nudge shows. Pure logic, everything passed in (CORE-R7);
-- adapter/Lures.lua reads the bags and the pole.

---@alias PagleQoLLuresMode "off"|"best"|"one"

--- The lure the Fishing key applies next (QOL-R51): under *Best I have*, the available lure with the highest bonus,
--- ties to the lower item ID; under *Only this one*, the chosen lure if it is available; under *Off*, none. Only the
--- lure table's items are ever picked (QOL-R96).
---@param mode PagleQoLLuresMode
---@param chosen integer the item ID chosen for *Only this one*
---@param isAvailable fun(itemID: integer): boolean in the bags, usable and not skipped (QOL-R51)
---@return integer? itemID
function ns.ChooseLure(mode, chosen, isAvailable)
	local best
	for _, lure in ipairs(ns.LURES) do
		local wanted = mode == "best" or (mode == "one" and lure.itemID == chosen)
		if wanted and isAvailable(lure.itemID) then
			if not best or lure.bonus > best.bonus or (lure.bonus == best.bonus and lure.itemID < best.itemID) then
				best = lure
			end
		end
	end
	return best and best.itemID
end

--- Seconds QoL waits for a lure's result before it counts the use as failed (qol.md › Tunables, QOL-R29).
ns.RESULT_WAIT = 2

--- QoL's live lure state: the use whose result it awaits, the lures it skips after a failed use (QOL-R29), and
--- the pole's last lure reading for the out-of-lures Nudge (QOL-R53). It lives for the session, so a login or
--- `/reload` starts it afresh.
---@class PagleQoLLureState
---@field waiting { itemID: integer, due: number }? the use awaited, and when the result wait ends
---@field skipped table<integer, true> the lure IDs skipped
---@field wasOn boolean? the pole's lure at the last reading; nil with no pole in hand, or before a first reading
---@field nudged integer? the Fishing stretch the out-of-lures Nudge last showed in
local LureState = {}
LureState.__index = LureState

--- A lure state with nothing awaited or skipped.
---@return PagleQoLLureState
function ns.NewLureState()
	return setmetatable({ skipped = {} }, LureState)
end

--- A lure's use finished casting (`UNIT_SPELLCAST_SUCCEEDED`): the result wait starts (QOL-R29).
---@param itemID integer
---@param now number seconds, as GetTime() reads them
function LureState:Applied(itemID, now)
	self.waiting = { itemID = itemID, due = now + ns.RESULT_WAIT }
end

--- Whether the pole counts as lured (QOL-R20 step 4, QOL-R29): its lure is on, or a use's result is awaited. The
--- wait ends once the lure shows; once it has run out with no lure on, that lure is skipped.
---@param enchanted boolean the main hand's lure is on, as `GetWeaponEnchantInfo()` reads it
---@param now number seconds, as GetTime() reads them
---@return boolean
function LureState:Lured(enchanted, now)
	local waiting = self.waiting
	if waiting and (enchanted or now >= waiting.due) then
		self.waiting = nil
		if not enchanted then
			self:Skip(waiting.itemID)
		end
	end
	return enchanted or self.waiting ~= nil
end

--- Skips a lure whose use failed, until ClearSkips (QOL-R29, QOL-R51).
---@param itemID integer
function LureState:Skip(itemID)
	self.skipped[itemID] = true
end

---@param itemID integer
---@return boolean
function LureState:IsSkipped(itemID)
	return self.skipped[itemID] == true
end

--- Fishing skill changed (`SKILL_LINES_CHANGED`): every skipped lure may be tried again (QOL-R29).
function LureState:ClearSkips()
	self.skipped = {}
end

--- Reads the pole's lure, and whether the out-of-lures Nudge is due (QOL-R53): the lure went from on to off during
--- a Fishing stretch that hasn't had the Nudge yet, Lures isn't *Off*, and no lure is available. A pole coming off
--- isn't its lure going off.
---@param enchanted boolean? the main hand's lure is on; nil while no fishing pole is in hand
---@param stretch integer? the running Fishing stretch's number, nil while none runs
---@param mode PagleQoLLuresMode
---@param lure integer? the lure ns.ChooseLure picks now
---@return boolean
function LureState:OutOfLures(enchanted, stretch, mode, lure)
	local wentOff = self.wasOn == true and enchanted == false
	self.wasOn = enchanted
	if not wentOff or stretch == nil or stretch == self.nudged or mode == "off" or lure ~= nil then
		return false
	end
	self.nudged = stretch
	return true
end

--- The out-of-lures Nudge's text (QOL-R53), naming the chosen lure under *Only this one*.
---@param mode PagleQoLLuresMode
---@param lureName string? the chosen lure's name, under *Only this one*
---@return string
function ns.OutOfLuresText(mode, lureName)
	if mode == "one" then
		return ns.L.NUDGE_OUT_OF_LURE:format(lureName or "")
	end
	return ns.L.NUDGE_OUT_OF_LURES
end
