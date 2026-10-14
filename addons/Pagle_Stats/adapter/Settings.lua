if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' watches on the client (STA-R60–R63): logic/Watches.lua over PagleStatsDB.profile, read at each call, the
-- game's error text and the chat.

ns.WireWatches({
	Profile = function()
		return ns.db.profile
	end,
	UIError = function(text, r, g, b)
		UIErrorsFrame:AddMessage(text, r, g, b)
	end,
	Print = function(line)
		print(line)
	end,
})
