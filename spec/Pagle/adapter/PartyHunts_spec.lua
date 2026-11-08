-- A Party Catch's moments and "Completed for the party" on the client, through the real TOC (announcements.md › Party
-- Catches and the party, ANN-R110, ANN-R111; settings.md SET-R35, SET-R36; from 1.6, #646): the Angler's own moments
-- for a Party Catch merged by its entry ID, and the hp party toast, sent for a live moment that carries partyCatch and
-- shown to every groupmate, the catcher as "Your catch", merged per Catch and Hunt, behind the player's own toasts,
-- held in combat, silent in Cozy mode, and under the party switches and Party Hunts.

local TRADE_FISHING = "Interface\\Icons\\Trade_Fishing"
-- A Party Catch's entry ID: the receiver's own header (LOG-R115), here the player's GUID.
local G1 = "Player-1-00000001-1791731700-0"
-- A groupmate's source Catch ID (LOG-R116), item 1 of their Cast at 1791731700.
local SOURCE = "Player-4701-0A1B2C3D-1791731700-0:1"
local THEIRS = SOURCE
-- A source Catch ID of the player's own, as a groupmate's hp names it: PLAYER_GUID is "Player-1-00000001".
local MINE = "Player-1-00000001-1791731700-0:1"

-- A party of two groupmates, Kukli (with Forever's surname) and Arwen.
local function party()
	return { members = { { name = "Kukli", surname = "Stonebrew" }, { name = "Arwen" } } }
end

-- Core logged in on Forever over a log of two old Casts, with `group` (none: alone), Hunts registered with names for
-- one Hunt and one event, and every login frame run; Margin notes off.
local function loggedIn(group)
	local loaded = loadCore(history(2))
	loaded.env.PagleDB.global.onboarding.notesOn = false
	loaded.client.group = group
	local M = loaded.env.Pagle.RegisterModule({
		name = "Hunts",
		title = "Hunts",
		order = 20,
		partyHuntName = function(huntID)
			return huntID == "mackerel_run" and "Mackerel Run" or nil
		end,
		partyEventName = function(eventID)
			return eventID == "darkshore_moonlight" and "Grouper by Moonlight" or nil
		end,
	})
	enterWorld(loaded, 3)
	return loaded, M
end

-- The texts Core sent on either prefix, as "<prefix> <text>", in order, and forgets them.
local function sent(loaded)
	local texts = {}
	for _, message in ipairs(loaded.client.addonMessages) do
		assert.are.equal("PARTY", message.chatType)
		texts[#texts + 1] = message.prefix .. " " .. message.text
	end
	loaded.client.addonMessages = {}
	return texts
end

-- Only the hp messages of `sent`, each on the prefix PagleCatch (LOG-R110), as their text.
local function sentHp(loaded)
	local texts = {}
	for _, text in ipairs(sent(loaded)) do
		local hp = text:match("^PagleCatch (hp|.*)$")
		assert.is_nil(text:find("^Pagle hp|"))
		if hp then
			texts[#texts + 1] = hp
		end
	end
	return texts
end

-- A message arriving on the prefix PagleCatch (or `prefix`) from `sender` (Kukli on the player's realm by default), on
-- the party channel.
local function receive(loaded, text, sender, prefix)
	loaded.client.fire(
		"CHAT_MSG_ADDON",
		prefix or "PagleCatch",
		text,
		"PARTY",
		sender or "Kukli-Testrealm",
		"",
		0,
		0,
		"",
		0
	)
end

-- In a party, past the hello at login; `profile` set over PagleDB.profile first, one key at a time.
local function inParty(profile)
	local loaded, M = loggedIn(party())
	for key, value in pairs(profile or {}) do
		if type(value) == "table" and type(loaded.ns.db.profile[key]) == "table" then
			for field, inner in pairs(value) do
				loaded.ns.db.profile[key][field] = inner
			end
		else
			loaded.ns.db.profile[key] = value
		end
	end
	loaded.client.advance(2)
	sent(loaded)
	return loaded, M
end

-- The party toast on screen: its frame, or nil.
local function partyToast(loaded)
	local frame = loaded.ns.announcementFrames.party
	return frame and frame.display and frame or nil
end

-- What the party toast on screen reads: its kicker and its line, or nil.
local function reads(loaded)
	local toast = partyToast(loaded)
	return toast and { toast.kicker:GetText(), toast.line:GetText() } or nil
end

-- The Nod on screen, or nil.
local function nodShown(loaded)
	local frame = loaded.ns.announcementFrames.nod
	return frame and frame.display or nil
end

-- Raises each moment, then runs the next frame, where Core flushes them.
local function raise(loaded, M, ...)
	for i = 1, select("#", ...) do
		M:RaiseMoment((select(i, ...)))
	end
	loaded.client.advance(0)
end

-- Hunts' moment for a Hunt a Party Catch completed (HNT-R185), as #645's Hunts raises it.
local function completed(extra)
	local moment = {
		rung = "toast.high",
		kind = "huntCompleted",
		title = "Hunt completed",
		text = "Mackerel Run · with Kukli Stonebrew",
		cast = G1,
		partyCatch = SOURCE,
		partyHunt = "mackerel_run",
	}
	for key, value in pairs(extra or {}) do
		moment[key] = value
	end
	return moment
end

describe("the Angler's own moments for a Party Catch (ANN-R110)", function()
	it("merge by the Party Catch's entry ID into one Announcement, the groupmate named in its text", function()
		local loaded, M = inParty()
		raise(loaded, M, completed(), {
			rung = "banner",
			kind = "huntSetTitle",
			title = "Title earned",
			text = "Tidewatcher · with Kukli Stonebrew",
			stamp = "Title",
			cast = G1,
		})
		local big = loaded.ns.announcementFrames.banner
		local shown = big and big.display and big.display.announcement
		assert(shown, "no banner")
		assert.are.equal("Tidewatcher · with Kukli Stonebrew", shown.headline.text)
		local toast = loaded.ns.announcementFrames.toast
		assert.are.equal("Mackerel Run · with Kukli Stonebrew", toast.display.announcement.headline.text)
	end)

	it("keep the source Catch ID out of the Session summary: partyCatch is never stored (LOG-R116)", function()
		local loaded, M = inParty()
		raise(loaded, M, completed())
		-- With no Session open, the summary keeps it pending (ANN-R52).
		local global = loaded.ns.db.global
		local moments = #global.summary.moments > 0 and global.summary.moments or global.pending
		assert.are.equal(1, #moments)
		assert.are.equal("Mackerel Run · with Kukli Stonebrew", moments[1].text)
		assert.is_nil(moments[1].partyCatch)
		assert.is_nil(moments[1].partyHunt)
	end)

	it("are dropped, and share nothing, when a rebuild raises them: no name and no hp (ANN-R4, LOG-R75)", function()
		local loaded = loadCore(history(3, 1791731000))
		loaded.client.group = party()
		local reported = {}
		loaded.env.geterrorhandler = function()
			return function(err)
				reported[#reported + 1] = tostring(err)
			end
		end
		local M = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
		M:NewProjection({
			db = {},
			rulesVersion = 1,
			reset = function()
				return {}
			end,
			apply = function(_, record)
				if record.kind == "cast" then
					M:RaiseMoment(completed({ cast = record.id }))
				end
			end,
		})
		enterWorld(loaded)
		loaded.client.runTimers()
		loaded.client.advance(10)
		assert.are.same({}, sentHp(loaded))
		assert.are.same({}, loaded.ns.db.global.summary.moments)
		assert.matches("during a projection's rebuild apply", reported[1])
	end)
end)

describe("sending Completed for the party (ANN-R111)", function()
	it(
		"sends hp|1 once on PagleCatch for a live moment that carries partyCatch: h with its Hunt, w with its run (LOG-R110)",
		function()
			local loaded, M = inParty()
			raise(loaded, M, completed())
			assert.are.same({ "hp|1|h|mackerel_run|" .. THEIRS }, sentHp(loaded))
			raise(
				loaded,
				M,
				completed({
					kind = "wagerSettled",
					title = "Wager settled",
					partyHunt = false,
					partyEvent = "darkshore_moonlight",
				})
			)
			assert.are.same({ "hp|1|w|darkshore_moonlight|" .. THEIRS }, sentHp(loaded))
			loaded.client.advance(30)
			assert.are.same({}, sentHp(loaded))
		end
	)

	it("sends it while Cozy mode keeps the moment off the player's screen, and with no hello answered yet", function()
		local loaded, M = inParty({ announcements = { cozy = true } })
		raise(loaded, M, completed())
		assert.are.equal(1, #sentHp(loaded))
	end)

	it(
		"sends nothing with Party Hunts off, with Share off, alone, in a raid, or with no partyCatch (LOG-R121)",
		function()
			local loaded, M = inParty({ partyHunts = false })
			raise(loaded, M, completed())
			assert.are.same({}, sentHp(loaded))

			loaded.ns.db.profile.partyHunts = nil
			loaded.ns.db.profile.party = { share = false }
			raise(loaded, M, completed())
			assert.are.same({}, sentHp(loaded))

			loaded.ns.db.profile.party = nil
			raise(loaded, M, completed({ partyCatch = false }))
			local summaryOnly = completed({ summaryOnly = true })
			summaryOnly.cast = nil
			raise(loaded, M, summaryOnly)
			assert.are.same({}, sentHp(loaded))

			loaded.client.group.raid = true
			raise(loaded, M, completed())
			assert.are.same({}, sentHp(loaded))

			local alone, A = loggedIn(nil)
			raise(alone, A, completed())
			assert.are.same({}, sentHp(alone))
		end
	)
end)

describe("receiving Completed for the party (ANN-R111)", function()
	it("shows a groupmate's as one compact party toast: Completed for the party, the Hunt for them, no mug", function()
		local loaded = inParty()
		receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS)
		loaded.client.advance(5)
		assert.are.same({ "COMPLETED FOR THE PARTY", "Mackerel Run · for Kukli Stonebrew" }, reads(loaded))
		local toast = assert(partyToast(loaded))
		assert.is_false(toast.mug:IsShown())
		local headline = toast.display.announcement.headline
		assert.are.same({ "toast.low", TRADE_FISHING, 0 }, { headline.rung, headline.icon, headline.coins or 0 })
		assert.are.same({ 380, 50 }, { toast:GetWidth(), toast:GetHeight() })
		-- No mug, no cheer: the hidden mug raises nothing.
		assert.is_false(loaded.ns.RaisePartyMug(toast.display))
		assert.are.same({}, sent(loaded))
		assert.are.same({}, loaded.ns.db.global.summary.moments)
	end)

	it("tells the catcher it was their Catch: Your catch", function()
		local loaded = inParty()
		receive(loaded, "hp|1|h|mackerel_run|" .. MINE)
		loaded.client.advance(5)
		assert.are.same({ "YOUR CATCH", "Mackerel Run · for Kukli Stonebrew" }, reads(loaded))
	end)

	it("names a settled run from the player's lore, or a Pagle Wager it doesn't know, and a Hunt it doesn't", function()
		local loaded = inParty()
		receive(loaded, "hp|1|w|darkshore_moonlight|" .. THEIRS)
		loaded.client.advance(5)
		assert.are.same(
			{ "COMPLETED FOR THE PARTY", "Grouper by Moonlight settled · for Kukli Stonebrew" },
			reads(loaded)
		)
		loaded.client.advance(10)
		receive(loaded, "hp|1|w|p_elsewhere|" .. THEIRS)
		loaded.client.advance(5)
		assert.are.same({ "COMPLETED FOR THE PARTY", "a Pagle Wager settled · for Kukli Stonebrew" }, reads(loaded))
		loaded.client.advance(10)
		receive(loaded, "hp|1|h|nowhere|" .. THEIRS)
		loaded.client.advance(5)
		assert.are.same({ "COMPLETED FOR THE PARTY", "a Hunt · for Kukli Stonebrew" }, reads(loaded))
	end)

	it("merges one Catch and Hunt's toasts that arrive within 5 s into one, naming every groupmate", function()
		local loaded = inParty()
		receive(loaded, "hp|1|h|mackerel_run|" .. MINE, "Kukli-Testrealm")
		loaded.client.advance(3)
		assert.is_nil(partyToast(loaded))
		receive(loaded, "hp|1|h|mackerel_run|" .. MINE, "Arwen-Testrealm")
		-- Another Hunt of the same Catch is a toast of its own.
		receive(loaded, "hp|1|w|darkshore_moonlight|" .. MINE, "Arwen-Testrealm")
		loaded.client.advance(2)
		assert.are.same({ "YOUR CATCH", "Mackerel Run · for Kukli Stonebrew and Arwen" }, reads(loaded))
		loaded.client.advance(10)
		assert.are.same({ "YOUR CATCH", "Grouper by Moonlight settled · for Arwen" }, reads(loaded))
	end)

	it("makes a new toast of one that arrives after the merge window, and of another Catch", function()
		local loaded = inParty()
		receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS, "Kukli-Testrealm")
		receive(loaded, "hp|1|h|mackerel_run|Player-4701-0A1B2C3D-1791731700-0:2", "Arwen-Testrealm")
		loaded.client.advance(6)
		receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS, "Arwen-Testrealm")
		local lines, last = {}, nil
		for _ = 1, 40 do
			local toast = partyToast(loaded)
			if toast and toast.display ~= last then
				last = toast.display
				lines[#lines + 1] = toast.line:GetText()
			end
			loaded.client.advance(1)
		end
		assert.are.same({
			"Mackerel Run · for Kukli Stonebrew",
			"Mackerel Run · for Arwen",
			"Mackerel Run · for Arwen",
		}, lines)
	end)

	it(
		"shows nothing with Party Hunts off, Show my party's moments off, or its kind's switch off (SET-R35, SET-R36)",
		function()
			for _, profile in ipairs({
				{ partyHunts = false },
				{ party = { show = false } },
				{ party = { kinds = { hp = false } } },
			}) do
				local loaded = inParty(profile)
				receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS)
				loaded.client.advance(10)
				assert.is_nil(partyToast(loaded))
				assert.is_nil(nodShown(loaded))
			end
			-- The other kinds' switches don't touch it.
			local loaded = inParty({ party = { kinds = { gold = false, legend = false } } })
			receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS)
			loaded.client.advance(5)
			assert.is_not_nil(partyToast(loaded))
		end
	)

	it("goes nowhere in Cozy mode (ANN-R106, ANN-R40)", function()
		local loaded = inParty({ announcements = { cozy = true } })
		receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS)
		loaded.client.advance(10)
		assert.is_nil(partyToast(loaded))
		assert.is_nil(nodShown(loaded))
	end)

	it("waits out combat, and is dropped once it has waited 120 s (ANN-R106, ANN-R35, ANN-R45)", function()
		local loaded = inParty()
		setCombat(loaded, true)
		receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS)
		loaded.client.advance(30)
		assert.is_nil(partyToast(loaded))
		setCombat(loaded, false)
		loaded.client.advance(3)
		assert.are.same({ "COMPLETED FOR THE PARTY", "Mackerel Run · for Kukli Stonebrew" }, reads(loaded))

		local late = inParty()
		setCombat(late, true)
		receive(late, "hp|1|h|mackerel_run|" .. THEIRS)
		late.client.advance(121)
		setCombat(late, false)
		late.client.advance(3)
		assert.is_nil(partyToast(late))
	end)

	it("waits behind the player's own toast (ANN-R106)", function()
		local loaded, M = inParty()
		raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species", text = "Nightfin Snapper" })
		receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS)
		loaded.client.advance(5)
		assert.is_nil(partyToast(loaded))
		loaded.client.advance(10)
		assert.is_not_nil(partyToast(loaded))
	end)

	it(
		"takes a groupmate's hp messages 4 at once, then one per 10 s, and ignores one from outside the party",
		function()
			local loaded = inParty()
			receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS, "Stranger-Testrealm")
			-- On 1.5.2's prefix it isn't one, and a malformed one is nothing.
			receive(loaded, "hp|1|h|mackerel_run|" .. THEIRS, nil, "Pagle")
			receive(loaded, "hp|1|h|mackerel_run|Player-4701-0A1B2C3D", nil)
			for n = 1, 5 do
				receive(loaded, "hp|1|h|mackerel_run|Player-4701-0A1B2C3D-1791731700-0:" .. n)
			end
			local count = 0
			for _ = 1, 80 do
				if partyToast(loaded) then
					count = count + 1
					loaded.ns.lanes:Dismiss(partyToast(loaded).display)
				end
				loaded.client.advance(1)
			end
			assert.are.equal(4, count)
		end
	)
