-- How a goal's progress moves, one Catch at a time (tackle-board.md › Progress, TKB-R40–R46, TKB-R104, TKB-R196):
-- which Catches each kind counts, the session-bound reset, the need and stranded goals, completion and the displayed
-- progress. Over the fixture catalogue (spec/Pagle_TackleBoard/fixtures/Catalogue.lua) through FakePagle's catalogue
-- calls, with hand-built goals (tackle-board.md › Projection: TackleGoal) and Cast records (LOG-R42, LOG-R98).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Zones of the fixture (its header lists what each is for).
local DUROTAR, BARRENS, DARKSHORE, ASHENVALE, ELWYNN, WESTFALL = 14, 17, 148, 331, 12, 40
local THOUSAND_NEEDLES = 400
local KALIMDOR, EASTERN_KINGDOMS = 1, 0

-- Items of the fixture.
local SMALLFISH, MACKEREL, MUD_SNAPPER, CATFISH, BLACKMOUTH = 6291, 6303, 6289, 6308, 6358
local MIGHTFISH, LARGE_MIGHTFISH, GROUPER, BASS, EEL = 13754, 13893, 12238, 13756, 13757
local LEGEND, QUEST_FISH, REMOVED_FISH, MANA_POTION = 92001, 92002, 92003, 2455
local JUNK_A, JUNK_B, NOISY_JUNK = 92011, 92012, 92013
local CONTAINER_A, CONTAINER_B, REMOVED_CONTAINER = 92021, 92022, 92023
local TREASURE_A, TREASURE_B, TROPHY_A = 92031, 92032, 92041
local UNCHARTED = 999999 -- no catalogue record (LOG-R55)

-- Size bands (LOG-R65): 3 Hefty, 4 Whopper, 5 Monster.
local HEFTY, WHOPPER, MONSTER = 3, 4, 5

local GOAL_SEQ = 100 -- the seq of the record that issued every goal here

