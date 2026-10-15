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
---@field iterate fun(afterSeq: integer?): fun(): PagleRecord? -- the log's records after a seq (Pagle.IterateCatches)
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
---@field fieldReport PagleFieldReportReaders? Core's Field report, from login step 1 on (ns.WireFieldReport).
---@field walletProjection PagleProjection? Core's wallet projection, from login step 1 (ns.WireWalletProjection).
---@field LengthUnit fun(): PagleLengthUnit The Angler's length unit now (ns.WireLength).
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
	--- The Size bands in order, `{ key, name }`, Tiddler to Monster (LOG-R67). The names are drafts for the lore pass.
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
--- and its one way to spend Coins, which the Buy popup's confirm calls (SHOP-R13, LOG-R39).
---@class PagleShop
---@field Open fun(goodID: string?) -- Pagle.OpenShop
---@field Toggle fun()              -- /pagle shop
---@field Buy fun(goodID: string, useNow: boolean): boolean -- the Buy popup's Buy: true if it bought
---@field Use fun(goodID: string): boolean -- the stage's Use: true if it equipped the good

--- The Curio Shop's entry points as ns.shop (SHOP-R40, SHOP-R41), its buying (ns.shop.Buy), and ns.ShopModel, the
--- shop's data now: Core's goods, their cache, the Modules On, the balance and whether a projection is updating
--- (logic/Shop.lua). Opening while restricted prints "Pagle: the Curio Shop opens after combat." and opens nothing; at
--- RestrictionChanged(true) an open shop closes, its Buy popup with it, and nothing is queued. Returns
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
--- hands its probe line to `showGlyphs` (#248).
---@param host PagleHost
---@param show fun(announcement: PagleAnnouncement) hands an Announcement to the display (ANN-R20)
---@param showGlyphs fun(fonts: PagleDevGlyphFont[], probe: string) shows the probe line in each font
function ns.WireDev(host, show, showGlyphs)
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
		print = host.print,
	})
end
