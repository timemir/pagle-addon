---@class PagleNS
local ns = select(2, ...)

-- Sets each secret value in `t`, and in the tables it holds, to nil. `seen` stops a table that holds itself.
---@param isSecret fun(value: any): boolean
---@param t table
---@param seen table<table, true>
local function stripTable(isSecret, t, seen)
	seen[t] = true
	for key, value in pairs(t) do
		if isSecret(value) then
			t[key] = nil
		elseif type(value) == "table" and not seen[value] then
			stripTable(isSecret, value, seen)
		end
	end
end

--- The one place Core drops secret values before it publishes anything: events, snapshots, records (CORE-R31).
--- Returns `...` with each secret value replaced by nil, keeping the count. A table in `...` is stripped in place,
--- with the tables it holds, and returned as itself.
---@param isSecret fun(value: any): boolean `issecretvalue`
---@param ... any
---@return any ...
function ns.StripSecrets(isSecret, ...)
	local n = select("#", ...)
	local values = { ... }
	local seen = {}
	for i = 1, n do
		local value = values[i]
		if isSecret(value) then
			values[i] = nil
		elseif type(value) == "table" and not seen[value] then
			stripTable(isSecret, value, seen)
		end
	end
	return unpack(values, 1, n)
end
