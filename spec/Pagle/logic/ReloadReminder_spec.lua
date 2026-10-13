-- The unsaved-Casts reminder's counting (catch-log.md LOG-R86): pure logic told each recorded Cast and each end of
-- restriction, with the option and the restriction state read through the functions it's given.

describe("ns.NewReloadReminder", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- A reminder with the option `on.value` and restriction `restricted.value`, and the counts it showed.
	local function reminder(on, restricted)
		local shown = {}
		local r = ns.NewReloadReminder({
			isOn = function()
				return on.value
			end,
			isRestricted = function()
				return restricted.value
			end,
			show = function(count)
				shown[#shown + 1] = count
			end,
		})
		return r, shown
	end

	-- Tells `r` about `n` recorded Casts.
	local function record(r, n)
		for _ = 1, n do
			r:CastRecorded()
		end
	end

	it("steps every 50 Casts (LOG-R86's tunable)", function()
		assert.are.equal(50, ns.RELOAD_REMINDER_STEP)
	end)

	it("shows nothing while the option is off (LOG-R86)", function()
		local r, shown = reminder({ value = false }, { value = false })

		record(r, 120)

		assert.are.same({}, shown)
	end)

	it("shows one line at 50 and one at 100 Casts recorded since load, while the option is on (LOG-R86)", function()
		local r, shown = reminder({ value = true }, { value = false })

		record(r, 49)
		assert.are.same({}, shown)
		record(r, 1)
		assert.are.same({ 50 }, shown)
		record(r, 50)
		assert.are.same({ 50, 100 }, shown)
		record(r, 49)
		assert.are.same({ 50, 100 }, shown)
	end)

	it("holds a line that falls due while restricted, and shows it once when the restriction ends (LOG-R86)", function()
		local restricted = { value = false }
		local r, shown = reminder({ value = true }, restricted)

		record(r, 49)
		restricted.value = true
		record(r, 1)
		assert.are.same({}, shown)

		restricted.value = false
		r:RestrictionEnded()
		assert.are.same({ 50 }, shown)
		r:RestrictionEnded()
		assert.are.same({ 50 }, shown)
	end)

	it("shows one line, with the latest count, for every step passed in one restriction (LOG-R86)", function()
		local restricted = { value = true }
		local r, shown = reminder({ value = true }, restricted)

		record(r, 100)
		restricted.value = false
		r:RestrictionEnded()

		assert.are.same({ 100 }, shown)
	end)

	it("drops a held line if the option is off when the restriction ends (LOG-R86)", function()
		local on, restricted = { value = true }, { value = true }
		local r, shown = reminder(on, restricted)

		record(r, 50)
		on.value = false
		restricted.value = false
		r:RestrictionEnded()

		assert.are.same({}, shown)
	end)

	it("holds nothing that fell due while the option was off (LOG-R86)", function()
		local on, restricted = { value = false }, { value = true }
		local r, shown = reminder(on, restricted)

		record(r, 50)
		on.value = true
		restricted.value = false
		r:RestrictionEnded()

		assert.are.same({}, shown)
	end)
end)
