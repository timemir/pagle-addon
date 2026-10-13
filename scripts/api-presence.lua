-- The API presence stage of scripts/check.sh: every WoW API in the .luacheckrc inventory (stds.wow) must exist in
-- the pinned Ketho BlizzardInterfaceResources forever dump, so Pagle never calls something the client lacks.
--
--   lua scripts/api-presence.lua <.luacheckrc> <dump Resources dir>
--
-- Exits 1 and names each problem when one is found.

local configPath, dumpDir = arg[1], arg[2]
if not configPath or not dumpDir then
	io.stderr:write("usage: lua scripts/api-presence.lua <.luacheckrc> <dump Resources dir>\n")
	os.exit(2)
end

-- Runs a Lua file in its own environment and returns that environment and the file's results.
local function run(path, env)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	return env, chunk()
end

-- Every name the dump knows, dotted for namespaced ones ("C_Weather.GetCurrentWeather"). A namespace counts too.
local known = {}
local function know(name)
	known[name] = true
	for prefix in name:gmatch("()%.") do
		known[name:sub(1, prefix - 1)] = true
	end
end

-- Functions (C API, Lua extras, FrameXML) and named frames: each file returns arrays of names.
for _, file in ipairs({ "GlobalAPI.lua", "FrameXML.lua", "Frames.lua" }) do
	local _, lists = run(dumpDir .. "/" .. file, {})
	for _, list in ipairs(lists) do
		for _, name in ipairs(list) do
			know(name)
		end
	end
end

-- Enum, Constants and the LE_* values: top-level assignments, walked down to their leaves.
local function knowTable(prefix, t)
	for key, value in pairs(t) do
		if type(key) == "string" then
			know(prefix .. key)
			if type(value) == "table" then
				knowTable(prefix .. key .. ".", value)
			end
		end
	end
end
knowTable("", (run(dumpDir .. "/LuaEnum.lua", {})))

-- Global strings. The file isn't valid Lua throughout, so it's read line by line.
for line in io.lines(dumpDir .. "/GlobalStrings/enUS.lua") do
	local name = line:match("^([%a_][%w_]*) = ") or line:match('^_G%["(.-)"%] = ')
	if name then
		know(name)
	end
end

-- The names a luacheck read_globals table declares: strings, and keys whose fields nest further.
local function declared(globals, prefix, out)
	for key, value in pairs(globals or {}) do
		if type(key) == "number" then
			out[#out + 1] = prefix .. value
		else
			out[#out + 1] = prefix .. key
			if type(value) == "table" and value.fields then
				declared(value.fields, prefix .. key .. ".", out)
			end
		end
	end
	table.sort(out)
	return out
end

-- luacheck runs its config with the standard library in reach, and so does this.
local config = run(configPath, setmetatable({ stds = {}, files = {} }, { __index = _G }))
local problems = 0
local function problem(message)
	print("api: " .. message)
	problems = problems + 1
end

for _, option in ipairs({ "globals", "read_globals", "new_globals", "new_read_globals" }) do
	if config[option] then
		problem("top-level " .. option .. " in .luacheckrc reaches logic/ too (CORE-R7); use a custom std")
	end
end

local wow = declared(config.stds.wow and config.stds.wow.read_globals, "", {})
for _, name in ipairs(wow) do
	if not known[name] then
		problem(name .. " is in stds.wow but not in the forever dump")
	end
end

local variables = declared(config.stds.wow_variables and config.stds.wow_variables.read_globals, "", {})
for _, name in ipairs(variables) do
	if known[name] then
		problem(name .. " is in the forever dump now; move it from stds.wow_variables to stds.wow")
	end
end

if problems > 0 then
	os.exit(1)
end
print(("api: %d inventoried names found in the dump; %d client variables listed apart"):format(#wow, #variables))
