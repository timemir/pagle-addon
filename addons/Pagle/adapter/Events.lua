---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle
local L = ns.L

-- Every WoW event registration in the package goes through here (CORE-R23). Each owner gets its own frame, so two
-- owners can register the same unit event for different units.

---@class PagleEventOwner
---@field frame Frame
---@field handlers table<string, fun(event: string, ...: any)>

---@type table<any, PagleEventOwner>
local owners = {}
local reports = ns.NewReportOnce()

-- Sends a failure to geterrorhandler(), once per owner and event per login (CORE-R23).
local function report(owner, event, message)
	if reports:First(owner, event) then
		geterrorhandler()(message)
	end
end

---@return PagleEventOwner
local function ownerEntry(owner)
	local entry = owners[owner]
	if not entry then
		local handlers = {}
		local frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, ...)
			local handler = handlers[event]
			if handler then
				local ok, err = pcall(handler, event, ...)
				if not ok then
					report(owner, event, L.EVENT_HANDLER_FAILED:format(tostring(owner), event, tostring(err)))
				end
			end
		end)
		entry = { frame = frame, handlers = handlers }
		owners[owner] = entry
	end
	return entry
end

-- Registers on the owner's frame in pcall; a failure (an event missing on Forever) is reported, not raised.
local function register(owner, event, fn, ...)
	local entry = ownerEntry(owner)
	local frame = entry.frame
	local ok, registered
	if select("#", ...) > 0 then
		ok, registered = pcall(frame.RegisterUnitEvent, frame, event, ...)
	else
		ok, registered = pcall(frame.RegisterEvent, frame, event)
	end
	if ok and registered ~= false then
		entry.handlers[event] = fn
	else
		report(owner, event, L.EVENT_REGISTER_FAILED:format(tostring(owner), event, tostring(registered)))
	end
end

--- Registers `fn` for a WoW event on `owner`'s behalf (CORE-R23). The only way Core and Modules register one.
--- `fn` is called with `(event, ...)` in `pcall`. A registration that fails, or a handler error, goes to
--- `geterrorhandler()` once per owner and event per login. Registering again replaces the owner's handler.
---@param owner table|string
---@param event string
---@param fn fun(event: string, ...: any)
function Pagle.RegisterEvent(owner, event, fn)
	register(owner, event, fn)
end

--- As `Pagle.RegisterEvent`, for a unit event that fires only for `unit` (CORE-R23).
---@param owner table|string
---@param event string
---@param unit string
---@param fn fun(event: string, ...: any)
function Pagle.RegisterUnitEvent(owner, event, unit, fn)
	register(owner, event, fn, unit)
end

--- Removes `owner`'s handler for a WoW event (CORE-R23).
---@param owner table|string
---@param event string
function Pagle.UnregisterEvent(owner, event)
	local entry = owners[owner]
	if entry and entry.handlers[event] then
		entry.handlers[event] = nil
		pcall(entry.frame.UnregisterEvent, entry.frame, event)
	end
end
