-- No words in the Stats book draw past its pages' edges (stats.md › UI; the dev's rule for the books art kit): every
-- page, laid out with the longest strings Pagle meets (the longest Species name in the catalogue for every fish, the
-- longest real zone or subzone name for every place), each text bound to its page's column, wrapped, or cut short.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

local I = stats.IDS

-- The longest Species name in the catalogue.
local function longestSpecies()
	local best = ""
	for found in readFile("data/forever/species.toml"):gmatch("\n# ([^:(\n]-)[:(][^\n]*\n%[species%.") do
		if #found > #best then
			best = found
		end
	end
	return best
end

-- The longest real area name in the client's table: letters, spaces and apostrophes, no dev leftovers.
local function longestArea()
	local best = ""
	for name in readFile("data/db2/areas.csv"):gmatch("\n%d+,%d+,%d+,([^\n]*)") do
		name = name:gsub("\r$", "")
		if #name > #best and name:match("^[%a' ]+$") and not name:lower():find("unused") then
			best = name
		end
	end
	return best
end

local SPECIES, AREA = longestSpecies(), longestArea()

describe("the Stats book's words stay on its pages", function()
	it("are the longest the data holds", function()
		assert.is_true(#SPECIES >= 25)
		assert.is_true(#AREA >= 20)
	end)

	it(
		"on every page: home, a zone and a subzone with each fish chosen, each fish's page, the Sessions, Lifetime",
		function()
			local loaded, fake, book = stats.start({
				records = stats.darkshore({ uncharted = true }),
				at = { zone = I.DARKSHORE, subzone = I.AUBERDINE, skillRank = 200, skillMod = 0 },
			})
			local ns = loaded.ns
			for itemID in pairs(stats.NAMES.items) do
				loaded.client.itemNames[itemID] = SPECIES
			end
			loaded.client.itemNames[I.UNCHARTED] = SPECIES
			for areaID in pairs(stats.NAMES.areas) do
				loaded.client.areaNames[areaID] = AREA
			end
			ns.Watch(I.NIGHTFIN, I.AUBERDINE)

			local found, placed = {}, 0
			local function collect(label, page)
				for _, side in ipairs({ "left", "right" }) do
					local view = book.pages[page .. ":" .. side]
					if view and view.clip:IsShown() then
						for _, overflow in ipairs(bounds.overflows(view.content)) do
							found[#found + 1] = ("%s %s: %s"):format(label, side, overflow)
						end
						placed = placed + bounds.measured
					end
				end
				for _, overflow in ipairs(bounds.overflows(book.frame.crumbs)) do
					found[#found + 1] = ("%s crumbs: %s"):format(label, overflow)
				end
			end
			ns.OpenBook({ page = "home" })
			collect("home", "home")
			for _, area in ipairs({ I.DARKSHORE, I.AUBERDINE }) do
				ns.OpenBook({ page = "place", area = area })
				collect("place " .. area, "place")
				for itemID in pairs(stats.NAMES.items) do
					ns.OpenBook({ page = "place", area = area, item = itemID })
					collect(("place %d item %d"):format(area, itemID), "place")
					ns.OpenBook({ page = "item", item = itemID })
					collect("item " .. itemID, "item")
				end
			end
			for _, page in ipairs({ "session", "sessions", "lifetime" }) do
				ns.OpenBook({ page = page })
				collect(page, page)
			end
			local _ = fake

			assert.are.same({}, found)
			assert(placed > 200, "only " .. placed .. " texts placed")
		end
	)
end)
