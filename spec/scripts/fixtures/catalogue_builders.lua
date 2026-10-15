-- The builders the fixture catalogues in this folder (Catalogue.lua, TestLogCatalogue.lua) share, in the shape of
-- addons/Pagle/data/Catalogue.lua's records (DATA-R76). scripts/read-wtf.lua and scripts/make-test-log.lua load those
-- catalogues outside busted, where spec/support/helpers.lua's itemRecord and areaRecord don't exist, so each one
-- loads this file from its own folder:
--
--   local build = dofile(debug.getinfo(1, "S").source:match("^@(.-)[^/\\]*$") .. "catalogue_builders.lua")

local build = {}

-- The night window's spec: realm minutes 1260 to 360, 21:00 to 06:00.
build.night = { time = { { 1260, 360 } } }

-- An item record of `category`, `fields` over its defaults.
function build.item(category, fields)
	local record = { category = category, legend = false, noise = false, removed = false, pool = false }
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

-- An area record under `parent` (0 for a zone), `fields` over its defaults.
function build.area(parent, fields)
	local record = { parent = parent, continent = 0, hasData = true, skillBaseConfirmed = false, catches = {} }
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

return build
