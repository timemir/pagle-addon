-- The book binding on the client (core/book-binding.md): Pagle.NewBookBinding draws a binding's look on a book's frame
-- with Core's art (its material, vignette, band, corner pieces and features), dips every shown book when the Angler picks
-- another binding, and plays the page turn once. The looks here are the spec's own, in ns.BindingLook's shape, so it
-- reads the drawing and not the catalogue of bindings.

local SLOT = "core.binding"
local LEATHER = "Interface\\AddOns\\Pagle\\media\\books\\Leather"

---@type table<string, PagleBindingLook>
local LOOKS = {
	-- Field Leather's shape: Core's leather tiled at 128, darker toward the foot
	["test.field"] = {
		texture = LEATHER,
		tileW = 128,
		tileH = 128,
		foot = 0.8,
		gilt = { 0.91, 0.79, 0.42 },
		giltShadow = { 0, 0, 0, 0.95, 0, -1 },
		silver = false,
		paperTint = { 1, 1, 1 },
	},
	-- a tinted material at its own repeat, a band tone, gold corners and the tooled rule
	["test.tooled"] = {
		texture = "Interface\\AddOns\\Pagle\\media\\books\\Tooled",
		tileW = 150,
		tileH = 196,
		tint = { 0.5, 0.4, 0.3 },
		foot = 0.8,
		band = { 0.9, 0.6, 0.3 },
		gilt = { 0.85, 0.71, 0.38 },
		giltShadow = { 0, 0, 0, 0.95, 0, -1 },
		silver = false,
		corners = "gold",
		tooled = true,
		paperTint = { 1, 0.98, 0.96 },
	},
	-- a cloth stretched over the book, unshaded, with the gilt corner
	["test.cloth"] = {
		fill = "Interface\\AddOns\\Pagle\\media\\books\\Cloth",
		tileW = 128,
		tileH = 128,
		foot = 1,
		gilt = { 0.8, 0.8, 0.8 },
		giltShadow = { 0, 0, 0, 0.95, 0, -1 },
		silver = true,
		giltCorner = true,
		paperTint = { 0.98, 1, 1 },
	},
}

-- Core logged in on Forever, its looks the spec's, with Field Leather's shape equipped.
---@param motion boolean? Core's Animations setting (off unless true)
---@return LoadedAddon
local function core(motion)
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }))
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.runTimers()
	local ns = loaded.ns
	ns.BINDING_SLOT = SLOT
	ns.BindingLook = function(goodID)
		return LOOKS[goodID] or LOOKS["test.field"]
	end
	ns.db.profile.announcements.motion = motion == true
	return loaded
end

-- A book's frame, 920 × 600 and shown unless `hidden`, every texture made on it recording its gradient.
---@param loaded LoadedAddon
---@param hidden boolean?
---@return table
local function bookFrame(loaded, hidden)
	local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
	frame:SetSize(920, 600)
	local createTexture = frame.CreateTexture
	function frame.CreateTexture(...)
		local texture = createTexture(...)
		function texture.SetGradient(region, orientation, from, to)
			region.gradient = { orientation, { from.r, from.g, from.b }, { to.r, to.g, to.b } }
		end
		return texture
	end
	if hidden then
		frame:Hide()
	end
	return frame
end

-- The Angler picks `goodID`: Core fires AppearanceChanged for the slot (SHOP-R33).
local function pick(loaded, goodID)
	loaded.ns.Fire("AppearanceChanged", SLOT, goodID)
end

-- A book's regions (adapter/BookBinding.lua).
---@return PagleBookBindingRegions
local function regionsOf(binding)
	return binding.skin --[[@as PagleBookBindingRegions]]
end

-- The page turns played since `from`.
local function turnsSince(loaded, from)
	local turns = 0
	for i = from + 1, #loaded.client.sounds do
		if loaded.client.sounds[i] == "836 SFX" then
			turns = turns + 1
		end
	end
	return turns
end

