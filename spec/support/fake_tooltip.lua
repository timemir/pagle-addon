-- The fake client's tooltip data hooks, for the diagnostics buffer's hovers (LOG-R80) and the Pagle block on a
-- player's tooltip (VIEW-R20). spec/support/addon.lua adds these stubs to every load.
--
--   loaded.client.hover("Oily Blackmouth School")  -- the mouse goes over a world object with that name
--   loaded.client.hoverUnit(guid, "Ada")           -- the mouse goes over a unit with that GUID and name
--   loaded.client.showTooltip(type, data)          -- a tooltip of any Enum.TooltipDataType is shown with `data`
--
-- How the hooks run follows Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua: an addon's
-- AddTooltipPostCall(type, func) runs func(tooltip, data) through securecallfunction after a tooltip of that type
-- (or of TooltipDataProcessor.AllTypes) is filled, in the order they were added.

---@class FakeClient
---@field hover fun(text: any) Shows the tooltip of a world object whose first line is `text`, as the mouse going over
--- it does: data.type is Object (4) and data.lines[1].leftText is `text`.
---@field hoverUnit fun(guid: any, name: string) Shows GameTooltip for a unit, as the mouse going over it does: the
--- game's own line (its name) on a cleared GameTooltip, then the Unit (2) post-calls with data.guid `guid` and
--- data.lines[1].leftText `name`.
---@field showTooltip fun(type: integer, data: table) Runs the post-calls for a tooltip of `type` filled with `data`,
--- handing them GameTooltip as the tooltip.
---@field tooltipColors fun(): string[] The colour of each text tooltipLines reads, as "RRGGBB" (AddLine's and
--- AddDoubleLine's r, g, b; "" when given none).
---@field tooltipLines fun(): string[] The texts an addon put on GameTooltip since its last SetOwner or ClearLines,
--- each side of a double line on its own, while it is shown; none while it is hidden.

-- GameTooltip, the game's own tooltip frame, as far as an addon fills it for its own frame: SetOwner, ClearLines,
-- SetText, AddLine, AddDoubleLine, Show, Hide and IsOwned. It keeps what specs read back: `owner` (nil once hidden),
-- `anchor`, `text` (SetText's line) and every line, which `client.tooltipLines()` reads.
--
--   loaded.env.GameTooltip.text        -- the line it shows, while `shown`
--   loaded.client.tooltipLines()       -- every line it shows

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newWidget = dofile("spec/support/widgets.lua").newWidget

---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	local gameTooltip = newWidget("GameTooltip", stubs.UIParent)
	gameTooltip.shown = false
	local lines = {} -- since its last SetOwner or ClearLines, each side of a double line on its own
	local colors = {} -- each line's colour, as "RRGGBB" or ""
	-- r, g, b as "RRGGBB", "" for none.
	local function hex(r, g, b)
		if r == nil then
			return ""
		end
		return ("%02X%02X%02X"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
	end
	function gameTooltip:SetOwner(owner, anchor)
		self.owner, self.anchor, self.text = owner, anchor, nil
		lines, colors = {}, {}
	end
	function gameTooltip:ClearLines()
		self.text = nil
		lines, colors = {}, {}
	end
	function gameTooltip:SetText(text)
		self.text = text
		lines, colors = { text }, { "" }
	end
	function gameTooltip.AddLine(_, text, r, g, b)
		lines[#lines + 1] = text
		colors[#colors + 1] = hex(r, g, b)
	end
	function gameTooltip.AddDoubleLine(_, left, right, leftR, leftG, leftB, rightR, rightG, rightB)
		lines[#lines + 1] = left
		lines[#lines + 1] = right
		colors[#colors + 1] = hex(leftR, leftG, leftB)
		colors[#colors + 1] = hex(rightR, rightG, rightB)
	end
	function gameTooltip:Hide()
		self.shown, self.owner = false, nil
	end
	function gameTooltip:IsOwned(frame)
		return self.owner == frame
	end
	stubs.GameTooltip = gameTooltip

	-- The forever dump's LuaEnum.lua at BIR_COMMIT (scripts/tools.env), as far as specs use it.
	stubs.Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4 }

	local postCalls = {} -- by tooltip type: { func, … }
	stubs.TooltipDataProcessor = {
		AllTypes = "ALL",
		AddTooltipPostCall = function(tooltipType, func)
			postCalls[tooltipType] = postCalls[tooltipType] or {}
			table.insert(postCalls[tooltipType], func)
		end,
	}

	function client.tooltipLines()
		local copy = {}
		for i, line in ipairs(gameTooltip.shown and lines or {}) do
			copy[i] = tostring(line)
		end
		return copy
	end

	function client.tooltipColors()
		local copy = {}
		for i, color in ipairs(gameTooltip.shown and colors or {}) do
			copy[i] = color
		end
		return copy
	end

	function client.showTooltip(tooltipType, data)
		for _, key in ipairs({ "ALL", tooltipType }) do
			for _, func in ipairs(postCalls[key] or {}) do
				stubs.securecallfunction(func, gameTooltip, data)
			end
		end
	end

	function client.hoverUnit(guid, name)
		local Unit = stubs.Enum.TooltipDataType.Unit
		gameTooltip:SetOwner(stubs.UIParent, "ANCHOR_NONE")
		gameTooltip:AddLine(name)
		gameTooltip:Show()
		client.showTooltip(Unit, { type = Unit, guid = guid, lines = { { leftText = name } } })
	end

	function client.hover(text)
		local Object = stubs.Enum.TooltipDataType.Object
		client.showTooltip(Object, { type = Object, lines = { { leftText = text } } })
	end
end
