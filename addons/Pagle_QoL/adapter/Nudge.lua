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

--- The Nudge's frame: the strip, three-sliced on it, and what it says now as plain text (`message`).
---@class PagleQoLNudge: PagleThreeSlice
---@field message string

local frame ---@type PagleQoLNudge? made at the first Nudge; a plain frame, so combat never stops it (QOL-R76)
-- The regions the strip's pieces have used, by kind, reused in turn: words in the hand, words in red, key caps.
local pools = { words = {}, em = {}, key = {} } ---@type table<string, table[]>
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

-- Lays the pieces on the strip and sizes it to them (ns.NudgeLayout).
---@param nudge PagleQoLNudge
---@param parts PagleQoLNudgePart[]
local function draw(nudge, parts)
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
	for i, part in ipairs(parts) do
		local kind, region = kindOf(part), drawn[i]
		if kind == "key" then
			ns.SetKeyCap(region, part.key, pieces[i].width, 24)
		end
		-- The kit's baselines: a key cap sits 2 px up, the red words 1 px down.
		region:ClearAllPoints()
		region:SetPoint("LEFT", nudge, "LEFT", pieces[i].x, kind == "key" and 2 or kind == "em" and -1 or 0)
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
	draw(frame, parts)
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
