---@class PagleNS
local ns = select(2, ...)

-- Core's wiring (CORE-R18): how its projection machinery, Sessions, moments, Session summary, cards, wallet,
-- Prestige and purchase entries, goods, Field report and wallet projection are built and connected to each other, to
-- PagleDB and to the Module handle. Pure logic over a host (CORE-R7): Core's adapter builds its host over the WoW
-- client (adapter/Host.lua), and FakePagle builds one over its fakes, so both run this one wiring and the double can't
-- drift from Core. What differs between them is only the host and the display each factory is handed.

--- What the wiring needs from where Core runs. Every function is called when needed, never stored.
---@class PagleHost
---@field registry PagleModuleRegistry          -- the Module registry, whose handles get the methods
---@field db fun(): { global: table, profile: table } -- PagleDB, once login step 1 has opened it
---@field catchLog fun(): PagleCatchLog          -- the Catch log, once login step 1 has opened it
---@field character fun(): integer?             -- the logged-in character's index in PagleLog.characters (LOG-R25)
---@field fire fun(event: PagleEvent, ...: any)  -- fires a Core event on the bus (CORE-R22)
---@field listen fun(owner: string, event: PagleEvent, fn: fun(event: string, ...: any)) -- Pagle.RegisterCallback
---@field fingerprint fun(): string?             -- Pagle.CONTENT_FINGERPRINT
---@field iterate fun(afterSeq: integer?, module: string?): fun(): PagleRecord? -- the log's records after a seq: what
--- Pagle.IterateCatches yields, plus the Module records of `module` if given (M:IterateCatches, LOG-R41, LOG-R42)
---@field serverTime fun(): integer              -- GetServerTime()
---@field after fun(seconds: number, fn: fun())  -- runs fn `seconds` from now (C_Timer.After)
---@field nextFrame fun(step: fun())             -- runs step on the next frame
---@field clock fun(): number                    -- a clock in ms, for the projections' frame budget (debugprofilestop)
---@field call fun(fn: function, ...: any): ...  -- calls fn; an error is reported, not raised (securecallfunction)
---@field report fun(message: string)            -- reports an error and carries on (geterrorhandler())
---@field region fun(): integer?                 -- GetCurrentRegion(), nil where the call doesn't exist (LOG-R69)
---@field print fun(line: string)                -- prints a chat line
---@field isRestricted fun(): boolean            -- Pagle.IsRestricted() (CORE-R33)
---@field syncLimit? integer                     -- the projections' sync limit; default PROJECTION_SYNC_LIMIT

---@class PagleNS
---@field projections PagleProjections Core's one projection machinery (ns.WireProjections).
---@field sessions PagleSessions Core's Sessions (ns.WireSessions).
---@field moments PagleMoments Core's one moment collector (ns.WireMoments).
---@field summary PagleSummary Core's one Session summary (ns.WireSummary).
---@field cards PagleCards Core's cards (ns.WireCards).
---@field wallet PagleWallet Core's one wallet (ns.WireWallet).
---@field goods PagleGoods Core's one goods registry (ns.WireGoods).
---@field shop PagleShop The Curio Shop's entry points (ns.WireShop).
---@field dock PagleDockWiring Core's tracker dock (ns.WireDock).
---@field fieldReport PagleFieldReportReaders? Core's Field report, from login step 1 on (ns.WireFieldReport).
---@field walletProjection PagleProjection? Core's wallet projection, from login step 1 (ns.WireWalletProjection).
---@field LengthUnit fun(): PagleLengthUnit The Angler's length unit now (ns.WireLength).
---@field fishing PagleFishing Core's Cast state machine, which Core's adapter and FakePagle each build.
---@field dev PagleDevCommands Core's `/pagle dev` commands (ns.WireDev).
---@field tourStops PagleTourStops Core's one registry of tour stops (ns.WireDev, CORE-R65).
---@field tour PagleTour Core's `/pagle dev tour` (ns.WireDev, CORE-R66).
---@field onboarding PagleOnboarding Core's onboarding state and its hooks (ns.WireOnboarding, core/onboarding.md).
---@field guideSteps PagleGuideSteps The Field guide's step registry (ns.WireGuide, ONB-R21).
---@field guide PagleGuide The Field guide (ns.WireGuide, ONB-R20–R27).
---@field marginNotes PagleMarginNotes Core's Margin notes (ns.WireMarginNotes, ONB-R50–R53).

--- Core's projection machinery (LOG-R70–R78) as ns.projections, and `M:NewProjection` and `M:IterateCatches` on every
--- Module handle. A Module's records are the ones Pagle.IterateCatches yields plus its own Module records (LOG-R42).
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
		-- #262: while this login's load timings are kept (dev mode at ADDON_LOADED, logic/LoadTimings.lua).
		timings = function()
			return ns.loadTimings and ns.loadTimings.projections
		end,
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

