-- The Stats book on the tour, on FakePagle (CORE-R65, CORE-R68, ONB-R84): Stats registers no stops of its own, so the
-- book's tour stop is its First look's, `core.onboarding.look.stats.book`, which Core's adapter adds (here
-- fake.ns.AddFirstLookTourStops, as FakePagle doesn't). It opens the book and shows the set, writing nothing.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS

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

-- Stats on a fake for a new Angler (the onboarding state as login step 1 makes it with no Cast yet, ONB-R1, ONB-R2:
-- `letter = "waiting"`, nothing seen, no First evening item done), logged in with the worked Darkshore history, the
-- player in Darkshore's Auberdine at skill 200, the First look tour stops added and dev on.
local function ready()
	local fake = newFakePagle()
	fake.global.onboarding = fake.ns.NewOnboardingState("waiting")
	local loaded, _, book = stats.start({
		fake = fake,
		firstLook = true,
		records = stats.darkshore(),
		at = { zone = I.DARKSHORE, subzone = I.AUBERDINE, skillRank = 200, skillMod = 0 },
	})
	fake.ns.AddFirstLookTourStops()
	fake.slash("dev on")
	fake.printed = {}
	return loaded, fake, book
end

describe("the Stats book's tour stop (CORE-R65, CORE-R68, ONB-R84)", function()
	it("opens the book with its First look, then leaves a new Angler's onboarding state as it was", function()
		local _, fake, book = ready()
		local before = copy(fake.global.onboarding)

		fake.slash("dev tour core")
		fake.wait(1.6)
		local showing, open = fake.firstLooks:Showing(), book:IsShown()
		fake.wait(60)

		assert.are.equal(1, #fake.tourShots)
		assert.is_true(open)
		assert.are.equal("stats.book", showing and showing.id)
		assert.is_false(book:IsShown())
		assert.are.same(before, fake.global.onboarding)
		assert.are.same({}, fake.notesShown)
	end)

	it("leaves the First look for the Angler's own first opening of the book (ONB-R55)", function()
		local loaded, fake = ready()
		fake.slash("dev tour core")
		fake.wait(60)

		loaded.ns.OpenBook()

		assert.is_true(fake.onboarding:IsLookSeen("stats.book"))
	end)
end)
