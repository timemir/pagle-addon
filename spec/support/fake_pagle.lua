-- FakePagle (CORE-R18): the Core test double Module specs run against, so a Module is specced without Core's
-- adapter, the WoW client or SavedVariables. spec/support/addon.lua loads this file, so busted's helper defines
-- newFakePagle for every spec.
--
--   local fake = newFakePagle()
--   local loaded = fake.load("Pagle_QoL")                 -- the Module sees fake.globals.Pagle as its Pagle
--   fake.login()                                            -- Core's PLAYER_LOGIN: the character, ModulesChanged
--   fake.enterWorld()                                       -- login step 3: every projection catches up or rebuilds
--   fake.fire("RestrictionChanged", true)                   -- any Core event; tables arrive read-only
--   fake.setRestricted(true)
--   fake.playCast("caught", { { itemID = 6358, quantity = 1 } }) -- CastStarted … Catch, CastEnded (LOG-R9)
--   fake.nextFrame()                                        -- the frame after: the Cast's moments are one Announcement
--   fake.announcements[1].headline.title                    -- what Core would show (also .stamps, .more, .coins)
--
-- A Module raises moments only for what is worth one: an ordinary Catch raises nothing and never pops up (ANN-R13),
-- so a Module spec playing an ordinary Cast expects fake.announcements to stay empty.
--
-- It is built on Core's real logic/: each FakePagle loads Pagle.toc's data/, locale/ and logic/ files (and the
-- CallbackHandler bus) afresh, so what it validates, computes and refuses is what Core does. Core's projections,
-- Sessions, moments, Session summary, cards and wallet are built and connected by logic/Wiring.lua, which Core's
-- adapter runs too: the fake hands it a host over its fakes where Core's adapter hands it the client (adapter/Host.lua).
-- Only the client is faked.
--
-- Records Core hands to Modules are shared and immutable (CORE-R18). FakePagle hands out read-only proxies
-- instead, which raise an error on any write, so a Module that writes to one fails its spec. Lua 5.1 can't make a
-- proxy behave fully like its record: `#proxy` is 0, and the stock pairs, ipairs, next and unpack see an empty table.
-- fake.globals replaces those four with proxy-aware ones for Module code loaded with it; a spec that walks a record
-- itself uses fake.globals.pairs and friends.
--
-- Extending it: each Core ticket that adds a Pagle call or a Module handle method adds a part (see `part` below)
-- that fakes it, specced in spec/support/fake_pagle_spec.lua against the rule Core follows. Glue between Core's
-- parts goes in a logic/ factory both call (logic/Wiring.lua), never in a copy here.

