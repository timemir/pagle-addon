if not Pagle or not Pagle.RegisterTrailerPart then
	return
end
---@class PagleTackleBoardNS
local ns = select(2, ...)

Pagle.RegisterTrailerPart("TackleBoard", function(ctx)
	local state = ns.NewBoardState()
	-- Fold the sample without celebrating it into the real account's scratch tally or summary.
	local outlets = ns.outlets
	ns.outlets =
		{ Completed = function() end, Advanced = function() end, Done = function() end, Stepped = function() end }
	local ok, problem = pcall(function()
		for _, record in ipairs(ctx.records) do
			ns.ApplyEntry(state, record, "rebuild")
		end
	end)
	ns.outlets = outlets
	assert(ok, problem)
	ctx.defer(function()
		if ctx.loggingOut then
			return
		end
		ns.board:Hide()
		ns.BoardHoverHide()
		ns.Redraw("trailer-end")
		ns.LiveStep() -- resume the real board's reset schedule if a reset happened during the recording
	end)
	ctx.swap(ns, "db", ctx.db(ns.db))
	ctx.swap(ns, "projection", ctx.projection(state))
	ns.db.profile.tracker = true
	ns.db.profile.trackerCollapsed = false
	ctx.coins("TackleBoard", state.coins)
	ctx.xp("TackleBoard", state.xp)
	-- The actual Take it down handler writes a record. During this display, that record belongs to the sample only.
	ctx.moduleRecords(ns.Module, "TackleBoard", function(record)
		ns.ApplyEntry(state, record, "live")
		ctx.coins("TackleBoard", state.coins)
		ctx.xp("TackleBoard", state.xp)
		ns.Redraw("projection")
	end)
	---@return TackleLedgeFrame
	local function ledge()
		return ns.board.frame.parts.ledge --[[@as TackleLedgeFrame]]
	end
	return {
		actions = {
			open = function()
				ns.OpenBoard()
			end,
			replace = function()
				for _, id in ipairs(state.pins.notices) do
					local goal = id and state.goals[id]
					if id and goal and ns.CanTakeDown(id) then
						ns.TakeDown(id)
						local confirm = ns.TakeDownConfirm()
						if confirm and confirm:IsShown() then
							ctx.click(confirm.accept)
						end
						return
					end
				end
				error("No Notice can be replaced in the trailer sample")
			end,
			flybox = function()
				ctx.click(ledge().box)
				local drawer = assert(ledge().drawer)
				for _, cell in ipairs(drawer.cells) do
					if state.flies[cell.cell.id] then
						local enter = cell:GetScript("OnEnter")
						if enter then
							enter(cell)
						end
						return
					end
				end
			end,
			campfire = function()
				ns.BoardHoverHide()
				ctx.click(ledge().fire)
			end,
			close = function()
				ns.BoardHoverHide()
				ns.board:Hide()
			end,
		},
	}
end)
