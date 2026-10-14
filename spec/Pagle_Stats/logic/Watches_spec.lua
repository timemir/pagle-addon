-- Watched Dry spells (STA-R60–R63; stats.md › Tunables › Watches) on FakePagle: ns.Watch, ns.StopWatching and
-- ns.IsWatched over PagleStatsDB.profile, the cap and its UI error, turning the live tracker on, and the "watches"
-- redraw after each change.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, ELWYNN = 148, 442, 12
local NIGHTFIN, FIREFIN, BASS, MUD_SNAPPER = 13759, 6359, 13756, 6289

local FULL = "You can watch up to 3 Dry spells. Stop watching one first."
local TURNED_ON = "Pagle: live tracker turned on to show your watched Dry spells."

-- Stats on a new FakePagle, with the redraws it asks for counted by reason.
local function load()
	local loaded = stats.load()
	local redraws = {}
	loaded.ns.OnRedraw(function(reason)
		redraws[#redraws + 1] = reason
	end)
	return loaded, redraws
end

-- The watches as "item@area", oldest first.
local function watches(ns)
	local out = {}
	for i, watch in ipairs(ns.db.profile.watched) do
		out[i] = ("%d@%d"):format(watch.item, watch.area)
	end
	return out
end

describe("Watched Dry spells", function()
	it("keeps up to 3 watches oldest first, one item in two places among them (STA-R60)", function()
		local loaded = load()
		local ns = loaded.ns

		assert.is_true(ns.Watch(NIGHTFIN, DARKSHORE))
		assert.is_true(ns.Watch(FIREFIN, AUBERDINE))
		assert.is_true(ns.Watch(NIGHTFIN, ELWYNN))

		assert.are.same({ "13759@148", "6359@442", "13759@12" }, watches(ns))
		assert.is_true(ns.IsWatched(NIGHTFIN, DARKSHORE))
		assert.is_true(ns.IsWatched(NIGHTFIN, ELWYNN))
		assert.is_false(ns.IsWatched(NIGHTFIN, AUBERDINE))
		assert.is_false(ns.IsWatched(FIREFIN, DARKSHORE))
	end)

	it("refuses a 4th: nothing changes and the red UI error shows (STA-R61, Tunables › Watches)", function()
		local loaded, redraws = load()
		local ns = loaded.ns
		ns.Watch(NIGHTFIN, DARKSHORE)
		ns.Watch(FIREFIN, AUBERDINE)
		ns.Watch(NIGHTFIN, ELWYNN)
		local drawn = #redraws

		assert.is_false(ns.Watch(BASS, ELWYNN))

		assert.are.same({ "13759@148", "6359@442", "13759@12" }, watches(ns))
		assert.is_false(ns.IsWatched(BASS, ELWYNN))
		assert.are.equal(drawn, #redraws)
		assert.are.same({ { text = FULL, r = 1, g = 0.1, b = 0.1 } }, loaded.client.uiErrors)
	end)

	it("counts its cap from ns.MAX_WATCHES, 3 (stats.md › Tunables › Watches)", function()
		assert.are.equal(3, stats.load().ns.MAX_WATCHES)
	end)

	it("watching what is already watched changes nothing and shows no error (STA-R60)", function()
		local loaded, redraws = load()
		local ns = loaded.ns
		ns.Watch(NIGHTFIN, DARKSHORE)
		local drawn = #redraws

		assert.is_true(ns.Watch(NIGHTFIN, DARKSHORE))

		assert.are.same({ "13759@148" }, watches(ns))
		assert.are.equal(drawn, #redraws)
		assert.are.same({}, loaded.client.uiErrors)
	end)

	it("a full list still answers a watch already on it, without the error (STA-R61)", function()
		local loaded = load()
		local ns = loaded.ns
		ns.Watch(NIGHTFIN, DARKSHORE)
		ns.Watch(FIREFIN, AUBERDINE)
		ns.Watch(NIGHTFIN, ELWYNN)

		assert.is_true(ns.Watch(FIREFIN, AUBERDINE))
		assert.are.same({}, loaded.client.uiErrors)
	end)

	it("stops a watch, keeping the others in order, and frees its place (STA-R60, STA-R61)", function()
		local loaded = load()
		local ns = loaded.ns
		ns.Watch(NIGHTFIN, DARKSHORE)
		ns.Watch(FIREFIN, AUBERDINE)
		ns.Watch(NIGHTFIN, ELWYNN)

		ns.StopWatching(FIREFIN, AUBERDINE)

		assert.are.same({ "13759@148", "13759@12" }, watches(ns))
		assert.is_true(ns.Watch(MUD_SNAPPER, ELWYNN))
		assert.are.same({ "13759@148", "13759@12", "6289@12" }, watches(ns))
		assert.are.same({}, loaded.client.uiErrors)
	end)

	it("stopping a watch it doesn't have changes nothing (STA-R63)", function()
		local loaded, redraws = load()
		local ns = loaded.ns
		ns.Watch(NIGHTFIN, DARKSHORE)
		local drawn = #redraws

		ns.StopWatching(NIGHTFIN, ELWYNN)

		assert.are.same({ "13759@148" }, watches(ns))
		assert.are.equal(drawn, #redraws)
	end)

	it("asks every view to redraw for \"watches\" after each change (STA-R60, Seams)", function()
		local loaded, redraws = load()
		local ns = loaded.ns

		ns.Watch(NIGHTFIN, DARKSHORE)
		ns.StopWatching(NIGHTFIN, DARKSHORE)

		assert.are.same({ "watches", "watches" }, redraws)
	end)

	it("keeps a watch whose item the catalogue no longer lists in that place (STA-R60)", function()
		local loaded = load()
		local ns = loaded.ns
		ns.db.profile.watched = { { item = 90001, area = DARKSHORE } }

		assert.is_true(ns.IsWatched(90001, DARKSHORE))
		assert.is_true(ns.Watch(NIGHTFIN, DARKSHORE))
		assert.are.same({ "90001@148", "13759@148" }, watches(ns))
	end)

	describe("and the live tracker", function()
		it("watching while it is off turns it on, with exactly one chat line (STA-R62)", function()
			local loaded = load()
			local ns = loaded.ns
			assert.is_false(ns.db.profile.tracker)

			ns.Watch(NIGHTFIN, DARKSHORE)
			ns.Watch(FIREFIN, AUBERDINE)

			assert.is_true(ns.db.profile.tracker)
			assert.are.same({ TURNED_ON }, loaded.printed)
		end)

		it("watching while it is on prints nothing (STA-R62)", function()
			local loaded = load()
			local ns = loaded.ns
			ns.db.profile.tracker = true

			ns.Watch(NIGHTFIN, DARKSHORE)

			assert.are.same({}, loaded.printed)
		end)

		it("a refused 4th doesn't turn it on (STA-R61, STA-R62)", function()
			local loaded = load()
			local ns = loaded.ns
			ns.Watch(NIGHTFIN, DARKSHORE)
			ns.Watch(FIREFIN, AUBERDINE)
			ns.Watch(NIGHTFIN, ELWYNN)
			ns.db.profile.tracker = false

			ns.Watch(BASS, ELWYNN)

			assert.is_false(ns.db.profile.tracker)
			assert.are.same({ TURNED_ON }, loaded.printed)
		end)

		it("stopping a watch leaves it on, even the last one (STA-R63)", function()
			local loaded = load()
			local ns = loaded.ns
			ns.Watch(NIGHTFIN, DARKSHORE)

			ns.StopWatching(NIGHTFIN, DARKSHORE)

			assert.is_true(ns.db.profile.tracker)
			assert.are.same({}, watches(ns))
		end)
	end)
end)
