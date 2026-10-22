if not Pagle or not Pagle.RegisterTrailerPart then
	return
end
---@class PagleStatsNS
local ns = select(2, ...)

Pagle.RegisterTrailerPart("Stats", function(ctx)
	local def = ns.ProjectionDef({}, ns.places, Pagle.SESSION_RULES_VERSION)
	local state = def.reset()
	for _, record in ipairs(ctx.records) do
		def.apply(state, record, "rebuild")
	end
	def.apply(state, ctx.cast, "rebuild")
	ctx.defer(function()
		if ctx.loggingOut then
			return
		end
		ns.book:Hide()
		ns.Redraw("trailer-end")
	end)
	ctx.swap(ns, "db", ctx.db(ns.db))
	ctx.swap(ns, "projection", ctx.projection(state))
	ns.db.profile.watched, ns.db.profile.tracker = {}, true
	local function place(item)
		ns.OpenBook({ page = "place", area = ctx.zone, item = item })
	end
	return {
		actions = {
			place = function()
				place()
			end,
			entry = function()
				place(ctx.item)
			end,
			watch = function()
				ns.Watch(ctx.item, ctx.zone)
			end,
			close = function()
				ns.book:Hide()
			end,
			reopen = function()
				place(ctx.item)
			end,
			session = function()
				ns.OpenBook({ page = "session", session = ctx.cast.session })
			end,
			lifetime = function()
				ns.OpenBook({ page = "lifetime" })
			end,
		},
	}
end)
