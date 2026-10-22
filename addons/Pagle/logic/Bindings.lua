---@class PagleNS
local ns = select(2, ...)

-- The bindings (ADR 0015, wallet-and-shop.md SHOP-R25): the look every book of the Angler's wears, chosen once in
-- Core's slot. Core registers the slot, its default and every binding for sale (logic/CoreGoods.lua); the Modules add
-- only earned ones (the Ledger's, LED-R110, and Hunts', HNT-R122), and Core ships every binding's art and its look,
-- theirs included, as it does a Module's earned toast style. Pure logic, as data (CORE-R7): adapter/CoreGoods.lua
-- draws the closed book on the shop's stage, and the books draw the rest of the look.

--- Core's binding slot (SHOP-R25).
ns.BINDING_SLOT = "core.binding"
--- Field Leather's good ID: the slot's default, and the look for any ID that isn't a binding's.
ns.DEFAULT_BINDING = "core.binding.field"

-- The bindings' art, all Core's (Pagle/media/books): Field Leather's leather (the books' own), the grey leather a
-- vertex tint colours, Birch Bark's bark and Buckram's cloth, the Curio Shop expansion's materials, one per key
-- (`bindings/<key>`), and the two cloths drawn at the book's size (`fills/<key>`).
local BOOKS = "Interface\\AddOns\\Pagle\\media\\books\\"
local FIELD_LEATHER = BOOKS .. "Leather"
local LEATHER_GREY = BOOKS .. "LeatherGrey"
local BARK = BOOKS .. "Bark"
local CLOTH = BOOKS .. "Cloth"
local TILES = BOOKS .. "bindings\\"
local FILLS = BOOKS .. "fills\\"

local ICONS = "Interface\\Icons\\"
--- The icon of every binding the Ledger art kit and the shop expansion's Bindings board drew (the shop's medallion for
--- one put away): the ledger book the Ledger's level-up moment shows.
ns.BINDING_BOOK_ICON = ICONS .. "INV_Misc_Book_09"

--- The corner pieces a binding's book wears, as the shop expansion kit's Bindings board draws them.
---@alias PagleBindingCorners "brass"|"gold"|"silver"|"iron"|"bone"|"pearl"|"silverfiligree"

--- A binding as data: its key (the last part of its good ID, and of Core's lore keys `binding.<key>.*`), its good ID,
--- what kind of good it is (Field Leather the default, a `tier` for sale, or `earned`, registered by the Module whose
--- prefix its ID has), its icon, and its look as the kits measured it. The material is a `texture` tiled at `tileW` ×
--- `tileH` UI units a repeat (128 square without one), under a vertex `tint` for the grey leather, or a `fill` drawn at
--- the book's size; the gilt of the crumbs, fleurons and plate ("RRGGBB"); the band's tone ("RRGGBB", times `bandGain`;
--- the tint's own hue where none is given); whether the plate is silver, where a kit says (else a silver gilt makes it
--- so); its corner pieces; how dark its material turns toward the foot; Tooled Leather's gilt double rule and
--- Verdigris's gilt corner; and its closed-book swatch.
---@class PagleBinding
---@field key string
---@field id string
---@field default? true
---@field tier? 1|2|3|4|5           -- Tunables: Core goods' tiers
---@field earned? true              -- registered by a Module, earned by its rule (SHOP-R23)
---@field icon string
---@field texture? string
---@field fill? string
---@field tileW? number
---@field tileH? number
---@field tint? number[]
---@field gilt string
---@field band? string
---@field bandGain? number
---@field silver? boolean
---@field corners? PagleBindingCorners
---@field foot? number
---@field tooled? true
---@field giltCorner? true
---@field swatchAtlas? "Bindings"|"Bindings2"|"Covers2"
---@field swatch? string

-- Field Leather's gilt (the Ledger art kit's), the gilt of any binding no kit gives one.
local FIELD_GILT = "e8c96a"
-- The shop expansion kit draws its band tones at 1.9 times their colour over the band's luminance (its board's tint
-- filter), on its bindings and its covers alike.
local EXPANSION_BAND_GAIN = 1.9
-- How dark a material turns toward its foot (1 none): Field Leather's, the books kit v2's Tooled Leather's, and the
-- shop expansion's covers' (its board shades them 18% darker toward the foot).
local FIELD_FOOT, TOOLED_FOOT, COVER_FOOT = 0.8, 0.75, 0.82

