-- Loading Pagle_Hunts for its specs: over FakePagle (its catalogue, clock and Module registry) with the fixture Hunt
-- list in place of the shipped one, and the fixture lore unless a spec asks for none (hunts.md › Data: "Tests inject
-- their own Hunt list and `since` dates"). Specs load this file with dofile (and the undefined-global suppression
-- every dofile in spec/ carries), then call it:
--
--   local hunts = dofile("spec/Pagle_Hunts/support.lua")
--   local loaded, fake = hunts.load()

local FIXTURE_LIST = "spec/Pagle_Hunts/fixtures/HuntList.lua"
local FIXTURE_LORE = "spec/Pagle_Hunts/fixtures/Lore.lua"

-- Runs a fixture file as one of Pagle_Hunts' own files: its globals, its `...` and its ns.
---@param path string
---@param loaded LoadedAddon
local function runAsHunts(path, loaded)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile(path))
	setfenv(chunk, loaded.env)
	chunk("Pagle_Hunts", loaded.ns)
end

local support = {}

--- Loads Pagle_Hunts on `fake` (a new FakePagle if nil) with the fixture Hunt list, which replaces a shipped
--- data/HuntList.lua if the TOC lists one, then fires its ADDON_LOADED, so OnInitialize reads the fixture.
---@param fake table? a FakePagle (newFakePagle()), for a spec that set it up first
---@param options { lore: boolean? }? lore = false loads no fixture lore, so names fall back to IDs (HNT-R1)
---@return LoadedAddon loaded
---@return table fake
function support.load(fake, options)
	fake = fake or newFakePagle()
	options = options or {}
	local loaded = fake.load("Pagle_Hunts", { holdAddonLoaded = true })
	runAsHunts(FIXTURE_LIST, loaded)
	if options.lore ~= false then
		runAsHunts(FIXTURE_LORE, loaded)
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_Hunts")
	return loaded, fake
end

return support
