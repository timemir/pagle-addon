-- Core's reads of the Companion's data addons through the real TOC and the fake client (core/anglers-in-game.md):
-- PagleFollowingData as Pagle_Following leaves it before PLAYER_LOGIN, Pagle_Anglers loaded on demand by the hover
-- entry point the tooltip block calls (ns.anglerViews:HoverPlayer), Pagle.GetFollowedAnglers and `/pagle dev views`,
-- over IGV Contracts' examples (anglerFileExamples).

local DAY = 24 * 3600
-- When the files were written in these specs: ten minutes before the fake client's server time.
local WRITTEN = SERVER_TIME - 600
local ADA, ADA_ALT, CARD_2 = "Player-4618-0A1B2C3D", "Player-4618-0A1B2C3E", "Player-4395-01234567"

---@class AnglersCore: LoadedAddon
---@field files { following: table, anglers: table } the data the Companion's files set

describe("the Companion's data addons", function()
	-- Types `/pagle <msg>` in chat.
	local function pagle(loaded, msg)
		loaded.env.SlashCmdList.PAGLE(msg)
	end

	-- Core over a saved log, up to PLAYER_LOGIN's eve, with both data addons installed as the Companion writes them,
	-- each file written at WRITTEN: Pagle_Following, loaded, has set PagleFollowingData; Pagle_Anglers, load-on-demand,
	-- sets PagleAnglersData when C_AddOns.LoadAddOn loads it. `options.following` / `options.anglers` false leaves that
	-- addon uninstalled; `options.saved` is a saved PagleDB.
	---@return AnglersCore
	local function core(options)
		options = options or {}
		local loaded = loadCore(history(1), options.saved) --[[@as AnglersCore]]
		local files = anglerFileExamples()
		files.following.generatedAt, files.anglers.generatedAt = WRITTEN, WRITTEN
		loaded.files = files
		if options.following ~= false then
			loaded.client.addons.Pagle_Following = { metadata = {} }
			loaded.env.PagleFollowingData = files.following
		end
		if options.anglers ~= false then
			loaded.client.addons.Pagle_Anglers = {
				loaded = false,
				metadata = {},
				load = function()
					loaded.env.PagleAnglersData = files.anglers
				end,
			}
		end
		return loaded
	end

	-- The server time from now on.
	local function at(loaded, time)
		loaded.env.GetServerTime = function()
			return time
		end
	end

	-- A player unit's tooltip shows for `guid`, as the tooltip block calls Core: the unit's card.
	local function hover(loaded, guid)
		return loaded.ns.anglerViews:HoverPlayer(guid)
	end

	-- `/pagle dev views`' lines, with dev mode on.
	local function devViews(loaded)
		pagle(loaded, "dev on")
		local from = #loaded.printed + 1
		pagle(loaded, "dev views")
		local lines = {}
		for i = from, #loaded.printed do
			lines[#lines + 1] = loaded.printed[i]
		end
		return lines
	end

	describe("Pagle_Following", function()
		it("is read at PLAYER_LOGIN, and Pagle.GetFollowedAnglers hands out Ada (VIEW-R1, VIEW-R11)", function()
			local loaded = core()
			local Pagle = loaded.env.Pagle
			assert.are.same({ state = "absent", anglers = {} }, Pagle.GetFollowedAnglers())

			enterWorld(loaded)

			local followed = Pagle.GetFollowedAnglers()
			assert.are.equal("ok", followed.state)
			assert.are.same({ "Ada" }, { followed.anglers[1].name })
			assert.are.same({ ADA, ADA_ALT }, followed.anglers[1].guids)
			followed.anglers[1].name = "Changed"
			assert.are.equal("Ada", Pagle.GetFollowedAnglers().anglers[1].name)
			assert.are_not.equal(followed.anglers, Pagle.GetFollowedAnglers().anglers)
		end)

		it("is read once: what writes to the global after login changes nothing (VIEW-R1)", function()
			local loaded = core()
			enterWorld(loaded)

			loaded.env.PagleFollowingData = nil
			loaded.files.following.anglers[1].name = "Changed"

			assert.are.equal("Ada", loaded.env.Pagle.GetFollowedAnglers().anglers[1].name)
		end)

		it("reads none when live with no Anglers (VIEW-R11)", function()
			local loaded = core()
			loaded.files.following.anglers, loaded.files.following.count = {}, 0
			enterWorld(loaded)

			assert.are.same({ state = "none", anglers = {} }, loaded.env.Pagle.GetFollowedAnglers())
		end)

		it("expires mid-session at 24 h, with no reload (VIEW-R2, VIEW-R91)", function()
			local loaded = core()
			enterWorld(loaded)

			at(loaded, WRITTEN + DAY - 1)
			assert.are.equal("ok", loaded.env.Pagle.GetFollowedAnglers().state)
			assert.are.equal(ADA, hover(loaded, ADA).guids[1])
			at(loaded, WRITTEN + DAY)
			assert.are.same({ state = "expired", anglers = {} }, loaded.env.Pagle.GetFollowedAnglers())
			assert.is_nil(hover(loaded, ADA))
			assert.are.equal(
				"Pagle dev: Pagle_Following is expired: generated 86400 s ago, the expiry age is 86400 s.",
				devViews(loaded)[1]
			)
		end)

		it("reads a file IGV-R44 refuses absent, and names why in dev mode (VIEW-R1, VIEW-R12)", function()
			local loaded = core()
			loaded.files.following.ok = nil
			enterWorld(loaded)

			assert.are.same({ state = "absent", anglers = {} }, loaded.env.Pagle.GetFollowedAnglers())
			local lines = devViews(loaded)
			assert.are.same({
				"Pagle dev: Pagle_Following is absent: ok isn't true.",
				("Pagle dev: Pagle_Following's generatedAt %d, Anglers 1."):format(WRITTEN),
			}, { lines[1], lines[2] })
		end)
	end)

	it(
		"reads both files absent on a first install of the Companion, and says why in dev mode (VIEW-R90, VIEW-R12)",
		function()
			local loaded = core({ following = false, anglers = false })
			enterWorld(loaded)

			assert.are.same({ state = "absent", anglers = {} }, loaded.env.Pagle.GetFollowedAnglers())
			assert.is_nil(hover(loaded, ADA))
			assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			assert.are.same({
				"Pagle dev: Pagle_Following is absent: no file (Pagle_Following isn't installed).",
				"Pagle dev: Pagle_Following's generatedAt none, Anglers none.",
				"Pagle dev: Pagle_Anglers is absent: no file (Pagle_Anglers isn't installed).",
				"Pagle dev: Pagle_Anglers' generatedAt none, blocks none.",
				"Pagle dev: Pagle_Anglers hasn't loaded this login.",
			}, devViews(loaded))
		end
	)

	describe("loading Pagle_Anglers", function()
		it("happens at the first player hover, once per login, and never before (VIEW-R3)", function()
			local loaded = core()
			enterWorld(loaded, 1)
			assert.are.same({}, loaded.client.loads)
			assert.are.same({
				"Pagle dev: Pagle_Anglers is absent: not loaded yet (it loads at the first player tooltip while Pagle"
					.. " isn't restricted, with the tooltip setting on).",
				"Pagle dev: Pagle_Anglers' generatedAt none, blocks none.",
				"Pagle dev: Pagle_Anglers hasn't loaded this login.",
			}, { unpack(devViews(loaded), 3) })

			local card = hover(loaded, CARD_2)
			hover(loaded, "Player-1-00000002")
			hover(loaded, ADA)

			assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			assert.are.same({ false, 60, "Seeker of the Deep" }, { card.followed, card.level, card.title })
			assert.are.same({
				"Pagle dev: Pagle_Following is live.",
				("Pagle dev: Pagle_Following's generatedAt %d, Anglers 1."):format(WRITTEN),
				"Pagle dev: Pagle_Anglers is live.",
				("Pagle dev: Pagle_Anglers' generatedAt %d, blocks 1."):format(WRITTEN),
				"Pagle dev: Pagle_Anglers has loaded this login.",
			}, devViews(loaded))
		end)

		it(
			"finds a Followed Angler in Pagle_Following though Pagle_Anglers holds them too (VIEW-R10, VIEW-R93)",
			function()
				local loaded = core()
				enterWorld(loaded)

				local card = hover(loaded, ADA_ALT)

				assert.are.same({ true, "Ada", 5120 }, { card.followed, card.name, card.catches })
			end
		)

		it(
			"waits while restricted, the hover using Pagle_Following alone, and loads at the next hover outside it (VIEW-R3, VIEW-R22)",
			function()
				local loaded = core()
				enterWorld(loaded)

				setCombat(loaded, true)
				assert.is_true(loaded.env.Pagle.IsRestricted())
				assert.are.equal("Ada", hover(loaded, ADA).name)
				assert.is_nil(hover(loaded, CARD_2))
				assert.are.same({}, loaded.client.loads)
				setCombat(loaded, false)
				assert.are.same({}, loaded.client.loads)

				assert.are.equal(60, hover(loaded, CARD_2).level)
				assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			end
		)

		it(
			"never happens with the tooltip setting off; on again, the next hover loads it (VIEW-R3, VIEW-R30)",
			function()
				local loaded = core()
				enterWorld(loaded)
				assert.is_true(loaded.ns.db.profile.anglerTooltips)

				loaded.ns.db.profile.anglerTooltips = false
				hover(loaded, CARD_2)
				hover(loaded, CARD_2)
				assert.are.same({}, loaded.client.loads)
				loaded.ns.db.profile.anglerTooltips = true
				hover(loaded, CARD_2)

				assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			end
		)

		it("leaves the file absent for the login when the load fails, and never tries again (VIEW-R3)", function()
			local loaded = core()
			loaded.client.addons.Pagle_Anglers.refuse = "CORRUPT"
			enterWorld(loaded)

			assert.is_nil(hover(loaded, CARD_2))
			assert.is_nil(hover(loaded, CARD_2))
			assert.are.equal("Ada", hover(loaded, ADA).name)

			assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			assert.are.same({
				"Pagle dev: Pagle_Anglers is absent: no file (Pagle_Anglers didn't load: CORRUPT).",
				"Pagle dev: Pagle_Anglers' generatedAt none, blocks none.",
				"Pagle dev: Pagle_Anglers hasn't loaded this login.",
			}, { unpack(devViews(loaded), 3) })
		end)

		it("reads a loaded Pagle_Anglers that set no PagleAnglersData absent (VIEW-R1, IGV-R44)", function()
			local loaded = core()
			loaded.client.addons.Pagle_Anglers.load = nil
			enterWorld(loaded)

			assert.is_nil(hover(loaded, CARD_2))
			assert.are.same({
				"Pagle dev: Pagle_Anglers is absent: no file (Pagle_Anglers loaded but set no PagleAnglersData).",
				"Pagle dev: Pagle_Anglers' generatedAt none, blocks none.",
				"Pagle dev: Pagle_Anglers has loaded this login.",
			}, { unpack(devViews(loaded), 3) })
		end)

		it("expires mid-session at 24 h, like Pagle_Following (VIEW-R2)", function()
			local loaded = core()
			loaded.files.following.generatedAt = WRITTEN + 3600
			enterWorld(loaded)
			hover(loaded, CARD_2)

			at(loaded, WRITTEN + DAY - 1)
			assert.are.equal(60, hover(loaded, CARD_2).level)
			at(loaded, WRITTEN + DAY)
			assert.is_nil(hover(loaded, CARD_2))
			assert.are.equal("Ada", hover(loaded, ADA).name)
			assert.are.equal(
				"Pagle dev: Pagle_Anglers is expired: generated 86400 s ago, the expiry age is 86400 s.",
				devViews(loaded)[3]
			)
		end)
	end)

	it("never looks up a secret GUID, though the hover still loads Pagle_Anglers (VIEW-R10, CORE-R31)", function()
		local loaded = core()
		enterWorld(loaded)
		loaded.env.issecretvalue = function(value)
			return value == ADA or value == CARD_2
		end

		assert.is_nil(hover(loaded, ADA))
		assert.is_nil(hover(loaded, CARD_2))
		assert.is_nil(hover(loaded, nil))
		assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
		assert.are.equal("Ada", hover(loaded, ADA_ALT).name)
	end)

	it(
		"writes nothing back: the globals, PagleDB and PagleLog hold nothing from the files, and Pagle's addons never hold them (VIEW-R4)",
		function()
			local loaded = core()
			enterWorld(loaded, 1)
			hover(loaded, ADA)
			hover(loaded, CARD_2)
			loaded.env.Pagle.GetFollowedAnglers()
			devViews(loaded)

			local files = anglerFileExamples()
			files.following.generatedAt, files.anglers.generatedAt = WRITTEN, WRITTEN
			assert.are.same(files.following, loaded.env.PagleFollowingData)
			assert.are.same(files.anglers, loaded.env.PagleAnglersData)
			-- Nothing from either file in the SavedVariables, or in chat but the dev lines' states and counts: no GUID
			-- but the saved log's own character's (Ada, Player-4618-0A1B2C3D), and no title.
			local function holds(value, seen)
				seen = seen or {}
				if type(value) == "string" then
					for _, text in ipairs({ ADA_ALT, CARD_2, "Warden of Feralas Waters", "Seeker of the Deep" }) do
						if value:find(text, 1, true) then
							return true
						end
					end
				elseif type(value) == "table" and not seen[value] then
					seen[value] = true
					for key, field in pairs(value) do
						if holds(key, seen) or holds(field, seen) then
							return true
						end
					end
				end
				return false
			end
			assert.is_false(holds(loaded.env.PagleDB))
			assert.is_false(holds(loaded.env.PagleLog))
			assert.is_false(holds(loaded.printed))
			for _, path in ipairs(shippedFiles("addons/")) do
				assert.are.equal(nil, (path:find("Pagle_Following", 1, true)), path)
				assert.are.equal(nil, (path:find("Pagle_Anglers", 1, true)), path)
				assert.are.equal(nil, (readFile(path):find("PagleFollowingData%s*=[^=]")), path)
				assert.are.equal(nil, (readFile(path):find("PagleAnglersData%s*=[^=]")), path)
			end
		end
	)

	it("prints nothing with dev mode off (VIEW-R12)", function()
		local loaded = core()
		enterWorld(loaded)

		pagle(loaded, "dev views")

		assert.are.equal(
			"Pagle dev: dev commands are off; /pagle dev on turns them on.",
			loaded.printed[#loaded.printed]
		)
	end)

	describe("the Pagle block", function()
		-- The fish and the header, as the block draws them (VIEW-R21).
		local HEADER = "|TInterface\\AddOns\\Pagle\\media\\minimap\\Pagle:0|t Pagle Angler"

		-- The mouse goes over a unit with `guid`: GameTooltip's texts then, the game's own line first.
		local function tooltipOf(loaded, guid)
			loaded.client.hoverUnit(guid, "Ada")
			return loaded.client.tooltipLines()
		end

		it(
			"never shows a hidden tooltip it adds a block to, such as another addon's scanning tooltip (VIEW-R20)",
			function()
				local loaded = core()
				enterWorld(loaded)
				local tooltip = loaded.env.GameTooltip
				tooltip:Hide()
				local Unit = loaded.env.Enum.TooltipDataType.Unit

				loaded.client.showTooltip(Unit, { type = Unit, guid = ADA, lines = { { leftText = "Ada" } } })

				assert.is_false(tooltip:IsShown())
			end
		)

		it(
			"adds a Followed Angler's block after the game's lines, on the player's own character too, with every Module off (VIEW-R20, VIEW-R21, VIEW-R93)",
			function()
				local loaded = core()
				enterWorld(loaded)

				assert.are.same({
					"Ada",
					" ",
					HEADER,
					"Following",
					"Warden of Feralas Waters",
					"Angler Level",
					"23 · Prestige I",
					"Ledger",
					"37%",
					"Legends",
					"3 of 12",
				}, tooltipOf(loaded, ADA))
				assert.are.same({
					"",
					"FFFFFF",
					"5FD3C4",
					"1EFF00",
					"FFD100",
					"E9D8AE",
					"FFFFFF",
					"E9D8AE",
					"FFFFFF",
					"E9D8AE",
					"FFFFFF",
				}, loaded.client.tooltipColors())
			end
		)

		it(
			"adds a tooltip card's block once Pagle_Anglers has loaded, Hardcore Angler in red (VIEW-R20, VIEW-R21)",
			function()
				local loaded = core()
				enterWorld(loaded)

				assert.are.same({
					"Ada",
					" ",
					HEADER,
					"Seeker of the Deep",
					"Angler Level",
					"60 · Master Prestige 2",
					"Ledger",
					"100%",
					"Legends",
					"7 of 12",
					"Hardcore Angler",
				}, tooltipOf(loaded, CARD_2))
				assert.are.equal("FF4B3A", loaded.client.tooltipColors()[11])
				assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			end
		)

		it(
			"adds nothing for a player with no card, a unit that isn't a player's, or a secret or missing GUID (VIEW-R20, CORE-R31)",
			function()
				local loaded = core()
				enterWorld(loaded)
				local secret = "Player-4618-0A1B2C3E"
				loaded.env.issecretvalue = function(value)
					return value == secret
				end

				assert.are.same({ "Ada" }, tooltipOf(loaded, "Creature-0-4618-0-1-2-0000000001"))
				assert.are.same({ "Ada" }, tooltipOf(loaded, secret))
				assert.are.same({ "Ada" }, tooltipOf(loaded, nil))
				assert.are.same({}, loaded.client.loads) -- none of them is a player's hover that can be told (VIEW-R3)
				assert.are.same({ "Ada" }, tooltipOf(loaded, "Player-1-00000002"))
				assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			end
		)

		it(
			"shows in combat, finding Followed Anglers only until Pagle_Anglers loads after it (VIEW-R22, VIEW-R3)",
			function()
				local loaded = core()
				enterWorld(loaded)

				setCombat(loaded, true)
				assert.are.equal("Following", tooltipOf(loaded, ADA)[4])
				assert.are.same({ "Ada" }, tooltipOf(loaded, CARD_2))
				setCombat(loaded, false)

				assert.are.equal("Seeker of the Deep", tooltipOf(loaded, CARD_2)[4])
			end
		)

		it(
			"adds nothing, and never loads Pagle_Anglers, with the setting off; on again, the next hover does both (VIEW-R30, VIEW-R3)",
			function()
				local loaded = core()
				enterWorld(loaded)

				loaded.ns.db.profile.anglerTooltips = false
				assert.are.same({ "Ada" }, tooltipOf(loaded, ADA))
				assert.are.same({ "Ada" }, tooltipOf(loaded, CARD_2))
				assert.are.same({}, loaded.client.loads)
				loaded.ns.db.profile.anglerTooltips = true

				assert.are.equal(HEADER, tooltipOf(loaded, CARD_2)[3])
				assert.are.same({ "Pagle_Anglers" }, loaded.client.loads)
			end
		)
	end)

	describe("Show other Anglers on player tooltips", function()
		-- The root's last two rows: the Pagle website header and the row (SET-R10 row 11).
		local function websiteRows(loaded)
			local initializers = loaded.client.settings.category("Pagle").layout.initializers
			return initializers[#initializers - 1], initializers[#initializers]
		end

		it(
			"is a checkbox under a Pagle website header, the root's last rows, with its tooltip (SET-R10 row 11, VIEW-R30)",
			function()
				local loaded = core()
				enterWorld(loaded)

				local header, row = websiteRows(loaded)

				assert.are.same(
					{ "Pagle website", "SettingsListSectionHeaderTemplate" },
					{ header:GetName(), header.template }
				)
				assert.are.same(
					{ "Show other Anglers on player tooltips", "SettingsCheckboxControlTemplate" },
					{ row:GetName(), row.template }
				)
				assert.are.equal(
					"Adds a Pagle block to the tooltip of players whose Angler is on the Pagle website. Needs the Pagle"
						.. " Companion.",
					row.data.tooltip
				)
			end
		)

		it(
			"reads PagleDB.profile.anglerTooltips, on by default, with no default for Defaults to restore (VIEW-R30, SET-R13)",
			function()
				local loaded = core()
				enterWorld(loaded)
				local setting = select(2, websiteRows(loaded)):GetSetting()

				assert.is_true(setting:GetValue())
				assert.is_nil(setting:GetDefaultValue())
				loaded.ns.db.profile.anglerTooltips = false
				assert.is_false(setting:GetValue())
			end
		)

		it(
			"off, removes the block and never loads Pagle_Anglers; on, the next hover loads it (VIEW-R30, VIEW-R3)",
			function()
				local loaded = core()
				enterWorld(loaded)
				local setting = select(2, websiteRows(loaded)):GetSetting()

				setting:SetValue(false)
				loaded.client.hoverUnit(CARD_2, "Ada")
				loaded.client.hoverUnit(ADA, "Ada")
				assert.are.same({ false, { "Ada" }, {} }, {
					loaded.ns.db.profile.anglerTooltips,
					loaded.client.tooltipLines(),
					loaded.client.loads,
				})

				setting:SetValue(true)
				loaded.client.hoverUnit(CARD_2, "Ada")
				assert.are.same(
					{ true, "Seeker of the Deep", { "Pagle_Anglers" } },
					{ loaded.ns.db.profile.anglerTooltips, loaded.client.tooltipLines()[4], loaded.client.loads }
				)
			end
		)
	end)
end)
