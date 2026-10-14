-- The test harness's error lists (spec/support/errors.lua): an error reaching the fake client's handler or
-- FakePagle's report is kept, never raised inside a handler where it would vanish, and a spec that never reads the
-- list fails at its end (roadmap M0 › Toolchain: a spec failure fails the gate).

describe("the harness's error lists", function()
	it("keep an error the fake client's default handler gets, readable as client.errors", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		loaded.env.geterrorhandler()("boom")

		assert.are.same({ "boom" }, loaded.client.errors)
	end)

	it("keep an error raised in an AceAddon OnInitialize, where xpcall calls the handler", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local addon = loaded.env.LibStub("AceAddon-3.0"):NewAddon("Broken")
		addon.OnInitialize = function()
			error("broken at init", 0)
		end

		loaded.client.fire("ADDON_LOADED", "Broken")

		assert.are.same({ "broken at init" }, loaded.client.errors)
	end)

	it("keep what FakePagle reports, readable as fake.reported", function()
		local fake = newFakePagle()

		fake.report("dropped")

		assert.are.same({ "dropped" }, fake.reported)
	end)

	it("name the errors of a list nobody read, and only those, once", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local errors = dofile("spec/support/errors.lua")
		local read, unread = {}, {}
		local addRead = errors.watch(read, "errors")
		local addUnread = errors.watch(unread, "errors")

		addRead("seen")
		addUnread("missed")
		local _ = read.errors

		assert.are.same({ "missed" }, errors.unasserted())
		assert.are.same({}, errors.unasserted())
	end)
end)
