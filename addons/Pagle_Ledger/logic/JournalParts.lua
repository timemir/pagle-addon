if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's parts that more than one spread uses: tile order, prose lists, sorted keys and how stars print.
-- Pure logic (CORE-R7), loaded before the spreads (Pagle_Ledger.toc).

--- Zones in tile order (LED-R131): by skill base, zones without one last, then by areaID. A sorted copy: `zones` is
--- left as it was.
---@param zones integer[]
---@param skillBase { [integer]: integer }
---@return integer[]
function ns.SortZonesBySkill(zones, skillBase)
	local sorted = {}
	for i, zone in ipairs(zones) do
		sorted[i] = zone
	end
	table.sort(sorted, function(a, b)
		local sa, sb = skillBase[a], skillBase[b]
		if sa ~= sb then
			if sa == nil or sb == nil then
				return sb == nil
			end
			return sa < sb
		end
		return a < b
	end)
	return sorted
end

--- The keys of a set, ascending (LED-R123).
---@generic K
---@param set table<K, any>
---@return K[]
function ns.SortedKeys(set)
	local keys = {}
	for key in pairs(set) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

--- A list as prose (LED-R140): "A", "A and B", "A, B and C".
---@param items string[]
---@return string
function ns.JoinAnd(items)
	local L = ns.L
	if #items <= 1 then
		return items[1] or ""
	end
	return table.concat(items, L.LIST_SEPARATOR, 1, #items - 1) .. L.LIST_LAST .. items[#items]
end

--- A set of stars as the Journal prints it (LED-R48): three marks, ★ for each star shown and ☆ for each blank, so
--- ★★★ without ★★ reads "★☆★".
---@param stars LedgerStars
---@return string
function ns.JournalStars(stars)
	local L = ns.L
	local marks = {}
	for star = 1, 3 do
		marks[star] = stars[star] and L.STAR_ON or L.STAR_OFF
	end
	return table.concat(marks)
end

--- A set of stars as three ink stamps (LED-R140, LED-R143): each of `labels`, inked when its star is shown (LED-R48,
--- LED-R92).
---@param stars LedgerStars
---@param labels string[] the three stamps' words
---@return { text: string, inked: boolean }[]
function ns.JournalStamps(stars, labels)
	local stamps = {}
	for star, text in ipairs(labels) do
		stamps[star] = { text = text, inked = stars[star] == true }
	end
	return stamps
end
