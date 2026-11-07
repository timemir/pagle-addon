-- The Lua half of scripts/measure-name-pages.py (#582, VAR-R28): every toast style's toast, ruled and gilt pages and
-- its Nod, each drawn naming a variety, as the client draws them with Animations off. For each it writes the band the
-- name line takes (from the line's left to the end of its room, a name long enough to fill it) and every texture drawn
-- under the words there, with its place on the screen, for the Python half to composite from the BLP art and measure.
-- Not a spec: its name keeps it out of the check gate's busted run.
--
--   NAME_PAGES_OUT=<file> .tools/bin/busted scripts/measure-name-pages/probe.lua
--
-- Writes <file>: one JSON object a line, { style, page, band = { left, top, right, bottom }, textures = { ... } },
-- each texture { tex, color, tc, rect, vc, desaturated, alpha, blend, layer, sub, fl } in draw order.

local RealFont = dofile("scripts/measure-layout/realfont.lua")
local json = require("dkjson")

local OUT = assert(os.getenv("NAME_PAGES_OUT"), "NAME_PAGES_OUT names the file to write")

-- What counts as drawn: an alpha above this, its parents' times its own.
local SEEN = 0.05

-- A fish's name long enough to fill any name line's room, so its band reaches the room's end.
local FISH = "Raw Bristle Whisker Catfish of the Far Deep Reaches and the Sunken Sea"

-- `region`'s alpha times its parents', or nil if it or one of them is hidden.
local function drawnAlpha(region)
	local alpha, r = 1, region
	while r do
		if r.shown == false then
			return nil
		end
		alpha = alpha * (r.alpha or 1)
		r = r.parent
	end
	return alpha
end

local function round(x)
	return math.floor(x * 1000 + 0.5) / 1000
end

local function rounded(box)
	return { round(box[1]), round(box[2]), round(box[3]), round(box[4]) }
end

-- The textures `frame` draws at or under the words' frame level `words`, in the order it holds them, leaving out the
-- subtrees in `skip` (the gem, the stamps): what stands behind the name line.
local function textures(frame, words, skip, memo)
	local out = {}
	local function walk(region)
		if skip[region] or region.shown == false then
			return
		end
		if region.kind == "Texture" and (region.texture or region.color) then
			local alpha = drawnAlpha(region)
			local box = RealFont.rect(region, memo)
			local level = region.parent and region.parent:GetFrameLevel() or 0
			if alpha and alpha > SEEN and box and level <= words then
				out[#out + 1] = {
					tex = type(region.texture) == "string" and region.texture or nil,
					color = region.color,
					tc = region.texCoord,
					rect = rounded(box),
					vc = region.vertexColor,
					desaturated = region.desaturated == true,
					alpha = round(alpha),
					blend = region.blendMode,
					layer = region.layer,
					sub = region.sublevel,
					fl = level,
				}
			end
		end
		for _, child in ipairs(region.children or {}) do
			walk(child)
		end
	end
	walk(frame)
	return out
end

-- The band from `first`'s left to `last`'s right, as tall as `first`'s line.
local function band(first, last, memo)
	local a, b = RealFont.rect(first, memo), RealFont.rect(last, memo)
	return rounded({ a[1], a[2], b[3], a[4] })
end

describe("name pages", function()
	it("measures where every style writes a variety's name", function()
		local loaded = loadCore()
		local ns, client = loaded.ns, loaded.client
		loaded.env.PagleDB.global.onboarding.notesOn = false
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded, 3)
		ns.db.profile.announcements.motion = false
		client.runTimers()
		local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
		local variety = { name = "Coral", rarity = "common", before = FISH .. " ·", after = "· Decent · 34.2 cm" }

		local function catch()
			ns.moments:RaiseCatchToast({
				rung = "toast.low",
				kind = "catch",
				title = "Decent · 34.2 cm",
				text = FISH,
				nodLine = FISH .. " · Coral · Decent · 34.2 cm",
				icon = 6359,
				cast = cast,
				variety = variety,
			})
			client.advance(0)
			return ns.announcementFrames.toast
		end
		local function riding(rung, fields)
			local headline =
				{ rung = rung, kind = "probe", title = "Size record", text = FISH, icon = 6291, cast = cast }
			for key, value in pairs(fields or {}) do
				headline[key] = value
			end
			M:RaiseMoment(headline)
			M:RaiseMoment({
				rung = "toast.low",
				kind = "newVariety",
				title = "New variety",
				text = "Coral",
				icon = 6291,
				cast = cast,
				variety = { name = "Coral", rarity = "common" },
			})
			client.advance(0)
			return ns.announcementFrames.toast
		end
		local cases = {
			{ "toast", catch },
			{
				"toast-ruled",
				function()
					return riding("toast.low", { ruler = { old = 303, new = 304, unit = "length", label = "Tiddler" } })
				end,
			},
			{
				"high",
				function()
					return riding("toast.high")
				end,
			},
			{
				"nod",
				function()
					local budget = ns.db.profile.announcements.budget
					budget.count = 0
					catch()
					budget.count = 40
					return ns.announcementFrames.nod
				end,
			},
		}

		local ids = {}
		for id in pairs(ns.TOAST_STYLES) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		local lines = {}
		for _, case in ipairs(cases) do
			local frame = case[2]()
			for _, id in ipairs(ids) do
				local display = frame.display
				display.announcement.style = id
				ns.DrawAnnouncement(frame, display)
				local page = display.form == "nod" and "nod" or ns.ToastPage(display.announcement).page
				assert(page == case[1], ("%s drew on %s, not %s"):format(id, tostring(page), case[1]))
				local memo = {}
				local first = display.form == "nod" and frame.title or frame.text
				local last = display.form == "nod" and frame.tail or frame.variety
				local skip = { [frame.gem] = true }
				for _, stamp in ipairs(frame.stamps or {}) do
					skip[stamp] = true
				end
				local words = first.parent:GetFrameLevel()
				lines[#lines + 1] = json.encode({
					style = id,
					page = page,
					band = band(first, last, memo),
					textures = textures(frame, words, skip, memo),
				})
			end
			client.advance(10)
		end
		local file = assert(io.open(OUT, "w"))
		file:write(table.concat(lines, "\n"), "\n")
		file:close()
		assert.are.same({}, client.errors)
	end)
end)
