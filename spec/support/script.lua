-- What the specs of scripts/ (spec/scripts/) share, written once: running a script as its command line runs it, and
-- the helpers the scripts themselves use (scripts/lib/wtf.lua), so a spec reads files the way the script does.
--
--   local script = dofile("spec/support/script.lua")
--   local out, err, code = script.run("scripts/read-wtf.lua", { account, "--catalogue", catalogue })
--   local out, err, code = script.run("scripts/make-test-log.lua", args, { now = NOW, globals = { loadfile = f } })
--   script.wtf.readFile(path)                 -- the file's bytes, or nil when there's none
--
-- busted runs on stock Lua 5.1, which has the io, os and loadfile the WoW client lacks.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
local io = io
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local os = os
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
local loadfile = loadfile

local script = {}

--- The scripts' own helpers (scripts/lib/wtf.lua), over the repo root busted runs from.
script.wtf = assert(loadfile("scripts/lib/wtf.lua"))(".")

--- Runs the script at `path` as `lua <path> <args>` would, and returns its output lines, what it wrote to stderr,
--- and its exit code (nil when it never called os.exit). With `options.now`, os.time() answers that server time;
--- `options.globals` are set in its environment over the standard ones (a spec's own loadfile, say).
---@param path string
---@param args string[]
---@param options { now: integer?, globals: table<string, any>? }?
---@return string[] out, string err, integer? code
function script.run(path, args, options)
	options = options or {}
	local out, err, code = {}, {}, nil
	local chunk = assert(loadfile(path))
	local env = setmetatable({
		arg = { [0] = path, unpack(args) },
		print = function(line)
			out[#out + 1] = line
		end,
		io = setmetatable({
			stderr = {
				write = function(_, text)
					err[#err + 1] = text
				end,
			},
		}, { __index = io }),
		os = setmetatable({
			exit = function(status)
				code = status
			end,
			time = function(date)
				return date and os.time(date) or options.now or os.time()
			end,
		}, { __index = os }),
	}, { __index = _G })
	for key, value in pairs(options.globals or {}) do
		env[key] = value
	end
	setfenv(chunk, env)
	chunk(unpack(args))
	return out, table.concat(err), code
end

return script
