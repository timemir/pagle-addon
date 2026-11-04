-- TOC files, read as the client reads them: the files an addon lists, in order, and its `## Field: value` lines.
-- spec/support/addon.lua loads this file; it defines the global addonFiles for specs and returns readToc for
-- loadAddon.

--- A TOC: the files it lists, in order, as paths relative to the addon folder with forward slashes, and its
--- `## Field: value` lines by field.
---@param tocPath string
---@return string[] files
---@return table<string, string> fields
local function readToc(tocPath)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local toc = assert(io.open(tocPath, "r"))
	local files, fields = {}, {}
	for line in toc:lines() do
		line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
		local field, value = line:match("^##%s*([^:]-)%s*:%s*(.-)$")
		if field then
			fields[field] = value
		elseif line ~= "" and line:sub(1, 1) ~= "#" then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	toc:close()
	return files, fields
end

--- The files addons/<name>/<name>.toc lists, in order, relative to the addon folder with forward slashes
--- ("logic/Modules.lua"). An XML file is followed by the Lua files its `<Script file="…"/>` lines load, in order and
--- relative to its own folder, as the client loads them: locale/Locales.xml, whose scripts the TOC never names (ADR 0019).
---@param name string
---@return string[]
function addonFiles(name)
	local dir = "addons/" .. name .. "/"
	local listed = readToc(dir .. name .. ".toc")
	local files = {}
	for _, file in ipairs(listed) do
		files[#files + 1] = file
		if file:match("%.xml$") then
			local folder = file:match("^(.*)/[^/]*$")
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local xml = assert(io.open(dir .. file, "r"))
			local text = xml:read("*a"):gsub("<!%-%-.-%-%->", "")
			xml:close()
			for script in text:gmatch('<Script%s+file="([^"]+)"') do
				files[#files + 1] = (folder and folder .. "/" or "") .. script:gsub("\\", "/")
			end
		end
	end
	return files
end

return readToc
