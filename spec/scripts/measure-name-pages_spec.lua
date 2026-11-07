-- The name pages' probe (scripts/measure-name-pages/probe.lua, #582, #625) measures the band a variety's name line
-- takes with the RealFont the layout harness's helper installed, the one that keeps the client's font objects by name
-- (#620). A Nod's line is set by its art font's name (SetFontObject("PagleArtNodName")), so its band is as tall as
-- that font's line: before #625 the probe loaded its own RealFont, which knew no names, and measured the Nod's band
-- in the stand-in at 12, about 15 units tall where the client draws 28.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local RealFont = dofile("scripts/measure-layout/realfont.lua")

describe("the name pages' probe's font objects (#625)", function()
	it("measures a Nod's name line, set by its font object's name, as tall as that font's line", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local _, stubs = dofile("spec/support/client.lua")()
		local loaded = loadCore(nil, nil, { CreateFont = RealFont.keepNamed(stubs.CreateFont) })
		local ns, client = loaded.ns, loaded.client
		enterWorld(loaded, 3)
		ns.db.profile.announcements.motion = false
		client.runTimers()
		-- The catch toast stepped down to a Nod, as the probe raises it (ANN-R31), in a style that draws the art's Nod.
		local budget = ns.db.profile.announcements.budget
		budget.count = 0
		ns.moments:RaiseCatchToast({
			rung = "toast.low",
			kind = "catch",
			title = "Decent · 34.2 cm",
			text = "Firefin Snapper",
			nodLine = "Firefin Snapper · Coral · Decent · 34.2 cm",
			icon = 6359,
			cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME),
			variety = {
				name = "Coral",
				rarity = "common",
				before = "Firefin Snapper ·",
				after = "· Decent · 34.2 cm",
			},
		})
		client.advance(0)
		budget.count = 40
		local nod = ns.announcementFrames.nod
		nod.display.announcement.style = "core.toaststyle.folio"
		ns.DrawAnnouncement(nod, nod.display)
		assert.are.equal("nod", nod.display.form)

		-- The probe's band starts at the Nod's line, which the art sets by its font's name: Caveat SemiBold at 22.
		local line = nod.title
		assert.are.equal(ns.ART_FONTS.NodName, line.fontObject)
		local file, size, standIn = RealFont.face(line)
		assert.are.same({ "Caveat-SemiBold.ttf", ns.ArtFontSize("NodName"), false }, { file, size, standIn })
		local box = assert(RealFont.rect(line, {}))
		local tall = box[4] - box[2]
		assert.is_near(RealFont.lineHeight(file, size) * RealFont.scale(line), tall, 1e-6)
		-- Not the stand-in's line, as it measured without the name.
		local standInFile, standInSize = RealFont.face({})
		assert.is_true(tall > RealFont.lineHeight(standInFile, standInSize) * RealFont.scale(line) + 5)
		assert.are.same({}, client.errors)
	end)
end)
