-- spec/language_before_wiring_spec.lua's stand-in for Core's locale/enUS.lua: the shipped file, then its `ns.L` behind
-- a table that records the key of each read while the global `__langReads` is a table.
local name, ns = ...
assert(loadfile("addons/Pagle/locale/enUS.lua"))(name, ns)
local strings = ns.L
ns.L = setmetatable({}, {
	__index = function(_, key)
		local reads = rawget(_G, "__langReads")
		if type(reads) == "table" then
			reads[#reads + 1] = tostring(key)
		end
		return strings[key]
	end,
	__newindex = strings,
})
