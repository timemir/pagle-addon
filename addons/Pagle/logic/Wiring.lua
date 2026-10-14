---@class PagleNS
local ns = select(2, ...)

-- Core's wiring (CORE-R18): how its projection machinery, Sessions, moments, Session summary, cards, wallet and
-- Prestige and purchase entries are built and connected to each other, to PagleDB and to the Module handle. Pure
-- logic over a host (CORE-R7): Core's adapter builds its host over the WoW client (adapter/Host.lua), and FakePagle
-- builds one over its fakes, so both run this one wiring and the double can't drift from Core. What differs between
-- them is only the host and the display each factory is handed.

--- What the wiring needs from where Core runs. Every function is called when needed, never stored.
---@class PagleHost
---@field registry PagleModuleRegistry          -- the Module registry, whose handles get the methods
---@field db fun(): { global: table, profile: table } -- PagleDB, once login step 1 has opened it
---@field catchLog fun(): PagleCatchLog          -- the Catch log, once login step 1 has opened it
---@field character fun(): integer?             -- the logged-in character's index in PagleLog.characters (LOG-R25)
---@field fire fun(event: PagleEvent, ...: any)  -- fires a Core event on the bus (CORE-R22)
---@field listen fun(owner: string, event: PagleEvent, fn: fun(event: string, ...: any)) -- Pagle.RegisterCallback
---@field fingerprint fun(): string?             -- Pagle.CONTENT_FINGERPRINT
---@field iterate fun(afterSeq: integer?): fun(): PagleRecord? -- the log's records after a seq (Pagle.IterateCatches)
---@field serverTime fun(): integer              -- GetServerTime()
---@field after fun(seconds: number, fn: fun())  -- runs fn `seconds` from now (C_Timer.After)
---@field nextFrame fun(step: fun())             -- runs step on the next frame
---@field clock fun(): number                    -- a clock in ms, for the projections' frame budget (debugprofilestop)
---@field call fun(fn: function, ...: any): ...  -- calls fn; an error is reported, not raised (securecallfunction)
---@field report fun(message: string)            -- reports an error and carries on (geterrorhandler())
---@field syncLimit? integer                     -- the projections' sync limit; default PROJECTION_SYNC_LIMIT

---@class PagleNS
---@field projections PagleProjections Core's one projection machinery (ns.WireProjections).
---@field sessions PagleSessions Core's Sessions (ns.WireSessions).
---@field moments PagleMoments Core's one moment collector (ns.WireMoments).
---@field summary PagleSummary Core's one Session summary (ns.WireSummary).
---@field cards PagleCards Core's cards (ns.WireCards).
---@field wallet PagleWallet Core's one wallet (ns.WireWallet).

--- Core's projection machinery (LOG-R70–R78) as ns.projections, and `M:NewProjection` and `M:IterateCatches` on every
--- Module handle. Until Module records (M7), a Module's records are the ones Pagle.IterateCatches yields.
---@param host PagleHost
function ns.WireProjections(host)
	ns.projections = ns.NewProjections({
		length = function()
			return #host.catchLog().data.entries
		end,
		logId = function()
			return host.catchLog().data.logId
		end,
		fingerprint = host.fingerprint,
		clock = host.clock,
		nextFrame = host.nextFrame,
		call = host.call,
		syncLimit = host.syncLimit,
	})
	ns.AddProjectionMethods(host.registry, ns.projections, host.iterate)
end

--- Sessions as Core runs them (LOG-R60–R64): the tracker over the Catch log and PagleDB.global, on the server time,
--- with a timer for the 900 s after each Cast.
---@class PagleSessions
---@field package host PagleHost
---@field package tracker PagleSessionTracker? -- from Open on
---@field package waits integer                -- each wait started bumps it, so only the latest one's timer ticks
local Sessions = {}
Sessions.__index = Sessions

--- Core's Sessions as ns.sessions, opened by login step 1 (Sessions:Open).
---@param host PagleHost
function ns.WireSessions(host)
	ns.sessions = setmetatable({ host = host, waits = 0 }, Sessions)
end

-- Calls Tick `seconds` from now, unless a later wait replaces it; nothing for nil.
---@param sessions PagleSessions
---@param seconds integer?
local function waitFor(sessions, seconds)
	sessions.waits = sessions.waits + 1
	local wait = sessions.waits
	if seconds then
		sessions.host.after(seconds, function()
			local tracker = sessions.tracker
			if wait == sessions.waits and tracker then
				waitFor(sessions, tracker:Tick(sessions.host.serverTime()))
			end
		end)
	end
end

