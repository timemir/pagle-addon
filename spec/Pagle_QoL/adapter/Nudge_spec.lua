-- Nudges (QOL-R75, QOL-R76): one line of QoL's own at the top centre, shown with ns.ShowNudge, driven through
-- FakePagle and the fake client's frames.

-- QoL loaded against FakePagle and logged in.
---@return FakePagle fake
---@return LoadedAddon loaded
local function start()
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, loaded
end

-- The Nudge's frame, found as the frame that says something (`message`, its plain text), and what it says; nil
-- before the first Nudge.
---@param client FakeClient
---@return table? frame
---@return { text: string }? line
local function nudgeOf(client)
	for _, frame in ipairs(client.frames) do
		if frame.message then
			return frame, { text = frame.message }
		end
	end
	return nil
end

-- The Nudge's frame and what it says, which must be there.
---@param client FakeClient
---@return table frame
---@return { text: string } line
local function theNudge(client)
	local frame, line = nudgeOf(client)
	return assert(frame), assert(line)
end

-- The font strings and key caps on the strip that show now, left to right: the first anchored to the strip, each
-- after it to the one before.
---@param frame table
---@return table[]
local function strung(frame)
	local shown = {}
	for _, child in ipairs(frame.children) do
		if child.shown and (child.kind == "FontString" or child.Text) then
			shown[#shown + 1] = child
		end
	end
	local found, after = {}, frame
	while true do
		local nextPiece
		for _, piece in ipairs(shown) do
			if piece.points[1][2] == after then
				nextPiece = piece
			end
		end
		if not nextPiece then
			return found
		end
		found[#found + 1] = nextPiece
		after = nextPiece
	end
end

-- The pieces on the strip that show now, left to right (see strung), as their texts: a key as "[G]", red words as
-- "*Pagle: Swap gear*".
---@param frame table
---@return string[]
local function pieces(frame)
	local texts = {}
	for i, piece in ipairs(strung(frame)) do
		if piece.Text then
			texts[i] = "[" .. piece.Text.text .. "]"
		else
			local red = piece.fontObject.name == "PagleQoLNudgeEm"
			texts[i] = red and ("*" .. piece.text .. "*") or piece.text
		end
	end
	return texts
end

describe("A Nudge", function()
	it("is one line on QoL's own strip, 4 px below UIErrorsFrame at the top centre (QOL-R75)", function()
		local _, loaded = start()
		assert.is_nil(nudgeOf(loaded.client))

		loaded.ns.ShowNudge("Your lure is gone and there are none left in your bags.")

		local frame, line = theNudge(loaded.client)
		assert.are.equal(loaded.env.UIParent, frame.parent)
		assert.are.same({ { "TOP", loaded.env.UIErrorsFrame, "BOTTOM", 0, -4 } }, frame.points)
		assert.are.equal("Your lure is gone and there are none left in your bags.", line.text)
		assert.are.same({ "Your lure is gone and there are none left in your bags." }, pieces(frame))
		-- The kit's paper strip, Core's field art, three-sliced to the line: 30 px of paper either side.
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\field\\Field", frame.middle.texture)
		assert.are.equal(#"Your lure is gone and there are none left in your bags." * 6 + 60, frame.width)
		assert.is_true(frame.shown)
		assert.are.equal(1, frame.alpha)
	end)

	it("puts a key on a brass cap and a binding's name in red, and reuses them (QOL-R75, QOL-R77)", function()
		local _, loaded = start()
		local ns = loaded.ns

		ns.ShowNudge(ns.SwapBackNudge("G"))
		local frame, line = theNudge(loaded.client)
		assert.are.same({ "Still holding your pole. Press", "[G]", "to swap back." }, pieces(frame))
		assert.are.equal("Still holding your pole. Press G to swap back.", line.text)

		ns.ShowNudge(ns.SwapBackNudge(nil))
		assert.are.same(
			{ "Still holding your pole. Bind", "*Pagle: Swap gear*", "to swap back in one press." },
			pieces(frame)
		)

		local frames = #loaded.client.frames
		ns.ShowNudge(ns.SwapBackNudge("s-G"))
		assert.are.same({ "Still holding your pole. Press", "[s-G]", "to swap back." }, pieces(frame))
		assert.are.equal(frames, #loaded.client.frames)
	end)

	it(
		"sets each piece 8 px past the right end of the one before as it draws, a name in print on the hand's line (QOL-R75)",
		function()
			local _, loaded = start()
			local ns = loaded.ns

			ns.ShowNudge(ns.SwapBackNudge(nil))

			local frame = theNudge(loaded.client)
			local words, name, rest = unpack(strung(frame))
			-- 30 px of paper, then each piece's left end on the right end of the one before, so a piece drawn wider than
			-- it measured never runs into the next; the red words' middle 1 px down, the hand's back on the line.
			assert.are.same({ "LEFT", frame, "LEFT", 30, 0 }, words.points[1])
			assert.are.same({ "LEFT", words, "RIGHT", 8, -1 }, name.points[1])
			assert.are.same({ "LEFT", name, "RIGHT", 8, 1 }, rest.points[1])
			-- IM Fell English at 19, near the height of Caveat at 24, so it sits on the line, not a small chip in it.
			assert.are.same(
				{ "PagleQoLNudgeEm", "Interface\\AddOns\\Pagle\\media\\fonts\\IMFeENrm28P.ttf", 19 },
				{ name.fontObject.name, name.fontObject.font[1], name.fontObject.font[2] }
			)
			assert.are.same({ "PagleQoLNudge", 24 }, { words.fontObject.name, words.fontObject.font[2] })

			ns.ShowNudge(ns.SwapBackNudge("G"))
			local press, key, back = unpack(strung(frame))
			-- A key's cap is as wide as it is set, and sits 2 px up.
			assert.are.same({ "LEFT", press, "RIGHT", 8, 2 }, key.points[1])
			assert.are.same({ "LEFT", key, "RIGHT", 8, -2 }, back.points[1])
		end
	)

	it("shows for 3 s, fades out over 0.5 s, then hides (QOL-R75)", function()
		local _, loaded = start()
		local client = loaded.client
		loaded.ns.ShowNudge("A Nudge")
		local frame = theNudge(client)

		client.update(2)
		client.update(1)
		assert.are.equal(1, frame.alpha)
		client.update(0.25)
		assert.are.equal(0.5, frame.alpha)
		client.update(0.25)
		assert.is_false(frame.shown)
		assert.is_nil(frame.scripts.OnUpdate)
	end)

	it("goes at once after its 3 s with Core's Animations setting off, without a fade (QOL-R75)", function()
		local fake, loaded = start()
		local client = loaded.client
		fake.profile.announcements.motion = false
		loaded.ns.ShowNudge("A Nudge")
		local frame = theNudge(client)

		client.update(3)
		local held = { frame.shown, frame.alpha }
		client.update(0.05)

		assert.are.same({ true, 1 }, held)
		assert.is_false(frame.shown)
		assert.is_nil(frame.scripts.OnUpdate)
	end)

	it("replaces the one showing, and shows its full 3 s (QOL-R75)", function()
		local _, loaded = start()
		local client = loaded.client
		loaded.ns.ShowNudge("The first")
		client.update(3.25)

		loaded.ns.ShowNudge("The second")
		local frame, line = theNudge(client)
		assert.are.equal("The second", line.text)
		assert.are.equal(1, frame.alpha)
		client.update(3)
		assert.are.equal(1, frame.alpha)

		local frames = #client.frames
		loaded.ns.ShowNudge("The third")
		assert.are.equal(frames, #client.frames)
	end)

	it("is silent and goes through no Core call but the Animations setting's: no Announcement (QOL-R76)", function()
		local fake, loaded = start()
		local sounds = {}
		for _, name in ipairs({ "PlaySound", "PlaySoundFile" }) do
			loaded.env[name] = function(...)
				sounds[#sounds + 1] = { name, ... }
			end
		end
		-- A spy on every Pagle call and every method of QoL's Module handle (ADR 0007: Core alone presents
		-- Announcements). The handle's methods live on its metatable, so each spy shadows one on the handle itself.
		local coreCalls = {}
		---@param target table
		---@param label string
		---@param functions table<string, any>
		local function spyOn(target, label, functions)
			for name, fn in pairs(functions) do
				if type(fn) == "function" then
					target[name] = function(...)
						coreCalls[#coreCalls + 1] = label .. name
						return fn(...)
					end
				end
			end
		end
		local module = assert(loaded.ns.Module)
		local methods = {}
		for name, fn in pairs(getmetatable(module).__index) do
			methods[name] = fn
		end
		for name, fn in pairs(module) do
			methods[name] = fn
		end
		spyOn(fake.Pagle, "Pagle.", fake.Pagle)
		spyOn(module, "M:", methods)
		-- The spies see what QoL calls: Pagle through its read-only global, and the handle's methods.
		loaded.env.Pagle.IsRestricted()
		assert.is_function(rawget(module, "AddSetting"))
		assert.are.same({ "Pagle.IsRestricted" }, coreCalls)
		coreCalls = {}

		loaded.ns.ShowNudge("A Nudge")
		-- Only the Nudge's own frame runs: client.update would also run the Fishing key's tick, which reads Core.
		local frame = theNudge(loaded.client)
		while frame.scripts.OnUpdate do
			frame.scripts.OnUpdate(frame, 0.25)
		end

		assert.is_false(frame.shown)
		-- Its fade reads the Animations setting (QOL-R75), and nothing else of Core's.
		for _, call in ipairs(coreCalls) do
			assert.are.equal("Pagle.IsAnimationsOn", call)
		end
		assert.are.same({}, sounds)
		assert.are.same({}, fake.printed)
		assert.are.same({}, loaded.printed)
	end)

	it("still shows in combat, under lockdown (QOL-R76, QOL-R93)", function()
		local fake, loaded = start()
		fake.setRestricted(true)
		loaded.env.InCombatLockdown = function()
			return true
		end

		loaded.ns.ShowNudge("A Nudge")

		local frame, line = theNudge(loaded.client)
		assert.is_true(frame.shown)
		assert.are.equal("A Nudge", line.text)
	end)
end)
