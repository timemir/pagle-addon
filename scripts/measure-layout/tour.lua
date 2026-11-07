-- The layout harness's run (scripts/measure-layout.sh): `/pagle dev tour` on the package as shipped, every roster
-- Module loaded (as spec/tour_spec.lua loads it), in one Language, every font string measured in its real face
-- (realfont.lua, which helper.lua installs). At each stop's screenshot it writes what every shown surface draws and
-- what's wrong with its text, for scripts/measure-layout.py to report and draw. Not a spec: its name keeps it out of
-- the check gate's busted run.
--
--   MEASURE_LANG=deDE MEASURE_OUT=build/measure-layout/deDE [MEASURE_MODULE=hunts] \
--     .tools/bin/busted --helper=scripts/measure-layout/helper.lua scripts/measure-layout/tour.lua
--
-- Writes, into MEASURE_OUT: findings.jsonl (one finding a line: its stop, kind, text and detail), errors.txt (any
-- error the addons raised on the tour) and, per stop, NN-<stop>.jsonl (the stop's name, then every shown region of
-- every shown surface with its screen rect) for the PNGs.

-- The RealFont helper.lua installed: the one that knows the client's font objects by name, as the toasts are set.
local RealFont = assert(MEASURE_REALFONT, "run with --helper=scripts/measure-layout/helper.lua")
local json = require("dkjson")

local LANGUAGE = os.getenv("MEASURE_LANG") or "enUS"
-- "pseudo" is the development pseudo-locale (#524) on an enUS client: every string padded, accented and bracketed,
-- as `/pagle dev pseudo on` and a /reload show it.
local PSEUDO = LANGUAGE == "pseudo"
local LOCALE = PSEUDO and "enUS" or LANGUAGE
local MODULE = os.getenv("MEASURE_MODULE") or ""
local OUT = assert(os.getenv("MEASURE_OUT"), "MEASURE_OUT names the folder to write into")

-- The roster Modules' folders, in CORE-R1 order (spec/tour_spec.lua's ROSTER).
local ROSTER = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" }

-- How far ink may pass its surface's edge, in units, before it counts: line heights are estimates.
local EDGE = 2
-- How far two inks must cross, both ways, to overlap.
local SLACK = 1.5
-- A texture or line this thin (and at least LONG long) is a rule the text must not cross, such as Hunts' now line.
local THIN, LONG = 3, 12
-- A texture at least this big both ways is paper a text may sit on.
local PAPER = 8
-- What counts as drawn: an alpha above this, its parents' times its own.
local SEEN = 0.05

-- Whether `region` and its parents are all shown, and their alphas multiplied are above SEEN.
---@param region table
---@return boolean
local function visible(region)
	local alpha = 1
	local r = region
	while r do
		if r.shown == false then
			return false
		end
		alpha = alpha * (r.alpha or 1)
		r = r.parent
	end
	return alpha > SEEN
end

-- The nearest parent of `region`, below `root`, that keeps what it holds inside it: a scroll frame (its width only,
-- since its child scrolls) or a frame that clips its children. Nil for none.
---@param region table
---@param root table
---@return table? frame
---@return boolean scrolls
local function clipper(region, root)
	local r = region.parent
	while r and r ~= root do
		if r.scrollChild then
			return r, true
		elseif r.clipsChildren then
			return r, false
		end
		r = r.parent
	end
	return nil, false
end

-- Where a thin texture or line draws, as a rect, or nil if it isn't one.
---@param region table
---@param memo table
---@return number[]?
local function rule(region, memo)
	if region.kind == "Line" and region.startPoint and region.endPoint then
		local function at(point)
			local relative = type(point[2]) == "table" and RealFont.rect(point[2], memo)
			if not relative then
				return nil
			end
			local p = point[1]
			local x = p:find("LEFT") and relative[1]
				or p:find("RIGHT") and relative[3]
				or (relative[1] + relative[3]) / 2
			local y = p:find("TOP") and relative[2]
				or p:find("BOTTOM") and relative[4]
				or (relative[2] + relative[4]) / 2
			return x + point[3], y - point[4]
		end
		local x1, y1 = at(region.startPoint)
		local x2, y2 = at(region.endPoint)
		if not (x1 and x2) then
			return nil
		end
		local half = (region.thickness or 1) / 2
		local box =
			{ math.min(x1, x2) - half, math.min(y1, y2) - half, math.max(x1, x2) + half, math.max(y1, y2) + half }
		if math.min(box[3] - box[1], box[4] - box[2]) <= THIN then
			return box
		end
		return nil
	end
	if region.kind ~= "Texture" or not (region.color or region.texture) then
		return nil
	end
	local box = RealFont.rect(region, memo)
	if not box then
		return nil
	end
	local w, h = box[3] - box[1], box[4] - box[2]
	if math.min(w, h) <= THIN and math.max(w, h) >= LONG then
		return box
	end
	return nil
