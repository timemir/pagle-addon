-- `/pagle dev tour` on Core's real TOC and the fake client (CORE-R65–R68): Core's own stops (each Announcement form,
-- the cards, the Curio Shop, the Field report box, the glyph panel and the Settings pages), shot with Screenshot()
-- and each put back as it was.

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- Whether `frame` and every parent above it are shown.
local function visible(frame)
	while frame do
		if not frame:IsShown() then
			return false
		end
		frame = frame:GetParent()
	end
	return true
end

-- Every frame on screen now, as a set, with the Settings panel.
local function onScreen(loaded)
	local set = {}
	for _, frame in ipairs(loaded.client.frames) do
		if visible(frame) then
			set[frame] = true
		end
	end
	local panel = loaded.client.settings.panel
	if panel.shown then
		set[panel] = true
	end
	return set
end

-- How many frames are in `set` and not in `before`.
local function added(set, before)
	local n = 0
	for frame in pairs(set) do
		if not before[frame] then
			n = n + 1
		end
	end
	return n
end

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

-- Core loaded, logged in and settled, with a Module that adds a Fishing row, dev on and the chat read.
local function touring()
	local loaded = loadCore({ BUILD_ENTRY })
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	M:AddSetting("fishing", { kind = "header", label = "A Ledger row" })
	enterWorld(loaded, 3)
	pagle(loaded, "dev on")
	for i = #loaded.printed, 1, -1 do
		loaded.printed[i] = nil
	end
	return loaded
end

describe("Core's own tour stops (CORE-R65, CORE-R68)", function()
	it(
		"are each Announcement form, both cards, the shop, the Field report, the glyphs, each Settings page, the First"
			.. " evening list and each Field guide step (ONB-R84)",
		function()
			local loaded = touring()

			pagle(loaded, "dev tour list core")

			assert.are.same({
				"Pagle dev: 18 tour stops:",
				"  core.announce.toast: a sample toast",
				"  core.announce.nod: a sample nod",
				"  core.announce.banner: a sample banner",
				"  core.announce.splash: a sample splash",
				"  core.card.session: a sample session card",
				"  core.card.writeup: a sample writeup card",
				"  core.shop: the Curio Shop",
				"  core.fieldreport: the Field report box",
				"  core.glyphs: the glyph probe panel",
				"  core.onboarding.evening: the First evening list",
				"  core.settings: Settings: Pagle",
				"  core.settings.fishing: Settings: Fishing",
				"  core.settings.announcements: Settings: Announcements",
				"  core.settings.look: Settings: Look and Feel",
				"  core.onboarding.step.welcome: the Field guide at its welcome step",
				"  core.onboarding.step.box: the Field guide at its box step",
				"  core.onboarding.step.moments: the Field guide at its moments step",
				"  core.onboarding.step.off: the Field guide at its off step",
			}, loaded.printed)
		end
	)

	it("each put something on screen for its screenshot, with Screenshot()", function()
		local loaded = touring()
		local before = onScreen(loaded)
		local shown = {}
		loaded.env.Screenshot = function()
			shown[#shown + 1] = added(onScreen(loaded), before)
		end

		pagle(loaded, "dev tour core")
		loaded.client.advance(90)

		assert.are.equal(18, #shown)
		for i, n in ipairs(shown) do
			assert(n > 0, "stop " .. i .. " showed nothing")
		end
	end)

	it("leave the screen and PagleDB as they were, and print each stop's line", function()
		local loaded = touring()
		local before = onScreen(loaded)
		local saved = copy(loaded.env.PagleDB)

		pagle(loaded, "dev tour core")
		loaded.client.advance(90)

		assert.are.equal(0, added(onScreen(loaded), before))
		assert.are.equal(18, loaded.client.screenshots)
		assert.are.same(saved, loaded.env.PagleDB)
		assert.are.equal("Pagle dev: tour 1/18: core.announce.toast", loaded.printed[2])
		assert.are.equal("Pagle dev: tour 18/18: core.onboarding.step.off", loaded.printed[19])
		assert.are.equal("Pagle dev: the tour is done at ", loaded.printed[20]:sub(1, 31))
	end)

	it("leave open a window that was open before its stop", function()
		local loaded = touring()
		pagle(loaded, "shop")
		local shop = loaded.ns.shopFrame

		pagle(loaded, "dev tour core")
		loaded.client.advance(90)

		assert.is_true(shop:IsShown())
	end)

	it("refuse to start in combat, opening nothing (CORE-R67)", function()
		local loaded = touring()
		setCombat(loaded, true)

		pagle(loaded, "dev tour")
		loaded.client.advance(90)

		assert.are.equal(0, loaded.client.screenshots)
		assert.are.same({ "Pagle dev: the tour waits until combat ends; try again then." }, loaded.printed)
	end)
end)