--- Login step 1 (LOG-R1), once the Catch log and PagleDB are open: notes the latest Session (LOG-R63). One still
--- open ends 900 s after its last Cast; one that ended while away gets its SessionEnded once no projection is
--- updating, unless a Cast fires it first.
function Sessions:Open()
	local host = self.host
	local tracker = ns.NewSessionTracker({ catchLog = host.catchLog(), global = host.db().global, fire = host.fire })
	self.tracker = tracker
	waitFor(self, tracker:Start(host.serverTime()))
	ns.projections:WhenIdle(function()
		tracker:Idle()
	end)
end

--- LOG-R9 step 3, right after a Cast's entry is appended and before the projections get it: any SessionEnded still
--- due, then SessionStarted if the Cast opened a Session (LOG-R62, LOG-R63).
function Sessions:Cast()
	if self.tracker then
		waitFor(self, self.tracker:Cast())
	end
end

--- The Session open now, while its last Cast is under 900 s ago, else nil (LOG-R64). A fresh copy each call.
---@return PagleSession?
function Sessions:Get()
	return self.tracker and self.tracker:Get(self.host.serverTime())
end

--- Core's moment collector as ns.moments (ANN-R1–R4, ANN-R10–R12), and `M:RaiseMoment` on every Module handle. Each
--- Announcement goes to `show`, the display; every moment Core keeps goes to ns.summary (ANN-R25).
---@param host PagleHost
---@param show fun(announcement: PagleAnnouncement) hands an Announcement to the display (ANN-R20)
function ns.WireMoments(host, show)
	ns.moments = ns.NewMoments({
		mode = function()
			return ns.projections:Mode()
		end,
		isUpdating = function()
			return ns.projections:IsUpdating()
		end,
		whenIdle = function(fn)
			ns.projections:WhenIdle(fn)
		end,
		nextFrame = host.nextFrame,
		report = host.report,
		show = function(announcement)
			host.call(show, announcement)
		end,
		summarize = function(moment)
			host.call(ns.summary.Add, ns.summary, moment)
		end,
	})
	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Raises a moment (ANN-R1): see ns.RaiseMomentMethod. Raises an error for an unknown rung, or no kind or title.
	--- Ordinary Catches raise nothing (ANN-R13): that is each Module's choice, not Core's.
	ModuleHandle.RaiseMoment = ns.RaiseMomentMethod(host.registry, ns.moments)
end

--- Core's Session summary as ns.summary (ANN-R50–R54), fed the Session events on the bus, and `M:SetSummaryLine` on
--- every Module handle. It reads PagleDB.global at each call.
---@param host PagleHost
---@param waitingChanged fun(waiting: integer) the count Cozy mode kept changed: the compartment entry's label (ANN-R42)
function ns.WireSummary(host, waitingChanged)
	ns.summary = ns.NewSummary({
		global = function()
			return host.db().global
		end,
		isOpen = function()
			return ns.sessions:Get() ~= nil -- ANN-R52: Pagle.GetSession() isn't nil
		end,
		modules = function()
			return host.registry:Modules()
		end,
		cozy = function()
			return host.db().profile.announcements.cozy
		end,
		serverTime = host.serverTime,
		waitingChanged = waitingChanged,
		takeWriteUp = function()
			return ns.cards:TakeWriteUp()
		end,
	})
	-- Its own owner on the bus, so no other registration replaces these.
	local owner = "Pagle summary"
	-- ANN-R52: moments raised with no Session open join the one that starts.
	host.listen(owner, "SessionStarted", function()
		ns.summary:Started()
	end)
	-- ANN-R53: a Session that raised a moment becomes a card, which shows when it can (ANN-R21); its moments are
	-- cleared either way.
	host.listen(owner, "SessionEnded", function(_, session)
		if ns.summary:Ended(session) then
			ns.cards:Next()
		end
	end)
	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Sets one of the Module's Session summary lines, or removes it with nil (ANN-R51): see
	--- ns.SetSummaryLineMethod. Lines stay set across Sessions until the Module changes them, and alone never make a
	--- card.
	ModuleHandle.SetSummaryLine = ns.SetSummaryLineMethod(host.registry, ns.summary)
end

--- Where the cards show: the frame, and the lanes they wait for.
---@class PagleCardsView
---@field show fun(card: PagleCard)    -- puts the card on screen, until the player closes it
---@field hide fun(card: PagleCard)    -- takes it off screen without closing it (ANN-R35)
---@field lanesEmpty fun(): boolean    -- the toast and big lanes are empty (ANN-R21)
---@field held fun(): boolean          -- the lanes are held through combat (ANN-R35)

