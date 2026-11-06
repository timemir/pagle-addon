-- The Fish Journal's zone tiles on FakePagle (LED-R131): the name kept to its room above the rank line, whatever its
-- length and whether a seal narrows it. The fake measures no font, so a spec stands in for the client's measures
-- (IsTruncated, GetStringHeight) on the tile's name, then draws the spread again over the same tile.

local TILE_H = 76 -- the kit's tile (P.Tile)

-- Opens a spread whose left page is one grid of `tiles`; returns the loaded Ledger and its tiles.
---@param tiles LedgerZoneTile[]
local function drawnTiles(tiles)
	local _, loaded = openJournal({ id = false })
	loaded.ns.RegisterJournalSpread("tiles", {
		crumbs = function()
			return { { label = "Tiles", place = { id = "tiles" } } }
		end,
		draw = function()
			return { left = { { kind = "tiles", tiles = tiles } }, right = {} }
		end,
	})
	loaded.ns.journal:Open("tiles")
	return loaded, loaded.ns.journal.shown.left.drawn.tiles[1].tiles
end

-- Draws the spread again in place (the same tiles, filled anew) and returns its tiles.
local function redrawn(loaded)
	loaded.ns.journal:Draw()
	return loaded.ns.journal.shown.left.drawn.tiles[1].tiles
end

