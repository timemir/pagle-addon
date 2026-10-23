-- The Fish Journal wearing Core's binding (LED-R112, core/book-binding.md): it draws its leather through
-- Pagle.NewBookBinding and none of its own, inks its crumbs, fleurons, brass plate and paper from the look Core hands it,
-- and leaves a change's dip and its one page turn to Core. Core's looks here are the spec's own, in ns.BindingLook's
-- shape, so it reads what the Journal does with a look and not the catalogue of bindings.

local SLOT = "core.binding"

---@type table<string, PagleBindingLook>
local LOOKS = {
	["core.binding.field"] = {
		texture = "Interface\\AddOns\\Pagle\\media\\books\\Leather",
		tileW = 128,
		tileH = 128,
		foot = 0.8,
		gilt = { 0.91, 0.79, 0.42 },
		giltShadow = { 0, 0, 0, 0.95, 0, -1 },
		silver = false,
		paperTint = { 1, 1, 1 },
	},
	-- a silver gilt over a light pressed edge, the plate silver, the paper cooled
	["test.silver"] = {
		texture = "Interface\\AddOns\\Pagle\\media\\books\\Silver",
		tileW = 128,
		tileH = 128,
		foot = 1,
		gilt = { 0.8, 0.82, 0.85 },
		giltShadow = { 1, 1, 1, 0.35, 0, 1 },
		silver = true,
		paperTint = { 0.95, 0.97, 1 },
	},
}

-- A test spread two crumbs deep, so the strip shows a fleuron between them.
---@type LedgerSpread
local DEEP = {
	crumbs = function()
		return { { label = "Home", place = { id = "home" } }, { label = "Deep" } }
	end,
	draw = function()
		return { left = { { kind = "text", text = "left" } }, right = { { kind = "text", text = "right" } } }
	end,
}

-- The Journal open on DEEP with Core's looks the spec's, moving while `motion`.
---@param motion boolean?
---@return FakePagle
---@return LoadedAddon
local function journal(motion)
	local fake, loaded = openJournal({
		motion = motion,
		modules = function(fake)
			fake.ns.BINDING_SLOT = SLOT
			fake.ns.BindingLook = function(goodID)
				return LOOKS[goodID] or LOOKS["core.binding.field"]
			end
		end,
		before = function(loaded)
			loaded.ns.RegisterJournalSpread("deep", DEEP)
		end,
		id = "deep",
	})
	if motion then
		loaded.client.update(1)
	end
	return fake, loaded
end

-- What the Journal inked from a look: the crumbs' gilt, the fleuron's tint, the plate's silver and the pages' paper.
---@param frame PagleBookFrame
local function inked(frame)
	local function rgb(region)
		local color = (region --[[@as table]]).vertexColor or { 1, 1, 1 }
		return { color[1], color[2], color[3] }
	end
	local crumbs = frame.crumbButtons
	return {
		gilt = {
			(crumbs[1].label --[[@as table]]).textColor,
			(crumbs[2].label --[[@as table]]).textColor,
		},
		fleuron = rgb((crumbs[2] --[[@as table]]).fleuron),
		silver = (frame.plate.brass.left --[[@as table]]).desaturated == true,
		paper = { rgb(frame.parchments.left.paper), rgb(frame.parchments.right.paper) },
	}
end

-- What `look` inks them in (LED-R112): the fleuron toward the gilt from the kit's own #e8c96a.
---@param look PagleBindingLook
local function inksOf(look)
	local gilt = look.gilt
	return {
		gilt = { { gilt[1], gilt[2], gilt[3] }, { gilt[1], gilt[2], gilt[3] } },
		fleuron = { math.min(1, gilt[1] / 0.91), math.min(1, gilt[2] / 0.79), math.min(1, gilt[3] / 0.42) },
		silver = look.silver,
		paper = { look.paperTint, look.paperTint },
	}
end

describe("the Fish Journal's binding (LED-R112)", function()
	it("is Core's, drawn through Pagle.NewBookBinding in the equipped binding, with no leather of its own", function()
		local fake, loaded = journal()
		local frame = loaded.ns.journal.frame

		local equipped = LOOKS[fake.Pagle.GetEquipped(SLOT) or ""] or LOOKS["core.binding.field"]
		assert.are.equal(equipped, frame.binding:Look())
		assert.are.equal(equipped, (frame.binding.skin --[[@as table]]).look)
		local shell = frame --[[@as table]]
		assert.are.same({}, { shell.leatherFill, shell.bandFrame, shell.corners, shell.leatherTint })
		assert.are.same(inksOf(equipped), inked(frame))
	end)

	it("inks its crumbs, fleurons, brass plate and paper from each look Core hands it (LED-R112, BIND-R3)", function()
		local fake, loaded = journal()
		local frame = loaded.ns.journal.frame
		local shadow = {}
		local label = frame.crumbButtons[1].label --[[@as table]]
		function label.SetShadowColor(_, ...)
			shadow.color = { ... }
		end
		function label.SetShadowOffset(_, ...)
			shadow.offset = { ... }
		end

		fake.fire("AppearanceChanged", SLOT, "test.silver")

		assert.are.same(inksOf(LOOKS["test.silver"]), inked(frame))
		assert.are.same({ color = { 1, 1, 1, 0.35 }, offset = { 0, 1 } }, shadow)
	end)

	it(
		"leaves a change of binding to Core: the dip, the cover changing at its deepest, and one page turn (LED-R112, BIND-R20, BIND-R21)",
		function()
			local fake, loaded = journal(true)
			local frame = loaded.ns.journal.frame
			local skin = frame.binding.skin --[[@as table]]
			local from = #loaded.client.sounds

			fake.fire("AppearanceChanged", SLOT, "test.silver")
			local before = { frame.binding:Look(), inked(frame).silver }
			loaded.client.update(0.2)
			local deepest = { skin.dim, frame.binding:Look(), inked(frame).silver }
			loaded.client.update(0.25)

			assert.are.same({ "836 SFX" }, { unpack(loaded.client.sounds, from + 1) })
			assert.are.same({ LOOKS["core.binding.field"], false }, before)
			assert.is_true(math.abs(deepest[1] - 0.25) < 1e-6)
			assert.are.same({ LOOKS["test.silver"], true }, { deepest[2], deepest[3] })
			assert.are.same({ 1, inksOf(LOOKS["test.silver"]) }, { skin.dim, inked(frame) })
		end
	)
end)
