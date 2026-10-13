-- The fake client's tooltip data hooks, for the diagnostics buffer's hovers (LOG-R80). spec/support/addon.lua adds
-- these stubs to every load.
--
--   loaded.client.hover("Oily Blackmouth School")  -- the mouse goes over a world object with that name
--   loaded.client.showTooltip(type, data)          -- a tooltip of any Enum.TooltipDataType is shown with `data`
--
-- How the hooks run follows Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua: an addon's
-- AddTooltipPostCall(type, func) runs func(tooltip, data) through securecallfunction after a tooltip of that type
-- (or of TooltipDataProcessor.AllTypes) is filled, in the order they were added.

---@class FakeClient
---@field hover fun(text: any) Shows the tooltip of a world object whose first line is `text`, as the mouse going over
--- it does: data.type is Object (4) and data.lines[1].leftText is `text`.
---@field showTooltip fun(type: integer, data: table) Runs the post-calls for a tooltip of `type` filled with `data`.

---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
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

	local tooltip = {} -- GameTooltip, as far as a post-call sees it here: never read

	function client.showTooltip(tooltipType, data)
		for _, key in ipairs({ "ALL", tooltipType }) do
			for _, func in ipairs(postCalls[key] or {}) do
				stubs.securecallfunction(func, tooltip, data)
			end
		end
	end

	function client.hover(text)
		local Object = stubs.Enum.TooltipDataType.Object
		client.showTooltip(Object, { type = Object, lines = { { leftText = text } } })
	end
end