--- `/pagle dev endsession` (#247, #258): ends the Session open now as if its gap had passed (LOG-R62), notes a
--- Session break so the next Cast starts a new one (LOG-R99), and stops its timer. Returns false when none is open.
---@return boolean ended
function Sessions:EndNow()
	local tracker = self.tracker
	if not tracker or not tracker:EndNow(self.host.serverTime()) then
		return false
	end
	waitFor(self, nil)
	return true
end

--- The Angler's length unit (LOG-R69) as ns.LengthUnit(): PagleDB.profile.lengthUnit, or with none stored (or before
--- PagleDB is open) the host's region default, read at each call. Returns Pagle.FormatLength, a length in it.
---@param host PagleHost
---@return fun(mm: number): string
function ns.WireLength(host)
	function ns.LengthUnit()
		local db = host.db()
		return ns.LengthUnitOf(db and db.profile.lengthUnit, host.region())
	end
	return function(mm)
		return ns.FormatLength(mm, ns.LengthUnit())
	end
end

--- Publishes Simulated Size on `Pagle` (LOG-R67–R69): `Pagle.SIZE_BANDS`, the bands in order as `{ key, name }`, a
--- copy of Core's own so a Module can't change Core's; `Pagle.SIZE_RULES_VERSION`; and `Pagle.FormatLength(mm)` on
--- ns.WireLength. `wrap` turns the band list into what Modules get: Core's adapter passes none, FakePagle its
--- read-only proxy (CORE-R18).
---@param Pagle table
---@param host PagleHost
---@param wrap (fun(value: any): any)?
function ns.PublishSize(Pagle, host, wrap)
	---@class Pagle
	local api = Pagle
	local bands = {}
	for band, entry in ipairs(ns.SIZE_BANDS) do
		bands[band] = { key = entry.key, name = entry.name }
	end
	--- The Size bands in order, `{ key, name }`, Tiddler to Monster (LOG-R67). Names signed off for 1.0 (#264).
	---@type { key: string, name: string }[]
	api.SIZE_BANDS = wrap and wrap(bands) or bands
	--- Changes whenever the size multipliers change; a Module that stores sizes folds it into its rules version
	--- (LOG-R68).
	api.SIZE_RULES_VERSION = ns.SIZE_RULES_VERSION
	--- A length of `mm` millimetres in the Angler's length unit, to 0.1 of it: "34.2 cm" or "13.5 in" (LOG-R69). The
	--- unit is PagleDB.profile.lengthUnit, or inches on region 1 and centimetres elsewhere. It changes only what a
	--- length reads: compare lengths in millimetres.
	---@type fun(mm: number): string
	api.FormatLength = ns.WireLength(host)
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
	--- A Module raises nothing for an ordinary Catch: Core's catch Nod is its (ANN-R13, ns.WireCatchNods).
	ModuleHandle.RaiseMoment = ns.RaiseMomentMethod(host.registry, ns.moments)
end

--- Core's catch Nod (ANN-R13) on ns.moments: at each live `CastEnded("caught", cast)` (LOG-R9), while
--- PagleDB.profile.announcements.everyCatch ("Show every catch") is on, the Cast's catch Nod (ns.CatchNodMoment) in
--- the Angler's length unit. Replays and rebuilds fire no CastEnded, so only live Casts get one (ANN-R4).
---@param host PagleHost
---@param itemName fun(itemID: integer): string? the client's name for an item, nil until it has cached it
function ns.WireCatchNods(host, itemName)
	-- Its own owner on the bus, so no other registration replaces it.
	host.listen("Pagle catch nod", "CastEnded", function(_, outcome, cast)
		if outcome ~= "caught" or not cast or not host.db().profile.announcements.everyCatch then
			return
		end
		local moment = ns.CatchNodMoment(cast, itemName, ns.LengthUnit())
		if moment then
			ns.moments:RaiseCatchNod(moment)
		end
	end)
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
---@field lanesEmpty fun(): boolean    -- no toast, banner or splash shows or waits (ANN-R21)
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

--- Prestige and purchase entries and Module records (LOG-R38–R40) as Core appends them: `M:RecordPrestige()` and
--- `M:AppendRecord(kind, payload)` on every Module handle, and Core's own `ns.RecordPrestige()` and
--- `ns.RecordPurchase(goodID, price)`. Each appends for the logged-in character at the server time and hands the
--- record to the projections live (LOG-R73). A purchase has no Pagle or Module call: the Curio Shop's buy flow is its
--- only caller.
---@param host PagleHost
function ns.WireLogEntries(host)
	-- Appends `record` (its kind and fields) for the logged-in character now, and hands it over live. Raises an error
	-- at the caller of `what`, appending nothing, before login or from a replay, rebuild or done: an entry appended
	-- while a projection updates would be appended again at its next rebuild, and the log is never rewritten
	-- (LOG-R14, LOG-R40, LOG-R75).
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

	--- Appends a Module record (`A1`, LOG-R40, ADR 0008) of the Module's own `kind` ([%w_.]+) with `payload` (a
	--- string with no newline, at most 200 bytes, which Core never reads), for the logged-in character now, and
	--- returns it. Its Module's projections get it as live (LOG-R73, LOG-R74): at once when up to date, after the
	--- current apply returns when called from one, or behind the catch-up or rebuild in progress. Only this Module's
	--- `M:IterateCatches` and projections ever see it (LOG-R41). Raises an error at the caller, appending nothing, for
	--- a bad kind or payload, before PLAYER_LOGIN, or from a replay or rebuild apply or a done, so a rebuild never
	--- writes a record twice.
	---@param kind string
	---@param payload string
	---@return PagleModuleRecord
	function ModuleHandle:AppendRecord(kind, payload)
		local module = host.registry:ModuleCalling(self, "AppendRecord", "kind, payload")
		local problem = ns.ModuleRecordProblem(kind, payload)
		if problem then
			error(problem, 2)
		end
		-- Not a tail call, so append's error is this method's caller's.
		local record = append(
			{ kind = "module", module = module.def.name, recordKind = kind, payload = payload },
			"M:AppendRecord"
		)
		---@cast record PagleModuleRecord
		return record
	end
