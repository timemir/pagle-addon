---@class PagleNS
local ns = select(2, ...)

-- Showing Announcements (announcements.md › The display queue, › Interruption budget, › Sounds; ADR 0007): pure
-- logic, fed the Announcements logic/Moments.lua merges, a clock and the player's budget setting (CORE-R7).
-- adapter/Announcements.lua draws what it shows in the Timber frames and plays the sounds it picks.

--- How long each form stays on screen, in seconds (ANN-R20; Tunables). A splash also goes when clicked.
ns.ANNOUNCEMENT_SECONDS = { toast = 6, banner = 4, splash = 8, nod = 3 }
--- Toasts that wait for their turn at most (ANN-R20; Tunables).
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

--- The sound sets Core plays, by name (ANN-R72, ANN-R74): Driftwood, the free default, and Gilded, a Curio Shop
--- good (logic/CoreGoods.lua's sound set slot).
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
	gilded = {
		toast = { SOUNDS .. "gilded\\toast_1.ogg" },
		banner = SOUNDS .. "gilded\\banner.ogg",
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
---@field empty? fun()                         -- both lanes just freed with nothing waiting: cards may show (ANN-R21)

--- The three lanes (ANN-R20), each with its own place on screen: a banner or splash in the centre, a toast above the
--- action bar, a Nod under it. A splash, full-screen, holds the toast and Nod lanes back.
---@class PagleLanes
---@field package options PagleLanesOptions
---@field package centre PagleDisplay?          -- the banner or splash on screen
---@field package toast PagleDisplay?           -- the toast on screen
---@field package nod PagleDisplay?             -- the Nod on screen
---@field package bigSoundAt number?            -- when a banner or splash last played its sound (ANN-R24)
---@field package toasts PagleAnnouncement[]    -- toasts waiting, first in first out
---@field package big PagleAnnouncement[]       -- banners and splashes waiting: splashes first, then in order raised
---@field package overflow integer              -- toasts not shown since the last toast appeared
---@field package interruptions number[]        -- when each recent interruption appeared (ANN-R30), oldest first
---@field package toastSounds table<PagleSoundSet, integer> -- toast sounds played per set, for its next variant (ANN-R72)
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
		toastSounds = {},
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
	elseif not self:toastMayStart() and #self.toasts >= ns.TOASTS_WAITING then
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

--- A restriction started (ANN-R35): the banner, splash and toast on screen go off it and are held, with what waits in
--- the lanes, and every Announcement pushed from now; the Nod on screen goes and never shows again (ANN-R36).
--- Inside the wait after a restriction, the wait starts over at the next Release.
function Lanes:Hold()
	self.releases = self.releases + 1
	if self.holding then
		return
	end
	self.holding = true
	local centre, toast, nod = self.centre, self.toast, self.nod
	self.centre, self.toast, self.nod = nil, nil, nil
	if centre then
		self.options.hide(centre)
		wait(self.heldBig, centre.announcement)
	end
	if toast then
		self.options.hide(toast)
		self.heldToasts[#self.heldToasts + 1] = toast.announcement
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
--- show what they held, its expired moments dropped (ANN-R45): each splash and banner as itself, splashes first, and
--- with the first banner one "While you were fighting" toast listing every held toast headline, so a held Cast's two
--- Announcements show together; then the cards (ANN-R21).
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

-- Whether a splash holds the toast lane back (ANN-R20): one on screen, or one at the front of the big lane, waiting.
---@package
---@return boolean
function Lanes:splashHolds()
	local centre, front = self.centre, self.big[1]
	return (centre ~= nil and centre.form == "splash") or (front ~= nil and front.rung == "splash")
end

-- Whether the next toast may start (ANN-R20): no toast is on screen and no splash holds the lane back.
---@package
---@return boolean
function Lanes:toastMayStart()
	return self.toast == nil and not self:splashHolds()
end

-- Whether the next banner or splash, `front`, may start (ANN-R20): nothing is in the centre, and for a splash, no
-- toast is on screen.
---@package
---@param front PagleAnnouncement
---@return boolean
function Lanes:bigMayStart(front)
	return self.centre == nil and not (front.rung == "splash" and self.toast ~= nil)
end

-- Shows whatever is next in each lane whose place is free, while the lanes aren't held: the next banner or splash
-- first, so a Cast's two Announcements appear in that order, then the next toast. Each is checked as it is about to
-- show (ANN-R40, ANN-R45): one with nothing left to show is skipped, and one whose headline is now a Nod follows the
-- Nod lane's rules, as a stepped-down toast.low does (ANN-R31).
---@package
function Lanes:next()
	while not self.holding do
		local waiting
		if self.big[1] and self:bigMayStart(self.big[1]) then
			waiting = table.remove(self.big, 1)
		elseif self:toastMayStart() then
			waiting = table.remove(self.toasts, 1)
		end
		if not waiting then
			return
		end
		local kept = self:showable(waiting)
		if kept then
			self:place(kept)
		end
	end
end

-- Shows `announcement`, just taken from its lane, by the rung it has now: in the centre, as a toast, or as a Nod, the
-- last for a toast.low the budget steps down (ANN-R31). One whose expired moments left it for another lane's rung (a
-- hand-made Announcement mixing both sides) waits at the front of that lane if its place is taken.
---@package
---@param announcement PagleAnnouncement
function Lanes:place(announcement)
	local lane = LANE[announcement.rung]
	if lane == "big" then
		if self:bigMayStart(announcement) then
			self:showOn(announcement, announcement.rung --[[@as "banner"|"splash"]])
		else
			wait(self.big, announcement)
		end
	elseif lane == "nod" or (announcement.rung == "toast.low" and self:spent()) then
		self:showNod(announcement)
	elseif self:toastMayStart() then
		self:showOn(announcement, "toast")
	else
		table.insert(self.toasts, 1, announcement)
	end
end

-- Puts an Announcement on screen as `form`, in the centre or as the toast, until its time is up.
---@package
---@param announcement PagleAnnouncement
---@param form PagleAnnouncementForm
function Lanes:showOn(announcement, form)
	local display = { announcement = announcement, form = form, overflow = 0 }
	if form == "toast" then
		display.overflow, self.overflow = self.overflow, 0
		self.toast = display
	else
		self.centre = display
	end
	local now = self.options.now()
	while self.interruptions[1] and self.interruptions[1] <= now - LONGEST_WINDOW do
		table.remove(self.interruptions, 1)
	end
	self.interruptions[#self.interruptions + 1] = now
	display.sound = self:sound(announcement, form, now)
	self.options.show(display)
	if display.sound then
		self.options.play(display.sound)
	end
	self.options.after(ns.ANNOUNCEMENT_SECONDS[form], function()
		self:done(display)
	end)
end

-- The sound an Announcement shown as `form` at `now` plays as it appears (ANN-R70–R72): the equipped set's toast
-- variant next in turn, its banner sound, or the Legend sting. None for a Nod, for a headline with sound = false, in
-- Cozy mode, where a splash shows silently (ANN-R41), or for a toast appearing in the same frame as a banner or splash
-- that played its sound, so only the higher rung's plays and the next toast gets this one's variant (ANN-R24). Each
-- set keeps its own turn, so a set equipped again goes on where it left off.
---@package
---@param announcement PagleAnnouncement
---@param form PagleAnnouncementForm
---@param now number
---@return string?
function Lanes:sound(announcement, form, now)
	if announcement.headline.sound == false or self.options.cozy() then
		return nil
	end
	local set = self.options.soundSet()
	if form == "toast" then
		if self.bigSoundAt == now then
			return nil
		end
		local played = self.toastSounds[set] or 0
		self.toastSounds[set] = played + 1
		return set.toast[played % #set.toast + 1]
	end
	self.bigSoundAt = now
	return form == "banner" and set.banner or ns.LEGEND_STING
end

-- Takes `display` off screen if it's still there, and frees its place.
---@package
---@param display PagleDisplay
function Lanes:done(display)
	if self.centre == display then
		self.centre = nil
	elseif self.toast == display then
		self.toast = nil
	else
		return
	end
	self.options.hide(display)
	self:next()
	if self.options.empty and self:IsEmpty() then
		self.options.empty()
	end
end

--- Whether the toast and big lanes are empty (ANN-R21): no banner, splash or toast on screen and none waiting. The
--- Nod lane doesn't count. Cards show only then.
---@return boolean
function Lanes:IsEmpty()
	return self.centre == nil and self.toast == nil and #self.toasts == 0 and #self.big == 0
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

-- Shows a Nod for its 3 s, unless a toast, a splash or another Nod is showing (ANN-R20); a banner doesn't stop it. A
-- toast.low headline stepped down by the budget comes here too (ANN-R31).
---@package
---@param announcement PagleAnnouncement
function Lanes:showNod(announcement)
	if self.toast or self.nod or (self.centre and self.centre.form == "splash") then
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
--- Seconds after the margin lands until the "New record" stamp does (ANN-R22): a beat, so the two land one by one.
ns.RULER_STAMP_DELAY = 0.4

--- A record ruler at one moment of its animation (ANN-R22): where the old record's mark and the fill sit along the
--- track (0 to 1), the old record's number by its mark, the number counted up so far, the margin, which shows once it
--- has landed, and the "New record" stamp a beat after.
---@class PagleRulerFrame
---@field mark number     -- the old record's mark
---@field old string      -- the old record, with its unit ("10.0 lb")
---@field fill number     -- how far the fill has come
---@field value string    -- the number so far, with its unit ("11.4 lb")
---@field passed boolean  -- the fill is past the old mark
---@field done boolean    -- it has landed: the margin shows
---@field stamped boolean -- RULER_STAMP_DELAY after it landed: the "New record" stamp shows, and the animation ends
---@field margin string   -- "+x" with the unit ("+1.6 lb")
---@field label string    -- whose number it is ("weight")

-- A ruler's number with its unit, to one decimal: millimetres in the Angler's length unit for "length" (LOG-R69),
-- any other unit as given.
---@param value number
---@param unit string
---@param lengthUnit PagleLengthUnit?
---@return string
local function withUnit(value, unit, lengthUnit)
	if unit == "length" then
		return ns.FormatLength(value, lengthUnit --[[@as PagleLengthUnit]])
	end
	return ("%.1f %s"):format(value, unit)
end

--- The ruler `elapsed` seconds after it appeared (ANN-R22): the number eases up from 0 to the new record over
--- RULER_SECONDS, on a track a tenth longer than it, past the old record's mark; then the margin lands, and the
--- stamp RULER_STAMP_DELAY later. A Simulated Size (`unit` "length", in millimetres) reads in `lengthUnit`, and a
--- margin that rounds to zero there as "+<0.1 cm".
---@param ruler { old: number, new: number, unit: string, label: string }
---@param elapsed number
---@param lengthUnit PagleLengthUnit? the Angler's length unit (LOG-R69), which a "length" ruler needs
---@return PagleRulerFrame
function ns.RulerAt(ruler, elapsed, lengthUnit)
	local length = ruler.new * 1.1
	local progress = math.min(1, elapsed / ns.RULER_SECONDS)
	local value = ruler.new * (1 - (1 - progress) ^ 3)
	local unit, margin = ruler.unit, ruler.new - ruler.old
	return {
		mark = ruler.old / length,
		old = withUnit(ruler.old, unit, lengthUnit),
		fill = value / length,
		value = withUnit(value, unit, lengthUnit),
		passed = value > ruler.old,
		done = progress >= 1,
		stamped = elapsed >= ns.RULER_SECONDS + ns.RULER_STAMP_DELAY,
		margin = unit == "length" and ns.FormatLengthMargin(margin, lengthUnit --[[@as PagleLengthUnit]])
			or "+" .. withUnit(margin, unit),
		label = ruler.label,
	}
end
