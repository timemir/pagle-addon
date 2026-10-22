if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal bindings (LED-R110–R112, LED-R116): the Ledger's one slot, its goods and each one's look, and when a
-- level binding is earned (the expansion's earned bindings' rules are logic/EarnedGoods.lua's). Pure logic, everything
-- passed in (CORE-R7); adapter/Bindings.lua registers them and draws the swatch, adapter/Journal.lua tints the book.

--- The Ledger's slot (LED-R110).
ns.BINDING_SLOT = "ledger.binding"

--- Every binding's icon, the shop's swatch for one put away (wallet-and-shop.md › UI): the ledger book the level-up
--- moment shows (LED-R97).
ns.BINDING_ICON = "Interface\\Icons\\INV_Misc_Book_09"

-- The bindings' materials (LED-R110): Core's own leather for Field Leather (the book's, Pagle/media/books), the grey
-- leather a vertex tint colours, Birch Bark's bark and Buckram's cloth, and each of the shop expansion's twenty its
-- own (`media/journal/bindings/<key>`).
local OWN = "Interface\\AddOns\\Pagle_Ledger\\media\\journal\\"
local FIELD_LEATHER = "Interface\\AddOns\\Pagle\\media\\books\\Leather"
local LEATHER_GREY = OWN .. "LeatherGrey"
local BARK = OWN .. "Bark"
local CLOTH = OWN .. "Cloth"
local TILES = OWN .. "bindings\\"

--- The corner pieces a binding's open book wears (LED-R110), as the shop expansion kit's Bindings board draws them.
---@alias LedgerBindingCorners "brass"|"gold"|"silver"|"iron"|"bone"|"pearl"|"silverfiligree"

--- A binding: its good's last ID part (`ledger.binding.<name>`, and its lore keys `binding.<name>.*`, LED-R160),
--- its kind (exactly one of `default`, `level` or `earn` for an earned one, `tier` for one for sale), and its look as
--- the art kits measured it: the Ledger art kit's ten from the canvas's swatches, the shop expansion kit's from its
--- Bindings board (`goods.json`). The material's texture, tiled at `tileW` × `tileH` UI units a repeat (128 square
--- without one), under a vertex `tint` for the grey leather; the gilt of the crumbs, fleurons and plate ("RRGGBB");
--- the band's tone (the tint's own hue where none is given); whether the plate is silver, where the kit says (else a silver gilt
--- makes it so); its corner pieces; and its closed-book swatch.
---@class LedgerBinding
---@field name string
---@field default? true
---@field level? integer -- earned at this peak or celebrated level (LED-R111)
---@field earn? LedgerEarnedRule -- earned by this rule (LED-R116, logic/EarnedGoods.lua)
---@field tier? 1|2|3|4|5
---@field texture string  -- the material's texture
---@field tileW? number
---@field tileH? number
---@field tint? number[]  -- the grey leather's vertex tint, { r, g, b }
---@field gilt string
---@field band? string    -- the band's tone, "RRGGBB"
---@field bandGain? number -- the band tone's gain over the band's luminance, 1 without one
---@field silver? boolean -- the plate's silver, as the kit says; nil to read it from the gilt
---@field corners? LedgerBindingCorners
---@field swatchAtlas? "Bindings"|"Bindings2" -- the atlas of its swatch, "Bindings" without one
---@field swatch string   -- its closed book in that atlas

-- The shop expansion kit's band tones are drawn at 1.9 times their colour over the band's luminance (its board's
-- tint filter).
local EXPANSION_BAND_GAIN = 1.9

-- One of the shop expansion kit's bindings (LED-R110, `goods.json`): its own material, `media/journal/bindings/<key>`,
-- unless it names another, a brass plate unless it says silver (never read from its gilt), and its swatch
-- `swatch-<key>` in the Bindings2 atlas.
---@param binding table a LedgerBinding but for its texture, band gain and swatch
---@return LedgerBinding
local function expansion(binding)
	binding.texture = binding.texture or TILES .. binding.name
	binding.bandGain = EXPANSION_BAND_GAIN
	binding.silver = binding.silver == true
	binding.swatchAtlas = "Bindings2"
	binding.swatch = "swatch-" .. binding.name
	return binding
end

