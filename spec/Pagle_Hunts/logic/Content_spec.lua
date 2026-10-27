-- Pushed Hunt Events (HNT-R140, HNT-R141, HNT-R154; hunts.md › Contracts › Pushed Hunt Events and runs): Hunts' own
-- strict reader and writer of one item in the content grammar (core/pushed-content.md › The payload, PUSH-R20), and
-- the checks it runs in game on a `huntEvent` item (DATA-R99's that need no generator). Over FakePagle with the fixture
-- catalogue and Hunt list.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

-- A pushed event that passes every check: the example in hunts.md › Contracts, in the fixture's zones and classes.
local function item()
	return {
		kind = "huntEvent",
		v = 1,
		id = "p_hallows_hollow_tide",
		zones = { C.DARKSHORE, C.ELWYNN },
		tags = { "hallows_end", "night" },
		skill = { 75, 150 },
		rotation = false,
		name = "Hollow Tide",
		note = 'A "hollow" tide\nand a \\ in it.',
		hunts = {
			{
				id = "p_hallows_hollow_tide_haul",
				name = "Tide Haul",
				class = "species.any",
				minBand = 3,
				conditions = { time = { { 1260, 240 } } },
				tiers = { 20, 50, 100 },
			},
			{ id = "p_hallows_hollow_tide_snapper", species = C.NIGHTFIN, tiers = { 1 } },
			{ id = "p_hallows_hollow_tide_oddity", class = "fixed.oddity", tiers = { 1, 5 } },
		},
	}
end

describe("Pushed Hunt Events", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local ns = hunts.load(fake).ns

	describe("the reader and writer (PUSH-R20, HNT-R154)", function()
		it("writes an item on one line, kind and v first, fields by name, and reads it back the same", function()
			local text = assert(ns.WriteContentItem(item()))

			assert.is_nil(text:find("\n"))
			assert.are.equal('{kind="huntEvent",v=1,hunts={', text:sub(1, 29))
			assert.are.same(item(), ns.ReadContentItem(text))
		end)

		it("reads the grammar with whitespace between tokens, and every value kind", function()
			local read = ns.ReadContentItem(
				'{ kind = "huntRun", v = 1, event = "p_x", start = 1793714400, list = { -1, true, false, "a", },'
					.. " empty = {}, nested = { a = { b = 1, }, }, }"
			)

			assert.are.same({
				kind = "huntRun",
				v = 1,
				event = "p_x",
				start = 1793714400,
				list = { -1, true, false, "a" },
				empty = {},
				nested = { a = { b = 1 } },
			}, read)
		end)

		it("reads nothing outside the grammar, and says why", function()
			for _, text in ipairs({
				'{v=1,kind="huntEvent",}', -- kind first
				'{kind="huntEvent",v=1}', -- every field ends in ","
				'{kind="huntEvent",v=1,id="a"}',
				"{kind=\"huntEvent\",v=1,id='a',}", -- single quotes
				'{kind="huntEvent",v=1,id="a\\tb",}', -- an escape the grammar hasn't
				'{kind="huntEvent",v=1,n=1.5,}', -- not an integer
				'{kind="huntEvent",v=1,n=0x10,}',
				'{kind="huntEvent",v=1,n=nil,}',
				'{kind="huntEvent",v=1,t={1,a=2,},}', -- values and fields mixed
				'{kind="huntEvent",v=1,a=1,a=2,}', -- a field twice
				'{kind="huntEvent",v=1,["a"]=1,}',
				'{kind="huntEvent",v=1,id="a",} x', -- text after it
				'{kind="huntEvent",v=1,f=function() end,}',
				'{kind="huntEvent",v=1,id="unterminated,}',
				"return {}",
			}) do
				local read, problem = ns.ReadContentItem(text)
				assert.is_nil(read)
				assert.are.equal("string", type(problem))
			end
		end)

		it("refuses to write what the grammar can't hold", function()
			for _, bad in ipairs({
				{ kind = "huntEvent", v = 1, n = 1.5 },
				{ kind = "huntEvent", v = 1, t = { 1, a = 2 } },
				{ kind = "huntEvent", v = 1, t = { [2] = 1 } },
				{ kind = "huntEvent", v = 1, ["not a name"] = 1 },
				{ kind = "huntEvent", v = 1, f = print },
				{ v = 1 },
			}) do
				local text, problem = ns.WriteContentItem(bad)
				assert.is_nil(text)
				assert.are.equal("string", type(problem))
			end
		end)
	end)

	describe("the checks it can run in game (hunts.md › Contracts, DATA-R99)", function()
		it("passes the Contracts' example", function()
			assert.is_nil(ns.HuntEventProblem(item(), ns.lookups))
		end)

		it("admits a skill range below zero, as the pool's (DATA-R97)", function()
			local e = item()
			e.skill = { -70, -20 }
			assert.is_nil(ns.HuntEventProblem(e, ns.lookups))
			e.skill = { -20, 75 }
			assert.is_nil(ns.HuntEventProblem(e, ns.lookups))
		end)

		-- Each change to the passing item, and the start of the problem it makes.
		local cases = {
			{
				"another kind",
				function(e)
					e.kind = "huntRun"
				end,
				"it isn't a huntEvent",
			},
			{
				"another version",
				function(e)
					e.v = 2
				end,
				"it isn't a huntEvent",
			},
			{
				"a field it doesn't have",
				function(e)
					e.season = "autumn"
				end,
				"it has a field",
			},
			{
				"an ID without p_",
				function(e)
					e.id = "hallows_hollow_tide"
				end,
				"its id isn't",
			},
			{
				"no zones",
				function(e)
					e.zones = {}
				end,
				"its zones",
			},
			{
				"three zones",
				function(e)
					e.zones = { C.DARKSHORE, C.ELWYNN, C.WESTFALL }
				end,
				"its zones",
			},
			{
				"a subzone as a zone",
				function(e)
					e.zones = { C.AUBERDINE }
				end,
				"its zones",
			},
			{
				"an area the catalogue hasn't",
				function(e)
					e.zones = { 999999 }
				end,
				"its zones",
			},
			{
				"a zone twice",
				function(e)
					e.zones = { C.DARKSHORE, C.DARKSHORE }
				end,
				"its zones",
			},
			{
				"an unknown tag",
				function(e)
					e.tags = { "night", "spooky" }
				end,
				"its tags",
			},
			{
				"a skill range upside down",
				function(e)
					e.skill = { 150, 75 }
				end,
				"its skill",
			},
			{
				"a negative skill range upside down",
				function(e)
					e.skill = { -20, -70 }
				end,
				"its skill",
			},
			{
				"a skill that isn't a whole number",
				function(e)
					e.skill = { -20.5, 75 }
				end,
				"its skill",
			},
			{
				"a skill that isn't a number",
				function(e)
					e.skill = { "75", 150 }
				end,
				"its skill",
			},
			{
				"a rotation that isn't a boolean",
				function(e)
					e.rotation = "no"
				end,
				"its rotation",
			},
			{
				"two Hunts",
				function(e)
					e.hunts[3] = nil
				end,
				"it hasn't 3 to 5 Hunts",
			},
			{
				"six Hunts",
				function(e)
					for i = 4, 6 do
						e.hunts[i] = { id = "p_more_" .. i, class = "species.any", tiers = { 1 } }
					end
				end,
				"it hasn't 3 to 5 Hunts",
			},
			{
				"a Hunt twice",
				function(e)
					e.hunts[2].id = e.hunts[1].id
				end,
				"its Hunt p_hallows_hollow_tide_haul twice",
			},
			{
				"an unknown class",
				function(e)
					e.hunts[1].class = "fixed.nothing"
				end,
				"its Hunt 1: its class",
			},
			{
				"an item that isn't a Species",
				function(e)
					e.hunts[2].species = C.NIGHTFIN_FOREVER
				end,
				"its Hunt 2: its species",
			},
			{
				"both a species and a class",
				function(e)
					e.hunts[2].class = "species.any"
				end,
				"its Hunt 2: it has neither or both",
			},
			{
				"minBand 5",
				function(e)
					e.hunts[1].minBand = 5
				end,
				"its Hunt 1: its minBand",
			},
			{
				"minBand 1",
				function(e)
					e.hunts[1].minBand = 1
				end,
				"its Hunt 1: its minBand",
			},
			{
				"tiers not ascending",
				function(e)
					e.hunts[1].tiers = { 20, 20, 100 }
				end,
				"its Hunt 1: its tiers aren't ascending",
			},
			{
				"no tiers",
				function(e)
					e.hunts[1].tiers = {}
				end,
				"its Hunt 1: its tiers",
			},
			{
				"areas in its own conditions (HNT-R141)",
				function(e)
					e.hunts[1].conditions = { areas = { C.DARKSHORE } }
				end,
				"its Hunt 1: its conditions name areas",
			},
			{
				"a condition field LOG-R48 hasn't",
				function(e)
					e.hunts[1].conditions = { weather = { 1 } }
				end,
				"its Hunt 1: its conditions have a field",
			},
			{
				"an empty time list (LOG-R48)",
				function(e)
					e.hunts[1].conditions = { time = {} }
				end,
				"its Hunt 1: its conditions' time",
			},
			{
				"a time range from == to",
				function(e)
					e.hunts[1].conditions = { time = { { 60, 60 } } }
				end,
				"its Hunt 1: its conditions' time",
			},
			{
				"a bad season",
				function(e)
					e.hunts[1].conditions = { season = { { from = { 13, 1 }, to = { 1, 1 } } } }
				end,
				"its Hunt 1: its conditions' season",
			},
			{
				"a bad skill",
				function(e)
					e.hunts[1].conditions = { skill = { max = 10 } }
				end,
				"its Hunt 1: its conditions' skill",
			},
			{
				"a field a Hunt hasn't",
				function(e)
					e.hunts[1].window = "night"
				end,
				"its Hunt 1: it isn't a table of a Hunt's fields only",
			},
		}
		for _, case in ipairs(cases) do
			it("fails " .. case[1], function()
				local e = item()
				case[2](e)

				local problem = ns.HuntEventProblem(e, ns.lookups)

				assert.are.equal("string", type(problem))
				assert.are.equal(case[3], problem:sub(1, #case[3]))
			end)
		end

		it("passes every LOG-R48 field but areas, and a lure of any kind", function()
			local e = item()
			e.hunts[1].conditions = {
				time = { { 1260, 240 } },
				season = { { from = { 10, 18 }, to = { 11, 1 } } },
				events = { 301 },
				auras = { C.RACK_AURA },
				lure = true,
				skill = { min = 0 },
			}
			assert.is_nil(ns.HuntEventProblem(e, ns.lookups))
		end)

		it("knows exactly data/hunts/tags.toml's tags (DATA-R97)", function()
			local tags = {}
			for line in readFile("data/hunts/tags.toml"):gmatch("[^\n]+") do
				local id = line:match('^id%s*=%s*"([^"]+)"')
				if id then
					tags[id] = true
				end
			end
			assert.are.same(tags, ns.EVENT_TAGS)
		end)
	end)
end)
