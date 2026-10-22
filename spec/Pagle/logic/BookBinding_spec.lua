-- The book binding as logic (core/book-binding.md): which binding each book wears, pinned or following the equipped
-- one, the look it hands the book, and a change of binding: the dip on a shown book and the one page turn. Its host
-- here records what it is asked to draw and play, on Core's real motion player stepped by hand.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
local SLOT = "core.binding"

--- A recording host: `equipped` is the slot's pick, `motion` the Animations setting, `sounds` the page turns played,
--- and `step(seconds)` moves the motion on. Each book's skin records the look on it (`look`), its dip's alpha (`dim`)
--- and is shown while `shown`.
---@return table host
local function newHost()
	local host = { equipped = "core.binding.field", motion = true, sounds = 0 }
	local player = ns.NewMotionPlayer({
		isOn = function()
			return host.motion
		end,
		wake = function() end,
		sleep = function() end,
	})
	host.bindings = ns.NewBookBindings({
		lookOf = function(goodID)
			---@diagnostic disable-next-line: missing-fields -- a stand-in look, named by its good
			return { id = goodID or "core.binding.field" } --[[@as PagleBindingLook]]
		end,
		equipped = function()
			return host.equipped
		end,
		skin = function(frame)
			return {
				frame = frame,
				dim = 1,
				Dress = function(skin, look)
					skin.look = look
				end,
				Dim = function(skin, alpha)
					skin.dim = alpha
				end,
				IsShown = function()
					return frame.shown
				end,
			}
		end,
		motionOn = function()
			return host.motion
		end,
		animate = function(owner, animations, onDone)
			player:Animate(owner, animations, onDone)
		end,
		stopMotion = function(owner)
			player:Stop(owner)
		end,
		cue = function(owner, seconds, fn)
			player:Cue(owner, seconds, fn)
		end,
		turnSound = function()
			host.sounds = host.sounds + 1
		end,
	})
	function host.step(seconds)
		player:Step(seconds)
	end
	-- The Angler picks `goodID` (AppearanceChanged, SHOP-R33).
	function host.pick(goodID)
		host.equipped = goodID
		host.bindings.Changed(SLOT, goodID)
	end
	return host
end

