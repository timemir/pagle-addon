-- Loading Pagle_Stats for its specs: over FakePagle (its catalogue, clock, Sessions and Module registry) with the
-- fixture catalogue served in place of the shipped one (M6 graph, conventions: Stats' specs never run on the shipped
-- catalogue). Specs load this file with dofile (and the undefined-global suppression every dofile in spec/ carries),
-- then call it:
--
--   local stats = dofile("spec/Pagle_Stats/support.lua")
--   local loaded, fake = stats.load()

local FIXTURE_CATALOGUE = "spec/Pagle_Stats/fixtures/Catalogue.lua"

local support = {}

--- The fixture catalogue (spec/Pagle_Stats/fixtures/Catalogue.lua), a new table each call.
---@return table
function support.catalogue()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	return dofile(FIXTURE_CATALOGUE)
end

--- Loads Pagle_Stats on `fake` (a new FakePagle if nil), serving `options.catalogue` or else the fixture catalogue
--- through fake.setCatalogue first, so Stats reads it from OnInitialize on. `options.prepare(loaded)` runs after
--- Stats' files load and before its ADDON_LOADED (OnInitialize), e.g. to change `loaded.ns.STATS_RULES_VERSION`.
---@param fake table? a FakePagle (newFakePagle()), for a spec that set it up first
---@param options { catalogue: table?, prepare: fun(loaded: LoadedAddon)? }? catalogue: a catalogue in the shape of
--- ns.catalogue to serve instead
---@return LoadedAddon loaded
---@return table fake
function support.load(fake, options)
	fake = fake or newFakePagle()
	options = options or {}
	fake.setCatalogue(options.catalogue or support.catalogue())
	local loaded = fake.load("Pagle_Stats", { holdAddonLoaded = true })
	if options.prepare then
		options.prepare(loaded)
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_Stats")
	return loaded, fake
end

return support
