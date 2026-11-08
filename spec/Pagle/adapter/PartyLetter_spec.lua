-- The party letter on the client, through the real TOC (announcements.md › The party letter, ANN-R113–R117; settings.md
-- SET-R35, SET-R36; from 1.5.3, #655, and from 1.6, #665): Party Hunts, party sharing, showing and cheers are off until
-- the player accepts it, a 1.5.2 player's stored choice is kept, a switch set by hand is an answer; when it shows (a
-- Pagle groupmate in the same zone while the player fishes, through Core's letter service and its gates,
-- ONB-R15–R17); its words and three buttons, all the service's own; 1.5.3's answer moved into the service; and
-- /pagle dev party letter.

local ELWYNN, DUROTAR = 1429, 1411
local KEEFER = 19805
local DAY = 24 * 60 * 60

local LINE = "Kukli Stonebrew is fishing Elwynn Forest with you, and they run Pagle too. Fish together: share your best"
	.. " catches, cheer theirs, and count each other’s catches toward your Hunts."
local ID = "core.party"

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
	-- the zone a Cast is logged in, so a caught one goes to the party as a party catch with Party Hunts on (LOG-R111)
	loaded.client.areaNames[148] = "Darkshore"
	loaded.env.GetRealZoneText = function()
		return "Darkshore"
	end
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	enterWorld(loaded, 3)
	loaded.client.advance(4)
	return loaded, M
end

