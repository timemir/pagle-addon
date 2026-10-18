---@class PagleNS
local ns = select(2, ...)

-- Showing Announcements (announcements.md › The display queue, › Interruption budget, › Sounds; ADR 0007): pure
-- logic, fed the Announcements logic/Moments.lua merges, a clock and the player's budget setting (CORE-R7).
-- adapter/Announcements.lua draws what it shows in the announcements art and plays the sounds it picks.

--- Seconds an entry stays once it has settled (announcements.md › The display queue; Tunables): a toast by its page
--- (logic/ToastStyles.lua's ns.ToastPage), a Nod, and a banner. A splash stays SPLASH_SECONDS, or until clicked.
ns.HOLD_SECONDS =
	{ low = 4, ["low-ruled"] = 5, toast = 6, ["toast-ruled"] = 6, high = 8, digest = 8, nod = 3, banner = 4.5 }
--- Seconds after it appears that each form's entry motion settles (announcements.md › Motion): its hold starts then.
ns.SETTLE_SECONDS = { toast = 2.7, nod = 0.3, banner = 1.4 }
--- Seconds a splash stays unless clicked (ANN-R20).
ns.SPLASH_SECONDS = 8
--- Seconds each form takes to leave (announcements.md › Motion): a toast or Nod fades out drifting up, a banner fades
--- and shrinks; the next banner waits for that.
ns.LEAVE_SECONDS = { toast = 0.4, nod = 0.3, banner = 0.5 }
--- The column toasts and Nods share (ANN-R20): at most this many entries, this many of them toasts, and this many units
--- tall, so it never reaches a banner; entries stand COLUMN_GAP apart.
ns.COLUMN_ENTRIES, ns.COLUMN_TOASTS, ns.COLUMN_HEIGHT, ns.COLUMN_GAP = 4, 3, 300, 12
--- A Nod's height in the column, and how far toast.high's bookmark hangs below its page.
ns.NOD_HEIGHT, ns.RIBBON_HEIGHT = 40, 22
--- Held toasts that fold into one "While you were fighting" toast (ANN-R36): fewer show as themselves.
ns.FIGHTING_DIGEST = 3
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
---@field height number? its height in the column, gap included: a toast's or a Nod's
---@field sound string? the in-game path of the sound it played when it appeared (ANN-R24), nil for none
---@field package endsAt number? when its time is up, while it isn't paused
---@field package left number? seconds it had left when it was paused
---@field package paused boolean? the pointer is on it: its clock stands still
---@field package token integer? its timer's turn: a timer from an earlier turn does nothing

--- What the lanes are fed. Every function is called when needed, never stored.
---@class PagleLanesOptions
---@field now fun(): number                     -- seconds, on the clock `after` runs on (GetTime())
---@field after fun(seconds: number, fn: fun()) -- runs fn once, `seconds` from now (C_Timer.After)
---@field budget fun(): { on: boolean, count: integer, window: integer } -- the player's setting (ANN-R32)
---@field cozy fun(): boolean                   -- Cozy mode is on (ANN-R40)
---@field serverTime fun(): number              -- server time, which a moment's expiresAt is in (ANN-R45)
---@field soundSet fun(): PagleSoundSet         -- the equipped sound set (ANN-R70)
---@field show fun(display: PagleDisplay)       -- puts it on screen; a toast or Nod at the foot of the column
---@field hide fun(display: PagleDisplay, atOnce: boolean?) -- takes it off screen: as its form leaves, or at once
--                                                 (the combat hold, ANN-R35)
---@field play fun(path: string)                -- plays a sound file on the SFX channel (ANN-R73)
---@field empty? fun()                         -- the column's toasts and the centre just freed with nothing waiting:
--                                                 cards may show (ANN-R21)

--- Where Announcements show (ANN-R20): a banner or splash in the centre, one at a time; toasts and Nods in one column
--- at the bottom centre, the newest at its foot. A splash, full-screen, holds the column back.
---@class PagleLanes
---@field package options PagleLanesOptions
---@field package centre PagleDisplay?          -- the banner or splash on screen
---@field package column PagleDisplay[]         -- the toasts and Nods on screen, the newest first
---@field package waiting PagleAnnouncement[]   -- toasts and Nods waiting for the column, first in first out
---@field package big PagleAnnouncement[]       -- banners and splashes waiting: splashes first, then in order raised
---@field package bigSoundAt number?            -- when a banner or splash last played its sound (ANN-R24)
---@field package bannerLeaving boolean?       -- the last banner is leaving: the centre is still taken
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
		column = {},
		waiting = {},
		big = {},
		interruptions = {},
		toastSounds = {},
		holding = false,
		heldToasts = {},
		heldBig = {},
		releases = 0,
	}, Lanes)