-- A book on `host`: shown unless `hidden`, with `options`; and the looks its onLook was handed, by ID.
---@return PagleBookBinding binding
---@return string[] looks
local function book(host, hidden, options)
	local looks = {}
	options = options or {}
	options.onLook = function(look)
		looks[#looks + 1] = look.id
	end
	local binding = host.bindings.New({ shown = not hidden } --[[@as Frame]], options)
	return binding, looks
end

---@class BookBindingSpecSkin: PagleBookBindingSkin
---@field dim number          -- the dip's alpha, 1 at rest
---@field look { id: string } -- the look on it

-- A book's recording skin.
---@param binding PagleBookBinding
---@return BookBindingSpecSkin
local function skinOf(binding)
	return binding.skin --[[@as BookBindingSpecSkin]]
end

-- The good a stand-in look is named by.
---@param look PagleBindingLook
---@return string
local function idOf(look)
	return (look --[[@as { id: string }]]).id
end

-- The ID of the look a book wears, and of the one on its skin.
local function worn(binding)
	return { idOf(binding:Look()), skinOf(binding).look.id }
end

local saved
before_each(function()
	saved = ns.BINDING_SLOT
	ns.BINDING_SLOT = SLOT
end)
after_each(function()
	ns.BINDING_SLOT = saved
end)

describe("the binding a book wears", function()
	it("is the equipped binding, drawn at once and handed to the book before New returns (BIND-R1, BIND-R3)", function()
		local host = newHost()
		host.equipped = "core.binding.oilcloth"

		local binding, looks = book(host)

		assert.are.same({ "core.binding.oilcloth", "core.binding.oilcloth" }, worn(binding))
		assert.are.same({ "core.binding.oilcloth" }, looks)
	end)

	it("is the pinned one, whatever is equipped, and stays through a change (BIND-R1, BIND-R22)", function()
		local host = newHost()
		local binding, looks = book(host, false, { pinned = "core.binding.field" })
		host.equipped = "core.binding.verdigris"

		host.pick("core.binding.tooled")
		host.step(1)

		assert.are.same({ "core.binding.field", "core.binding.field" }, worn(binding))
		assert.are.same({ "core.binding.field" }, looks)
		assert.are.equal(0, host.sounds)
	end)

	it("can be pinned and let go again, at once, with no dip and no sound (BIND-R2)", function()
		local host = newHost()
		local binding, looks = book(host)

		binding:SetLook("core.binding.verdigris")
		local pinned = worn(binding)
		host.pick("core.binding.tooled")
		local kept = worn(binding)
		binding:SetLook(nil)

		assert.are.same({ "core.binding.verdigris", "core.binding.verdigris" }, pinned)
		assert.are.same(pinned, kept)
		assert.are.same({ "core.binding.tooled", "core.binding.tooled" }, worn(binding))
		assert.are.same({ "core.binding.field", "core.binding.verdigris", "core.binding.tooled" }, looks)
		assert.are.same({ 1, 0 }, { skinOf(binding).dim, host.sounds })
	end)
end)

describe("a change of binding", function()
	it(
		"dips a shown book to a quarter and back over 0.4 s, the cover changing at the deepest point (BIND-R20, BIND-R3)",
		function()
			local host = newHost()
			local binding, looks = book(host)

			host.pick("core.binding.tooled")
			local start = { idOf(binding:Look()), skinOf(binding).dim }
			host.step(0.1)
			local falling = skinOf(binding).dim
			host.step(0.1)
			local deepest = { idOf(binding:Look()), skinOf(binding).dim }
			host.step(0.2)

			assert.are.same({ "core.binding.field", 1 }, start)
			assert.is_true(falling < 1 and falling > 0.25)
			assert.are.same("core.binding.tooled", deepest[1])
			assert.is_true(math.abs(deepest[2] - 0.25) < 1e-6)
			assert.are.same({ 1, "core.binding.tooled" }, { skinOf(binding).dim, skinOf(binding).look.id })
			assert.are.same({ "core.binding.field", "core.binding.tooled" }, looks)
		end
	)

	it("changes a hidden book, or any while things don't move, at once (BIND-R20, BIND-R90)", function()
		local host = newHost()
		local hidden = book(host, true)
		local shown = book(host)
		host.motion = false

		host.pick("core.binding.tooled")

		assert.are.same({ "core.binding.tooled", "core.binding.tooled" }, worn(hidden))
		assert.are.same({ "core.binding.tooled", "core.binding.tooled" }, worn(shown))
		assert.are.same({ 1, 1 }, { skinOf(hidden).dim, skinOf(shown).dim })
	end)

	it(
		"starts the dip again from rest toward the newest binding when another change comes mid-dip (BIND-R20)",
		function()
			local host = newHost()
			local binding, looks = book(host)

			host.pick("core.binding.tooled")
			host.step(0.1)
			host.pick("core.binding.verdigris")
			local restarted = skinOf(binding).dim
			host.step(0.4)

			assert.are.equal(1, restarted)
			assert.are.same({ "core.binding.verdigris", "core.binding.verdigris" }, worn(binding))
			assert.are.same({ "core.binding.field", "core.binding.verdigris" }, looks)
			assert.are.equal(2, host.sounds)
		end
	)

	it(
		"plays the page turn once however many books are shown, whether or not things move, and never with none shown (BIND-R21)",
		function()
			local host = newHost()
			book(host)
			book(host)
			book(host, true)

			host.pick("core.binding.tooled")
			local moving = host.sounds
			host.motion = false
			host.pick("core.binding.verdigris")
			local still = host.sounds - moving

			local alone = newHost()
			book(alone, true)
			alone.pick("core.binding.tooled")

			assert.are.same({ 1, 1, 0 }, { moving, still, alone.sounds })
		end
	)

	it("does nothing for another slot, or for the binding the books wear already (BIND-R20, BIND-R21)", function()
		local host = newHost()
		local binding = book(host)

		host.bindings.Changed("core.crest", "core.crest.plain")
		host.pick("core.binding.field")

		assert.are.same({ "core.binding.field", 1, 0 }, { idOf(binding:Look()), skinOf(binding).dim, host.sounds })
	end)
end)
