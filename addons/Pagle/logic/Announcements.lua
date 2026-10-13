---@class PagleNS
local ns = select(2, ...)

-- Showing Announcements (announcements.md › The display queue, › Interruption budget, › Sounds; ADR 0007): pure
-- logic, fed the Announcements logic/Moments.lua merges, a clock and the player's budget setting (CORE-R7).
-- adapter/Announcements.lua draws what it shows in the Timber frames and plays the sounds it picks.

--- How long each form stays on screen, in seconds (ANN-R20; Tunables). A splash also goes when clicked.
ns.ANNOUNCEMENT_SECONDS = { toast = 6, banner = 4, splash = 8, nod = 3 }
--- Toasts that wait for the slot at most (ANN-R20; Tunables).
ns.TOASTS_WAITING = 2
--- Seconds after a restriction ends before Core shows what it held (ANN-R36; Tunables: Delay after combat).
ns.AFTER_COMBAT_SECONDS = 2
-- The longest budget window the player can set, in seconds (settings.md › Tunables: 1–15 min): interruptions older
-- than it never count again, so the lanes forget them.
local LONGEST_WINDOW = 15 * 60

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"

--- A sound set's files (ANN-R70, ANN-R72), as in-game paths: the toast sound's variants, played in turn, and the
--- banner sound. Every set shares the Legend sting.
---@class PagleSoundSet
---@field toast string[]
---@field banner string

--- The sound sets Core plays, by name (ANN-R72, ANN-R74). Driftwood is the free default and the only one in M2;
--- Gilded is rendered too and joins as a Curio Shop good in M4.
---@type table<string, PagleSoundSet>
ns.SOUND_SETS = {
	driftwood = {
		toast = {
			SOUNDS .. "driftwood\\toast_1.ogg",
			SOUNDS .. "driftwood\\toast_2.ogg",
			SOUNDS .. "driftwood\\toast_3.ogg",
		},
		banner = SOUNDS .. "driftwood\\banner.ogg",
	},
}
--- The Legend sting every set shares (ANN-R72).
ns.LEGEND_STING = SOUNDS .. "legend.ogg"

---@alias PagleAnnouncementForm "toast"|"nod"|"banner"|"splash"

--- One Announcement as it goes on screen.
---@class PagleDisplay
---@field announcement PagleAnnouncement
---@field form PagleAnnouncementForm how it shows: a toast.* headline stepped down by the budget shows as a "nod"
---@field overflow integer toasts not shown since the last toast appeared, read "+N more" (ANN-R20); 0 for none
---@field sound string? the in-game path of the sound it played when it appeared (ANN-R24), nil for none

--- What the lanes are fed. Every function is called when needed, never stored.
---@class PagleLanesOptions
---@field now fun(): number                     -- seconds, on the clock `after` runs on (GetTime())
---@field after fun(seconds: number, fn: fun()) -- runs fn once, `seconds` from now (C_Timer.After)
---@field budget fun(): { on: boolean, count: integer, window: integer } -- the player's setting (ANN-R32)
---@field cozy fun(): boolean                   -- Cozy mode is on (ANN-R40)
---@field serverTime fun(): number              -- server time, which a moment's expiresAt is in (ANN-R45)
---@field soundSet fun(): PagleSoundSet         -- the equipped sound set (ANN-R70)
---@field show fun(display: PagleDisplay)       -- puts it on screen
---@field hide fun(display: PagleDisplay)       -- takes it off screen
---@field play fun(path: string)                -- plays a sound file on the SFX channel (ANN-R73)
---@field empty? fun()                         -- the slot just freed with nothing waiting: cards may show (ANN-R21)

--- The three lanes (ANN-R20): the toast and big lanes share one on-screen slot; the Nod lane has its own line.
---@class PagleLanes
---@field package options PagleLanesOptions
---@field package slot PagleDisplay?            -- the toast, banner or splash on screen
---@field package nod PagleDisplay?             -- the Nod on screen
---@field package toasts PagleAnnouncement[]    -- toasts waiting, first in first out
---@field package big PagleAnnouncement[]       -- banners and splashes waiting: splashes first, then in order raised
---@field package overflow integer              -- toasts not shown since the last toast appeared
---@field package interruptions number[]        -- when each recent interruption appeared (ANN-R30), oldest first
---@field package toastSounds integer           -- toast sounds played, for the next variant (ANN-R72)
---@field package holding boolean               -- restricted, or within the wait after (ANN-R35, ANN-R36)
---@field package heldToasts PagleAnnouncement[] -- toasts held, in order
---@field package heldBig PagleAnnouncement[]   -- banners and splashes held: splashes first, then in order raised
---@field package releases integer              -- Hold and Release calls so far: a wait that sees a newer one ends
local Lanes = {}
Lanes.__index = Lanes