end

--- Core's goods registry as ns.goods (SHOP-R20–R26, SHOP-R30–R33) over PagleDB.global.goods and
--- PagleDB.profile.appearance, firing AppearanceChanged on the bus from ModulesChanged on, and `M:RegisterSlot`,
--- `M:RegisterGood` and `M:RefreshGoods` on every Module handle. Core registers its own goods with
--- ns.RegisterCoreSlot and ns.RegisterCoreGood, and refreshes them with ns.goods:Refresh(ns.CORE_OWNER). The wallet
--- projection hands it the purchased set with ns.goods:SetPurchased (SHOP-R11).
---@param host PagleHost
function ns.WireGoods(host)
	local goods = ns.NewGoods({
		db = host.db,
		modules = function()
			return host.registry:Modules()
		end,
		fire = host.fire,
		call = host.call,
		report = host.report,
	})
	ns.goods = goods
	-- Raises `problem`, if any, at the call of the function that called this one (SHOP-R23).
	---@param problem string?
	local function raise(problem)
		if problem then
			error(problem, 3)
		end
	end
	-- CORE-R19: every enabled Module has registered its goods, or failed to. Its own owner on the bus.
	host.listen("Pagle goods", "ModulesChanged", function()
		goods:Start()
	end)

	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Registers one of the Module's slots (SHOP-R21), any time after RegisterModule. Raises an error at the Module's
	--- call, registering nothing, for each mistake SHOP-R23 lists: an ID that isn't `<name lowercased>.<name>` of
	--- [%w_.], a duplicate, no label, or a category not in ns.SLOT_CATEGORY_ORDER.
	---@param slot PagleSlot
	function ModuleHandle:RegisterSlot(slot)
		local module = host.registry:ModuleCalling(self, "RegisterSlot", "slot")
		raise(goods:RegisterSlot(module.def.name, slot))
	end
	--- Registers one of the Module's goods in one of its slots (SHOP-R21, SHOP-R22), calling its isEarned() now if
	--- it is earned (SHOP-R31). Raises an error at the Module's call, registering nothing, for each mistake SHOP-R23
	--- lists: a duplicate ID or one without the Module's prefix, an unknown slot or another's, a second default, or
	--- not exactly one of `default`, `tier` (1, 2 or 3) and `isEarned`.
	---@param good PagleGood
	function ModuleHandle:RegisterGood(good)
		local module = host.registry:ModuleCalling(self, "RegisterGood", "good")
		raise(goods:RegisterGood(module.def.name, good))
	end
	--- Calls each of the Module's earned goods' isEarned() and caches the results (SHOP-R31); looks follow. Call it
	--- after a live entry that could change one, and from the projection's done, never mid-catch-up or mid-rebuild.
	function ModuleHandle:RefreshGoods()
		local module = host.registry:ModuleCalling(self, "RefreshGoods", "")
		goods:Refresh(module.def.name)
	end

	--- Registers one of Core's slots, with the `core.` prefix (SHOP-R21, SHOP-R25). Raises an error at Core's call,
	--- registering nothing, for a SHOP-R23 mistake.
	---@param slot PagleSlot
	function ns.RegisterCoreSlot(slot)
		raise(goods:RegisterSlot(ns.CORE_OWNER, slot))
	end
	--- Registers one of Core's goods in one of its slots (SHOP-R21, SHOP-R25). Raises an error at Core's call,
	--- registering nothing, for a SHOP-R23 mistake.
	---@param good PagleGood
	function ns.RegisterCoreGood(good)
		raise(goods:RegisterGood(ns.CORE_OWNER, good))
	end
end

--- Publishes the goods registry's reads and its one write on `Pagle` (wallet-and-shop.md › Contracts):
--- `Pagle.IsOwned`, `GetEquipped`, `SetEquipped` and `GetGood`, over ns.goods (ns.WireGoods). `wrap` turns what
--- GetGood returns into what Modules get: Core's adapter passes none, FakePagle its read-only proxy (CORE-R18).
---@param Pagle table
---@param wrap (fun(value: any): any)?
function ns.PublishGoods(Pagle, wrap)
	---@class Pagle
	local api = Pagle
	wrap = wrap or function(value)
		return value
	end

	--- Whether the Angler owns a good (SHOP-R30): a registered slot's default, a purchased good, or an earned good
	--- whose cached isEarned() result is true. It reads the cache, whether or not the good's Module is enabled.
	---@param goodID string
	---@return boolean
	function api.IsOwned(goodID)
		return ns.goods:IsOwned(goodID)
	end

	--- The good equipped in a slot (SHOP-R32): the stored pick while it is owned and its Module enabled, else the
	--- slot's default. Nil for a slot with no goods.
	---@param slot string
	---@return string? goodID
	function api.GetEquipped(slot)
		return ns.goods:GetEquipped(slot)
	end

	--- Equips an owned good of that slot (SHOP-R32), and returns true; returns false, changing nothing, for any
	--- other. AppearanceChanged follows if the look changed (SHOP-R33).
	---@param slot string
	---@param goodID string
	---@return boolean
	function api.SetEquipped(slot, goodID)
		return ns.goods:SetEquipped(slot, goodID)
	end

	--- A good's name, slot, icon, Module and description as cached (SHOP-R26), and whether it is its slot's default
	--- (`isDefault`, SHOP-R22), whether or not its Module is enabled; nil for a good never registered. A fresh copy
	--- each call.
	---@param goodID string
	---@return PagleGoodInfo?
	function api.GetGood(goodID)
		return wrap(ns.goods:GetGood(goodID))
	end