-- The texts Core sent on `prefix` (Pagle, the party toasts', by default), in order; every message sent is forgotten.
local function sent(loaded, prefix)
	local texts = {}
	for _, message in ipairs(loaded.client.addonMessages) do
		if message.prefix == (prefix or "Pagle") then
			texts[#texts + 1] = message.text
		end
	end
	loaded.client.addonMessages = {}
	return texts
end

-- The letter service's state of the party letter, and the time its Not now was kept (ONB-R16).
local function letterState(loaded)
	local onboarding = loaded.env.PagleDB.global.onboarding
	return onboarding.letters and onboarding.letters[ID], onboarding.laterAt and onboarding.laterAt[ID]
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
	it("ann_r113 shares nothing, shows nothing and counts nothing of the party until the letter is accepted", function()
		local loaded, M = loggedIn(party())
		hello(loaded)
		sent(loaded)

		legend(loaded, M)
		receive(loaded, "1:M:k3x91:legend:19805")
		cast(loaded)
		loaded.client.advance(1)

		assert.are.same({}, loaded.client.addonMessages)
		assert.is_nil(loaded.ns.announcementFrames.party and loaded.ns.announcementFrames.party.display)
		assert.is_false(loaded.ns.PartyOption("share"))
		assert.is_false(loaded.ns.PartyOption("show"))
		assert.is_false(loaded.ns.PartyHuntsOn())
		assert.is_nil(loaded.ns.db.profile.partyHunts)
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

	it("ann_r113 counts Party Hunts turned on in Settings by hand as an answer too (SET-R35)", function()
		local loaded = loggedIn(party())
		row(loaded, "Party Hunts"):GetSetting():SetValue(true)
		assert.is_true(loaded.ns.db.profile.partyHunts)
		assert.is_false(loaded.ns.PartyOption("share"))

		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
		assert.are.equal(1, #sent(loaded, "PagleCatch"))
	end)

	it("ann_r113 counts no answer from the Defaults button on a player not asked yet (SET-R33)", function()
		local loaded = loggedIn(party())
		loaded.client.settings.defaults(loaded.client.settings.page("Announcements"))
		assert.is_nil(loaded.ns.db.profile.partyHunts)
		assert.is_false(row(loaded, "Party Hunts"):GetSetting():GetValue())
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

	it("ann_r114 never shows while the client places the Pagle groupmate in another zone", function()
		local loaded = loggedIn(party(DUROTAR))
		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
	end)

	it(
		"ann_r114 shows, naming no zone, when the client can't place the Pagle groupmate: unknown isn't another",
		function()
			local unplaced = loggedIn({ members = { { name = "Kukli", surname = "Stonebrew" } } })
			hello(unplaced)
			cast(unplaced)
			assert.is_true(letterOf(unplaced):IsShown())
			assert.are.equal(
				"Kukli Stonebrew runs Pagle too and is in your party. Fish together: share your best catches, cheer"
					.. " theirs, and count each other’s catches toward your Hunts.",
				letterOf(unplaced).line.text
			)

			-- nor the player
			local lost = loggedIn(party())
			lost.client.playerMap = nil
			hello(lost)
			cast(lost)
			assert.is_true(letterOf(lost):IsShown())
			assert.matches("^Kukli Stonebrew runs Pagle too and is in your party%.", letterOf(lost).line.text)
		end
	)

	it("ann_r114 names the groupmate the client places in the player's zone before one it can't place", function()
		local loaded =
			loggedIn({ members = { { name = "Kukli", surname = "Stonebrew" }, { name = "Arwen", map = ELWYNN } } })
		hello(loaded)
		hello(loaded, "Arwen-Testrealm")
		cast(loaded)
		assert.matches("^Arwen is fishing Elwynn Forest with you", letterOf(loaded).line.text)
	end)

	it(
		"ann_r114 sends nothing more for a groupmate it can't place: the letter shows on what already arrived",
		function()
			local loaded = loggedIn({ members = { { name = "Kukli", surname = "Stonebrew" } } })
			hello(loaded)
			sent(loaded)
			sent(loaded, "PagleCatch")
			cast(loaded)
			assert.is_true(letterOf(loaded):IsShown())
			assert.are.same({}, sent(loaded))
			assert.are.same({}, sent(loaded, "PagleCatch"))
		end
	)

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
		"ann_r115 Fish together turns Party Hunts, sharing, showing and cheers on, stored, and the letter never asks"
			.. " again (SET-R35)",
		function()
			local loaded, M = asked()

			press(loaded, "Fish together")

			assert.is_false(letterOf(loaded):IsShown())
			local saved = stored(loaded)
			assert.are.same({ true, true, true }, { saved.share, saved.show, saved.sounds })
			assert.is_nil(saved.letter)
			assert.is_true(loaded.ns.db.profile.partyHunts)
			assert.are.equal("opened", (letterState(loaded)))
			receive(loaded, "1:M:k3x91:legend:19805")
			loaded.client.advance(10)
			assert.are.equal("Kukli Stonebrew", loaded.ns.announcementFrames.party.display.announcement.headline.title)
			legend(loaded, M)
			assert.are.equal(1, #sent(loaded))
			cast(loaded)
			assert.are.equal(1, #sent(loaded, "PagleCatch"))

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
		assert.are.same({ "later", now }, { letterState(loaded) })
		assert.is_nil(stored(loaded))
		assert.is_false(loaded.ns.PartyOption("share"))
		assert.is_false(loaded.ns.PartyHuntsOn())
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
		assert.are.same({ "later", SERVER_TIME + DAY + 60 }, { letterState(day) })
	end)

	it("ann_r115 No thanks never asks again, and leaves every switch off", function()
		local loaded = asked()

		press(loaded, "No thanks")

		assert.is_false(letterOf(loaded):IsShown())
		assert.are.same({ "declined" }, { letterState(loaded) })
		assert.is_nil(stored(loaded))
		assert.is_false(loaded.ns.PartyOption("share"))
		assert.is_false(loaded.ns.PartyOption("show"))
		assert.is_false(loaded.ns.PartyHuntsOn())

		local later = loggedIn(party(), loaded.env.PagleDB, {
			GetServerTime = function()
				return SERVER_TIME + 30 * DAY
			end,
		})
		hello(later)
		cast(later)
		assert.is_false(shows(later))
	end)

	it(
		"sign_r40 holds a news sign asked for while the letter shows, and drops it once No thanks answers (ONB-R17)",
		function()
			local loaded = asked()

			loaded.ns.DropNewsSign(nil, loaded.ns.NewsSignSample("legend"))
			loaded.client.advance(1)
			assert.is_nil(loaded.ns.NewsSignState())
			press(loaded, "No thanks")
			loaded.client.advance(0)
			loaded.client.advance(0)

			assert.is_false(letterOf(loaded):IsShown())
			assert.is_not_nil(loaded.ns.NewsSignState())
		end
	)

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
		assert.is_nil(loaded.ns.db.profile.partyHunts)
		assert.is_nil(loaded.env.PagleDB.global.onboarding.letters)
		assert.is_nil(loaded.env.PagleDB.global.onboarding.laterAt)
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
					.. " catches, cheer theirs, and count each other’s catches toward your Hunts.",
				frame.line.text
			)
			press(loaded, "No thanks")
			assert.are.equal("declined", (letterState(loaded)))

			slash(loaded, "dev party letter")
			press(loaded, "Fish together")
			assert.are.equal("opened", (letterState(loaded)))
			assert.is_true(loaded.ns.PartyOption("share"))
			assert.is_true(loaded.ns.PartyHuntsOn())

			slash(loaded, "dev party letter reset")
			assert.is_false(loaded.ns.PartyOption("share"))
			assert.is_false(loaded.ns.PartyHuntsOn())
			assert.is_nil((letterState(loaded)))
		end
	)

	it(
		"ann_r116 names the made-up groupmate in the sample and the dev command, never a real one in the zone",
		function()
			-- Arwen, a Pagle groupmate, fishes the player's zone: the real letter would name her.
			local loaded = loggedIn(party(DUROTAR))
			hello(loaded, "Arwen-Testrealm")
			local stop
			for _, listed in ipairs(loaded.ns.tourStops:List(loaded.ns.Modules:Modules(), "core")) do
				if listed.name == "core.onboarding.letter.core.party" then
					stop = listed
				end
			end

			assert(stop, "no tour stop for the party letter").show()
			assert.matches("^Kukli Emnabi is fishing Elwynn Forest", letterOf(loaded).line.text)
			stop.hide()

			slash(loaded, "dev on")
			slash(loaded, "dev party letter")
			assert.matches("^Kukli Emnabi is fishing Elwynn Forest", letterOf(loaded).line.text)
			press(loaded, "Not now")
		end
	)
end)

describe("the party letter on the letter service (ANN-R115, ONB-R15, ONB-R16; from 1.6, #665)", function()
	it("ann_r115 is the service's own letter: its third button, live words and asking again a day on", function()
		local loaded = loggedIn(nil)
		local spec = assert(loaded.ns.letter:Spec(ID))

		assert.are.equal("No thanks", spec.decline)
		assert.are.equal(DAY, spec.again)
		assert.are.equal("function", type(spec.words))
		assert.are.equal("function", type(spec.isDue))
	end)

	it("ann_r115 leaves no workaround in the adapter: no letter extras, no answer kept beside the switches", function()
		local loaded = loggedIn(party())
		hello(loaded)
		cast(loaded)
		press(loaded, "Not now")

		assert.is_nil(rawget(loaded.ns, "letterExtras"))
		assert.is_nil(stored(loaded))
		assert.are.equal("later", (letterState(loaded)))
	end)
end)

describe("1.5.3's answer, moved into the letter service (ANN-R117)", function()
	-- The onboarding state as 1.5.3 saved it for a returning Angler, with `letters` and `laterAt` as given.
	local function onboardingState(letters, laterAt)
		return {
			letter = "returning",
			stepsSeen = {},
			guideDone = false,
			skipped = false,
			reopen = false,
			notesOn = false,
			notesSeen = {},
			looksSeen = {},
			evening = { shown = false, closed = false, done = {} },
			characters = {},
			letters = letters,
			laterAt = laterAt,
		}
	end

	-- A PagleDB as 1.5.3 left it (schemaVersion 3): `profiles` by name, the service's state `letters`.
	local function from153(profiles, letters)
		return { global = { schemaVersion = 3, onboarding = onboardingState(letters) }, profiles = profiles }
	end

	-- 1.5.3's Fish together, Not now and No thanks, as profile.party kept them (ANN-R115 as 1.5.3 had it), each a new
	-- table, since the migration changes it.
	local function accepted()
		return { optIn = 1, share = true, show = true, sounds = true, letter = "accepted" }
	end
	local function notNow(at)
		return { optIn = 1, letter = "later", laterAt = at }
	end
	local function declined()
		return { optIn = 1, letter = "declined" }
	end

	it("ann_r117 keeps Party Hunts on for a player who accepted it, and never asks again", function()
		local loaded = loggedIn(party(), from153({ Default = { party = accepted() } }, { [ID] = "opened" }))

		assert.is_true(loaded.ns.PartyHuntsOn())
		assert.is_true(loaded.ns.PartyOption("share"))
		assert.is_true(loaded.ns.PartyOption("show"))
		assert.are.equal("opened", (letterState(loaded)))
		assert.is_nil(stored(loaded).letter)
		assert.are.equal(4, loaded.env.PagleDB.global.schemaVersion)
		hello(loaded)
		sent(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
		assert.are.equal(1, #sent(loaded, "PagleCatch"))
	end)

	it("ann_r117 keeps a Not now: asked again 24 h after it, not before, with Party Hunts off", function()
		-- 1.5.3's service had stepped the letter to declined after two Not nows; profile.party is the answer.
		local at = SERVER_TIME - 3600
		local saved = from153({ Default = { party = notNow(at) } }, { [ID] = "declined" })

		local soon = loggedIn(party(), saved)
		assert.are.same({ "later", at }, { letterState(soon) })
		assert.is_nil(stored(soon).letter)
		assert.is_nil(stored(soon).laterAt)
		assert.is_false(soon.ns.PartyHuntsOn())
		hello(soon)
		cast(soon)
		assert.is_false(shows(soon))

		local day = loggedIn(party(), soon.env.PagleDB, {
			GetServerTime = function()
				return at + DAY + 60
			end,
		})
		hello(day)
		cast(day)
		assert.is_true(shows(day))
	end)

	it("ann_r117 keeps a No thanks: never asked again, Party Hunts off", function()
		local loaded = loggedIn(party(), from153({ Default = { party = declined() } }, { [ID] = "later" }))

		assert.are.equal("declined", (letterState(loaded)))
		assert.is_false(loaded.ns.PartyHuntsOn())
		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
	end)

	it("ann_r117 drops the service's own state where no profile answered, unless the letter was waiting", function()
		local stale = loggedIn(party(), from153({ Default = { party = { optIn = 1 } } }, { [ID] = "declined" }))
		assert.is_nil((letterState(stale)))
		hello(stale)
		cast(stale)
		assert.is_true(shows(stale))

		local waiting = loggedIn(party(), from153({}, { [ID] = "waiting" }))
		assert.are.equal("waiting", (letterState(waiting)))
	end)

	it("ann_r117 takes the strongest answer of every profile, Party Hunts on only where it was accepted", function()
		local saved = from153({
			Default = { party = notNow(SERVER_TIME - 60) },
			Alt = { party = declined() },
			Main = { party = accepted() },
		})

		local loaded = loggedIn(nil, saved)

		local profiles = loaded.env.PagleDB.profiles
		assert.are.equal("opened", (letterState(loaded)))
		assert.is_true(profiles.Main.partyHunts)
		assert.is_nil(profiles.Alt.partyHunts)
		assert.is_nil(profiles.Default.partyHunts)
		for _, name in ipairs({ "Default", "Alt", "Main" }) do
			assert.are.same({ name }, { name, profiles[name].party.letter, profiles[name].party.laterAt })
		end
	end)

	it("ann_r117 changes nothing for a 1.5.2 player's kept choice: still never asked, Party Hunts off", function()
		local loaded = loggedIn(party(), from153({ Default = { party = { share = false } } }))

		assert.is_nil((letterState(loaded)))
		assert.is_false(loaded.ns.PartyHuntsOn())
		assert.is_true(loaded.ns.PartyOption("show"))
		hello(loaded)
		cast(loaded)
		assert.is_false(shows(loaded))
	end)
end)
