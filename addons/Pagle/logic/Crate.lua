---@class PagleNS
local ns = select(2, ...)

-- The Curio crate (wallet-and-shop.md › The Curio crate, SHOP-R50–R55): its pool, its price, odds, payback and Curio
-- pity, and the draw the wallet projection makes for each crate in the log, so every rebuild gives the same result
-- (SHOP-R51). Pure logic (CORE-R7): logic/WalletProjection.lua opens each crate, logic/Shop.lua shows the odds.

--- The crate's purchase entries' good ID (SHOP-R11, SHOP-R50): `U1|<header>|core.crate|<price>`.
ns.CRATE_ID = "core.crate"

--- The crate's price (Tunables): 1,500 Coins, its own and not a price tier's (SHOP-R50).
ns.CRATE_PRICE = 1500

--- The crate tiers in the order the draw walks them (SHOP-R51): a good's price tier 1 to 6, then Curio.
ns.CRATE_TIERS = { 1, 2, 3, 4, 5, 6, "curio" }

--- Each crate tier's odds in per mille, in CRATE_TIERS' order (Tunables): fixed, never rescaled (SHOP-R51).
ns.CRATE_ODDS = { 400, 260, 160, 100, 50, 25, 5 }

--- The pity (SHOP-R52, Tunables): the 100th crate in a row without a crate-only good is a Curio crate.
ns.CRATE_PITY = 100

-- The price tiers' prices as they stood at 1.0, frozen (SHOP-R53): a payback reads these, never ns.TIER_PRICES, so a
-- later price change never moves a balance (SHOP-R10).
local PAYBACK_PRICES = { 250, 400, 900, 3000, 10000, 25000 }

local TWO_32 = 2 ^ 32

--- One good of the crate pool (SHOP-R50, SHOP-R53): its ID, its crate tier (its price tier 1 to 6 as it joined the
--- pool, or "curio" for a crate-only good) and the kind of emblem the reel shows for it (after its slot).
---@class PagleCratePoolGood
---@field id string
---@field tier 1|2|3|4|5|6|"curio"
---@field kind "toaststyle"|"soundset"|"binding"|"trackerframe"|"crest"
---@field since? integer   -- the server time of the release that added it: a candidate only for crates bought from
--- then on (SHOP-R53); nil for the pool's first goods