end

-- Whether boxes a and b cross by more than `slack` both ways.
local function crosses(a, b, slack)
	return a[1] + slack < b[3] and b[1] + slack < a[3] and a[2] + slack < b[4] and b[2] + slack < a[4]
end

local function round(box)
	return {
		math.floor(box[1] * 10 + 0.5) / 10,
		math.floor(box[2] * 10 + 0.5) / 10,
		math.floor(box[3] * 10 + 0.5) / 10,
		math.floor(box[4] * 10 + 0.5) / 10,
	}
end

-- A name for a surface: its global name, else its kind and place in the client's frames.
local function surfaceName(root, index)
	return root.name or ("%s#%d"):format(root.kind, index)
end

-- What one surface draws (for the PNGs) and what's wrong with its text: appended to `regions` and `findings`.
---@param root table
---@param name string
---@param memo table RealFont.rect's, for the stop
---@param regions table[]
---@param findings table[]
local function measure(root, name, memo, regions, findings)
	local rootBox = RealFont.rect(root, memo)
	local texts, rules, papers, pieces = {}, {}, {}, {}

	local function walk(region)
		if region.shown == false then
			return
		end
		local box = RealFont.rect(region, memo)
		if box and visible(region) then
			local record = { kind = region.kind, rect = round(box), surface = name }
			if region.kind == "FontString" then
				if region.text and region.text ~= "" then
					local layout = RealFont.layout(region)
					local ink = RealFont.inked(region, memo)
					record.text, record.lines, record.font = region.text, layout.lines, layout.file
					local scale = RealFont.scale(region)
					record.size, record.cut, record.justify =
						layout.size * scale, layout.cut ~= nil, region.justifyH or "CENTER"
					record.line = RealFont.lineHeight(layout.file, layout.size) * scale
					record.ink = ink and round(ink)
					local c = region.textColor or { 1, 0.82, 0 }
					record.color = { c[1] or 0, c[2] or 0, c[3] or 0 }
					regions[#regions + 1] = record
					texts[#texts + 1] = { region = region, layout = layout, ink = ink, line = record.line }
				end
			else
				if region.kind == "Texture" and region.color then
					record.color = region.color
				end
				regions[#regions + 1] = record
				local thin = rule(region, memo)
				if thin then
					rules[#rules + 1] = { region = region, box = thin }
				elseif region.kind == "Texture" and (region.texture or region.color) then
					pieces[#pieces + 1] = box
				end
				if
					not thin
					and region.kind == "Texture"
					and (region.texture or region.color)
					and box[3] - box[1] >= PAPER
					and box[4] - box[2] >= PAPER
				then
					papers[#papers + 1] = box
				end
			end
		end
		for _, child in ipairs(region.children or {}) do
			walk(child)
		end
	end
	walk(root)

	-- What each rule shows of itself, as a text does: inside the scroll frame that holds it, or nothing once scrolled out
	-- of view (a row's thin mark under the list's foot, where the legend's wrapped row is). And a thin texture with a
	-- piece of its own height touching each of its long sides is the middle of a three-slice (a chip behind a short word,
	-- "…"), part of one wider shape, not a rule.
	local function touching(box, across)
		local a, b, lo, hi = 1, 3, 2, 4
		if not across then
			a, b, lo, hi = 2, 4, 1, 3
		end
		local before, after = false, false
		for _, piece in ipairs(pieces) do
			if math.abs(piece[lo] - box[lo]) <= 0.5 and math.abs(piece[hi] - box[hi]) <= 0.5 then
				before = before or math.abs(piece[b] - box[a]) <= 0.5
				after = after or math.abs(piece[a] - box[b]) <= 0.5
			end
		end
		return before and after
	end
	local kept = {}
	for _, r in ipairs(rules) do
		local box = r.box
		local frame, scrolls = clipper(r.region, root)
		local view = frame and scrolls and RealFont.rect(frame, memo)
		if view then
			local top, bottom = math.max(box[2], view[2]), math.min(box[4], view[4])
			box = bottom > top and { box[1], top, box[3], bottom } or nil
		end
		if box and not (r.region.kind == "Texture" and touching(r.box, r.box[3] - r.box[1] <= r.box[4] - r.box[2])) then
			kept[#kept + 1] = { region = r.region, box = box }
		end
	end
	rules = kept

	local function find(kind, text, detail, estimated, other)
		findings[#findings + 1] = {
			surface = name,
			kind = kind,
			text = text,
			other = other,
			detail = detail,
			estimated = estimated or nil,
		}
	end

	-- What each text shows of itself: its ink inside the scroll frame that holds it, or nil if scrolled out of view;
	-- and its em box, the ink's lines each one size tall rather than one line height, for overlaps.
	for _, t in ipairs(texts) do
		local frame, scrolls = clipper(t.region, root)
		t.frame, t.scrolls = frame, scrolls
		t.seen = t.ink
		if t.ink and frame and scrolls then
			local view = RealFont.rect(frame, memo)
			if view then
				local top, bottom = math.max(t.ink[2], view[2]), math.min(t.ink[4], view[4])
				t.seen = bottom > top and { t.ink[1], top, t.ink[3], bottom } or nil
			end
		end
		if t.seen then
			local trim = math.max(0, (t.line - t.layout.size * RealFont.scale(t.region)) / 2)
			t.em = { t.seen[1], t.seen[2] + trim, t.seen[3], t.seen[4] - trim }
		end
	end

	-- A surface drawn on a ground (a texture over half of it, as a book's paper or a card's) holds its texts on its
	-- textures; one with none (the plain tracker, over the world) only inside its edges.
	local backed = false
	if rootBox then
		local area = (rootBox[3] - rootBox[1]) * (rootBox[4] - rootBox[2])
		for _, box in ipairs(papers) do
			if area > 0 and (box[3] - box[1]) * (box[4] - box[2]) >= area / 2 then
				backed = true
			end
		end
	end

	-- Whether the point x, y lies on one of the surface's textures, EDGE allowed.
	local function onPaper(x, y)
		for _, box in ipairs(papers) do
			if x >= box[1] - EDGE and x <= box[3] + EDGE and y >= box[2] - EDGE and y <= box[4] + EDGE then
				return true
			end
		end
		return false
	end

	local function where(ink)
		return ("ink [%.0f,%.0f,%.0f,%.0f]"):format(ink[1], ink[2], ink[3], ink[4])
	end

	for _, t in ipairs(texts) do
		local region, layout, ink = t.region, t.layout, t.seen
		if layout.cut then
			find(
				"cut",
				region.text,
				("%s: %.0f wide in %.0f"):format(layout.cut, layout.natural, region:GetWidth() or 0),
				layout.estimated
			)
		end
		if ink and t.frame then
			-- Past the sides of the scroll frame that holds it, or any edge of a frame that clips it.
			local bounds = RealFont.rect(t.frame, memo)
			if bounds then
				local most = math.max(
					bounds[1] - ink[1],
					ink[3] - bounds[3],
					t.scrolls and -math.huge or bounds[2] - ink[2],
					t.scrolls and -math.huge or ink[4] - bounds[4]
				)
				if most > EDGE then
					find(
						"out",
						region.text,
						("%.0f past %s: %s"):format(
							most,
							t.scrolls and "the sides of its scroll frame" or "a frame that clips it",
							where(ink)
						),
						layout.estimated
					)
				end
			end
		elseif ink and backed then
			-- Off the page: a corner or the middle of its em box over none of its surface's textures.
			local box = t.em
			local inset = math.min(EDGE, (box[3] - box[1]) / 2, (box[4] - box[2]) / 2)
			local l, tp, r, b = box[1] + inset, box[2] + inset, box[3] - inset, box[4] - inset
			if
				not (
					onPaper(l, tp)
					and onPaper(r, tp)
					and onPaper(l, b)
					and onPaper(r, b)
					and onPaper((l + r) / 2, (tp + b) / 2)
				)
			then
				find("out", region.text, "off its surface's textures: " .. where(ink), layout.estimated)
			end
		elseif ink and rootBox and rootBox[3] - rootBox[1] > 0 and rootBox[4] - rootBox[2] > 0 then
			-- A surface with no texture: past its edges.
			local most = math.max(rootBox[1] - ink[1], ink[3] - rootBox[3], rootBox[2] - ink[2], ink[4] - rootBox[4])
			if most > EDGE then
				find("out", region.text, ("%.0f past its surface: %s"):format(most, where(ink)), layout.estimated)
			end
		end
	end

	-- Overlap: two texts' em boxes crossing (a text drawn twice, as a shadow, is one), and a text crossing a rule.
	for i = 1, #texts do
		local a = texts[i]
		if a.em then
			for j = i + 1, #texts do
				local b = texts[j]
				if b.em and a.region.text ~= b.region.text and crosses(a.em, b.em, SLACK) then
					find(
						"overlap",
						a.region.text,
						"inks cross",
						a.layout.estimated or b.layout.estimated,
						b.region.text
					)
				end
			end
			for _, r in ipairs(rules) do
				if crosses(a.em, r.box, SLACK) then
					local w, h = r.box[3] - r.box[1], r.box[4] - r.box[2]
					find(
						"overlap",
						a.region.text,
						("crosses a %.0fx%.0f rule at [%.0f,%.0f]"):format(w, h, r.box[1], r.box[2]),
						a.layout.estimated,
						"(rule)"
					)
				end
			end
		end
	end
end

-- The surfaces shown now: every shown frame the addons made whose parent they didn't make (UIParent, the minimap),
-- except Core's tracker dock: its anchor draws nothing and only stacks the trackers parented to it (CORE-R70, CORE-R72),
-- each one its Module's own, on its own ground or none, so each shown docked tracker is a surface instead. Taken as
-- one, the First evening list's paper covered over half the stack, and the plain Hunts tracker under it, over the
-- world by design, was judged against that paper (#618).
---@param client table
---@param dock table? Core's dock anchor (ns.dockFrame)
---@return { frame: table, name: string }[]
local function surfaces(client, dock)
	local made, index = {}, {}
	for i, frame in ipairs(client.frames) do
		made[frame], index[frame] = true, i
	end
	local out = {}
	for i, frame in ipairs(client.frames) do
		if frame == dock then
			if visible(frame) then
				for _, child in ipairs(frame.children or {}) do
					if index[child] and visible(child) then
						out[#out + 1] = { frame = child, name = surfaceName(child, index[child]) }
					end
				end
			end
		elseif not made[frame.parent] and visible(frame) then
			out[#out + 1] = { frame = frame, name = surfaceName(frame, i) }
		end
	end
	return out
end

local function write(path, lines)
	local file = assert(io.open(path, "w"))
	file:write(table.concat(lines, "\n"), "\n")
	file:close()
end

describe("the layout harness", function()
	it("measures every stop of /pagle dev tour in " .. LANGUAGE, function()
		local loaded = loadAddon(
			"Pagle",
			foreverWith({
				GetLocale = function()
					return LOCALE
				end,
				PagleDB = { global = { language = LOCALE, dev = PSEUDO or nil, devPseudo = PSEUDO or nil } },
			}),
			{ also = ROSTER }
		)
		enterWorld(loaded, 3)
		local env, client = loaded.env, loaded.client
		local core = loaded.namespaces.Pagle
		-- The fake client runs no OnUpdate, so an animation would stay at its first frame (a book at alpha 0); with
		-- Animations off each one jumps to where it settles, which is what the tour's screenshot shows in-game.
		core.db.profile.announcements.motion = false
		env.SlashCmdList.PAGLE("dev on")
		client.advance(30)

		local findings, stops = {}, {}
		local shoot = env.Screenshot
		env.Screenshot = function()
			shoot()
			local run = core.tour.run
			local stop = run.stops[run.index].name
			local regions, found = {}, {}
			-- The fakes never place the minimap: it sits at the screen's top right, as the client's does.
			local memo = {
				[env.MinimapCluster] = { 1920 - 230, 0, 1920, 240 },
				[env.Minimap] = { 1920 - 218, 20, 1920 - 20, 218 },
			}
			for _, surface in ipairs(surfaces(client, core.dockFrame)) do
				measure(surface.frame, surface.name, memo, regions, found)
			end
			local file = ("%02d-%s.jsonl"):format(run.index, stop)
			local lines = { json.encode({ stop = stop, index = run.index, language = LANGUAGE }) }
			for _, record in ipairs(regions) do
				lines[#lines + 1] = json.encode(record)
			end
			write(OUT .. "/" .. file, lines)
			for _, finding in ipairs(found) do
				finding.stop, finding.index, finding.file = stop, run.index, file
				findings[#findings + 1] = json.encode(finding)
			end
			stops[#stops + 1] = stop
		end

		env.SlashCmdList.PAGLE(MODULE == "" and "dev tour" or "dev tour " .. MODULE)
		local count = #core.tourStops:List(core.Modules:Modules(), MODULE ~= "" and MODULE or nil)
		assert(count > 0, "the tour has no stops for '" .. MODULE .. "'")
		for _ = 1, count * 4 do
			client.advance(1)
		end
		assert.is_false(core.tour:IsRunning())
		assert.are.equal(count, #stops, "a screenshot at every stop")
		write(OUT .. "/findings.jsonl", findings)
		-- An error the addons raised on the way (real widths can reach code 6 units a byte never does) goes in
		-- errors.txt, which fails the report; the run itself ends clean.
		local errors = {}
		for i = #client.errors, 1, -1 do
			table.insert(errors, 1, tostring(client.errors[i]))
			client.errors[i] = nil
		end
		write(OUT .. "/errors.txt", errors)
	end)
end)
