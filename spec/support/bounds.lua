-- Where the fake client's words land across a page: each shown font string's inked span, left to right, measured from a
-- root frame's left edge by following its anchors as the client lays them out, at the fake's 6 pixels a character.
-- A spec asserts no words draw past a page's edges:
--
--   local bounds = dofile("spec/support/bounds.lua")
--   assert.are.same({}, bounds.overflows(page))   -- each overflow as "<text>: <left>..<right> of <width>"
--
-- A font string with a width keeps its words within it (the client wraps them, or cuts a single line short with an
-- ellipsis); one without is as wide as its words.

local bounds = {}

-- How far across a region each anchor point sits: 0 at its left edge, 1 at its right.
local ACROSS = {
	LEFT = 0,
	TOPLEFT = 0,
	BOTTOMLEFT = 0,
	CENTER = 0.5,
	TOP = 0.5,
	BOTTOM = 0.5,
	RIGHT = 1,
	TOPRIGHT = 1,
	BOTTOMRIGHT = 1,
}

-- An anchor as relativeTo, relativePoint, x: SetPoint(point, x, y) and SetPoint(point) are relative to the same point
-- of the region's parent.
local function resolve(region, anchor)
	if type(anchor[2]) == "number" or anchor[2] == nil then
		return region.parent, anchor[1], anchor[2] or 0
	end
	return anchor[2], anchor[3] or anchor[1], anchor[4] or 0
end

-- A font string's own width: the width it was given, or its words'.
local function textWidth(region)
	local words = #(region.text or "") * 6
	if region.width and region.width > 0 then
		return region.width, math.min(words, region.width)
	end
	return words, words
end

local across -- forward: a region's left edge and width from the root's left

-- Where an anchor of `region` puts that point across the root.
local function pointAt(region, anchor, root)
	local relativeTo, relativePoint, x = resolve(region, anchor)
	local left, width = across(relativeTo, root)
	if not left then
		return nil
	end
	return left + ACROSS[relativePoint] * width + x
end

-- `region`'s left edge from `root`'s left, and its width; nil when its anchors don't lead back to the root.
across = function(region, root)
	if region == root then
		return 0, root:GetWidth()
	end
	if region == nil then
		return nil
	end
	local width = region.kind == "FontString" and textWidth(region) or region.width or 0
	local anchors = region.points
	if #anchors == 0 then
		-- a scroll frame's child sits at its scroll frame's left
		local parent = region.parent
		if parent and parent.scrollChild == region then
			local left = across(parent, root)
			return left, width
		end
		return nil
	end
	local leftAnchor, rightAnchor
	for _, anchor in ipairs(anchors) do
		local at = ACROSS[anchor[1]]
		if at == 0 then
			leftAnchor = leftAnchor or anchor
		elseif at == 1 then
			rightAnchor = rightAnchor or anchor
		end
	end
	if leftAnchor and rightAnchor and region.kind ~= "FontString" then
		local left, right = pointAt(region, leftAnchor, root), pointAt(region, rightAnchor, root)
		if left and right then
			return left, right - left
		end
	end
	local anchor = anchors[1]
	local at = pointAt(region, anchor, root)
	if not at then
		return nil
	end
	return at - ACROSS[anchor[1]] * width, width
end

-- Whether `region` and every frame between it and `root` show.
local function shows(region, root)
	while region and region ~= root do
		if not region.shown then
			return false
		end
		region = region.parent
	end
	return region == root
end

-- Every widget under `widget`, depth first.
local function descendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children or {}) do
		list[#list + 1] = child
		descendants(child, list)
	end
	return list
end

--- Each shown font string under `root` whose words draw past its left or right edge (`slack` pixels allowed, 0.5 by
--- default), as "<text>: <left>..<right> of <width>"; an empty list when every word is within. `bounds.measured` is
--- then how many texts it could place, so a spec can tell "none over" from "none found".
---@param root table a frame of the fake client
---@param slack number?
---@return string[]
function bounds.overflows(root, slack)
	slack = slack or 0.5
	local width, out = root:GetWidth(), {}
	bounds.measured = 0
	for _, region in ipairs(descendants(root)) do
		if region.kind == "FontString" and region.text and region.text ~= "" and shows(region, root) then
			local left, frameWidth = across(region, root)
			if left then
				bounds.measured = bounds.measured + 1
				local _, inked = textWidth(region)
				local justify = region.justifyH or "LEFT"
				local start = justify == "RIGHT" and frameWidth - inked
					or justify == "CENTER" and (frameWidth - inked) / 2
					or 0
				local inkLeft, inkRight = left + start, left + start + inked
				if inkLeft < -slack or inkRight > width + slack then
					out[#out + 1] = ("%s: %g..%g of %g"):format(region.text, inkLeft, inkRight, width)
				end
			end
		end
	end
	return out
end

return bounds
