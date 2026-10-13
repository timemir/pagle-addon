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

-- The Nudge's frame and its line, found as the frame holding a GameFontNormalLarge font string; nil before the
-- first Nudge.
---@param client FakeClient
---@return table? frame
---@return table? line
local function nudgeOf(client)
	for _, frame in ipairs(client.frames) do
		for _, child in ipairs(frame.children) do
			if child.kind == "FontString" and child.fontObject == "GameFontNormalLarge" then
				return frame, child
			end
		end
	end
	return nil
end

-- The Nudge's frame and its line, which must be there.
---@param client FakeClient
---@return table frame
---@return table line
local function theNudge(client)
	local frame, line = nudgeOf(client)
	return assert(frame), assert(line)
end

describe("A Nudge", function()
	it("is one line in QoL's own frame, 4 px below UIErrorsFrame at the top centre (QOL-R75)", function()
		local _, loaded = start()
		assert.is_nil(nudgeOf(loaded.client))

		loaded.ns.ShowNudge("Your lure is gone and there are none left in your bags.")

		local frame, line = theNudge(loaded.client)
		assert.are.equal(loaded.env.UIParent, frame.parent)
		assert.are.same({ { "TOP", loaded.env.UIErrorsFrame, "BOTTOM", 0, -4 } }, frame.points)
		assert.are.equal("Your lure is gone and there are none left in your bags.", line.text)
		assert.are.same({ 1, 1, 0 }, line.textColor) -- YELLOW_FONT_COLOR
		assert.is_true(frame.shown)
		assert.are.equal(1, frame.alpha)
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