-- How far below its tile's top `region` is placed (its one anchor's y offset, down).
local function top(region)
	local anchor = region.points[1]
	return -anchor[#anchor]
end

-- The print size the tile's name is set in.
local function size(label)
	return label.fontObject.font[2]
end

describe("a zone tile on the Fish Journal's pages (LED-R131)", function()
	it(
		"writes the name in the kit's print from the tile's top, two lines at most, over its rank line and bar",
		function()
			local _, tiles = drawnTiles({
				{ name = "Wetlands", line = "Local · 88%", bar = 0.88 },
				{ name = "Hillsbrad Foothills", line = "unfished · skill ~150", faded = true },
			})

			local wetlands, hillsbrad = tiles[1], tiles[2]
			assert.are.same({ 15.5, "TOP", 2, 8 }, {
				size(wetlands.name),
				wetlands.name.justifyV,
				wetlands.name.maxLines,
				top(wetlands.name),
			})
			-- the kit's places: the rank line at 42, the bar at 62; on a dashed tile, which has no bar, the line at 49
			assert.are.same({ 42, 62, 63 }, { top(wetlands.line), top(wetlands.barCase), top(wetlands.barFill) })
			assert.are.equal(49, top(hillsbrad.line))
		end
	)

	it("sets a name that doesn't fit beside the seal a size smaller, so it ends above its rank line", function()
		local loaded, tiles = drawnTiles({
			{ name = "Redridge Mountains", line = "Master · 100%", bar = 1, seal = "M" },
		})
		-- the client's measures: "Mountains" is wider than the room the seal leaves at 15.5 (so it is cut, "Mountai…"),
		-- and fits at 13.5; two lines of print stand 2 × size + 0.8 (the kit's spacing) tall
		local name = tiles[1].name
		name.IsTruncated = function(self)
			return size(self) > 14
		end
		name.GetStringHeight = function(self)
			return 2 * size(self) + 0.8
		end

		local redridge = redrawn(loaded)[1]

		assert.are.equal(name, redridge.name)
		assert.are.equal(13.5, size(name))
		assert.is_true(top(name) + name:GetStringHeight() <= top(redridge.line))
		assert.are.same({ 42, 62 }, { top(redridge.line), top(redridge.barCase) })
	end)

	it(
		'lays the rank line, its "caught ✓" and the bar under a name whose two lines run taller than the kit\'s',
		function()
			local loaded, tiles = drawnTiles({
				{ name = "Stranglethorn Vale", line = "Local · 63%", bar = 0.63, line2 = "caught" },
			})
			tiles[1].name.GetStringHeight = function()
				return 38
			end

			local vale = redrawn(loaded)[1]

			assert.are.equal(15.5, size(vale.name))
			assert.is_true(top(vale.name) + 38 <= top(vale.line))
			assert.are.same({ 48, 43, 68, 69 }, {
				top(vale.line),
				top(vale.line2),
				top(vale.barCase),
				top(vale.barFill),
			})
		end
	)

	it("never lays the rank line more than 7 under the kit's place, so the bar stays on the tile", function()
		local loaded, tiles = drawnTiles({ { name = "Swamp of Sorrows", line = "Local · 87%", bar = 0.87 } })
		tiles[1].name.GetStringHeight = function()
			return 60
		end

		local swamp = redrawn(loaded)[1]

		assert.are.same({ 49, 69 }, { top(swamp.line), top(swamp.barCase) })
		assert.is_true(top(swamp.barFill) + 4 <= TILE_H)
	end)

	-- A rank line longer than its row was cut by the client: German "Einheimischer · 5…", "unbefischt · jede…" on Home's
	-- tiles and "Stammgast ·…" beside "gefangen ✓" on a fish's (1.1.1). It wraps onto a second line above, its last at
	-- the kit's place over the bar, where a one-line name leaves the room. The client's measures stood in: a line of
	-- italic stands 14 tall, two 29.
	local function twoLinesWhenWrapped(line)
		line.GetStringHeight = function(self)
			local wrapped = self.wordWrap and (self.width or 0) > 0 and #(self.text or "") * 6 > self.width
			return wrapped and 29 or 14
		end
	end

	it("led_r131 wraps a rank line longer than its row onto two lines, its last at the kit's place", function()
		local loaded, tiles = drawnTiles({
			{ name = "Tirisfal Glades", line = "unbefischt · jede Fertigkeit", faded = true },
			{ name = "Duskwood", line = "Einheimischer · 63%", bar = 0.63, line2 = "gefangen" },
			{ name = "Wetlands", line = "Local · 88%", bar = 0.88 },
		})
		for _, tile in ipairs(tiles) do
			twoLinesWhenWrapped(tile.line)
		end
		assert(#tiles[1].line.text * 6 > tiles[1].tileW - 20, "the dashed tile's line is wider than its row")

		local tirisfal, duskwood, wetlands = unpack(redrawn(loaded))

		assert.are.same({ true, 2, tirisfal.tileW - 20, 49 - 15 }, {
			tirisfal.line.wordWrap,
			tirisfal.line.maxLines,
			tirisfal.line:GetWidth(),
			top(tirisfal.line),
		})
		local room = duskwood.tileW - 20 - duskwood.line2:GetWidth() - 6
		assert(#duskwood.line.text * 6 > room, "the line beside caught is wider than what caught leaves")
		assert.are.same({ true, room, 42 - 15, 37, 62 }, {
			duskwood.line.wordWrap,
			duskwood.line:GetWidth(),
			top(duskwood.line),
			top(duskwood.line2),
			top(duskwood.barCase),
		})
		assert(top(duskwood.line) >= top(duskwood.name) + 14 + 2, "under the name's one line")
		-- a line that fits stays one line at the kit's place, as wide as its words
		assert.are.same({ false, 42, #"Local · 88%" * 6 + 1 }, {
			wetlands.line.wordWrap,
			top(wetlands.line),
			wetlands.line:GetWidth(),
		})
	end)

	it("led_r131 keeps a long rank line to one line, cut by the client, under a name of two lines", function()
		local loaded, tiles = drawnTiles({
			{ name = "Stranglethorn Vale", line = "Einheimischer · 63%", bar = 0.63, line2 = "gefangen" },
		})
		twoLinesWhenWrapped(tiles[1].line)
		tiles[1].name.GetStringHeight = function()
			return 38
		end

		local vale = redrawn(loaded)[1]

		assert.are.same({ false, 48, 68 }, { vale.line.wordWrap, top(vale.line), top(vale.barCase) })
		assert(10 + vale.line:GetWidth() <= vale.tileW - 8 - vale.line2:GetWidth(), "and clear of caught")
	end)

	-- "caught ✓" in a longer language ran out of the tile's left edge, over the rank line (#560): it keeps to at most
	-- about half the line's room, and the rank line takes what it leaves.
	it("led_r131 keeps a long caught line on its tile, and the rank line clear of it", function()
		local _, tiles = drawnTiles({
			{
				name = "Stranglethorn Vale",
				line = "Local · 63% of the way to Expert",
				bar = 0.63,
				line2 = "[çàüĝĥţ ĥéŕé ŵĩţĥ à ļõñĝ ŵõŕð]",
			},
		})
		local vale = tiles[1]
		local room = vale.tileW - 20
		local line2W, lineW = vale.line2:GetWidth(), vale.line:GetWidth()

		assert(line2W > 0 and line2W <= room * 0.55, ("caught's %d keeps to its share of %d"):format(line2W, room))
		-- the rank line from 10 in, "caught" ending 8 short of the right: never on each other
		assert(10 + lineW <= vale.tileW - 8 - line2W, "the rank line ends before the caught line starts")
	end)
end)