--- The crate pool (SHOP-R50, Tunables): every good for sale and every crate-only good at 1.0, in the shop's order
--- (SHOP-R53): Core's slots as SHOP-R25 lists them (toast styles, sound sets, crests, bindings), then each Module's by
--- def.order, each slot's goods in registration order. A good joins only at the end, with `since`. A repo check
--- (spec/crate_pool_spec.lua) fails when a good for sale or crate only is missing from it, or a row's tier
--- or kind isn't its good's. A good in it need not be registered: the draw reads the log alone, so a crate can still
--- give it, and the shop shows it once it registers (SHOP-R50).
---@type PagleCratePoolGood[]
ns.CRATE_POOL = {
	{ id = "core.toaststyle.ripple", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.lanternglow", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.ship", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.birch", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.tidepool", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.chart", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.frost", tier = 1, kind = "toaststyle" },
	{ id = "core.toaststyle.goblin", tier = 2, kind = "toaststyle" },
	{ id = "core.toaststyle.kelp", tier = 2, kind = "toaststyle" },
	{ id = "core.toaststyle.moon", tier = 2, kind = "toaststyle" },
	{ id = "core.toaststyle.leaf", tier = 2, kind = "toaststyle" },
	{ id = "core.toaststyle.bottle", tier = 2, kind = "toaststyle" },
	{ id = "core.toaststyle.rune", tier = 3, kind = "toaststyle" },
	{ id = "core.toaststyle.folio", tier = 2, kind = "toaststyle" },
	{ id = "core.toaststyle.storm", tier = 4, kind = "toaststyle" },
	{ id = "core.toaststyle.foil", tier = "curio", kind = "toaststyle" },
	{ id = "core.toaststyle.hive", tier = 4, kind = "toaststyle" },
	{ id = "core.toaststyle.ooze", tier = 3, kind = "toaststyle" },
	{ id = "core.toaststyle.robot", tier = 3, kind = "toaststyle" },
	{ id = "core.toaststyle.spider", tier = 3, kind = "toaststyle" },
	{ id = "core.toaststyle.glacier", tier = 3, kind = "toaststyle" },
	{ id = "core.toaststyle.magma", tier = 4, kind = "toaststyle" },
	{ id = "core.toaststyle.arcane", tier = 4, kind = "toaststyle" },
	{ id = "core.toaststyle.pirate", tier = 3, kind = "toaststyle" },
	{ id = "core.soundset.gilded", tier = 2, kind = "soundset" },
	{ id = "core.soundset.rain", tier = 1, kind = "soundset" },
	{ id = "core.soundset.marimba", tier = 1, kind = "soundset" },
	{ id = "core.soundset.shipbell", tier = 1, kind = "soundset" },
	{ id = "core.soundset.squeaky", tier = 1, kind = "soundset" },
	{ id = "core.soundset.bubbleworks", tier = 1, kind = "soundset" },
	{ id = "core.soundset.kalimba", tier = 2, kind = "soundset" },
	{ id = "core.soundset.musicbox", tier = 2, kind = "soundset" },
	{ id = "core.soundset.glass", tier = 2, kind = "soundset" },
	{ id = "core.soundset.steelpan", tier = 2, kind = "soundset" },
	{ id = "core.soundset.dulcimer", tier = 2, kind = "soundset" },
	{ id = "core.soundset.goblintill", tier = 2, kind = "soundset" },
	{ id = "core.soundset.kazoo", tier = 2, kind = "soundset" },
	{ id = "core.soundset.arcade", tier = 2, kind = "soundset" },
	{ id = "core.soundset.boing", tier = 2, kind = "soundset" },
	{ id = "core.soundset.slime", tier = 2, kind = "soundset" },
	{ id = "core.soundset.frost", tier = 3, kind = "soundset" },
	{ id = "core.soundset.harp", tier = 3, kind = "soundset" },
	{ id = "core.soundset.gizmo", tier = 3, kind = "soundset" },
	{ id = "core.soundset.mrglglgl", tier = 3, kind = "soundset" },
	{ id = "core.soundset.parrot", tier = 3, kind = "soundset" },
	{ id = "core.soundset.laser", tier = 3, kind = "soundset" },
	{ id = "core.soundset.silithid", tier = 3, kind = "soundset" },
	{ id = "core.soundset.succubus", tier = 3, kind = "soundset" },
	{ id = "core.soundset.wardrums", tier = 4, kind = "soundset" },
	{ id = "core.soundset.dragonroost", tier = 4, kind = "soundset" },
	{ id = "core.binding.birch", tier = 1, kind = "binding" },
	{ id = "core.binding.chartlinen", tier = 1, kind = "binding" },
	{ id = "core.binding.sailcloth", tier = 1, kind = "binding" },
	{ id = "core.binding.oilskin", tier = 1, kind = "binding" },
	{ id = "core.binding.canvas", tier = 1, kind = "binding" },
	{ id = "core.binding.kraft", tier = 1, kind = "binding" },
	{ id = "core.binding.tartan", tier = 1, kind = "binding" },
	{ id = "core.binding.buckram", tier = 2, kind = "binding" },
	{ id = "core.binding.moss", tier = 2, kind = "binding" },
	{ id = "core.binding.driftwood", tier = 2, kind = "binding" },
	{ id = "core.binding.eelskin", tier = 2, kind = "binding" },
	{ id = "core.binding.kodo", tier = 2, kind = "binding" },
	{ id = "core.binding.frosthide", tier = 2, kind = "binding" },
	{ id = "core.binding.netcork", tier = 2, kind = "binding" },
	{ id = "core.binding.tooled", tier = 2, kind = "binding" },
	{ id = "core.binding.maplinen", tier = 2, kind = "binding" },
	{ id = "core.binding.planks", tier = 2, kind = "binding" },
	{ id = "core.binding.sharkskin", tier = 3, kind = "binding" },
	{ id = "core.binding.copper", tier = 3, kind = "binding" },
	{ id = "core.binding.velvet", tier = 3, kind = "binding" },
	{ id = "core.binding.turtle", tier = 3, kind = "binding" },
	{ id = "core.binding.morocco", tier = 3, kind = "binding" },
	{ id = "core.binding.verdigris", tier = 3, kind = "binding" },
	{ id = "core.binding.snakeskin", tier = 3, kind = "binding" },
	{ id = "core.binding.shagreen", tier = 3, kind = "binding" },
	{ id = "core.binding.lacquer", tier = 3, kind = "binding" },
	{ id = "core.binding.bone", tier = 3, kind = "binding" },
	{ id = "core.binding.brasscase", tier = 3, kind = "binding" },
	{ id = "core.binding.coral", tier = 4, kind = "binding" },
	{ id = "core.binding.scrimshaw", tier = 4, kind = "binding" },
	{ id = "core.binding.shagreenbone", tier = 4, kind = "binding" },
	{ id = "core.binding.pearl", tier = 5, kind = "binding" },
	{ id = "core.binding.trophycase", tier = 5, kind = "binding" },
	{ id = "hunts.trackerframe.inkwash", tier = 1, kind = "trackerframe" },
	{ id = "hunts.trackerframe.waxseal", tier = 2, kind = "trackerframe" },
	{ id = "hunts.trackerframe.slate", tier = 1, kind = "trackerframe" },
	{ id = "hunts.trackerframe.mapscrap", tier = 1, kind = "trackerframe" },
	{ id = "hunts.trackerframe.bounty", tier = 2, kind = "trackerframe" },
	{ id = "hunts.trackerframe.spyglass", tier = 3, kind = "trackerframe" },
	{ id = "stats.trackerframe.logbook", tier = 1, kind = "trackerframe" },
	{ id = "stats.trackerframe.brass", tier = 2, kind = "trackerframe" },
	{ id = "stats.trackerframe.greenbar", tier = 1, kind = "trackerframe" },
	{ id = "stats.trackerframe.chalkboard", tier = 1, kind = "trackerframe" },
	{ id = "stats.trackerframe.tidegauge", tier = 2, kind = "trackerframe" },
	{ id = "stats.trackerframe.abacus", tier = 2, kind = "trackerframe" },
	{ id = "stats.trackerframe.astrolabe", tier = 3, kind = "trackerframe" },
	{ id = "tackleboard.trackerframe.corkboard", tier = 1, kind = "trackerframe" },
	{ id = "tackleboard.trackerframe.driftwood", tier = 2, kind = "trackerframe" },
	{ id = "tackleboard.trackerframe.net", tier = 1, kind = "trackerframe" },
	{ id = "tackleboard.trackerframe.bamboo", tier = 1, kind = "trackerframe" },
	{ id = "tackleboard.trackerframe.tin", tier = 2, kind = "trackerframe" },
	{ id = "tackleboard.trackerframe.bobber", tier = 2, kind = "trackerframe" },
}

