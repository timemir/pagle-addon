-- One place decides a font's file (CORE-R9, #522): logic/Fonts.lua's per-locale table. No other shipped Lua file
-- holds a client font path (`Fonts\...`) or a bundled one (`...\media\fonts\...`), or calls SetFont with a path written
-- in the call. The probe's list of client fonts (logic/DevFonts.lua) is the one other file that names client paths. A
-- kit holds a bundled face by its file name ("Caveat-Medium.ttf"), which Core's table turns into the file that draws it.

local ALLOWED = {
	["addons/Pagle/logic/Fonts.lua"] = "the per-locale font table",
	["addons/Pagle/logic/DevFonts.lua"] = "the probe's list of client fonts",
}

-- A line's code: a whole-line comment is nothing, and a trailing comment is cut.
---@param line string
---@return string
local function codeOf(line)
	if line:match("^%s*%-%-") then
		return ""
	end
	return (line:gsub("%-%-.*$", ""))
end

describe("font paths in the shipped Lua", function()
	local files = {}
	for _, addon in ipairs({ "Pagle", "Pagle_Ledger", "Pagle_QoL", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard" }) do
		for _, path in ipairs(shippedFiles("addons/" .. addon .. "/")) do
			if path:match("%.lua$") and not path:find("/libs/", 1, true) then
				files[#files + 1] = path
			end
		end
	end

	it("scans the files", function()
		assert.is_true(#files > 300)
		for path in pairs(ALLOWED) do
			assert(readFile(path) ~= "", path)
		end
	end)

	it("hold no client or bundled font path outside the font table and the probe's list", function()
		local found = {}
		for _, path in ipairs(files) do
			if not ALLOWED[path] then
				local number = 0
				for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
					number = number + 1
					local code = codeOf(line)
					if code:find("Fonts\\\\", 1, true) or code:find("media\\\\fonts", 1, true) then
						found[#found + 1] = ("%s:%d: %s"):format(path, number, line)
					end
				end
			end
		end
		assert.are.same({}, found)
	end)

	it("call SetFont with a path in no kit, only with what Core's font function gives", function()
		local found = {}
		for _, path in ipairs(files) do
			local number = 0
			for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
				number = number + 1
				if codeOf(line):find("SetFont%(%s*[\"']") then
					found[#found + 1] = ("%s:%d: %s"):format(path, number, line)
				end
			end
		end
		assert.are.same({}, found)
	end)
end)
