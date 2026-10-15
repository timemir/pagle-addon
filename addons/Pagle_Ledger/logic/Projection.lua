if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's one projection (LED-R2): the def it hands `M:NewProjection`, over the fold (LED-R3). Pure logic,
-- everything passed in (CORE-R7).

--- The projection's rules version (LED-R2): `LEDGER_RULES_VERSION × 100 + Pagle.SIZE_RULES_VERSION`. Core declared
--- no `SIZE_RULES_VERSION` before M4's Simulated Sizes (LOG-R68), so a missing one counts as 0, as M2's 100 and M3's
--- 200 were stored.
---@param sizeRulesVersion integer? Pagle.SIZE_RULES_VERSION
---@return integer
function ns.RulesVersion(sizeRulesVersion)
	return ns.LEDGER_RULES_VERSION * 100 + (sizeRulesVersion or 0)
end

--- Core's lookups the Ledger reads (LOG-R55, LOG-R49), from the Pagle API, with the world index built over them
--- (LED-R10) as `world`. Build it where the catalogue is ready (CORE-R10).
---@param pagle table the Pagle API
---@return LedgerLookups
function ns.LedgerLookups(pagle)
	local lookups = {
		GetItem = pagle.GetItem,
		GetZones = pagle.GetZones,
		GetArea = pagle.GetArea,
		GetZoneCatches = pagle.GetZoneCatches,
		MatchesConditions = pagle.MatchesConditions,
	}
	lookups.world = ns.NewWorld(lookups)
	return lookups
end

--- The Ledger's projection for Pagle's backend (#223, #76 item 5), whose projection driver folds the Catch log through
--- logic/ alone, without adapter/ or locale/ (CORE-R7). Binds it with `M:NewProjection` over a table of its own
--- making: the fold of ns.ProjectionDef with the same rules version, so the same state, and none of what the client
--- does besides (moments, Write-ups, Coins reports, the summary line, goods; LED-R89–R98), which the driver drops.
--- The client's adapter never calls it. It also sets ns.world, which the derived values read (logic/Derived.lua).
---@param M PagleModuleHandle
---@return PagleProjection
function ns.BindProjections(M)
	-- The driver hands over only M, so Core's lookups come from the Pagle API it hosts.
	local pagle = Pagle -- luacheck: read globals Pagle (#223: the backend's driver passes no Core)
	local lookups = ns.LedgerLookups(pagle)
	ns.world = lookups.world
	local fold = ns.NewLedgerFold(lookups)
	return M:NewProjection({
		db = {},
		rulesVersion = ns.RulesVersion(pagle.SIZE_RULES_VERSION),
		reset = fold.reset,
		apply = function(state, record, mode)
			fold.apply(state, record, mode)
		end,
	})
end

--- A Ledger state's lifetime Coins earned (SHOP-R2, LED-R2), as the Ledger reports them with M:ReportCoinsEarned:
--- for Pagle's backend (#223), read after done.
---@param state LedgerState
---@return integer
function ns.CoinsEarned(state)
	return state.coins
end

--- The Ledger's projection def (LED-R2, LOG-R70), bound to `global.projection`, which it makes if missing: Core
--- owns it from here on. `apply` is the fold's, the same in every mode (LED-R3); it ignores every kind but Casts,
--- Skill Readings and Prestiges. No `extraFingerprint`, and no Sessions read.
---
--- A `"live"` entry's achievements are celebrated as it is applied (LED-R91): their moments raised, Coins reported
--- and the summary line set through `outlets`. A `"replay"` or `"rebuild"` entry's go to the scratch list (LED-R98),
--- which `reset` and `done` clear; `done` reads it (LED-R93, logic/Done.lua).
---@param global table PagleLedgerDB's global section
---@param lookups LedgerLookups Core's lookups
---@param outlets LedgerOutlets
---@param sizeRulesVersion integer? Pagle.SIZE_RULES_VERSION
---@return PagleProjectionDef
function ns.ProjectionDef(global, lookups, outlets, sizeRulesVersion)
	if type(global.projection) ~= "table" then
		global.projection = {}
	end
	local fold = ns.NewLedgerFold(lookups)
	---@type LedgerAchievement[]
	local scratch = {}
	---@type string? the summary line as last set this login
	local summaryLine

	-- Sets the summary line when its text changed (LED-R95).
	---@param state LedgerState
	---@param celebrated LedgerCelebrated
	local function setSummaryLine(state, celebrated)
		local text = ns.SummaryLine(state, celebrated, lookups)
		if text ~= summaryLine then
			summaryLine = text
			outlets.SetSummaryLine(text)
		end
	end

	-- One `"live"` entry (LED-R89–R91, LED-R95, LED-R96): every moment it earns is raised while it is applied, so a
	-- Cast's merge into one Announcement. In combat too: Core holds them (LED-R193).
	---@param state LedgerState
	---@param record PagleRecord
	local function applyLive(state, record)
		local coins, peak = state.coins, ns.PeakLevel(state)
		local earned = fold.apply(state, record, "live")
		local celebrated = ns.CelebratedSet(global)
		for _, moment in ipairs(ns.Celebrate(celebrated, state, record, earned, outlets, lookups)) do
			outlets.RaiseMoment(moment)
		end
		celebrated.coins = state.coins
		if state.coins ~= coins then
			outlets.ReportCoinsEarned(state.coins)
		end
		-- A level binding may be earned now (LED-R111, SHOP-R31).
		if ns.LevelBindingCrossed(peak, ns.PeakLevel(state)) then
			outlets.RefreshGoods()
		end
		-- The shown level and completion change only with an achievement (a level-up, a first Catch, a rank), so an
		-- entry that earned none leaves the line as it is, once set.
		if #earned > 0 or not summaryLine then
			setSummaryLine(state, celebrated)
		end
	end

	return {
		db = global.projection,
		rulesVersion = ns.RulesVersion(sizeRulesVersion),
		reset = function()
			scratch = {}
			return fold.reset()
		end,
		apply = function(state, record, mode)
			if mode == "live" then
				applyLive(state, record)
			else
				local from = #scratch
				fold.apply(state, record, mode, scratch)
				-- Each level-up keeps its climb, so done merges them per climb (LED-R36, LED-R93).
				for i = from + 1, #scratch do
					if scratch[i].kind == "levelUp" then
						scratch[i].rank = state.prestige
					end
				end
			end
		end,
		-- LED-R93: the first build's, rebuild's or catch-up's celebration, then Coins, the goods and the summary line.
		done = function(state, info)
			local celebrated = ns.CelebrateDone(global, state, scratch, info, outlets, lookups)
			scratch = {}
			outlets.RefreshGoods() -- the level bindings, never mid-rebuild (LED-R111, SHOP-R31)
			setSummaryLine(state, celebrated)
		end,
	}
end
