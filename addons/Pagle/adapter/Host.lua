---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

--- The WoW client as Core's wiring sees it (logic/Wiring.lua): FakePagle builds the same over its fakes, so both run
--- one wiring (CORE-R18). Every WoW global is read at each call.
---@type PagleHost
ns.host = {
	registry = ns.Modules,
	db = function()
		return ns.db
	end,
	catchLog = function()
		return ns.catchLog
	end,
	fire = function(event, ...)
		ns.Fire(event, ...)
	end,
	listen = function(owner, event, fn)
		Pagle.RegisterCallback(owner, event, fn)
	end,
	fingerprint = function()
		return Pagle.CONTENT_FINGERPRINT
	end,
	iterate = function(afterSeq)
		return Pagle.IterateCatches(afterSeq)
	end,
	serverTime = function()
		return GetServerTime()
	end,
	after = function(seconds, fn)
		C_Timer.After(seconds, fn)
	end,
	nextFrame = function(step)
		C_Timer.After(0, step)
	end,
	clock = function()
		return debugprofilestop()
	end,
	call = function(fn, ...)
		return securecallfunction(fn, ...)
	end,
	report = function(message)
		geterrorhandler()(message)
	end,
}