---@param options PagleLanesOptions
---@return PagleLanes
function ns.NewLanes(options)
	return setmetatable({
		options = options,
		toasts = {},
		big = {},
		overflow = 0,
		interruptions = {},
		toastSounds = 0,
		holding = false,
		heldToasts = {},
		heldBig = {},
		releases = 0,
	}, Lanes)
end

-- The lane each rung goes through (ANN-R11, ANN-R20).
local LANE = {
	nod = "nod",
	["toast.low"] = "toast",
	toast = "toast",
	["toast.high"] = "toast",
	banner = "big",
	splash = "big",
}

-- Puts a banner or splash in a big lane's list: after the splashes already there if it's a splash, otherwise last.
---@param big PagleAnnouncement[]
---@param announcement PagleAnnouncement
local function wait(big, announcement)
	local at = #big + 1
	if announcement.rung == "splash" then
		at = 1
		while big[at] and big[at].rung == "splash" do
			at = at + 1
		end
	end
	table.insert(big, at, announcement)
end

-- `announcement` without its expired moments (ANN-R45): itself if none expired, else the Announcement what is left
-- makes, its next-ranked moment the headline, or nil if every moment expired. An expired moment already reached the
-- Session summary when it was raised.
---@package
---@param announcement PagleAnnouncement
---@return PagleAnnouncement?
function Lanes:unexpired(announcement)
	local now = self.options.serverTime()
	local kept = {}
	for _, moment in ipairs(announcement.moments) do
		if not (moment.expiresAt and now >= moment.expiresAt) then
			kept[#kept + 1] = moment
		end
	end
	if #kept == #announcement.moments then
		return announcement
	end
	return ns.MakeAnnouncement(kept)
end

-- `announcement` as it may show now, or nil if nothing of it may: its expired moments dropped (ANN-R45), and nothing
-- but a splash in Cozy mode (ANN-R40, ANN-R41).
---@package
---@param announcement PagleAnnouncement
---@return PagleAnnouncement?
function Lanes:showable(announcement)
	local kept = self:unexpired(announcement)
	if kept and self.options.cozy() and kept.rung ~= "splash" then
		return nil
	end
	return kept
end

--- Takes an Announcement from the collector (ANN-R20): it shows now if its lane lets it, waits, or isn't shown.
--- Whatever isn't shown already reached the Session summary when its moments were raised (ANN-R25). A moment that
--- expired before it got here never shows (ANN-R45), nor anything but a splash in Cozy mode (ANN-R40). While the
--- lanes are held a toast, banner or splash is held with them, and a Nod never shows (ANN-R35, ANN-R36).
---@param announcement PagleAnnouncement
function Lanes:Push(announcement)
	local kept = self:showable(announcement)
	if not kept then
		return
	end
	local lane = LANE[kept.rung]
	if self.holding then
		if lane == "big" then
			wait(self.heldBig, kept)
		elseif lane == "toast" then
			self.heldToasts[#self.heldToasts + 1] = kept
		end
	elseif lane == "nod" then
		self:showNod(kept)
	elseif lane == "big" then
		wait(self.big, kept)
		self:next()
	elseif self.slot and #self.toasts >= ns.TOASTS_WAITING then
		self.overflow = self.overflow + 1
	else
		self.toasts[#self.toasts + 1] = kept
		self:next()
	end
end

--- Whether the lanes are holding (ANN-R35, ANN-R36): restricted, or in the wait after. Cards wait too (ANN-R55).
---@return boolean
function Lanes:IsHeld()
	return self.holding
end

--- A restriction started (ANN-R35): the toast, banner or splash on screen goes off it and is held, with what waits
--- for the slot, and every Announcement pushed from now; the Nod on screen goes and never shows again (ANN-R36).
--- Inside the wait after a restriction, the wait starts over at the next Release.
function Lanes:Hold()
	self.releases = self.releases + 1
	if self.holding then
		return
	end
	self.holding = true
	local slot, nod = self.slot, self.nod
	self.slot, self.nod = nil, nil
	if slot then
		self.options.hide(slot)
		if LANE[slot.announcement.rung] == "big" then
			wait(self.heldBig, slot.announcement)
		else
			self.heldToasts[#self.heldToasts + 1] = slot.announcement
		end
	end
	if nod then
		self.options.hide(nod)
	end
	for _, announcement in ipairs(self.big) do
		wait(self.heldBig, announcement)
	end
	for _, announcement in ipairs(self.toasts) do
		self.heldToasts[#self.heldToasts + 1] = announcement
	end
	self.big, self.toasts = {}, {}
end

--- The restriction ended (ANN-R36): AFTER_COMBAT_SECONDS later, unless a restriction started meanwhile, the lanes
--- show what they held, its expired moments dropped (ANN-R45): each splash and banner as itself, splashes first, then
--- one "While you were fighting" toast listing every held toast headline, then the cards (ANN-R21).
function Lanes:Release()
	self.releases = self.releases + 1
	local release = self.releases
	self.options.after(ns.AFTER_COMBAT_SECONDS, function()
		if self.releases == release and self.holding then
			self:showHeld()
		end
	end)
end

-- Ends the hold, putting what it held in the lanes (ANN-R36).
---@package
function Lanes:showHeld()
	self.holding = false
	self.big, self.heldBig = self.heldBig, {}
	local toasts = self.heldToasts
	self.heldToasts = {}
	local fighting = self:whileFighting(toasts)
	if fighting then
		table.insert(self.toasts, 1, fighting)
	end
	self:next()
	if self.options.empty and self:IsEmpty() then
		self.options.empty()
	end
end

-- The "While you were fighting" toast for the toasts held (ANN-R36), or nil when none is left once expired moments
-- are dropped (ANN-R45). It lists each one's headline, carries their Coins (ANN-R23), and is a plain `toast`, so it
-- plays the toast sound once, counts as one interruption and never steps down (ANN-R31).
---@package
---@param toasts PagleAnnouncement[]
---@return PagleAnnouncement?
function Lanes:whileFighting(toasts)
	local headlines, coins = {}, 0
	for _, held in ipairs(toasts) do
		local kept = self:unexpired(held)
		-- A toast whose toast moments expired is headlined by a Nod now, and held Nods don't show (ANN-R36).
		if kept and LANE[kept.rung] == "toast" then
			headlines[#headlines + 1] = kept.headline
			coins = coins + kept.coins
		end
	end
	if #headlines == 0 then
		return nil
	end
	---@type PagleRaisedMoment
	local headline = {
		rung = "toast",
		kind = "whileFighting",
		title = ns.L.ANNOUNCEMENT_WHILE_FIGHTING,
		module = "Pagle",
		moduleTitle = "Pagle",
		moduleOrder = 0,
		raised = 0,
	}
	return {
		headline = headline,
		rung = "toast",
		stamps = {},
		more = 0,
		coins = coins,
		moments = {},
		fighting = headlines,
	}
end

--- Takes a splash off screen when it is clicked (ANN-R20). Does nothing for one no longer on screen.
---@param display PagleDisplay
function Lanes:Dismiss(display)
	self:done(display)
end

-- Shows whatever is next for the free slot, if it is free and the lanes aren't held: the next banner or splash, else
-- the next toast. Each is checked as it is about to show (ANN-R40, ANN-R45): one with nothing left to show is skipped,
-- and one whose headline is now a Nod follows the Nod lane's rules, as a stepped-down toast.low does (ANN-R31).
---@package
function Lanes:next()
	while not self.slot and not self.holding do
		local waiting = table.remove(self.big, 1) or table.remove(self.toasts, 1)
		if not waiting then
			return
		end
		local kept = self:showable(waiting)
		if kept then
			local lane = LANE[kept.rung]
			if lane == "big" then
				self:showSlot(kept, kept.rung --[[@as "banner"|"splash"]])
			elseif lane == "nod" or (kept.rung == "toast.low" and self:spent()) then
				self:showNod(kept)
			else
				self:showSlot(kept, "toast")
			end
		end
	end
end

-- Puts an Announcement in the shared slot as `form`, until its time is up.
---@package
---@param announcement PagleAnnouncement
---@param form PagleAnnouncementForm
function Lanes:showSlot(announcement, form)
	local display = { announcement = announcement, form = form, overflow = 0 }
	if form == "toast" then
		display.overflow, self.overflow = self.overflow, 0
	end
	self.slot = display
	local now = self.options.now()
	while self.interruptions[1] and self.interruptions[1] <= now - LONGEST_WINDOW do
		table.remove(self.interruptions, 1)
	end
	self.interruptions[#self.interruptions + 1] = now
	display.sound = self:sound(announcement, form)
	self.options.show(display)
	if display.sound then
		self.options.play(display.sound)
	end
	self.options.after(ns.ANNOUNCEMENT_SECONDS[form], function()
		self:done(display)
	end)
end

-- The sound an Announcement shown as `form` plays as it appears (ANN-R70–R72): the equipped set's toast variant
-- next in turn, its banner sound, or the Legend sting. None for a Nod, for a headline with sound = false, or in Cozy
-- mode, where a splash shows silently (ANN-R41).
---@package
---@param announcement PagleAnnouncement
---@param form PagleAnnouncementForm
---@return string?
function Lanes:sound(announcement, form)
	if announcement.headline.sound == false or self.options.cozy() then
		return nil
	end
	local set = self.options.soundSet()
	if form == "toast" then
		self.toastSounds = self.toastSounds + 1
		return set.toast[(self.toastSounds - 1) % #set.toast + 1]
	elseif form == "banner" then
		return set.banner
	end
	return ns.LEGEND_STING
end

-- Takes `display` off screen if it's still there, and frees its place.
---@package
---@param display PagleDisplay
function Lanes:done(display)
	if self.slot ~= display then
		return
	end
	self.slot = nil
	self.options.hide(display)
	self:next()
	if self.options.empty and self:IsEmpty() then
		self.options.empty()
	end
end

--- Whether the toast and big lanes are empty (ANN-R21): nothing in the shared slot and nothing waiting for it. The
--- Nod lane doesn't count. Cards show only then.
---@return boolean
function Lanes:IsEmpty()
	return self.slot == nil and #self.toasts == 0 and #self.big == 0
end

-- Whether the Interruption budget is spent (ANN-R31, ANN-R32): it's on, and its count of interruptions already
-- appeared in its window. An interruption exactly a window ago has left it.
---@package
---@return boolean
function Lanes:spent()
	local budget = self.options.budget()
	if not budget.on then
		return false
	end
	local since = self.options.now() - budget.window
	local count = 0
	for _, at in ipairs(self.interruptions) do
		if at > since then
			count = count + 1
		end
	end
	return count >= budget.count
end

-- Shows a Nod for its 3 s, unless the slot or another Nod is showing (ANN-R20). A toast.low headline stepped down
-- by the budget comes here too (ANN-R31).
---@package
---@param announcement PagleAnnouncement
function Lanes:showNod(announcement)
	if self.slot or self.nod then
		return
	end
	local display = { announcement = announcement, form = "nod", overflow = 0 }
	self.nod = display
	self.options.show(display)
	self.options.after(ns.ANNOUNCEMENT_SECONDS.nod, function()
		-- A hold may have taken it off screen already (ANN-R35).
		if self.nod == display then
			self.nod = nil
			self.options.hide(display)
		end
	end)
end

--- Seconds the record ruler takes to fill (ANN-R22; Tunables).
ns.RULER_SECONDS = 1.5

--- A record ruler at one moment of its animation (ANN-R22): where the old record's mark and the fill sit along the
--- track (0 to 1), the number counted up so far, and the margin, which shows once it has landed.
---@class PagleRulerFrame
---@field mark number     -- the old record's mark
---@field fill number     -- how far the fill has come
---@field value string    -- the number so far, with its unit ("11.4 lb")
---@field passed boolean  -- the fill is past the old mark
---@field done boolean    -- it has landed: the margin and the "New record" stamp show
---@field margin string   -- "+x" with the unit ("+1.6 lb")
---@field label string    -- whose number it is ("weight")

-- A ruler's number with its unit, to one decimal. A unit other than "length" shows as given; "length" in the Angler's
-- unit through Pagle.FormatLength comes with Simulated Size (M4).
---@param value number
---@param unit string
---@return string
local function withUnit(value, unit)
	return ("%.1f %s"):format(value, unit)
end

--- The ruler `elapsed` seconds after it appeared (ANN-R22): the number eases up from 0 to the new record over
--- RULER_SECONDS, on a track a tenth longer than it, past the old record's mark.
---@param ruler { old: number, new: number, unit: string, label: string }
---@param elapsed number
---@return PagleRulerFrame
function ns.RulerAt(ruler, elapsed)
	local length = ruler.new * 1.1
	local progress = math.min(1, elapsed / ns.RULER_SECONDS)
	local value = ruler.new * (1 - (1 - progress) ^ 3)
	return {
		mark = ruler.old / length,
		fill = value / length,
		value = withUnit(value, ruler.unit),
		passed = value > ruler.old,
		done = progress >= 1,
		margin = "+" .. withUnit(ruler.new - ruler.old, ruler.unit),
		label = ruler.label,
	}
end
