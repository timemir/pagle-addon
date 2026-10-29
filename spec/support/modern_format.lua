-- The modern client's string.format: `%d`, `%i`, `%x` and `%X` raise "integer overflow attempting to store <n>" for
-- a number outside a signed 32-bit int, where stock Lua 5.1 (which busted runs on) formats any double. A hash or a
-- sum read as unsigned (LOG-R66's size hashes reach 2^32 - 1) therefore formats fine in a spec and then raises in
-- the game, which broke `/pagle dev probe` once: format such a value with `%s` and tostring, or `%.0f`.
--
-- It replaces string.format itself, so `("%d"):format(n)` and `string.format("%d", n)` both raise, for the addon and
-- for the specs. Installed once per busted process by spec/support/addon.lua.

local format = string.format

-- The conversions that store their argument in a C int.
local INTEGER_CONVERSIONS = { d = true, i = true, x = true, X = true }
local INT_MIN, INT_MAX = -2 ^ 31, 2 ^ 31 - 1

---@diagnostic disable-next-line: duplicate-set-field -- the harness replaces string.format on purpose
function string.format(pattern, ...) -- luacheck: ignore 122 (the harness replaces string.format on purpose)
	if type(pattern) == "string" then
		local argument, at = 0, 1
		while true do
			local start, stop, conversion = pattern:find("%%[-+ #0]*%d*%.?%d*(.)", at)
			if not start then
				break
			end
			at = stop + 1
			if conversion ~= "%" then
				argument = argument + 1
				if INTEGER_CONVERSIONS[conversion] then
					local value = tonumber((select(argument, ...)))
					if value and (value < INT_MIN or value > INT_MAX) then
						error(format("integer overflow attempting to store %.0f", value), 2)
					end
				end
			end
		end
	end
	return format(pattern, ...)
end
