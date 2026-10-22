---@class PagleNS
local ns = select(2, ...)
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle
local L = ns.L

local factories = {}
local ORDER = { "Ledger", "Stats", "Hunts", "TackleBoard" }
-- The Ledger folds last: its Angler Level reads the other parts' staged Activity XP.
local BUILD = { "Stats", "Hunts", "TackleBoard", "Ledger" }
local context, parts, captionFrame

--- Development-only recording adapters. Each Module owns its disposable state and its ordinary UI actions.
---@param name string
---@param factory fun(context: table): table
function Pagle.RegisterTrailerPart(name, factory)
	assert(not factories[name], "Duplicate Pagle trailer part: " .. name)
	factories[name] = factory
end

local function caption(text)
	if not text then
		if captionFrame then
			captionFrame:Hide()
		end
		return
	end
	if not captionFrame then
		captionFrame = CreateFrame("Frame", nil, UIParent)
		captionFrame:SetFrameStrata("DIALOG")
		captionFrame:SetSize(1000, 72)
		captionFrame:SetPoint("TOP", UIParent, "TOP", 0, -45)
		captionFrame:EnableMouse(false)
		captionFrame.label = captionFrame:CreateFontString(nil, "OVERLAY")
		captionFrame.label:SetFont("Interface\\AddOns\\Pagle\\media\\fonts\\Marcellus-Regular.ttf", 27, "")
		captionFrame.label:SetTextColor(1, 0.9, 0.68)
		captionFrame.label:SetShadowOffset(2, -2)
		captionFrame.label:SetShadowColor(0, 0, 0, 1)
		captionFrame.label:SetAllPoints()
		captionFrame.note = captionFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		captionFrame.note:SetPoint("TOP", captionFrame, "BOTTOM", 0, 4)
	end
	captionFrame.label:SetText(L[text])
	captionFrame.note:SetText(text == "TRAILER_CAPTION_CATCH" and L.TRAILER_LENGTH_NOTE or "")
	captionFrame:Show()
end

local function click(button)
	assert(button and button:IsShown(), "Pagle trailer control is not visible")
	local handler = button:GetScript("OnClick")
	assert(handler, "Pagle trailer control has no click action")
	handler(button, "LeftButton")
end

local function hide(frame)
	if frame then
		frame:Hide()
	end
end

local summary, goodID
local actions = {
	shop = function()
		goodID = "core.toaststyle.ripple"
		Pagle.OpenShop(goodID)
	end,
	["shop.preview"] = function()
		-- The native stage already draws the selected good's preview.
		Pagle.OpenShop(goodID)
	end,
	["shop.bill"] = function()
		click(ns.shopFrame.stage.buy)
	end,
	["shop.buy"] = function()
		click(ns.shopFrame.bill.buy)
	end,
	["shop.result"] = function()
		local announcement = assert(ns.DevPreviewAnnouncement("toast"))
		context.defer(function()
			ns.lanes:Withdraw(announcement)
		end)
		ns.lanes:Push(announcement)
	end,
	["shop.close"] = function()
		hide(ns.shopFrame)
	end,
	cozy = function()
		Pagle.OpenSettings("announcements")
	end,
	["cozy.on"] = function()
		ns.cozySetting:SetValue(true)
	end,
	["settings.close"] = function()
		HideUIPanel(SettingsPanel)
	end,
	summary = function()
		summary = {
			title = ns.L.CARD_SESSION,
			preview = true,
			numbers = { casts = 90, catches = 84, gotAway = 6, seconds = 1800 },
			coins = 30,
			lines = {
				{
					module = "Ledger",
					title = "Ledger",
					lines = { L.TRAILER_SUMMARY_LINE },
				},
			},
			moments = {
				{
					module = "Ledger",
					title = "Ledger",
					order = 10,
					moments = {
						{
							title = L.TRAILER_SUMMARY_TITLE,
							text = L.TRAILER_SUMMARY_TEXT,
							icon = context.item,
						},
					},
				},
			},
		}
		ns.cards:Preview(summary)
	end,
	["summary.close"] = function()
		if summary then
			ns.CloseCardOnScreen(summary)
		end
	end,
	report = function()
		Pagle.OpenFieldReport()
	end,
	["report.close"] = function()
		hide(ns.fieldReportBox)
	end,
}

