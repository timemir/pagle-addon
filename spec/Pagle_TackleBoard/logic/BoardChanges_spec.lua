-- Which moments of change a draw of the board plays (tackle-board.md › UI › Motion, › Sound; the board art kit's
-- MOTION.md › Moments of change), decided by logic/BoardChanges.lua's ns.BoardChanges over two plain snapshots of the
-- board, as adapter/BoardChanges.lua's ns.BoardSnapshot reads them. The pins' slots are plain strings here: the logic
-- only hands them back.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local changes = board.load().ns.BoardChanges

-- A snapshot: `pins` as { slot, id, fill } triples, and the rest as given.
---@param pins table[]
---@param rest table?
---@return TackleBoardShot
local function shot(pins, rest)
	local out = rest or {}
	out.hung = out.hung or {}
	out.pins = {}
	for i, pin in ipairs(pins) do
		out.pins[i] = { slot = pin[1], id = pin[2], fill = pin[3], busy = pin.busy }
	end
	return out
end

-- The moments' kinds and sounds, one string each: "kind", "(sound)" or "kind (sound)".
---@param moments TackleBoardMoment[]
---@return string[]
local function steps(moments)
	local out = {}
	for i, moment in ipairs(moments) do
		local parts = {}
		parts[#parts + 1] = moment.kind
		parts[#parts + 1] = moment.sound and ("(" .. moment.sound .. ")") or nil
		out[i] = table.concat(parts, " ")
	end
	return out
end

-- A lit Campfire at `stage` with `kindling` sticks of 3.
local function lit(stage, kindling)
	return { stage = stage, state = "lit", kindling = kindling, sticks = 3 }
end

describe("ns.BoardChanges (logic/BoardChanges.lua)", function()
	it("plays nothing when nothing changed", function()
		local before = shot({ { "e1", "a", 0.2 }, { "n1", "b", 0 } }, { fire = lit("3", 2), tied = 1, box = "1 of 30" })
		local after = shot({ { "e1", "a", 0.2 }, { "n1", "b", 0 } }, { fire = lit("3", 2), tied = 1, box = "1 of 30" })

		assert.are.same({}, changes(before, after, true))
	end)

	it("flies a goal done whose slip hangs on the spike, sounding the first one done once", function()
		local before = shot({ { "n1", "a", 0.5 }, { "n2", "b", 0.5 } })
		local after = shot({ { "n1", nil }, { "n2", nil } }, { hung = { a = true, b = true } })

		local moments = changes(before, after, true)

		assert.are.same({ "(noticeDone)", "goalDone", "goalDone" }, steps(moments))
		assert.are.same({ "n1", "a" }, { moments[2].slot, moments[2].goalID })
		assert.are.same({ "n2", "b" }, { moments[3].slot, moments[3].goalID })
	end)

	it("plays no goal done for a goal taken down, or for a pin a moment holds", function()
		local before = shot({ { "n1", "a" }, { "n2", "b" } })
		local after = shot({ { "n1", nil }, { "n2", nil, busy = true } }, { hung = { b = true } })

		assert.are.same({}, changes(before, after, true))
	end)

	it("drops a fresh goal onto its pin, the first pinned at once sounding its tack", function()
		local before = shot({ { "n1", "a" }, { "n2", nil }, { "n3", "c" } })
		local after = shot({ { "n1", "x" }, { "n2", "y" }, { "n3", "c" } })

		local moments = changes(before, after, true)

		assert.are.same({ "freshGoal", "freshGoal" }, steps(moments))
		assert.are.same({ "n1", true }, { moments[1].slot, moments[1].tack })
		assert.are.same({ "n2", false }, { moments[2].slot, moments[2].tack })
	end)

	it("inks in progress, its bar running from the old share to the new", function()
		local before = shot({ { "n1", "a", 0.25 } })
		local after = shot({ { "n1", "a", 0.5 } })

		local moments = changes(before, after, true)

		assert.are.same({ "inked" }, steps(moments))
		assert.are.same({ "n1", 0.25, 0.5 }, { moments[1].slot, moments[1].from, moments[1].to })
	end)

	it("steps the Campfire up, lights it, or puts it out, from the stage it was at", function()
		local up = changes(shot({}, { fire = lit("3", 2) }), shot({}, { fire = lit("7", 2) }), true)
		local out = changes(
			shot({}, { fire = lit("7", 2) }),
			shot({}, { fire = { stage = "out", state = "out", kindling = 0, sticks = 3 } }),
			true
		)

		assert.are.same({ "fireUp (fireUp)" }, steps(up))
		assert.are.equal("3", up[1].from)
		assert.are.same({ "fireOut (fireOut)" }, steps(out))
		assert.are.equal("7", out[1].from)
	end)

	it("burns each Kindling stick spent, sounding it once", function()
		local moments = changes(shot({}, { fire = lit("3", 3) }), shot({}, { fire = lit("3", 1) }), true)

		assert.are.same({ "(kindling)", "kindlingBurns", "kindlingBurns" }, steps(moments))
		assert.are.same({ 2, 3 }, { moments[2].stick, moments[3].stick })
	end)

	it("hops the Fly Box as a fly is tied, after a done slip lands, its sound at the hop", function()
		local before = shot({ { "n1", "a" } }, { fire = lit("3", 2), tied = 1, box = "1 of 30" })
		local after = shot({ { "n1", nil } }, { fire = lit("3", 2), tied = 2, box = "2 of 30", hung = { a = true } })

		local moments = changes(before, after, true)

		assert.are.same({ "(noticeDone)", "goalDone", "boxHops" }, steps(moments))
		assert.are.same({ "1 of 30", true, true }, { moments[3].from, moments[3].afterDone, moments[3].flyTied })
	end)

	it("settles each fly newly tied in an open drawer, sounding the tie at once and not at the hop", function()
		local before = shot({}, { fire = lit("3", 2), tied = 1, box = "1 of 30", cells = { true, false, false } })
		local after = shot({}, { fire = lit("3", 2), tied = 3, box = "3 of 30", cells = { true, true, true } })

		local moments = changes(before, after, true)

		assert.are.same({ "(flyTied)", "flySettles", "flySettles", "boxHops" }, steps(moments))
		assert.are.same({ 2, 3 }, { moments[2].cell, moments[3].cell })
		assert.are.same({ false, false }, { moments[4].afterDone, moments[4].flyTied })
	end)

	it("plays the pins' moments, then the Campfire's, then the Fly Box's", function()
		local before = shot({ { "e1", "a" }, { "n1", "b", 0.2 } }, { fire = lit("3", 2), tied = 1, box = "1 of 30" })
		local after = shot(
			{ { "e1", nil }, { "n1", "b", 0.4 } },
			{ fire = lit("7", 2), tied = 2, box = "2 of 30", hung = { a = true } }
		)

		assert.are.same(
			{ "(noticeDone)", "goalDone", "inked", "fireUp (fireUp)", "boxHops" },
			steps(changes(before, after, true))
		)
	end)

	it("with Animations off plays no moment, but marks each by its sound alone", function()
		local before = shot({ { "e1", "a" }, { "n1", nil }, { "n2", "c", 0.2 } }, { fire = lit("3", 3), tied = 1 })
		local after = shot(
			{ { "e1", nil }, { "n1", "y" }, { "n2", "c", 0.4 } },
			{ fire = lit("3", 2), tied = 2, hung = { a = true } }
		)
		local up = changes(shot({}, { fire = lit("3", 2) }), shot({}, { fire = lit("7", 2) }), false)

		assert.are.same({ "(noticeDone)", "(kindling)", "(flyTied)" }, steps(changes(before, after, false)))
		assert.are.same({ "(fireUp)" }, steps(up))
	end)

	it("leaves the Campfire and the Fly Box alone on a board drawn without its ledge", function()
		local before = shot({}, { tied = 1 })
		local after = shot({}, { tied = 2 })

		assert.are.same({}, changes(before, after, true))
	end)
end)