--- A fresh Core double. Every field is the spec's to read; `addons` and `Pagle` are also the spec's to change.
---@class FakePagle
---@field Pagle table The Pagle API Core publishes. Specs may stub on it; Modules see it read-only via `globals`.
---@field globals table<string, any> Globals for `loadAddon` when it loads a Module: `Pagle` (read-only) and the
--- proxy-aware `pairs`, `ipairs`, `next` and `unpack`.
---@field ns table Core's logic/ (with `ns.L` and `ns.catalogue`), loaded for this fake alone.
---@field registry PagleModuleRegistry Core's real Module registry; `registry:ModuleOf(handle)` finds a Module.
---@field addons table<string, FakeAddOn> The roster Modules' addons by folder name, as the client reports them.
--- By default each is installed, enabled, loaded and declares `X-Pagle-API` = API_VERSION. Set one to nil to
--- uninstall it.
---@field printed string[] Each chat line Core printed, in order.
---@field fire fun(event: string, ...) Fires a Core event on the bus, each table in the payload read-only.
---@field fireGameEvent fun(event: string, ...) Calls the handlers registered with Pagle.RegisterEvent or
--- RegisterUnitEvent for a WoW event, as the client would fire it. A unit event reaches only its unit's handlers.
---@field setRestricted fun(isRestricted: boolean) Sets the restriction state; RestrictionChanged fires on a change.
---@field login fun() Does Core's PLAYER_LOGIN work: adds the character (PLAYER_GUID) to the Angler, then fires
--- ModulesChanged. Raises an error if called twice. The log's length then is loginSeq (LOG-R1): what the spec
--- appended to fake.catchLog before it is history, and anything after it reaches projections live.
---@field enterWorld fun() Login step 3 at the first PLAYER_ENTERING_WORLD (LOG-R1): starts every projection's
--- catch-up or rebuild (LOG-R71, LOG-R72) and runs it to the end at once, then its done and the live entries queued
--- behind it. Raises an error before login or a second time.
---@field projections PagleProjections Core's real projection machinery, with its seams: IsUpdating, Mode,
--- WhenIdle and Live.
---@field live fun(record: PagleRecord) Hands an entry the spec appended to fake.catchLog to the projections, as Core
--- does with every entry it appends (LOG-R73); playCast and readSkill do it themselves.
---@field prestige fun(): PaglePrestige What M:RecordPrestige() does, without a Module handle (LOG-R38): appends a P1
--- for the logged-in character, one rank above the Prestiges in fake.catchLog, applies it live, then fires Prestige.
--- Returns the record, read-only. Raises an error before login. A purchase is Core's own: fake.ns.RecordPurchase
--- (LOG-R39). A spec puts either in a history with fake.catchLog:Append, or in a saved log with helpers.lua's
--- prestigeEntry and purchaseEntry.
---@field readSkill fun(rank: integer, max: integer, mod: integer) Reads fishing skill as Core does after login: an
--- S1 when rank or max changed, then SkillChanged; then fake.conditions takes the rank and modifier, firing
--- ConditionsChanged({"skill"}) if either changed. Does nothing before login.
---@field readOnly fun(value: any): any The read-only proxy of a table (the same one each time); other values as is.
---@field moduleState fun(name: string): PagleModuleState A roster Module's state (CORE-R41).
---@field settingsPage fun(topic: string): { module: string, kind: string, label: string, indented: boolean, setting: PagleSetting }[]?
--- The rows Core would put on a topic page, in order, its header rows included; nil before login or with no rows,
--- when Core registers no page (CORE-R42).
---@field reported string[] Each error Core reported through geterrorhandler(), e.g. a late M:AddSetting, a
--- Module function that raised under securecallfunction, or a moment dropped in a replay or rebuild (ANN-R4). A
--- spec that gets one must read this list (assert it), or it fails at its end (spec/support/errors.lua).
---@field print fun(line: string) What Core's print does: adds a chat line to `printed`.
---@field report fun(err: any) What Core's geterrorhandler() does: adds the error to `reported`.
---@field securecall fun(fn: function, ...: any): ... What Core's securecallfunction does: runs `fn`; on an error,
--- reports it and returns nothing.
---@field openedSettings string[] What each Pagle.OpenSettings opened: "root" or the topic (CORE-R43).
---@field menu fun(): PagleMenuEntry[] The compartment menu as it would open now, labels read (CORE-R50, CORE-R52);
--- each entry's onClick is what clicking it does. Its last three entries are the Curio Shop (disabled), "Help chart
--- the waters" (with " (N)" while Pagle.GetFieldReportCount() is above 0; it calls Pagle.OpenFieldReport) and Settings.
---@field coinReports { module: string, total: integer }[] Each M:ReportCoinsEarned Core accepted, in order, an
--- unchanged total too (SHOP-R2).
---@field setSpent fun(spent: integer) Sets the Coins spent, as the Curio Shop will (M4): BalanceChanged fires if the
--- balance or held changes (SHOP-R12).
---@field goods table<string, table> PagleDB.global.goods, the goods cache (SHOP-R26), the same table as
--- fake.global.goods: every good registered, by ID, with name, slot, slotLabel, category, module, icon, default, tier,
--- description and, for an earned good, `earned` (isEarned()'s result at registration or the last M:RefreshGoods).
--- A spec may fill it before login, as a saved PagleDB, for goods of a Module that isn't loaded (SHOP-R90).
---@field setPurchased fun(purchased: table<string, true>) Hands Core the purchased goods, `{ [goodID] = true }`, as
--- the wallet projection does (SHOP-R11); empty until then. AppearanceChanged fires if a look changes (SHOP-R33).
---@field shopsOpened { goodID: string? }[] Each Pagle.OpenShop(goodID?) call, in order, with the good it asked for
--- (SHOP-R40). The fake has no Curio Shop: it only records.
---@field announcements PagleAnnouncement[] Each Announcement Core would hand the display, in order (ANN-R11): its
--- headline, rung, stamps (at most 4), more ("+N"), coins and every moment, ranked. One per Cast, made on the frame
--- after its moments were raised, or after the last projection finishes (ANN-R10); one per moment without a Cast.
---@field summarized PagleRaisedMoment[] Each moment Core kept, as it was raised, shown or not (ANN-R25): a
--- summaryOnly one is here and never in announcements. A moment Core dropped (ANN-R4) is in neither.
---@field global table PagleDB.global, the one the fake's Core keeps all its keys in, from Core's defaults
--- (ns.PAGLEDB_DEFAULTS): `coins.earned`, each Module's last reported total by def.name (SHOP-R3);
--- `lastEndedSession` (LOG-R63); and the Session summary keys (announcements.md › Data): `summary` (the open
--- Session's moments and every Module's M:SetSummaryLine lines), `pending` (moments raised with no Session open,
--- ANN-R52), `cards` (each SessionEnded's card for a Session that raised a moment, ANN-R53, at most 3, ANN-R54) and
--- `writeUp` (the Write-up sections waiting, ANN-R61). A spec may seed its keys before login, as a saved PagleDB.
---@field profile table PagleDB.profile, from Core's defaults: `announcements.cozy` is Cozy mode (ANN-R62), off; a
--- spec may set it. `appearance` holds each slot's pick, `{ [slot] = goodID }` (SHOP-R32), which Pagle.SetEquipped
--- writes and a spec may seed.
---@field writeUps PagleWriteUpStored[] Each Write-up section Core kept from a Module's M:RaiseWriteUp, in order, as
--- stored: module, order, title, heading, lines (ANN-R60). Closing the Write-up card doesn't empty it.
---@field cardsShown PagleCard[] Each card Core would show, in order (ANN-R21): the Write-up (title "Write-up" and
--- writeUp, its sections by Module order) before the stored Session cards, oldest first, one at a time. None shows
--- before the second fake.nextFrame after the projections are idle (enterWorld).
---@field closeCard fun() The player closes the card on screen (the last in cardsShown): it leaves global.cards, or
--- the Write-up's sections leave global.writeUp, and the next card shows (ANN-R54, ANN-R61).
---@field nextFrame fun() Runs the next frame: what Core queued for it so far, such as flushing moments into
--- fake.announcements (ANN-R10, ANN-R12).
---@field queueFrame fun(step: fun()) Queues a step for the next fake.nextFrame; the parts' own frame scheduler.
---@field slash fun(line: string) Types `/pagle <line>` (CORE-R60–R62); help lines go to `printed`.
---@field load fun(name: string, options: table?): LoadedAddon Loads a Module with `loadAddon` against this fake:
--- `globals`, and of Pagle.toc only the vendored libs/ the Module reaches through LibStub (CORE-R6). Options as
--- loadAddon's. WoW events its client raises on its own (`client.fireGameEvent`) go to `fake.fireGameEvent`.
---@field catchLog PagleCatchLog The Catch log Pagle.IterateCatches reads, on Core's real codec; empty at first.
---@field setCatalogue fun(data: table) Serves the catalogue calls over `data` (shaped as ns.catalogue, DATA-R76)
--- instead of the generated catalogue.
---@field diagnostics PagleDiagnostic[] PagleDB.global.diagnostics (LOG-R81): empty, and playCast adds nothing; a spec
--- adds entries for the P rows Pagle.GetFieldReportCount counts (REP-R22).
---@field fieldReportDB table PagleDB.global.projections.fieldReport (REP-R25); a spec may fill it before enterWorld,
--- as a saved one.
---@field setFieldReportCount fun(n: integer?) Makes Pagle.GetFieldReportCount return `n`, whatever the rows; nil goes
--- back to the count Core's projection gives (REP-R26).
---@field fieldReportsOpened PagleFieldReportView[] Each box Pagle.OpenFieldReport opened, in order: its message
--- (REP-R41, REP-R42), or its parts and the issue form's URL (REP-R40). While restricted it opens none and prints
--- REP-R44's line in `printed`.
---@field conditions ConditionsSnapshot The live conditions Pagle.GetConditions serves (without `restricted`, which
--- follows setRestricted). Read it; change it with setConditions.
---@field setConditions fun(snapshot: ConditionsSnapshot) Replaces the live conditions and fires ConditionsChanged
--- with the keys that changed, if any (LOG-R47).
---@field playCast fun(outcome: "caught"|"gotAway"|"interrupted", items: PagleLootItem[]?): PagleCast? Plays a whole
--- Cast's signals: a fishing channel, then its loot (`items`, as `{ itemID, quantity }`), LOOT_CLOSED and the
--- channel stopping; or the escaped message; or the channel stopping and the grace time passing. Returns the Cast
--- recorded (read-only), nil when interrupted or before login.
---@field channel fun(spellID: integer?) The player's channel starts (LOG-R2); Fishing (7731) by default.
---@field stopChannel fun(spellID: integer?) The player's channel stops; its grace time starts (LOG-R7).
---@field loot fun(items: PagleLootItem[]?, isFishing: boolean?) LOOT_READY with these items; fishing loot by default.
---@field closeLoot fun() LOOT_CLOSED.
---@field escape fun() The game reports the fish escaped (LOG-R6).
---@field wait fun(seconds: number) Moves the fake's clock on, running each grace timer that comes due, and ending
--- the Session 900 s after its last Cast (LOG-R62).
---@field serverTime fun(): integer The fake's server time: SERVER_TIME plus its clock, in whole seconds.
---@field compartmentText fun(): string The compartment entry's label as it reads now (CORE-R51): "Pagle", or with
--- moments kept while Cozy mode was on and no Session summary card shown since, "Pagle · 2 waiting" (ANN-R42).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newSecureCall = dofile("spec/support/securecall.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newClock = dofile("spec/support/timers.lua").newClock

-- A copy of a conditions snapshot, to change without changing the one it came from.
---@param conditions table
---@return table
local function copyConditions(conditions)
	local copy = {}
	for key, value in pairs(conditions) do
		copy[key] = value
	end
	return copy
end

-- A deep copy of a table of plain values.
---@param source table
---@return table
local function copyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and copyTable(value) or value
	end
	return copy
end

--- FakePagle's PagleHost: the client's seams over its fakes, plus its timer fake (spec/support/timers.lua).
---@class FakeHost: PagleHost
---@field timers table the fake's clock: time(), after(seconds, fn) and advance(seconds)

-- Core's logic/ for one fake: Pagle.toc's libs (for the bus), generated data/, locale/ and logic/ files, in TOC
-- order, sharing one ns, as the client would load them. None uses WoW globals (CORE-R7), so plain Lua runs them.
---@return table ns
---@return table env
local function loadCoreLogic()
	local env = setmetatable({}, { __index = _G })
	-- LibStub keeps itself in _G.LibStub: this one stays in env, or every later load would share its libraries.
	env._G = env
	-- CallbackHandler calls each listener through this. Here a listener's error fails the spec instead.
	env.securecallfunction = function(fn, ...)
		return fn(...)
	end
	local ns = {}
	for _, file in ipairs(addonFiles("Pagle")) do
		local wanted = file:match("^logic/")
			or file:match("^locale/")
			or file:match("^data/")
			or file:match("^libs/LibStub/")
			or file:match("^libs/CallbackHandler")
		if wanted then
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle/" .. file))
			setfenv(chunk, env)
			chunk("Pagle", ns)
		end
	end
	return ns, env
end

-- Read-only proxies (CORE-R18). Weak both ways, so one record has one proxy and neither keeps the other alive.
local originalOf = setmetatable({}, { __mode = "k" }) -- proxy -> record
local proxyOf = setmetatable({}, { __mode = "kv" }) -- record -> proxy

---@param value any
---@return any
local function readOnly(value)
	if type(value) ~= "table" or originalOf[value] then
		return value
	end
	local proxy = proxyOf[value]
	if not proxy then
		proxy = setmetatable({}, {
			__index = function(_, key)
				return readOnly(value[key])
			end,
			__newindex = function(_, key)
				error(
					("%s written to a record Core handed out; records are shared and immutable (CORE-R18)"):format(
						tostring(key)
					),
					2
				)
			end,
			__metatable = "read-only Pagle record",
		})
		originalOf[proxy] = value
		proxyOf[value] = proxy
	end
	return proxy
end

-- next, pairs, ipairs and unpack that see through a proxy, handing out read-only values.
local function proxyNext(t, key)
	local original = originalOf[t]
	if not original then
		return next(t, key)
	end
	local nextKey, value = next(original, key)
	return nextKey, readOnly(value)
end

local function proxyPairs(t)
	return proxyNext, t, nil
end

local function proxyIpairs(t)
	local original = originalOf[t]
	if not original then
		return ipairs(t)
	end
	local function step(_, i)
		local value = original[i + 1]
		if value == nil then
			return nil
		end
		return i + 1, readOnly(value)
	end
	return step, t, 0
end

local function proxyUnpack(t, i, j)
	local original = originalOf[t]
	if not original then
		return unpack(t, i, j)
	end
	i, j = i or 1, j or #original
	local values = {}
	for k = i, j do
		values[k - i + 1] = readOnly(original[k])
	end
	return unpack(values, 1, j - i + 1)
end

--- One part of the fake: it adds a Core topic's calls to `fake.Pagle` (and fake helpers to `fake`), using Core's
--- real logic in `ns` and, where Core's adapter runs logic/Wiring.lua, the same wiring over `host`, the fake's
--- PagleHost (newFakePagle below). Parts run in order, each on a fresh fake.
---@type fun(fake: FakePagle, Pagle: table, ns: table, host: FakeHost)[]
local parts = {}

---@param build fun(fake: FakePagle, Pagle: table, ns: table, host: FakeHost)
local function part(build)
	parts[#parts + 1] = build
end

-- WoW events through Pagle (CORE-R23). One handler per owner and event; registering again replaces it.
part(function(fake, Pagle)
	local handlers = {} -- event -> owner -> { fn, unit? }
	local function register(owner, event, unit, fn)
		handlers[event] = handlers[event] or {}
		handlers[event][owner] = { fn = fn, unit = unit }
	end
	function Pagle.RegisterEvent(owner, event, fn)
		register(owner, event, nil, fn)
	end
	function Pagle.RegisterUnitEvent(owner, event, unit, fn)
		register(owner, event, unit, fn)
	end
	function Pagle.UnregisterEvent(owner, event)
		if handlers[event] then
			handlers[event][owner] = nil
		end
	end
	function fake.fireGameEvent(event, ...)
		local unit = ...
		local listening = {}
		for _, handler in pairs(handlers[event] or {}) do
			listening[#listening + 1] = handler
		end
		for _, handler in ipairs(listening) do
			if handler.unit == nil or handler.unit == unit then
				handler.fn(event, ...)
			end
		end
	end
end)

-- Restriction state (CORE-R30), on Core's real Restriction logic. setRestricted works as combat would.
part(function(fake, Pagle, ns)
	local restriction = ns.NewRestriction(false, {})
	function Pagle.IsRestricted()
		return restriction:IsRestricted()
	end
	function fake.setRestricted(isRestricted)
		if restriction:SetCombat(isRestricted) then
			fake.fire("RestrictionChanged", isRestricted)
		end
	end
end)

-- Attaching a Module (CORE-R12–R14, CORE-R19, CORE-R41), on Core's real registry.
part(function(fake, Pagle, ns)
	fake.addons = {}
	for _, name in ipairs(ns.MODULE_ROSTER) do
		fake.addons[ns.ModuleAddOn(name)] =
			{ enabled = true, loaded = true, metadata = { ["X-Pagle-API"] = tostring(Pagle.API_VERSION) } }
	end

	local function readAPI(addon)
		local info = fake.addons[addon]
		return info and info.metadata and info.metadata["X-Pagle-API"]
	end
	Pagle.RegisterModule = ns.ModuleRegistrar(fake.registry, readAPI, fake.print)

	function fake.moduleState(name)
		local info = fake.addons[ns.ModuleAddOn(name)]
		local enabled = info ~= nil and info.enabled ~= false
		return fake.registry:State(name, {
			installed = info ~= nil,
			enabled = enabled,
			loaded = info ~= nil and (info.loaded or (info.loaded == nil and enabled)),
		})
	end

	local loggedIn = false
	function fake.login()
		assert(not loggedIn, "FakePagle: PLAYER_LOGIN happens once a session")
		loggedIn = true
		fake.fire("ModulesChanged")
	end
end)

-- Settings (CORE-R33, CORE-R42, CORE-R43), on Core's real rows logic. Pages count as registered from login.
part(function(fake, Pagle, ns)
	local rows = ns.NewSettingsRows()
	local loggedIn = false
	fake.openedSettings = {}

	ns.ModuleHandle.AddSetting = ns.AddSettingMethod(fake.registry, rows, fake.report)

	Pagle.RegisterCallback(fake, "ModulesChanged", function()
		rows:Close()
		loggedIn = true
	end)

	function fake.settingsPage(topic)
		local entries = loggedIn and rows:Page(topic, fake.registry:Modules()) or {}
		if #entries == 0 then
			return nil
		end
		local page = {}
		for i, entry in ipairs(entries) do
			local setting = entry.setting
			page[i] = {
				module = entry.module.def.name,
				kind = setting.kind,
				label = setting.label,
				indented = entry.parent ~= nil,
				setting = setting,
			}
		end
		return page
	end

	function Pagle.OpenSettings(topic)
		if Pagle.IsRestricted() then
			fake.print(ns.L.SETTINGS_AFTER_COMBAT)
		elseif loggedIn then
			fake.openedSettings[#fake.openedSettings + 1] = (type(topic) == "string" and fake.settingsPage(topic))
					and topic
				or "root"
		end
	end
end)

-- The wallet (SHOP-R2–R4, SHOP-R12), on Core's wiring over fake.global.coins: M:ReportCoinsEarned,
-- Pagle.GetBalance (read-only) and BalanceChanged. Each report Core accepts is also in fake.coinReports. PagleDB is
-- open from the start, as it is by the time any Module registers (login step 1).
part(function(fake, Pagle, ns, host)
	fake.coinReports = {}
	ns.WireWallet(host)
	ns.OpenWallet()
	local wallet = ns.wallet
	local report = wallet.Report
	function wallet.Report(self, name, total)
		fake.coinReports[#fake.coinReports + 1] = { module = name, total = total }
		report(self, name, total)
	end

	function Pagle.GetBalance()
		return readOnly(wallet:Get())
	end

	function fake.setSpent(spent)
		wallet:SetSpent(spent)
	end
end)

-- Goods (SHOP-R20–R26, SHOP-R30–R33, SHOP-R90), on Core's wiring over fake.global.goods (fake.goods) and
-- fake.profile.appearance: M:RegisterSlot, M:RegisterGood and M:RefreshGoods on the handle, Pagle.IsOwned,
-- GetEquipped, SetEquipped and GetGood (read-only), and AppearanceChanged from login on. The purchased set is
-- empty until fake.setPurchased hands one over, as the wallet projection will (SHOP-R11). Pagle.OpenShop only
-- records what it was asked for in fake.shopsOpened. Core's own slots and goods (SHOP-R25) are registered from the
-- start, as login step 1 registers them before any Module, without previews: no shop draws here.
part(function(fake, Pagle, ns, host)
	ns.WireGoods(host)
	ns.RegisterCoreGoods()
	fake.goods = fake.global.goods
	fake.shopsOpened = {}

	function Pagle.IsOwned(goodID)
		return ns.goods:IsOwned(goodID)
	end

	function Pagle.GetEquipped(slot)
		return ns.goods:GetEquipped(slot)
	end

	function Pagle.SetEquipped(slot, goodID)
		return ns.goods:SetEquipped(slot, goodID)
	end

	function Pagle.GetGood(goodID)
		return readOnly(ns.goods:GetGood(goodID))
	end

	function Pagle.OpenShop(goodID)
		fake.shopsOpened[#fake.shopsOpened + 1] = { goodID = goodID }
	end

	function fake.setPurchased(purchased)
		ns.goods:SetPurchased(purchased)
	end
end)

-- Moments (ANN-R1–R4, ANN-R10–R12), on Core's wiring over fake.projections' seams: M:RaiseMoment validates and
-- drops as Core does, and each Announcement Core would show lands in fake.announcements when fake.nextFrame runs the
-- frame after. A dropped moment's report is in fake.reported.
part(function(fake, _, ns, host)
	fake.announcements = {}
	local frame = {}
	ns.WireMoments(host, function(announcement)
		fake.announcements[#fake.announcements + 1] = announcement
	end)

	function fake.nextFrame()
		local steps = frame
		frame = {}
		for _, step in ipairs(steps) do
			step()
		end
	end

	-- Queues a step of a later part for the next fake.nextFrame.
	function fake.queueFrame(step)
		frame[#frame + 1] = step
	end
end)

-- The compartment menu and /pagle (CORE-R50, CORE-R52, CORE-R60–R62), on Core's real logic. Modules' subcommands
-- are added at login, by def.order; one Core skips is in fake.reported. Labels and subcommands run through
-- fake.securecall, as Core's run through securecallfunction.
part(function(fake, Pagle, ns)
	local commands = ns.NewSlashCommands()
	Pagle.RegisterCallback(commands, "ModulesChanged", function()
		commands:AddModules(fake.registry:Modules(), fake.report)
	end)

	local core = {
		settings = function()
			Pagle.OpenSettings()
		end,
		report = function()
			Pagle.OpenFieldReport()
		end,
	}
	local settings = ns.SettingsMenuEntry(core.settings)
	function fake.menu()
		local shop = ns.CurioShopMenuEntry(Pagle.GetBalance(), breakUpLargeNumbers)
		local report = ns.FieldReportMenuEntry(Pagle.GetFieldReportCount(), core.report)
		return ns.CompartmentMenu(fake.registry:Modules(), shop, report, settings, fake.securecall)
	end

	function fake.slash(line)
		commands:Run(line, core, fake.securecall, fake.print)
	end
end)

-- Condition specs (LOG-R48): pure, so the real one. A Module hands back the specs and conditions Core gave it, here
-- read-only proxies, which the real one sees through as Core does its own tables in the client.
part(function(_, Pagle, ns)
	function Pagle.MatchesConditions(spec, snapshot)
		return ns.MatchesConditions(originalOf[spec] or spec, originalOf[snapshot] or snapshot)
	end
end)

-- The Catch log (LOG-R10–R16, LOG-R42) on Core's real codec, over an empty in-memory PagleLog. A spec adds
-- characters to fake.catchLog.data.characters and entries with fake.catchLog:Append(record). Every Cast it hands out
-- carries Core's Simulated Sizes over the catalogue served when it's read (LOG-R65), and the band list and size
-- rules version are Core's (LOG-R67, LOG-R68).
part(function(fake, Pagle, ns)
	fake.catchLog = ns.OpenCatchLog(nil, fake.global, SERVER_TIME, ns.CatalogueItem)
	Pagle.SIZE_BANDS = ns.SIZE_BANDS
	Pagle.SIZE_RULES_VERSION = ns.SIZE_RULES_VERSION
	function Pagle.IterateCatches(afterSeq)
		local iterate = fake.catchLog:Iterate(afterSeq)
		return function()
			return readOnly(iterate())
		end
	end
end)

-- Projections (LOG-R70–R77), on Core's wiring over fake.catchLog: M:NewProjection and M:IterateCatches on the
-- handle. login notes loginSeq (the log's length then); enterWorld is login step 3, running every catch-up and
-- rebuild at once; each entry the fake appends afterwards (playCast, readSkill) is handed over live, before its events.
-- Records reach apply read-only (CORE-R18). Module code that raises goes to fake.reported.
part(function(fake, _, ns, host)
	ns.WireProjections(host)
	fake.projections = ns.projections
	-- Every entry handed over live reaches apply read-only, whichever part or wiring appended it (CORE-R18).
	local live = fake.projections.Live
	function fake.projections.Live(self, record)
		live(self, readOnly(record))
	end

	local loginSeq
	local login = fake.login
	function fake.login()
		loginSeq = #fake.catchLog.data.entries
		login()
	end

	local enteredWorld = false
	function fake.enterWorld()
		assert(loginSeq, "FakePagle: PLAYER_ENTERING_WORLD comes after fake.login()")
		assert(not enteredWorld, "FakePagle: login step 3 runs at the first PLAYER_ENTERING_WORLD only")
		enteredWorld = true
		fake.projections:Start(loginSeq)
	end

	-- Hands an entry the fake just appended to the projections (LOG-R73).
	function fake.live(record)
		fake.projections:Live(record)
	end
end)

-- The Angler (LOG-R25–R27) and Skill Readings (LOG-R31, LOG-R32), on Core's real logic over fake.catchLog. Login
-- adds the fake client's character (PLAYER_GUID) before ModulesChanged, as Core's login order does (LOG-R1).
part(function(fake, Pagle, ns)
	local now = SERVER_TIME -- the fake client's GetServerTime()
	local angler = ns.NewAngler(fake.catchLog)
	function Pagle.GetAngler()
		return readOnly(angler:Get())
	end

	local login = fake.login
	function fake.login()
		angler:SeeCharacter({
			guid = PLAYER_GUID,
			name = "Angler",
			surname = "Tester",
			classID = 1,
			raceID = 1,
			faction = "Alliance",
			realmID = ns.RealmIDFromGUID(PLAYER_GUID),
		}, now)
		login()
	end

	function fake.readSkill(rank, max, mod)
		if not angler.current then
			return
		end
		local appended = angler:ReadSkill({ rank = rank, max = max, mod = mod }, now)
		if appended then
			fake.live(appended)
			fake.fire("SkillChanged", appended)
		end
		-- The live conditions follow the reading, through the same tracker as setConditions (LOG-R32, LOG-R47).
		local conditions = copyConditions(fake.conditions)
		conditions.skillRank, conditions.skillMod = rank, mod
		fake.setConditions(conditions)
	end
end)

-- Prestige and purchase entries (LOG-R38, LOG-R39), on Core's wiring over fake.catchLog, for the logged-in character
-- at the fake's server time: M:RecordPrestige appends a real P1, applies it live and fires Prestige, as
-- fake.prestige() does without a handle. A purchase has no Pagle or Module call; fake.ns.RecordPurchase is Core's own.
part(function(fake, _, ns, host)
	ns.WireLogEntries(host)
	-- The record it returns is read-only, as every record a Module gets here (CORE-R18).
	local ModuleHandle = ns.ModuleHandle
	local recordPrestige = ModuleHandle.RecordPrestige
	function ModuleHandle:RecordPrestige()
		return readOnly(recordPrestige(self))
	end
	function fake.prestige()
		return readOnly(ns.RecordPrestige())
	end
end)

-- The catalogue (LOG-R55), on Core's real accessors over the generated catalogue or a spec's own. Each record
-- they hand out is read-only (CORE-R18, DATA-R80).
part(function(fake, Pagle, ns)
	-- As Core's login step 1, the catalogue goes in ns.Catalogue, which the Cast state machine reads too (LOG-R2).
	function fake.setCatalogue(data)
		ns.Catalogue = ns.NewCatalogue(data)
		Pagle.CONTENT_FINGERPRINT = ns.Catalogue.CONTENT_FINGERPRINT
	end
	for _, name in ipairs({ "GetItem", "GetZones", "GetArea", "GetZoneOf", "GetZoneCatches", "GetWindowSpec" }) do
		Pagle[name] = function(...)
			return readOnly(ns.Catalogue[name](...))
		end
	end
	fake.setCatalogue(ns.catalogue)
end)

-- The Field report's count (REP-R25, REP-R26, LOG-R78), on Core's real projection, bound on fake.projections ahead
-- of every Module's, over fake.catchLog, the catalogue served now and fake.diagnostics (empty; a spec fills it with
-- LOG-R81 entries). Live entries reach it as read-only proxies, which Core's logic walks with newFakePagle's
-- proxy-aware pairs and ipairs.
part(function(fake, Pagle, ns)
	fake.diagnostics = {}
	fake.fieldReportDB = {}
	local catalogue = setmetatable({}, {
		__index = function(_, name)
			return ns.Catalogue[name]
		end,
	})
	local rows, count = ns.AddFieldReport({
		projections = fake.projections,
		db = fake.fieldReportDB,
		catalogue = catalogue,
		iterate = function(afterSeq)
			return fake.catchLog:Iterate(afterSeq)
		end,
		buffer = function()
			return fake.diagnostics
		end,
		casts = function()
			return fake.catchLog:Reverse("cast")
		end,
	})
	local setCount
	function Pagle.GetFieldReportCount()
		if setCount then
			return setCount
		end
		return count()
	end
	function fake.setFieldReportCount(n)
		setCount = n
	end

	-- The box (REP-R40–R44), on Core's real Pagle.OpenFieldReport: each opening's view, its text built now from the
	-- rows above as Core's adapter builds it (the header's addon version reads "test", and no name is cached), lands
	-- in fake.fieldReportsOpened; while restricted it prints REP-R44's line instead.
	fake.fieldReportsOpened = {}
	local noName = function()
		return nil
	end
	Pagle.OpenFieldReport = ns.OpenFieldReportFunction({
		isRestricted = function()
			return Pagle.IsRestricted()
		end,
		print = fake.print,
		rows = rows,
		text = function(reportRows)
			return ns.FieldReportParts(reportRows, {
				addon = "test",
				fingerprint = Pagle.CONTENT_FINGERPRINT,
				locale = "enUS",
				logId = fake.catchLog.data.logId or "",
			}, { item = noName, area = noName })
		end,
		show = function(view)
			fake.fieldReportsOpened[#fake.fieldReportsOpened + 1] = view
		end,
	})
end)

-- The live conditions (LOG-R45, LOG-R47). Pagle.GetConditions hands out fake.conditions, read-only, with the
-- restriction flag; fake.setConditions replaces it and fires ConditionsChanged with the keys Core's real tracker
-- finds changed.
part(function(fake, Pagle, ns)
	-- Fishing The Long Wash (148/453) at realm 08:15 on Sunday 11 October 2026, Fishing 86+25 with lure 263 on, no
	-- listed event or aura (probe report 70338).
	fake.conditions = {
		time = SERVER_TIME,
		minute = 495,
		date = { year = 2026, month = 10, day = 11, weekday = 1 },
		uiMap = 1439,
		instance = 1,
		zone = 148,
		subzone = 453,
		skillRank = 86,
		skillMod = 25,
		lure = 263,
		events = {},
		auras = {},
	}
	local tracker = ns.NewConditionsTracker()
	tracker:Update(fake.conditions)

	function Pagle.GetConditions()
		local conditions = copyConditions(fake.conditions)
		conditions.restricted = Pagle.IsRestricted()
		return readOnly(conditions)
	end

	function fake.setConditions(snapshot)
		fake.conditions = snapshot
		local changed = tracker:Update(snapshot)
		if #changed > 0 then
			fake.fire("ConditionsChanged", changed)
		end
	end
end)

-- Window forecasts (LOG-R50), on Core's own Pagle.NextWindow body (ns.ForecastWindow) over the fake's catalogue: the
-- realm's UTC offset comes from fake.conditions' time and minute (a nil minute is a secret clock), and the events
-- open now from fake.conditions.events, so setConditions moves the clock and the calendar. Each Window is read-only.
-- A spec Pagle.GetWindowSpec handed out goes in as its record, as Core takes its own (`#` sees nothing in a proxy).
part(function(fake, Pagle, ns)
	function Pagle.NextWindow(spec, fromTime)
		spec = originalOf[spec] or spec
		return readOnly(ns.ForecastWindow(spec, fromTime, fake.conditions, ns.Catalogue.GetEventRule))
	end
end)

-- Fishing (LOG-R2–R9, LOG-R43), on Core's real Cast state machine: a spec plays a Cast's signals (or a whole Cast
-- with playCast) and the Module gets Core's events, each Cast recorded to fake.catchLog first, with fake.conditions
-- as its snapshot, at the fake's server time. The fake's clock starts at 0 (server time SERVER_TIME) and moves only
-- with fake.wait, which runs the grace timers that come due, on the fake client's timer fake (spec/support/timers.lua).
part(function(fake, Pagle, ns, host)
	local FISHING = 7731 -- Fishing (Classic Journeyman), on the generated fishing-spell list
	local clock = host.timers
	local recorded -- the Cast record last appended

	local fishing = ns.NewFishing({
		isFishingSpell = ns.IsFishingChannel,
		record = function(outcome, items)
			local char = Pagle.GetAngler().current
			if not char then
				return nil
			end
			local conditions = copyConditions(fake.conditions)
			conditions.time, conditions.date = SERVER_TIME + math.floor(clock.time()), nil
			recorded = fake.catchLog:Append({
				kind = "cast",
				char = char,
				time = conditions.time,
				outcome = outcome,
				conditions = conditions,
				items = items,
			})
			ns.sessions:Cast() -- LOG-R9 step 3
			fake.live(recorded)
			return recorded
		end,
		fire = fake.fire,
	})

	function Pagle.GetFishingState()
		return fishing:GetState()
	end

	function fake.channel(spellID)
		fishing:ChannelStarted(spellID or FISHING, clock.time())
	end

	function fake.stopChannel(spellID)
		local graceEnded = fishing:ChannelStopped(spellID or FISHING, clock.time())
		if graceEnded then
			clock.after(ns.FISHING_GRACE, graceEnded)
		end
	end

	function fake.loot(items, isFishing)
		if isFishing == nil then
			isFishing = true
		end
		fishing:LootReady(isFishing, function()
			return items or {}
		end, clock.time())
	end

	function fake.closeLoot()
		fishing:LootClosed(clock.time())
	end

	function fake.escape()
		fishing:Escaped(clock.time())
	end

	fake.wait = clock.advance

	-- Sessions (LOG-R60–R64), on Core's wiring over fake.catchLog and fake.global, at the fake's server time. The
	-- session tag is the Catch log's own. Login opens them, noting the latest Session (one ended before it gets its
	-- SessionEnded, whileAway, once no projection is updating, unless global.lastEndedSession names it); each Cast
	-- fires the Session events after its append (LOG-R9 step 3); the Session ends when fake.wait has passed 900 s
	-- after its last Cast.
	fake.serverTime = host.serverTime
	Pagle.SESSION_RULES_VERSION = ns.SESSION_RULES_VERSION
	ns.WireSessions(host)

	local login = fake.login
	function fake.login()
		ns.sessions:Open()
		login()
	end

	function Pagle.GetSession()
		return readOnly(ns.sessions:Get())
	end

	function fake.playCast(outcome, items)
		recorded = nil
		fake.channel()
		if outcome == "caught" then
			fake.loot(items)
			fake.stopChannel()
			fake.closeLoot()
		elseif outcome == "gotAway" then
			fake.escape()
			fake.stopChannel()
		else
			fake.stopChannel()
			fake.wait(ns.FISHING_GRACE)
		end
		return readOnly(recorded)
	end
end)

-- The Session summary and the cards (ANN-R21, ANN-R50–R54, ANN-R60–R62), on Core's wiring over fake.global: each
-- moment Core keeps goes to the open Session's summary (or global.pending with none open) and to fake.summarized,
-- M:SetSummaryLine sets lines, and SessionEnded makes a card in fake.global.cards for a Session that raised a moment.
-- M:RaiseWriteUp keeps a section in fake.global.writeUp and fake.writeUps. Cards show in fake.cardsShown, as Core's
-- would, from the second fake.nextFrame after enterWorld; the fake has no lanes, so they never wait for them, nor for
-- the combat hold. Each moment kept in Cozy mode counts on the compartment's label until a Session summary card shows
-- (ANN-R42), and a card shows each moment expired by the time it was made with its pastText (ANN-R45).
part(function(fake, _, ns, host)
	fake.summarized = {}
	fake.writeUps = {}
	fake.cardsShown = {}
	ns.WireCards(host, {
		show = function(card)
			fake.cardsShown[#fake.cardsShown + 1] = card
		end,
		hide = function() end,
		lanesEmpty = function()
			return true
		end,
		held = function()
			return false
		end,
	})
	-- Each section Core keeps is also noted in fake.writeUps, which closing the Write-up doesn't empty.
	local cards = ns.cards
	local raise = cards.Raise
	function cards.Raise(self, module, section)
		raise(self, module, section)
		local writeUp = fake.global.writeUp
		fake.writeUps[#fake.writeUps + 1] = writeUp[#writeUp]
	end
	function fake.closeCard()
		cards:Close(fake.cardsShown[#fake.cardsShown])
	end

	ns.WireSummary(host, function() end)
	-- Every moment Core keeps is also noted in fake.summarized, as raised.
	local summary = ns.summary
	local add = summary.Add
	function summary.Add(self, moment)
		fake.summarized[#fake.summarized + 1] = moment
		add(self, moment)
	end
	function fake.compartmentText()
		return ns.CompartmentText(summary:Waiting())
	end
end)

--- A fresh FakePagle: no Module registered, not restricted, before PLAYER_LOGIN.
---@return FakePagle
function newFakePagle()
	local ns, env = loadCoreLogic()
	-- Core's own projections get live entries as the read-only proxies every projection gets here; on plain tables
	-- these behave as the stock ones.
	env.pairs, env.ipairs, env.next = proxyPairs, proxyIpairs, proxyNext
	-- Pagle.API_VERSION as adapter/Core.lua sets it; fake_pagle_spec.lua checks they agree.
	local Pagle = { API_VERSION = 1 }
	local fake = { Pagle = Pagle, ns = ns, printed = {}, readOnly = readOnly }
	-- PagleDB as login step 1 opens it: Core's defaults, and nothing saved. A spec seeds fake.global's keys and
	-- fake.profile's before login, as a saved PagleDB would hold them.
	fake.global = copyTable(ns.PAGLEDB_DEFAULTS.global)
	fake.profile = copyTable(ns.PAGLEDB_DEFAULTS.profile)
	fake.registry = ns.NewModuleRegistry(Pagle.API_VERSION)
	function fake.print(line)
		fake.printed[#fake.printed + 1] = line
	end
	-- fake.reported: a spec that gets a report must read it, or it fails at its end (spec/support/errors.lua).
	fake.report = watchErrors(fake, "reported")
	fake.securecall = newSecureCall(function()
		return fake.report
	end)

	-- The event bus (CORE-R20–R22): Core's own CallbackHandler registry, which every part fires on.
	local bus = env.LibStub("CallbackHandler-1.0")
		:New(Pagle, "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")
	function fake.fire(event, ...)
		local count = select("#", ...)
		local args = { ... }
		for i = 1, count do
			args[i] = readOnly(args[i])
		end
		bus:Fire(event, unpack(args, 1, count))
	end

	-- The fake's PagleHost, which logic/Wiring.lua builds Core's parts over, as adapter/Host.lua's is the client.
	local timers = newClock()
	---@type FakeHost
	local host = {
		registry = fake.registry,
		db = function()
			return { global = fake.global, profile = fake.profile }
		end,
		catchLog = function()
			return fake.catchLog
		end,
		character = function()
			return Pagle.GetAngler().current
		end,
		fire = fake.fire,
		listen = function(owner, event, fn)
			Pagle.RegisterCallback(owner, event, fn)
		end,
		fingerprint = function()
			return Pagle.CONTENT_FINGERPRINT
		end,
		iterate = function(afterSeq)
			local records = fake.catchLog:Iterate(afterSeq)
			return function()
				return readOnly(records())
			end
		end,
		serverTime = function()
			return SERVER_TIME + math.floor(timers.time())
		end,
		after = timers.after,
		nextFrame = function(step)
			fake.queueFrame(step)
		end,
		clock = function()
			return 0
		end,
		call = fake.securecall,
		report = fake.report,
		syncLimit = math.huge, -- every catch-up and rebuild runs at once
		timers = timers,
	}

	for _, build in ipairs(parts) do
		build(fake, Pagle, ns, host)
	end
	fake.globals = {
		Pagle = readOnly(Pagle),
		pairs = proxyPairs,
		ipairs = proxyIpairs,
		next = proxyNext,
		unpack = proxyUnpack,
	}
	function fake.load(name, options)
		local loadOptions = { dependencyLibsOnly = true }
		for key, value in pairs(options or {}) do
			loadOptions[key] = value
		end
		local loaded = loadAddon(name, fake.globals, loadOptions)
		-- WoW events the game raises on its own (UPDATE_BINDINGS) reach the Module through Pagle.RegisterEvent.
		loaded.client.fireGameEvent = fake.fireGameEvent
		return loaded
	end
	return fake
end
