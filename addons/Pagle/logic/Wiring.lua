---@class PagleNS
local ns = select(2, ...)

-- Core's wiring (CORE-R18): how its projection machinery, Sessions, moments, Session summary, cards, wallet and Field
-- report are built and connected to each other, to PagleDB and to the Module handle. Pure logic over a host
-- (CORE-R7): Core's adapter builds its host over the WoW client (adapter/Host.lua), and FakePagle builds one over its
-- fakes, so both run this one wiring and the double can't drift from Core. What differs between them is only the host
-- and the display each factory is handed.

--- What the wiring needs from where Core runs. Every function is called when needed, never stored.
---@class PagleHost
---@field registry PagleModuleRegistry          -- the Module registry, whose handles get the methods
---@field db fun(): { global: table, profile: table } -- PagleDB, once login step 1 has opened it
---@field catchLog fun(): PagleCatchLog          -- the Catch log, once login step 1 has opened it
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
---@field print fun(line: string)                -- prints a chat line
---@field syncLimit? integer                     -- the projections' sync limit; default PROJECTION_SYNC_LIMIT

---@class PagleNS
---@field projections PagleProjections Core's one projection machinery (ns.WireProjections).
---@field sessions PagleSessions Core's Sessions (ns.WireSessions).
---@field moments PagleMoments Core's one moment collector (ns.WireMoments).
---@field summary PagleSummary Core's one Session summary (ns.WireSummary).
---@field cards PagleCards Core's cards (ns.WireCards).
---@field wallet PagleWallet Core's one wallet (ns.WireWallet).
---@field fieldReport PagleFieldReportReaders? Core's Field report, from login step 1 on (ns.WireFieldReport).
---@field fishing PagleFishing Core's Cast state machine, which Core's adapter and FakePagle each build.
---@field dev PagleDevCommands Core's `/pagle dev` commands (ns.WireDev).

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
--- with a timer for the 300 s after each Cast.
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
--- open ends 300 s after its last Cast; one that ended while away gets its SessionEnded once no projection is
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

--- The Session open now, while its last Cast is under 300 s ago, else nil (LOG-R64). A fresh copy each call.
---@return PagleSession?
function Sessions:Get()
	return self.tracker and self.tracker:Get(self.host.serverTime())
end

--- `/pagle dev endsession` (#247): ends the Session open now as if its gap had passed (LOG-R62), and stops its
--- timer. Returns false when none is open.
---@return boolean ended
function Sessions:EndNow()
	local tracker = self.tracker
	if not tracker or not tracker:EndNow(self.host.serverTime()) then
		return false
	end
	waitFor(self, nil)
	return true
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
			if card.numbers and not card.preview then
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

--- The Field report's two readers (field-report.md › The projection).
---@class PagleFieldReportReaders
---@field rows fun(): PagleReportRow[]? -- every I, K and P row, unsorted; nil while the projection updates (REP-R42)
---@field count fun(): integer          -- the I and K rows stored, plus the P rows built now (REP-R26)

--- Login step 1 (LOG-R1), once PagleDB is open and the catalogue built: Core's Field report as ns.fieldReport. Its
--- projection is bound in PagleDB.global.projections.fieldReport on Core's machinery, ahead of every Module's, so
--- login step 3 catches it up or rebuilds it with the rest (REP-R25, LOG-R71, LOG-R72, LOG-R78). It reads the log's
--- records as every projection does (host.iterate), the catalogue in ns.Catalogue at each call, and the P rows from
--- PagleDB.global.diagnostics when asked for (REP-R22). It reads only Core's log, catalogue and buffer, so enabled
--- Modules change nothing (REP-R90), and it raises no moment and no Write-up (REP-R45, REP-R92).
---@param host PagleHost
function ns.WireFieldReport(host)
	---@type PagleCatalogue
	local catalogue = setmetatable({}, {
		__index = function(_, name)
			return ns.Catalogue[name]
		end,
	})
	local rows, count = ns.AddFieldReport({
		projections = ns.projections,
		db = host.db().global.projections.fieldReport,
		catalogue = catalogue,
		iterate = host.iterate,
		buffer = function()
			return host.db().global.diagnostics
		end,
		casts = function()
			return host.catchLog():Reverse("cast")
		end,
	})
	ns.fieldReport = { rows = rows, count = count }
end

--- What only the client knows for the Field report's text: the header's addon version and locale, and the names a
--- row's comment shows (REP-R30). Core's adapter passes the client's lookups; FakePagle passes fixed ones.
---@class PagleFieldReportClient
---@field addon fun(): string    -- this addon's TOC version, or "unknown"
---@field locale fun(): string   -- GetLocale()
---@field names PagleReportNames -- a secret is never a name (CORE-R31)

--- The Field report's text for its rows (ns.FieldReportRows(), any order), as its parts in order (REP-R30–R33),
--- built when called, never stored: the header from `client`, the catalogue's fingerprint (host.fingerprint) and the
--- Catch log's logId, which is written only as its reporter key (REP-R35, REP-R36).
---@param host PagleHost
---@param client PagleFieldReportClient
---@return fun(rows: PagleReportRow[]): string[]
function ns.FieldReportTextFunction(host, client)
	return function(rows)
		return ns.FieldReportParts(rows, {
			addon = client.addon(),
			fingerprint = assert(host.fingerprint(), "the catalogue is built first"),
			locale = client.locale(),
			logId = host.catchLog().data.logId or "",
		}, client.names)
	end
end

--- Core's `/pagle dev` commands as ns.dev (#247), over PagleDB.global's `dev` switch, Core's Sessions, the
--- catalogue's areas and the Cast state machine (ns.fishing). `catch` runs only on a test log (`PagleLog.test`).
--- `preview` hands its samples to `show`, the display (as ns.WireMoments' is), and its card to ns.cards.
---@param host PagleHost
---@param show fun(announcement: PagleAnnouncement) hands an Announcement to the display (ANN-R20)
function ns.WireDev(host, show)
	ns.dev = ns.NewDevCommands({
		global = function()
			return host.db().global
		end,
		testLog = function()
			return host.catchLog().data.test == true
		end,
		endSession = function()
			return ns.sessions:EndNow()
		end,
		area = function(areaID)
			return ns.DevArea(ns.Catalogue, areaID)
		end,
		catch = function(itemID, zone, subzone)
			local area = zone and { zone = zone, subzone = subzone } or nil
			return ns.fishing:RecordSynthetic({ { itemID = itemID, quantity = 1 } }, area)
		end,
		announce = function(announcement)
			host.call(show, announcement)
		end,
		showCard = function(card)
			return ns.cards:Preview(card)
		end,
		print = host.print,
	})
end
