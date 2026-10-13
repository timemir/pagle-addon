---@class PagleNS
local ns = select(2, ...)

-- Showing Announcements (announcements.md › The display queue, › Interruption budget, › Sounds; ADR 0007): pure
-- logic, fed the Announcements logic/Moments.lua merges, a clock and the player's budget setting (CORE-R7).
-- adapter/Announcements.lua draws what it shows in the Timber frames and plays the sounds it picks.

--- How long each form stays on screen, in seconds (ANN-R20; Tunables). A splash also goes when clicked.
ns.ANNOUNCEMENT_SECONDS = { toast = 6, banner = 4, splash = 8, nod = 3 }
--- Toasts that wait for the slot at most (ANN-R20; Tunables).
ns.TOASTS_WAITING = 2
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
---@field soundSet fun(): PagleSoundSet         -- the equipped sound set (ANN-R70)
---@field show fun(display: PagleDisplay)       -- puts it on screen
---@field hide fun(display: PagleDisplay)       -- takes it off screen
---@field play fun(path: string)                -- plays a sound file on the SFX channel (ANN-R73)

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

--- Takes an Announcement from the collector (ANN-R20): it shows now if its lane lets it, waits, or isn't shown.
--- Whatever isn't shown already reached the Session summary when its moments were raised (ANN-R25).
---@param announcement PagleAnnouncement
function Lanes:Push(announcement)
	local lane = LANE[announcement.rung]
	if lane == "nod" then
		self:showNod(announcement)
	elseif lane == "big" then
		self:wait(announcement)
	elseif self.slot and #self.toasts >= ns.TOASTS_WAITING then
		self.overflow = self.overflow + 1
	else
		self.toasts[#self.toasts + 1] = announcement
		self:next()
	end
end

-- Puts a banner or splash in the big lane: after the splashes already waiting if it's a splash, otherwise last.
---@package
---@param announcement PagleAnnouncement
function Lanes:wait(announcement)
	local at = #self.big + 1
	if announcement.rung == "splash" then
		at = 1
		while self.big[at] and self.big[at].rung == "splash" do
			at = at + 1
		end
	end
	table.insert(self.big, at, announcement)
	self:next()
end

--- Takes a splash off screen when it is clicked (ANN-R20). Does nothing for one no longer on screen.
---@param display PagleDisplay
function Lanes:Dismiss(display)
	self:done(display)
end

-- Shows whatever is next for the free slot, if it is free.
---@package
function Lanes:next()
	if self.slot then
		return
	end
	local big = table.remove(self.big, 1)
	if big then
		self:showSlot(big, big.rung)
		return
	end
	local toast = table.remove(self.toasts, 1)
	while toast and toast.rung == "toast.low" and self:spent() do
		self:showNod(toast)
		toast = table.remove(self.toasts, 1)
	end
	if toast then
		self:showSlot(toast, "toast")
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
-- next in turn, its banner sound, or the Legend sting. None for a Nod, or for a headline with sound = false.
---@package
---@param announcement PagleAnnouncement
---@param form PagleAnnouncementForm
---@return string?
function Lanes:sound(announcement, form)
	if announcement.headline.sound == false then
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
		self.nod = nil
		self.options.hide(display)
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
