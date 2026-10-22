-- The companion hint and its weekly Nod as data (HNT-R27, HNT-R86, HNT-R170–R172, HNT-R176, PUSH-R90): when the hint
-- applies, its lines on the board and the tracker, when the Nod is due, and the Nod. Pure logic (logic/Companion.lua);
-- the strip, the placeholder slip, the tracker line, Get it, Dismiss, the Nod at login and the Settings row are
-- checked on FakePagle in spec/Pagle_Hunts/adapter/Companion_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local ns = hunts.load().ns
local DAY = 86400
local NOW = SERVER_TIME

local MISSING = {
	"New wagers are out there. The Pagle companion brings them: more XP, more Coins.",
	"Installed it just now? Log out to character select once.",
}
local NOT_RUNNING = { "The Pagle companion isn't running. Start it to get this week's wagers." }

describe("the companion hint (HNT-R170)", function()
	it("is on at 1.0: the switch ships on, with the companion's download address (HNT-R172, HNT-R170)", function()
		assert.is_true(ns.COMPANION_HINT_ON)
		assert.are.equal("https://pagle.app/download", ns.COMPANION_URL)
	end)

	it("applies to no companion state while the switch is off (HNT-R172)", function()
		for _, state in ipairs({ "checking", "missing", "notRunning", "connected" }) do
			assert.is_nil(ns.CompanionHint(false, state, true))
		end
	end)

	it("reads what the companion brings when missing, then the first-install line (PUSH-R90)", function()
		local hint = ns.CompanionHint(true, "missing", true)

		assert.are.same({ state = "missing", lines = MISSING, tracker = "New wagers with the Pagle companion" }, hint)
	end)

	it("reads its own line when the companion isn't running", function()
		local hint = ns.CompanionHint(true, "notRunning", true)

		assert.are.same({ state = "notRunning", lines = NOT_RUNNING, tracker = "Pagle companion not running" }, hint)
	end)

	it('shows nothing while "checking" or "connected"', function()
		assert.is_nil(ns.CompanionHint(true, "checking", true))
		assert.is_nil(ns.CompanionHint(true, "connected", true))
	end)

	it("shows nothing once dismissed (profile.companionHint false)", function()
		assert.is_nil(ns.CompanionHint(true, "missing", false))
		assert.is_nil(ns.CompanionHint(true, "notRunning", false))
	end)

	it("claims no odds, chance or due fish in any of its words (HNT-R27)", function()
		local L = ns.L
		local words = {
			L.HINT_MISSING,
			L.HINT_FIRST_INSTALL,
			L.HINT_NOT_RUNNING,
			L.HINT_GET_IT,
			L.HINT_DISMISS,
			L.HINT_ADDRESS_KICKER,
			L.HINT_ADDRESS_COPY,
			L.TRACKER_HINT_MISSING,
			L.TRACKER_HINT_NOT_RUNNING,
			L.TRACKER_HINT_WHY,
			L.COMPANION_HINT_SETTING,
			L.COMPANION_HINT_TOOLTIP,
		}
		for _, text in ipairs(words) do
			for _, word in ipairs({ "odds", "chance", "due", "likely", "%%", "rate" }) do
				assert.is_nil(text:lower():find(word))
			end
		end
	end)
end)

describe("the weekly Nod (HNT-R171)", function()
	local hint = ns.CompanionHint(true, "missing", true)

	it("is due when the hint applies and none was ever raised", function()
		assert.is_true(ns.HintNodDue(hint, 0, NOW))
	end)

	it("is not due again within 7 days, and is at 7 days (Tunables)", function()
		assert.are.equal(7 * DAY, ns.HINT_NOD_INTERVAL)
		assert.is_false(ns.HintNodDue(hint, NOW - 7 * DAY + 1, NOW))
		assert.is_true(ns.HintNodDue(hint, NOW - 7 * DAY, NOW))
	end)

	it("is never due while the hint doesn't apply", function()
		assert.is_false(ns.HintNodDue(nil, 0, NOW))
	end)

	it("is HNT-R86's companionHint nod: the first line, no cast and no Coins, opening the spread", function()
		local opened = 0
		local nod = ns.HintNod(hint, function()
			opened = opened + 1
		end)

		local onClick = nod.onClick
		nod.onClick = nil
		assert.are.same({
			rung = "nod",
			kind = "companionHint",
			title = "Pagle Wagers",
			text = MISSING[1],
			pastText = MISSING[1],
			icon = "Interface\\Icons\\Trade_Fishing",
		}, nod)
		onClick()
		assert.are.equal(1, opened)
	end)

	it("says the not-running line when the companion isn't running", function()
		local nod = ns.HintNod(ns.CompanionHint(true, "notRunning", true), function() end)

		assert.are.equal(NOT_RUNNING[1], nod.text)
		assert.are.equal(NOT_RUNNING[1], nod.pastText)
	end)
end)
