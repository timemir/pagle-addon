---@class PagleNS
local ns = select(2, ...)

-- The Curio crate (wallet-and-shop.md › The Curio crate, SHOP-R50–R55): its pool, its weights and pity, and the draw
-- the wallet projection makes for each crate in the log, so every rebuild gives the same goods (SHOP-R51). Pure logic
-- (CORE-R7): logic/WalletProjection.lua opens each crate, logic/Shop.lua shows the odds.

--- The crate's purchase entries' good ID (SHOP-R11, SHOP-R50): `U1|<header>|core.crate|<price>`.
ns.CRATE_ID = "core.crate"

--- The crate's price tier (Tunables): tier 4, 2,000 Coins.
ns.CRATE_TIER = 4

--- One good of the crate pool (SHOP-R50, SHOP-R53).
---@class PagleCratePoolGood
---@field id string
---@field crateOnly? true  -- given by a crate alone (SHOP-R22)
---@field since? integer   -- the server time of the release that added it: a candidate only for crates bought from
--- then on (SHOP-R53); nil for the pool's first goods

--- The crate pool (SHOP-R50, Tunables), in its frozen order (SHOP-R53): a good joins only at its end, with `since`.
--- A good in it need not be registered yet (today's three are, Shagreen and Bone in Core's binding slot): the draw
--- reads the log alone, so a crate can still give it, and the shop shows it once it registers.
---@type PagleCratePoolGood[]
ns.CRATE_POOL = {
	{ id = "core.toaststyle.foil", crateOnly = true },
	{ id = "core.toaststyle.storm" },
	{ id = "core.binding.shagreenbone" },
	-- The third round's grandest toast style (ANN-R84), for sale at tier 5 too; the pool had no crate in the log yet.
	{ id = "core.toaststyle.arcane" },
}

--- Each candidate's weight (SHOP-R51, Tunables): a crate-only good 1, any other 2. Frozen once shipped (SHOP-R53).
ns.CRATE_WEIGHTS = { crateOnly = 1, other = 2 }

--- The pity (SHOP-R52, Tunables): a crate-only good comes by this crate at the latest.
ns.CRATE_PITY = 8

local TWO_32 = 2 ^ 32

--- One candidate for the next crate.
---@class PagleCrateCandidate
---@field id string
---@field crateOnly boolean
---@field weight integer

--- The candidates for a crate bought at `time` (SHOP-R51, SHOP-R52): the pool goods not in `owned` (the goods earlier
--- purchases and crates gave) that are in the pool by then, in pool order, each with its weight; but when the last
--- `dry` crates in a row (CRATE_PITY - 1 or more) gave no crate-only good and one is still unowned, the unowned
--- crate-only goods alone. Empty when the Angler owns every one.
---@param owned table<string, true>
---@param dry integer
---@param time integer?
---@return PagleCrateCandidate[]
function ns.CrateCandidates(owned, dry, time)
	local open, crateOnly = {}, {}
	for _, good in ipairs(ns.CRATE_POOL) do
		if not owned[good.id] and (good.since == nil or (time ~= nil and time >= good.since)) then
			local only = good.crateOnly == true
			local candidate = {
				id = good.id,
				crateOnly = only,
				weight = only and ns.CRATE_WEIGHTS.crateOnly or ns.CRATE_WEIGHTS.other,
			}
			open[#open + 1] = candidate
			if only then
				crateOnly[#crateOnly + 1] = candidate
			end
		end
	end
	if (dry or 0) >= ns.CRATE_PITY - 1 and #crateOnly > 0 then
		return crateOnly
	end
	return open
end

--- The good the crate whose purchase entry has the ID `entryID` gives (SHOP-R51): with `u` LOG-R66's frozen hash of
--- the entry ID over 2^32, the first candidate whose running share of the candidates' total weight is above `u`, and
--- whether it is crate only. Nil when there is no candidate: the Angler owns the whole pool.
---@param entryID string the crate's U1 entry ID (LOG-R13)
---@param owned table<string, true>
---@param dry integer
---@param time integer?
---@return string? goodID
---@return boolean crateOnly
function ns.CrateDraw(entryID, owned, dry, time)
	local candidates = ns.CrateCandidates(owned, dry, time)
	local total = 0
	for _, candidate in ipairs(candidates) do
		total = total + candidate.weight
	end
	if total == 0 then
		return nil, false
	end
	local u = ns.SizeHash(entryID) / TWO_32
	local running = 0
	for _, candidate in ipairs(candidates) do
		running = running + candidate.weight
		if running / total > u then
			return candidate.id, candidate.crateOnly
		end
	end
	local last = candidates[#candidates]
	return last.id, last.crateOnly
end

--- One pool good's odds for the next crate (SHOP-R54).
---@class PagleCrateOdds
---@field id string
---@field owned boolean        -- owned already: no chance, struck through on the stage
---@field chance number        -- its chance of coming next, 0 to 1

--- Each pool good in the pool by `now`, in pool order, with its chance of coming in the next crate (SHOP-R54): its
--- weight's share of the candidates' total, 0 for one owned or left out by the pity.
---@param owned table<string, true>
---@param dry integer
---@param now integer?
---@return PagleCrateOdds[]
function ns.CrateOdds(owned, dry, now)
	local candidates = ns.CrateCandidates(owned, dry, now)
	local total, weights = 0, {}
	for _, candidate in ipairs(candidates) do
		total = total + candidate.weight
		weights[candidate.id] = candidate.weight
	end
	local odds = {}
	for _, good in ipairs(ns.CRATE_POOL) do
		if good.since == nil or (now ~= nil and now >= good.since) then
			odds[#odds + 1] = {
				id = good.id,
				owned = owned[good.id] == true,
				chance = total > 0 and (weights[good.id] or 0) / total or 0,
			}
		end
	end
	return odds
end

--- How many more crates at most until a crate-only good comes (SHOP-R52, SHOP-R54): CRATE_PITY less the crates in a
--- row without one, at least 1; nil when every crate-only good in the pool by `now` is owned.
---@param owned table<string, true>
---@param dry integer
---@param now integer?
---@return integer?
function ns.CratePityLeft(owned, dry, now)
	for _, good in ipairs(ns.CRATE_POOL) do
		if good.crateOnly and not owned[good.id] and (good.since == nil or (now ~= nil and now >= good.since)) then
			return math.max(ns.CRATE_PITY - (dry or 0), 1)
		end
	end
	return nil
end
