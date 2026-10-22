-- The Tackle Board on the tour, on FakePagle (CORE-R65, CORE-R68, ONB-R84): the Tackle Board registers no stops of its
-- own, so the board's tour stop is its First look's, `core.onboarding.look.tackleboard.board`, which Core's adapter
-- adds (here fake.ns.AddFirstLookTourStops, as FakePagle doesn't). It opens the board and shows the set, writing
-- nothing.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record = board.record

local W = board.WEEK0
local TODAY = board.DAILY_RESET
local S = TODAY + 60
local FILLER = "n;haul;2;15;30;12"
local EXPEDITION = "e;haul;0;60;150;12"

-- A board started today with an Expedition and three Notices.
local STARTED = {
	board.skill(S - 30),
	record("start", S, TODAY .. ";" .. W),
	record("issue", S + 1, EXPEDITION),
	record("issue", S + 2, FILLER),
	record("issue", S + 3, FILLER),
	record("issue", S + 4, FILLER),
}

-- A deep copy of `value`.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, field in pairs(value) do
		result[key] = copy(field)
	end
	return result
end

-- The Tackle Board on a fake for a new Angler (the onboarding state as login step 1 makes it with no Cast yet,
-- ONB-R1, ONB-R2: `letter = "waiting"`, nothing seen, no First evening item done), its log holding a started board,
-- logged in with its projection built and the login's live step run, the First look tour stops added and dev on; the
-- board isn't opened.
local function ready()
	local fake = board.withHistory(STARTED)
	fake.global.onboarding = fake.ns.NewOnboardingState("waiting")
	local loaded = board.load(fake)
	fake.login()
	fake.enterWorld()
	loaded.client.runTimers()
	fake.ns.AddFirstLookTourStops()
	fake.slash("dev on")
	fake.printed = {}
	return loaded, fake
end

describe("the Tackle Board's tour stop (CORE-R65, CORE-R68, ONB-R84)", function()
	it("opens the board with its First look, then leaves a new Angler's onboarding state as it was", function()
		local loaded, fake = ready()
		local before = copy(fake.global.onboarding)

		fake.slash("dev tour core")
		fake.wait(1.6)
		local showing, open = fake.firstLooks:Showing(), loaded.ns.board.frame:IsShown()
		fake.wait(60)

		assert.are.equal(1, #fake.tourShots)
		assert.is_true(open)
		assert.are.equal("tackleboard.board", showing and showing.id)
		assert.is_false(loaded.ns.board.frame:IsShown())
		assert.are.same(before, fake.global.onboarding)
		assert.are.same({}, fake.notesShown)
	end)

	it("leaves the First look for the Angler's own first opening of the board (ONB-R55)", function()
		local loaded, fake = ready()
		fake.slash("dev tour core")
		fake.wait(60)

		loaded.ns.OpenBoard()

		assert.is_true(fake.onboarding:IsLookSeen("tackleboard.board"))
	end)
end)