local function installCore()
	local realDB, realGoods = ns.db, ns.goods
	ns.cards:Hold()
	context.swap(ns.cards, "Next", function() end)
	context.swap(ns, "db", ns.TrailerDB(realDB))
	local wallet = ns.NewWallet(ns.Fire)
	wallet:Open({})
	context.swap(ns, "wallet", wallet)
	-- Keep the registered slots and their native preview functions, with separate ownership and redraw bookkeeping.
	local goods = realGoods:PreviewCopy()
	context.swap(ns, "goods", goods)
	local purchased, spent = {}, 0
	context.swap(ns, "RecordPurchase", function(id, price)
		local entry = context.log:Append({
			kind = "purchase",
			char = ns.angler.current,
			time = GetServerTime(),
			good = id,
			price = price,
		})
		purchased[id], spent = true, spent + price
		goods:SetPurchased(purchased)
		wallet:SetSpent(spent)
		return entry
	end)
	local report = ns.NewFieldReport(ns.Catalogue)
	local state = report.reset()
	for _, record in ipairs(context.records) do
		report.apply(state, record)
	end
	context.swap(ns, "FieldReportRows", function()
		return report.Rows(state)
	end)
	ns.db.profile.announcements.cozy = false
	ns.db.profile.announcements.motion = true
	ns.db.profile.announcements.budget.on = false
	-- These restore after the Module adapters, so the final redraw reads the original views and wallet together.
	context.defer(function()
		if context.loggingOut then
			return
		end
		hide(ns.shopFrame)
		hide(ns.fieldReportBox)
		HideUIPanel(SettingsPanel)
		if summary then
			ns.CloseCardOnScreen(summary)
			summary = nil
		end
	end)
end

