if not Pagle or not Pagle.RegisterTrailerPart then
	return
end
---@class PagleLedgerNS
local ns = select(2, ...)

Pagle.RegisterTrailerPart("Ledger", function(ctx)
	local fold = ns.NewLedgerFold(ns.LedgerLookups(Pagle))
	local state = fold.reset()
	for _, record in ipairs(ctx.records) do
		fold.apply(state, record, "rebuild")
	end
	local savedPlace, wasShown = ns.journal.router:Place(), ns.journal:IsShown()
	ctx.defer(function()
		if ctx.loggingOut then
			return
		end
		ns.journal.router:Open(savedPlace.id, savedPlace.args)
		if wasShown then
			ns.journal:Draw()
		else
			ns.journal:Close()
		end
	end)
	ctx.swap(ns, "db", ctx.db(ns.db))
	ctx.swap(ns, "projection", ctx.projection(state))
	ns.CelebratedSet(ns.db.global)
	ctx.coins("Ledger", state.coins)
	local openingItem = assert(Pagle.GetItem(ctx.item))
	local species = assert(openingItem.species)
	local function open(place)
		ns.journal:OpenPlace(place)
	end
	local function stop(id)
		for _, entry in ipairs(ns.JOURNAL_TOUR) do
			if entry.id == id then
				local view = ns.journal:Context()
				assert(not view.updating and view.state)
				open(entry.place(view --[[@as LedgerSpreadContext]]))
				return
			end
		end
	end
	local other = species
	for id in pairs(state.species) do
		if id ~= species then
			other = id
			break
		end
	end
	-- The Species with the most varieties caught, the opening fish's on a tie, and two of its caught varieties.
	local variety, varietyCount = species, -1
	for id, caught in pairs(state.varieties) do
		local count = 0
		for _ in pairs(caught) do
			count = count + 1
		end
		if count > varietyCount or (count == varietyCount and id == species) then
			variety, varietyCount = id, count
		end
	end
	local positions = {}
	for position in pairs(state.varieties[variety] or {}) do
		positions[#positions + 1] = position
	end
	table.sort(positions)
	--- A zone with a crest, earned or not as `earned` says: the opening water first.
	---@param earned boolean
	---@return string?
	local function crestOf(earned)
		local celebrated = ns.SavedCelebrated()
		local zones = { ctx.zone }
		for areaID in pairs(state.zones) do
			zones[#zones + 1] = areaID
		end
		for _, areaID in ipairs(zones) do
			local crest = ns.ZoneCrestOf(areaID)
			if crest and ns.ZoneCrestEarned(state, celebrated, areaID) == earned then
				return crest.id
			end
		end
	end
	local actions = {
		home = function()
			open(ns.JournalPlace.home())
		end,
		zone = function()
			open(ns.JournalPlace.zone(ctx.zone, species))
		end,
		fish = function()
			open(ns.JournalPlace.fish(species))
		end,
		waters = function()
			open(ns.JournalPlace.zone(ctx.zone, species))
		end,
		search = function()
			ns.journal.frame.search:SetText(ns.journal:Context().text:Item(other):sub(1, 4))
			ns.journal.frame.search:ClearFocus()
		end,
		searchResult = function()
			ns.journal.frame.search:SetText("")
			open(ns.JournalPlace.fish(other))
		end,
		varieties = function()
			open(ns.JournalPlace.varieties(variety, positions[1]))
		end,
		variety = function()
			open(ns.JournalPlace.varieties(variety, positions[#positions]))
		end,
		angler = function()
			open(ns.JournalPlace.angler())
		end,
		-- The home water's zone crest, earned in the sample, pinned on the Angler page's bookplate (LED-R112): the shop
		-- lists no earned crest (SHOP-R25), and equipping it here is the disposable copy's, restored with it.
		crest = function()
			Pagle.SetEquipped("core.crest", assert(crestOf(true), "No zone crest is earned in the trailer sample"))
			open(ns.JournalPlace.angler())
		end,
		title = function()
			local pages = ns.journal.router:Pages(ns.journal:Context())
			for _, side in ipairs({ pages.left, pages.right }) do
				for _, block in ipairs(side) do
					if block.style == "radio" and block.action and not block.on then
						block.action()
						return
					end
				end
			end
		end,
		trophy = function()
			stop("journal.trophy")
		end,
		curios = function()
			open(ns.JournalPlace.curios())
		end,
		legend = function()
			for id in pairs(state.items) do
				local item = Pagle.GetItem(id)
				if item and item.legend then
					open(ns.JournalPlace.legends(id, true))
					return
				end
			end
			open(ns.JournalPlace.legends())
		end,
		close = function()
			ns.journal:Close()
		end,
	}
	return {
		actions = actions,
		catch = function(cast)
			local caught
			for _, item in ipairs(cast.items) do
				if item.itemID == ctx.item then
					caught = item
					break
				end
			end
			if not caught or not caught.size then
				return nil
			end
			-- Stage the preceding record in this disposable display only. The real length and progression are untouched.
			local old = math.max(1, math.floor(caught.size.length * 0.86))
			local entry = state.species[species]
			if entry then
				entry.record = {
					length = old,
					band = 2,
					catchId = "trailer-previous",
					time = cast.time - 86400,
					char = cast.char,
					zone = cast.conditions.zone,
				}
				entry.since = 60
			end
			local earned = fold.apply(state, cast, "rebuild")
			ctx.coins("Ledger", state.coins)
			local record
			for _, achievement in ipairs(earned) do
				if achievement.kind == "sizeRecord" then
					record = achievement
					break
				end
			end
			if not record then
				-- A fish outside the seeded waters still gets an honest Pagle-length demonstration.
				record = {
					kind = "sizeRecord",
					cast = cast.id,
					coins = 0,
					itemID = ctx.item,
					old = old,
					new = caught.size.length,
					flair = true,
					size = caught.size,
				}
			end
			local moments = ns.Celebrate(
				ns.CelebratedSet(ns.db.global),
				state,
				cast,
				{ record },
				ns.Outlets(ns.Module),
				ns.LedgerLookups(Pagle)
			)
			return moments[1]
		end,
	}
end)