end)

describe("Completed for the party in Settings (SET-R35, SET-R36)", function()
	it("has its own kind row under Show my party's moments, on by default, writing kinds.hp", function()
		local loaded = loggedIn(nil)
		local page = assert(loaded.client.settings.category("Announcements"))
		local show, row
		for _, initializer in ipairs(page.layout.initializers) do
			if initializer:GetName() == "Show my party's moments" then
				show = initializer
			elseif initializer:GetName() == "Completed for the party" then
				row = initializer
			end
		end
		assert(row, "no Completed for the party row")
		assert.are.equal(show, row:GetParentInitializer())
		assert.is_true(row:GetSetting():GetValue())
		row:GetSetting():SetValue(false)
		assert.are.same({ kinds = { hp = false } }, loaded.ns.db.profile.party)
	end)
end)

describe("/pagle dev party hp (ANN-R109, ANN-R111)", function()
	it("fakes a groupmate's Completed for the party, alone, sending nothing", function()
		local loaded = loggedIn(nil)
		loaded.env.SlashCmdList.PAGLE("dev on")
		loaded.env.SlashCmdList.PAGLE("dev party hp")
		loaded.client.advance(5)
		assert.are.same({ "COMPLETED FOR THE PARTY", "Mackerel Run · for Kukli Emnabi" }, reads(loaded))
		assert.are.same({}, sent(loaded))
	end)
end)
