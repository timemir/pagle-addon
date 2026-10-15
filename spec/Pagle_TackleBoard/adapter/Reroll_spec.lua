-- Taking a goal down (TKB-R55, TKB-R56, TKB-R108, TKB-R193): ns.CanTakeDown, ns.TakeDown, the native confirm and the
-- `reroll` record, on FakePagle over the fixture catalogue with a seeded random source. A started board's history is
-- appended with fake.catchLog:Append, then login and the first PLAYER_ENTERING_WORLD build the projection; what the
-- reroll appends is read back from the log, and its new goal from the projection. Progress is set on the projection's
-- goals by hand where a spec needs it (counting Catches is the completions' fold, #232).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DAY, WEEK = 86400, 604800
local W = board.WEEKLY_RESET - WEEK -- Tuesday 6 October 2026 15:00 UTC: week 0's weekly reset
local D0 = W + DAY -- Wednesday 7 October 15:00 UTC: board day 0, the start record's day
local UNKNOWN_AREA = 9999 -- an area the fixture catalogue doesn't know (GetArea nil): its goals are stranded

local SEED = 11

-- A Tackle Board Module record for fake.catchLog:Append, by the player's character (1).
local function record(kind, time, payload)
	return { kind = "module", char = 1, time = time, module = "TackleBoard", recordKind = kind, payload = payload }
end

-- The entry ID of the player's entry at `time`, the first at that second (LOG-R13): a goal's ID (TKB-R23).
local function idAt(time)
	return PLAYER_GUID .. "-" .. time .. "-0"
end

-- Goals (tackle-board.md › Data), issued right after the start record: an Expedition on Expedition pin 1, then
-- Notices on Notice pins 1, 2 and 3.
local EXPEDITION, HAUL, QUALITY, WANDERER = idAt(D0 + 3601), idAt(D0 + 3602), idAt(D0 + 3603), idAt(D0 + 3604)
local STARTED = {
	record("start", D0 + 3600, D0 .. ";" .. W),
	record("issue", D0 + 3601, "e;size;0;60;1;4"),
	record("issue", D0 + 3602, "n;haul;2;15;30;14"),
	record("issue", D0 + 3603, "n;quality;1;10;3;2"),
	record("issue", D0 + 3604, "n;wanderer;3;20;3;"),
}

-- The Tackle Board on a FakePagle whose log holds STARTED, then `extra`, built at login (the projection's first
-- build) with the fixture Angler's skill read, drawing from `random` (default board.random(SEED)).
---@param extra table[]? records appended after STARTED
---@param random function? the random source
---@return PagleTackleBoardNS ns
---@return LoadedAddon loaded
---@return table fake
local function started(extra, random)
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, entry in ipairs(STARTED) do
		fake.catchLog:Append(entry)
	end
	for _, entry in ipairs(extra or {}) do
		fake.catchLog:Append(entry)
	end
	local loaded = board.load(fake, { random = random or board.random(SEED) })
	fake.login()
	fake.enterWorld()
	board.readSkill(fake)
	return loaded.ns, loaded, fake
end

-- The `reroll` records in the log, in order.
local function rerolls(ns)
	local found = {}
	for entry in ns.Module:IterateCatches(0) do
		if entry.kind == "module" and entry.recordKind == "reroll" then
			found[#found + 1] = entry
		end
	end
	return found
end

describe("taking a goal down", function()
	describe("with no displayed progress (TKB-R55, TKB-R56)", function()
		it("comes down at once: one reroll record whose new goal has another kind, on the same pin", function()
			local ns, loaded = started()

			ns.TakeDown(HAUL)

			assert.is_nil(loaded.client.popup)
			local appended = rerolls(ns)
			assert.are.equal(1, #appended)
			local decoded = assert(ns.DecodeRecord("reroll", appended[1].payload))
			local def = assert(decoded.goal)
			assert.are.equal(HAUL, decoded.old)
			-- TKB-R55: a new goal of the same type, the old kind dropped
			assert.are.equal("n", def.type)
			assert.are_not.equal("haul", def.kind)
			-- TKB-R57, TKB-R101: the projection re-posts it on the old goal's pin, and the old goal is gone
			local state = ns.State()
			local goal = state.goals[appended[1].id]
			assert.are.same({ appended[1].id, true, 1 }, { state.pins.notices[1], goal.reposted, goal.pin })
			assert.are.equal(def.kind, goal.kind)
			assert.is_nil(state.goals[HAUL])
			-- TKB-R55: a re-posted goal can't be taken down
			assert.is_false(ns.CanTakeDown(appended[1].id))
		end)

		it("carries the goal ns.GenerateGoal draws for the old goal's type with its kind dropped (TKB-R55)", function()
			local ns, _, fake = started()
			-- the same draws the reroll will make: a source of the same seed, nothing drawn from it yet
			local expected =
				ns.GenerateGoal(ns.GenerationContext(ns.State(), fake.serverTime(), board.random(SEED)), "e", "size")

			ns.TakeDown(EXPEDITION)

			local appended = rerolls(ns)
			assert.are.equal(1, #appended)
			assert.are.equal(ns.EncodeReroll(EXPEDITION, expected), appended[1].payload)
			-- the new Expedition takes Expedition pin 1 (TKB-R57)
			assert.are.same({ appended[1].id, false }, ns.State().pins.expeditions)
		end)

		it("never draws the old kind, even when every other kind is open too (TKB-R32, TKB-R55)", function()
			-- A Notice of every kind open, so generation takes the open kinds back; a source that always draws its
			-- lowest value picks the first kind by weight, haul, unless the old kind is dropped.
			local everyKind = {
				record("issue", D0 + 3605, "n;variety;1;10;3;17"),
				record("issue", D0 + 3606, "n;size;1;10;3;3"),
				record("issue", D0 + 3607, "n;collector;2;15;2;"),
				record("issue", D0 + 3608, "n;lure;3;20;25;"),
				record("issue", D0 + 3609, "n;species;2;15;10;6358"),
			}
			local ns = started(everyKind, function(m)
				return m or 0
			end)

			ns.TakeDown(HAUL)

			local appended = rerolls(ns)
			assert.are.equal(1, #appended)
			assert.are_not.equal("haul", ns.DecodeRecord("reroll", appended[1].payload).goal.kind)
		end)

		it("comes down at once for a session-bound goal whose Session has ended, displayed 0 (TKB-R104)", function()
			local ns, loaded, fake = started()
			local wanderer = ns.State().goals[WANDERER]
			wanderer.progress, wanderer.session = 2, "an ended Session"

			assert.is_nil(fake.Pagle.GetSession())
			ns.TakeDown(WANDERER)

			assert.is_nil(loaded.client.popup)
			assert.are.equal(1, #rerolls(ns))
		end)

		it("asks for a session-bound goal with progress in the current Session (TKB-R104)", function()
			local ns, loaded, fake = started()
			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
			local wanderer = ns.State().goals[WANDERER]
			wanderer.progress, wanderer.session = 2, fake.Pagle.GetSession().id

			ns.TakeDown(WANDERER)

			assert.are.equal(
				"Take down this Notice? Its progress (2/3) is lost, and the new one can't be taken down.",
				loaded.client.popup.text
			)
			assert.are.equal(0, #rerolls(ns))
		end)
	end)

	describe("with progress (TKB-R56)", function()
		local NOTICE_TEXT = "Take down this Notice? Its progress (12/30) is lost, and the new one can't be taken down."

		-- The board with the Haul Notice (need 30) at 12.
		local function at12()
			local ns, loaded, fake = started()
			ns.State().goals[HAUL].progress = 12
			return ns, loaded, fake
		end

		it("asks first in a native popup with the exact text and buttons, appending nothing yet", function()
			local ns, loaded = at12()

			ns.TakeDown(HAUL)

			assert.are.same({ NOTICE_TEXT, { "Take it down", "Keep it" } }, {
				loaded.client.popup.text,
				loaded.client.popup.buttons,
			})
			assert.are.equal(0, #rerolls(ns))
		end)

		it('"Keep it" and Esc append nothing, and the goal stays', function()
			local ns, loaded = at12()

			ns.TakeDown(HAUL)
			loaded.client.clickPopup(2)
			ns.TakeDown(HAUL)
			loaded.client.pressEscape()

			assert.is_nil(loaded.client.popup)
			assert.are.equal(0, #rerolls(ns))
			assert.are.equal(HAUL, ns.State().pins.notices[1])
			assert.is_true(ns.CanTakeDown(HAUL))
		end)

		it('"Take it down" appends one reroll record for the goal', function()
			local ns, loaded = at12()

			ns.TakeDown(HAUL)
			loaded.client.clickPopup(1)

			assert.is_nil(loaded.client.popup)
			local appended = rerolls(ns)
			assert.are.equal(1, #appended)
			assert.are.equal(HAUL, ns.DecodeRecord("reroll", appended[1].payload).old)
			assert.are.equal(appended[1].id, ns.State().pins.notices[1])
		end)

		it('says "Expedition" for an Expedition', function()
			local ns, loaded = started()
			ns.State().goals[EXPEDITION].progress = 1 -- of 1: not yet completed in the fold

			ns.TakeDown(EXPEDITION)

			assert.are.equal(
				"Take down this Expedition? Its progress (1/1) is lost, and the new one can't be taken down.",
				loaded.client.popup.text
			)
		end)

		it("works while restricted: the popup is native and non-secure (TKB-R193)", function()
			local ns, loaded, fake = at12()
			fake.setRestricted(true)

			ns.TakeDown(HAUL)
			loaded.client.clickPopup(1)

			assert.are.equal(1, #rerolls(ns))
		end)

		it('appends nothing on "Take it down" when the goal completed while the popup was open (TKB-R55)', function()
			local ns, loaded = at12()
			ns.TakeDown(HAUL)
			-- completing it as the fold does (#232): it is done, no longer open
			local state = ns.State()
			state.goals[HAUL].doneDay = state.day

			loaded.client.clickPopup(1)

			assert.are.equal(0, #rerolls(ns))
		end)

		it('appends nothing on "Take it down" when an update started while the popup was open (TKB-R55)', function()
			local ns, loaded = at12()
			ns.TakeDown(HAUL)
			ns.IsUpdating = function()
				return true
			end

			loaded.client.clickPopup(1)

			assert.are.equal(0, #rerolls(ns))
		end)
	end)

	describe("when it is allowed (TKB-R55, TKB-R108)", function()
		it("is allowed for every open goal from an issue record, and for no unknown goal", function()
			local ns = started()

			assert.are.same({ true, true, true, true, false }, {
				ns.CanTakeDown(EXPEDITION),
				ns.CanTakeDown(HAUL),
				ns.CanTakeDown(QUALITY),
				ns.CanTakeDown(WANDERER),
				ns.CanTakeDown("Player-0-00000000-0-0"),
			})
		end)

		it("isn't allowed for a completed goal", function()
			local ns = started()
			local state = ns.State()
			state.goals[QUALITY].doneDay = state.day

			ns.TakeDown(QUALITY)

			assert.is_false(ns.CanTakeDown(QUALITY))
			assert.are.equal(0, #rerolls(ns))
		end)

		it("isn't allowed for a re-posted goal, unless it is stranded (TKB-R44)", function()
			local rerolled = {
				record("reroll", D0 + 3700, HAUL .. ";n;size;1;10;3;3"),
				record("reroll", D0 + 3701, QUALITY .. ";n;haul;1;10;20;" .. UNKNOWN_AREA), -- its zone is gone
			}
			local ns = started(rerolled)
			local reposted, stranded = idAt(D0 + 3700), idAt(D0 + 3701)

			ns.TakeDown(reposted)
			assert.are.equal(2, #rerolls(ns)) -- only the history's two
			ns.TakeDown(stranded)

			assert.are.same({ false, false }, { ns.CanTakeDown(reposted), ns.CanTakeDown(stranded) })
			local appended = rerolls(ns)
			assert.are.equal(3, #appended)
			assert.are.equal(stranded, ns.DecodeRecord("reroll", appended[3].payload).old)
			assert.are.equal(appended[3].id, ns.State().pins.notices[2])
		end)

		it("takes nothing down while the projection is updating; the pins grey the button meanwhile", function()
			local ns, loaded = started()
			ns.IsUpdating = function()
				return true
			end

			ns.TakeDown(HAUL)
			ns.TakeDown(EXPEDITION)

			assert.is_nil(loaded.client.popup)
			assert.are.equal(0, #rerolls(ns))
			-- TKB-R108: the pins (#239) disable the shown button while ns.IsUpdating(); CanTakeDown doesn't hide it
			assert.are.same({ true, true }, { ns.CanTakeDown(HAUL), ns.CanTakeDown(EXPEDITION) })
		end)

		it("asks nothing while the projection is updating, even for a goal with progress", function()
			local ns, loaded = started()
			ns.State().goals[HAUL].progress = 12
			ns.IsUpdating = function()
				return true
			end

			ns.TakeDown(HAUL)

			assert.is_nil(loaded.client.popup)
			assert.are.equal(0, #rerolls(ns))
		end)
	end)
end)
