if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Coexisting with Angleur and Fishing Buddy (QOL-R80–R84): which other fishing-key addons are loaded, and what the
-- popup and chat say about them. Pure logic, everything passed in (CORE-R7).

--- The conflict list (qol.md › Tunables, QOL-R80): the folder names of the other fishing-key addons. Re-checked on
--- the live build in M8 (QOL-R104).
--- - `Angleur`: Angleur's folder; its Forever build is Angleur_Camelot.toc in it (Angleur 2.9.78, read from its
---   installed TOCs). Its plugin Angleur_NicheOptions depends on it, so it never loads without it.
--- - `FishingBuddy`: Fishing Buddy's folder (Sutorix), and the folder both Forever ports install into, read from
---   their published zips: Fishing Buddy Forever Fix by Ezreth (CurseForge project 1702188, file 8917542,
---   FishingBuddy-1.0.2-Forever-Beta-1.60.1-2026-09-19.zip) and Fishing Buddy (Forever) (Crusade) by crediar
---   (CurseForge project 1455763, file 9026969, Fishing Buddy Forever 1.0.7). Each zip's one top-level folder is
---   FishingBuddy/, so one name covers all three.
ns.CONFLICT_LIST = { "Angleur", "FishingBuddy" }

--- An other fishing-key addon that is loaded.
---@class PagleQoLConflict
---@field name string its folder name
---@field title string its title, as the popup and chat name it

--- The other fishing-key addons that are loaded, in conflict-list order (QOL-R80).
---@param isLoaded fun(name: string): boolean whether an addon is loaded, as `C_AddOns.IsAddOnLoaded` reads it
---@param titleOf fun(name: string): string? an addon's TOC Title; the folder name stands in when there is none
---@return PagleQoLConflict[]
function ns.FindConflicts(isLoaded, titleOf)
	local found = {}
	for _, name in ipairs(ns.CONFLICT_LIST) do
		if isLoaded(name) then
			found[#found + 1] = { name = name, title = titleOf(name) or name }
		end
	end
	return found
end

--- The popup's second choice: "Use {other}", or "Use the others" when there are several (QOL-R81).
---@param found PagleQoLConflict[] at least one
---@return string
function ns.UseOtherLabel(found)
	if #found > 1 then
		return ns.L.CONFLICT_USE_OTHERS
	end
	return ns.L.CONFLICT_USE_OTHER:format(found[1].title)
end

--- The chat line after "Use Pagle", the titles joined by ", " (QOL-R83).
---@param found PagleQoLConflict[]
---@return string
function ns.TurnedOffMessage(found)
	local titles = {}
	for i, conflict in ipairs(found) do
		titles[i] = conflict.title
	end
	return ns.L.CONFLICT_TURNED_OFF:format(table.concat(titles, ", "))
end
