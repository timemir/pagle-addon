-- What the Tackle Board offers the player through Core (TKB-R1, TKB-R3): no slash entry, view, menu entry, button or
-- setting stops or resets a started board; only disabling the addon does.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Words an entry that stops or resets the board would use.
local STOPPING = { "stop", "reset", "clear", "abandon", "end", "quit", "restart", "wipe", "delete", "remove" }

-- Each stopping word `text` says, as whole words, lower case.
local function stoppingWords(text)
	local found = {}
	for word in text:lower():gmatch("%a+") do
		for _, stopping in ipairs(STOPPING) do
			if word == stopping then
				found[#found + 1] = word
			end
		end
	end
	return found
end

describe("the Tackle Board's entries (TKB-R3)", function()
	-- The board started, so the status button reads as it does once it is (TKB-R1).
	local loaded, fake = board.load()
	loaded.ns.IsStarted = function()
		return true
	end
	fake.login()
	local module = fake.registry:ModuleOf(loaded.ns.Module)
	local def = module.def

	it("has one slash entry, board, which toggles the board whatever follows it (TKB-R1)", function()
		local toggles = 0
		loaded.ns.ToggleBoard = function()
			toggles = toggles + 1
		end

		for _, line in ipairs({ "board", "board stop", "board reset", "board abandon" }) do
			fake.slash(line)
		end

		assert.are.same({ "board" }, { def.slash[1].name, def.slash[2] })
		assert.are.equal(4, toggles)
	end)

	it("offers nothing that stops or resets a started board: slash entries, views, menu, button, settings", function()
		local texts = {}
		for _, entry in ipairs(def.slash or {}) do
			texts[#texts + 1] = entry.name .. " " .. entry.help
		end
		for _, view in ipairs(def.views or {}) do
			texts[#texts + 1] = view.id .. " " .. view.label
		end
		for _, entry in ipairs(def.menu or {}) do
			texts[#texts + 1] = type(entry.label) == "function" and entry.label() or entry.label
		end
		texts[#texts + 1] = def.settingsAction.label()
		for _, topic in ipairs(fake.ns.SETTINGS_TOPICS) do
			for _, row in ipairs(fake.settingsPage(topic) or {}) do
				if row.module == "TackleBoard" and row.setting then -- Core's slot row has no setting (SET-R44)
					texts[#texts + 1] = tostring(row.label) .. " " .. tostring(row.setting.tooltip)
				end
			end
		end

		-- The Trackers page's rows (adapter/Settings.lua) are read here too.
		assert.are.same(
			{ "board Open or close the Tackle Board", "board Tackle Board", "Open Tackle Board" },
			{ unpack(texts, 1, 3) }
		)
		for _, text in ipairs(texts) do
			assert.are.same({}, stoppingWords(text), text)
		end
	end)

	it("finds a stopping entry when one is planted, so the check above can fail", function()
		assert.are.same({ "stop" }, stoppingWords("Stop my board"))
		assert.are.same({ "reset", "reset" }, stoppingWords("board reset: Reset the Tackle Board"))
		assert.are.same({}, stoppingWords("Open or close the Tackle Board (Lure, Legend)"))
	end)
end)