end

-- The lane each rung goes through (ANN-R11, ANN-R20): the column for toasts and Nods, the centre for the rest.
local LANE = {
	nod = "nod",
	["toast.low"] = "toast",
	toast = "toast",
	["toast.high"] = "toast",
	banner = "big",
	splash = "big",
}

-- Puts a banner or splash in the centre's queue: after the splashes already there if it's a splash, otherwise last.
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

--- Takes an Announcement from the collector (ANN-R20): it shows now if its place lets it, or waits its turn. Whatever
--- never shows already reached the Session summary when its moments were raised (ANN-R25). A moment that expired
--- before it got here never shows (ANN-R45), nor anything but a splash in Cozy mode (ANN-R40). While the lanes are
--- held a toast, banner or splash is held with them, and a Nod never shows (ANN-R35, ANN-R36).
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
	elseif lane == "big" then
		wait(self.big, kept)
		self:next()
	else
		self.waiting[#self.waiting + 1] = kept
		self:next()
	end
end

--- Whether the lanes are holding (ANN-R35, ANN-R36): restricted, or in the wait after. Cards wait too (ANN-R55).
---@return boolean
function Lanes:IsHeld()
	return self.holding
end

--- A restriction started (ANN-R35): the banner or splash and the toasts on screen go off it at once and are held,
--- with the toasts, banners and splashes that wait, and every Announcement pushed from now; the Nods on screen or
--- waiting go and never show (ANN-R36). Inside the wait after a restriction, the wait starts over at the next Release.
function Lanes:Hold()
	self.releases = self.releases + 1
	if self.holding then
		return
	end
	self.holding = true
	local centre, column = self.centre, self.column
	self.centre, self.column = nil, {}
	if centre then
		self.options.hide(centre, true)
		wait(self.heldBig, centre.announcement)
	end
	-- Oldest first, so they show again in the order they came.
	for i = #column, 1, -1 do
		local display = column[i]
		display.token = (display.token or 0) + 1
		self.options.hide(display, true)
		if display.form == "toast" then
			self.heldToasts[#self.heldToasts + 1] = display.announcement
		end
	end
	for _, announcement in ipairs(self.waiting) do
		if LANE[announcement.rung] == "toast" then
			self.heldToasts[#self.heldToasts + 1] = announcement
		end
	end
	for _, announcement in ipairs(self.big) do
		wait(self.heldBig, announcement)
	end
	self.big, self.waiting = {}, {}
end

--- The restriction ended (ANN-R36): AFTER_COMBAT_SECONDS later, unless a restriction started meanwhile, the lanes
--- show what they held, its expired moments dropped (ANN-R45): each splash and banner as itself, splashes first, and
--- the held toasts: FIGHTING_DIGEST or more fold into one "While you were fighting" toast, fewer show as themselves,
--- in order; then the cards (ANN-R21).
function Lanes:Release()
	self.releases = self.releases + 1
	local release = self.releases
	self.options.after(ns.AFTER_COMBAT_SECONDS, function()
		if self.releases == release and self.holding then
			self:showHeld()
		end
	end)
end

-- The "While you were fighting" toast for held toasts, below.
local whileFighting

-- Ends the hold, putting what it held in the lanes (ANN-R36).
---@package
function Lanes:showHeld()
	self.holding = false
	self.big, self.heldBig = self.heldBig, {}
	local held = {}
	for _, announcement in ipairs(self.heldToasts) do
		local kept = self:unexpired(announcement)
		-- A toast whose toast moments expired is headlined by a Nod now, and held Nods don't show (ANN-R36).
		if kept and LANE[kept.rung] == "toast" then
			held[#held + 1] = kept
		end
	end
	self.heldToasts = {}
	if #held >= ns.FIGHTING_DIGEST then
		self.waiting = { whileFighting(held) }
	else
		self.waiting = held
	end
	self:next()
	if self.options.empty and self:IsEmpty() then
		self.options.empty()
	end
end

-- The "While you were fighting" toast for the toasts held (ANN-R36): it lists each one's headline, carries their Coins
-- (ANN-R23), and is a plain `toast`, so it plays the toast sound once, counts as one interruption and never steps
-- down (ANN-R31).
---@param toasts PagleAnnouncement[]
---@return PagleAnnouncement
function whileFighting(toasts)
	local headlines, coins = {}, 0
	for _, held in ipairs(toasts) do
		headlines[#headlines + 1] = held.headline
		coins = coins + held.coins
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

--- Takes a toast, a Nod or a splash off screen when it is clicked (ANN-R20). Does nothing for one no longer on
--- screen, or for a banner.
---@param display PagleDisplay
function Lanes:Dismiss(display)
	if display.form ~= "banner" then
		self:done(display)
	end
end

--- The pointer is on a toast or Nod (ANN-R20): its clock stands still until Resume. Nothing for one not on screen.
---@param display PagleDisplay
function Lanes:Pause(display)
	if display.paused or not self:onScreen(display) or display.form == "banner" or display.form == "splash" then
		return
	end
	display.paused = true
	display.left = math.max(0, (display.endsAt or 0) - self.options.now())
	display.token = (display.token or 0) + 1
end

--- The pointer left a paused toast or Nod: its clock goes on from where it stood.
---@param display PagleDisplay
function Lanes:Resume(display)
	if not display.paused then
		return
	end
	display.paused = false
	if self:onScreen(display) then
		self:schedule(display, display.left or 0)
	end
end

--- Takes `announcement` back (a `/pagle dev tour` stop's hide, CORE-R68): off screen if it shows, out of its lane or
--- the hold if it waits, so what waits behind it comes next. Nothing for one the lanes don't have.
---@param announcement PagleAnnouncement
function Lanes:Withdraw(announcement)
	for _, list in ipairs({ self.waiting, self.big, self.heldToasts, self.heldBig }) do
		for i = #list, 1, -1 do
			if list[i] == announcement then
				table.remove(list, i)
			end
		end
	end
	local showing = {}
	for _, display in ipairs(self.column) do
		showing[#showing + 1] = display
	end
	showing[#showing + 1] = self.centre
	for _, display in ipairs(showing) do
		if display.announcement == announcement then
			self:done(display)
		end
	end
end

-- Whether `display` is on screen, in the centre or the column.
---@package
---@param display PagleDisplay
---@return boolean
function Lanes:onScreen(display)
	if self.centre == display then
		return true
	end
	for _, entry in ipairs(self.column) do
		if entry == display then
			return true
		end
	end
	return false
end

-- Whether a splash holds the column back (ANN-R20): one on screen, or one at the front of the centre's queue.
---@package
---@return boolean
function Lanes:splashHolds()
	local centre, front = self.centre, self.big[1]
	return (centre ~= nil and centre.form == "splash") or (front ~= nil and front.rung == "splash")
end

-- How many toasts the column shows, and how tall it stands.
---@package
---@return integer toasts
---@return number height
function Lanes:columnLoad()
	local toasts, height = 0, 0
	for _, display in ipairs(self.column) do
		if display.form == "toast" then
			toasts = toasts + 1
		end
		height = height + display.height
	end
	return toasts, height
end

-- The form `announcement` would show in now: a Nod for a Nod, or for a toast.low the budget steps down (ANN-R31);
-- otherwise a toast.
---@package
---@param announcement PagleAnnouncement
---@return "toast"|"nod"
function Lanes:formOf(announcement)
	if LANE[announcement.rung] == "nod" or (announcement.rung == "toast.low" and self:spent()) then
		return "nod"
	end
	return "toast"
end

-- The height `announcement` takes in the column as `form`, its gap included: a Nod's, or its toast page's with
-- toast.high's bookmark below it (logic/ToastStyles.lua's ns.ToastPage).
---@param announcement PagleAnnouncement
---@param form "toast"|"nod"
---@return number
local function heightOf(announcement, form)
	if form == "nod" then
		return ns.NOD_HEIGHT + ns.COLUMN_GAP
	end
	local page = ns.ToastPage(announcement)
	return page.h + (page.high and ns.RIBBON_HEIGHT or 0) + ns.COLUMN_GAP
end

-- Whether the column takes `announcement` as `form` now (ANN-R20): no splash holds it back, it has fewer than
-- COLUMN_ENTRIES entries and, for a toast, fewer than COLUMN_TOASTS toasts, and it fits under COLUMN_HEIGHT (an empty
-- column takes anything).
---@package
---@param announcement PagleAnnouncement
---@param form "toast"|"nod"
---@return boolean
function Lanes:columnTakes(announcement, form)
	if self:splashHolds() or #self.column >= ns.COLUMN_ENTRIES then
		return false
	end
	local toasts, height = self:columnLoad()
	if form == "toast" and toasts >= ns.COLUMN_TOASTS then
		return false
	end
	return #self.column == 0 or height + heightOf(announcement, form) <= ns.COLUMN_HEIGHT + ns.COLUMN_GAP
end

-- Whether the next banner or splash, `front`, may start (ANN-R20): nothing is in the centre, no banner is still
-- leaving it, and for a splash, no toast is in the column.
---@package
---@param front PagleAnnouncement
---@return boolean
function Lanes:bigMayStart(front)
	if self.centre ~= nil or self.bannerLeaving then
		return false
	end
	if front.rung == "splash" then
		local toasts = self:columnLoad()
		return toasts == 0
	end
	return true
end

-- Shows whatever is next in each lane whose place is free, while the lanes aren't held: the next banner or splash
-- first, so a Cast's two Announcements appear in that order, then the next toast or Nod. Each is checked as it is
-- about to show (ANN-R40, ANN-R45): one with nothing left to show is skipped, and a toast.low the budget steps down
-- shows as a Nod (ANN-R31).
---@package
function Lanes:next()
	while not self.holding do
		local front = self.waiting[1]
		local shown
		if self.big[1] and self:bigMayStart(self.big[1]) then
			shown = self:place(table.remove(self.big, 1))
		elseif front and self:columnTakes(front, self:formOf(front)) then
			shown = self:place(table.remove(self.waiting, 1))
		else
			return
		end
		if shown == nil then
			return
		end
	end
end

-- Shows `announcement`, just taken from its lane, by the rung it has now (expired moments may have changed it): in
-- the centre, or in the column as a toast or a Nod. One that may not show there now goes back to the front of its
-- lane. Returns nil when it went back, so the caller stops; true otherwise, shown or dropped.
---@package
---@param announcement PagleAnnouncement
---@return boolean?
function Lanes:place(announcement)
	local kept = self:showable(announcement)
	if not kept then
		return true
	end
	if LANE[kept.rung] == "big" then
		if not self:bigMayStart(kept) then
			wait(self.big, kept)
			return nil
		end
		self:showCentre(kept, kept.rung --[[@as "banner"|"splash"]])
		return true
	end
	local form = self:formOf(kept)
	if not self:columnTakes(kept, form) then
		table.insert(self.waiting, 1, kept)
		return nil
	end
	self:showInColumn(kept, form)
	return true
end

-- Counts an interruption appearing now (ANN-R30), forgetting those older than the longest window.
---@package
---@param now number
function Lanes:interrupt(now)
	while self.interruptions[1] and self.interruptions[1] <= now - LONGEST_WINDOW do
		table.remove(self.interruptions, 1)
	end
	self.interruptions[#self.interruptions + 1] = now
end

-- Puts a banner or splash in the centre until its time is up: a banner settles, then stays its hold; a splash stays
-- SPLASH_SECONDS unless clicked.
---@package
---@param announcement PagleAnnouncement
---@param form "banner"|"splash"
function Lanes:showCentre(announcement, form)
	local display = { announcement = announcement, form = form }
	self.centre = display
	local now = self.options.now()
	self:interrupt(now)
	display.sound = self:sound(announcement, form, now)
	self.options.show(display)
	if display.sound then
		self.options.play(display.sound)
	end
	local seconds = form == "banner" and ns.SETTLE_SECONDS.banner + ns.HOLD_SECONDS.banner or ns.SPLASH_SECONDS
	self:schedule(display, seconds)
end

-- How long a toast holds once settled (ANN-R20): "While you were fighting" and a toast.high 8 s, whatever page it is
-- drawn on (a ruled toast.high is on the ruled toast page); any other toast its page's hold.
---@param announcement PagleAnnouncement
---@return number
local function toastHold(announcement)
	if announcement.fighting then
		return ns.HOLD_SECONDS.digest
	elseif announcement.headline.rung == "toast.high" then
		return ns.HOLD_SECONDS.high
	end
	return ns.HOLD_SECONDS[ns.ToastPage(announcement).page]
end

-- Puts a toast or a Nod at the foot of the column until its time is up: it settles, then stays its hold, a toast's
-- (toastHold) or a Nod's. A toast counts as an interruption and plays its sound (ANN-R30, ANN-R70); a Nod does neither.
---@package
---@param announcement PagleAnnouncement
---@param form "toast"|"nod"
function Lanes:showInColumn(announcement, form)
	local display = { announcement = announcement, form = form, height = heightOf(announcement, form) }
	table.insert(self.column, 1, display)
	local hold = ns.HOLD_SECONDS.nod
	if form == "toast" then
		local now = self.options.now()
		self:interrupt(now)
		display.sound = self:sound(announcement, form, now)
		hold = toastHold(announcement)
	end
	self.options.show(display)
	if display.sound then
		self.options.play(display.sound)
	end
	self:schedule(display, ns.SETTLE_SECONDS[form] + hold)
end

-- Ends `display`'s time `seconds` from now, unless it is paused or taken off first.
---@package
---@param display PagleDisplay
---@param seconds number
function Lanes:schedule(display, seconds)
	display.token = (display.token or 0) + 1
	local token = display.token
	display.endsAt = self.options.now() + seconds
	self.options.after(seconds, function()
		if display.token == token then
			self:done(display)
		end
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

-- Takes `display` off screen if it's still there, and frees its place for what waits.
---@package
---@param display PagleDisplay
function Lanes:done(display)
	if self.centre == display then
		self.centre = nil
	else
		local at
		for i, entry in ipairs(self.column) do
			if entry == display then
				at = i
			end
		end
		if not at then
			return
		end
		table.remove(self.column, at)
	end
	display.token = (display.token or 0) + 1
	self.options.hide(display)
	if display.form == "banner" then
		-- The centre stays taken while it leaves (LEAVE_SECONDS).
		self.bannerLeaving = true
		self.options.after(ns.LEAVE_SECONDS.banner, function()
			self.bannerLeaving = false
			self:next()
			if self.options.empty and self:IsEmpty() then
				self.options.empty()
			end
		end)
	end
	self:next()
	-- A Nod leaving frees nothing the cards wait for (ANN-R21).
	if display.form ~= "nod" and self.options.empty and self:IsEmpty() then
		self.options.empty()
	end
end

--- Whether the toasts and the centre are empty (ANN-R21): no banner, splash or toast on screen and none waiting.
--- Nods don't count. Cards show only then.
---@return boolean
function Lanes:IsEmpty()
	if self.centre ~= nil or self.bannerLeaving or #self.big > 0 then
		return false
	end
	for _, display in ipairs(self.column) do
		if display.form == "toast" then
			return false
		end
	end
	for _, announcement in ipairs(self.waiting) do
		if LANE[announcement.rung] == "toast" then
			return false
		end
	end
	return true
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
---@field label string    -- the number in plain words ("length", "weight")

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
