if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Nudges (QOL-R75–R78): one line of text QoL draws in its own frame, below the game's error text. A Nudge is
-- silent and isn't an Announcement: it goes through no Core call, so Cozy mode, the Interruption budget and the
-- Session summary never see it, and it shows in combat too (QOL-R76). QoL has two (QOL-R78): the out-of-lures
-- Nudge (adapter/Lures.lua) and the swap-back Nudge (Track Q step 2).

local frame ---@type Frame? made at the first Nudge; a plain frame, so combat never stops it (QOL-R76)
local line ---@type FontString
local elapsed = 0 -- seconds since the Nudge showing now showed

-- Holds the Nudge for NUDGE_SHOW, fades it over NUDGE_FADE, then hides it and stops (QOL-R75).
---@param self Frame
---@param seconds number
local function onUpdate(self, seconds)
	elapsed = elapsed + seconds
	local alpha = ns.NudgeAlpha(elapsed)
	if alpha then
		self:SetAlpha(alpha)
	else
		self:Hide()
		self:SetScript("OnUpdate", nil)
	end
end

--- Shows a Nudge, replacing the one showing (QOL-R75).
---@param text string
function ns.ShowNudge(text)
	if not frame then
		frame = CreateFrame("Frame", nil, UIParent)
		-- At the top centre, NUDGE_GAP px below the game's error text. The line sizes itself to its text.
		frame:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, -ns.NUDGE_GAP)
		frame:SetSize(1, 1)
		line = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		line:SetPoint("TOP")
		line:SetTextColor(YELLOW_FONT_COLOR:GetRGB())
	end
	line:SetText(text)
	elapsed = 0
	frame:SetAlpha(1)
	frame:Show()
	frame:SetScript("OnUpdate", onUpdate)
end
