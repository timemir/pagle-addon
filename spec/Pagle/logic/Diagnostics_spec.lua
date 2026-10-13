-- The diagnostics buffer's pure parts (LOG-R80, LOG-R81): the world-object texts hovered before a Cast's channel,
-- and the ring buffer of entries.

describe("ns.NewHoverLog", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("gives the texts hovered before the channel started, most recent first (LOG-R80, LOG-R81)", function()
		local hovers = ns.NewHoverLog()
		hovers:Hovered("Oily Blackmouth School", 100)
		hovers:Hovered("Mailbox", 110)

		assert.are.same({ "Mailbox", "Oily Blackmouth School" }, hovers:TextsBefore(120))
	end)

	it("leaves out texts hovered more than 60 s before the channel started, or after it (LOG-R81)", function()
		local hovers = ns.NewHoverLog()
		hovers:Hovered("Mailbox", 39)
		hovers:Hovered("Oily Blackmouth School", 40)
		hovers:Hovered("Food Crate", 100)
		hovers:Hovered("Fishing Bobber", 101)

		assert.are.same({ "Food Crate", "Oily Blackmouth School" }, hovers:TextsBefore(100))
	end)

	it("gives a text hovered again once, at its most recent hover (LOG-R81)", function()
		local hovers = ns.NewHoverLog()
		hovers:Hovered("Oily Blackmouth School", 50)
		hovers:Hovered("Mailbox", 60)
		hovers:Hovered("Oily Blackmouth School", 70)
		hovers:Hovered("Oily Blackmouth School", 71)

		assert.are.same({ "Oily Blackmouth School", "Mailbox" }, hovers:TextsBefore(80))
	end)

	it("gives at most 3 texts, leaving out the older ones (LOG-R81)", function()
		local hovers = ns.NewHoverLog()
		hovers:Hovered("Mailbox", 50)
		hovers:Hovered("Food Crate", 55)
		hovers:Hovered("Oily Blackmouth School", 60)
		hovers:Hovered("Gubber Blump", 65)

		assert.are.same({ "Gubber Blump", "Oily Blackmouth School", "Food Crate" }, hovers:TextsBefore(70))
	end)

	it("counts a text hovered from before the channel started until after it (LOG-R81)", function()
		local hovers = ns.NewHoverLog()
		hovers:Hovered("Oily Blackmouth School", 30)
		hovers:Hovered("Mailbox", 50)
		hovers:Hovered("Oily Blackmouth School", 55)
		hovers:Hovered("Oily Blackmouth School", 99)
		hovers:Hovered("Fishing Bobber", 102)

		assert.are.same({ "Oily Blackmouth School", "Mailbox" }, hovers:TextsBefore(100))
	end)

	it("gives none when nothing was hovered (LOG-R81)", function()
		assert.are.same({}, ns.NewHoverLog():TextsBefore(100))
	end)
end)

describe("ns.AddDiagnostic", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("adds an entry at the end of the buffer (LOG-R81)", function()
		local buffer = { { id = "a" } }

		ns.AddDiagnostic(buffer, { id = "b" })

		assert.are.same({ { id = "a" }, { id = "b" } }, buffer)
	end)

	it("keeps the last 500 entries: the 501st drops the oldest (LOG-R81)", function()
		local buffer = {}
		for i = 1, 500 do
			ns.AddDiagnostic(buffer, { id = "e" .. i })
		end
		assert.are.equal(500, #buffer)
		assert.are.equal("e1", buffer[1].id)

		ns.AddDiagnostic(buffer, { id = "e501" })

		assert.are.equal(500, #buffer)
		assert.are.equal("e2", buffer[1].id)
		assert.are.equal("e501", buffer[500].id)
	end)
end)
