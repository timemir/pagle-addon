-- No words on the Hunts board draw past its pages' edges (HNT-R60; the dev's rule for the books art kit): every page
-- of every mode, laid out with the longest strings Pagle ships (the longest Species name in the catalogue, Hunt name,
-- set name, title and notes in Hunts' lore), each text bound to its page's column, wrapped, or cut short.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

-- The longest of `pattern`'s captures in the file at `path`.
local function longest(path, pattern)
	local best = ""
	for found in readFile(path):gmatch(pattern) do
		if #found > #best then
			best = found
		end
	end
	return best
end

local LORE = "addons/Pagle_Hunts/data/Lore.lua"
local LONGEST = {
	species = longest("data/forever/species.toml", "\n# ([^:(\n]-)[:(][^\n]*\n%[species%."),
	hunt = longest(LORE, 'L%["hunt%.[%w_]+%.name"%] = "([^"]*)"'),
	note = longest(LORE, 'L%["[%w_]+%.[%w_]+%.note"%] = "([^"]*)"'),
	set = longest(LORE, 'L%["set%.[%w_]+%.name"%] = "([^"]*)"'),
	title = longest(LORE, 'L%["set%.[%w_]+%.title"%] = "([^"]*)"'),
}

-- Hunts with every name, note, set and title the longest shipped, and every item named the longest Species.
local function start()
	local run = hunts.start({
		names = true,
		prepare = function(loaded)
			local L = loaded.ns.L
			for _, hunt in ipairs(loaded.ns.huntList.hunts) do
				L["hunt." .. hunt.id .. ".name"] = LONGEST.hunt
				L["hunt." .. hunt.id .. ".note"] = LONGEST.note
			end
			for _, set in ipairs(loaded.ns.huntList.sets) do
				L["set." .. set.id .. ".name"] = LONGEST.set
				L["set." .. set.id .. ".title"] = LONGEST.title
				L["set." .. set.id .. ".note"] = LONGEST.note
			end
		end,
	})
	for itemID in pairs(hunts.catalogue.NAMES.items) do
		run.loaded.client.loadItem(itemID, LONGEST.species)
	end
	-- every Hunt done to its second tier, with long counts, and every set's title earned: seals, dates and ink bars show
	local progress, sets = {}, {}
	for _, hunt in ipairs(run.ns.hunts:Hunts()) do
		progress[hunt.id] = hunts.progress({ tiers = 2, count = 12345, effort = 123456, sinceLast = 12345 })
	end
	for _, set in ipairs(run.ns.hunts:Sets()) do
		sets[set.id] = { earnedAt = hunts.JAN_1, date = { year = 2026, month = 12, day = 30 }, fromRetirement = false }
	end
	hunts.useState(run, progress, sets)
	run.ns.Redraw("names")
	return run
end

-- Every overflow on both pages of the mode shown, each with its place; and how many texts it placed.
local function overflows(run, label)
	local out, placed = {}, 0
	for _, side in ipairs({ "left", "right" }) do
		for _, overflow in ipairs(bounds.overflows(run.ns.board:Page(run.ns.board.router:Place(), side))) do
			out[#out + 1] = ("%s %s: %s"):format(label, side, overflow)
		end
		placed = placed + bounds.measured
	end
	return out, placed
end

describe("the Hunts board's words stay on its pages", function()
	it("are the longest the data ships", function()
		-- a check on the check: the strings are real, and long
		assert.is_true(#LONGEST.species >= 25)
		assert.is_true(#LONGEST.hunt >= 18)
		assert.is_true(#LONGEST.note >= 50)
	end)

	it("on the Board, the set pages, the entries and retired entries opened from them, and the strip", function()
		local run = start()
		local found, measured = {}, 0
		local function collect(label)
			local pages, placed = overflows(run, label)
			for _, overflow in ipairs(pages) do
				found[#found + 1] = overflow
			end
			measured = measured + placed
			-- the shell's crumbs (BOOK-R12) and the board's clock and checkbox on its leather anchors (BOOK-R16)
			local book = run.ns.board.book
			local parts = { crumbs = book.frame.crumbs, clock = book.anchors.clock, completed = book.anchors.completed }
			for _, part in ipairs({ "crumbs", "clock", "completed" }) do
				for _, overflow in ipairs(bounds.overflows(parts[part])) do
					found[#found + 1] = ("%s %s: %s"):format(label, part, overflow)
				end
			end
		end
		for _, hunt in ipairs(run.ns.hunts:Current(run.ns.ViewNow())) do
			run.ns.board:Open({ mode = "board", hunt = hunt.id })
			collect("board " .. hunt.id)
		end
		for _, set in ipairs(run.ns.hunts:Sets()) do
			run.ns.board:Open({ mode = "set", set = set.id })
			collect("set " .. set.id)
			for _, hunt in ipairs(run.ns.hunts:SetHunts(set.id)) do
				run.ns.board:Open({ mode = "entry", set = set.id, hunt = hunt.id })
				collect("entry " .. hunt.id)
				run.ns.board:Open({ mode = "retired", set = set.id, hunt = hunt.id })
				collect("retired " .. hunt.id)
			end
		end

		assert.are.same({}, found)
		assert(measured > 200, "only " .. measured .. " texts placed")
	end)
end)
