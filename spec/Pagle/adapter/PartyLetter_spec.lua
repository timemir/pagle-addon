-- The party letter on the client, through the real TOC (announcements.md › The party letter, ANN-R113–R116; settings.md
-- SET-R36; from 1.5.3, #655): party sharing, showing and cheers are off until the player answers it, a 1.5.2 player's
-- stored choice is kept, a switch set by hand is an answer; when it shows (a Pagle groupmate in the same zone while
-- the player fishes, through Core's letter service and its gates, ONB-R15–R17); its words and three buttons; and
-- /pagle dev party letter.

local ELWYNN, DUROTAR = 1429, 1411
local KEEFER = 19805
local DAY = 24 * 60 * 60

local LINE = "Kukli Stonebrew is fishing Elwynn Forest with you, and they run Pagle too. Fish together: share your best"
	.. " catches and cheer theirs."

-- Kukli (with Forever's surname) and Arwen, both in Elwynn Forest unless `kukliMap` says otherwise; a raid with `raid`.
local function party(kukliMap, raid)
	return {
		raid = raid,
		members = {
			{ name = "Kukli", surname = "Stonebrew", map = kukliMap or ELWYNN },
			{ name = "Arwen", map = ELWYNN },
		},
	}
end

-- Core logged in on Forever over a log of two old Casts (a returning Angler: no onboarding Letter) and `saved`, in
-- Elwynn Forest with `group` (none: alone), the Ledger registered, and past the hello's 2 s and the letters' 4 s
-- (ANN-R103, ONB-R10); Margin notes off. `globals` as loadCore's.
local function loggedIn(group, saved, globals)
	local loaded = loadCore(history(2), saved, globals)
	loaded.env.PagleDB.global.onboarding.notesOn = false
	loaded.client.group = group
	loaded.client.playerMap = ELWYNN
	loaded.client.mapNames[ELWYNN] = "Elwynn Forest"
	loaded.client.mapNames[DUROTAR] = "Durotar"
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	enterWorld(loaded, 3)
	loaded.client.advance(4)
	return loaded, M
end

-- The texts Core sent on the prefix Pagle, in order, and forgets them.
local function sent(loaded)
	local texts = {}
	for _, message in ipairs(loaded.client.addonMessages) do
		texts[#texts + 1] = message.text
	end
	loaded.client.addonMessages = {}
	return texts
end

-- A message arriving on the party channel from `sender` (Kukli by default).
local function receive(loaded, text, sender)
	loaded.client.fire("CHAT_MSG_ADDON", "Pagle", text, "PARTY", sender or "Kukli-Testrealm", "", 0, 0, "", 0)
end

-- Kukli's hello: they run Pagle (ANN-R103).
local function hello(loaded, sender)
	receive(loaded, "1:H:0", sender)
	loaded.client.advance(0)
end

-- The player casts (and catches), then the frame where Core flushes the Cast's moments and a letter sent then is
-- checked (ONB-R17).
local function cast(loaded)
	catchOne(loaded)
	loaded.client.advance(0)
	loaded.client.advance(0)
end

-- The letter's frame, nil before its first showing.
local function letterOf(loaded)
	return loaded.env.PagleLetter
end

-- Whether a letter is on screen, and whether it is the party letter.
local function shows(loaded)
	local frame = letterOf(loaded)
	return frame ~= nil and frame:IsShown() and frame.line.text == LINE
end

-- Clicks the letter's button reading `text`.
local function press(loaded, text)
	local frame = assert(letterOf(loaded))
	for _, button in ipairs({ frame.open, frame.later, frame.decline }) do
		if button:IsShown() and button.label.text == text then
			button:Click()
			return
		end
	end
	error("no " .. text .. " on the letter")
end

-- PagleDB.profile.party as the client holds it.
local function stored(loaded)
	return loaded.ns.db.profile.party
end

-- A Legend's first Catch, marked for the party (ANN-R104), raised and flushed.
local function legend(loaded, M)
	M:RaiseMoment({ rung = "splash", kind = "legend", title = "Legend", icon = KEEFER, party = "legend" })
	loaded.client.advance(0)
end

local function slash(loaded, line)
	loaded.env.SlashCmdList.PAGLE(line)
end

-- The Party block's row labelled `label`, on Settings › Announcements.
local function row(loaded, label)
	for _, initializer in ipairs(assert(loaded.client.settings.category("Announcements")).layout.initializers) do
		if initializer:GetName() == label then
			return initializer
		end
	end
	error("no row " .. label)
end

describe("the opt-in (ANN-R113)", function()
	it("ann_r113 shares nothing and shows nothing of the party until the letter is answered", function()
		local loaded, M = loggedIn(party())
		hello(loaded)
		sent(loaded)

		legend(loaded, M)
		receive(loaded, "1:M:k3x91:legend:19805")
		loaded.client.advance(1)

		assert.are.same({}, sent(loaded))
		assert.is_nil(loaded.ns.announcementFrames.party and loaded.ns.announcementFrames.party.display)
		assert.is_false(loaded.ns.PartyOption("share"))
		assert.is_false(loaded.ns.PartyOption("show"))
	end)

	it("ann_r113 still says hello, which carries no moment and no place, so a groupmate can be found", function()
		local loaded = loadCore(history(2))
		loaded.client.group = party()
		enterWorld(loaded, 3)
		loaded.client.advance(2)
		local texts = sent(loaded)
		assert.are.same({ "1:H:1" }, texts)
		assert.is_nil(stored(loaded))
	end)

	it(
		"ann_r113 keeps a 1.5.2 player's stored choice: their switches read as they did, and the letter never asks",
		function()
			local loaded, M =
				loggedIn(party(), { profiles = { Default = { party = { share = false, kinds = { gold = false } } } } })
			assert.is_false(loaded.ns.PartyOption("share"))
			assert.is_true(loaded.ns.PartyOption("show"))
			assert.is_true(loaded.ns.PartyOption("sounds"))
			assert.is_false(loaded.ns.PartyKindOn("gold"))

			hello(loaded)
			cast(loaded)
			assert.is_false(shows(loaded))

			receive(loaded, "1:M:k3x91:legend:19805")
			loaded.client.advance(10)
			assert.are.equal("Kukli Stonebrew", loaded.ns.announcementFrames.party.display.announcement.headline.title)
			sent(loaded)
			legend(loaded, M)
			assert.are.same({}, sent(loaded))
		end
	)

	it("ann_r113 counts a 1.5.2 kind switch alone as a stored choice, with Share and Show on as they were", function()
		local loaded = loggedIn(party(), { profiles = { Default = { party = { kinds = { zone = false } } } } })
		assert.is_true(loaded.ns.PartyOption("share"))
		assert.is_true(loaded.ns.PartyOption("show"))
		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
	end)

	it("ann_r113 counts an empty 1.5.2 Party table as nothing stored: not asked yet, so off", function()
		local loaded = loggedIn(party(), { profiles = { Default = { party = { kinds = {} } } } })
		assert.is_false(loaded.ns.PartyOption("share"))
		hello(loaded)
		cast(loaded)
		assert.is_true(shows(loaded))
	end)

	it("ann_r113 migrates once: a kind switched off under 1.5.3 doesn't turn Share and Show on", function()
		local first = loggedIn(nil)
		row(first, "Gold tier in a Hunt"):GetSetting():SetValue(false)
		local second = loggedIn(nil, first.env.PagleDB)
		assert.is_false(second.ns.PartyOption("share"))
		assert.is_false(second.ns.PartyOption("show"))
		assert.is_false(second.ns.PartyKindOn("gold"))
	end)

	it("ann_r113 counts a switch turned on in Settings by hand as an answer: the letter never asks", function()
		local loaded, M = loggedIn(party())
		row(loaded, "Share my moments with my party"):GetSetting():SetValue(true)
		assert.is_true(stored(loaded).share)

		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
		sent(loaded)
		legend(loaded, M)
		assert.are.equal(1, #sent(loaded))
	end)

	it("ann_r113 counts no answer from the Defaults button on a player not asked yet (SET-R33)", function()
		local loaded = loggedIn(party())
		loaded.client.settings.defaults(loaded.client.settings.page("Announcements"))
		assert.is_false(row(loaded, "Share my moments with my party"):GetSetting():GetValue())
		assert.is_false(row(loaded, "Show my party's moments"):GetSetting():GetValue())
		assert.is_true(row(loaded, "Cheers sounds"):GetSetting():GetValue())
		hello(loaded)
		cast(loaded)
		assert.is_true(shows(loaded))
	end)
end)

describe("when the party letter shows (ANN-R114)", function()
	it("ann_r114 shows once a Pagle groupmate is in the player's zone and the player has cast, mid-session", function()
		local loaded = loggedIn(party())
		loaded.client.advance(600)
		assert.is_false(shows(loaded))
		hello(loaded)
		assert.is_false(shows(loaded))

		cast(loaded)

		assert.is_true(shows(loaded))
		local frame = letterOf(loaded)
		assert.are.same({ "A letter, passed along the bank", LINE, "Fish together", "Not now", "No thanks" }, {
			frame.kicker.text,
			frame.line.text,
			frame.open.label.text,
			frame.later.label.text,
			frame.decline.label.text,
		})
		assert.is_true(loaded.ns.LetterShows())
	end)

	it("ann_r114 shows as the hello arrives when the player cast in the last 300 s, and not after", function()
		local loaded = loggedIn(party())
		cast(loaded)
		loaded.client.advance(299)
		hello(loaded)
		assert.is_true(shows(loaded))

		local late = loggedIn(party())
		cast(late)
		late.client.advance(301)
		hello(late)
		assert.is_false(shows(late))
	end)

	it("ann_r114 never shows in a raid", function()
		local loaded = loggedIn(party(nil, true))
		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
	end)

	it("ann_r114 never shows without a groupmate's hello: nobody else runs Pagle", function()
		local loaded = loggedIn(party())
		cast(loaded)
		loaded.client.advance(10)
		cast(loaded)
		assert.is_false(shows(loaded))
	end)

	it("ann_r114 never shows while the Pagle groupmate is in another zone, or the client can't place them", function()
		local loaded = loggedIn(party(DUROTAR))
		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))

		local unplaced = loggedIn({ members = { { name = "Kukli", surname = "Stonebrew" } } })
		hello(unplaced)
		cast(unplaced)
		assert.is_false(shows(unplaced))
	end)

	it("ann_r114 names the Pagle groupmate in the player's zone, not another who isn't", function()
		local loaded = loggedIn(party(DUROTAR))
		hello(loaded)
		hello(loaded, "Arwen-Testrealm")
		cast(loaded)
		assert.is_true(letterOf(loaded):IsShown())
		assert.matches("^Arwen is fishing Elwynn Forest with you", letterOf(loaded).line.text)
	end)

	it("ann_r114 never shows in combat: it waits for the combat hold to end and what it held (ONB-R10)", function()
		local loaded = loggedIn(party())
		hello(loaded)
		setCombat(loaded, true)
		cast(loaded)
		loaded.client.advance(5)
		assert.is_false(shows(loaded))

		setCombat(loaded, false)
		loaded.client.advance(12)
		assert.is_true(shows(loaded))
	end)

	it("ann_r114 waits while another letter shows, one at a time, and comes after it is answered (ONB-R17)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.client.group = party()
		loaded.client.playerMap = ELWYNN
		loaded.client.mapNames[ELWYNN] = "Elwynn Forest"
		enterWorld(loaded, 3)
		loaded.client.advance(4)
		local frame = assert(letterOf(loaded))
		assert.are.equal("Open the letter", frame.open.label.text)

		hello(loaded)
		cast(loaded)
		assert.are.equal("Open the letter", frame.open.label.text)

		press(loaded, "Later")
		assert.is_false(shows(loaded))
		loaded.client.advance(10)
		assert.is_true(shows(loaded))
	end)

	it("ann_r114 doesn't show once the reason has passed while it waited: the groupmate left the zone", function()
		local loaded = loggedIn(party())
		hello(loaded)
		setCombat(loaded, true)
		cast(loaded)
		loaded.client.group.members[1].map = DUROTAR
		loaded.client.group.members[2].map = DUROTAR
		setCombat(loaded, false)
		loaded.client.advance(12)
		assert.is_false(letterOf(loaded) ~= nil and letterOf(loaded):IsShown())
	end)
end)

describe("the party letter's buttons (ANN-R115)", function()
	-- In a party with Kukli, the letter on screen.
	local function asked(saved, globals)
		local loaded, M = loggedIn(party(), saved, globals)
		hello(loaded)
		cast(loaded)
		assert.is_true(shows(loaded))
		sent(loaded)
		return loaded, M
	end

	it(
		"ann_r115 Fish together turns sharing, showing and cheers on, stored, and the letter never asks again",
		function()
			local loaded, M = asked()

			press(loaded, "Fish together")

			assert.is_false(letterOf(loaded):IsShown())
			local saved = stored(loaded)
			assert.are.same({ true, true, true, "accepted" }, { saved.share, saved.show, saved.sounds, saved.letter })
			receive(loaded, "1:M:k3x91:legend:19805")
			loaded.client.advance(10)
			assert.are.equal("Kukli Stonebrew", loaded.ns.announcementFrames.party.display.announcement.headline.title)
			legend(loaded, M)
			assert.are.equal(1, #sent(loaded))

			local next = loggedIn(party(), loaded.env.PagleDB, {
				GetServerTime = function()
					return SERVER_TIME + 2 * DAY
				end,
			})
			hello(next)
			cast(next)
			assert.is_false(shows(next))
		end
	)

	it("ann_r115 Not now stores the time, asks no more this login, nor within 24 h, then again", function()
		local loaded = asked()
		local now = loaded.env.GetServerTime()

		press(loaded, "Not now")

		assert.is_false(letterOf(loaded):IsShown())
		local saved = stored(loaded)
		assert.are.same({ "later", now }, { saved.letter, saved.laterAt })
		assert.is_false(loaded.ns.PartyOption("share"))
		loaded.client.advance(10)
		cast(loaded)
		assert.is_false(letterOf(loaded):IsShown())

		local soon = loggedIn(party(), loaded.env.PagleDB, {
			GetServerTime = function()
				return SERVER_TIME + DAY - 60
			end,
		})
		hello(soon)
		cast(soon)
		assert.is_false(shows(soon))

		local day = loggedIn(party(), loaded.env.PagleDB, {
			GetServerTime = function()
				return SERVER_TIME + DAY + 60
			end,
		})
		hello(day)
		cast(day)
		assert.is_true(shows(day))
		press(day, "Not now")
		assert.are.equal("later", stored(day).letter)
	end)

	it("ann_r115 No thanks never asks again, and leaves every switch off", function()
		local loaded = asked()

		press(loaded, "No thanks")

		assert.is_false(letterOf(loaded):IsShown())
		assert.are.equal("declined", stored(loaded).letter)
		assert.is_false(loaded.ns.PartyOption("share"))
		assert.is_false(loaded.ns.PartyOption("show"))

		local later = loggedIn(party(), loaded.env.PagleDB, {
			GetServerTime = function()
				return SERVER_TIME + 30 * DAY
			end,
		})
		hello(later)
		cast(later)
		assert.is_false(shows(later))
	end)

	it("ann_r115 keeps every switch in Settings after any answer", function()
		local loaded = asked()
		press(loaded, "No thanks")
		row(loaded, "Show my party's moments"):GetSetting():SetValue(true)
		assert.is_true(loaded.ns.PartyOption("show"))
		assert.is_false(loaded.ns.PartyOption("share"))
	end)

	it("ann_r115 hides the third button for every other letter", function()
		local loaded = loadCore({ BUILD_ENTRY })
		enterWorld(loaded, 3)
		loaded.client.advance(4)
		local frame = assert(letterOf(loaded))
		assert.are.equal("Open the letter", frame.open.label.text)
		assert.is_false(frame.decline:IsShown())
	end)

	it("ann_r115 sets its three buttons in a row, each sized to its words (ONB-R15)", function()
		local loaded = asked()
		local frame = letterOf(loaded)
		assert.are.equal(#"Not now" * 6 + 36, frame.later:GetWidth())
		assert.are.equal(#"No thanks" * 6 + 36, frame.decline:GetWidth())
		local x = 34 + frame.open:GetWidth() + 14 + frame.later:GetWidth() + 14
		assert.are.equal(x, frame.decline.points[1][4])
	end)

	it("ann_r115 closes its row of three up when the words would pass the slip's margin (ONB-R15)", function()
		local loaded = asked()
		local frame = letterOf(loaded)
		-- Words the client measures at 120 each: 3 × (120 + 36) + 2 × 14 = 496 would pass the slip's 470 - 2 × 34.
		for _, button in ipairs({ frame.open, frame.later, frame.decline }) do
			button.label.GetStringWidth = function()
				return 120
			end
		end
		press(loaded, "Not now")
		slash(loaded, "dev on")
		slash(loaded, "dev party letter")

		assert.are.same({ 144, 144, 144 }, { frame.open:GetWidth(), frame.later:GetWidth(), frame.decline:GetWidth() })
		assert.are.equal(34 + 144 + 8 + 144 + 8, frame.decline.points[1][4])
	end)
end)

describe("the party letter's tour stop and dev command (ANN-R116)", function()
	it("ann_r116 adds core.onboarding.letter.core.party, a sample whose buttons write nothing (ONB-R84)", function()
		local loaded = loggedIn(nil)
		local stop
		for _, listed in ipairs(loaded.ns.tourStops:List(loaded.ns.Modules:Modules(), "core")) do
			if listed.name == "core.onboarding.letter.core.party" then
				stop = listed
			end
		end

		assert(stop, "no tour stop for the party letter").show()
		local frame = letterOf(loaded)
		assert.is_true(frame:IsShown())
		assert.matches("^Kukli Emnabi is fishing", frame.line.text)
		assert.is_true(frame.decline:IsShown())
		press(loaded, "No thanks")
		stop.show()
		press(loaded, "Not now")
		stop.show()
		press(loaded, "Fish together")
		stop.show()
		stop.hide()

		assert.is_false(frame:IsShown())
		assert.is_nil(stored(loaded))
		assert.is_nil(loaded.env.PagleDB.global.onboarding.letters)
	end)

	it(
		"ann_r116 /pagle dev party letter shows it alone with a made-up groupmate, its buttons acting as ever",
		function()
			local loaded = loggedIn(nil)
			slash(loaded, "dev on")
			slash(loaded, "dev party letter")
			local frame = assert(letterOf(loaded))
			assert.is_true(frame:IsShown())
			assert.are.equal(
				"Kukli Emnabi is fishing Elwynn Forest with you, and they run Pagle too. Fish together: share your best"
					.. " catches and cheer theirs.",
				frame.line.text
			)
			press(loaded, "No thanks")
			assert.are.equal("declined", stored(loaded).letter)

			slash(loaded, "dev party letter")
			press(loaded, "Fish together")
			assert.are.equal("accepted", stored(loaded).letter)
			assert.is_true(loaded.ns.PartyOption("share"))

			slash(loaded, "dev party letter reset")
			assert.is_false(loaded.ns.PartyOption("share"))
			assert.is_nil(stored(loaded).letter)
		end
	)
end)
