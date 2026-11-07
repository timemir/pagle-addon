-- The layout harness's font faces (scripts/measure-layout/realfont.lua, #620): a font string set to a font object by
-- its name, as the art sets the toasts' (SetFontObject("PagleArtName")), measures in the face and size CreateFont's
-- font object was given, not in the stand-in at 12. Before #620 the tour measured every toast's name so, at about
-- 5 units on the Field guide's Moments page, and missed #592's Moments row.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local RealFont = dofile("scripts/measure-layout/realfont.lua")

describe("the layout harness's font objects (#620)", function()
	it("measures a font string set to a named font object in that object's face and size", function()
		local createFont = RealFont.keepNamed(function(name)
			local font = { name = name }
			function font:SetFont(file, size)
				self.font = { file, size }
			end
			return font
		end)
		createFont("PagleSpecHand"):SetFont("Interface\\AddOns\\Pagle\\media\\fonts\\Caveat-SemiBold.ttf", 31)
		local file, size, standIn = RealFont.face({ fontObject = "PagleSpecHand" })
		assert.are.same({ "Caveat-SemiBold.ttf", 31, false }, { file, size, standIn })
		-- A font object the add-on didn't make, such as the client's GameFontNormal, stays the stand-in.
		file, size, standIn = RealFont.face({ fontObject = "GameFontNormal" })
		assert.are.same({ "Marcellus-Regular.ttf", 12, true }, { file, size, standIn })
	end)

	it("keeps the fake client's font objects by name once installed, as the harness's helper installs it", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local realDofile = dofile
		local ok, err = pcall(function()
			RealFont.install()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
			local _, stubs = dofile("spec/support/client.lua")()
			stubs.CreateFont("PagleSpecPrint"):SetFont("Interface\\AddOns\\Pagle\\media\\fonts\\IMFeENrm28P.ttf", 16)
		end)
		-- Every other spec keeps the fake's 6 units a byte.
		rawset(_G, "dofile", realDofile)
		assert(ok, err)
		local file, size, standIn = RealFont.face({ fontObject = "PagleSpecPrint" })
		assert.are.same({ "IMFeENrm28P.ttf", 16, false }, { file, size, standIn })
	end)

	it("measures a toast's name in its style's face and size, as the game draws it", function()
		local _, stubs = dofile("spec/support/client.lua")()
		local loaded = loadAddon("Pagle", foreverWith({ CreateFont = RealFont.keepNamed(stubs.CreateFont) }))
		enterWorld(loaded, 3)
		local ns = loaded.ns
		local stage = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		local toast = ns.DrawStillAnnouncement(stage, "toast", assert(ns.DevPreviewAnnouncement("toast", "Bream")))
		local name = toast.text
		assert.are.equal("Bream", name.text)
		-- The art's font Name (adapter/Art.lua): Caveat SemiBold at 31, set by its font object's name.
		assert.are.equal("PagleArtName", name.fontObject)
		local file, size, standIn = RealFont.face(name)
		assert.are.same({ "Caveat-SemiBold.ttf", ns.ArtFontSize("Name"), false }, { file, size, standIn })
		assert.are.equal(RealFont.width("Bream", "Caveat-SemiBold.ttf", 31), RealFont.layout(name).natural)
		-- Its kicker, in the art's font What: IM Fell English at 16.
		file, size = RealFont.face(toast.title)
		assert.are.same({ "IMFeENrm28P.ttf", ns.ArtFontSize("What") }, { file, size })
	end)
end)

describe("the layout harness's cut words (1.3.5)", function()
	-- A wrapping font string `width` wide in Marcellus at `size`, reading `text`, as the fake client keeps one.
	local function wrapping(text, width, size)
		return {
			kind = "FontString",
			text = text,
			font = { "Interface\\AddOns\\Pagle\\media\\fonts\\Marcellus-Regular.ttf", size },
			wordWrap = true,
			GetWidth = function()
				return width
			end,
		}
	end

	it("measures the widest line it shows, so a word wider than its box reports that word's width", function()
		local note = wrapping("one two three", 40, 19)
		local layout = RealFont.layout(note)
		local widest = 0
		for _, word in ipairs({ "one", "two", "three" }) do
			widest = math.max(widest, (RealFont.width(word, "Marcellus-Regular.ttf", 19)))
		end

		assert.are.equal("a word wider than its box", layout.cut)
		assert.are.equal(widest, layout.widest)
		assert.is_true(layout.widest < layout.natural)
	end)
end)