-- A binding's good ID: Core's for one it registers, a Module's for one it earns (`ledger.binding.<key>`,
-- `hunts.binding.<key>`).
---@param owner "core"|"ledger"|"hunts"
---@param key string
---@return string
local function idOf(owner, key)
	return owner .. ".binding." .. key
end

-- One of the Ledger art kit's ten (its Bindings board, `bindings.json`): its swatch in the Bindings atlas, drawn in
-- the ledger book's icon.
---@param owner "core"|"ledger"
---@param binding table a PagleBinding but for its ID, icon and swatch atlas
---@return PagleBinding
local function ledgerKit(owner, binding)
	binding.id = idOf(owner, binding.key)
	binding.icon = ns.BINDING_BOOK_ICON
	binding.swatchAtlas = "Bindings"
	return binding
end

-- One of the shop expansion kit's bindings (its Bindings board, `goods.json`): its own material unless it names
-- another, a brass plate unless it says silver (never read from its gilt), and its swatch `swatch-<key>` in the
-- Bindings2 atlas.
---@param owner "core"|"ledger"
---@param binding table a PagleBinding but for its ID, icon, band gain and swatch
---@return PagleBinding
local function expansion(owner, binding)
	binding.id = idOf(owner, binding.key)
	binding.icon = ns.BINDING_BOOK_ICON
	binding.texture = binding.texture or TILES .. binding.key
	binding.bandGain = EXPANSION_BAND_GAIN
	binding.silver = binding.silver == true
	binding.swatchAtlas = "Bindings2"
	binding.swatch = "swatch-" .. binding.key
	return binding
end

-- One of the shop expansion kit's covers (its goods.json): its material at its repeat, also its icon, its band's tone
-- and its corners, Field Leather's gilt and a brass plate (the kit gives a cover neither), darker toward its foot, and
-- its swatch `swatch-<key>` in the Covers2 atlas.
---@param owner "core"|"hunts"
---@param key string
---@param tileW number
---@param tileH number
---@param band string
---@param corners PagleBindingCorners?
---@param tier (1|2|3|4|5)?
---@return PagleBinding
local function cover(owner, key, tileW, tileH, band, corners, tier)
	return {
		key = key,
		id = idOf(owner, key),
		tier = tier,
		earned = owner ~= "core" or nil,
		icon = TILES .. key,
		texture = TILES .. key,
		tileW = tileW,
		tileH = tileH,
		gilt = FIELD_GILT,
		band = band,
		bandGain = EXPANSION_BAND_GAIN,
		silver = false,
		corners = corners,
		foot = COVER_FOOT,
		swatchAtlas = "Covers2",
		swatch = "swatch-" .. key,
	}
end