end

--- Where the Curio Shop shows: the window (adapter/Shop.lua), or FakePagle's record of it.
---@class PagleShopSeams
---@field isShown fun(): boolean      -- the shop is open
---@field show fun(selection: string|false|nil, asked: string?) -- opens it, or keeps it open: selecting that good,
--- nothing (false), or keeping the selection it has (nil); `asked` is the good Pagle.OpenShop asked for, if any
---@field hide fun()                  -- closes it

--- The Curio Shop's entry points (SHOP-R40, SHOP-R41), which Pagle.OpenShop, /pagle shop and the compartment entry call,
--- and its one way to spend Coins, which the bill of sale's Buy calls (SHOP-R13, LOG-R39).
---@class PagleShop
---@field Open fun(goodID: string?) -- Pagle.OpenShop
---@field Toggle fun()              -- /pagle shop
---@field Buy fun(goodID: string, useNow: boolean): boolean -- the bill of sale's Buy: true if it bought
---@field Use fun(goodID: string): boolean -- the stage's Use: true if it equipped the good

--- The Curio Shop's entry points as ns.shop (SHOP-R40, SHOP-R41), its buying (ns.shop.Buy), and ns.ShopModel, the
--- shop's data now: Core's goods, their cache, the Modules On, the balance and whether a projection is updating
--- (logic/Shop.lua). Opening while restricted prints "Pagle: the Curio Shop opens after combat." and opens nothing; at
--- RestrictionChanged(true) an open shop closes, its bill of sale with it, and nothing is queued. Returns
--- Pagle.OpenShop.
---@param host PagleHost
---@param seams PagleShopSeams
---@return fun(goodID: string?) openShop
function ns.WireShop(host, seams)
	--- The shop's model now; `format` writes a number of Coins (BreakUpLargeNumbers).
	---@param format (fun(value: number): string)?
	---@return PagleShopModel
	function ns.ShopModel(format)
		local db = host.db()
		return ns.NewShopModel({
			goods = ns.goods,
			cache = db and db.global.goods or {},
			modules = host.registry:Modules(),
			balance = ns.wallet:Get(),
			updating = ns.projections:IsUpdating(),
			format = format,
		})
	end

	--- Buys `goodID` if Buy is enabled for it now (SHOP-R13), checked again at the confirm: appends one purchase entry
	--- with its ID and its price now, the purchase entry's only caller (LOG-R39, SHOP-R10), which the wallet projection
	--- applies live, so the balance drops and the good is owned at once; then, with `useNow`, equips it (SHOP-R32). One
	--- good, one confirmation; no Announcement and no summary line follow (ANN-R23). Returns whether it bought.
	---@param goodID string
	---@param useNow boolean
	---@return boolean
	local function buy(goodID, useNow)
		local purchase = ns.ShopModel():Purchase(goodID)
		if not purchase then
			return false
		end
		ns.RecordPurchase(purchase.id, purchase.price)
		if useNow then
			ns.goods:SetEquipped(purchase.slot, purchase.id)
		end
		return true
	end

	--- Equips `goodID` in its slot, if it is an owned good registered this session (SHOP-R32): the stage's Use.
	--- Returns whether it did; AppearanceChanged follows if the look changed (SHOP-R33).
	---@param goodID string
	---@return boolean
	local function use(goodID)
		local good = ns.goods:Good(goodID)
		return good ~= nil and ns.goods:SetEquipped(good.slot, good.id)
	end

	---@param goodID string?
	local function open(goodID)
		if host.isRestricted() then
			host.print(ns.L.SHOP_AFTER_COMBAT)
			return
		end
		local selection
		if goodID ~= nil then
			selection = ns.ShopModel():Select(goodID) or false
		end
		seams.show(selection, goodID)
	end
	local function toggle()
		if seams.isShown() then
			seams.hide()
		else
			open()
		end
	end
	ns.shop = { Open = open, Toggle = toggle, Buy = buy, Use = use }
	-- CORE-R33's row, SHOP-R41: an open shop closes as restriction starts. Its own owner on the bus.
	host.listen("Pagle shop", "RestrictionChanged", function(_, isRestricted)
		if isRestricted and seams.isShown() then
			seams.hide()
		end
	end)
	return open
end

--- Where the tracker dock is drawn: adapter/Dock.lua's anchor frame on the client, or FakePagle's record of it.
---@class PagleDockView
---@field watch fun(tracker: PagleTracker)       -- a tracker docked: reflow as its frame shows, hides or resizes, and
--- move the dock on a Shift-drag of it
---@field reflow fun()                           -- lays the stack out again (ns.dock:Layout)
---@field place fun(point: PagleDockPoint)       -- puts the dock's anchor at `point`
---@field stopMoving fun(): PagleDockPoint?      -- ends a drag in progress where the dock is now, returning that point
--- to save; nil with none in progress

