-- Core's onboarding state through the real TOC and the fake client (core/onboarding.md): PagleDB's migration adds it
-- at login step 1 (ONB-R1, ONB-R2), PLAYER_LOGIN adds the character (ONB-R3), a returning Angler's welcome hook waits
-- for the first SessionStarted or 20 s (ONB-R2), `/pagle guide` (ONB-R80, CORE-R61) and `/pagle dev onboarding reset`
-- (ONB-R83).

local ADA = "Player-4618-0A1B2C3D"

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- PagleDB.global.onboarding as the client holds it.
local function state(loaded)
	return loaded.env.PagleDB.global.onboarding
end

-- A saved PagleDB at schemaVersion 2 holding `onboarding`.
local function savedDB(onboarding)
	return { global = { schemaVersion = 2, onboarding = onboarding } }
end

-- The onboarding state as made for a new Angler (`letter`, default "waiting"), with `guids` in characters.
local function stateWith(ns, letter, guids)
	local made = ns.NewOnboardingState(letter or "waiting")
	for _, guid in ipairs(guids or {}) do
		made.characters[guid] = true
	end
	return made
end

-- Registers QoL (order 50), as Pagle_QoL's OnInitialize would before PLAYER_LOGIN.
local function registerQoL(loaded)
	loaded.client.addons.Pagle_QoL = { metadata = { ["X-Pagle-API"] = "1" } }
	loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
end

-- Counts each call of the onboarding hook `name`.
local function countHook(loaded, name)
	local raised = { count = 0 }
	loaded.ns.onboarding:SetHook(name, function()
		raised.count = raised.count + 1
	end)
	return raised
end

describe("Core's onboarding state at login", function()
	it("is added by PagleDB's migration at ADDON_LOADED, waiting for a new Angler (ONB-R1, ONB-R2)", function()
		local loaded = loadCore({ BUILD_ENTRY })

		assert.are.equal(2, loaded.env.PagleDB.global.schemaVersion)
		assert.are.same(stateWith(loaded.ns), state(loaded))
	end)

	it("is returning when the Catch log already holds a C1 Cast (ONB-R2)", function()
		local loaded = loadCore(history(3))

		assert.are.equal("returning", state(loaded).letter)
		assert.is_true(loaded.ns.onboarding:IsReturning())
	end)

	it("puts the first character's GUID in characters at PLAYER_LOGIN, raising no hook (ONB-R3, Data)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		registerQoL(loaded)
		local raised = countHook(loaded, "character")

		enterWorld(loaded)

		assert.are.same({ [PLAYER_GUID] = true }, state(loaded).characters)
		assert.are.equal(0, raised.count)
	end)

	it("never recreates a table that exists, from a migration or a login (ONB-R1)", function()
		local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
		local saved = stateWith(ns, "opened", { PLAYER_GUID })
		saved.notesSeen["core.nod"] = true
		local db = savedDB(saved)
		db.global.schemaVersion = 1

		local loaded = enterWorld(loadCore({ BUILD_ENTRY }, db))

		assert.are.equal(2, loaded.env.PagleDB.global.schemaVersion)
		assert.are.equal("opened", state(loaded).letter)
		assert.is_true(state(loaded).notesSeen["core.nod"])
	end)

	it("is added at PLAYER_LOGIN for a PagleDB past the migration that lost it (ONB-R1)", function()
		local loaded = loadCore(history(2), savedDB(nil))
		assert.is_nil(state(loaded))

		enterWorld(loaded)

		assert.are.same(stateWith(loaded.ns, "returning", { PLAYER_GUID }), state(loaded))
	end)
end)

describe("another character (ONB-R3)", function()
	-- Ada has logged in before; PLAYER_GUID is a second character's first login.
	local function secondCharacter(withQoL)
		local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
		local loaded = loadCore(history(2), savedDB(stateWith(ns, "returning", { ADA })))
		if withQoL then
			registerQoL(loaded)
		end
		return loaded, countHook(loaded, "character")
	end

	it("raises the character hook at a second GUID's first login, once, and adds the GUID (ONB-R3)", function()
		local loaded, raised = secondCharacter(true)

		enterWorld(loaded)

		assert.are.equal(1, raised.count)
		assert.are.same({ [ADA] = true, [PLAYER_GUID] = true }, state(loaded).characters)

		-- The next login of that character, with what this one saved: no hook.
		local again = loadCore(loaded.env.PagleLog, loaded.env.PagleDB)
		registerQoL(again)
		local raisedAgain = countHook(again, "character")
		enterWorld(again)

		assert.are.equal(0, raisedAgain.count)
	end)

	it("adds the GUID without the hook while QoL isn't registered (ONB-R3, ONB-R101)", function()
		local loaded, raised = secondCharacter(false)

		enterWorld(loaded)

		assert.are.equal(0, raised.count)
		assert.are.same({ [ADA] = true, [PLAYER_GUID] = true }, state(loaded).characters)
	end)
end)

