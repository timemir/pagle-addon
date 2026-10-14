-- Helpers many specs share, so each is written once. spec/support/addon.lua loads this file, so busted's helper
-- defines them for every spec.
--
--   local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ "S1|1|1791731000|0|80|150|0" }) }))
--   setCombat(loaded, true)
--   openedNames(loaded)                       -- { "Pagle", "Fishing" }
--   local loaded, errors = loadCollectingErrors()
--   breakUpLargeNumbers(1950)                -- "1,950"
--
--   local loaded = loadCore(history(2))       -- Core over Ada's 2 old Casts, its server time on the client's clock
--   enterWorld(loaded, 3)                     -- PLAYER_LOGIN, the first PLAYER_ENTERING_WORLD, then 3 frames
--   catchOne(loaded)                          -- a caught Cast of one Oily Blackmouth (catchAndFlush: then a frame)

--- FOREVER_GLOBALS plus `extra`, as loadAddon's globals.
---@param extra table<string, any>?
---@return table<string, any>
function foreverWith(extra)
	local globals = {}
	for key, value in pairs(FOREVER_GLOBALS) do
		globals[key] = value
	end
	for key, value in pairs(extra or {}) do
		globals[key] = value
	end
	return globals
end

--- A combat flip on the fake client: PLAYER_REGEN_DISABLED or _ENABLED, with InCombatLockdown agreeing.
---@param loaded LoadedAddon
---@param inCombat boolean
function setCombat(loaded, inCombat)
	loaded.env.InCombatLockdown = function()
		return inCombat
	end
	loaded.client.fire(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

--- The names of the categories Settings.OpenToCategory opened, in order (false for an unknown ID).
---@param loaded LoadedAddon
---@return (string|false)[]
function openedNames(loaded)
	local names = {}
	for i, category in ipairs(loaded.client.settings.opened) do
		names[i] = category and category.name
	end
	return names
end

--- A PagleLog as SavedVariables hand it back (catch-log.md › Data), holding `entries`. Its characters are
--- `characters`, or by default Ada (Player-4618-0A1B2C3D), first and last seen at 1791700000. Each call makes a
--- fresh table, which Core may change.
---@param entries string[]?
---@param format integer? Default 1.
---@param characters table[]?
---@return table
function savedLog(entries, format, characters)
	return {
		format = format or 1,
		logId = "3f9a2c1e7b0d4a65",
		characters = characters or {
			{
				guid = "Player-4618-0A1B2C3D",
				name = "Ada",
				classID = 1,
				raceID = 1,
				faction = "Alliance",
				realmID = 4618,
				firstSeen = 1791700000,
				lastSeen = 1791700000,
			},
		},
		entries = entries or {},
	}
end

--- Loads Core on Forever, with the errors its default handler gets (loaded.client.errors), for a spec that asserts
--- them.
---@return LoadedAddon loaded
---@return string[] errors Each error the handler got, as text, in order.
function loadCollectingErrors()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	return loaded, loaded.client.errors
end

--- What the enUS client's BreakUpLargeNumbers writes for a whole number, 0 or more: commas between groups of three
--- digits.
---@param value integer
---@return string
function breakUpLargeNumbers(value)
	local grouped = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

--- Oily Blackmouth's item link, as the loot window hands it.
OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"
--- Fishing (Classic Journeyman), on the generated catalogue's fishing-spell list (probe report 70338 §4).
FISHING = 7731
--- The build entry the fake client's build matches, so login appends no B1.
BUILD_ENTRY = ("B1|1|%d|0|70338|1.60.1"):format(SERVER_TIME - 5000)

--- Ada's caught Cast at server time `time`, as a PagleLog entry (savedLog's character 1): in Darkshore (148) at realm
--- 08:14, Fishing 86+25 with lure 263, catching one item. By default the item is Oily Blackmouth (6358) and the
--- subzone The Long Wash (453).
---@param time integer
---@param itemID integer?
---@param subzone integer?
---@return string
function castEntry(time, itemID, subzone)
	return ("C1|1|%d|0|c|494|1439|1|148|%d|86|25|263|||%dx1"):format(time, subzone or 453, itemID or 6358)
end

--- `n` of Ada's Casts, at `first` + 1, + 2, … (default SERVER_TIME - 90000, long ended), then BUILD_ENTRY.
---@param n integer
---@param first integer?
---@return string[]
function history(n, first)
	local entries = {}
	for i = 1, n do
		entries[i] = castEntry((first or SERVER_TIME - 90000) + i)
	end
	entries[n + 1] = BUILD_ENTRY
	return entries
end

--- Core on Forever over a saved log holding `entries` (or the PagleLog `entries` itself, when it has `format`) and
--- PagleDB `saved`, if given, with the Ledger and Hunts installed. Its server time is SERVER_TIME plus the client's
--- clock, so loaded.client.advance moves both.
---@param entries table?
---@param saved table?
---@return LoadedAddon
function loadCore(entries, saved)
	local clock
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			PagleLog = entries and entries.format and entries or savedLog(entries),
			PagleDB = saved,
			GetServerTime = function()
				return SERVER_TIME + math.floor(clock and clock() or 0)
			end,
		})
	)
	clock = loaded.client.time
	for _, name in ipairs({ "Ledger", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

--- Login up to the first PLAYER_ENTERING_WORLD (LOG-R1), then `frames` frames (none by default).
---@param loaded LoadedAddon
---@param frames integer?
---@return LoadedAddon loaded
function enterWorld(loaded, frames)
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	for _ = 1, frames or 0 do
		loaded.client.advance(0)
	end
	return loaded
end

--- Plays a caught Cast of `slots` (one Oily Blackmouth by default) on the fake client: the channel, the loot, the
--- channel stopping and the loot closing.
---@param loaded LoadedAddon
---@param slots table[]?
function catchOne(loaded, slots)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
	loaded.client.loot = { fishing = true, slots = slots or { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", FISHING)
	loaded.client.fire("LOOT_CLOSED")
end

--- catchOne, then the next frame, where Core flushes the Cast's moments (ANN-R10).
---@param loaded LoadedAddon
function catchAndFlush(loaded)
	catchOne(loaded)
	loaded.client.advance(0)
end

--- Code with its comments removed, for a Module's boundary spec: Lua's --[[ ]] and -- comments, XML's <!-- -->.
---@param text string
---@return string
function withoutComments(text)
	text = text:gsub("<!%-%-.-%-%->", "")
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	text = text:gsub("%-%-[^\n]*", "")
	return text
end

--- Each forbidden thing `code` (comments removed) says, as "<why>: <match>": `forbidden` lists { Lua pattern, why }.
---@param code string
---@param forbidden string[][]
---@return string[]
function forbiddenIn(code, forbidden)
	local found = {}
	for _, rule in ipairs(forbidden) do
		local match = code:match(rule[1])
		if match then
			found[#found + 1] = rule[2] .. ": " .. match
		end
	end
	return found
end

--- Every .lua and .xml file under `dir` (an addon's folder, "addons/Pagle_QoL/"), sorted.
---@param dir string
---@return string[]
function shippedFiles(dir)
	local files = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local find = assert(io.popen("find " .. dir .. " -type f \\( -name '*.lua' -o -name '*.xml' \\)"))
	for path in find:lines() do
		files[#files + 1] = path
	end
	find:close()
	table.sort(files)
	return files
end

--- A file's bytes, exactly (binary mode: no line-end translation), for goldens as for code.
---@param path string
---@return string
function readFile(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