--- What a crate gave (SHOP-R51): the crate tier it rolled, and the good, or, with no candidate left in that tier, the
--- Coins paid back.
---@class PagleCrateResult
---@field tier 1|2|3|4|5|6|"curio"
---@field good? string       -- the good it gave
---@field crateOnly? true    -- the good is crate only (SHOP-R52)
---@field payback? integer   -- the Coins it paid back (SHOP-R51)

-- Whether `row` is in the pool by `time` (SHOP-R53).
---@param row PagleCratePoolGood
---@param time integer?
---@return boolean
local function inPool(row, time)
	return row.since == nil or (time ~= nil and time >= row.since)
end

--- The candidates of crate tier `tier` for a crate bought at `time` (SHOP-R51): its pool goods that are in the pool by
--- then and not in `owned` (what earlier purchases and crates gave), in pool order.
---@param tier 1|2|3|4|5|6|"curio"
---@param owned table<string, true>
---@param time integer?
---@return PagleCratePoolGood[]
function ns.CrateCandidates(tier, owned, time)
	local found = {}
	for _, row in ipairs(ns.CRATE_POOL) do
		if row.tier == tier and not owned[row.id] and inPool(row, time) then
			found[#found + 1] = row
		end
	end
	return found
end

--- Whether any pool good in the pool by `time` is a candidate (SHOP-R54): the Buy's first condition, and the crate's
--- row staying in the list.
---@param owned table<string, true>
---@param time integer?
---@return boolean
function ns.CrateHasCandidates(owned, time)
	for _, row in ipairs(ns.CRATE_POOL) do
		if not owned[row.id] and inPool(row, time) then
			return true
		end
	end
	return false
end

--- What a crate of price `price` pays back when it rolls `tier` with no candidate (SHOP-R51): the tier's 1.0 price,
--- or for Curio nothing of its own, capped by the crate's price.
---@param tier 1|2|3|4|5|6|"curio"
---@param price integer
---@return integer
function ns.CratePayback(tier, price)
	local tierPrice = PAYBACK_PRICES[
		tier --[[@as integer]]
	]
	return tierPrice and math.min(tierPrice, price) or price
end

--- The crate tier the odds give for the hash `h` of the entry ID (SHOP-R51): the first of CRATE_TIERS whose running
--- odds satisfy `running × 2^32 > h × 1000`, in whole numbers so every step is exact below 2^53.
---@param h integer
---@return 1|2|3|4|5|6|"curio"
local function tierOf(h)
	local running = 0
	for i, tier in ipairs(ns.CRATE_TIERS) do
		running = running + ns.CRATE_ODDS[i]
		if running * TWO_32 > h * 1000 then
			return tier
		end
	end
	return "curio"
end

--- The crate whose purchase entry has the ID `entryID`, bought at `time` for `price`, as the draw opens it (SHOP-R51,
--- SHOP-R52): its crate tier by the entry ID's hash, or Curio at the pity (`dry` crates in a row without a crate-only
--- good, CRATE_PITY - 1 or more, while a crate-only good is a candidate); then the candidate of that tier at position
--- `⌊h(entry ID .. "/good") × n / 2^32⌋ + 1`, or with none the Coins paid back.
---@param entryID string the crate's U1 entry ID (LOG-R13)
---@param owned table<string, true>
---@param dry integer
---@param time integer?
---@param price integer the crate's price, the U1's
---@return PagleCrateResult
function ns.CrateRoll(entryID, owned, dry, time, price)
	local tier = tierOf(ns.SizeHash(entryID))
	if (dry or 0) >= ns.CRATE_PITY - 1 and #ns.CrateCandidates("curio", owned, time) > 0 then
		tier = "curio"
	end
	local candidates = ns.CrateCandidates(tier, owned, time)
	local n = #candidates
	if n == 0 then
		return { tier = tier, payback = ns.CratePayback(tier, price) }
	end
	local row = candidates[math.floor(ns.SizeHash(entryID .. "/good") * n / TWO_32) + 1]
	return { tier = tier, good = row.id, crateOnly = row.tier == "curio" or nil }
