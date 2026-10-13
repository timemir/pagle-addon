-- The conflict check's pure part: which other fishing-key addons are loaded, and what the popup and chat say about
-- them (QOL-R80, QOL-R81, QOL-R83; qol.md › Tunables).

---@return table ns QoL's ns, as its logic/ sees it
local function qol()
	return loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns
end

-- An `isLoaded` that answers from a set of folder names.
---@param names string[]
---@return fun(name: string): boolean
local function loadedSet(names)
	local set = {}
	for _, name in ipairs(names) do
		set[name] = true
	end
	return function(name)
		return set[name] == true
	end
end

local TITLES = { Angleur = "Angleur", FishingBuddy = "Fishing Buddy (Forever)" }
local function titleOf(name)
	return TITLES[name]
end

describe("The conflict list", function()
	it("names Angleur and the folder every Fishing Buddy build installs into (qol.md › Tunables, QOL-R80)", function()
		-- Angleur: the Angleur_Camelot.toc it ships for Forever. FishingBuddy: the original, and the folder both
		-- Forever ports' published zips hold (Fishing Buddy Forever Fix 1.0.2, Fishing Buddy (Forever) 1.0.7).
		assert.are.same({ "Angleur", "FishingBuddy" }, qol().CONFLICT_LIST)
	end)
end)

describe("Finding conflicts", function()
	it("finds none when no listed addon is loaded (QOL-R80)", function()
		assert.are.same({}, qol().FindConflicts(loadedSet({ "Pagle", "Pagle_QoL", "Details" }), titleOf))
	end)

	it("finds each loaded one with its title, in list order (QOL-R80, QOL-R81)", function()
		assert.are.same(
			{ { name = "Angleur", title = "Angleur" }, { name = "FishingBuddy", title = "Fishing Buddy (Forever)" } },
			qol().FindConflicts(loadedSet({ "FishingBuddy", "Angleur" }), titleOf)
		)
	end)

	it("names one with no Title by its folder (QOL-R81)", function()
		assert.are.same(
			{ { name = "Angleur", title = "Angleur" } },
			qol().FindConflicts(loadedSet({ "Angleur" }), function() end)
		)
	end)
end)

describe("The popup's words", function()
	it("offers Use {other} for one other addon, and Use the others for several (QOL-R81)", function()
		local ns = qol()
		local angleur = { name = "Angleur", title = "Angleur" }
		local buddy = { name = "FishingBuddy", title = "Fishing Buddy (Forever)" }

		assert.are.equal("Use Angleur", ns.UseOtherLabel({ angleur }))
		assert.are.equal("Use the others", ns.UseOtherLabel({ angleur, buddy }))
	end)

	it("says which addons Use Pagle turned off, titles joined by commas (QOL-R83)", function()
		local ns = qol()

		assert.are.equal(
			"Pagle: turned off Angleur, Fishing Buddy (Forever). Type /reload to finish.",
			ns.TurnedOffMessage({
				{ name = "Angleur", title = "Angleur" },
				{ name = "FishingBuddy", title = "Fishing Buddy (Forever)" },
			})
		)
	end)
end)