--- LED-R110's bindings, in its order: the Ledger art kit's ten (its Bindings.lua, `bindings.json`), then the shop
--- expansion kit's fifteen for sale and its five earned (`goods.json`).
---@type LedgerBinding[]
ns.BINDINGS = {
	{ name = "field", default = true, texture = FIELD_LEATHER, gilt = "e8c96a", swatch = "binding-field-leather" },
	{
		name = "level10", -- Tanned Hide
		level = 10,
		texture = LEATHER_GREY,
		tint = { 0.736, 0.386, 0.008 },
		gilt = "f0d890",
		swatch = "binding-tanned-hide",
	},
	{
		name = "level20", -- Tidewater Blue
		level = 20,
		texture = LEATHER_GREY,
		tint = { 0.188, 0.363, 0.563 },
		gilt = "c9ccd3",
		swatch = "binding-tidewater-blue",
	},
	{
		name = "level30", -- Reed Green
		level = 30,
		texture = LEATHER_GREY,
		tint = { 0.207, 0.422, 0.192 },
		gilt = "d8c47a",
		swatch = "binding-reed-green",
	},
	{
		name = "level40", -- Oxblood
		level = 40,
		texture = LEATHER_GREY,
		tint = { 0.689, 0.179, 0.179 },
		gilt = "f2c230",
		swatch = "binding-oxblood",
	},
	{
		name = "level50", -- Storm Grey
		level = 50,
		texture = LEATHER_GREY,
		tint = { 0.296, 0.341, 0.381 },
		gilt = "c9ccd3",
		swatch = "binding-storm-grey",
	},
	{
		name = "level60", -- Nat's Own
		level = 60,
		texture = LEATHER_GREY,
		tint = { 0.213, 0.174, 0.147 },
		gilt = "ffd100",
		swatch = "binding-nats-own",
	},
	{
		name = "birch",
		tier = 1,
		texture = BARK,
		tileW = 256,
		tileH = 256,
		gilt = "6a4a20",
		band = "b8a888",
		swatch = "binding-birch-bark",
	},
	{
		name = "buckram", -- Sea-Green Buckram
		tier = 2,
		texture = CLOTH,
		tileW = 256,
		tileH = 256,
		gilt = "efe0bb",
		band = "6a9a8c",
		swatch = "binding-sea-green-buckram",
	},
	{
		name = "sharkskin",
		tier = 3,
		texture = LEATHER_GREY,
		tint = { 0.235, 0.282, 0.306 },
		gilt = "dfe2e8",
		swatch = "binding-sharkskin",
	},
	-- Tide-Chart Linen
	expansion({
		name = "chartlinen",
		tier = 1,
		tileW = 256,
		tileH = 256,
		gilt = "1e3a5a",
		band = "5a7a90",
		corners = "brass",
	}),
	-- Tarred Sailcloth
	expansion({ name = "sailcloth", tier = 1, tileW = 128, tileH = 128, gilt = "d8c08a", band = "3a342a" }),
	-- Oilskin Yellow
	expansion({ name = "oilskin", tier = 1, tileW = 200, tileH = 200, gilt = "3a2a08", band = "b88a10" }),
	-- Mossbound
	expansion({
		name = "moss",
		tier = 2,
		tileW = 160,
		tileH = 160,
		gilt = "c8d880",
		band = "4a5a2a",
		corners = "brass",
	}),
	-- Driftwood Boards
	expansion({
		name = "driftwood",
		tier = 2,
		tileW = 150,
		tileH = 196,
		gilt = "d8d0c0",
		band = "5a5448",
		corners = "iron",
	}),
	-- Eelskin
	expansion({
		name = "eelskin",
		tier = 2,
		tileW = 64,
		tileH = 64,
		gilt = "b8c08a",
		band = "2a2e1e",
		silver = true,
		corners = "silver",
	}),
	-- Kodo Hide
	expansion({ name = "kodo", tier = 2, tileW = 220, tileH = 220, gilt = "f0d8a8", band = "7a4a24", corners = "bone" }),
	-- Frost-Tanned Hide
	expansion({
		name = "frosthide",
		tier = 2,
		tileW = 180,
		tileH = 180,
		gilt = "3a5a7a",
		band = "8aa0b0",
		silver = true,
		corners = "silver",
	}),
	-- Net over Cork
	expansion({ name = "netcork", tier = 2, tileW = 140, tileH = 140, gilt = "2a1a08", band = "8a5a2a" }),
	-- Riveted Copper
	expansion({ name = "copper", tier = 3, tileW = 150, tileH = 196, gilt = "ffd0a8", band = "8a4024" }),
	-- Night Velvet
	expansion({
		name = "velvet",
		tier = 3,
		tileW = 200,
		tileH = 200,
		gilt = "dfe6ff",
		band = "1e2a5a",
		silver = true,
		corners = "silver",
	}),
	-- Turtle Shell
	expansion({
		name = "turtle",
		tier = 3,
		tileW = 150,
		tileH = 196,
		gilt = "f0c060",
		band = "5a2e0e",
		corners = "gold",
	}),
	-- Gilded Morocco
	expansion({
		name = "morocco",
		tier = 3,
		tileW = 52,
		tileH = 52,
		gilt = "f0c850",
		band = "7a0e16",
		corners = "gold",
	}),
	-- Coral Inlay
	expansion({
		name = "coral",
		tier = 4,
		texture = LEATHER_GREY,
		tint = { 0x1e / 255, 0x5a / 255, 0x54 / 255 },
		tileW = 128,
		tileH = 128,
		gilt = "ffd8b8",
		band = "1e5a54",
		corners = "pearl",
	}),
	-- Mother-of-Pearl
	expansion({
		name = "pearl",
		tier = 5,
		tileW = 150,
		tileH = 196,
		gilt = "5a5070",
		band = "a8a0b8",
		silver = true,
		corners = "silverfiligree",
	}),
	-- Three Gilt Fish
	expansion({
		name = "legend",
		earn = "legends",
		tileW = 40,
		tileH = 34,
		gilt = "f0c850",
		band = "16245a",
		corners = "gold",
	}),
	-- Monster Hide
	expansion({
		name = "monster",
		earn = "monster",
		tileW = 90,
		tileH = 78,
		gilt = "c8d0a0",
		band = "2e3a2a",
		corners = "bone",
	}),
	-- Abyssal Black
	expansion({
		name = "abyssal",
		earn = "prestige10",
		tileW = 128,
		tileH = 128,
		gilt = "e8c050",
		band = "0e1018",
		corners = "gold",
	}),
	-- Keeper's Gold
	expansion({
		name = "keeper",
		earn = "ledger",
		tileW = 28,
		tileH = 28,
		gilt = "7a5410",
		band = "c8a868",
		corners = "gold",
	}),
	-- Iridescent Scale
	expansion({
		name = "iridescent",
		earn = "varieties",
		tileW = 150,
		tileH = 196,
		gilt = "f8f0ff",
		band = "6a5a8a",
		silver = true,
		corners = "silver",
	}),
}