describe("Goal progress", function()
	local loaded = board.load()
	local ns = loaded.ns
	local Pagle = loaded.env.Pagle

	-- A goal (TackleGoal) issued at GOAL_SEQ with no progress: `fields` gives its type, kind, need and target or items.
	local function goal(fields)
		local made = {
			id = "Player-4618-0A1B2C3D-1791731747-0",
			seq = GOAL_SEQ,
			type = "n",
			tier = 1,
			pay = 10,
			reposted = false,
			issuedDay = 1,
			time = 1791731747,
			progress = 0,
			seen = {},
		}
		for key, value in pairs(fields) do
			made[key] = value
		end
		return made
	end

	-- A caught Cast record (LOG-R42) after the goal, in `zone`, in Session "S1", with one Catch per entry of
	-- `catches`: an item ID, or `{ itemID, band }` for a Catch with a Simulated Size of that band (LOG-R65). Every
	-- Catch is a stack of 3, to show quantity never matters (TKB-R40). `options` sets `seq`, `outcome`, `session`
	-- and `lure`.
	local seq = GOAL_SEQ
	local function cast(zone, catches, options)
		options = options or {}
		seq = seq + 1
		local id = ("Player-4618-0A1B2C3D-%d-0"):format(1791732000 + seq)
		local items = {}
		for n, catch in ipairs(catches) do
			local itemID, band = catch, nil
			if type(catch) == "table" then
				itemID, band = catch[1], catch[2]
			end
			items[n] = {
				n = n,
				itemID = itemID,
				quantity = 3,
				catchId = id .. ":" .. n,
				size = band and { length = 400, band = band } or nil,
			}
		end
		return {
			seq = options.seq or seq,
			id = id,
			kind = "cast",
			char = 1,
			time = 1791732000 + seq,
			outcome = options.outcome or "caught",
			session = options.session or "S1",
			conditions = { time = 1791732000 + seq, minute = 500, zone = zone, subzone = 0, lure = options.lure },
			items = items, -- kept on a got-away Cast too (Core's has none), so the spec sees CountCatch refuse them

		}
	end

	-- Runs `casts` through `goal` as the completions' ticket does (TKB-R41, TKB-R45, TKB-R46): EnterCast once per
	-- Cast, then CountCatch for each Catch in item order, adding each Catch's item to the ever-caught set after
	-- counting it. `caught` is the ever-caught set before the first Cast. Returns the goal's progress and, per Catch,
	-- whether it counted.
	local function run(subject, casts, caught)
		caught = caught or {}
		local ctx = {
			pagle = Pagle,
			caughtBefore = function(itemID)
				return caught[itemID] == true
			end,
		}
		local counted = {}
		for _, record in ipairs(casts) do
			ns.EnterCast(subject, record)
			for _, slot in ipairs(record.items) do
				counted[#counted + 1] = ns.CountCatch(subject, record, slot, ctx)
				caught[slot.itemID] = true
			end
		end
		return subject.progress, counted
	end

	describe("haul", function()
		it("counts +1 per Catch in the zone, whatever its quantity, Noise and Uncharted included (TKB-R40, TKB-R42, TKB-R43)", function()
			local haul = goal({ kind = "haul", need = 20, target = DUROTAR })

			local progress, counted = run(haul, {
				cast(DUROTAR, { SMALLFISH, MANA_POTION }),
				cast(DUROTAR, { UNCHARTED, 0 }),
			})

			assert.are.equal(4, progress)
			assert.are.same({ true, true, true, true }, counted)
		end)

		it("ignores Catches in another zone, in zone 0, of got-away Casts and from before the goal (TKB-R40, TKB-R42)", function()
			local haul = goal({ kind = "haul", need = 20, target = DUROTAR })

			local progress = run(haul, {
				cast(BARRENS, { SMALLFISH }),
				cast(0, { SMALLFISH }),
				cast(DUROTAR, { SMALLFISH }, { outcome = "gotAway" }),
				cast(DUROTAR, { SMALLFISH }, { seq = GOAL_SEQ }),
				cast(DUROTAR, { SMALLFISH }, { seq = GOAL_SEQ - 1 }),
			})

			assert.are.equal(0, progress)
		end)
	end)

	describe("variety", function()
		it("as a Notice counts distinct Species in the zone, gated, quest fish and Legends included (TKB-R42)", function()
			local variety = goal({ kind = "variety", need = 5, target = DUROTAR })

			local progress, counted = run(variety, {
				cast(DUROTAR, { SMALLFISH, SMALLFISH, MACKEREL }),
				cast(DUROTAR, { BASS, QUEST_FISH, LEGEND }),
			})

			assert.are.equal(5, progress)
			assert.are.same({ true, false, true, true, true, true }, counted)
		end)

		it("as a Notice counts no Noise, item without a Species, Uncharted item or item 0 (TKB-R42, TKB-R43)", function()
			local variety = goal({ kind = "variety", need = 5, target = DUROTAR })

			local progress = run(variety, {
				cast(DUROTAR, { MANA_POTION, JUNK_A, CONTAINER_A, UNCHARTED, 0 }),
				cast(BARRENS, { CATFISH }),
			})

			assert.are.equal(0, progress)
		end)

		it("as an Expedition counts distinct stored Species caught in the zone, any item of the Species (TKB-R42)", function()
			-- Darkshore's five eligible Species, by representative item (Mightfish's is 13754, from Auberdine).
			local variety = goal({
				type = "e",
				kind = "variety",
				need = 5,
				target = DARKSHORE,
				items = { SMALLFISH, MACKEREL, BLACKMOUTH, GROUPER, MIGHTFISH },
			})

			local progress, counted = run(variety, {
				cast(DARKSHORE, { LARGE_MIGHTFISH, MIGHTFISH, SMALLFISH }),
				cast(DARKSHORE, { LEGEND, CATFISH, UNCHARTED, 0 }),
				cast(BARRENS, { MACKEREL, BLACKMOUTH }),
			})

			assert.are.equal(2, progress)
			assert.are.same({ true, false, true, false, false, false, false, false, false }, counted)
		end)
	end)

	describe("wanderer", function()
		it("as a Notice counts distinct zones but 0 in the Session, any Catch, Noise and Uncharted too (TKB-R42, TKB-R43)", function()
			local wanderer = goal({ kind = "wanderer", tier = 3, need = 3 })

			local progress, counted = run(wanderer, {
				cast(DUROTAR, { UNCHARTED, 0 }),
				cast(0, { SMALLFISH }),
				cast(BARRENS, { MANA_POTION }),
			})

			assert.are.equal(2, progress)
			assert.are.same({ true, false, false, true }, counted)
		end)

		it("as a Notice at 2 of 3 resets to 0 on a Cast from a new Session, then counts its zone (TKB-R41)", function()
			local wanderer = goal({ kind = "wanderer", tier = 3, need = 3 })
			run(wanderer, { cast(DUROTAR, { SMALLFISH }), cast(BARRENS, { SMALLFISH }) })
			assert.are.equal(2, wanderer.progress)

			local progress = run(wanderer, { cast(DUROTAR, { SMALLFISH }, { session = "S2" }) })

			assert.are.equal(1, progress)
			assert.are.equal("S2", wanderer.session)
			assert.are.same({ [DUROTAR] = true }, wanderer.seen)
		end)

		it("as a Notice resets on a new Session's Cast even when none of its Catches counts (TKB-R41)", function()
			local wanderer = goal({ kind = "wanderer", tier = 3, need = 3 })
			run(wanderer, { cast(DUROTAR, { SMALLFISH }), cast(BARRENS, { SMALLFISH }) })

			local progress = run(wanderer, { cast(0, { SMALLFISH }, { session = "S2" }) })

			assert.are.equal(0, progress)
			assert.are.equal("S2", wanderer.session)
		end)

		it("as a Notice isn't reset by a got-away Cast or one from before the goal (TKB-R40, TKB-R41)", function()
			local wanderer = goal({ kind = "wanderer", tier = 3, need = 3 })
			run(wanderer, { cast(DUROTAR, { SMALLFISH }), cast(BARRENS, { SMALLFISH }) })

			local progress = run(wanderer, {
				cast(DARKSHORE, {}, { session = "S2", outcome = "gotAway" }),
				cast(DARKSHORE, { SMALLFISH }, { session = "S0", seq = GOAL_SEQ - 1 }),
			})

			assert.are.equal(2, progress)
			assert.are.equal("S1", wanderer.session)
		end)

		it("as an Expedition counts distinct zones on the continent, across Sessions (TKB-R42)", function()
			local wanderer = goal({ type = "e", kind = "wanderer", tier = 0, need = 5, target = KALIMDOR })

			local progress, counted = run(wanderer, {
				cast(DUROTAR, { UNCHARTED, SMALLFISH }),
				cast(BARRENS, { 0 }, { session = "S2" }),
				cast(ELWYNN, { SMALLFISH }),
				cast(0, { SMALLFISH }),
				cast(DARKSHORE, { MANA_POTION }, { session = "S3" }),
			})

			assert.are.equal(3, progress)
			assert.are.same({ true, false, true, false, false, true }, counted)
		end)
	end)

	describe("quality", function()
		it("counts +1 per Catch of the target quality or better, any category, any zone (TKB-R42)", function()
			local quality = goal({ kind = "quality", need = 8, target = 2 })

			local progress, counted = run(quality, {
				cast(DUROTAR, { EEL, EEL, SMALLFISH, CONTAINER_B }),
				cast(0, { LEGEND, JUNK_A, TREASURE_B }),
			})

			assert.are.equal(5, progress)
			assert.are.same({ true, true, false, true, true, false, true }, counted)
		end)

		it("at rare counts quality 3 or better only, never an Uncharted item or item 0 (TKB-R42, TKB-R43)", function()
			local quality = goal({ type = "e", kind = "quality", tier = 0, need = 3, target = 3 })

			local progress = run(quality, { cast(DARKSHORE, { EEL, TREASURE_B, LEGEND, UNCHARTED, 0 }) })

			assert.are.equal(2, progress)
		end)
	end)

	describe("size", function()
		it("counts +1 per Catch whose Size band is the target or better: a Monster counts for Hefty (TKB-R42)", function()
			local size = goal({ kind = "size", need = 10, target = HEFTY })

			local progress, counted = run(size, {
				cast(DUROTAR, { { SMALLFISH, HEFTY }, { SMALLFISH, 2 }, { MACKEREL, MONSTER }, { SMALLFISH, WHOPPER } }),
				cast(0, { TROPHY_A, { LEGEND, HEFTY }, { UNCHARTED, MONSTER }, { 0, MONSTER } }),
			})

			assert.are.equal(4, progress)
			assert.are.same({ true, false, true, true, false, true, false, false }, counted)
		end)

		it("at Whopper counts Whopper or Monster, not Hefty (TKB-R42)", function()
			local size = goal({ type = "e", kind = "size", tier = 0, need = 1, target = WHOPPER })

			local _, counted = run(size, { cast(BARRENS, { { SMALLFISH, HEFTY }, { SMALLFISH, WHOPPER } }) })

			assert.are.same({ false, true }, counted)
		end)
	end)

	describe("lure", function()
		it("counts +1 per Catch of a Cast with a lure on, any item and zone (TKB-R42, TKB-R43)", function()
			local lure = goal({ kind = "lure", need = 15 })

			local progress, counted = run(lure, {
				cast(DUROTAR, { SMALLFISH, UNCHARTED, 0, MANA_POTION }, { lure = 263 }),
				cast(0, { SMALLFISH }, { lure = 264 }),
				cast(DUROTAR, { SMALLFISH, JUNK_A }),
				cast(DUROTAR, { SMALLFISH }, { lure = 0 }),
			})

			assert.are.equal(5, progress)
			assert.are.same({ true, true, true, true, true, false, false, false }, counted)
		end)
	end)

	describe("species", function()
		it("counts +1 per Catch of the representative item's Species, in any zone (TKB-R42)", function()
			local species = goal({ kind = "species", need = 5, target = MIGHTFISH })

			local progress, counted = run(species, {
				cast(BARRENS, { LARGE_MIGHTFISH, MIGHTFISH, SMALLFISH }),
				cast(0, { LARGE_MIGHTFISH, UNCHARTED, 0 }),
			})

			assert.are.equal(3, progress)
			assert.are.same({ true, true, false, true, false, false }, counted)
		end)
	end)

	describe("collector", function()
		it("as a Notice counts a junk item and a container, not Noise or other categories (TKB-R42, TKB-R43)", function()
			local collector = goal({ kind = "collector", tier = 2, need = 2 })

			local progress, counted = run(collector, {
				cast(DUROTAR, { NOISY_JUNK, TREASURE_A, UNCHARTED, 0, JUNK_A, JUNK_B }),
				cast(BARRENS, { CONTAINER_A }),
			})

			assert.are.equal(2, progress)
			assert.are.same({ false, false, false, false, true, false, true }, counted)
		end)

		it("as a Notice needs its junk item and container in one Session (TKB-R41)", function()
			local collector = goal({ kind = "collector", tier = 2, need = 2 })

			local progress = run(collector, {
				cast(DUROTAR, { JUNK_A }),
				cast(ELWYNN, { CONTAINER_A }, { session = "S2" }),
			})

			assert.are.equal(1, progress)
			assert.are.same({ container = true }, collector.seen)
		end)

		it("as an Expedition counts distinct Sub-collection items never caught before this Catch (TKB-R42, TKB-R46)", function()
			local collector = goal({ type = "e", kind = "collector", tier = 0, need = 3 })

			local progress, counted = run(collector, {
				cast(THOUSAND_NEEDLES, { TREASURE_A, JUNK_A, JUNK_A, CONTAINER_B }),
				cast(ASHENVALE, { REMOVED_CONTAINER, NOISY_JUNK, SMALLFISH, UNCHARTED, 0 }),
			}, { [TREASURE_A] = true })

			assert.are.equal(2, progress)
			assert.are.same({ false, true, false, true, false, false, false, false, false }, counted)
		end)

		it("as an Expedition counts treasure and trophies too (TKB-R46)", function()
			local collector = goal({ type = "e", kind = "collector", tier = 0, need = 3 })

			local progress = run(collector, { cast(DARKSHORE, { TREASURE_B, TROPHY_A, CONTAINER_A }) })

			assert.are.equal(3, progress)
		end)
	end)

	describe("completion", function()
		it("comes at the Catch that brings progress to the need; later Catches don't count (TKB-R45)", function()
			local haul = goal({ kind = "haul", need = 2, target = DUROTAR })
			run(haul, { cast(DUROTAR, { SMALLFISH }) })
			assert.is_false(ns.IsComplete(haul, Pagle))

			local progress, counted = run(haul, { cast(DUROTAR, { SMALLFISH, MACKEREL }), cast(DUROTAR, { SMALLFISH }) })

			assert.are.equal(2, progress)
			assert.are.same({ true, false, false }, counted)
			assert.is_true(ns.IsComplete(haul, Pagle))
		end)

		it("can come for two goals on the same Catch, each counting it in board order (TKB-R45)", function()
			local haul = goal({ kind = "haul", need = 1, target = DUROTAR })
			local lure = goal({ kind = "lure", need = 1 })
			local ctx = {
				pagle = Pagle,
				caughtBefore = function()
					return false
				end,
			}
			local record = cast(DUROTAR, { SMALLFISH, MACKEREL }, { lure = 263 })
			local completed = {}

			for _, slot in ipairs(record.items) do
				for _, subject in ipairs({ haul, lure }) do
					if not ns.IsComplete(subject, Pagle) then
						ns.EnterCast(subject, record)
						if ns.CountCatch(subject, record, slot, ctx) and ns.IsComplete(subject, Pagle) then
							completed[#completed + 1] = subject.kind .. "@" .. slot.n
						end
					end
				end
			end

			assert.are.same({ "haul@1", "lure@1" }, completed)
		end)

		it("keeps a complete session-bound goal's progress through a new Session (TKB-R41, TKB-R45)", function()
			local wanderer = goal({ kind = "wanderer", tier = 3, need = 3 })
			run(wanderer, { cast(DUROTAR, { SMALLFISH }), cast(BARRENS, { SMALLFISH }), cast(ASHENVALE, { SMALLFISH }) })

			local progress = run(wanderer, { cast(DARKSHORE, { SMALLFISH }, { session = "S2" }) })

			assert.are.equal(3, progress)
			assert.are.equal("S1", wanderer.session)
			assert.is_true(ns.IsComplete(wanderer, Pagle))
		end)

		it("needs the record's need, for every goal but a Variety Expedition (TKB-R34, TKB-R44)", function()
			assert.are.equal(30, ns.GoalNeed(goal({ kind = "haul", need = 30, target = DUROTAR }), Pagle))
			assert.are.equal(3, ns.GoalNeed(goal({ kind = "variety", need = 3, target = DUROTAR }), Pagle))
			assert.are.equal(1, ns.GoalNeed(goal({ type = "e", kind = "size", need = 1, target = WHOPPER }), Pagle))
		end)
	end)
end)