--- Every binding, in the kits' order: the Ledger art kit's ten, the shop expansion's twenty bindings, the books kit
--- v2's three covers and the shop expansion's fifteen covers. Core registers the default and those for sale in its
--- shop order (ns.CoreBindings); the Ledger and Hunts register the earned ones. Every look is Core's, theirs included.
---@type PagleBinding[]
ns.BINDINGS = {
	ledgerKit("core", {
		key = "field",
		default = true,
		texture = FIELD_LEATHER,
		gilt = FIELD_GILT,
		foot = FIELD_FOOT,
		swatch = "binding-field-leather",
	}),
	ledgerKit("ledger", {
		key = "level10", -- Tanned Hide
		earned = true,
		texture = LEATHER_GREY,
		tint = { 0.736, 0.386, 0.008 },
		gilt = "f0d890",
		swatch = "binding-tanned-hide",
	}),
	ledgerKit("ledger", {
		key = "level20", -- Tidewater Blue
		earned = true,
		texture = LEATHER_GREY,
		tint = { 0.188, 0.363, 0.563 },
		gilt = "c9ccd3",
		swatch = "binding-tidewater-blue",
	}),
	ledgerKit("ledger", {
		key = "level30", -- Reed Green
		earned = true,
		texture = LEATHER_GREY,
		tint = { 0.207, 0.422, 0.192 },
		gilt = "d8c47a",
		swatch = "binding-reed-green",
	}),
	ledgerKit("ledger", {
		key = "level40", -- Oxblood
		earned = true,
		texture = LEATHER_GREY,
		tint = { 0.689, 0.179, 0.179 },
		gilt = "f2c230",
		swatch = "binding-oxblood",
	}),
	ledgerKit("ledger", {
		key = "level50", -- Storm Grey
		earned = true,
		texture = LEATHER_GREY,
		tint = { 0.296, 0.341, 0.381 },
		gilt = "c9ccd3",
		swatch = "binding-storm-grey",
	}),
	ledgerKit("ledger", {
		key = "level60", -- Nat's Own
		earned = true,
		texture = LEATHER_GREY,
		tint = { 0.213, 0.174, 0.147 },
		gilt = "ffd100",
		swatch = "binding-nats-own",
	}),
	ledgerKit("core", {
		key = "birch",
		tier = 1,
		texture = BARK,
		tileW = 256,
		tileH = 256,
		gilt = "6a4a20",
		band = "b8a888",
		swatch = "binding-birch-bark",
	}),
	ledgerKit("core", {
		key = "buckram", -- Sea-Green Buckram
		tier = 2,
		texture = CLOTH,
		tileW = 256,
		tileH = 256,
		gilt = "efe0bb",
		band = "6a9a8c",
		swatch = "binding-sea-green-buckram",
	}),
	ledgerKit("core", {
		key = "sharkskin",
		tier = 3,
		texture = LEATHER_GREY,
		tint = { 0.235, 0.282, 0.306 },
		gilt = "dfe2e8",
		swatch = "binding-sharkskin",
	}),
	-- Tide-Chart Linen
	expansion("core", {
		key = "chartlinen",
		tier = 1,
		tileW = 256,
		tileH = 256,
		gilt = "1e3a5a",
		band = "5a7a90",
		corners = "brass",
	}),
	-- Tarred Sailcloth
	expansion("core", { key = "sailcloth", tier = 1, tileW = 128, tileH = 128, gilt = "d8c08a", band = "3a342a" }),
	-- Oilskin Yellow
	expansion("core", { key = "oilskin", tier = 1, tileW = 200, tileH = 200, gilt = "3a2a08", band = "b88a10" }),
	-- Mossbound
	expansion("core", {
		key = "moss",
		tier = 2,
		tileW = 160,
		tileH = 160,
		gilt = "c8d880",
		band = "4a5a2a",
		corners = "brass",
	}),
	-- Driftwood Boards
	expansion("core", {
		key = "driftwood",
		tier = 2,
		tileW = 150,
		tileH = 196,
		gilt = "d8d0c0",
		band = "5a5448",
		corners = "iron",
	}),
	-- Eelskin
	expansion("core", {
		key = "eelskin",
		tier = 2,
		tileW = 64,
		tileH = 64,
		gilt = "b8c08a",
		band = "2a2e1e",
		silver = true,
		corners = "silver",
	}),
	-- Kodo Hide
	expansion("core", {
		key = "kodo",
		tier = 2,
		tileW = 220,
		tileH = 220,
		gilt = "f0d8a8",
		band = "7a4a24",
		corners = "bone",
	}),
	-- Frost-Tanned Hide
	expansion("core", {
		key = "frosthide",
		tier = 2,
		tileW = 180,
		tileH = 180,
		gilt = "3a5a7a",
		band = "8aa0b0",
		silver = true,
		corners = "silver",
	}),
	-- Net over Cork
	expansion("core", { key = "netcork", tier = 2, tileW = 140, tileH = 140, gilt = "2a1a08", band = "8a5a2a" }),
	-- Riveted Copper
	expansion("core", { key = "copper", tier = 3, tileW = 150, tileH = 196, gilt = "ffd0a8", band = "8a4024" }),
	-- Night Velvet
	expansion("core", {
		key = "velvet",
		tier = 3,
		tileW = 200,
		tileH = 200,
		gilt = "dfe6ff",
		band = "1e2a5a",
		silver = true,
		corners = "silver",
	}),
	-- Turtle Shell
	expansion("core", {
		key = "turtle",
		tier = 3,
		tileW = 150,
		tileH = 196,
		gilt = "f0c060",
		band = "5a2e0e",
		corners = "gold",
	}),
	-- Gilded Morocco
	expansion("core", {
		key = "morocco",
		tier = 3,
		tileW = 52,
		tileH = 52,
		gilt = "f0c850",
		band = "7a0e16",
		corners = "gold",
	}),
	-- Coral Inlay
	expansion("core", {
		key = "coral",
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
	expansion("core", {
		key = "pearl",
		tier = 5,
		tileW = 150,
		tileH = 196,
		gilt = "5a5070",
		band = "a8a0b8",
		silver = true,
		corners = "silverfiligree",
	}),
	-- Three Gilt Fish
	expansion("ledger", {
		key = "legend",
		earned = true,
		tileW = 40,
		tileH = 34,
		gilt = "f0c850",
		band = "16245a",
		corners = "gold",
	}),
	-- Monster Hide
	expansion("ledger", {
		key = "monster",
		earned = true,
		tileW = 90,
		tileH = 78,
		gilt = "c8d0a0",
		band = "2e3a2a",
		corners = "bone",
	}),
	-- Abyssal Black
	expansion("ledger", {
		key = "abyssal",
		earned = true,
		tileW = 128,
		tileH = 128,
		gilt = "e8c050",
		band = "0e1018",
		corners = "gold",
	}),
	-- Keeper's Gold
	expansion("ledger", {
		key = "keeper",
		earned = true,
		tileW = 28,
		tileH = 28,
		gilt = "7a5410",
		band = "c8a868",
		corners = "gold",
	}),
	-- Iridescent Scale
	expansion("ledger", {
		key = "iridescent",
		earned = true,
		tileW = 150,
		tileH = 196,
		gilt = "f8f0ff",
		band = "6a5a8a",
		silver = true,
		corners = "silver",
	}),
	-- The books kit v2's covers (its Covers.lua): Oilcloth, a waxed green cloth drawn at the book's size; Tooled
	-- Leather, Field Leather's leather darker at its foot with a gilt double rule; Verdigris, copper gone green, with a
	-- gilt corner. No kit has a closed book of them.
	{
		key = "oilcloth",
		id = idOf("core", "oilcloth"),
		tier = 1,
		icon = ICONS .. "INV_Fabric_Felcloth_Ebon",
		fill = FILLS .. "oilcloth",
		gilt = FIELD_GILT,
		silver = false,
	},
	{
		key = "tooled",
		id = idOf("core", "tooled"),
		tier = 2,
		icon = ICONS .. "Trade_LeatherWorking",
		texture = FIELD_LEATHER,
		gilt = FIELD_GILT,
		silver = false,
		foot = TOOLED_FOOT,
		tooled = true,
	},
	{
		key = "verdigris",
		id = idOf("core", "verdigris"),
		tier = 3,
		icon = ICONS .. "INV_Ore_Copper_01",
		fill = FILLS .. "verdigris",
		gilt = FIELD_GILT,
		silver = false,
		giltCorner = true,
	},
	cover("core", "canvas", 96, 96, "6a5e3a", nil, 1),
	cover("core", "kraft", 180, 180, "7a5a30", nil, 1),
	cover("core", "tartan", 96, 96, "14244a", nil, 1),
	cover("core", "maplinen", 150, 196, "5a6a7a", nil, 2),
	cover("core", "planks", 150, 196, "5a3414", nil, 2),
	cover("core", "snakeskin", 40, 40, "3a4a1e", "brass", 3),
	cover("core", "shagreen", 60, 60, "4a6a60", "silver", 3),
	cover("core", "lacquer", 150, 196, "8a1410", "gold", 3),
	cover("core", "bone", 200, 200, "8a6a3a", nil, 3),
	cover("core", "brasscase", 150, 196, "8a5a14", nil, 3),
	cover("core", "scrimshaw", 150, 196, "3a2410", "bone", 4),
	cover("core", "trophycase", 150, 196, "3a1a08", "gold", 5),
	cover("hunts", "pathfinder", 200, 200, "7a4818", "brass"),
	cover("hunts", "fiveseal", 128, 128, "1a1612"),
	cover("hunts", "wagersilk", 56, 56, "3a1450", "gold"),
}

-- Each binding by its good ID.
---@type table<string, PagleBinding>
local BY_ID = {}
for _, binding in ipairs(ns.BINDINGS) do
	BY_ID[binding.id] = binding
end

--- The bindings Core registers in its slot, in the shop's order (SHOP-R21, SHOP-R25): Field Leather, then those for
--- sale by tier, cheapest first, each tier's in the kits' order (ns.BINDINGS). The Modules' earned ones list after
--- them, as they register.
---@return PagleBinding[]
function ns.CoreBindings()
	local list, byTier = {}, { {}, {}, {}, {}, {} }
	for _, binding in ipairs(ns.BINDINGS) do
		if binding.default then
			list[#list + 1] = binding
		elseif binding.tier then
			local tier = byTier[binding.tier]
			tier[#tier + 1] = binding
		end
	end
	for _, tier in ipairs(byTier) do
		for _, binding in ipairs(tier) do
			list[#list + 1] = binding
		end
	end
	return list
end

-- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
local function hexTint(hex)
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
-- A gilt this light or less (Rec. 709 weights over its hex values) is dark ink on a light material: its words take
-- a light edge under them, pressed into the material, never the black shadow that blurs dark words on birch.
local DARK_GILT = 0.45
-- The crumbs' shadow under a light gilt, as the kit's font draws words on the leather, and the pressed edge under a
-- dark one: { r, g, b, a, x, y }.
local GILT_SHADOW = { 0, 0, 0, 0.95, 0, -1 }
local PRESSED_EDGE = { 1, 0.96, 0.86, 0.6, 0, -1 }

--- What a binding draws, on every book alike: its material (a texture tiled at its repeat, or a fill drawn at the
--- book's size, exactly one of them), its tint, how dark it turns toward the foot, the band's tone, the gilt and its
--- shadow, whether the plate turns silver, the corner pieces, Tooled Leather's double gilt rule and Verdigris's gilt
--- corner, the page paper's tint and the closed book's swatch.
---@class PagleBindingLook
---@field texture? string        -- the material's texture, tiled at tileW × tileH
---@field fill? string           -- or a cloth drawn at the frame's size (Oilcloth, Verdigris)
---@field tileW number           -- UI units a repeat, across
---@field tileH number           -- and down
---@field tint? number[]         -- the material's vertex tint; nil for a texture drawn as it is
---@field foot number            -- how dark the material turns toward its foot: 1 none
---@field band? number[]         -- the band's tone (desaturated, then tinted); nil for the band as it is
---@field gilt number[]          -- the crumbs, fleurons and plate's ink
---@field giltShadow number[]    -- the crumbs' shadow, { r, g, b, a, x, y }: a light pressed edge under a dark gilt
---@field silver boolean         -- the brass plate turns silver
---@field corners? PagleBindingCorners -- the book's corner pieces; nil for none
---@field tooled? boolean        -- Tooled Leather's gilt double rule inside the band
---@field giltCorner? boolean    -- Verdigris's gilt corner at the top left
---@field paperTint number[]     -- the page paper's vertex tint
---@field swatchAtlas? "Bindings"|"Bindings2"|"Covers2" -- the closed book's atlas (the shop's preview)
---@field swatch? string         -- and its sprite there; nil where no kit drew one (Oilcloth, Tooled, Verdigris)

--- The look of binding `goodID`, a fresh table: Field Leather's for an ID that isn't a binding's.
---@param goodID string?
---@return PagleBindingLook
function ns.BindingLook(goodID)
	local found = BY_ID[goodID] or BY_ID[ns.DEFAULT_BINDING]
	local gilt = hexTint(found.gilt)
	local tint, band, paper = found.tint, nil, { 1, 1, 1 }
	if tint then
		local top = math.max(tint[1], tint[2], tint[3])
		band = { tint[1] / top, tint[2] / top, tint[3] / top }
		paper = {
			1 - PAPER_SHARE + PAPER_SHARE * band[1],
			1 - PAPER_SHARE + PAPER_SHARE * band[2],
			1 - PAPER_SHARE + PAPER_SHARE * band[3],
		}
		tint = { tint[1], tint[2], tint[3] }
	end
	if found.band then
		local tone, gain = hexTint(found.band), found.bandGain or 1
		band = { math.min(1, tone[1] * gain), math.min(1, tone[2] * gain), math.min(1, tone[3] * gain) }
	end
	local silver = found.silver
	if silver == nil then
		silver = math.abs(gilt[1] - gilt[3]) < SILVER
	end
	local shadow = 0.2126 * gilt[1] + 0.7152 * gilt[2] + 0.0722 * gilt[3] <= DARK_GILT and PRESSED_EDGE or GILT_SHADOW
	return {
		texture = found.texture,
		fill = found.fill,
		tileW = found.tileW or LEATHER_TILE,
		tileH = found.tileH or LEATHER_TILE,
		tint = tint,
		foot = found.foot or 1,
		band = band,
		gilt = gilt,
		giltShadow = { unpack(shadow) },
		silver = silver,
		corners = found.corners,
		tooled = found.tooled,
		giltCorner = found.giltCorner,
		paperTint = paper,
		swatchAtlas = found.swatchAtlas,
		swatch = found.swatch,
	}
end