describe("a returning Angler's welcome (ONB-R2)", function()
	it("is raised 20 s after login, once, when no Session starts first (ONB-R2)", function()
		local loaded = loadCore(history(3))
		local raised = countHook(loaded, "welcome")
		enterWorld(loaded)

		loaded.client.advance(19)
		assert.are.equal(0, raised.count)
		loaded.client.advance(1)
		assert.are.equal(1, raised.count)
		catchOne(loaded)
		loaded.client.advance(30)

		assert.are.equal(1, raised.count)
	end)

	it("is raised at the first SessionStarted when it comes first, and not again at 20 s (ONB-R2)", function()
		local loaded = loadCore(history(3))
		local raised = countHook(loaded, "welcome")
		enterWorld(loaded, 1)

		catchOne(loaded)
		assert.are.equal(1, raised.count)
		loaded.client.advance(30)

		assert.are.equal(1, raised.count)
	end)

	it("is never raised for a new Angler (ONB-R2)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		local raised = countHook(loaded, "welcome")
		enterWorld(loaded, 1)

		catchOne(loaded)
		loaded.client.advance(30)

		assert.are.equal(0, raised.count)
	end)
end)

describe("/pagle guide (ONB-R80, CORE-R61)", function()
	it("with notes empties notesSeen and looksSeen and prints its line (ONB-R80)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))
		state(loaded).notesSeen["core.nod"] = true
		state(loaded).looksSeen["ledger.journal"] = true

		pagle(loaded, "guide notes")

		assert.are.same({}, state(loaded).notesSeen)
		assert.are.same({}, state(loaded).looksSeen)
		assert.are.same({ "Pagle: margin notes will show again, once each." }, loaded.printed)
	end)

	it("on its own opens the Field guide, printing nothing (ONB-R80, ONB-R22)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "Guide")

		assert.are.same({}, loaded.printed)
		assert.is_true(loaded.env.PagleGuide:IsShown())
		assert.are.equal("welcome", state(loaded).guideStep)
	end)

	it("lists guide in the help list (ONB-R80, CORE-R61)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "help")

		assert.are.equal("Pagle commands:", loaded.printed[1])
		assert.are.equal(
			"/pagle guide: open the Field guide; /pagle guide notes shows the margin notes again",
			loaded.printed[5]
		)
		assert.are.same({}, openedNames(loaded))
	end)

	it("is reserved: a Module's guide subcommand is skipped and reported (CORE-R61, CORE-R62)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.env.Pagle.RegisterModule({
			name = "Ledger",
			title = "Ledger",
			order = 10,
			slash = { { name = "Guide", fn = print } },
		})

		local errors = loaded.client.errors
		enterWorld(loaded)

		assert.are.same({ "Pagle: Ledger's /pagle Guide is skipped: Pagle reserves guide" }, errors)
		local reserved = {}
		for _, name in ipairs(loaded.ns.SLASH_RESERVED) do
			reserved[name] = true
		end
		assert.is_true(reserved.guide)
	end)
end)

describe("/pagle dev onboarding (ONB-R83)", function()
	it("reset puts the state back as created for a new Angler, with a log full of Casts (ONB-R83)", function()
		local loaded = enterWorld(loadCore(history(40)))
		local onboarding = state(loaded)
		assert.are.equal("returning", onboarding.letter)
		onboarding.notesSeen["core.nod"] = true
		onboarding.characters[ADA] = true
		onboarding.guideStep, onboarding.guideDone = "box", true

		pagle(loaded, "dev on")
		pagle(loaded, "dev onboarding reset")

		assert.are.same(stateWith(loaded.ns, "waiting", { PLAYER_GUID }), state(loaded))
		assert.are.same({
			"Pagle dev: dev commands are on.",
			"Pagle dev: onboarding is back as a new Angler's, with the Letter waiting; /reload to start from there.",
		}, loaded.printed)
	end)

	it("does nothing while dev mode is off, but says how to turn it on (ONB-R83, #247)", function()
		local loaded = enterWorld(loadCore(history(2)))
		local before = state(loaded)

		pagle(loaded, "dev onboarding reset")

		assert.are.equal(before, state(loaded))
		assert.are.equal("returning", state(loaded).letter)
		assert.are.same({ "Pagle dev: dev commands are off; /pagle dev on turns them on." }, loaded.printed)
	end)

	it("prints its usage for none or an unknown subcommand (ONB-R83)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))
		pagle(loaded, "dev on")

		pagle(loaded, "dev onboarding")
		pagle(loaded, "dev onboarding letters")

		local usage = "Pagle dev: /pagle dev onboarding reset | step <id> | note <id>"
		assert.are.same({ "Pagle dev: dev commands are on.", usage, usage }, loaded.printed)
	end)
end)
