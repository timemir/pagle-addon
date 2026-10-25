-- The tier principles for Core's toast styles for sale (SHOP-R25, "Tier principles"): the tiers are pinned, so a later
-- change is deliberate, and no animated (composed, moving) style sits below tier 3, the first animated tier.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- The toast styles Core sells, in the shop's order, as { id, tier }.
local function toastStylesForSale()
	local sold = {}
	for _, slot in ipairs(ns.CORE_GOODS) do
		if slot.id == ns.TOAST_STYLE_SLOT then
			for _, good in ipairs(slot.goods) do
				if good.tier then
					sold[#sold + 1] = { good.id, good.tier }
				end
			end
		end
	end
	return sold
end

-- Whether a style animates: it is composed (layered art) and a layer of any of its rungs carries motion. A static style
-- is one atlas of pages, no layers. The page, ink and stamp entrance is the same for every style (ANN-R80), so it
-- doesn't count.
---@param id string
---@return boolean
local function animated(id)
	local style = ns.ToastStyleOf(id)
	if not (style and style.layered) then
		return false
	end
	for _, rung in pairs(style.art.rungs) do
		for _, layer in ipairs(rung.layers or {}) do
			if layer.motion then
				return true
			end
		end
	end
	return false
end

-- The styles of tier `tier`, by ID without the prefix, sorted.
---@param tier integer
---@return string[]
local function tierOf(tier)
	local ids = {}
	for _, good in ipairs(toastStylesForSale()) do
		if good[2] == tier then
			ids[#ids + 1] = good[1]:gsub("^core%.toaststyle%.", "")
		end
	end
	table.sort(ids)
	return ids
end

describe("Core's toast styles for sale", function()
	it("are the 23 of SHOP-R25, in tiers 1 to 4 and none in tier 5 (the tier principles)", function()
		assert.are.equal(23, #toastStylesForSale())
		assert.are.same({}, tierOf(5))
	end)

	it("sit in the tiers the principles give them, so a later move is deliberate (SHOP-R25)", function()
		-- Tier 1, entry look: Ripple, Ship's Log, Birch Scroll, Tidepool, Lantern Glow, Sea Chart, Frostbitten.
		assert.are.same({ "birch", "chart", "frost", "lanternglow", "ripple", "ship", "tidepool" }, tierOf(1))
		-- Tier 2, richer static art: Goblin Ticker, Illuminated Folio, Kelp & Pearl, Moonlit Vellum, Driftglass Bottle,
		-- Pressed Leaf.
		assert.are.same({ "bottle", "folio", "goblin", "kelp", "leaf", "moon" }, tierOf(2))
		-- Tier 3, the first animated tier: Ooze, Mechanical Angler, Widow's Web, Black Flag, Rune-Plate, Glacier Heart.
		assert.are.same({ "glacier", "ooze", "pirate", "robot", "rune", "spider" }, tierOf(3))
		-- Tier 4, a showpiece: Hive Chitin, Magma Flow, Storm Front, Arcane Sigil.
		assert.are.same({ "arcane", "hive", "magma", "storm" }, tierOf(4))
	end)

	it("animate in nine styles, which are the composed ones Core sells (the guard sees them)", function()
		local moving = {}
		for _, good in ipairs(toastStylesForSale()) do
			if animated(good[1]) then
				moving[#moving + 1] = (good[1]:gsub("^core%.toaststyle%.", ""))
			end
		end
		table.sort(moving)

		assert.are.same({ "arcane", "glacier", "hive", "magma", "ooze", "pirate", "robot", "spider", "storm" }, moving)
	end)

	it("never sell an animated style below tier 3, the first animated tier (the tier principles)", function()
		local below = {}
		for _, good in ipairs(toastStylesForSale()) do
			if good[2] < 3 and animated(good[1]) then
				below[#below + 1] = good[1] .. " tier " .. good[2]
			end
		end

		assert.are.same({}, below)
	end)
end)
