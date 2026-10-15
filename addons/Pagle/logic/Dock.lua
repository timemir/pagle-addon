---@class PagleNS
local ns = select(2, ...)

-- The tracker dock's stacking rules (CORE-R70–R72): which trackers dock, in what order, where each visible one sits
-- in the stack, and where the stack's anchor is. Pure logic, the frames passed in (CORE-R7); adapter/Dock.lua anchors
-- the frames on the client and FakePagle reads the same layout.

--- The space between two docked trackers, in pixels (core/README.md › Tunables).
ns.DOCK_SPACING = 8

--- A point as Frame:SetPoint takes it, with the frame it is relative to by global name. `dock.point` is one, always
--- relative to "UIParent" (core/README.md › Data).
---@class PagleDockPoint
---@field point string
---@field relativeTo string
---@field relativePoint string
---@field x number
---@field y number

--- One tracker a Module docked with `M:RegisterTracker{ id, order, frame }` (CORE-R70).
---@class PagleTracker
---@field id string
---@field order number
---@field frame table a frame: the dock reads its IsShown, GetWidth and GetHeight
---@field module string the docking Module's def.name, for ties

--- Where one visible tracker goes: its frame's TOPRIGHT at the anchor's TOPRIGHT, `y` below it.
---@class PagleDockPlacement
---@field tracker PagleTracker
---@field point string
---@field relativePoint string
---@field x number
---@field y number

--- The stack laid out: each visible tracker's placement, top to bottom, and the stack's size.
---@class PagleDockLayout
---@field placements PagleDockPlacement[]
---@field width number
---@field height number

--- The trackers docked so far.
---@class PagleDock
---@field private trackers PagleTracker[]
local Dock = {}
Dock.__index = Dock

---@return PagleDock
function ns.NewDock()
	return setmetatable({ trackers = {} }, Dock)
end

-- Why `tracker` can't dock, or nil if it can (CORE-R70).
---@param trackers PagleTracker[]
---@param tracker any
---@return string?
local function problem(trackers, tracker)
	if type(tracker) ~= "table" then
		return "takes a tracker table, got " .. type(tracker)
	end
	local id = tracker.id
	if type(id) ~= "string" then
		return "the id must be a string, got " .. tostring(id)
	end
	if type(tracker.order) ~= "number" then
		return ("%s's order must be a number, got %s"):format(id, type(tracker.order))
	end
	if tracker.frame == nil then
		return id .. " has no frame"
	end
	for _, docked in ipairs(trackers) do
		if docked.id == id then
			return id .. " is already docked"
		end
	end
	return nil
end

--- Docks a Module's tracker (CORE-R70), returning the docked record. Returns nil and why it can't, docking nothing:
--- a tracker that isn't a table, an id that isn't a string, an order that isn't a number, no frame, or an id already
--- docked by any Module.
---@param module string the Module's def.name
---@param tracker any `{ id, order, frame }`
---@return PagleTracker? docked
---@return string? problem
function Dock:Add(module, tracker)
	local why = problem(self.trackers, tracker)
	if why then
		return nil, "M:RegisterTracker: " .. why
	end
	local docked = { id = tracker.id, order = tracker.order, frame = tracker.frame, module = module }
	self.trackers[#self.trackers + 1] = docked
	return docked, nil
end

--- The docked trackers in stack order: by `order`, ties by Module name, then by id (CORE-R70). A fresh list.
---@return PagleTracker[]
function Dock:Trackers()
	local list = {}
	for i, tracker in ipairs(self.trackers) do
		list[i] = tracker
	end
	table.sort(list, function(a, b)
		if a.order == b.order and a.module == b.module then
			return a.id < b.id
		end
		return ns.ModuleSortsBefore(a.order, a.module, b.order, b.module)
	end)
	return list
end

--- The stack now (CORE-R70, CORE-R72): each shown tracker, in stack order, right-aligned to the anchor's top right
--- and below the ones above it with DOCK_SPACING between; a hidden one takes no room. With none shown it is empty,
--- 0 by 0. Each frame is read now (IsShown, GetWidth, GetHeight; the only calls logic makes on the frames it was
--- handed), so a resized frame moves the ones below it.
---@return PagleDockLayout
function Dock:Layout()
	local placements, width, offset = {}, 0, 0
	for _, tracker in ipairs(self:Trackers()) do
		local frame = tracker.frame
		if frame:IsShown() then
			local frameWidth, frameHeight = frame:GetWidth(), frame:GetHeight()
			if #placements > 0 then
				offset = offset + ns.DOCK_SPACING
			end
			placements[#placements + 1] =
				{ tracker = tracker, point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = 0, y = -offset }
			offset = offset + frameHeight
			width = math.max(width, frameWidth)
		end
	end
	return { placements = placements, width = width, height = offset }
end

--- Where the dock's anchor goes (CORE-R70, CORE-R71): the saved `dock.point`, or by default 10 px below the minimap
--- cluster, right-aligned to its right edge (core/README.md › Tunables). A saved point it can't read counts as none.
---@param saved any PagleDB.profile.dock.point
---@return PagleDockPoint
function ns.DockAnchor(saved)
	if
		type(saved) == "table"
		and type(saved.point) == "string"
		and saved.relativeTo == "UIParent"
		and type(saved.relativePoint) == "string"
		and type(saved.x) == "number"
		and type(saved.y) == "number"
	then
		return {
			point = saved.point,
			relativeTo = saved.relativeTo,
			relativePoint = saved.relativePoint,
			x = saved.x,
			y = saved.y,
		}
	end
	return { point = "TOPRIGHT", relativeTo = "MinimapCluster", relativePoint = "BOTTOMRIGHT", x = 0, y = -10 }
end
