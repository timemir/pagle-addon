describe("ns.NewWorkQueue", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- Calls each piece of work, as the adapter's runner does.
	local function call(work)
		work()
	end

	it("runs nothing until drained, then everything in the order it was queued (CORE-R32)", function()
		local queue = ns.NewWorkQueue()
		local ran = {}
		for i = 1, 3 do
			queue:Push(function()
				ran[#ran + 1] = i
			end)
		end

		assert.are.same({}, ran)
		queue:Drain(call)

		assert.are.same({ 1, 2, 3 }, ran)
	end)

	it("runs work queued while draining after the rest, and each piece once (CORE-R32)", function()
		local queue = ns.NewWorkQueue()
		local ran = {}
		queue:Push(function()
			ran[#ran + 1] = "first"
			queue:Push(function()
				ran[#ran + 1] = "queued while draining"
			end)
		end)
		queue:Push(function()
			ran[#ran + 1] = "second"
		end)

		queue:Drain(call)
		queue:Drain(call)

		assert.are.same({ "first", "second", "queued while draining" }, ran)
	end)
end)