describe("Pagle.NewBookBinding's drawing", function()
	it(
		"tiles the material inside the band from the top left at its repeat, shaded toward the foot, under the vignette (BIND-R10, BIND-R11)",
		function()
			local loaded = core()
			local frame = bookFrame(loaded)

			local regions = regionsOf(loaded.env.Pagle.NewBookBinding(frame))

			local fill = regions.fill --[[@as table]]
			assert.are.same({ LEATHER, "BACKGROUND", 0 }, { fill.texture, fill.layer, fill.sublevel })
			assert.are.same({ 0, 906 / 128, 0, 586 / 128 }, fill.texCoord)
			assert.are.same({ { "TOPLEFT", 7, -7 }, { "BOTTOMRIGHT", -7, 7 } }, fill.points)
			assert.are.same({ "VERTICAL", { 0.8, 0.8, 0.8 }, { 1, 1, 1 } }, fill.gradient)
			local vignette = regions.vignette --[[@as table]]
			assert.are.same({ "BACKGROUND", 1, loaded.ns.ATLASES.Book.file }, {
				vignette.layer,
				vignette.sublevel,
				vignette.texture,
			})
		end
	)

	it("tiles a material at its own repeat under its tint, again when the book's size changes (BIND-R10)", function()
		local loaded = core()
		local frame = bookFrame(loaded)
		local binding = loaded.env.Pagle.NewBookBinding(frame, { sublevel = 2 })

		binding:SetLook("test.tooled")
		frame:SetSize(614, 400)

		local fill = regionsOf(binding).fill --[[@as table]]
		assert.are.same({ "BACKGROUND", 2 }, { fill.layer, fill.sublevel })
		assert.are.same({ 0, 600 / 150, 0, 386 / 196 }, fill.texCoord)
		assert.are.same({ "VERTICAL", { 0.5, 0.4, 0.3 } }, { fill.gradient[1], fill.gradient[3] })
		for i = 1, 3 do
			assert.is_true(math.abs(fill.gradient[2][i] - LOOKS["test.tooled"].tint[i] * 0.8) < 1e-9)
		end
	end)

	it("stretches a cloth over the book once, unshaded (BIND-R10)", function()
		local loaded = core()
		local binding = loaded.env.Pagle.NewBookBinding(bookFrame(loaded), { pinned = "test.cloth" })

		local fill = regionsOf(binding).fill --[[@as table]]
		assert.are.same({ LOOKS["test.cloth"].fill, { 0, 1, 0, 1 } }, { fill.texture, fill.texCoord })
		assert.are.same({ "VERTICAL", { 1, 1, 1 }, { 1, 1, 1 } }, fill.gradient)
	end)

	it(
		"nine-slices the band on a frame six levels up, in its own colours or desaturated to the look's tone (BIND-R11)",
		function()
			local loaded = core()
			local frame = bookFrame(loaded)
			local binding = loaded.env.Pagle.NewBookBinding(frame)
			local regions = regionsOf(binding)
			local own = {}
			for i, piece in ipairs(regions.bandPieces) do
				own[i] = {
					piece:IsDesaturated(),
					(piece --[[@as table]]).vertexColor,
				}
			end

			binding:SetLook("test.tooled")

			assert.are.equal(8, #regions.bandPieces)
			assert.are.equal(frame:GetFrameLevel() + 6, regions.band:GetFrameLevel())
			assert.are.same({ 16, 16 }, { regions.bandPieces[1]:GetSize() })
			for i, piece in ipairs(regions.bandPieces) do
				assert.are.same({ false, { 1, 1, 1 } }, own[i])
				assert.are.same({ true, { 0.9, 0.6, 0.3 } }, {
					piece:IsDesaturated(),
					(piece --[[@as table]]).vertexColor,
				})
			end
		end
	)

	it(
		"puts the look's corner pieces at the four corners, the top-left one mirrored into the others, 44 square (BIND-R12)",
		function()
			local loaded = core()
			local frame = bookFrame(loaded)
			local binding = loaded.env.Pagle.NewBookBinding(frame)
			local regions = regionsOf(binding)
			local none = {}
			for i, piece in ipairs(regions.corners) do
				none[i] = piece:IsShown()
			end

			binding:SetLook("test.tooled")

			local atlas = loaded.ns.ATLASES.BindingCorners
			local sprite = atlas.sprites["corner-gold"]
			local l, r = sprite.x / atlas.width, (sprite.x + sprite.w) / atlas.width
			local t, b = sprite.y / atlas.height, (sprite.y + sprite.h) / atlas.height
			assert.are.same({ false, false, false, false }, none)
			assert.are.equal(regions.band:GetFrameLevel() + 1, regions.gilt:GetFrameLevel())
			local drawn = {}
			for i, piece in ipairs(regions.corners) do
				drawn[i] = {
					piece:IsShown(),
					(piece --[[@as table]]).texture,
					(piece --[[@as table]]).texCoord,
				}
				assert.are.same({ 44, 44 }, { piece:GetSize() })
			end
			assert.are.same({
				{ true, atlas.file, { l, r, t, b } },
				{ true, atlas.file, { r, l, t, b } },
				{ true, atlas.file, { l, r, b, t } },
				{ true, atlas.file, { r, l, b, t } },
			}, drawn)
			assert.are.same({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }, {
				regions.corners[1]:GetPoint(1),
				regions.corners[2]:GetPoint(1),
				regions.corners[3]:GetPoint(1),
				regions.corners[4]:GetPoint(1),
			})
		end
	)

	it(
		"draws Tooled Leather's double gilt rule 9 and 12 in, and Verdigris's gilt corner, only in looks with them, at the sizes asked (BIND-R12)",
		function()
			local loaded = core()
			local plain = regionsOf(loaded.env.Pagle.NewBookBinding(bookFrame(loaded)))
			local tooled = regionsOf(loaded.env.Pagle.NewBookBinding(bookFrame(loaded), { pinned = "test.tooled" }))
			local cloth = regionsOf(
				loaded.env.Pagle.NewBookBinding(
					bookFrame(loaded),
					{ pinned = "test.cloth", giltCornerSize = 30, cornerSize = 20 }
				)
			)

			local function shown(textures)
				local count = 0
				for _, texture in ipairs(textures) do
					count = count + (texture:IsShown() and 1 or 0)
				end
				return count
			end
			assert.are.same({ 0, 8, 0 }, { shown(plain.rules), shown(tooled.rules), shown(cloth.rules) })
			local gilt = 0xd8 / 255
			assert.are.same({ gilt, 0xb6 / 255, 0x60 / 255, 1 }, (tooled.rules[1] --[[@as table]]).color)
			assert.are.same({ "TOPLEFT", 9, -9 }, { tooled.rules[1]:GetPoint(1) })
			assert.are.same({ "TOPRIGHT", -12, -12 }, { tooled.rules[5]:GetPoint(2) })
			assert.are.same({ false, false, true }, {
				plain.giltCorner:IsShown(),
				tooled.giltCorner:IsShown(),
				cloth.giltCorner:IsShown(),
			})
			assert.are.same({ 30, 30 }, { cloth.giltCorner:GetSize() })
			assert.are.same({ 20, 20 }, { cloth.corners[1]:GetSize() })
		end
	)

	it(
		"draws only on Core's art that ships: the Book atlas, the corner pieces of every metal and the gilt corner (BIND-R13)",
		function()
			local loaded = core()
			local atlases = loaded.ns.ATLASES
			for _, name in ipairs({ "Book", "BindingCorners", "BindingGilt" }) do
				local file = atlases[name].file
				assert.matches("^Interface\\AddOns\\Pagle\\media\\books\\", file)
				local path = file:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/") .. ".blp"
				assert(#readFile(path) > 0, path)
			end
			for _, metal in ipairs({ "brass", "gold", "silver", "iron", "bone", "pearl", "silverfiligree" }) do
				assert(atlases.BindingCorners.sprites["corner-" .. metal], metal)
			end
			assert.is_table(atlases.BindingGilt.sprites.corner)
		end
	)
end)

describe("Pagle.NewBookBinding through a change of binding", function()
	it(
		"dips every shown book's material to a quarter and its band to 55%, changing it at the deepest point, with one page turn (BIND-R20, BIND-R21)",
		function()
			local loaded = core(true)
			local Pagle = loaded.env.Pagle
			local first = Pagle.NewBookBinding(bookFrame(loaded))
			local second = Pagle.NewBookBinding(bookFrame(loaded))
			local hidden = Pagle.NewBookBinding(bookFrame(loaded, true))
			local from = #loaded.client.sounds

			pick(loaded, "test.tooled")
			local hiddenLook = hidden:Look()
			loaded.client.update(0.2)
			local fill = regionsOf(first).fill --[[@as table]]
			local band = regionsOf(first).band --[[@as table]]
			local deepest = { fill.alpha, band.alpha, first:Look(), second:Look() }
			loaded.client.update(0.25)

			assert.are.equal(1, turnsSince(loaded, from))
			assert.are.equal(LOOKS["test.tooled"], hiddenLook)
			assert.is_true(math.abs(deepest[1] - 0.25) < 1e-6)
			assert.is_true(math.abs(deepest[2] - 0.55) < 1e-6)
			assert.are.same({ LOOKS["test.tooled"], LOOKS["test.tooled"] }, { deepest[3], deepest[4] })
			assert.are.same({ 1, 1 }, { fill.alpha, band.alpha })
		end
	)

	it(
		"changes at once while Core's Animations setting is off, still with one page turn (BIND-R20, BIND-R21)",
		function()
			local loaded = core(false)
			local binding = loaded.env.Pagle.NewBookBinding(bookFrame(loaded))
			local from = #loaded.client.sounds

			pick(loaded, "test.cloth")

			assert.are.equal(LOOKS["test.cloth"], binding:Look())
			assert.are.equal(1, turnsSince(loaded, from))
		end
	)

	it("plays nothing with no book shown, and leaves a pinned book as it is (BIND-R21, BIND-R22)", function()
		local loaded = core(true)
		local hidden = loaded.env.Pagle.NewBookBinding(bookFrame(loaded, true))
		local pinned = loaded.env.Pagle.NewBookBinding(bookFrame(loaded), { pinned = "test.field" })
		local from = #loaded.client.sounds

		pick(loaded, "test.tooled")
		loaded.client.update(1)

		assert.are.equal(0, turnsSince(loaded, from))
		assert.are.same({ LOOKS["test.tooled"], LOOKS["test.field"] }, { hidden:Look(), pinned:Look() })
	end)
end)