--- The tracker dock (CORE-R70–R72) as ns.dock (ns.WireDock).
---@class PagleDockWiring
---@field package host PagleHost
---@field package view PagleDockView
---@field package trackers PagleDock
local DockWiring = {}
DockWiring.__index = DockWiring

-- PagleDB.profile.dock: its default is in PAGLEDB_DEFAULTS (logic/Migrations.lua).
---@param wiring PagleDockWiring
---@return { point: PagleDockPoint? }
local function storedDock(wiring)
	return wiring.host.db().profile.dock
end

--- The docked trackers, in stack order (CORE-R70).
---@return PagleTracker[]
function DockWiring:Trackers()
	return self.trackers:Trackers()
end

--- The stack now (CORE-R70, CORE-R72), each docked frame read as it is now: see PagleDock:Layout.
---@return PagleDockLayout
function DockWiring:Layout()
	return self.trackers:Layout()
end

--- Where the anchor goes now: dock.point, or under the minimap (CORE-R70, CORE-R71).
---@return PagleDockPoint
function DockWiring:Anchor()
	return ns.DockAnchor(storedDock(self).point)
end

--- Whether a Shift-drag may move the dock: never while restricted (CORE-R71).
---@return boolean
function DockWiring:CanMove()
	return not self.host.isRestricted()
end

--- The player dropped the dock at `point`: saved to dock.point, relative to UIParent (core/README.md › Data).
---@param point PagleDockPoint
function DockWiring:Moved(point)
	storedDock(self).point = {
		point = point.point,
		relativeTo = "UIParent",
		relativePoint = point.relativePoint,
		x = point.x,
		y = point.y,
	}
end

--- A whole Shift-drag, dropped with the dock at `point` (CORE-R71): saved as Moved saves it, unless restricted. True
--- when it moved.
---@param point PagleDockPoint
---@return boolean
function DockWiring:Drop(point)
	if not self:CanMove() then
		return false
	end
	self:Moved(point)
	return true
end

--- The Trackers page's Reset (SET-R40): clears dock.point and puts the dock back under the minimap. While restricted
--- it does nothing (CORE-R71). True when it did.
---@return boolean
function DockWiring:Reset()
	if self.host.isRestricted() then
		return false
	end
	storedDock(self).point = nil
	self.view.place(self:Anchor())
	return true
end

--- The tracker dock (CORE-R70–R72) as ns.dock, over PagleDB.profile.dock (core/README.md › Data), and
--- `M:RegisterTracker` on every Module handle. The anchor is placed at ModulesChanged, at dock.point or under the
--- minimap; each docked tracker is watched and the stack reflowed. A drag in progress when restriction starts stops
--- where it is and is saved.
---@param host PagleHost
---@param view PagleDockView
function ns.WireDock(host, view)
	local trackers = ns.NewDock()
	---@type PagleDockWiring
	local dock = setmetatable({ host = host, view = view, trackers = trackers }, DockWiring)
	ns.dock = dock

	-- Its own owner on the bus. CORE-R19: every enabled Module has registered, so every tracker is in.
	host.listen("Pagle dock", "ModulesChanged", function()
		view.place(dock:Anchor())
		view.reflow()
	end)
	-- CORE-R71: the dock never moves while restricted.
	host.listen("Pagle dock", "RestrictionChanged", function(_, isRestricted)
		if isRestricted then
			local point = view.stopMoving()
			if point then
				dock:Moved(point)
			end
		end
	end)

	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Docks the Module's tracker frame (CORE-R70): `{ id, order, frame }`. The dock stacks the visible docked frames
	--- top to bottom by order (Hunts 10, Stats 20, Tackle Board 30; ties by Module name), 8 px apart, under the
	--- minimap, and reflows as one shows, hides or resizes; the Module shows and hides its own (CORE-R72). Raises an
	--- error at the Module's call, docking nothing, for a missing or non-string id, a non-number order, no frame, or an
	--- id already docked.
	---@param tracker { id: string, order: number, frame: table }
	function ModuleHandle:RegisterTracker(tracker)
		local module = host.registry:ModuleCalling(self, "RegisterTracker", "{ id, order, frame }")
		local docked, problem = trackers:Add(module.def.name, tracker)
		if not docked then
			error(problem, 2)
		end
		view.watch(docked)
		view.reflow()
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

