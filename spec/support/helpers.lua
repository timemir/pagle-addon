-- Helpers many specs share, so each is written once. spec/support/addon.lua loads this file, so busted's helper
-- defines them for every spec.
--
--   local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ "S1|1|1791731000|0|80|150|0" }) }))
--   setCombat(loaded, true)
--   openedNames(loaded)                       -- { "Pagle", "Fishing" }
--   local loaded, errors = loadCollectingErrors()
--   breakUpLargeNumbers(1950)                -- "1,950"

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

--- Loads Core on Forever with an error handler that collects what reaches it instead of failing the spec.
---@return LoadedAddon loaded
---@return string[] errors Each error the handler got, as text, in order.
function loadCollectingErrors()
	local errors = {}
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	loaded.env.geterrorhandler = function()
		return function(err)
			errors[#errors + 1] = tostring(err)
		end
	end
	return loaded, errors
end

--- What the enUS client's BreakUpLargeNumbers writes for a whole number, 0 or more: commas between groups of three
--- digits.
---@param value integer
---@return string
function breakUpLargeNumbers(value)
	local grouped = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end
