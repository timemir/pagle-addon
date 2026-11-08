-- Hunts' moments marked for the player's party (announcements.md ANN-R104, from 1.5.2, #640): the moment of a Hunt's
-- first gold tier, as the adapter wraps logic's ns.HuntTierMoment, carries `party = "gold"` and the Hunt's ID, and no
-- other tier does; Hunts' def names a Hunt by its ID for a groupmate's toast (ANN-R106). From 1.6 (#646): a live Party
-- Catch's moments name the groupmate and merge by its entry ID, and a Hunt completed or a run settled through one
-- carries the source Catch ID Core shares as "Completed for the party" (HNT-R185, ANN-R110, ANN-R111).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- A Hunt of the fixture list with three tiers or more.
local function threeTiered(loaded)
	for _, hunt in ipairs(loaded.ns.hunts:Hunts()) do
		if #hunt.tiers >= 3 then
			return hunt
		end
	end
	error("no Hunt with three tiers in the fixture list")
end

describe("Hunts' party moments (ANN-R104)", function()
	it("mark the gold tier's moment with its Hunt, and not bronze or silver, and say what it says as before", function()
		local loaded = hunts.login(nil, {})
		local hunt = threeTiered(loaded)
		local marks = {}
		for k = 1, 3 do
			local moment = loaded.ns.HuntTierMoment(hunt, k, { itemID = 6303 })
			marks[k] = { tostring(moment.party), tostring(moment.partyHunt), moment.stamp }
		end
		local L = loaded.ns.L
		assert.are.same({
			{ "nil", "nil", L.HUNT_COMPLETE_STAMP },
			{ "nil", "nil", L.TRIMS.silver },
			{ "gold", hunt.id, L.TRIMS.gold },
		}, marks)
	end)

	it("name a Hunt it knows by its ID through its def, and nothing for one it doesn't (ANN-R106)", function()
		local loaded, fake = hunts.login(nil, {})
		local hunt = threeTiered(loaded)
		local def = fake.registry:ModuleOf(loaded.ns.Module).def
		assert(def.partyHuntName, "Hunts' def has no partyHuntName")
		assert.are.equal(loaded.ns.hunts:HuntName(hunt.id), def.partyHuntName(hunt.id))
		assert.is_nil(def.partyHuntName("no_such_hunt"))
	end)
end)

describe("a live Party Catch's moments (HNT-R185, ANN-R110)", function()
	-- The Party Catch's entry ID (the receiver's own, LOG-R115) and the groupmate's Cast entry ID (LOG-R116).
	local G1 = "Player-1-00000001-1791731700-0"
	local SOURCE = "Player-4701-0A1B2C3D-1791731690-0"

	-- The live Party Catch record (LOG-R116), with `fields` over it; `name` and `sourceId` false to leave them out, as
	-- a replayed or rebuilt record has neither.
	local function partyCatch(fields)
		local record = { kind = "party", id = G1, catchTime = 1791731690, name = "Kukli Emnabi", sourceId = SOURCE }
		for key, value in pairs(fields or {}) do
			record[key] = value or nil
		end
		return record
	end

	-- A tier reached by the item of `catchId` (HNT-R181).
	local function tier(catchId)
		return {
			time = 1791731690,
			catchId = catchId,
			itemID = 6303,
			zone = 148,
			date = { year = 2026, month = 10, day = 12 },
			party = true,
		}
	end

	local function nothing()
		return { tiers = {}, sets = {}, marks = {}, settled = {}, ladder = {} }
	end

	local function celebrated()
		return { tiers = {}, sets = {}, runs = {}, ladder = {} }
	end

	it("name the groupmate after their text and carry the Party Catch's entry ID, so Core merges them", function()
		local loaded = hunts.login(nil, {})
		local ns = loaded.ns
		local hunt = threeTiered(loaded)
		local state = ns.NewHuntsState()
		state.hunts[hunt.id] = { count = 1, effort = 0, sinceLast = 0, caught = true, reached = { tier(G1 .. ":2") } }
		local reached = nothing()
		reached.tiers = { { hunt = hunt.id, tier = 1 } }
		local moments = ns.CelebrateReached(celebrated(), state, partyCatch(), reached)
		assert.are.equal(1, #moments)
		local moment = moments[1]
		assert.are.equal("huntCompleted", moment.kind)
		assert.are.equal(G1, moment.cast)
		assert.are.equal(ns.hunts:HuntName(hunt.id) .. " · with Kukli Emnabi", moment.text)
		-- What Core stores names no one (ANN-R110).
		assert.are.equal(ns.hunts:HuntName(hunt.id) .. " · with a groupmate", moment.storedText)
		-- The item that reached it is item 2 of the Party Catch: the groupmate's Catch 2 (ANN-R111).
		assert.are.equal(SOURCE .. ":2", moment.partyCatch)
		assert.are.equal(hunt.id, moment.partyHunt)
	end)

	it("carry no partyCatch on a further tier, which isn't a Hunt completed, but still name the groupmate", function()
		local loaded = hunts.login(nil, {})
		local ns = loaded.ns
		local hunt = threeTiered(loaded)
		local state = ns.NewHuntsState()
		state.hunts[hunt.id] = {
			count = 9,
			effort = 0,
			sinceLast = 0,
			caught = true,
			reached = { tier("Player-1-00000001-1791731000-0:1"), tier(G1 .. ":1") },
		}
		local reached = nothing()
		reached.tiers = { { hunt = hunt.id, tier = 2 } }
		local done = celebrated()
		done.tiers[hunt.id] = 1
		local moment = ns.CelebrateReached(done, state, partyCatch(), reached)[1]
		assert.are.equal("huntTier", moment.kind)
		assert.matches(" · with Kukli Emnabi$", moment.text)
		assert.is_nil(moment.partyCatch)
	end)

	it("carry the item's source Catch and the event's ID on a settled run, and name the groupmate on a mark", function()
		local loaded = hunts.login(nil, {})
		local ns = loaded.ns
		local state = ns.NewHuntsState()
		local key = "fixture_shore@1791700000"
		local own = "Player-1-00000001-1791720000-0:1"
		state.runs[key] = {
			event = "fixture_shore",
			start = 1791700000,
			end_ = 1791700000 + 72 * 3600,
			source = "r",
			completedAt = 1791731690,
			hunts = {
				fixture_shore_haul = { count = 2, effort = 0, sinceLast = 0, caught = true, reached = { tier(own) } },
				fixture_shore_snapper = { count = 1, effort = 0, sinceLast = 0, caught = true, reached = { tier(own) } },
				fixture_shore_oddity = {
					count = 1,
					effort = 0,
					sinceLast = 0,
					caught = true,
					reached = { tier(G1 .. ":3") },
				},
			},
		}
		local reached = nothing()
		reached.marks = { { run = key, hunt = "fixture_shore_oddity", tier = 1 } }
		reached.settled = { key }
		local moments = ns.CelebrateReached(celebrated(), state, partyCatch(), reached)
		assert.are.equal(2, #moments)
		local mark, settled = moments[1], moments[2]
		assert.are.same({ "wagerMark", G1 }, { mark.kind, mark.cast })
		assert.matches(" · with Kukli Emnabi$", mark.text)
		assert.matches(" · with a groupmate$", mark.storedText)
		assert.is_nil(mark.partyCatch)
		assert.are.same({ "wagerSettled", G1 }, { settled.kind, settled.cast })
		assert.are.equal(ns.events:EventName(ns.events:Event("fixture_shore")) .. " · with Kukli Emnabi", settled.text)
		assert.are.equal(
			ns.events:EventName(ns.events:Event("fixture_shore")) .. " · with a groupmate",
			settled.storedText
		)
		assert.are.equal(SOURCE .. ":3", settled.partyCatch)
		assert.are.equal("fixture_shore", settled.partyEvent)
	end)

	it("add nothing for a record with no name or source ID: only the live record carries them (LOG-R116)", function()
		local loaded = hunts.login(nil, {})
		local ns = loaded.ns
		local hunt = threeTiered(loaded)
		local state = ns.NewHuntsState()
		state.hunts[hunt.id] = { count = 1, effort = 0, sinceLast = 0, caught = true, reached = { tier(G1 .. ":1") } }
		local reached = nothing()
		reached.tiers = { { hunt = hunt.id, tier = 1 } }
		local moment =
			ns.CelebrateReached(celebrated(), state, partyCatch({ name = false, sourceId = false }), reached)[1]
		assert.are.equal(ns.hunts:HuntName(hunt.id), moment.text)
		assert.is_nil(moment.partyCatch)
		assert.is_nil(moment.partyHunt)
		assert.are.equal(G1, moment.cast)
	end)

	it("leave the Angler's own Cast's moments as they were: no name, no partyCatch", function()
		local loaded = hunts.login(nil, {})
		local ns = loaded.ns
		local hunt = threeTiered(loaded)
		local state = ns.NewHuntsState()
		local castID = "Player-1-00000001-1791731000-0"
		state.hunts[hunt.id] =
			{ count = 1, effort = 0, sinceLast = 0, caught = true, reached = { tier(castID .. ":1") } }
		local reached = nothing()
		reached.tiers = { { hunt = hunt.id, tier = 1 } }
		local moment = ns.CelebrateReached(celebrated(), state, { kind = "cast", id = castID }, reached)[1]
		assert.are.equal(ns.hunts:HuntName(hunt.id), moment.text)
		assert.is_nil(moment.partyCatch)
		assert.is_nil(moment.partyHunt)
	end)

	it("name an event it knows by its ID through its def, and nothing for one it doesn't (ANN-R111)", function()
		local loaded, fake = hunts.login(nil, {})
		local def = fake.registry:ModuleOf(loaded.ns.Module).def
		assert(def.partyEventName, "Hunts' def has no partyEventName")
		assert.are.equal(
			loaded.ns.events:EventName(loaded.ns.events:Event("fixture_shore")),
			def.partyEventName("fixture_shore")
		)
		assert.is_nil(def.partyEventName("p_never_logged"))
	end)
end)