--- Core's wallet projection (LOG-R78, SHOP-R11, SHOP-R34): `ns.StartWalletProjection()` binds it at login step 1,
--- after the Field report's and ahead of every Module's, to PagleDB.global.projections.wallet (ns.PAGLEDB_DEFAULTS),
--- over the log's records. It hands ns.wallet the Coins spent and ns.goods the purchased set: what it stored at
--- once, its new totals in its done, and each live purchase as it counts.
---@param host PagleHost
function ns.WireWalletProjection(host)
	--- Login step 1, once PagleDB is open and ns.wallet and ns.goods are wired.
	function ns.StartWalletProjection()
		ns.walletProjection = ns.AddWalletProjection({
			projections = ns.projections,
			db = host.db().global.projections.wallet,
			iterate = host.iterate,
			wallet = ns.wallet,
			goods = ns.goods,
		})
	end
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
--- `preview` hands its samples to `show`, the display (as ns.WireMoments' is), and its card to ns.cards; `glyphs`
--- hands its probe line to `showGlyphs` (#248). `tour` runs ns.tour over ns.tourStops, Core's one registry of tour
--- stops, which `M:RegisterTourStop` on every Module handle adds to (CORE-R65–R68). `probe` saves the client facts
--- launch re-verification needs in PagleDB.global.probe (#261, logic/Probe.lua), reading each API it tests from
--- `globals`.
---@param host PagleHost
---@param show fun(announcement: PagleAnnouncement) hands an Announcement to the display (ANN-R20)
---@param showGlyphs fun(fonts: PagleDevGlyphFont[], probe: string) shows the probe line in each font
---@param tour PagleTourSeams what the tour reads from where Core runs
---@param globals fun(): table the client's globals (_G), where `/pagle dev probe` looks up each API it tests (#261)
function ns.WireDev(host, show, showGlyphs, tour, globals)
	--- The Fishing channels seen while dev mode is on, for `/pagle dev probe`'s check 21 (LOG-R2): Core's fishing
	--- adapter notes each player channel here.
	ns.probeChannels = ns.NewProbeChannels()
	ns.tourStops = ns.NewTourStops()
	ns.tour = ns.NewTour({
		stops = ns.tourStops,
		modules = function()
			return host.registry:Modules()
		end,
		isRestricted = tour.isRestricted,
		canScreenshot = tour.canScreenshot,
		screenshot = tour.screenshot,
		after = host.after,
		call = host.call,
		clock = tour.clock,
		print = host.print,
	})
	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Registers one of the Module's tour stops for `/pagle dev tour` (CORE-R65): `show` puts a surface on screen in a
	--- representative state, `hide` puts back everything show changed. The stop is named `<module>.<id>`, the Module's
	--- name lowercased ("ledger.journal.home"), and tours in the order registered. Raises an error at the Module's
	--- call, adding nothing, for an ID that isn't [%w_.]+ or that the Module registered before, no label, or a show or
	--- hide that isn't a function. A Module calls it only `if M.RegisterTourStop then`, so it runs on a Core without it.
	ModuleHandle.RegisterTourStop = ns.RegisterTourStopMethod(host.registry, ns.tourStops)
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
		showGlyphs = showGlyphs,
		tour = function(args)
			ns.tour:Run(args)
		end,
		onboarding = function(args)
			ns.onboarding:RunDev(args)
		end,
		probe = function()
			ns.RunProbe({
				globals = globals,
				global = function()
					return host.db().global
				end,
				facts = function()
					return {
						inventory = ns.API_INVENTORY,
						fishingSpells = ns.Catalogue.GetFishingSpells(),
						channels = ns.probeChannels:List(ns.IsFishingChannel),
						sizeHash = ns.SizeHash,
						sizeBand = function(catchId)
							return ns.SimulatedSize(catchId, 300).band
						end,
						isForever = ns.IsForever,
					}
				end,
				after = host.after,
				print = host.print,
			})
		end,
		print = host.print,
	})
end

--- Core's onboarding (core/onboarding.md) as ns.onboarding, over PagleDB.global.onboarding, with `/pagle dev
--- onboarding reset` (ONB-R83) in its dev group, and ns.StartOnboarding, login step 2's part (ONB-R1–R3). The
--- migration adds the state at login step 1 (logic/Migrations.lua); later pieces add their own hooks (SetHook), the
--- guide's opener (SetGuideOpener) and dev subcommands (AddDevCommand).
---@param host PagleHost
function ns.WireOnboarding(host)
	local onboarding = ns.NewOnboarding({
		global = function()
			return host.db().global
		end,
		call = host.call,
		print = host.print,
	})
	ns.onboarding = onboarding

	-- The logged-in character's GUID (LOG-R25, LOG-R26); nil before PLAYER_LOGIN, or without a GUID to key it by.
	---@return string?
	local function guid()
		local char = host.character()
		local character = char and host.catchLog().data.characters[char]
		return character and character.guid
	end

	-- Whether QoL is registered (ONB-R3, ONB-R101).
	---@return boolean
	local function qolRegistered()
		for _, module in ipairs(host.registry:Modules()) do
			if module.def.name == "QoL" then
				return true
			end
		end
		return false
	end

	--- Login step 2, after ModulesChanged (LOG-R1): adds the state for a PagleDB that lost it since its migration
	--- (ONB-R1), adds the logged-in character, raising the `character` hook for another one while QoL is registered
	--- (ONB-R3), and waits for a returning Angler's welcome (ONB-R2): the first SessionStarted or
	--- ONBOARDING_WELCOME_DELAY s from now, whichever comes first, raises the `welcome` hook, once.
	function ns.StartOnboarding()
		ns.AddOnboarding(host.db().global, host.catchLog())
		onboarding:SeeCharacter(guid(), qolRegistered())
		local due = true
		local function welcome()
			if due then
				due = false
				onboarding:Welcome()
			end
		end
		host.after(ns.ONBOARDING_WELCOME_DELAY, welcome)
		-- Its own owner on the bus, so no other registration replaces it.
		host.listen("Pagle onboarding", "SessionStarted", welcome)
	end

	onboarding:AddDevCommand("reset", "reset", function()
		local current = guid()
		if not current then
			host.print(ns.L.DEV_NO_CHARACTER)
			return
		end
		onboarding:Reset(current)
		host.print(ns.L.DEV_ONBOARDING_RESET)
	end)
end

--- What the Field guide's wiring needs from where Core runs, beyond the host: Core's adapter passes the book and the
--- Announcement lanes' hold (adapter/Guide.lua), FakePagle its records.
---@class PagleGuideWiringView: PagleGuideView
---@field hold fun(reason: string)    -- ns.HoldAnnouncements (ANN-R38)
---@field release fun(reason: string) -- ns.ReleaseAnnouncements
---@field coreSteps table<string, PagleCoreGuideStepDrawing> -- what draws each of Core's own steps, by id (ONB-R21)

--- The Field guide (core/onboarding.md › The Field guide) as ns.guide over ns.guideSteps, with `M:RegisterGuideStep`
--- on every Module handle and ns.RegisterCoreGuideStep, which registers Core's own four steps here, drawn by
--- `view.coreSteps` (ONB-R21, ONB-R90). At ModulesChanged the
--- registry closes; ns.AddGuideTourStops gives each step its tour stop (ONB-R84); RestrictionChanged closes
--- and reopens the guide (ONB-R25); `/pagle guide` opens it (ONB-R80), and `/pagle dev onboarding step <id>` opens it
--- at a step (ONB-R83). Call it after ns.WireOnboarding and ns.WireDev.
---@param host PagleHost
---@param view PagleGuideWiringView
function ns.WireGuide(host, view)
	local steps = ns.NewGuideSteps()
	ns.guideSteps = steps
	local guide = ns.NewGuide({
		steps = steps,
		onboarding = function()
			return ns.onboarding
		end,
		isRestricted = host.isRestricted,
		view = view,
		hold = view.hold,
		release = view.release,
		fire = host.fire,
		call = host.call,
		print = host.print,
	})
	ns.guide = guide

	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Adds one of the Module's steps to the Field guide (ONB-R21): call it in OnInitialize, before ModulesChanged, and
	--- only `if M.RegisterGuideStep then`, so it runs on a Core without it (ONB-R90). Raises an error at the Module's
	--- call, adding nothing, for a missing or mistyped field or an id registered before (ns.GuideStepProblem); a call
	--- after ModulesChanged goes to geterrorhandler() and is dropped.
	---@param step PagleGuideStep
	function ModuleHandle:RegisterGuideStep(step)
		local module = host.registry:ModuleCalling(self, "RegisterGuideStep", "step")
		local problem, late = steps:Add(module.def.name, step)
		if problem and late then
			host.report(problem)
		elseif problem then
			error(problem, 2)
		end
	end

	--- Adds one of Core's own steps (ONB-R21), which may use Core's own fields (PagleGuideStep). Raises an error at
	--- Core's call, adding nothing, for a mistake.
	---@param step PagleGuideStep
	function ns.RegisterCoreGuideStep(step)
		local problem = steps:Add(ns.CORE_OWNER, step)
		if problem then
			error(problem, 2)
		end
	end

	for _, step in ipairs(ns.CoreGuideSteps(view.coreSteps)) do
		ns.RegisterCoreGuideStep(step)
	end

	-- CORE-R19: every enabled Module has registered its steps, or failed to. Its own owner on the bus.
	host.listen("Pagle guide", "ModulesChanged", function()
		steps:Close()
	end)

	--- Adds a tour stop per registered step to ns.tourStops (ONB-R84, CORE-R65): `core.onboarding.step.<id>`, which
	--- shows the guide at that step without writing guideStep or stepsSeen, and whose hide puts the guide back as it was
	--- (CORE-R68). Core's adapter calls it at ModulesChanged, once every step is in; FakePagle doesn't, so a Module's
	--- tour spec sees only its own stops.
	function ns.AddGuideTourStops()
		for _, entry in ipairs(steps:List()) do
			local id = entry.step.id
			local problem = ns.tourStops:Add(
				ns.TOUR_CORE,
				"onboarding.step." .. id,
				ns.L.DEV_TOUR_GUIDE_STEP:format(id),
				function()
					guide:TourShow(id)
				end,
				function()
					guide:TourHide()
				end
			)
			if problem then
				host.report(problem)
			end
		end
	end
	host.listen("Pagle guide", "RestrictionChanged", function(_, isRestricted)
		guide:RestrictionChanged(isRestricted)
	end)

	ns.onboarding:SetGuideOpener(function()
		guide:Open()
	end)
	ns.onboarding:AddDevCommand("step", "step <id>", function(args)
		local id = args:match("^%s*(%S*)")
		if steps:Index(id) then
			guide:Open(id)
			return
		end
		local ids = {}
		for i, entry in ipairs(steps:List()) do
			ids[i] = entry.step.id
		end
		host.print(ns.L.DEV_GUIDE_NO_STEP:format(id ~= "" and id or "<id>", table.concat(ids, ", ")))
	end)
end

--- What Margin notes' wiring needs from where Core runs, beyond the host: Core's adapter draws the notes
--- (adapter/MarginNotes.lua), FakePagle records them.
---@class PagleMarginNotesWiringView: PagleMarginNotesView
---@field coreTarget fun(key: "nod"|"coin"|"card"|"menu"): PagleNoteTarget? -- what a Core note points at on screen
--- now, resolved each time it's read; nil when nothing it could point at shows. `menu` is Pagle's menu button: the
--- minimap icon while it shows, else the Addon Compartment's button (ONB-R52, ONB-R108).
---@field isUncharted fun(itemID: integer): boolean -- no catalogue has the item (LOG-R55)

--- Core's Margin notes (core/onboarding.md › Margin notes) as ns.marginNotes, with `M:ShowMarginNote` on every Module
--- handle (ONB-R90, ONB-R92), the onboarding hooks' notes, `core.welcome` and `core.character` on Pagle's menu button
--- (ONB-R2, ONB-R3), RestrictionChanged's hold (ONB-R51), and `/pagle dev onboarding note <id>` (ONB-R83). Each live
--- caught Cast with an Uncharted Catch is noted, so its Nod shows `core.uncharted` (ONB-R52): Core's adapter hands
--- what shows to ns.marginNotes:AnnouncementShown and :CardShown. Call it after ns.WireOnboarding.
---@param host PagleHost
---@param view PagleMarginNotesWiringView
function ns.WireMarginNotes(host, view)
	local notes = ns.NewMarginNotes({
		onboarding = function()
			return ns.onboarding
		end,
		isRestricted = host.isRestricted,
		after = host.after,
		view = view,
	})
	ns.marginNotes = notes

	-- Each Module note shown this login, by id, for /pagle dev onboarding note (ONB-R83).
	---@type table<string, PagleMarginNote>
	local known = {}

	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle
	--- Shows one of the Module's Margin notes beside its target (ONB-R50–R52): once per account, never with Margin
	--- notes off, waiting out a restriction (ONB-R51). A Module calls it only `if M.ShowMarginNote then`, so it runs on
	--- a Core without it (ONB-R90). Raises an error at the Module's call, showing nothing, for a missing or mistyped
	--- field (ns.MarginNoteProblem). Core keeps a copy, so a later change to the Module's table changes nothing.
	---@param note PagleMarginNote
	function ModuleHandle:ShowMarginNote(note)
		local module = host.registry:ModuleCalling(self, "ShowMarginNote", "note")
		local problem = ns.MarginNoteProblem(note, module.def.name)
		if problem then
			error(problem, 2)
		end
		local copy = { id = note.id, text = note.text, target = note.target, side = note.side }
		known[copy.id] = copy
		notes:Show(copy)
	end

	-- One of Core's notes on its target now, shown as ONB-R50 has it; nothing while its target can't be found.
	---@param id string
	local function showCore(id)
		local target = view.coreTarget(ns.CORE_MARGIN_NOTES[id].target)
		if target then
			notes:Show(ns.CoreMarginNote(id, target))
		end
	end
	-- ONB-R2, ONB-R3: Onboarding raises these; ShowMarginNote's checks decide whether the note shows.
	ns.onboarding:SetHook("welcome", function()
		showCore("core.welcome")
	end)
	ns.onboarding:SetHook("character", function()
		showCore("core.character")
	end)

	-- Its own owner on the bus, so no other registration replaces these.
	local owner = "Pagle margin notes"
	host.listen(owner, "RestrictionChanged", function(_, isRestricted)
		notes:RestrictionChanged(isRestricted)
	end)
	-- The live Casts that caught an Uncharted item (LOG-R55), whose Nod shows core.uncharted (ONB-R52).
	---@type table<string, true>
	local uncharted = {}
	host.listen(owner, "CastEnded", function(_, outcome, cast)
		if outcome ~= "caught" or not cast then
			return
		end
		local n = 1
		while cast.items[n] do
			local itemID = cast.items[n].itemID
			if itemID ~= 0 and view.isUncharted(itemID) then
				uncharted[cast.id] = true
				return
			end
			n = n + 1
		end
	end)

	--- Whether an Announcement's Cast caught an Uncharted item (ONB-R52).
	---@param announcement PagleAnnouncement
	---@return boolean
	function ns.IsUnchartedAnnouncement(announcement)
		return announcement.cast ~= nil and uncharted[announcement.cast] == true
	end

	ns.onboarding:AddDevCommand("note", "note <id>", function(args)
		local id = args:match("^%s*(%S*)")
		local core = ns.CORE_MARGIN_NOTES[id]
		local note
		if core then
			local target = view.coreTarget(core.target)
			note = target and ns.CoreMarginNote(id, target)
		else
			note = known[id]
			if not note then
				local ids = {}
				for coreId in pairs(ns.CORE_MARGIN_NOTES) do
					ids[#ids + 1] = coreId
				end
				for moduleId in pairs(known) do
					ids[#ids + 1] = moduleId
				end
				table.sort(ids)
				host.print(ns.L.DEV_NOTE_NONE:format(id ~= "" and id or "<id>", table.concat(ids, ", ")))
				return
			end
		end
		if not note or not view.isShown(note) then
			host.print(ns.L.DEV_NOTE_NO_TARGET:format(id))
			return
		end
		notes:ShowNow(note)
	end)
end
