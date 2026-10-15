-- The Tackle Board's projection for Pagle's backend (#223): ns.BindProjections and ns.CoinsEarned
-- (logic/Projection.lua), on FakePagle over the fixture catalogue. The backend's driver folds the Catch log through
-- logic/ alone (spec/logic_alone_spec.lua), so the binding must fold a started board as the client's projection does.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local start, issue, cast, withHistory, built = board.start, board.issue, board.cast, board.withHistory, board.built

local DUROTAR = 14
local BLACKMOUTH = 6358
-- A Notice and an Expedition each done by one Catch in Durotar, paying 10 and 60 (tackle-board.md › Data).
local ONE = "n;haul;1;10;1;14"
local ONE_E = "e;haul;0;60;1;14"
local T = board.DAY0 + 3600

-- A started board whose Notice and Expedition are both done.
local function history()
	return {
		start(T),
		issue(T + 1, ONE),
		cast(T + 2, DUROTAR, { BLACKMOUTH }),
		issue(T + 3, ONE_E),
		cast(T + 4, DUROTAR, { BLACKMOUTH }),
	}
end

-- The Tackle Board loaded on a fake with `history()`, its OnInitialize replaced by what the backend's driver does:
-- register, then ns.BindProjections, with no ns.api (the driver loads no adapter/). Logged in and built.
---@return PagleProjection bound
---@return PagleTackleBoardNS ns
local function boundByBackend()
	local fake = withHistory(history())
	local bound
	local ns = built(fake, {
		prepare = function(loaded)
			local ns = loaded.ns
			ns.TackleBoard.OnInitialize = function()
				ns.api = nil
				bound = ns.BindProjections(fake.Pagle.RegisterModule(ns.ModuleDef()))
			end
		end,
	})
	return bound, ns
end

describe("the Tackle Board's projection for the backend (#223)", function()
	it("folds a started board to the state the client's projection holds", function()
		local client = built(withHistory(history()))
		local bound = boundByBackend()

		assert.are.same(client.State(), bound:GetState())
	end)

	it("gives the lifetime Coins earned: 10 for the Notice and 60 for the Expedition (TKB-R63, SHOP-R2)", function()
		local bound, ns = boundByBackend()

		assert.are.equal(70, ns.CoinsEarned(bound:GetState() --[[@as TackleBoardState]]))
	end)
end)
