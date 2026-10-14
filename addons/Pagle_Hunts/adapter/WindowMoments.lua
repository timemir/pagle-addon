if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Window moments at runtime (HNT-R88, SET-R32): the setting's row on the Announcements page, the baseline kept in
-- memory from one regroup to the next (ns.OnRegroup, adapter/Groups.lua), and the Nods raised. The comparison and
-- the Nod's wording are logic/WindowMoments.lua's. The baseline lives only as long as this login: a Module just
-- loaded (a login, a reload, or enabled again, HNT-R190) has none, so its first grouping raises nothing.

-- The Hunt's icon as a moment carries it (HNT-R55): HNT-R55's choice of item, by item ID, which Core turns into
-- its icon (an ID needs no cached item); a generated class's Trade_Fishing. A moment has no tint.
local itemIDs = {
	ItemIcon = function(itemID)
		return itemID
	end,
	QualityColor = function() end,
}

-- The window Nod for one opened row (HNT-R88), its tracker label read as the tracker reads it (HNT-R51).
---@param row HuntRow
---@param current HuntsGrouping
---@param snapshot table `Pagle.GetConditions()`
---@return PagleMoment
local function nodFor(row, current, snapshot)
	local hunt = row.hunt
	local _, label = ns.HuntLabels({
		group = row.group,
		auraUp = row.auraUp,
		window = row.window,
		spec = ns.where[hunt.id].boardSpec,
		need = ns.where[hunt.id].skillNeed,
		best = Pagle.GetAngler().bestBaseSkill,
		now = current.time,
		snapshot = snapshot,
	})
	return ns.WindowNod({
		name = ns.hunts:HuntName(hunt.id),
		label = label,
		icon = ns.HuntIcon(hunt, ns.hunts, itemIDs) or ns.HuntMomentIcon(nil),
		window = row.window,
		from = current.time,
		snapshot = snapshot,
	})
end

--- Adds the setting and starts watching regroups, from OnInitialize: the row before ModulesChanged (CORE-R42), under
--- the "Hunts" header Core puts before Hunts' first row (SET-R3). It has no isEnabled, so Cozy mode never greys it
--- (SET-R32). Every regroup records the baseline, setting on or off; with it on, each window found opened raises its
--- Nod (no cast: an Announcement of its own, ANN-R12). A first grouping made paused, in combat, records none: it read
--- the calendar as no events and a secret clock as no window (LOG-R46), so its redo at RestrictionChanged(false) is
--- the first grouping that sets the baseline (HNT-R43, HNT-R88).
function ns.StartWindowMoments()
	local L = ns.L
	ns.Module:AddSetting("announcements", {
		kind = "checkbox",
		label = L.WINDOW_MOMENTS_SETTING,
		tooltip = L.WINDOW_MOMENTS_TOOLTIP,
		get = function()
			return ns.db.profile.windowMoments
		end,
		set = function(value)
			ns.db.profile.windowMoments = value and true or false
		end,
		default = false,
	})

	local baseline -- HuntWindowBaseline? the last regroup's; nil until the first grouping (HNT-R88)
	ns.OnRegroup(function(_, current)
		local opened = ns.WindowOpenings(baseline, current.rows, ns.db.profile.pins, ns.db.profile.windowMoments)
		baseline = not ns.groups:IsPaused() and ns.WindowBaseline(current) or nil
		if #opened == 0 then
			return
		end
		local snapshot = Pagle.GetConditions()
		for _, row in ipairs(opened) do
			ns.Module:RaiseMoment(nodFor(row, current, snapshot))
		end
	end)
end
