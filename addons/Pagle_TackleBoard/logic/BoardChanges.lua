if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Which moments of change a draw of the board plays (tackle-board.md › UI › Motion, › Sound; the board art kit's
-- MOTION.md › Moments of change): pure logic over what the board showed before the draw and what it shows after, as
-- adapter/BoardChanges.lua's ns.BoardSnapshot reads them off its frames, which then plays each moment and sound in turn.

--- One pin as the board showed it: its slot (whatever the adapter keys it by; never read here), the goal on it, its
--- bar's share and its words, and whether a moment holds it.
---@class TackleBoardShotPin
---@field slot any
---@field id string?
---@field fill number?
---@field progress string?
---@field busy boolean?

--- What the board showed at a draw, to tell what changed by the next (adapter/BoardChanges.lua's ns.BoardSnapshot).
---@class TackleBoardShot
---@field pins TackleBoardShotPin[]   -- every pin, the Expeditions' then the Notices', in the board's order
---@field hung table<string, boolean> -- the done goals whose slip hangs on the spike
---@field glow number?                -- the cork's light, nil while it is hidden
---@field fire { stage: string?, state: string?, kindling: integer?, glow: number?, sticks: integer }?
---@field tied integer?
---@field box string?                 -- the Fly Box's "{n} of 30 tied"
---@field tally string?
---@field spike string?               -- the spike's label
---@field cells boolean[]?            -- an open drawer's compartments, tied or not

--- One step of what a draw changed: a sound to play at once (a key of ns.BOARD_SOUNDS), a moment to play (`kind`), or
--- both. A moment names what it moves:
--- - "goalDone": the goal `goalID` on pin `slot` is stamped and flown to the spike, where its slip hangs;
--- - "freshGoal": a fresh goal drops onto pin `slot`, its tack sounded when `tack` (the first pinned at once);
--- - "inked": pin `slot`'s progress is inked in, its bar running from `from` to `to`;
--- - "fireUp", "fireOut": the Campfire steps up (or is lit), or goes out, from stage `from`;
--- - "kindlingBurns": Kindling stick `stick` flares and chars;
--- - "flySettles": the open drawer's compartment `cell` takes its fly;
--- - "boxHops": the Fly Box hops, its count ticking over from `from`, after a done slip has landed when `afterDone`,
---   with the fly-tied sound when `flyTied`.
---@class TackleBoardMoment
---@field sound string?
---@field kind string?
---@field slot any?
---@field goalID string?
---@field tack boolean?
---@field from any?
---@field to number?
---@field stick integer?
---@field cell integer?
---@field afterDone boolean?
---@field flyTied boolean?

--- What changed on the board from `before` to `after`, in the order it plays. With `moving` false (Core's Animations
--- setting off) no moment plays, but each one's sound marks it all the same, the beats of the motion aside: a goal done
--- sounds once however many land, the Campfire's change and a burned Kindling once each, and a fly tied once.
---@param before TackleBoardShot
---@param after TackleBoardShot
---@param moving boolean
---@return TackleBoardMoment[]
function ns.BoardChanges(before, after, moving)
	local moments = {} ---@type TackleBoardMoment[]
	local function add(moment)
		moments[#moments + 1] = moment
	end
	local landed, pinned = false, false
	for i, was in ipairs(before.pins) do
		local now = after.pins[i]
		if not now then
			break
		end
		if was.id and now.id == nil and not now.busy then
			if after.hung[was.id] then
				if not landed then
					add({ sound = "noticeDone" })
				end
				landed = true
				if moving then
					add({ kind = "goalDone", slot = now.slot, goalID = was.id })
				end
			end
		elseif moving and now.id and now.id ~= was.id then
			add({ kind = "freshGoal", slot = now.slot, tack = not pinned })
			pinned = true
		elseif moving and now.id and was.fill and now.fill ~= was.fill then
			add({ kind = "inked", slot = now.slot, from = was.fill, to = now.fill })
		end
	end

	local fire, was = after.fire, before.fire
	if not (fire and was and fire.state) then
		return moments
	end
	if fire.state == "lit" and was.stage and was.stage ~= fire.stage then
		add({ sound = "fireUp", kind = moving and "fireUp" or nil, from = was.stage })
	elseif fire.state == "out" and was.state == "lit" and was.stage then
		add({ sound = "fireOut", kind = moving and "fireOut" or nil, from = was.stage })
	elseif fire.state == "lit" and was.kindling and fire.kindling and fire.kindling < was.kindling then
		add({ sound = "kindling" })
		if moving then
			for stick = fire.kindling + 1, math.min(was.kindling, fire.sticks) do
				add({ kind = "kindlingBurns", stick = stick })
			end
		end
	end
	if before.tied and after.tied and after.tied > before.tied then
		local inDrawer = before.cells ~= nil and after.cells ~= nil
		if inDrawer or not moving then
			add({ sound = "flyTied" })
		end
		if moving and inDrawer then
			for cell, tied in ipairs(after.cells) do
				if tied and not before.cells[cell] then
					add({ kind = "flySettles", cell = cell })
				end
			end
		end
		if moving then
			add({ kind = "boxHops", from = before.box or "", afterDone = landed, flyTied = not inDrawer })
		end
	end
	return moments
end
