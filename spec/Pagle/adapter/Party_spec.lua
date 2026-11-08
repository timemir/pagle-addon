-- Party toasts and cheers on the client, through the real TOC (announcements.md › Party toasts and cheers, ANN-R103–
-- R109, ANN-R112; settings.md SET-R36; from 1.5.2, #640): who is a Pagle groupmate, what is sent and when, what is
-- read and what is ignored, the party toast in the column behind the player's own, held in combat, silent in Cozy mode
-- and expiring, the mug and the merged cheers, the Party block's rows, and /pagle dev party.

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"
local ARRIVE, RAISE, CHEERED =
	SOUNDS .. "glass\\toast_2.ogg", SOUNDS .. "glass\\toast_1.ogg", SOUNDS .. "glass\\toast_3.ogg"
local KEEFER = 19805

-- A party of two groupmates, Kukli (with Forever's surname) and Arwen.
local function party()
	return { members = { { name = "Kukli", surname = "Stonebrew" }, { name = "Arwen" } } }
end

-- Core logged in on Forever over a log of two old Casts, with `group` (none: alone), the Ledger registered and every
-- login frame run; Margin notes off, so only the Announcements' own sounds play. The party letter accepted (Fish
-- together, ANN-R113, ANN-R115), so the party features are on, unless `unasked`.
local function loggedIn(group, unasked)
	local loaded = loadCore(history(2))
	loaded.env.PagleDB.global.onboarding.notesOn = false
	if not unasked then
		loaded.ns.db.profile.party = { optIn = 1, share = true, show = true, sounds = true, letter = "accepted" }
	end
	loaded.client.group = group
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	enterWorld(loaded, 3)
	return loaded, M
end

-- The texts Core sent on the prefix Pagle, in order, and forgets them.
local function sent(loaded)
	local texts = {}
	for _, message in ipairs(loaded.client.addonMessages) do
		assert.are.equal("Pagle", message.prefix)
		assert.are.equal("PARTY", message.chatType)
		texts[#texts + 1] = message.text
	end
	loaded.client.addonMessages = {}
	return texts
end

-- A message arriving on the prefix Pagle from `sender` (Kukli on the player's realm by default), on the party channel
-- unless `channel` says otherwise.
local function receive(loaded, text, sender, channel, prefix)
	loaded.client.fire(
		"CHAT_MSG_ADDON",
		prefix or "Pagle",
		text,
		channel or "PARTY",
		sender or "Kukli-Testrealm",
		"",
		0,
		0,
		"",
		0
	)
end

-- In a party, past the hello at login, with Kukli (and Arwen too, `both`) known to run Pagle; `profile` set over
-- PagleDB.profile first, one key at a time.
local function inParty(both, profile)
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
	receive(loaded, "1:H:0", "Kukli-Testrealm")
	if both then
		receive(loaded, "1:H:0", "Arwen-Testrealm")
	end
	sent(loaded)
	return loaded, M
end

-- The party toast on screen: its frame, or nil.
local function partyToast(loaded)
	local frame = loaded.ns.announcementFrames.party
	return frame and frame.display and frame or nil
end

-- The headline title of what the frame for `form` shows, or nil.
local function showing(loaded, form)
	local frame = loaded.ns.announcementFrames[form]
	return frame and frame.display and frame.display.announcement.headline.title or nil
end

-- Raises each moment, then runs the next frame, where Core flushes them.
local function raise(loaded, M, ...)
	for i = 1, select("#", ...) do
		M:RaiseMoment((select(i, ...)))
	end
	loaded.client.advance(0)
end

local function legend(extra)
	local moment = { rung = "splash", kind = "legend", title = "Legend", icon = KEEFER, party = "legend" }
	for key, value in pairs(extra or {}) do
		moment[key] = value
	end
	return moment
end

local function sounds(loaded)
	local played = loaded.client.sounds
	loaded.client.sounds = {}
	return played
end

describe("party detection", function()
	it("says hello at login in a party, and not alone or in a raid (ANN-R103)", function()
		local loaded = loggedIn(party())
		loaded.client.advance(2)
		assert.are.same({ "1:H:1" }, sent(loaded))

		local alone = loggedIn(nil)
		alone.client.advance(5)
		assert.are.same({}, sent(alone))

		local raid = loggedIn({ raid = true, members = { { name = "Kukli" } } })
		raid.client.advance(5)
		assert.are.same({}, sent(raid))
	end)

	it(
		"greets a groupmate who joins once, 2 s after the roster last changed, and not again for a change with no"
			.. " newcomer (ANN-R103)",
		function()
			local loaded = loggedIn(nil)
			loaded.client.group = { members = { { name = "Kukli" } } }
			loaded.client.fire("GROUP_ROSTER_UPDATE")
			loaded.client.advance(1)
			loaded.client.fire("GROUP_ROSTER_UPDATE")
			loaded.client.advance(1.9)
			assert.are.same({}, sent(loaded))
			loaded.client.advance(0.2)
			assert.are.same({ "1:H:1" }, sent(loaded))

			loaded.client.fire("GROUP_ROSTER_UPDATE")
			loaded.client.advance(5)
			assert.are.same({}, sent(loaded))

			loaded.client.group.members[2] = { name = "Arwen" }
			loaded.client.fire("GROUP_ROSTER_UPDATE")
			loaded.client.advance(2)
			assert.are.same({ "1:H:1" }, sent(loaded))
		end
	)

	it(
		"answers a hello that asks, unless it said hello in the last 10 s, and never answers an answer (ANN-R103)",
		function()
			local loaded = loggedIn(party())
			loaded.client.advance(2)
			assert.are.same({ "1:H:1" }, sent(loaded))

			receive(loaded, "1:H:1", "Kukli-Testrealm")
			assert.are.same({}, sent(loaded))
			loaded.client.advance(10)
			receive(loaded, "1:H:1", "Arwen-Testrealm")
			assert.are.same({ "1:H:0" }, sent(loaded))
			receive(loaded, "1:H:0", "Kukli-Testrealm")
			assert.are.same({}, sent(loaded))
		end
	)

	it("forgets a groupmate who leaves, and every one when the party ends (ANN-R103)", function()
		local loaded, M = inParty()
		loaded.client.group = { members = { { name = "Arwen" } } }
		loaded.client.fire("GROUP_ROSTER_UPDATE")
		loaded.client.advance(2)
		sent(loaded)

		raise(loaded, M, legend())
		assert.are.same({}, sent(loaded))

		receive(loaded, "1:H:0", "Arwen-Testrealm")
		loaded.client.group = nil
		loaded.client.fire("GROUP_ROSTER_UPDATE")
		loaded.client.advance(2)
		loaded.client.group = { members = { { name = "Arwen" } } }
		raise(loaded, M, legend({ icon = 19803 }))
		assert.are.same({}, sent(loaded))
	end)
end)

describe("sharing a moment", function()
	it("sends a marked live moment once, as 1:M with its id, kind and item (ANN-R104)", function()
		local loaded, M = inParty()
		raise(loaded, M, legend())
		local texts = sent(loaded)
		assert.are.equal(1, #texts)
		assert.matches("^1:M:[0-9a-z]+:legend:19805$", texts[1])
		loaded.client.advance(30)
		assert.are.same({}, sent(loaded))
	end)

	it("sends each marked moment of a Cast, and gives each its own id (ANN-R104)", function()
		local loaded, M = inParty()
		raise(loaded, M, legend({ cast = "Player-1-1-1791731700-0" }), {
			rung = "banner",
			kind = "zoneMaster",
			title = "Zone Master",
			text = "Elwynn Forest",
			cast = "Player-1-1-1791731700-0",
			party = "zone",
			partyArea = 357,
		})
		local texts = sent(loaded)
		assert.are.equal(2, #texts)
		local ids = {}
		for i, text in ipairs(texts) do
			ids[i] = text:match("^1:M:([0-9a-z]+):")
		end
		assert.are_not.equal(ids[1], ids[2])
		assert.matches(":zone:357$", texts[2])
	end)

	it(
		"sends nothing with no Pagle groupmate, alone, in a raid, with Share off, or for an unmarked or summaryOnly"
			.. " moment (ANN-R104)",
		function()
			local quiet = loggedIn(party())
			quiet.client.advance(2)
			sent(quiet)
			local M = quiet.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			raise(quiet, M, legend())
			assert.are.same({}, sent(quiet))

			local loaded, L = inParty()
			raise(loaded, L, { rung = "splash", kind = "legend", title = "Legend", icon = KEEFER })
			raise(loaded, L, legend({ summaryOnly = true }))
			loaded.ns.db.profile.party = { share = false }
			raise(loaded, L, legend())
			assert.are.same({}, sent(loaded))

			loaded.ns.db.profile.party = { optIn = 1, share = true }
			loaded.client.group.raid = true
			raise(loaded, L, legend())
			assert.are.same({}, sent(loaded))
		end
	)

	it("shares a moment while Cozy mode keeps it off the player's screen (ANN-R104)", function()
		local loaded, M = inParty(false, { announcements = { cozy = true } })
		raise(loaded, M, legend({ rung = "toast" }))
		assert.are.equal(1, #sent(loaded))
	end)

	it("paces what it sends: 3 at once, then one a second, waiting through chat lockdown (ANN-R103)", function()
		local loaded, M = inParty()
		-- Past the hello's turn, so the limiter has its whole burst.
		loaded.client.advance(5)
		for i = 1, 5 do
			raise(loaded, M, legend({ icon = KEEFER + i, title = "Legend " .. i }))
		end
		assert.are.equal(3, #sent(loaded))
		loaded.client.advance(1)
		assert.are.equal(1, #sent(loaded))
		loaded.client.chatLockdown = true
		loaded.client.advance(3)
		assert.are.equal(0, #sent(loaded))
		loaded.client.chatLockdown = false
		loaded.client.advance(1)
		assert.are.equal(1, #sent(loaded))
	end)
end)

describe("receiving a groupmate's moment", function()
	it(
		"shows it as a party toast: the groupmate's name in capitals, its line, the item's icon and the mug (ANN-R106,"
			.. " ANN-R107)",
		function()
			local loaded = inParty()
			loaded.client.itemNames = { [KEEFER] = "Keefer's Angelfish" }
			receive(loaded, "1:M:abcd1:legend:" .. KEEFER)
			local toast = assert(partyToast(loaded))
			assert.are.equal("KUKLI STONEBREW", toast.kicker:GetText())
			assert.are.equal("Caught a Legend · Keefer's Angelfish", toast.line:GetText())
			assert.is_true(toast.mug:IsShown())
			assert.are.equal("Interface\\Icons\\INV_Drink_04", toast.mug.icon:GetTexture())
			assert.are.same({ 380, 50 }, { toast:GetWidth(), toast:GetHeight() })
			assert.are.equal(62, toast.display.height)
		end
	)

	it(
		"ignores a message from outside the party, from the player, on another channel or prefix, in a raid, a secret"
			.. " or a malformed one (ANN-R105)",
		function()
			local loaded = inParty()
			receive(loaded, "1:M:abcd1:legend:19805", "Stranger-Testrealm")
			receive(loaded, "1:M:abcd2:legend:19805", "Angler-Testrealm")
			receive(loaded, "1:M:abcd3:legend:19805", "Kukli-Testrealm", "WHISPER")
			receive(loaded, "1:M:abcd4:legend:19805", "Kukli-Testrealm", "PARTY", "Other")
			receive(loaded, "1:M:abcd5:legend:19805|r")
			receive(loaded, "2:M:abcd6:legend:19805")
			-- The client's secrets, for one message's text, then none again.
			local function secrets(isSecret)
				rawset(loaded.env, "issecretvalue", isSecret)
			end
			secrets(function(value)
				return value == "1:M:abcd7:legend:19805"
			end)
			receive(loaded, "1:M:abcd7:legend:19805")
			secrets(function()
				return false
			end)
			loaded.client.group.raid = true
			receive(loaded, "1:M:abcd8:legend:19805")
			loaded.client.advance(30)
			assert.is_nil(partyToast(loaded))
		end
	)

	it("takes a groupmate's moments up to 3, then one per 20 s, and each id once (ANN-R105)", function()
		local loaded = inParty()
		for i = 1, 4 do
			receive(loaded, "1:M:abcd" .. i .. ":zone:0")
		end
		receive(loaded, "1:M:abcd1:zone:0", "Kukli-Testrealm")
		local shown = 0
		for _ = 1, 20 do
			if partyToast(loaded) then
				shown = shown + 1
				loaded.ns.lanes:Dismiss(partyToast(loaded).display)
			end
			loaded.client.advance(1)
		end
		assert.are.equal(3, shown)
		receive(loaded, "1:M:abcd5:zone:0")
		assert.is_not_nil(partyToast(loaded))
	end)

	it("shows nothing with Show my party's moments off, or with the kind's switch off (ANN-R106, SET-R36)", function()
		local loaded = inParty(false, { party = { show = false } })
		receive(loaded, "1:M:abcd1:zone:0")
		assert.is_nil(partyToast(loaded))

		local kinds = inParty(false, { party = { kinds = { zone = false } } })
		receive(kinds, "1:M:abcd1:zone:0")
		assert.is_nil(partyToast(kinds))
		receive(kinds, "1:M:abcd2:ledger")
		assert.is_not_nil(partyToast(kinds))
	end)
end)

describe("naming a groupmate and their moment", function()
	it(
		"names a Zone Master's zone in the player's language, or says Zone Master for one it can't name (ANN-R106)",
		function()
			local loaded = inParty()
			loaded.client.areaNames[357] = "Feralas"
			receive(loaded, "1:M:abcd1:zone:357")
			assert.are.equal("Became Master of Feralas", assert(partyToast(loaded)).line:GetText())
			loaded.ns.lanes:Dismiss(partyToast(loaded).display)
			loaded.client.advance(1)
			receive(loaded, "1:M:abcd2:zone:9999")
			assert.are.equal("Zone Master", assert(partyToast(loaded)).line:GetText())
		end
	)

	it("names a Hunt gold's Hunt through the player's Hunts, or says a Hunt without it (ANN-R106)", function()
		local loaded = inParty()
		receive(loaded, "1:M:abcd1:gold:6303:mackerelZrun")
		assert.are.equal("Took gold in a Hunt", assert(partyToast(loaded)).line:GetText())

		local named = loggedIn(party())
		named.env.Pagle.RegisterModule({
			name = "Hunts",
			title = "Hunts",
			order = 20,
			partyHuntName = function(huntID)
				return huntID == "mackerel_run" and "Mackerel Run" or nil
			end,
		})
		named.client.advance(2)
		receive(named, "1:H:0")
		receive(named, "1:M:abcd1:gold:6303:mackerelZrun")
		assert.are.equal("Took gold in Mackerel Run", assert(partyToast(named)).line:GetText())
		named.ns.lanes:Dismiss(partyToast(named).display)
		named.client.advance(1)
		receive(named, "1:M:abcd2:gold:6303:unknownZhunt")
		assert.are.equal("Took gold in a Hunt", assert(partyToast(named)).line:GetText())
	end)

	it(
		"tells two groupmates of one first name apart by GUID, and ignores a sender it can only match by a shared first"
			.. " name (ANN-R105)",
		function()
			local loaded = loggedIn({
				members = {
					{ name = "Kukli", surname = "Stonebrew", sender = "Kukli-Testrealm" },
					{ name = "Kukli", surname = "Emnabi", guid = "Party-Emnabi", sender = "Kukli-Otherrealm" },
				},
			})
			loaded.client.advance(2)
			receive(loaded, "1:M:abcd1:zone:0", "Kukli-Otherrealm")
			assert.are.equal("Kukli Emnabi", showing(loaded, "party"))
			loaded.ns.lanes:Dismiss(partyToast(loaded).display)
			loaded.client.advance(1)
			receive(loaded, "1:M:abcd2:zone:0", "Kukli-Testrealm")
			assert.are.equal("Kukli Stonebrew", showing(loaded, "party"))
			loaded.ns.lanes:Dismiss(partyToast(loaded).display)
			loaded.client.advance(1)
			receive(loaded, "1:M:abcd3:zone:0", "Kukli")
			loaded.client.advance(1)
			assert.is_nil(partyToast(loaded))
		end
	)
end)

describe("the party toast in the column", function()
	it("waits behind the player's own toast and shows once it has gone (ANN-R106)", function()
		local loaded, M = inParty()
		raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species", text = "Nightfin Snapper" })
		receive(loaded, "1:M:abcd1:zone:0")
		assert.are.equal("New Species", showing(loaded, "toast"))
		assert.is_nil(partyToast(loaded))
		loaded.client.advance(10)
		assert.is_nil(showing(loaded, "toast"))
		assert.are.equal("Kukli Stonebrew", showing(loaded, "party"))
	end)

	it("shows one party toast at a time, in the order they came (ANN-R106)", function()
		local loaded = inParty(true)
		receive(loaded, "1:M:abcd1:zone:0", "Kukli-Testrealm")
		receive(loaded, "1:M:efgh1:ledger", "Arwen-Testrealm")
		assert.are.equal("Kukli Stonebrew", showing(loaded, "party"))
		loaded.client.advance(10)
		assert.are.equal("Arwen", showing(loaded, "party"))
	end)

	it(
		"is held in combat with the column, and one arriving in combat waits until it ends (ANN-R106, ANN-R35)",
		function()
			local loaded = inParty(true)
			receive(loaded, "1:M:abcd1:zone:0", "Kukli-Testrealm")
			assert.are.equal("Kukli Stonebrew", showing(loaded, "party"))
			setCombat(loaded, true)
			assert.is_nil(partyToast(loaded))
			receive(loaded, "1:M:efgh1:ledger", "Arwen-Testrealm")
			loaded.client.advance(30)
			assert.is_nil(partyToast(loaded))

			setCombat(loaded, false)
			loaded.client.advance(2)
			assert.are.equal("Kukli Stonebrew", showing(loaded, "party"))
			loaded.client.advance(10)
			assert.are.equal("Arwen", showing(loaded, "party"))
		end
	)

	it("goes nowhere in Cozy mode, and plays nothing (ANN-R106, ANN-R40)", function()
		local loaded = inParty(false, { announcements = { cozy = true } })
		sounds(loaded)
		receive(loaded, "1:M:abcd1:zone:0")
		loaded.client.advance(10)
		assert.is_nil(partyToast(loaded))
		assert.is_nil(showing(loaded, "nod"))
		assert.are.same({}, sounds(loaded))
	end)

	it("is dropped once it has waited 120 s (ANN-R106, ANN-R45)", function()
		local loaded = inParty()
		setCombat(loaded, true)
		receive(loaded, "1:M:abcd1:zone:0")
		loaded.client.advance(121)
		setCombat(loaded, false)
		loaded.client.advance(3)
		assert.is_nil(partyToast(loaded))
	end)

	it("steps down to a Nod with no mug once the Interruption budget is spent (ANN-R106, ANN-R31)", function()
		local loaded = inParty(false, { announcements = { budget = { on = true, count = 1, window = 300 } } })
		receive(loaded, "1:M:abcd1:zone:0")
		assert.is_not_nil(partyToast(loaded))
		loaded.client.advance(10)
		loaded.client.advance(20)
		receive(loaded, "1:M:abcd2:ledger")
		assert.is_nil(partyToast(loaded))
		assert.are.equal("Kukli Stonebrew", showing(loaded, "nod"))
		assert.are.equal("Ledger 100%", loaded.ns.announcementFrames.nod.display.announcement.headline.text)
	end)

	it(
		"plays the arrive sound as it shows, only with Cheers sounds on, and never reaches the Session summary (ANN-R106, ANN-R108)",
		function()
			local loaded = inParty()
			sounds(loaded)
			receive(loaded, "1:M:abcd1:zone:0")
			assert.are.same({ ARRIVE .. " SFX" }, sounds(loaded))
			assert.are.same({}, loaded.ns.db.global.summary.moments)

			local quiet = inParty(false, { party = { sounds = false } })
			sounds(quiet)
			receive(quiet, "1:M:abcd1:zone:0")
			assert.is_not_nil(partyToast(quiet))
			assert.are.same({}, sounds(quiet))
		end
	)
end)

describe("cheers", function()
	it(
		"raise a mug once: it goes done, sends 1:C with the moment's id and plays the raise sound, and a second click"
			.. " does nothing (ANN-R108)",
		function()
			local loaded = inParty()
			receive(loaded, "1:M:abcd1:zone:0")
			local toast = assert(partyToast(loaded))
			sounds(loaded)
			toast.mug:Click()
			assert.are.same({ "1:C:abcd1" }, sent(loaded))
			assert.are.same({ RAISE .. " SFX" }, sounds(loaded))
			assert.is_true(toast.mug.icon:IsDesaturated())
			toast.mug:Click()
			assert.are.same({}, sent(loaded))
			assert.is_not_nil(partyToast(loaded))
		end
	)

	it("keep the toast's clock stopped while the pointer is on the mug (ANN-R108)", function()
		local loaded = inParty()
		receive(loaded, "1:M:abcd1:zone:0")
		local toast = assert(partyToast(loaded))
		toast.mug.scripts.OnEnter(toast.mug)
		loaded.client.advance(30)
		assert.is_not_nil(partyToast(loaded))
		toast.mug.scripts.OnLeave(toast.mug)
		loaded.client.advance(10)
		assert.is_nil(partyToast(loaded))
	end)

	it(
		"come back as one Nod 3 s after the first: one name, two, then a count, each groupmate once, its cheered"
			.. " sound playing (ANN-R108)",
		function()
			local loaded, M = inParty(true)
			raise(loaded, M, legend({ rung = "nod" }))
			local id = sent(loaded)[1]:match("^1:M:([0-9a-z]+):")
			loaded.client.advance(5)
			sounds(loaded)

			receive(loaded, "1:C:" .. id, "Kukli-Testrealm")
			receive(loaded, "1:C:" .. id, "Kukli-Testrealm")
			loaded.client.advance(2.9)
			assert.is_nil(showing(loaded, "nod"))
			loaded.client.advance(0.2)
			assert.are.equal("Kukli Stonebrew raised a mug", showing(loaded, "nod"))
			assert.are.same({ CHEERED .. " SFX" }, sounds(loaded))
			loaded.client.advance(5)

			receive(loaded, "1:C:" .. id, "Arwen-Testrealm")
			loaded.client.advance(3.1)
			assert.are.equal("Kukli Stonebrew and Arwen raised a mug", showing(loaded, "nod"))
		end
	)

	it("wait out combat, merged, and show once it ends, not dropped as a Nod would be (ANN-R108)", function()
		local loaded, M = inParty(true)
		raise(loaded, M, legend({ rung = "nod" }))
		local id = sent(loaded)[1]:match("^1:M:([0-9a-z]+):")
		loaded.client.advance(5)
		setCombat(loaded, true)
		receive(loaded, "1:C:" .. id, "Kukli-Testrealm")
		loaded.client.advance(5)
		receive(loaded, "1:C:" .. id, "Arwen-Testrealm")
		loaded.client.advance(30)
		assert.is_nil(showing(loaded, "nod"))

		setCombat(loaded, false)
		loaded.client.advance(2.2)
		assert.are.equal("Kukli Stonebrew and Arwen raised a mug", showing(loaded, "nod"))
	end)

	it("count from three on, and ignore a cheer for an id that isn't the player's (ANN-R108)", function()
		local loaded = loggedIn({ members = { { name = "Kukli" }, { name = "Arwen" }, { name = "Bram" } } })
		local M = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
		for _, name in ipairs({ "Kukli", "Arwen", "Bram" }) do
			receive(loaded, "1:H:0", name .. "-Testrealm")
		end
		raise(loaded, M, legend({ rung = "nod" }))
		local id
		for _, text in ipairs(sent(loaded)) do
			id = id or text:match("^1:M:([0-9a-z]+):")
		end
		loaded.client.advance(5)
		for _, name in ipairs({ "Kukli", "Arwen", "Bram" }) do
			receive(loaded, "1:C:" .. id, name .. "-Testrealm")
		end
		receive(loaded, "1:C:zzzz9", "Kukli-Testrealm")
		loaded.client.advance(3.1)
		assert.are.equal("3 raised a mug", showing(loaded, "nod"))
	end)
end)

describe("the Party block (SET-R36)", function()
	local LABELS = {
		"Share my moments with my party",
		"Show my party's moments",
		"Legends",
		"Rare colours",
		"Monster-size records",
		"Gold tier in a Hunt",
		"Zone Master",
		"Prestige",
		"Ledger 100%",
		"Cheers sounds",
	}

	local function page(loaded)
		return assert(loaded.client.settings.category("Announcements"))
	end

	local function row(loaded, label)
		for _, initializer in ipairs(page(loaded).layout.initializers) do
			if initializer:GetName() == label then
				return initializer
			end
		end
		error("no row " .. label)
	end

	it("follows Toast position under a Party header, its kinds indented under Show (SET-R36)", function()
		local loaded = loggedIn(nil)
		local names = {}
		local after = false
		for _, initializer in ipairs(page(loaded).layout.initializers) do
			if after then
				names[#names + 1] = initializer:GetName()
			end
			after = after or initializer:GetName() == "Toast position"
		end
		-- From 1.6, Party Hunts heads the block (SET-R35).
		local expected = { "Party", "Party Hunts" }
		for _, label in ipairs(LABELS) do
			expected[#expected + 1] = label
		end
		assert.are.same(expected, names)
		local show = row(loaded, "Show my party's moments")
		for i = 3, 9 do
			assert.are.equal(show, row(loaded, LABELS[i]):GetParentInitializer())
		end
		assert.is_nil(row(loaded, "Cheers sounds"):GetParentInitializer())
	end)

	it(
		"starts Share and Show off with nothing stored and the rest on, stores each change of Share, Show and Cheers"
			.. " sounds as it is, a kind's off as false, and Defaults turns Share and Show off and the rest on"
			.. " (SET-R36, SET-R33, ANN-R113)",
		function()
			local loaded = loggedIn(nil, true)
			for i, label in ipairs(LABELS) do
				assert(row(loaded, label):GetSetting():GetValue() == (i > 2), label)
			end
			assert.is_nil(loaded.ns.db.profile.party)

			row(loaded, "Share my moments with my party"):GetSetting():SetValue(true)
			row(loaded, "Gold tier in a Hunt"):GetSetting():SetValue(false)
			row(loaded, "Cheers sounds"):GetSetting():SetValue(false)
			assert.are.same(
				{ optIn = 1, share = true, kinds = { gold = false }, sounds = false },
				loaded.ns.db.profile.party
			)

			row(loaded, "Gold tier in a Hunt"):GetSetting():SetValue(true)
			assert.is_nil(loaded.ns.db.profile.party.kinds.gold)

			loaded.client.settings.defaults(page(loaded))
			for i, label in ipairs(LABELS) do
				assert(row(loaded, label):GetSetting():GetValue() == (i > 2), label)
			end
			assert.are.same({ false, true }, { loaded.ns.db.profile.party.share, loaded.ns.db.profile.party.sounds })
			assert.is_nil(loaded.ns.db.profile.party.show)
		end
	)

	it(
		"greys Show, its kinds and Cheers sounds in Cozy mode, and the kinds while Show is off (SET-R36, SET-R31)",
		function()
			local loaded = loggedIn(nil)
			local shown = loaded.client.settings.show(page(loaded))
			local function live(label)
				for _, entry in ipairs(shown) do
					if entry.initializer:GetName() == label then
						return entry.frame.enabled
					end
				end
				error("not shown: " .. label)
			end
			assert.is_true(live("Legends"))
			row(loaded, "Show my party's moments"):GetSetting():SetValue(false)
			assert.is_false(live("Legends"))
			assert.is_true(live("Share my moments with my party"))
			row(loaded, "Show my party's moments"):GetSetting():SetValue(true)
			row(loaded, "Cozy mode"):GetSetting():SetValue(true)
			assert.is_false(live("Show my party's moments"))
			assert.is_false(live("Legends"))
			assert.is_false(live("Cheers sounds"))
			assert.is_true(live("Share my moments with my party"))
		end
	)
end)

describe("/pagle dev party (ANN-R109)", function()
	local function slash(loaded, line)
		loaded.env.SlashCmdList.PAGLE(line)
	end

	it("needs the dev commands on, and prints its usage alone", function()
		local loaded = loggedIn(nil)
		slash(loaded, "dev party legend")
		assert.are.equal(
			"Pagle dev: dev commands are off; /pagle dev on turns them on.",
			loaded.printed[#loaded.printed]
		)
		assert.is_nil(partyToast(loaded))
		slash(loaded, "dev on")
		slash(loaded, "dev party")
		assert.matches("^Pagle dev: /pagle dev party", loaded.printed[#loaded.printed])
		slash(loaded, "dev party nonsense")
		assert.matches("^Pagle dev: /pagle dev party", loaded.printed[#loaded.printed])
	end)

	it("fakes a party toast of a kind, alone, sending nothing, and all seven in turn", function()
		local loaded = loggedIn(nil)
		slash(loaded, "dev on")
		slash(loaded, "dev party monster")
		assert.are.equal("Kukli Emnabi", showing(loaded, "party"))
		assert.matches("^Monster%-size record", partyToast(loaded).line:GetText())
		partyToast(loaded).mug:Click()
		assert.are.same({}, sent(loaded))

		slash(loaded, "dev party all")
		local lines = {}
		for _ = 1, 80 do
			local toast = partyToast(loaded)
			if toast and lines[#lines] ~= toast.line:GetText() then
				lines[#lines + 1] = toast.line:GetText()
			end
			loaded.client.advance(1)
		end
		assert.are.equal(8, #lines)
	end)

	it("fakes cheers for a moment of the player's, merged into one Nod", function()
		local loaded = loggedIn(nil)
		slash(loaded, "dev on")
		slash(loaded, "dev party cheer 2")
		loaded.client.advance(3.1)
		assert.are.equal("Kukli Emnabi and Arwen Tull raised a mug", showing(loaded, "nod"))
		loaded.client.advance(10)
		slash(loaded, "dev party cheer 4")
		loaded.client.advance(3.1)
		assert.are.equal("4 raised a mug", showing(loaded, "nod"))
	end)
end)
