-- A TOC version as Pagle shows it (CORE-R2, CORE-R41, REP-R30): the packager's version, a stand-in for a checkout
-- the packager never filled in, or none for an addon that has no version.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

describe("ns.ShownVersion", function()
	it("keeps a version the packager wrote, a tag or a commit hash (CORE-R2, CORE-R41)", function()
		assert.are.same({ "1.60.1", "v0.9.0-3-gabcdef1", "a1b2c3d" }, {
			ns.ShownVersion("1.60.1", "dev"),
			ns.ShownVersion("v0.9.0-3-gabcdef1", "dev"),
			ns.ShownVersion("a1b2c3d", "dev"),
		})
	end)

	it("shows the stand-in for a token the packager never replaced, never the token (CORE-R2, CORE-R41)", function()
		assert.are.same({ "dev", "dev", "dev" }, {
			ns.ShownVersion("@project-version@", "dev"),
			ns.ShownVersion("@project-abbreviated-hash@", "dev"),
			ns.ShownVersion("@x@", "dev"),
		})
	end)

	it("keeps a version with an @ that isn't a whole token (CORE-R41)", function()
		assert.are.same(
			{ "1.0@beta", "@1.0", "@@" },
			{ ns.ShownVersion("1.0@beta", "dev"), ns.ShownVersion("@1.0", "dev"), ns.ShownVersion("@@", "dev") }
		)
	end)

	it("is nil for an addon with no version: not installed, or a TOC without the field (CORE-R41)", function()
		assert.are.same({ true, true }, { ns.ShownVersion(nil, "dev") == nil, ns.ShownVersion("", "dev") == nil })
	end)
end)