local originalPush
local trailer
trailer = ns.NewTrailer({
	after = function(seconds, fn)
		C_Timer.After(seconds, fn)
	end,
	caption = caption,
	print = print,
	report = function(problem)
		geterrorhandler()(problem)
	end,
	ready = function()
		if Pagle.IsRestricted() then
			return L.TRAILER_AFTER_COMBAT
		elseif not (ns.angler and ns.angler.current) then
			return L.TRAILER_NEEDS_ANGLER
		elseif ns.projections:IsUpdating() then
			return L.TRAILER_WAIT_HISTORY
		elseif not ns.lanes:IsEmpty() then
			return L.TRAILER_WAIT_ANNOUNCEMENTS
		end
		local active = {}
		for _, module in ipairs(ns.Modules:Modules()) do
			active[module.def.name] = true
		end
		for _, name in ipairs(ORDER) do
			if not (factories[name] and active[name]) then
				return L.TRAILER_ENABLE_MODULE:format(name)
			end
		end
		if not active.QoL then
			return L.TRAILER_ENABLE_MODULE:format("QoL")
		end
	end,
	prepare = function(restores)
		assert(not Pagle.IsRestricted(), L.TRAILER_AFTER_COMBAT)
		assert(ns.angler and ns.angler.current, L.TRAILER_NEEDS_ANGLER)
		assert(not ns.projections:IsUpdating(), L.TRAILER_WAIT_HISTORY)
		assert(ns.lanes:IsEmpty(), L.TRAILER_WAIT_ANNOUNCEMENTS)
		for _, name in ipairs(ORDER) do
			assert(factories[name], L.TRAILER_ENABLE_MODULE:format(name))
		end
		context = ns.NewTrailerHistory(
			ns.Catalogue,
			ns.catchLog.data.characters,
			ns.angler.current,
			Pagle.GetConditions(),
			GetServerTime()
		)
		local requested = {}
		for _, record in ipairs(context.records) do
			if record.kind == "cast" then
				for _, caught in ipairs(record.items) do
					if caught.itemID ~= 999999 and not requested[caught.itemID] then
						requested[caught.itemID] = true
						C_Item.RequestLoadItemDataByID(caught.itemID)
					end
				end
			end
		end
		context.copy, context.db, context.projection, context.click =
			ns.TrailerCopy, ns.TrailerDB, ns.TrailerProjection, click
		context.defer = function(fn)
			restores[#restores + 1] = fn
		end
		context.swap = function(owner, key, value)
			local old = rawget(owner, key)
			context.defer(function()
				owner[key] = old
			end)
			owner[key] = value
		end
		-- Core owns the disposable log; native module interactions keep their normal record-writing path.
		context.moduleRecords = function(module, name, applied)
			context.swap(module, "AppendRecord", function(_, kind, payload)
				local record = context.log:Append({
					kind = "module",
					module = name,
					recordKind = kind,
					payload = payload,
					char = context.cast.char,
					time = GetServerTime(),
				})
				applied(record)
				return record
			end)
		end
		context.coins = function(name, total)
			ns.wallet:Report(name, total)
		end
		-- Real fishing still records and earns everything normally. Its display is replaced by the staged opening.
		originalPush = ns.lanes.Push
		context.swap(ns.lanes, "Push", function() end)
		parts = {}
		context.defer(function()
			if not context.loggingOut then
				for _, slot in ipairs(ns.goods:Slots()) do
					ns.Fire("AppearanceChanged", slot.id, ns.goods:GetEquipped(slot.id))
				end
				ns.Fire("BalanceChanged", ns.wallet:Get())
				ns.cards:Next()
			end
			parts, context = nil, nil
		end)
	end,
	catch = function(cast)
		local item
		for _, caught in ipairs(cast.items) do
			local info = Pagle.GetItem(caught.itemID)
			if caught.size and info and info.species then
				item = caught.itemID
				break
			end
		end
		if not item then
			return false
		end
		context.item, context.zone = item, cast.conditions.zone
		-- This append is only to the sample. The real catch has already been recorded by Core, unchanged.
		context.cast = context.log:Append(cast)
		installCore()
		local conditions = context.copy(cast.conditions)
		conditions.skillRank, conditions.skillMod = 300, 25
		context.swap(Pagle, "GetConditions", function()
			return context.copy(conditions)
		end)
		local angler = context.copy(Pagle.GetAngler())
		angler.bestBaseSkill, angler.logId = 300, context.log.data.logId
		context.swap(Pagle, "GetAngler", function()
			return angler
		end)
		-- The sample's Activity XP, by source, for the Angler Level and "Where your XP came from".
		local bySource = {}
		context.xp = function(name, total)
			bySource[name] = { total = total, enabled = true }
		end
		context.swap(Pagle, "GetActivityXP", function()
			local copy, total = {}, 0
			for name, source in pairs(bySource) do
				copy[name] = { total = source.total, enabled = source.enabled }
				total = total + source.total
			end
			return { total = total, bySource = copy }
		end)
		for _, name in ipairs(BUILD) do
			parts[name] = factories[name](context)
		end
		-- Earned goods, such as the home water's zone crest, from the sample's states into the disposable cache.
		for _, name in ipairs(ORDER) do
			ns.goods:Refresh(name)
		end
		context.swap(Pagle, "GetSession", function()
			return ns.SessionPayload(context.log:Session())
		end)
		local this = context
		C_Timer.After(0, function()
			if context == this then
				ns.lanes.Push = originalPush
			end
		end)
		local moment = parts.Ledger.catch(context.cast)
		assert(moment, "The trailer opening catch did not produce a size record")
		moment.module, moment.moduleTitle, moment.moduleOrder, moment.raised = "Ledger", "Ledger", 10, GetTime()
		local announcement = assert(ns.MakeAnnouncement({ moment }))
		context.defer(function()
			ns.lanes:Withdraw(announcement)
		end)
		originalPush(ns.lanes, announcement)
		return true
	end,
	action = function(action)
		if actions[action] then
			actions[action]()
			return
		end
		local name, key = action:match("^(%w+)%.(.+)$")
		local part = parts[name]
		assert(part and part.actions[key], "Missing Pagle trailer action: " .. action)
		part.actions[key]()
	end,
})

-- Read by logic/Wiring.lua's isTouring: a running trailer's scenes aren't the Angler's first looks.
ns.trailer = trailer

--- `/pagle trailer [stop|status]`, separate from the screenshot-only `/pagle dev tour`.
---@param args string
function ns.RunTrailer(args)
	local command = args:match("^%s*(%S*)") or ""
	if command == "stop" then
		trailer:Stop(L.TRAILER_STOPPED)
	elseif command == "status" then
		print(L.TRAILER_STATUS:format(trailer.state))
	elseif command == "" then
		trailer:Arm()
	else
		print(L.TRAILER_USAGE)
	end
end

Pagle.RegisterCallback("Pagle trailer", "CastEnded", function(_, outcome, cast)
	if outcome == "caught" and cast then
		trailer:Catch(cast)
	end
end)
Pagle.RegisterCallback("Pagle trailer", "RestrictionChanged", function(_, restricted)
	if restricted and trailer.state ~= "idle" then
		trailer:Stop(L.TRAILER_COMBAT)
	end
end)
Pagle.RegisterCallback("Pagle trailer", "CastStarted", function()
	if trailer.state == "running" then
		trailer:Stop(L.TRAILER_NEW_CAST)
	end
end)
Pagle.RegisterEvent("Pagle trailer", "PLAYER_LOGOUT", function()
	if trailer.state ~= "idle" then
		if context then
			context.loggingOut = true
		end
		trailer:Stop()
	end
end)