end

--- One crate tier on the crate's stage (SHOP-R54).
---@class PagleCrateTierOdds
---@field tier 1|2|3|4|5|6|"curio"
---@field permille integer     -- its fixed odds
---@field left integer         -- its goods left: its candidates
---@field payback? integer     -- what the next crate pays back when it rolls the tier with none left

--- The odds of each crate tier for the next crate, in CRATE_TIERS' order (SHOP-R54): its odds, its goods left in the
--- pool by `now`, and with none left what it would pay back at the crate's price now.
---@param owned table<string, true>
---@param now integer?
---@return PagleCrateTierOdds[]
function ns.CrateOdds(owned, now)
	local odds = {}
	for i, tier in ipairs(ns.CRATE_TIERS) do
		local left = #ns.CrateCandidates(tier, owned, now)
		odds[i] = {
			tier = tier,
			permille = ns.CRATE_ODDS[i],
			left = left,
			payback = left == 0 and ns.CratePayback(tier, ns.CRATE_PRICE) or nil,
		}
	end
	return odds
end

--- How many more crates at most until a crate-only good comes (SHOP-R52, SHOP-R54): CRATE_PITY less the crates in a
--- row without one, at least 1; nil when no crate-only good in the pool by `now` is a candidate.
---@param owned table<string, true>
---@param dry integer
---@param now integer?
---@return integer?
function ns.CratePityLeft(owned, dry, now)
	if #ns.CrateCandidates("curio", owned, now) == 0 then
		return nil
	end
	return math.max(ns.CRATE_PITY - (dry or 0), 1)
end
