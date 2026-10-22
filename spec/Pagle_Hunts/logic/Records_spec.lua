-- Hunts' own Module records (hunts.md › Contracts, HNT-R150, HNT-R154; LOG-R40, ADR 0008): logic/Records.lua's codec
-- of `run` and `def` payloads, and the largest definition the Contracts allow split into parts under LOG-R40's 200
-- bytes and put back together. Over FakePagle, whose M:AppendRecord checks each payload as Core does.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

describe("Hunts' run and def records", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local ns = hunts.load(fake).ns

	describe("run (HNT-R150)", function()
		it("writes <eventID>|<start>|<end>|<source> in decimal, and reads it back", function()
			local payload = ns.EncodeRun("fixture_shore", 1772323200, 1772582400, "r")

			assert.are.equal("fixture_shore|1772323200|1772582400|r", payload)
			assert.are.same(
				{ event = "fixture_shore", start = 1772323200, end_ = 1772582400, source = "r" },
				ns.DecodeRun(payload)
			)
			assert.are.same("p", ns.DecodeRun("p_tide|1|2|p").source)
		end)

		it("reads nothing from a payload that isn't a run: it is skipped (HNT-R150)", function()
			for _, payload in ipairs({
				"fixture_shore|20|10|r", -- start after end
				"fixture_shore|10|10|r", -- start == end
				"fixture_shore|10|20|x", -- an unknown source
				"fixture_shore|10|20", -- no source
				"fixture shore|10|20|r", -- an ID outside [%w_]+
				"fixture_shore|-10|20|r",
				"fixture_shore|010|20|r", -- a leading zero
				"fixture_shore|10|20|r|extra",
				"",
			}) do
				assert.is_nil(ns.DecodeRun(payload))
			end
		end)

		it("refuses to write a run the record can't hold", function()
			assert.has_error(function()
				ns.EncodeRun("fixture shore", 10, 20, "r")
			end)
			assert.has_error(function()
				ns.EncodeRun("fixture_shore", 20, 10, "r")
			end)
			assert.has_error(function()
				ns.EncodeRun("fixture_shore", 10, 20, "q")
			end)
		end)
	end)

	describe("def (HNT-R154)", function()
		it("reads <eventID>|<part>/<parts>|<text>, the text keeping any |", function()
			assert.are.same(
				{ event = "p_tide", part = 2, parts = 3, text = 'name="a|b",' },
				ns.DecodeDef('p_tide|2/3|name="a|b",')
			)
			for _, payload in ipairs({ "p_tide|0/3|x", "p_tide|4/3|x", "p_tide|1/3|", "p_tide|1|x", "p_tide|1/03|x" }) do
				assert.is_nil(ns.DecodeDef(payload))
			end
		end)

		-- The largest definition hunts.md › Contracts allows: 5 Hunts, each with conditions of every LOG-R48 field it
		-- may hold, a minBand and long names, and a long note, with a Latin-1 character in its name (CORE-R9).
		local function largest()
			local hunts5 = {}
			for i = 1, 5 do
				hunts5[i] = {
					id = "p_hallows_hollow_tide_hunt_" .. i,
					name = "The Hollow Tide's Long Hunt " .. i,
					class = "species.any",
					minBand = 3,
					conditions = {
						time = { { 1260, 240 }, { 300, 480 } },
						season = { { from = { 10, 18 }, to = { 11, 1 } } },
						events = { 301, 324 },
						auras = { 1280341 },
						lure = { 263, 264 },
						skill = { min = 150 },
					},
					tiers = { 20, 50, 100 },
				}
			end
			return {
				kind = "huntEvent",
				v = 1,
				id = "p_hallows_hollow_tide",
				zones = { C.DARKSHORE, C.ELWYNN },
				tags = { "hallows_end", "night", "coast", "low" },
				skill = { 75, 150 },
				rotation = false,
				name = "Hollow Tide · Hallow's End",
				note = string.rep("The bobbers bob under a hollow moon; mind the tide and the lanterns. ", 4),
				hunts = hunts5,
			}
		end

		it("splits the largest definition into parts under 200 bytes, and puts it back together", function()
			local item = largest()
			local text = assert(ns.WriteContentItem(item))

			local payloads = ns.EncodeDefParts(item.id, text)

			assert.is_true(#payloads > 5)
			local texts = {}
			for part, payload in ipairs(payloads) do
				assert.is_true(#payload <= 200)
				local def = assert(ns.DecodeDef(payload))
				assert.are.same({ item.id, part, #payloads }, { def.event, def.part, def.parts })
				texts[part] = def.text
			end
			assert.are.equal(text, table.concat(texts))
			assert.are.same(item, ns.ReadContentItem(table.concat(texts)))
		end)

		it("never cuts a part inside a UTF-8 character", function()
			-- A name of two-byte characters only, so some cut lands next to one.
			local text = '{kind="huntEvent",v=1,name="' .. string.rep("·", 400) .. '",}'
			for _, payload in ipairs(ns.EncodeDefParts("p_dots", text)) do
				local partText = ns.DecodeDef(payload).text
				assert.is_nil(partText:find("^[\128-\191]"))
				assert.is_nil(partText:find("[\194-\244]$"))
			end
		end)

		it("fits every part through M:AppendRecord, which checks LOG-R40's limit", function()
			local item = largest()
			local appended = {}
			local loaded = hunts.login()
			for _, payload in ipairs(ns.EncodeDefParts(item.id, assert(ns.WriteContentItem(item)))) do
				appended[#appended + 1] = loaded.ns.Module:AppendRecord("def", payload)
			end

			-- Folded back by the projection (HNT-R154): its parts kept by event ID, and the definition known.
			local state = loaded.ns.State()
			assert.are.equal(#appended, state.defs[item.id].parts)
			assert.are.equal("p_hallows_hollow_tide", loaded.ns.KnownEvent(state, item.id).id)
		end)

		it("keeps the first record of each part, and skips a part whose count of parts differs", function()
			local state = ns.NewHuntsState()
			assert.is_true(ns.AddDefPart(state, ns.DecodeDef("p_tide|1/2|first")))
			assert.is_false(ns.AddDefPart(state, ns.DecodeDef("p_tide|1/2|again")))
			assert.is_false(ns.AddDefPart(state, ns.DecodeDef("p_tide|2/3|other")))
			assert.are.same({ parts = 2, texts = { "first" } }, state.defs.p_tide)
			-- A part for a pool event is no pushed definition (HNT-R140).
			assert.is_false(ns.AddDefPart(state, ns.DecodeDef("fixture_shore|1/1|x")))
		end)
	end)
end)
