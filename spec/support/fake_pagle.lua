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
-- A Module raises moments only for what is worth one: an ordinary Catch gets Core's own catch Nod (ANN-R13), which
-- lands in fake.catchNods, so a Module spec playing an ordinary Cast expects fake.announcements to stay empty.
--
-- It is built on Core's real logic/: each FakePagle loads Pagle.toc's data/, locale/ and logic/ files (and the
-- CallbackHandler bus) afresh, so what it validates, computes and refuses is what Core does. Core's projections,
-- Sessions, moments, Session summary, cards, wallet, Activity XP, goods, wallet projection and tracker dock are built
-- and connected by logic/Wiring.lua, which Core's adapter runs too: the fake hands it a host over its fakes where
-- Core's adapter hands it the client (adapter/Host.lua).
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
---@field clientEnv table? The globals of the first client `load` gave a Module: Pagle.Animate's driver is a frame of
--- it, so that client's update steps every animation, and Pagle.FitToScreen fits to its UIParent.
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
---@field settingsPage fun(topic: string): { module: string, kind: string, label: string, caption: string?, indented: boolean, setting: PagleSetting?, slot: string? }[]?
--- The rows Core would put on a topic page, in order, its header rows included; nil before login or with no rows,
--- when Core registers no page (CORE-R42). A button row's caption is nil when its label is on the button (SET-R2).
--- On Trackers, each Module's section ends with Core's slot dropdown for each of its "Trackers"-category slots: kind
--- "slot", labelled with the slot's label, `slot` its ID, and no `setting` (SET-R44).
---@field reported string[] Each error Core reported through geterrorhandler(), e.g. a late M:AddSetting, a
--- Module function that raised under securecallfunction, or a moment dropped in a replay or rebuild (ANN-R4). A
--- spec that gets one must read this list (assert it), or it fails at its end (spec/support/errors.lua).
---@field print fun(line: string) What Core's print does: adds a chat line to `printed`.
---@field report fun(err: any) What Core's geterrorhandler() does: adds the error to `reported`.
---@field securecall fun(fn: function, ...: any): ... What Core's securecallfunction does: runs `fn`; on an error,
--- reports it and returns nothing.
---@field openedSettings string[] What each Pagle.OpenSettings opened: "root" or the topic (CORE-R43).
---@field menu fun(): PagleMenuEntry[] The compartment menu as it would open now, labels read (CORE-R50, CORE-R52);
--- each entry's onClick is what clicking it does. Its last three entries are the Curio Shop (it calls
--- Pagle.OpenShop), "Help chart the waters" (with " (N)" while Pagle.GetFieldReportCount() is above 0; it calls
--- Pagle.OpenFieldReport) and Settings.
---@field coinReports { module: string, total: integer }[] Each M:ReportCoinsEarned Core accepted, in order, an
--- unchanged total too (SHOP-R2).
---@field xpReports { module: string, total: integer, entry: PagleRecord? }[] Each M:ReportXPEarned Core accepted, in
--- order, an unchanged total too (AXP-R2), with the live entry it carried to ActivityXPChanged (nil from a done or
--- outside any apply, AXP-R7). An ActivityXPChanged fires only for a changed total.
---@field setActivityXP fun(name: string, total: integer) Stores a Module's lifetime Activity XP as a saved PagleDB
--- holds it (fake.global.activityXP.earned), firing nothing: how a spec has a disabled or uninstalled Module's last
--- total count (AXP-R3, AXP-R90), listed by Pagle.GetActivityXP with `enabled` false unless that Module registers.
--- Raises an error for a total M:ReportXPEarned would refuse.
---@field setSpent fun(spent: integer) Sets the Coins spent, for a spec that doesn't care about the log: BalanceChanged
--- fires if the balance or held changes (SHOP-R12). The wallet projection sets the log's own at enterWorld's done and
--- on each live purchase (fake.global.projections.wallet, SHOP-R11), replacing it; set it after enterWorld to keep it.
---@field setPurchased fun(purchased: table<string, true>) Hands Core the purchased goods, `{ [goodID] = true }`, for a
--- spec that doesn't care about the log; AppearanceChanged fires if a look changes (SHOP-R33). The wallet projection
--- hands over the log's own set at enterWorld's done and on each live purchase (SHOP-R11), replacing it; a spec that
--- wants its set kept hands it over after enterWorld. A U1 in fake.catchLog's history (helpers.lua's purchaseEntry, or
--- fake.catchLog:Append) gives the spent total, the purchased set and the balance the way Core's log does.
---@field shopsOpened { goodID: string?, selected: string? }[] Each time the Curio Shop opened (or Pagle.OpenShop
--- reached it open), in order: the good Pagle.OpenShop asked for, and the one Core selected (SHOP-R40: a good the
--- shop shows, a Module off's under Put away; nil for an unknown ID or none asked). While restricted nothing opens and
--- SHOP-R41's line is printed. /pagle shop and the compartment entry open it with no good. The fake has no window.
---@field shopOpen boolean Whether the Curio Shop is open: /pagle shop toggles it, and RestrictionChanged(true) closes
--- it (SHOP-R41).
---@field announcements PagleAnnouncement[] Each Announcement Core would hand the display, in order (ANN-R11): its
--- headline, rung, stamps (at most 4), more ("+N"), coins and every moment, ranked. One per Cast, made on the frame
--- after its moments were raised, or after the last projection finishes (ANN-R10); one per moment without a Cast.
--- Core's catch Nod is never here: it is in catchNods.
---@field catchNods PagleAnnouncement[] Each catch Nod Core would hand the display (ANN-R13): one per played caught
--- Cast for which no Module raised a moment, while `profile.announcements.everyCatch` is on, on the frame after.
--- Its headline's title is "{item name} · {band} · {length}", the name from `itemNames`.
---@field itemNames table<integer, string> The names the fake's client has cached, by item ID, for the catch Nod; a
--- spec sets them. An item without one reads "Item {itemID}".
---@field summarized PagleRaisedMoment[] Each moment Core kept, as it was raised, shown or not (ANN-R25): a
--- summaryOnly one is here and never in announcements. A moment Core dropped (ANN-R4) is in neither.
---@field global table PagleDB.global, the one the fake's Core keeps all its keys in, from Core's defaults
--- (ns.PAGLEDB_DEFAULTS): `coins.earned`, each Module's last reported total by def.name (SHOP-R3), and
--- `activityXP.earned`, its last reported Activity XP (AXP-R3), each with the `logId` of fake.catchLog;
--- `lastEndedSession` (LOG-R63); and the Session summary keys (announcements.md › Data): `summary` (the open
--- Session's moments and every Module's M:SetSummaryLine lines), `pending` (moments raised with no Session open,
--- ANN-R52), `cards` (each SessionEnded's card for a Session that raised a moment, ANN-R53, at most 3, ANN-R54) and
--- `writeUp` (the Write-up sections waiting, ANN-R61). The Field report's (catch-log.md › Data): `diagnostics`
--- (LOG-R81; empty, and playCast adds nothing, so a spec adds the entries for the P rows, REP-R22) and
--- `projections.fieldReport` (REP-R25; bound at construction, so a spec fills that table, never replaces it). A spec
--- may seed its keys before login, as a saved PagleDB.
---@field profile table PagleDB.profile, from Core's defaults: `announcements.cozy` is Cozy mode (ANN-R62), off, and
--- `announcements.everyCatch` is "Show every catch" (ANN-R13), on, and `announcements.motion` is Animations, on, which
--- Pagle.IsAnimationsOn reads; a spec may set any of them. `appearance` holds each slot's pick, `{ [slot] = goodID }` (SHOP-R32), which Pagle.SetEquipped
--- writes and a spec may seed. `lengthUnit` is the Angler's length unit Pagle.FormatLength reads in, "cm" or "in"
--- (LOG-R69); nil, the default, follows `region`.
---@field region integer? GetCurrentRegion() as the fake's client answers it: 1 (Americas), so with no lengthUnit
--- lengths read in inches; a spec may set another region, or nil for a client without the call (centimetres).
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
---@field slash fun(line: string) Types `/pagle <line>` (CORE-R60–R62); help lines go to `printed`. The hidden dev
--- commands work as Core's (#247): `fake.slash("dev on")`, then `"dev endsession"` ends the open Session now, and
--- with `fake.catchLog.data.test = true` (a test log) `"dev catch 6358 [areaID]"` records a caught Cast through the
--- fishing part's real append path, with its events and live projections, as playCast would without the signals.
--- `"dev preview <kind>"` adds a sample to fake.announcements, or for "card" to fake.cardsShown. `"dev glyphs"`
--- (#248) adds { fonts, probe } to fake.glyphProbes. `"dev tour"` (CORE-R66) tours the stops registered with
--- M:RegisterTourStop and ns.tourStops on the fake's clock, so fake.wait moves it on; shots go to fake.tourShots.
---@field glyphProbes { fonts: PagleDevGlyphFont[], probe: string }[] Each `/pagle dev glyphs` probe shown, in order.
---@field tourShots string[]? `/pagle dev tour`'s screenshots (CORE-R66): "shot" for each, in order; a spec may set it
--- to its own list, to read shots in order with what its stops do. Nil: the client has no Screenshot(). Empty at
--- first. The tour's clock reads 12:00:00.
---@field load fun(name: string, options: table?): LoadedAddon Loads a Module with `loadAddon` against this fake:
--- `globals`, and of Pagle.toc only the vendored libs/ the Module reaches through LibStub (CORE-R6). Options as
--- loadAddon's. WoW events its client raises on its own (`client.fireGameEvent`) go to `fake.fireGameEvent`.
---@field catchLog PagleCatchLog The Catch log Pagle.IterateCatches reads, on Core's real codec; empty at first.
---@field setCatalogue fun(data: table) Serves the catalogue calls over `data` (shaped as ns.catalogue, DATA-R76)
--- instead of the generated catalogue.
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
--- the Session 300 s after its last Cast (LOG-R62).
---@field serverTime fun(): integer The fake's server time: SERVER_TIME plus its clock, in whole seconds.
---@field dock FakeDock The tracker dock (CORE-R70–R72): what M:RegisterTracker docked, laid out when read. The
--- saved point is fake.profile.dock.point (core/README.md › Data), nil until a drag; a spec may seed it.
---@field onboarding PagleOnboarding Core's onboarding (core/onboarding.md), on Core's wiring over
--- fake.global.onboarding, which fake.login adds when it's missing (ONB-R1, ONB-R2: letter "returning" when
--- fake.catchLog holds a Cast then, else "waiting") and puts PLAYER_GUID in (ONB-R3). A spec may seed
--- fake.global.onboarding before login (ns.NewOnboardingState), as a saved PagleDB holds it, and set its hooks.
---@field guide PagleGuide The Field guide (core/onboarding.md › The Field guide), Core's own on its wiring
--- (ns.WireGuide): M:RegisterGuideStep on the handle validates and orders steps as Core does, ModulesChanged
--- (fake.login) closes the registry, and Open, Next, Back, GoTo, Skip, Close and Finish move as ONB-R22–R26 say,
--- writing fake.global.onboarding. RestrictionChanged (fake.setRestricted) closes and reopens it (ONB-R25).
---@field guideSteps PagleGuideSteps The guide's step registry: guideSteps:List() is every step, in order (ONB-R21).
---@field guideShown { id: string, how: PagleGuideShow, index: integer, count: integer }[] Each page the book would
--- show, in order: opened on, or turned to forward or back (ONB-R22, ONB-R23).
---@field guidePages table<string, { left: table, right: table, nav: PagleGuideNav }> Each step's two pages, 442 x
--- 546 frames on the client fake.load gave the Module, as its build drew them at the step's first showing, and the nav
--- it got: its moves are Core's, its widgets plain frames that keep what they were made with (a binding field also
--- keeps `greyed` from SetGreyed and counts its Refresh calls in `refreshed`; a choice card keeps `chosen` from
--- SetChosen; a panel marks the frame it's drawn on with `panel` and `panelCap`). No client, no pages.
---@field guideHeld boolean Whether Announcements are held for the guide now (ONB-R70).
---@field letter PagleLetter The Letter (core/onboarding.md › The Letter), Core's own on its wiring (ns.WireLetter):
--- M:SetDialogOpen on the handle tells it a Module's dialog is open (ONB-R100), letter:IsDialogOpen() reads it.
---@field letterOnScreen boolean Whether the Letter's frame would be on screen now (ONB-R11).
---@field inInstance boolean What IsInInstance() answers the Letter (ONB-R10); false unless a spec sets it.
---@field evening PagleEvening The First evening list (core/onboarding.md › The First evening list), Core's own on its
--- wiring (ns.WireEvening): M:CompleteEveningItem on the handle marks a Module's own item, as Core's items tick on
--- CastStarted, Catch, SessionEnded and the shop opening; fake.guide:Finish() (Off to the water) docks it for a new
--- Angler, and fake.login shows it again while due. evening:IsEveningItemDone isn't here: read
--- fake.onboarding:IsEveningItemDone(id), or evening:List().
---@field eveningList PagleEveningList? The list as Core would draw it now, docked; nil while it isn't shown. Its
--- tracker is in fake.dock.stack() as Core's own ("evening", order 1, module "Core") while it shows.
---@field eveningSounds string[] Each sound the list played, in order: `tick`, `listDone` (core/onboarding.md › Sounds).
---@field notesShown PagleMarginNote[] Each Margin note Core would show, in order (ONB-R50–R52): M:ShowMarginNote's,
--- and core.welcome and core.character on fake.menuButton. Once per account and only with Margin notes on.
---@field marginNotes PagleMarginNotes Core's Margin notes on its wiring: :Showing() is what is on screen now, and
--- :TargetHidden(id) plays a target hiding (Core's adapter watches for it each frame).
---@field menuButton { name: string, shown: boolean, IsVisible: fun(self): boolean } Pagle's menu button, which
--- core.welcome and core.character point at; set `shown` to false to play it hidden.
---@field looksShown { id: string, title: string, notes: { text: string, n: integer }[] }[] Each First look Core
--- would show, in order (ONB-R55, ONB-R59): M:ShowFirstLook's, its notes whose targets show, numbered 1 to n (ONB-R56).
---@field firstLooks PagleFirstLooks Core's First looks on its wiring: :Showing() is what is on screen now, :List() every
--- set registered, and :TargetHidden(id, index) plays a note's target hiding (Core's adapter watches for it each frame).
---@field compartmentText fun(): string The compartment entry's label as it reads now (CORE-R51): "Pagle", or with
--- moments kept while Cozy mode was on and no Session summary card shown since, "Pagle · 2 waiting" (ANN-R42).

--- FakePagle's tracker dock, read through Core's own stacking rules (logic/Dock.lua).
---@class FakeDock
---@field stack fun(): { id: string, order: number, module: string, frame: table, point: string, relativeTo: "dock", relativePoint: string, x: number, y: number }[]
--- The shown docked trackers now, top to bottom (by order, ties by Module name), each with its frame's anchor on the
--- dock: its TOPRIGHT at the dock's TOPRIGHT, `y` below it, 8 px between frames. A hidden one takes no room; empty
--- with none shown. Read from each frame's IsShown, GetWidth and GetHeight now, so a shown, hidden or resized frame
--- reflows at once.
---@field point fun(): PagleDockPoint Where the dock's anchor is: fake.profile.dock.point, or by default
--- `{ point = "TOPRIGHT", relativeTo = "MinimapCluster", relativePoint = "BOTTOMRIGHT", x = 0, y = -10 }`.
---@field drag fun(point: PagleDockPoint): boolean A whole Shift-drag of any docked tracker, dropped with the dock at
--- `point`, which is saved to fake.profile.dock.point (relative to "UIParent"). While restricted it does nothing and
--- returns false (CORE-R71).
---@field reset fun(): boolean The Trackers page's Reset (SET-R40): clears the saved point, so the dock goes back under
--- the minimap. While restricted it does nothing and returns false.

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

-- The Animations setting and the motion driver (announcements.md › Contracts), as Core reads it from the profile and
-- plays on Core's real motion player (logic/Motion.lua). Its driver is a frame of the client fake.load gave the
-- Module, made at the first animation, so that client's update (or nextFrame) steps it as the client's OnUpdate does.
part(function(fake, Pagle, ns)
	function Pagle.IsAnimationsOn()
		return fake.profile.announcements.motion ~= false
	end
	local driver
	local player
	local function step(_, elapsed)
		player:Step(elapsed)
	end
	player = ns.NewMotionPlayer({
		isOn = Pagle.IsAnimationsOn,
		wake = function()
			driver = driver or (fake.clientEnv and fake.clientEnv.CreateFrame("Frame"))
			if driver then
				driver:SetScript("OnUpdate", step)
				driver:Show()
			end
		end,
		sleep = function()
			if driver then
				driver:Hide()
				driver:SetScript("OnUpdate", nil)
			end
		end,
	})
	function Pagle.Animate(owner, animations, onDone)
		player:Animate(owner, animations, onDone)
	end
	function Pagle.StopMotion(owner)
		player:Stop(owner)
	end
	function Pagle.Cue(owner, seconds, fn)
		player:Cue(owner, seconds, fn)
	end
	Pagle.Bezier = ns.Bezier
	Pagle.EASE = ns.EASE
end)

-- Fitting a big window to the screen (core/README.md › Contracts), on Core's real logic/Fit.lua and the UIParent of
-- the client fake.load gave the Module. It fits again on UI_SCALE_CHANGED and DISPLAY_SIZE_CHANGED, registered
-- through Pagle.RegisterEvent at the first fit as Core's are, so the Module's client.fireGameEvent reaches them.
part(function(fake, Pagle, ns)
	Pagle.FitToScreen = ns.NewFitter(function()
		return fake.clientEnv.UIParent
	end, function(refit)
		Pagle.RegisterEvent("Pagle fit", "UI_SCALE_CHANGED", refit)
		Pagle.RegisterEvent("Pagle fit", "DISPLAY_SIZE_CHANGED", refit)
	end)
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
		local entries = loggedIn and rows:Page(topic, fake.registry:Modules(), ns.SectionSlots(ns.goods, topic)) or {}
		if #entries == 0 then
			return nil
		end
		local page = {}
		for i, entry in ipairs(entries) do
			local setting, slot = entry.setting, entry.slot
			if slot then
				page[i] = {
					module = entry.module.def.name,
					kind = "slot",
					label = slot.label,
					indented = false,
					slot = slot.id,
				}
			elseif setting then
				page[i] = {
					module = entry.module.def.name,
					kind = setting.kind,
					label = setting.label,
					caption = setting.caption,
					indented = entry.parent ~= nil,
					setting = setting,
				}
			end
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
-- open from the start, as it is by the time any Module registers (login step 1): the Activity XP part below opens
-- the stored totals, once fake.catchLog, whose logId they belong to (SHOP-R3), exists.
part(function(fake, Pagle, ns, host)
	fake.coinReports = {}
	ns.WireWallet(host)
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

-- Goods (SHOP-R20–R26, SHOP-R30–R33, SHOP-R90), on Core's wiring over fake.global.goods (the goods cache: every
-- good registered, by ID, which a spec may fill before login as a saved PagleDB, SHOP-R26, SHOP-R90) and
-- fake.profile.appearance: M:RegisterSlot, M:RegisterGood and M:RefreshGoods on the handle, Pagle.IsOwned,
-- GetEquipped, SetEquipped and GetGood (read-only), and AppearanceChanged from login on. The purchased set comes
-- from the wallet projection part below (SHOP-R11), or from fake.setPurchased. Pagle.OpenShop runs Core's entry
-- points (SHOP-R40, SHOP-R41) over a shop that only records: each opening lands in fake.shopsOpened, and
-- fake.shopOpen says whether it is open; fake.ns.shop.Buy(goodID, useNow) buys as the bill of sale's Buy does
-- (SHOP-R13, LOG-R39). Core's own slots and goods (SHOP-R25) are registered from the start, as
-- login step 1 registers them before any Module, without previews: no shop draws here.
part(function(fake, Pagle, ns, host)
	ns.WireGoods(host)
	ns.RegisterCoreGoods()
	fake.shopsOpened = {}
	fake.shopOpen = false
	Pagle.OpenShop = ns.WireShop(host, {
		isShown = function()
			return fake.shopOpen
		end,
		show = function(selection, asked)
			fake.shopOpen = true
			fake.shopsOpened[#fake.shopsOpened + 1] = { goodID = asked, selected = selection or nil }
		end,
		hide = function()
			fake.shopOpen = false
		end,
	})
	ns.PublishGoods(Pagle, readOnly)

	function fake.setPurchased(purchased)
		ns.goods:SetPurchased(purchased)
	end
end)

-- Moments (ANN-R1–R4, ANN-R10–R12), on Core's wiring over fake.projections' seams: M:RaiseMoment validates and
-- drops as Core does, and each Announcement Core would show lands in fake.announcements when fake.nextFrame runs the
-- frame after. A dropped moment's report is in fake.reported. Core's catch Nod (ANN-R13) runs on Core's wiring too,
-- naming items from fake.itemNames, and lands in fake.catchNods.
part(function(fake, _, ns, host)
	fake.announcements = {}
	fake.catchNods = {}
	fake.itemNames = {}
	local frame = {}
	ns.WireMoments(host, function(announcement)
		-- Core's own catch Nod (ANN-R13) goes apart, so a Module spec sees only what Modules raise.
		local list = announcement.headline.catchNod and fake.catchNods or fake.announcements
		list[#list + 1] = announcement
	end)
	ns.WireCatchNods(host, function(itemID)
		return fake.itemNames[itemID]
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
part(function(fake, Pagle, ns, host)
	local commands = ns.NewSlashCommands()
	Pagle.RegisterCallback(commands, "ModulesChanged", function()
		commands:AddModules(fake.registry:Modules(), fake.report)
	end)

	local core = ns.CoreSubcommands(Pagle)
	function fake.menu()
		return ns.CoreCompartmentMenu(Pagle, core, fake.registry:Modules(), breakUpLargeNumbers, fake.securecall)
	end

	-- /pagle dev (#247), on Core's wiring: the same switch in fake.global, Sessions and fishing as Core's.
	fake.glyphProbes = {}
	fake.tourShots = {}
	ns.WireDev(host, function(announcement)
		fake.announcements[#fake.announcements + 1] = announcement
	end, function(fonts, probe)
		fake.glyphProbes[#fake.glyphProbes + 1] = { fonts = fonts, probe = probe }
	end, {
		isRestricted = function()
			return Pagle.IsRestricted()
		end,
		-- /pagle dev tour (CORE-R66): each screenshot is "shot" in fake.tourShots; with none, the client has no
		-- Screenshot().
		canScreenshot = function()
			return fake.tourShots ~= nil
		end,
		screenshot = function()
			fake.tourShots[#fake.tourShots + 1] = "shot"
		end,
		clock = function()
			return "12:00:00"
		end,
	}, function()
		-- /pagle dev probe (#261) reads the client by name: FakePagle has no client, so every name is a miss.
		return {}
	end)
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
-- carries Core's Simulated Sizes over the catalogue served when it's read (LOG-R65).
part(function(fake, Pagle, ns)
	fake.catchLog = ns.OpenCatchLog(nil, fake.global, SERVER_TIME, ns.CatalogueItem)
	function Pagle.IterateCatches(afterSeq)
		local iterate = fake.catchLog:Iterate(afterSeq)
		return function()
			return readOnly(iterate())
		end
	end
end)

-- Simulated Size as Core publishes it (LOG-R67–R69): Pagle.SIZE_BANDS (read-only here, CORE-R18),
-- Pagle.SIZE_RULES_VERSION and Pagle.FormatLength, in fake.profile.lengthUnit or fake.region's default.
part(function(fake, Pagle, ns, host)
	fake.region = 1
	ns.PublishSize(Pagle, host, readOnly)
end)

-- The variety rarities as Core publishes them (VAR-R11): Pagle.VARIETY_RARITIES, read-only here (CORE-R18).
part(function(_, Pagle, ns)
	ns.PublishVarieties(Pagle, readOnly)
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

-- Prestige and purchase entries and Module records (LOG-R38–R40), on Core's wiring over fake.catchLog, for the
-- logged-in character at the fake's server time: M:RecordPrestige appends a real P1, applies it live and fires
-- Prestige, as fake.prestige() does without a handle. M:AppendRecord appends a real A1 and applies it live to its
-- Module's projections, which alone get it back through M:IterateCatches. A purchase has no Pagle or Module call;
-- fake.ns.RecordPurchase is Core's own.
part(function(fake, _, ns, host)
	ns.WireLogEntries(host)
	-- The records they return are read-only, as every record a Module gets here (CORE-R18). An error Core raises at
	-- the Module's call is raised again there, past the wrapper, as on the client.
	local ModuleHandle = ns.ModuleHandle
	local function readOnlyAtCaller(method)
		return function(...)
			local ok, result = pcall(method, ...)
			if not ok then
				error((tostring(result):gsub("^[^:\n]+:%d+: ", "")), 2)
			end
			return readOnly(result)
		end
	end
	ModuleHandle.RecordPrestige = readOnlyAtCaller(ModuleHandle.RecordPrestige)
	ModuleHandle.AppendRecord = readOnlyAtCaller(ModuleHandle.AppendRecord)
	function fake.prestige()
		return readOnly(ns.RecordPrestige())
	end
end)

-- Activity XP (AXP-R2–R7, ADR 0011), on Core's wiring over fake.global.activityXP: M:ReportXPEarned on the handle,
-- Pagle.GetActivityXP (read-only) and ActivityXPChanged, whose entry is the live record being applied. Each report
-- Core accepts is also in fake.xpReports. Login step 1 opens the wallet's and Activity XP's stored totals here, tied
-- to fake.catchLog's logId (SHOP-R3, AXP-R3), which has none until fake.login: they belong to the fake's log.
part(function(fake, Pagle, ns, host)
	fake.xpReports = {}
	ns.WireActivityXP(host)
	ns.OpenWallet()
	ns.OpenActivityXP()
	local activityXP = ns.activityXP
	local report = activityXP.Report
	function activityXP.Report(self, name, total, entry)
		fake.xpReports[#fake.xpReports + 1] = { module = name, total = total, entry = entry }
		report(self, name, total, entry)
	end

	function Pagle.GetActivityXP()
		return readOnly(activityXP:Get())
	end

	function fake.setActivityXP(name, total)
		local problem = ns.XPTotalProblem(total)
		if problem then
			error(problem, 2)
		end
		fake.global.activityXP.earned[name] = total
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
	for _, name in ipairs({
		"GetItem",
		"GetVarieties",
		"GetZones",
		"GetArea",
		"GetZoneOf",
		"GetZoneCatches",
		"GetWindowSpec",
	}) do
		Pagle[name] = function(...)
			return readOnly(ns.Catalogue[name](...))
		end
	end
	fake.setCatalogue(ns.catalogue)
end)

-- The Field report's count (REP-R25, REP-R26, LOG-R78), on Core's wiring over the fake's host, bound on
-- fake.projections ahead of every Module's: fake.catchLog, the catalogue served now, and fake.global's
-- projections.fieldReport and diagnostics (empty; a spec fills the buffer with LOG-R81 entries). Its records reach it
-- read-only, as every projection's do here, and Core's logic walks them with newFakePagle's proxy-aware pairs and
-- ipairs.
part(function(fake, Pagle, ns, host)
	ns.WireFieldReport(host)
	local fieldReport = assert(ns.fieldReport)
	local setCount
	function Pagle.GetFieldReportCount()
		if setCount then
			return setCount
		end
		return fieldReport.count()
	end
	function fake.setFieldReportCount(n)
		setCount = n
	end

	-- The box (REP-R40–R44), on Core's real Pagle.OpenFieldReport: each opening's view, its text built now from the
	-- rows above on Core's wiring, as Core's adapter builds it (the header's addon version reads "test", the locale
	-- "enUS", and no name is cached), lands in fake.fieldReportsOpened; while restricted it prints REP-R44's line
	-- instead.
	fake.fieldReportsOpened = {}
	local noName = function()
		return nil
	end
	Pagle.OpenFieldReport = ns.OpenFieldReportFunction({
		isRestricted = function()
			return Pagle.IsRestricted()
		end,
		print = fake.print,
		rows = fieldReport.rows,
		text = ns.FieldReportTextFunction(host, {
			addon = function()
				return "test"
			end,
			locale = function()
				return "enUS"
			end,
			names = { item = noName, area = noName },
		}),
		show = function(view)
			fake.fieldReportsOpened[#fake.fieldReportsOpened + 1] = view
		end,
	})
end)

-- The wallet projection (SHOP-R11, SHOP-R34, LOG-R78), on Core's wiring over fake.catchLog, bound in
-- fake.global.projections.wallet after the Field report's and ahead of every Module's: enterWorld's done hands the
-- wallet the Coins spent and the goods registry the purchased set from the U1 entries in the history, and each live
-- purchase (fake.ns.RecordPurchase) hands them over as it counts. PagleDB is open from the start, as for the wallet.
part(function(_, _, ns, host)
	ns.WireWalletProjection(host)
	ns.StartWalletProjection()
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
-- Core reads its snapshot at the call, so "now" (the time the calendar's events hold at, LOG-R46) is the server time
-- the Module reads: fake.globals.GetServerTime when a spec runs it on a clock, with the realm minute moved along.
part(function(fake, Pagle, ns)
	---@return ConditionsSnapshot
	local function snapshotNow()
		local conditions, getTime = fake.conditions, fake.globals.GetServerTime
		if not getTime or conditions.time == nil or conditions.minute == nil or getTime() == conditions.time then
			return conditions
		end
		local now = copyConditions(conditions)
		now.time = getTime()
		now.minute = (conditions.minute + math.floor((now.time - conditions.time) / 60)) % 1440
		return now
	end

	function Pagle.NextWindow(spec, fromTime)
		spec = originalOf[spec] or spec
		return readOnly(ns.ForecastWindow(spec, fromTime, snapshotNow(), ns.Catalogue.GetEventRule))
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
		record = function(outcome, items, _, area)
			local char = Pagle.GetAngler().current
			if not char then
				return nil
			end
			local conditions = copyConditions(fake.conditions)
			conditions.time, conditions.date = SERVER_TIME + math.floor(clock.time()), nil
			if area then
				conditions.zone, conditions.subzone = area.zone, area.subzone
			end
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
	ns.fishing = fishing

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
	-- fires the Session events after its append (LOG-R9 step 3); the Session ends when fake.wait has passed 300 s
	-- after its last Cast.
	fake.serverTime = host.serverTime
	Pagle.SESSION_RULES_VERSION = ns.SESSION_RULES_VERSION
	Pagle.SESSION_GAP = ns.SESSION_GAP
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

-- The tracker dock (CORE-R70–R72), on Core's wiring over fake.profile.dock: M:RegisterTracker on the handle, which
-- validates and orders as Core does, and fake.dock, which lays the stack out from each docked frame's IsShown,
-- GetWidth and GetHeight at the time it's read, as Core's dock reflows on the client. A Shift-drag (fake.dock.drag)
-- and Reset (fake.dock.reset) do nothing while restricted (CORE-R71, SET-R40).
part(function(fake, _, ns, host)
	ns.WireDock(host, {
		watch = function() end,
		reflow = function() end,
		place = function() end,
		-- The fake's drags are whole: none is ever in progress when restriction starts.
		stopMoving = function()
			return nil
		end,
	})

	local function stack()
		local list = {}
		for i, placement in ipairs(ns.dock:Layout().placements) do
			local tracker = placement.tracker
			list[i] = {
				id = tracker.id,
				order = tracker.order,
				module = tracker.module,
				frame = tracker.frame,
				point = placement.point,
				relativeTo = "dock",
				relativePoint = placement.relativePoint,
				x = placement.x,
				y = placement.y,
			}
		end
		return list
	end
	fake.dock = {
		stack = stack,
		point = function()
			return ns.dock:Anchor()
		end,
		drag = function(point)
			return ns.dock:Drop(point)
		end,
		reset = function()
			return ns.dock:Reset()
		end,
	}
end)

-- Onboarding (core/onboarding.md), on Core's wiring over fake.global.onboarding: fake.login adds the state when it's
-- missing, with letter by the history in fake.catchLog (ONB-R1, ONB-R2), then the character (PLAYER_GUID, ONB-R3),
-- after ModulesChanged as Core's login does. A returning Angler's welcome hook waits for the first SessionStarted or
-- fake.wait(20) (ONB-R2). `/pagle guide notes` (ONB-R80) and `/pagle dev onboarding reset` (ONB-R83) run through
-- fake.slash as Core's.
part(function(fake, _, ns, host)
	ns.WireOnboarding(host)
	fake.onboarding = ns.onboarding
	local login = fake.login
	function fake.login()
		login()
		ns.StartOnboarding()
	end
end)

-- The Field guide (core/onboarding.md › The Field guide), on Core's wiring: M:RegisterGuideStep, the guide's moves
-- and its hold. The fake's book draws no art: each page it would show lands in fake.guideShown, and each step's build
-- runs on the Module's client at its first showing (fake.guidePages), with widgets that are plain frames.
part(function(fake, _, ns, host)
	fake.guideShown, fake.guidePages, fake.guideHeld = {}, {}, false
	-- A plain frame of `kind` on `parent`, keeping what it was made with.
	local function made(kind, parent, fields)
		local frame = fake.clientEnv.CreateFrame(kind, nil, parent)
		for key, value in pairs(fields) do
			frame[key] = value
		end
		return frame
	end
	local widgets = {
		-- Its Refresh counts in `refreshed`, and SetGreyed keeps `greyed`, as the step called them (ONB-R44, ONB-R32).
		BindingField = function(parent, action, label)
			local field = made("Button", parent, { action = action, label = label, greyed = false, refreshed = 0 })
			function field.Refresh(self)
				self.refreshed = self.refreshed + 1
			end
			function field.SetGreyed(self, greyed)
				self.greyed = greyed
			end
			return field
		end,
		-- SetChosen keeps `chosen` (ONB-R32's current Input, ONB-R35's preset).
		ChoiceCard = function(parent, title, line, tag)
			local card = made("Button", parent, { title = title, line = line, tag = tag, chosen = false })
			function card.SetChosen(self, chosen)
				self.chosen = chosen
			end
			return card
		end,
		Note = function(parent, text, x, y, w, target, n)
			return made("Frame", parent, { text = text, x = x, y = y, w = w, target = target, n = n })
		end,
		Part = function(parent, sprite)
			local texture = parent:CreateTexture(nil, "ARTWORK")
			texture.sprite = sprite
			return texture
		end,
		-- The frame it was drawn on keeps `panel` and `panelCap`.
		Panel = function(frame, sprite, cap)
			frame.panel, frame.panelCap = sprite, cap
			return {
				SetShown = function() end,
				Hide = function() end,
				SetVertexColor = function() end,
			}
		end,
	}
	ns.WireGuide(host, {
		show = function(page, how)
			local id = page.entry.step.id
			fake.guideShown[#fake.guideShown + 1] = { id = id, how = how, index = page.index, count = page.count }
			if fake.clientEnv and not fake.guidePages[id] then
				local left = fake.clientEnv.CreateFrame("Frame")
				local right = fake.clientEnv.CreateFrame("Frame")
				left:SetSize(442, 546)
				right:SetSize(442, 546)
				local nav = ns.NewGuideNav(ns.guide, widgets)
				fake.guidePages[id] = { left = left, right = right, nav = nav }
				host.call(page.entry.step.build, left, right, nav)
			end
		end,
		close = function() end,
		hold = function()
			fake.guideHeld = true
		end,
		release = function()
			fake.guideHeld = false
		end,
		coreSteps = {},
	})
	fake.guide, fake.guideSteps = ns.guide, ns.guideSteps
end)

-- The Letter (core/onboarding.md › The Letter), on Core's wiring: M:SetDialogOpen on the handle (ONB-R100), the
-- checks on RestrictionChanged and the cards settling (ONB-R10, ONB-R14), and `/pagle dev onboarding letter`
-- (ONB-R83). The fake draws no frame: fake.letterOnScreen says whether it would show. A spec drives
-- PLAYER_ENTERING_WORLD's part itself (fake.letter:EnteredWorld()) and sets fake.inInstance.
part(function(fake, _, ns, host)
	fake.letterOnScreen, fake.inInstance = false, false
	ns.WireLetter(host, {
		show = function()
			fake.letterOnScreen = true
		end,
		hide = function()
			fake.letterOnScreen = false
		end,
		inInstance = function()
			return fake.inInstance
		end,
	})
	fake.letter = ns.letter
end)

-- The First evening list (core/onboarding.md › The First evening list), on Core's wiring: M:CompleteEveningItem on
-- the handle, Core's own items on CastStarted, Catch, SessionEnded and the shop opening, Off to the water and login.
-- Its tracker is a stand-in frame docked as Core's own at order 1, so fake.dock.stack() lists it while it shows; what
-- it would draw lands in fake.eveningList, each sound in fake.eveningSounds.
part(function(fake, _, ns, host)
	local frame = { shown = false }
	function frame:IsShown()
		return self.shown
	end
	-- The kit's tracker is 274 wide (adapter/Evening.lua); its height here stands for any.
	function frame.GetWidth()
		return 274
	end
	function frame.GetHeight()
		return 160
	end
	fake.eveningSounds = {}
	ns.WireEvening(host, {
		frame = frame,
		draw = function(list)
			fake.eveningList = list
			frame.shown = true
		end,
		hide = function()
			fake.eveningList = nil
			frame.shown = false
		end,
		fold = function()
			fake.eveningList = nil
			frame.shown = false
		end,
		sound = function(name)
			fake.eveningSounds[#fake.eveningSounds + 1] = name
		end,
	})
	fake.evening = ns.evening
end)

-- Margin notes (core/onboarding.md › Margin notes), on Core's wiring: M:ShowMarginNote validates as Core does, shows a
-- note once per account and only with Margin notes on (fake.global.onboarding), holds one raised while restricted
-- (fake.setRestricted) and drops it if its target hid, and takes it away after 12 s (fake.wait). The fake draws
-- nothing: each note Core would show lands in fake.notesShown, and fake.marginNotes:Showing() is what is on screen.
-- A target is shown while its IsVisible says so (a table without one always is). The onboarding hooks' notes point
-- at fake.menuButton, Pagle's menu button (ONB-R2, ONB-R3); nothing in the fake shows Announcements or cards, so
-- Core's first-moment notes never show here.
part(function(fake, _, ns, host)
	fake.notesShown = {}
	fake.menuButton = { name = "Pagle's menu button", shown = true }
	function fake.menuButton:IsVisible()
		return self.shown
	end
	ns.WireMarginNotes(host, {
		show = function(note)
			fake.notesShown[#fake.notesShown + 1] = note
		end,
		hide = function() end,
		place = function() end,
		isShown = function(note)
			local region = note.target
			if type(region) == "function" then
				region = region()
			end
			return region ~= nil and (type(region.IsVisible) ~= "function" or region:IsVisible() == true)
		end,
		coreTarget = function(key)
			if key == "menu" then
				return function()
					return fake.menuButton
				end
			end
			return nil
		end,
		isUncharted = function()
			return false
		end,
	})
	fake.marginNotes = ns.marginNotes
end)

-- First looks (core/onboarding.md › First looks), on Core's wiring: M:RegisterFirstLook validates as Core does, and
-- M:ShowFirstLook shows a set once per account with Margin notes on (fake.global.onboarding), or with `again` (the
-- "?", ONB-R59) seen or not. The fake draws nothing: each set Core would show lands in fake.looksShown, and
-- fake.firstLooks:Showing() is what is on screen. A target shows while its IsVisible says so (a table without one
-- always does). The set leaves as its window hides, through the window's OnHide where it has HookScript (a client
-- frame). No tour stops: Core's adapter adds those.
part(function(fake, _, ns, host)
	fake.looksShown = {}
	---@type table<string, true>
	local hooked = {}
	ns.WireFirstLooks(host, {
		show = function(set, entries)
			local notes = {}
			for i, entry in ipairs(entries) do
				notes[i] = { text = set.notes[entry.index].text, n = entry.n }
			end
			fake.looksShown[#fake.looksShown + 1] = { id = set.id, title = set.title, notes = notes }
			local window = ns.firstLooks:Window(set.id)
			if window and not hooked[set.id] and type(window.HookScript) == "function" then
				hooked[set.id] = true
				window:HookScript("OnHide", function()
					ns.firstLooks:WindowHidden(set.id)
				end)
			end
		end,
		renumber = function() end,
		hide = function() end,
		isShown = function(region)
			return type(region.IsVisible) ~= "function" or region:IsVisible() == true
		end,
	})
	fake.firstLooks = ns.firstLooks
end)

--- A fresh FakePagle: no Module registered, not restricted, before PLAYER_LOGIN.
---@return FakePagle
function newFakePagle()
	local ns, env = loadCoreLogic()
	-- Core's own projection (the Field report's) gets its records as the read-only proxies every projection gets here,
	-- through host.iterate and fake.live, and walks them with Core's logic: these see through a proxy, and on plain
	-- tables behave as the stock ones.
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
		iterate = function(afterSeq, module)
			local records = fake.catchLog:Iterate(afterSeq, module)
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
		region = function()
			return fake.region
		end,
		print = fake.print,
		isRestricted = function()
			return Pagle.IsRestricted()
		end,
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
		-- Pagle.Animate's driver and Pagle.FitToScreen's UIParent are this client's.
		fake.clientEnv = fake.clientEnv or loaded.env
		return loaded
	end
	return fake
end
