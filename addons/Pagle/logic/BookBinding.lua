---@class PagleNS
local ns = select(2, ...)

-- The book binding (core/book-binding.md, ADR 0015): which binding each book wears, and how it changes. A book wears
-- the binding the `core.binding` slot holds, or the one it is pinned to (BIND-R1, BIND-R2), and is handed each look it
-- puts on (BIND-R3); when the Angler picks another binding, every open book dips while the cover changes underneath,
-- and the page turn plays once (BIND-R20–R22). Pure logic over a host: adapter/BookBinding.lua draws each book's
-- binding on the client and hands in Core's goods, motion driver and sound, and FakePagle does the same over its own.

--- The page turn a change of binding plays, once (BIND-R21): IG_ABILITY_PAGE_TURN, on the SFX channel.
ns.BINDING_TURN_SOUND = 836

-- The dip (BIND-R20): how long it lasts, and the material's alpha at its deepest, halfway, where the cover changes.
local DIP, DEEPEST = 0.4, 0.25

--- What a book asks of its binding (book-binding.md › Contracts).
---@class PagleBookBindingOptions
---@field pinned string?                       -- a binding good to wear always (BIND-R1)
---@field onLook fun(look: PagleBindingLook)? -- each look it puts on (BIND-R3)
---@field sublevel integer?                   -- the material's BACKGROUND sublevel (BIND-R10)
---@field cornerSize number?                  -- the corner pieces' size (BIND-R12)
---@field giltCornerSize number?              -- the gilt corner's size (BIND-R12)
---@field pages { x: number, y: number, w: number, h: number }? -- the page block in the frame, from its top left (BIND-R15)

--- What draws one book's binding: Core's regions on its frame (adapter/BookBinding.lua), or FakePagle's record.
---@class PagleBookBindingSkin
---@field Dress fun(self: PagleBookBindingSkin, look: PagleBindingLook) -- draws `look` at once
---@field Dim fun(self: PagleBookBindingSkin, alpha: number) -- the dip (BIND-R20): the material at `alpha`, 1 at rest
---@field IsShown fun(self: PagleBookBindingSkin): boolean -- whether the book is on the screen now

--- What the bindings need from their client.
---@class PagleBookBindingHost
---@field lookOf fun(goodID: string?): PagleBindingLook -- a binding good's look (ns.BindingLook)
---@field equipped fun(): string? -- the `core.binding` slot's pick (Pagle.GetEquipped)
---@field skin fun(frame: Frame, options: PagleBookBindingOptions): PagleBookBindingSkin
---@field motionOn fun(): boolean -- Core's Animations setting
---@field animate fun(owner: table, animations: PagleAnimation[], onDone: fun()?) -- Core's motion driver
---@field stopMotion fun(owner: table)
---@field cue fun(owner: table, seconds: number, fn: fun())
---@field turnSound fun() -- plays the page turn (BIND-R21)

--- One book's binding: Pagle.NewBookBinding's handle. A book reads its look and pins it; the rest is Core's.
---@class PagleBookBinding
---@field skin PagleBookBindingSkin -- what draws it, for a spec or a probe to read; a book never changes it
---@field host PagleBookBindingHost
---@field pinned string? -- the good it is pinned to; nil while it follows the equipped binding
---@field goodID string? -- the good it wears, or is dipping toward
---@field look PagleBindingLook -- the look it wears now
---@field onLook fun(look: PagleBindingLook)?
---@field owner table -- the dip's motion owner
local Binding = {}
Binding.__index = Binding

-- Puts `look` on `binding` at once, and hands it to the book (BIND-R3).
---@param binding PagleBookBinding
---@param look PagleBindingLook
local function dress(binding, look)
	binding.look = look
	binding.skin:Dress(look)
	if binding.onLook then
		binding.onLook(look)
	end
end

-- Stops `binding`'s dip where it is, and puts it back at rest.
---@param binding PagleBookBinding
local function rest(binding)
	binding.host.stopMotion(binding.owner)
	binding.skin:Dim(1)
end

-- Changes `binding`, which follows the equipped binding, to `goodID` (BIND-R20): a book shown dips while things move,
-- the cover changing at the deepest point; any other changes at once. Returns whether the book was shown.
---@param binding PagleBookBinding
---@param goodID string?
---@return boolean shown
local function change(binding, goodID)
	local host, skin = binding.host, binding.skin
	local look = host.lookOf(goodID)
	binding.goodID = goodID
	rest(binding)
	local shown = skin:IsShown()
	if not (shown and host.motionOn()) then
		dress(binding, look)
		return shown
	end
	host.animate(binding.owner, {
		{
			dur = DIP,
			ease = ns.EASE.inOut,
			keys = { { 0, { 1 } }, { 0.5, { DEEPEST } }, { 1, { 1 } } },
			apply = function(v)
				skin:Dim(v[1])
			end,
		},
	})
	host.cue(binding.owner, DIP / 2, function()
		dress(binding, look)
	end)
	return true
end

--- The look the book wears now (BIND-R2): through a dip, the one it is changing from until the deepest point.
---@return PagleBindingLook
function Binding:Look()
	return self.look
end

--- Pins the book to binding `goodID` from now on, or with nil has it follow the equipped binding again (BIND-R2):
--- drawn at once, with no dip and no sound.
---@param goodID string?
function Binding:SetLook(goodID)
	self.pinned = goodID
	rest(self)
	self.goodID = goodID or self.host.equipped()
	dress(self, self.host.lookOf(self.goodID))
end

--- The bindings over a host: `New(frame, options)` draws a book's (Pagle.NewBookBinding, BIND-R1), and
--- `Changed(slot, goodID)` takes Core's AppearanceChanged (BIND-R20–R22).
---@class PagleBookBindings
---@field New fun(frame: Frame, options: PagleBookBindingOptions?): PagleBookBinding
---@field Changed fun(slot: string, goodID: string?)

---@param host PagleBookBindingHost
---@return PagleBookBindings
function ns.NewBookBindings(host)
	-- Every book's binding, weakly: nothing here keeps a book alive.
	---@type table<PagleBookBinding, true>
	local books = setmetatable({}, { __mode = "k" })
	return {
		New = function(frame, options)
			options = options or {}
			local binding = setmetatable({
				host = host,
				pinned = options.pinned,
				onLook = options.onLook,
				owner = {},
			}, Binding) --[[@as PagleBookBinding]]
			binding.skin = host.skin(frame, options)
			binding.goodID = options.pinned or host.equipped()
			dress(binding, host.lookOf(binding.goodID))
			books[binding] = true
			return binding
		end,
		Changed = function(slot, goodID)
			if slot ~= ns.BINDING_SLOT then
				return
			end
			goodID = goodID or host.equipped()
			-- The books as they are now: a book's onLook may make another.
			local following = {}
			for binding in pairs(books) do
				if binding.pinned == nil and binding.goodID ~= goodID then
					following[#following + 1] = binding
				end
			end
			local shown = false
			for _, binding in ipairs(following) do
				shown = change(binding, goodID) or shown
			end
			if shown then
				host.turnSound()
			end
		end,
	}
end
