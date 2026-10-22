---@class PagleNS
local ns = select(2, ...)

-- A recording runs against disposable views of an Angler's history. The real Catch log and its projections keep
-- recording; the trailer never replaces the SavedVariables globals. This file owns the cancellable timeline.

---@param value any
---@param seen table?
---@return any
function ns.TrailerCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, item in pairs(value) do
		copy[key] = ns.TrailerCopy(item, seen)
	end
	return copy
end

--- A disposable AceDB view. The saved global/profile tables remain untouched, including during logout.
---@param db table
---@return table
function ns.TrailerDB(db)
	return setmetatable({ global = ns.TrailerCopy(db.global), profile = ns.TrailerCopy(db.profile) }, { __index = db })
end

---@param state table
---@return table
function ns.TrailerProjection(state)
	return {
		GetState = function()
			return state
		end,
		IsUpdating = function()
			return false
		end,
	}
end

--- A deterministic, disposable recording history. Encoded with the same codec as real catches, then folded by
--- each Module's own rules. Module records post goals; the following catches earn their Coins and fly patterns.
---@param catalogue PagleCatalogue
---@param characters table
---@param char integer
---@param snapshot ConditionsSnapshot
---@param now integer
---@return table
function ns.NewTrailerHistory(catalogue, characters, char, snapshot, now)
	local data = {
		format = ns.LOG_FORMAT,
		logId = "pagle-trailer",
		test = true,
		characters = ns.TrailerCopy(characters),
		entries = {},
	}
	local log = ns.OpenCatchLog(data, {}, now, catalogue.GetItem)
	local zones, seen, pairsByZone = {}, {}, {}
	local function addZone(zone)
		if seen[zone] then
			return
		end
		local fish, species = {}, {}
		for _, entry in ipairs(catalogue.GetZoneCatches(zone) or {}) do
			local item = catalogue.GetItem(entry.itemID)
			if item and item.species and not item.legend and not item.removed and not species[item.species] then
				fish[#fish + 1] = entry
				species[item.species] = true
			end
		end
		if #fish >= 1 then
			seen[zone], pairsByZone[zone] = true, fish
			zones[#zones + 1] = zone
		end
	end
	addZone(snapshot.zone)
	for _, zone in ipairs(catalogue.GetZones()) do
		if #zones >= 9 then
			break
		end
		addZone(zone)
	end
	assert(#zones > 0, "Pagle trailer needs charted fishing waters")
	local records = {}
	local function append(record)
		local decoded = log:Append(record)
		records[#records + 1] = decoded
		return decoded
	end
	local function module(kind, payload, at)
		return append({
			kind = "module",
			module = "TackleBoard",
			recordKind = kind,
			payload = payload,
			char = char,
			time = at,
		})
	end
	local function cast(itemID, zone, at, away)
		local conditions = ns.TrailerCopy(snapshot)
		conditions.time, conditions.zone, conditions.subzone = at, zone, 0
		conditions.skillRank, conditions.skillMod, conditions.lure = 300, 25, 2605
		conditions.minute = (snapshot.minute - math.floor((now - at) / 60)) % 1440
		return append({
			kind = "cast",
			char = char,
			time = at,
			outcome = away and "gotAway" or "caught",
			conditions = conditions,
			items = away and {} or { { itemID = itemID, quantity = 1 } },
		})
	end
	local dayStart = math.floor(now / 86400) * 86400
	local start = dayStart - 119 * 86400
	append({ kind = "skill", char = char, time = start - 60, rank = 300, max = 300, mod = 0 })
	local gaps = { [27] = true, [61] = true, [86] = true, [95] = true, [103] = true }
	for day = 0, 119 do
		if not gaps[day] then
			local at = start + day * 86400
			local weekStart = start + math.floor(day / 7) * 7 * 86400
			module(day == 0 and "start" or "day", at .. ";" .. weekStart, at + 1)
			local zone = day == 119 and zones[1] or zones[day % #zones + 1]
			module("issue", "n;haul;1;10;5;" .. zone, at + 2)
			module("issue", "n;variety;1;10;2;" .. zone, at + 3)
			module("issue", "n;size;1;10;2;2", at + 4)
			if day % 7 == 0 then
				module("issue", "e;haul;1;80;30;" .. zone, at + 5)
			end
			local fish = pairsByZone[zone]
			local endAt = day == 119 and math.min(now - 600, at + 3600) or at + 3600
			for i = 1, 90 do
				cast(fish[(i - 1) % #fish + 1].itemID, zone, endAt - (90 - i) * 20, i % 13 == 0)
			end
		end
	end
	-- A few memorable historic catches, as well as ordinary fish, fill the collection spreads.
	local collectibles, collected = {}, {}
	for _, zone in ipairs(catalogue.GetZones()) do
		for _, entry in ipairs(catalogue.GetZoneCatches(zone) or {}) do
			local item = catalogue.GetItem(entry.itemID)
			if
				item
				and not item.removed
				and not collected[entry.itemID]
				and (
					item.legend
					or item.category == "trophy"
					or item.category == "junk"
					or item.category == "treasure"
					or item.category == "container"
				)
			then
				collected[entry.itemID] = true
				collectibles[#collectibles + 1] = { entry.itemID, zone }
			end
		end
	end
	for i, item in ipairs(collectibles) do
		cast(item[1], item[2], now - 500 + i)
	end
	-- Everything the home water lists, caught there, masters it: its zone crest is earned in the sample, for the
	-- Angler page's bookplate to wear.
	local at = now - 500 + #collectibles
	for _, entry in ipairs(catalogue.GetZoneCatches(zones[1]) or {}) do
		local item = catalogue.GetItem(entry.itemID)
		if item and not item.removed and not item.legend then
			at = at + 1
			cast(entry.itemID, zones[1], at)
		end
	end
	assert(at < now - 100, "Pagle trailer sample overran its opening")
	-- Deliberately unknown only inside the disposable sample, for the Field report demonstration.
	cast(999999, zones[1], now - 100)
	-- Leave fresh goals to replace and work towards on the board.
	module("issue", "n;haul;1;10;20;" .. zones[1], now - 90)
	module("issue", "n;variety;1;10;4;" .. zones[1], now - 89)
	module("issue", "n;lure;1;10;15;", now - 88)
	module("issue", "e;haul;1;80;200;" .. zones[1], now - 87)
	return { log = log, records = records, zone = zones[1], item = pairsByZone[zones[1]][1].itemID }
end

--- Relative seconds from the staged record toast. Actions use the same navigation and confirmation handlers
--- as the visible controls. The narration is an editing asset: no speech is played by this timeline.
ns.TRAILER_CUES = {
	{ 0, "caption", "TRAILER_CAPTION_CATCH" },
	{ 10, "caption", "TRAILER_CAPTION_JOURNAL" },
	{ 10, "Ledger.home" },
	{ 14, "Ledger.zone" },
	{ 19, "Ledger.fish" },
	{ 25, "Ledger.waters" },
	{ 30, "Ledger.search" },
	{ 35, "Ledger.searchResult" },
	{ 40, "caption", "TRAILER_CAPTION_VARIETIES" },
	{ 40, "Ledger.varieties" },
	{ 45, "Ledger.variety" },
	{ 50, "caption", "TRAILER_CAPTION_ANGLER" },
	{ 50, "Ledger.angler" },
	{ 57, "caption", "TRAILER_CAPTION_XP" },
	{ 61, "Ledger.title" },
	{ 68, "caption", "TRAILER_CAPTION_COLLECTIONS" },
	{ 68, "Ledger.trophy" },
	{ 74, "Ledger.curios" },
	{ 79, "Ledger.legend" },
	{ 86, "Ledger.close" },
	{ 86, "caption", "TRAILER_CAPTION_STATS" },
	{ 86, "Stats.place" },
	{ 91, "Stats.entry" },
	{ 97, "Stats.watch" },
	{ 99, "Stats.close" },
	{ 102, "Stats.reopen" },
	{ 106, "Stats.session" },
	{ 109, "Stats.lifetime" },
	{ 112, "Stats.close" },
	{ 112, "caption", "TRAILER_CAPTION_HUNTS" },
	{ 112, "Hunts.now" },
	{ 120, "Hunts.later" },
	{ 125, "Hunts.now" },
	{ 128, "Hunts.pin" },
	{ 131, "Hunts.close" },
	{ 134, "Hunts.reopen" },
	{ 137, "Hunts.set" },
	{ 140, "caption", "TRAILER_CAPTION_WAGERS" },
	{ 140, "Hunts.run" },
	{ 146, "Hunts.wagers" },
	{ 153, "Hunts.close" },
	{ 153, "caption", "TRAILER_CAPTION_BOARD" },
	{ 153, "TackleBoard.open" },
	{ 160, "TackleBoard.replace" },
	{ 167, "TackleBoard.flybox" },
	{ 174, "TackleBoard.campfire" },
	{ 180, "TackleBoard.close" },
	{ 182, "caption", "TRAILER_CAPTION_SHOP" },
	{ 182, "shop" },
	{ 188, "shop.preview" },
	{ 192, "shop.bill" },
	{ 196, "shop.buy" },
	{ 201, "shop.result" },
	{ 204, "shop.close" },
	{ 204, "caption", "TRAILER_CAPTION_CRESTS" },
	{ 204, "Ledger.crest" },
	{ 214, "Ledger.close" },
	{ 214, "caption", "TRAILER_CAPTION_COZY" },
	{ 214, "cozy" },
	{ 217, "cozy.on" },
	{ 220, "settings.close" },
	{ 224, "summary" },
	{ 231, "summary.close" },
	{ 231, "caption", "TRAILER_CAPTION_REPORT" },
	{ 231, "report" },
	{ 241, "report.close" },
	{ 241, "caption", "TRAILER_CAPTION_NAME" },
	{ 246, "caption", "TRAILER_CAPTION_END" },
	{ 259, "finish" },
}

---@param options table
---@return table
function ns.NewTrailer(options)
	local L = ns.L
	local trailer = { state = "idle", ticket = 0, restores = {} }

	function trailer:Stop(reason)
		self.ticket = self.ticket + 1
		self.state = "idle"
		local restores = self.restores
		self.restores = {}
		for i = #restores, 1, -1 do
			local ok, problem = pcall(restores[i])
			if not ok then
				options.report(problem)
			end
		end
		options.caption(nil)
		if reason then
			options.print(reason)
		end
	end

	function trailer:Protect(fn)
		local ok, problem = pcall(fn)
		if not ok then
			self:Stop(L.TRAILER_ERROR)
			options.report(problem)
		end
		return ok
	end

	function trailer:Arm()
		if self.state ~= "idle" then
			options.print(L.TRAILER_ACTIVE)
			return false
		end
		local reason = options.ready and options.ready()
		if reason then
			options.print(reason)
			return false
		end
		self.ticket = self.ticket + 1
		self.state = "preparing"
		return self:Protect(function()
			options.prepare(self.restores)
			self.state = "armed"
			options.print(L.TRAILER_ARMED)
		end)
	end

	function trailer:Catch(cast)
		if self.state ~= "armed" then
			return
		end
		self:Protect(function()
			if not options.catch(cast) then
				return
			end
			self.state = "running"
			local ticket = self.ticket
			for _, cue in ipairs(ns.TRAILER_CUES) do
				local at, action, text = cue[1], cue[2], cue[3]
				options.after(at, function()
					if self.ticket ~= ticket or self.state ~= "running" then
						return
					end
					self:Protect(function()
						if action == "finish" then
							self:Stop(L.TRAILER_COMPLETE)
						elseif action == "caption" then
							options.caption(text)
						else
							options.action(action)
						end
					end)
				end)
			end
		end)
	end

	return trailer
end
