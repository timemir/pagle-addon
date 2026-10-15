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

-- The font strings and key caps on the strip that show now, left to right, as their texts: a key as "[G]", red words
-- as "*Pagle: Swap gear*".
---@param frame table
---@return string[]
local function pieces(frame)
	local shown = {}
	for _, child in ipairs(frame.children) do
		if child.shown and child.kind == "FontString" then
			local red = child.fontObject.name == "PagleQoLNudgeEm"
			shown[#shown + 1] = { x = child.points[1][4], text = red and ("*" .. child.text .. "*") or child.text }
		elseif child.shown and child.Text then
			shown[#shown + 1] = { x = child.points[1][4], text = "[" .. child.Text.text .. "]" }
		end
	end
	table.sort(shown, function(a, b)
		return a.x < b.x
	end)
	local texts = {}
	for i, piece in ipairs(shown) do
		texts[i] = piece.text
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

	it("is silent and goes through no Core call: no Announcement (QOL-R76)", function()
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
		assert.are.same({}, coreCalls)
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