--- A binding's good ID (LED-R110).
---@param binding LedgerBinding
---@return string
function ns.BindingID(binding)
	return ns.BINDING_SLOT .. "." .. binding.name
end

--- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
function ns.HexTint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

-- How near a gilt's red and blue are for it to read as silver, which turns the brass plate silver (the kit's).
local SILVER = 0.12
-- How much of the binding's hue the page paper takes ("the page paper cools slightly").
local PAPER_SHARE = 0.1
-- A material's repeat without one of its own, in UI units: the leathers' (their texture is 256 texels at 2 a unit).
local LEATHER_TILE = 128

--- What a binding draws (LED-R110): the material's texture, its repeat and tint, the band's tone, the gilt, whether
--- the plate turns silver, the corner pieces, the page paper's tint and the closed book's swatch.
---@class LedgerBindingLook
---@field texture string         -- the material's texture, tiled
---@field tileW number           -- UI units a repeat, across
---@field tileH number           -- and down
---@field tint? number[]         -- the material's vertex tint; nil for a texture drawn as it is
---@field band? number[]         -- the band's tone (desaturated, then tinted); nil for the band as it is
---@field gilt number[]          -- the crumbs and fleurons (LED-R125)
---@field silver boolean         -- the brass plate turns silver (LED-R149)
---@field corners? LedgerBindingCorners -- the open book's corner pieces; nil for none
---@field paperTint number[]     -- the page paper's vertex tint
---@field swatchAtlas "Bindings"|"Bindings2" -- the closed book's atlas (the shop's preview)
---@field swatch string          -- and its sprite there

