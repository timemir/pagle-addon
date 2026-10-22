-- The Tackle Board's generated lore (DATA-R104, TKB-R130): addons/Pagle_TackleBoard/data/Lore.lua adds to ns.L the
-- name of each of the Fly Box's 30 patterns, the text of each of the board's 8 titles and the name and description of
-- each of its 9 goods (its 8 tracker frames and Hearth Ember), from data/lore/tackleboard.toml: the M7 batch
-- (DATA-R111), with the Curio Shop expansion's goods (TKB-R125, TKB-R126).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- tackle-board.md › Data: the Fly Box's patterns in pattern order (TKB-R62), the titles and the goods (TKB-R125,
-- TKB-R126).
local PATTERNS = {
	"murloc_nymph",
	"westfall_wheatwing",
	"goldshire_gnat",
	"duskwood_shadow",
	"redridge_ember",
	"barrens_dun",
	"mudsnout_woolly",
	"gnomish_whirligig",
	"tarnished_spoon",
	"ashenvale_olive",
	"kodo_hair_caddis",
	"elwynn_royal",
	"swamp_midge",
	"raptor_quill",
	"silverpine_spinner",
	"lakeshire_coachman",
	"bloodsail_streamer",
	"booty_bay_bucktail",
	"desolace_drifter",
	"grimtotem_hackle",
	"needles_ant",
	"feralas_fern",
	"tanaris_sandfly",
	"darkshore_dun",
	"nats_golden_doctor",
	"kraken_ink_streamer",
	"phoenix_hackle",
	"moonwell_silverwing",
	"thunderhead_tiger",
	"deepwater_duchess",
}
local TITLES =
	{ "tally_25", "tally_100", "tally_500", "campfire_7", "campfire_30", "campfire_100", "campfire_365", "flybox" }
local GOODS = {
	"tackleboard.trackerframe.none",
	"tackleboard.trackerframe.corkboard",
	"tackleboard.trackerframe.driftwood",
	"tackleboard.trackerframe.net",
	"tackleboard.trackerframe.bamboo",
	"tackleboard.trackerframe.tin",
	"tackleboard.trackerframe.bobber",
	"tackleboard.trackerframe.embers",
	"tackleboard.toaststyle.ember",
}

-- Every lore key the batch must hold (TKB-R130's Lore keys): 30 + 8 + 9 × 2 = 56.
local function loreKeys()
	local keys = {}
	for _, pattern in ipairs(PATTERNS) do
		keys[#keys + 1] = ("fly.%s.name"):format(pattern)
	end
	for _, title in ipairs(TITLES) do
		keys[#keys + 1] = ("boardtitle.%s.text"):format(title)
	end
	for _, good in ipairs(GOODS) do
		keys[#keys + 1] = ("boardgood.%s.name"):format(good)
		keys[#keys + 1] = ("boardgood.%s.description"):format(good)
	end
	return keys
end

describe("the Tackle Board's committed lore (DATA-R111, its M7 batch)", function()
	local ns

	setup(function()
		ns = board.load(nil, { lore = true }).ns
	end)

	it("holds all 56 lines once Pagle_TackleBoard loads: every fly name, title text and good (TKB-R130)", function()
		local keys = loreKeys()
		assert.are.equal(56, #keys)
		for _, key in ipairs(keys) do
			local value = rawget(ns.L, key)
			assert(type(value) == "string" and value:find("%S"), key .. " has no text")
		end
	end)

	it("names the same patterns as the shipped Fly Box, ns.FLY_PATTERNS, in its order (TKB-R62)", function()
		local ids = {}
		for _, pattern in ipairs(ns.FLY_PATTERNS) do
			ids[#ids + 1] = pattern.id
		end
		assert.are.same(PATTERNS, ids)
	end)

	it("gives a text to the same titles as the shipped ns.TITLES, in its order (TKB-R61, TKB-R73)", function()
		local ids = {}
		for _, title in ipairs(ns.TITLES) do
			ids[#ids + 1] = title.id
		end
		assert.are.same(TITLES, ids)
	end)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		assert.are.equal("Tackle Board", ns.L.TITLE)
	end)
end)
