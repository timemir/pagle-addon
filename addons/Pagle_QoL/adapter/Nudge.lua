if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Nudges (QOL-R75–R78): one line QoL draws on its own strip of paper, below the game's error text. A Nudge is silent
-- and isn't an Announcement: it goes through no Core call but a read of the Animations setting, so Cozy mode, the
-- Interruption budget and the Session summary never see it, and it shows in combat too (QOL-R76). QoL has two
-- (QOL-R78): the out-of-lures Nudge (adapter/Lures.lua) and the swap-back Nudge (adapter/Gear.lua). The strip is the
-- field art kit's (adapter/FieldArt.lua): the words in the Angler's hand, a key on a brass cap, a binding's name in
-- printed red.

--- A Nudge's strip: the paper, three-sliced on it, and the regions its pieces have used, by kind, reused in turn:
--- words in the hand, words in red, key caps.
---@class PagleQoLNudgeStrip: PagleThreeSlice
---@field pools table<string, table[]>

--- The Nudge's frame: a strip, and what it says now as plain text (`message`).
---@class PagleQoLNudge: PagleQoLNudgeStrip
---@field message string

local frame ---@type PagleQoLNudge? made at the first Nudge; a plain frame, so combat never stops it (QOL-R76)
local elapsed = 0 -- seconds since the Nudge showing now showed

-- Holds the Nudge for NUDGE_SHOW, fades it over NUDGE_FADE, then hides it and stops (QOL-R75). With Core's Animations
-- setting off (announcements.md › Contracts) it goes at once when its hold is up, without the fade.
---@param self Frame
---@param seconds number
local function onUpdate(self, seconds)
	elapsed = elapsed + seconds
	local alpha = ns.NudgeAlpha(elapsed)
	if alpha and (elapsed <= ns.NUDGE_SHOW or Pagle.IsAnimationsOn()) then
		self:SetAlpha(alpha)
	else
		self:Hide()
		self:SetScript("OnUpdate", nil)
	end
end

-- The pool a piece draws from.
---@param part PagleQoLNudgePart
---@return string
local function kindOf(part)
	if type(part) == "string" then
		return "words"
	end
	return part.key and "key" or "em"
end

--- Draws a Nudge's line on `nudge`, a strip: lays the pieces on its paper and sizes it to them (ns.NudgeLayout). The
--- Nudge itself and the Field guide's sample of it (ONB-R33) are drawn with it.
---@param nudge Frame
---@param parts PagleQoLNudgePart[]
function ns.DrawNudge(nudge, parts)
	local strip = nudge --[[@as PagleQoLNudgeStrip]]
	strip.pools = strip.pools or { words = {}, em = {}, key = {} }
	local pools = strip.pools
	local used = { words = 0, em = 0, key = 0 }
	for _, pool in pairs(pools) do
		for _, region in ipairs(pool) do
			region:Hide()
		end
	end
	local drawn = {} -- each piece's region
	for i, part in ipairs(parts) do
		local kind = kindOf(part)
		used[kind] = used[kind] + 1
		local pool = pools[kind]
		if not pool[used[kind]] then
			if kind == "key" then
				pool[used[kind]] = ns.NewKeyCap(nudge, "NudgeKey")
			else
				pool[used[kind]] = ns.ArtText(nudge, kind == "words" and "Nudge" or "NudgeEm")
			end
		end
		local region = pool[used[kind]]
		local text = kind == "key" and region.Text or region
		text:SetText(type(part) == "string" and part or part.key or part.em)
		drawn[i] = region
	end
	local pieces, width = ns.NudgeLayout(parts, function(index)
		local region = drawn[index]
		return (region.Text or region):GetStringWidth()
	end)
	ns.SetThreeSlice(nudge, "Field", "nudge", width, 26, "BACKGROUND")
	local lift = 0 -- the piece before's: how far its middle sits above the strip's
	for i, part in ipairs(parts) do
		local kind, region = kindOf(part), drawn[i]
		if kind == "key" then
			ns.SetKeyCap(region, part.key, pieces[i].width, 24)
		end
		-- The kit's baselines: a key cap sits 2 px up, the red words 1 px down.
		local y = kind == "key" and 2 or kind == "em" and -1 or 0
		region:ClearAllPoints()
		-- The first piece at its place on the paper; each after it 8 px past the right end of the one before as it
		-- draws, not as it measured: a strip drawn smaller (the Field guide's sample) sets its type at other pixel
		-- sizes, whose widths don't shrink in step, and pieces placed by the measured widths ran into each other.
		if i == 1 then
			region:SetPoint("LEFT", nudge, "LEFT", pieces[i].x, y)
		else
			local before = pieces[i - 1]
			region:SetPoint("LEFT", drawn[i - 1], "RIGHT", pieces[i].x - before.x - before.width, y - lift)
		end
		lift = y
		region:Show()
	end
end

--- Shows a Nudge, replacing the one showing (QOL-R75): `line` is its words, or its pieces (ns.NudgeParts).
---@param line string|PagleQoLNudgePart[]
function ns.ShowNudge(line)
	local parts = type(line) == "string" and { line } or line --[[@as PagleQoLNudgePart[] ]]
	if not frame then
		frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleQoLNudge]]
		-- At the top centre, NUDGE_GAP px below the game's error text. The strip sizes itself to its line.
		frame:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, -ns.NUDGE_GAP)
	end
	frame.message = ns.NudgeText(parts)
	ns.DrawNudge(frame, parts)
	elapsed = 0
	frame:SetAlpha(1)
	frame:Show()
	frame:SetScript("OnUpdate", onUpdate)
end

--- Takes the Nudge showing off the screen at once: the tour's stop, done with its sample (CORE-R68).
function ns.HideNudge()
	if frame then
		frame:Hide()
		frame:SetScript("OnUpdate", nil)
	end
end
