-- The news sign (core/news-sign.md, SIGN-R10–R60): its frame, its six looks through a whole drop, its words and
-- emblems, its timing, hover and clicks, its spot, Animations off, combat, its art and sounds, and `/pagle dev sign`,
-- through the real TOC and the fake client.

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sign\\sounds\\"
local LOOKS = { "wood", "scroll", "lantern", "kraken", "astro", "coral" }
local KINDS = { "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster", "region" }

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- Core logged in, with dev mode on.
local function devOn(saved)
	local loaded = enterWorld(loadCore({ BUILD_ENTRY }, saved))
	pagle(loaded, "dev on")
	return loaded
end

-- Runs `seconds` of frames at 30 a second.
local function run(loaded, seconds)
	for _ = 1, math.floor(seconds * 30 + 0.5) do
		loaded.client.nextFrame(1 / 30)
	end
end

-- The sounds played since `from` (an index into client.sounds), as their file names.
local function soundsSince(loaded, from)
	local names = {}
	for i = from + 1, #loaded.client.sounds do
		names[#names + 1] = loaded.client.sounds[i]:match("sounds\\([%w_]+)%.ogg SFX$")
	end
	return names
end

-- The texts of the sign's font strings that show.
local function words(loaded)
	local out = {}
	local function walk(region)
		for _, child in ipairs(region.children or {}) do
			if child.kind == "FontString" and child.shown ~= false and child.text then
				out[#out + 1] = child.text
			end
			walk(child)
		end
	end
	walk(loaded.ns.NewsSignFrame())
	return out
end

local function has(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

describe("/pagle dev sign", function()
	it("says dev mode is off, and drops nothing, while it's off (SIGN-R60)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "dev sign wood first")

		assert.are.same({ "Pagle dev: dev commands are off; /pagle dev on turns them on." }, loaded.printed)
		assert.is_nil(loaded.ns.NewsSignState())
	end)

	it("prints its usage for a look or kind it doesn't know (SIGN-R60)", function()
		local loaded = devOn()

		pagle(loaded, "dev sign barrel")

		assert.truthy(loaded.printed[#loaded.printed]:find("/pagle dev sign <look> [kind] [more]", 1, true))
		assert.truthy(loaded.printed[#loaded.printed]:find("wood, scroll, lantern, kraken, astro, coral", 1, true))
		assert.is_nil(loaded.ns.NewsSignState())
	end)

	it("drops the look asked for with sample news of the kind asked for (SIGN-R60, SIGN-R12)", function()
		local loaded = devOn()

		pagle(loaded, "dev sign scroll prestige more")
		run(loaded, 2)

		assert.are.equal("scroll", loaded.ns.NewsSignState().look)
		local shown = words(loaded)
		assert.truthy(has(shown, "Prestige"))
		assert.truthy(has(shown, "Kukli Emnabi reached Prestige III"))
		assert.truthy(has(shown, "+11 more from your anglers"))
	end)
end)

describe("The news sign", function()
	it("is PagleNewsSign, on UIParent at 0.85, its top centre at its spot (SIGN-R20)", function()
		local loaded = devOn()

		pagle(loaded, "dev sign wood first")
		run(loaded, 0.1)

		local frame = loaded.ns.NewsSignFrame()
		assert.are.equal(loaded.env.PagleNewsSign, frame)
		assert.are.equal(loaded.env.UIParent, frame:GetParent())
		assert.are.equal(0.85, frame:GetScale())
		assert.are.equal("TOP", (frame:GetPoint()))
	end)

	for _, look in ipairs(LOOKS) do
		it(
			"plays the " .. look .. " look's whole drop for every kind, and then hides (SIGN-R50–R56, SIGN-R41)",
			function()
				local loaded = devOn()
				for _, kind in ipairs(KINDS) do
					pagle(loaded, ("dev sign %s %s more"):format(look, kind))
					run(loaded, 1)
					assert.are.equal(look, loaded.ns.NewsSignState().look)
					run(loaded, 12)
					assert(loaded.ns.NewsSignState() == nil, kind)
					assert.is_false(loaded.ns.NewsSignFrame():IsShown())
				end
			end
		)
	end

	it(
		"makes a look's frames, textures and font strings once, and draws each next drop with them (SIGN-R30)",
		function()
			local loaded = devOn()
			local function count(region)
				local n = 0
				for _, child in ipairs(region.children or {}) do
					n = n + 1 + count(child)
				end
				return n
			end

			local function both()
				for _, kind in ipairs({ "monster", "first" }) do
					pagle(loaded, "dev sign kraken " .. kind .. " more")
					run(loaded, 12)
				end
			end
			both()
			local after = count(loaded.ns.NewsSignFrame())
			both()

			assert.are.equal(after, count(loaded.ns.NewsSignFrame()))
		end
	)

	it("plays its look's sounds at their cues on the SFX channel (SIGN-R31)", function()
		local loaded = devOn()
		local before = #loaded.client.sounds

		pagle(loaded, "dev sign wood first")
		run(loaded, 2)

		assert.are.same({ "wood_land", "wood_creak", "wood_creak" }, soundsSince(loaded, before))
		assert.truthy(loaded.client.sounds[before + 1]:find(SOUNDS, 1, true))
	end)

	it("hangs 8 s from the end of its entrance, then goes up and hides (SIGN-R41)", function()
		local loaded = devOn()

		pagle(loaded, "dev sign wood first")
		run(loaded, 1.0 + 7.8)
		assert.is_false(loaded.ns.NewsSignState().exiting)
		run(loaded, 0.4)
		assert.is_true(loaded.ns.NewsSignState().exiting)
		run(loaded, 1)
		assert.is_nil(loaded.ns.NewsSignState())
	end)

	it("holds while the mouse is over it, and its time runs on once it leaves (SIGN-R41)", function()
		local loaded = devOn()
		pagle(loaded, "dev sign lantern colour")
		run(loaded, 3)
		local frame = loaded.ns.NewsSignFrame()

		frame:GetScript("OnEnter")(frame)
		run(loaded, 20)
		assert.is_false(loaded.ns.NewsSignState().exiting)
		frame:GetScript("OnLeave")(frame)
		run(loaded, 6.9)
		assert.is_false(loaded.ns.NewsSignState().exiting)
		run(loaded, 2.5)
		assert.is_nil(loaded.ns.NewsSignState())
	end)

	it(
		"goes up at once on a right click, and on a left click, opening nothing for the dev command's sign (SIGN-R42)",
		function()
			local loaded = loadCore({ BUILD_ENTRY })
			loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
			local opened = {}
			loaded.env.Pagle.RegisterModule({
				name = "Ledger",
				title = "Ledger",
				order = 10,
				news = function(...)
					opened[#opened + 1] = { ... }
				end,
			})
			enterWorld(loaded)
			pagle(loaded, "dev on")
			assert.is_function(loaded.ns.NewsOffered and loaded.ns.NewsOffered())
			pagle(loaded, "dev sign astro legend")
			run(loaded, 3)
			local frame = loaded.ns.NewsSignFrame()

			frame:GetScript("OnMouseDown")(frame, "RightButton")
			frame:GetScript("OnClick")(frame, "RightButton")
			assert.is_true(loaded.ns.NewsSignState().exiting)
			run(loaded, 1.2)
			assert.is_nil(loaded.ns.NewsSignState())

			pagle(loaded, "dev sign coral zone")
			run(loaded, 3)
			frame:GetScript("OnMouseDown")(frame, "LeftButton")
			frame:GetScript("OnClick")(frame, "LeftButton")
			assert.are.same({}, opened)
			assert.is_true(loaded.ns.NewsSignState().exiting)
		end
	)

	-- Core in the world with a Ledger registered whose def.news is `news` (none when nil), then a sign dropped with a
	-- news item's words and its id, as the decision drops one (SIGN-R14, SIGN-R19).
	local function itemDropped(news)
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
		loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10, news = news })
		enterWorld(loaded)
		local item = loaded.ns.NewsSignSample("legend")
		item.id = "3f9a0c1d2e4b5a69"
		loaded.ns.DropNewsSign("wood", item)
		run(loaded, 3)
		return loaded, loaded.ns.NewsSignFrame()
	end

	it(
		"opens the Fish Journal's news list on the item shown, through def.news, and goes up on a left click (SIGN-R42, VIEW-R46)",
		function()
			local opened = {}
			local loaded, frame = itemDropped(function(...)
				opened[#opened + 1] = { ... }
			end)

			frame:GetScript("OnMouseDown")(frame, "LeftButton")
			frame:GetScript("OnClick")(frame, "LeftButton")

			assert.are.same({ { "3f9a0c1d2e4b5a69" } }, opened)
			assert.is_true(loaded.ns.NewsSignState().exiting)
		end
	)

	it("only goes up on a left click when no On Module offers def.news: the Ledger off (SIGN-R42, VIEW-R46)", function()
		local loaded, frame = itemDropped(nil)

		frame:GetScript("OnMouseDown")(frame, "LeftButton")
		frame:GetScript("OnClick")(frame, "LeftButton")

		assert.is_true(loaded.ns.NewsSignState().exiting)
		run(loaded, 1.2)
		assert.is_nil(loaded.ns.NewsSignState())
	end)

	it("reports a def.news that raises, and still goes up (SIGN-R42, VIEW-R46)", function()
		local loaded, frame = itemDropped(function()
			error("News broke")
		end)

		frame:GetScript("OnMouseDown")(frame, "LeftButton")
		frame:GetScript("OnClick")(frame, "LeftButton")

		assert.is_true(loaded.ns.NewsSignState().exiting)
		assert.are.equal(1, #loaded.client.errors)
		assert.matches("News broke", loaded.client.errors[1])
	end)

	it("keeps where it's dragged to as fractions of the screen (SIGN-R20)", function()
		local loaded = devOn()
		pagle(loaded, "dev sign kraken monster")
		run(loaded, 2)
		local frame = loaded.ns.NewsSignFrame()

		frame:GetScript("OnMouseDown")(frame, "LeftButton")
		frame:GetScript("OnDragStart")(frame, "LeftButton")
		-- the client moved it: its left and top edges now, in its own units
		frame.screenLeft, frame.screenTop = 300, 700
		frame:GetScript("OnDragStop")(frame)

		local W, H = loaded.env.UIParent:GetWidth(), loaded.env.UIParent:GetHeight()
		local point = loaded.ns.db.global.newsSign.point
		assert.are.same({ (300 + 392 / 2) * 0.85 / W, (H - 700 * 0.85) / H }, { point.x, point.y })
		assert.is_false(loaded.ns.NewsSignState().exiting) -- the drag's release isn't a click
	end)

	it("waits for combat to end, and goes up if combat starts while it shows (SIGN-R40)", function()
		local loaded = devOn()
		setCombat(loaded, true)

		pagle(loaded, "dev sign scroll hunt")
		run(loaded, 1)
		assert.is_nil(loaded.ns.NewsSignState())
		setCombat(loaded, false)
		run(loaded, 2)
		assert.are.equal("scroll", loaded.ns.NewsSignState().look)

		setCombat(loaded, true)
		assert.is_true(loaded.ns.NewsSignState().exiting)
	end)

	it("appears at rest and still with Animations off, and leaves at once after its time (SIGN-R43)", function()
		local loaded = devOn()
		loaded.ns.db.profile.announcements.motion = false
		local before = #loaded.client.sounds

		pagle(loaded, "dev sign kraken first")
		assert.is_true(loaded.ns.NewsSignState().static)
		loaded.client.advance(7.9)
		assert.is_not_nil(loaded.ns.NewsSignState())
		loaded.client.advance(0.5)
		assert.is_nil(loaded.ns.NewsSignState())
		assert.are.same({}, soundsSince(loaded, before))
	end)
end)

describe("The news sign's art", function()
	it("is one shared atlas and one per look, each a BLP of the size its data says (SIGN-R30)", function()
		local loaded = devOn()
		for _, name in ipairs({ "Common", "Wood", "Scroll", "Lantern", "Kraken", "Astro", "Coral" }) do
			local atlas = assert(loaded.ns.ATLASES["Sign" .. name], name)
			local path = atlas.file:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/") .. ".blp"
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local file = assert(io.open(path, "rb"), path)
			local header = file:read(20)
			file:close()
			assert.are.equal("BLP2", header:sub(1, 4))
			local function u32(offset)
				local a, b, c, d = header:byte(offset, offset + 3)
				return a + b * 256 + c * 65536 + d * 16777216
			end
			assert.are.same({ name, atlas.width, atlas.height }, { name, u32(13), u32(17) })
			for sprite, s in pairs(atlas.sprites) do
				assert(s.x >= 0 and s.y >= 0 and s.x + s.w <= atlas.width and s.y + s.h <= atlas.height, sprite)
			end
		end
	end)

	it("has every sound each look plays, as Ogg Vorbis in media/sign/sounds (SIGN-R31)", function()
		local loaded = devOn()
		for _, key in ipairs(LOOKS) do
			local look = loaded.ns.NEWS_SIGN_LOOKS[key]
			for _, list in ipairs({ look.sounds, look.outSounds }) do
				for _, cue in ipairs(list) do
					local path = "addons/Pagle/media/sign/sounds/" .. cue[1] .. ".ogg"
					---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
					local file = assert(io.open(path, "rb"), path)
					assert.are.equal("OggS", file:read(4))
					file:close()
				end
			end
		end
	end)
end)

describe("Pagle.DrawNewsEmblem", function()
	-- The files of the textures shown on `frame` and its children.
	local function shownFiles(frame)
		local files = {}
		local function walk(region)
			for _, child in ipairs(region.children or {}) do
				if child.kind == "Texture" and child.shown ~= false and child.texture then
					files[#files + 1] = child.texture
				end
				if child.shown ~= false then
					walk(child)
				end
			end
		end
		walk(frame)
		return files
	end

	it(
		"draws an item's emblem into any frame, as the sign's slot draws it, for the Journal's list (LED-R176, SIGN-R13)",
		function()
			local loaded = enterWorld(loadCore({ BUILD_ENTRY }))
			local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)

			loaded.env.Pagle.DrawNewsEmblem(frame, { sign = "laurel" }, 96)
			assert.are.same({ "Interface\\AddOns\\Pagle\\media\\sign\\SignCommon" }, shownFiles(frame))

			-- drawn again, the new emblem replaces the old
			loaded.env.Pagle.DrawNewsEmblem(
				frame,
				{ file = "Interface\\AddOns\\Pagle\\media\\crests\\fish\\13422", fill = 0.92 },
				96
			)
			assert.are.same({ "Interface\\AddOns\\Pagle\\media\\crests\\fish\\13422" }, shownFiles(frame))

			-- and none clears it
			loaded.env.Pagle.DrawNewsEmblem(frame, nil, 96)
			assert.are.same({}, shownFiles(frame))
		end
	)
end)