--- Core's cards as ns.cards (ANN-R21, ANN-R54, ANN-R61), started: they wait for the projections' idle hook, then show
--- whenever the lanes are empty and not held. `M:RaiseWriteUp` goes on every Module handle. A Session summary card
--- showing ends the compartment's waiting count (ANN-R42).
---@param host PagleHost
---@param view PagleCardsView
function ns.WireCards(host, view)
	ns.cards = ns.NewCards({
		global = function()
			return host.db().global
		end,
		mode = function()
			return ns.projections:Mode()
		end,
		whenIdle = function(fn)
			ns.projections:WhenIdle(fn)
		end,
		nextFrame = host.nextFrame,
		lanesEmpty = view.lanesEmpty,
		held = view.held,
		cozy = function()
			return host.db().profile.announcements.cozy
		end,
		show = function(card)
			view.show(card)
			if card.numbers then
				ns.summary:SummaryShown()
			end
		end,
		hide = view.hide,
	})
	ns.cards:Start()
	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Raises a Write-up section from a projection's done (ANN-R60): see ns.RaiseWriteUpMethod. Raises an error
	--- outside a done, or for a section without a heading or with lines that aren't strings.
	ModuleHandle.RaiseWriteUp = ns.RaiseWriteUpMethod(host.registry, ns.cards)
end

--- Core's wallet as ns.wallet (SHOP-R2–R4, SHOP-R12), firing BalanceChanged on the bus, and `M:ReportCoinsEarned` on
--- every Module handle. It is empty until login step 1 opens the stored totals (ns.OpenWallet).
---@param host PagleHost
function ns.WireWallet(host)
	ns.wallet = ns.NewWallet(host.fire)
	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Reports the Module's lifetime Coins earned (SHOP-R2): see ns.ReportCoinsEarnedMethod. Raises an error for
	--- anything but a whole number, 0 or more.
	ModuleHandle.ReportCoinsEarned = ns.ReportCoinsEarnedMethod(host.registry, ns.wallet)
	--- Login step 1, once PagleDB is open: the wallet reads and writes the stored totals from now on (SHOP-R3).
	function ns.OpenWallet()
		ns.wallet:Open(host.db().global.coins.earned)
	end
end

--- Prestige and purchase entries (LOG-R38, LOG-R39) as Core appends them: `M:RecordPrestige()` on every Module
--- handle, and Core's own `ns.RecordPrestige()` and `ns.RecordPurchase(goodID, price)`. Each appends for the
--- logged-in character at the server time and hands the record to the projections live (LOG-R73). A purchase has no
--- Pagle or Module call: the Curio Shop's buy flow is its only caller.
---@param host PagleHost
function ns.WireLogEntries(host)
	-- Appends `record` (its kind and fields) for the logged-in character now, and hands it over live. Raises an error
	-- at the caller of `what`, appending nothing, before login or from a replay, rebuild or done: an entry appended
	-- while a projection updates would be appended again at its next rebuild, and the log is never rewritten
	-- (LOG-R14, LOG-R75).
	---@param record table
	---@param what string the call, for its error
	---@return PagleRecord
	local function append(record, what)
		local mode = ns.projections:Mode()
		if mode and mode ~= "live" then
			error(("%s can't append from a projection's %s"):format(what, mode), 3)
		end
		local char = host.character()
		if not char then
			error(("%s appends for the logged-in character: call it after PLAYER_LOGIN"):format(what), 3)
		end
		record.char, record.time = char, host.serverTime()
		local appended = host.catchLog():Append(record)
		ns.projections:Live(appended) -- LOG-R73
		return appended
	end

	--- Appends a Prestige (`P1`) with the new prestige rank, one more than the Prestiges already in the log, hands
	--- it to the projections live, then fires `Prestige(record)` (LOG-R38). Returns the record.
	---@return PaglePrestige
	function ns.RecordPrestige()
		local rank = host.catchLog():Prestiges() + 1
		local prestige = append({ kind = "prestige", rank = rank }, "M:RecordPrestige()")
		---@cast prestige PaglePrestige
		host.fire("Prestige", prestige)
		return prestige
	end

	--- Appends a purchase (`U1`) of `goodID` for `price` Coins and hands it to the projections live (LOG-R39,
	--- SHOP-R10). Returns the record. Raises an error, appending nothing, for a good ID outside `[%w_.]+` or a price
	--- that isn't a whole number of Coins.
	---@param goodID string
	---@param price integer
	---@return PaglePurchase
	function ns.RecordPurchase(goodID, price)
		local purchase = append({ kind = "purchase", good = goodID, price = price }, "ns.RecordPurchase")
		---@cast purchase PaglePurchase
		return purchase
	end

	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Appends a Prestige for the logged-in character, hands it to the projections live, then fires `Prestige`
	--- (LOG-R38): see ns.RecordPrestige. Any Module may call it; Core decides nothing about when. Raises an error
	--- before login or from a projection's replay, rebuild or done.
	---@return PaglePrestige
	function ModuleHandle:RecordPrestige()
		host.registry:ModuleCalling(self, "RecordPrestige", "")
		return ns.RecordPrestige()
	end
end