--- The look of binding good `goodID` (LED-R112): Field Leather's for an ID that isn't a binding's.
---@param goodID string?
---@return LedgerBindingLook
function ns.BindingLook(goodID)
	local found = ns.BINDINGS[1]
	for _, binding in ipairs(ns.BINDINGS) do
		if ns.BindingID(binding) == goodID then
			found = binding
		end
	end
	local gilt = ns.HexTint(found.gilt)
	local tint, band, paper = found.tint, nil, { 1, 1, 1 }
	if tint then
		local top = math.max(tint[1], tint[2], tint[3])
		band = { tint[1] / top, tint[2] / top, tint[3] / top }
		paper = {
			1 - PAPER_SHARE + PAPER_SHARE * band[1],
			1 - PAPER_SHARE + PAPER_SHARE * band[2],
			1 - PAPER_SHARE + PAPER_SHARE * band[3],
		}
	end
	if found.band then
		local tone, gain = ns.HexTint(found.band), found.bandGain or 1
		band = { math.min(1, tone[1] * gain), math.min(1, tone[2] * gain), math.min(1, tone[3] * gain) }
	end
	local silver = found.silver
	if silver == nil then
		silver = math.abs(gilt[1] - gilt[3]) < SILVER
	end
	return {
		texture = found.texture,
		tileW = found.tileW or LEATHER_TILE,
		tileH = found.tileH or LEATHER_TILE,
		tint = tint,
		band = band,
		gilt = gilt,
		silver = silver,
		corners = found.corners,
		paperTint = paper,
		swatchAtlas = found.swatchAtlas or "Bindings",
		swatch = found.swatch,
	}
end

--- The highest level in the celebrated set, over every climb (LED-R90), or 0 with none.
---@param celebrated LedgerCelebrated
---@return integer
function ns.HighestCelebratedLevel(celebrated)
	local highest = 0
	for _, level in pairs(celebrated.levels or {}) do
		highest = math.max(highest, level)
	end
	return highest
end

--- Whether the level binding of `level` is earned (LED-R111): the higher of the peak level (LED-R35) and the highest
--- celebrated level is at least `level`, so a Prestige or a rebuild never takes one away (LED-R92). Without a state
--- (the projection not built yet), the celebrated level alone.
---@param level integer
---@param state LedgerState?
---@param celebrated LedgerCelebrated
---@return boolean
function ns.LevelBindingEarned(level, state, celebrated)
	local peak = state and ns.PeakLevel(state) or 0
	return math.max(peak, ns.HighestCelebratedLevel(celebrated)) >= level
end

--- Whether the peak level going from `before` to `after` reaches a level binding's level (LED-R111): the moment the
--- Ledger calls `M:RefreshGoods()` after a live entry (SHOP-R31).
---@param before integer
---@param after integer
---@return boolean
function ns.LevelBindingCrossed(before, after)
	for _, binding in ipairs(ns.BINDINGS) do
		local level = binding.level
		if level and before < level and level <= after then
			return true
		end
	end
	return false
end

--- What the Ledger needs to make its goods.
---@class LedgerBindingHooks
---@field earned fun(level: integer): boolean       -- whether that level binding is earned now (LED-R111)
---@field earnedBy fun(goodID: string, rule: LedgerEarnedRule): boolean -- whether an expansion one is (LED-R116)
---@field preview fun(stage: Frame, look: LedgerBindingLook) -- draws the closed book on the shop's stage

--- The Ledger's slot (LED-R110).
---@return PagleSlot
function ns.BindingSlot()
	return { id = ns.BINDING_SLOT, label = ns.L.BINDING_SLOT_LABEL, category = "Fish Journal" }
end

--- A binding's name (LED-R110): its lore, `binding.<name>.name` (LED-R160), or its good's ID while the key has no
--- text (LED-R161).
---@param binding LedgerBinding
---@return string
function ns.BindingName(binding)
	return ns.Lore("binding." .. binding.name .. ".name") or ns.BindingID(binding)
end

--- The goods to register, in LED-R110's order: named from lore (ns.BindingName, and `binding.<name>.description`,
--- LED-R160), with no description while its key has no text. A level binding is earned by its level (LED-R111), an
--- expansion one by its rule (LED-R116), each saying how in its `earnedText`.
---@param hooks LedgerBindingHooks
---@return PagleGood[]
function ns.BindingGoods(hooks)
	local L = ns.L
	local goods = {}
	for i, binding in ipairs(ns.BINDINGS) do
		local id = ns.BindingID(binding)
		local look = ns.BindingLook(id)
		local level, earn = binding.level, binding.earn
		goods[i] = {
			id = id,
			slot = ns.BINDING_SLOT,
			name = ns.BindingName(binding),
			description = ns.Lore("binding." .. binding.name .. ".description"),
			icon = ns.BINDING_ICON,
			default = binding.default,
			tier = binding.tier,
			isEarned = level and function()
				return hooks.earned(level)
			end or earn and function()
				return hooks.earnedBy(id, earn)
			end or nil,
			earnedText = level and L.BINDING_EARNED:format(level) or earn and L.EARNED_TEXT[earn] or nil,
			preview = function(stage)
				hooks.preview(stage, look)
			end,
		}
	end
	return goods
end
