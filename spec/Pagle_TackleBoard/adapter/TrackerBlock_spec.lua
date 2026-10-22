-- The tracker block maker (TKB-R122, TKB-R124, CORE-R73; tackle-board.md › UI, the tracker): a native
-- objective-tracker-style block drawn from line descriptions, in a frame look. The shop's previews draw it now
-- (TKB-R125); the live tracker (adapter/Tracker.lua) fills it with live lines.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Every shown widget under `widget`, depth first, skipping hidden ones and what they hold.
local function shownDescendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			list[#list + 1] = child
			shownDescendants(child, list)
		end
	end
	return list
end

-- The texts of every shown font string under `widget`, depth first.
local function textsOf(widget)
	local texts = {}
	for _, child in ipairs(shownDescendants(widget)) do
		if child.kind == "FontString" and child.text then
			texts[#texts + 1] = child.text
		end
	end
	return texts
end

---@param color number[]
local function rgb(color)
	return { color[1], color[2], color[3] }
end

-- A block on a fresh frame, with the Tackle Board loaded.
local function newBlock()
	local loaded = board.load()
	local ns = loaded.ns
	return ns.NewTrackerBlock(loaded.env.CreateFrame("Frame")), ns, loaded
end

-- The tracker's lines as TKB-R122 lays them out: the header, an Expedition's and a Notice's line pairs, then a plain
-- line.
local LINES = {
	{ kind = "header", text = "Tackle Board", right = "12 · 4 open", fire = true },
	{
		kind = "goal",
		text = "Expedition: Catches in 5 zones of Kalimdor",
		count = "2/5",
		where = "Kalimdor · here",
		expedition = true,
	},
	{ kind = "goal", text = "30 Catches in Durotar", count = "12/30", where = "Durotar · here" },
	{ kind = "line", text = "+2 more on the board (elsewhere)" },
}

describe("A tracker block", function()
	it(
		"draws its lines top to bottom: the header with its right text, each goal's text and count then where, then plain lines (TKB-R122, CORE-R73)",
		function()
			local block = newBlock()

			block:SetLines(LINES)

			assert.are.same({
				"Tackle Board",
				"12 · 4 open",
				"Expedition: Catches in 5 zones of Kalimdor",
				"2/5",
				"Kalimdor",
				" · here",
				"30 Catches in Durotar",
				"12/30",
				"Durotar",
				" · here",
				"+2 more on the board (elsewhere)",
			}, textsOf(block))
		end
	)

	it("grows with its lines, 250 px wide, and hides the rows a shorter list no longer needs (TKB-R122)", function()
		local block, ns = newBlock()

		local tall = block:SetLines(LINES)
		local short = block:SetLines({ LINES[1], LINES[3] })

		assert.are.equal(250, ns.TRACKER_WIDTH)
		assert.are.equal(ns.TRACKER_WIDTH, block:GetWidth())
		assert.is_true(short < tall)
		assert.are.equal(short, block:GetHeight())
		assert.are.same(
			{ "Tackle Board", "12 · 4 open", "30 Catches in Durotar", "12/30", "Durotar", " · here" },
			textsOf(block)
		)
	end)

	it("shows the flame only by a lit fire's days, and its chevron down, or up while collapsed (TKB-R122)", function()
		local block, ns = newBlock()
		local marks = ns.BOARD_ATLASES.Marks

		block:SetLines({ LINES[1] })
		local header = block.rows[1]
		assert.is_true(header.flame:IsShown())
		assert.are.equal(marks.file, header.flame.texture)
		assert.is_true(header.chevron.texCoord[3] < header.chevron.texCoord[4])

		block:SetLines({ { kind = "header", text = "Tackle Board", right = "4 open", collapsed = true } })
		assert.is_false(header.flame:IsShown())
		assert.is_true(header.chevron.texCoord[3] > header.chevron.texCoord[4])
		assert.are.same({ "Tackle Board", "4 open" }, textsOf(block))
	end)

	it('inks " · here" green apart from where the goal is (TKB-R122)', function()
		local block, ns = newBlock()

		block:SetLines(LINES)

		local goal = block.rows[3]
		assert.are.same(ns.BoardHex("8FD18F"), rgb(goal.here.textColor))
		assert.are.same(ns.BoardHex("C8C0A8"), rgb(goal.sub.textColor))
	end)

	it('draws a goal flashing "Complete" as one green line with no where line (TKB-R123)', function()
		local block, ns = newBlock()
		local flashing = { kind = "goal", text = "30 Catches in Durotar", count = "Complete", complete = true }

		block:SetLines({ flashing })

		assert.are.same({ "30 Catches in Durotar", "Complete" }, textsOf(block))
		assert.are.same(ns.BoardHex("9CF09C"), rgb(block.rows[1].text.textColor))
		assert.are.same(ns.BoardHex("9CF09C"), rgb(block.rows[1].right.textColor))
		block:SetFrame(ns.TRACKER_STYLES.cork)
		assert.are.same(ns.BoardHex("1E6A1E"), rgb(block.rows[1].right.textColor))
	end)

	it("gives each row the line it shows, for the live tracker's clicks (TKB-R123)", function()
		local block = newBlock()

		block:SetLines(LINES)

		assert.are.equal(LINES[3], block.rows[3].line)
	end)
end)

describe("A tracker block's frame", function()
	it("is nothing with No frame: each line on a shade, the native look (TKB-R124, TKB-R125)", function()
		local block = newBlock()
		block:SetLines(LINES)

		block:SetFrame(nil)

		assert.is_nil(block.frame)
		assert.is_true(block.rows[3].shade:IsShown())
	end)

	it(
		"slices the Corkboard round its lines, each goal on a slip with a tack, and only then loads its atlas",
		function()
			local block, ns = newBlock()
			block:SetLines(LINES)
			assert.is_nil(block.rows[3].slip)

			block:SetFrame(ns.TRACKER_STYLES.cork)

			local tracker = ns.BOARD_ATLASES.Tracker
			assert.is_true(block.frame:IsShown())
			assert.are.equal(tracker.file, block.frame.top.texture)
			assert.are.same({ 250 + 38, block:GetHeight() }, { block.frame.width, block.frame.height })
			assert.are.same({ "TOPLEFT", -19, 0 }, block.frame.points[1])
			assert.is_true(block.rows[3].slip:IsShown())
			assert.are.equal(tracker.file, block.rows[3].slip.texture)
			assert.is_true(block.rows[3].tack:IsShown())
			assert.is_false(block.rows[3].shade:IsShown())
			assert.are.same(ns.BoardHex("2A180A"), rgb(block.rows[3].text.textColor))
		end
	)

	it("rules the Tideworn Plank's lines apart, and hides a frame's slips back in No frame (TKB-R124)", function()
		local block, ns = newBlock()
		block:SetLines(LINES)

		block:SetFrame(ns.TRACKER_STYLES.cork)
		block:SetFrame(ns.TRACKER_STYLES.drift)

		assert.is_true(block.frame:IsShown())
		assert.is_true(block.rows[3].rule:IsShown()) -- the second goal line, under the first
		assert.is_false(block.rows[2].rule:IsShown())
		assert.is_false(block.rows[3].slip:IsShown())
		assert.are.equal("TACKLE BOARD", block.rows[1].text:GetText())

		block:SetFrame(nil)
		assert.is_false(block.frame:IsShown())
		assert.are.equal("Tackle Board", block.rows[1].text:GetText())
	end)
end)

describe("A tracker block in one of the Curio Shop expansion's frames (TKB-R125)", function()
	-- Each kit frame's style, sprite and goods.json metrics: its insets (left, right, top, foot) and its slice.
	local KIT = {
		net = { "frame-net", { 16, 16, 18, 14 }, { top = 24, foot = 12, mode = "stretch" } },
		bamboo = { "frame-bamboo", { 24, 24, 14, 14 }, { top = 10, foot = 10, mode = "tile", period = 34 } },
		tin = { "frame-tin", { 16, 16, 16, 30 }, { top = 20, foot = 44, mode = "stretch" } },
		-- the kit's top inset of 10 is under the bobber's red band, 14 deep: the words start under both
		bobber = { "frame-bobber", { 16, 50, 24, 14 }, { top = 44, foot = 14, mode = "stretch" } },
		embers = { "frame-embers", { 16, 16, 14, 22 }, { top = 16, foot = 30, mode = "stretch" } },
	}

	-- The pieces of `frame` shown, each as { its anchor's x and y, its width and height, its texture coordinates }.
	local function shownPieces(frame)
		local shown = {}
		for _, piece in ipairs(frame.pieces or {}) do
			if piece:IsShown() then
				local point = piece.points[1]
				shown[#shown + 1] = { point[4], point[5], piece.width, piece.height, piece.texCoord, piece.texture }
			end
		end
		return shown
	end

	it("takes its sprite, insets and slice from the kit's goods.json, in the TrackerFrames2 atlas", function()
		local _, ns = newBlock()

		for name, kit in pairs(KIT) do
			local style = ns.TRACKER_STYLES[name]
			local insets = kit[2]
			assert.are.same(
				{ "TrackerFrames2", kit[1], insets[1], insets[2], insets[3], insets[4], kit[3] },
				{ style.atlas, style.frame, style.left, style.right, style.header + 4, style.pad, style.slice },
				name
			)
			local sprite = ns.BOARD_ATLASES.TrackerFrames2.sprites[kit[1]]
			assert.are.same({ 556, 440, { 8, 6, 262, 200 } }, { sprite.w, sprite.h, sprite.box }, name)
		end
		assert.are.equal(
			"Interface\\AddOns\\Pagle_TackleBoard\\media\\board\\TrackerFrames2",
			ns.BOARD_ATLASES.TrackerFrames2.file
		)
	end)

	it("slices its frame in three round its lines, reaching out by the insets, scaled evenly to its width", function()
		local block, ns = newBlock()
		block:SetLines(LINES)

		block:SetFrame(ns.TRACKER_STYLES.net)

		local atlas = ns.BOARD_ATLASES.TrackerFrames2
		local frame = block.frame
		local height = block:GetHeight()
		assert.is_true(frame:IsShown())
		assert.are.same({ 250 + 32, height }, { frame.width, frame.height })
		assert.are.same({ "TOPLEFT", -16, 0 }, frame.points[1])
		local cut = ns.FrameSlices(atlas, atlas.sprites["frame-net"], KIT.net[3], 250 + 32, height)
		local expected = {}
		for i, piece in ipairs(cut.pieces) do
			expected[i] = {
				cut.x,
				-piece.y,
				cut.width,
				piece.height,
				{ cut.left, cut.right, piece.top, piece.bottom },
				atlas.file,
			}
		end
		assert.are.equal(3, #expected) -- top, stretched middle, foot
		assert.are.same(expected, shownPieces(frame))
	end)

	it("repeats Bamboo Slats' middle down the frame (TKB-R125)", function()
		local block, ns = newBlock()
		block:SetLines(LINES)

		block:SetFrame(ns.TRACKER_STYLES.bamboo)

		assert.is_true(#shownPieces(block.frame) > 3)
	end)

	it("sets its words in by the top and foot insets", function()
		local block, ns = newBlock()
		block:SetLines(LINES)
		local plain = block:GetHeight()

		block:SetFrame(ns.TRACKER_STYLES.tin)

		assert.are.same({ "TOPLEFT", 18, -16 }, block.rows[1].text.points[1])
		-- the header's words 16 down in place of No frame's 4, and 30 under the last line in place of 4
		assert.are.equal(plain + (16 - 4) + (30 - 4), block:GetHeight())
	end)

	it(
		"inks its words in the kit's inks: the header, the text, the dim and the accent for here and Complete",
		function()
			local block, ns = newBlock()
			block:SetFrame(ns.TRACKER_STYLES.embers)

			block:SetLines(LINES)

			local header, goal = block.rows[1], block.rows[3]
			assert.are.same(ns.BoardHex("FFC060"), rgb(header.text.textColor))
			assert.are.same(ns.BoardHex("C8A888"), rgb(header.right.textColor))
			assert.are.same(ns.BoardHex("F6EAD8"), rgb(goal.text.textColor))
			assert.are.same(ns.BoardHex("F6EAD8"), rgb(goal.right.textColor))
			assert.are.same(ns.BoardHex("C8A888"), rgb(goal.sub.textColor))
			assert.are.same(ns.BoardHex("FF9A40"), rgb(goal.here.textColor))
			assert.are.same(ns.BoardHex("C8A888"), rgb(block.rows[4].text.textColor))
			block:SetLines({ { kind = "goal", text = "30 Catches in Durotar", count = "Complete", complete = true } })
			assert.are.same(ns.BoardHex("FF9A40"), rgb(block.rows[1].right.textColor))
		end
	)

	it(
		"puts a kit frame's pieces away for the board kit's frames, and theirs away for a kit frame (TKB-R124)",
		function()
			local block, ns = newBlock()
			block:SetLines(LINES)

			block:SetFrame(ns.TRACKER_STYLES.cork)
			block:SetFrame(ns.TRACKER_STYLES.bobber)
			assert.is_false(block.frame.top:IsShown())
			assert.are.equal(3, #shownPieces(block.frame))

			block:SetFrame(ns.TRACKER_STYLES.drift)
			assert.is_true(block.frame.top:IsShown())
			assert.are.same({}, shownPieces(block.frame))
		end
	)
end)
