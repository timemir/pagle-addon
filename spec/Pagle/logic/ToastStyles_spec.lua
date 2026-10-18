-- The toast styles and the announcement art's choices as data (announcements.md › Toast styles, › UI, ANN-R80;
-- wallet-and-shop.md › SHOP-R25): Torn Page, Ripple and Lantern Glow, keyed by Core's toast style good IDs, with
-- Torn Page for any other ID; the page a toast is drawn on; a banner's seal; and the art's capitals.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local TORN_PAGE = "core.toaststyle.page"
local RIPPLE = "core.toaststyle.ripple"
local LANTERN = "core.toaststyle.lanternglow"

describe("the toast styles", function()
	it(
		"are Torn Page, Ripple and Lantern Glow, by SHOP-R25's good IDs in the core.toaststyle slot (ANN-R80)",
		function()
			local ids = {}
			for id in pairs(ns.TOAST_STYLES) do
				ids[#ids + 1] = id
			end
			table.sort(ids)

			assert.are.same({ LANTERN, TORN_PAGE, RIPPLE }, ids)
			assert.are.same({ "core.toaststyle", TORN_PAGE }, { ns.TOAST_STYLE_SLOT, ns.TOAST_STYLE_DEFAULT })
		end
	)

	it(
		"each draw the toasts and Nods from an atlas of their own, which has every page and the strip (ANN-R80)",
		function()
			local atlases = {}
			for _, id in ipairs({ TORN_PAGE, RIPPLE, LANTERN }) do
				local style = ns.ToastStyleOf(id)
				atlases[#atlases + 1] = style.atlas
				local sprites = ns.ATLASES[style.atlas].sprites
				for _, name in ipairs({ "low", "low-ruled", "toast", "toast-ruled", "high", "digest" }) do
					assert.is_table(sprites["toast-" .. name])
				end
				assert.is_table(sprites["nod-strip"])
			end

			assert.are.same({ "ToastsLedger", "ToastsRipple", "ToastsLantern" }, atlases)
		end
	)

	it(
		"find each announcement atlas's texture in Pagle's media/announce as a BLP the package ships (announcements.md"
			.. " › UI)",
		function()
			for _, name in ipairs({ "Announce", "Splash", "ToastsLedger", "ToastsRipple", "ToastsLantern" }) do
				local atlas = ns.ATLASES[name]
				assert.are.equal("Interface\\AddOns\\Pagle\\media\\announce\\" .. name, atlas.file)
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local file = io.open("addons/Pagle/media/announce/" .. name .. ".blp", "rb")
				assert.is_not_nil(file)
				assert.are.equal("BLP2", file:read(4))
				file:close()
			end
		end
	)

	it("name medallions, a stamp and inks the shared atlas and the palette have (ANN-R80)", function()
		for _, id in ipairs({ TORN_PAGE, RIPPLE, LANTERN }) do
			local style = ns.ToastStyleOf(id)
			for _, trim in ipairs({ style.trim, style.highTrim }) do
				assert.is_table(ns.ATLASES.Announce.sprites["bezel-" .. trim .. "-84"])
			end
			assert.is_table(ns.ATLASES.Announce.sprites[style.stamp])
			for _, ink in ipairs({ style.stampInk, style.what, style.name }) do
				assert.are.equal(3, #ns.ANNOUNCE_COLORS[ink], ("%s's %s"):format(id, ink))
			end
		end
	end)

	it(
		"give Ripple silver medallions and blue stamps, and Torn Page and Lantern Glow brass and red (ANN-R80)",
		function()
			local tornPage, ripple, lantern =
				ns.ToastStyleOf(TORN_PAGE), ns.ToastStyleOf(RIPPLE), ns.ToastStyleOf(LANTERN)

			assert.are.same(
				{ { "gold", "stamp" }, { "silver", "stamp-blue" }, { "gold", "stamp" } },
				{ { tornPage.trim, tornPage.stamp }, { ripple.trim, ripple.stamp }, { lantern.trim, lantern.stamp } }
			)
			assert.are_not.same(tornPage.what, lantern.what)
		end
	)

	for _, id in ipairs({ "core.toaststyle.moonlit", "hunts.cover.velvet", "", 7 }) do
		it(("draw %s, which is no toast style, as Torn Page (ANN-R80)"):format(tostring(id)), function()
			assert.are.equal(ns.TOAST_STYLES[TORN_PAGE], ns.ToastStyleOf(id))
		end)
	end

	it("draw Torn Page before Core's slot is registered, when GetEquipped has no good for it (ANN-R80)", function()
		assert.are.equal(ns.TOAST_STYLES[TORN_PAGE], ns.ToastStyleOf(nil))
	end)
end)

describe("a toast's page", function()
	-- An Announcement headlined by a moment on `rung`, with `fields`.
	local function announcement(rung, fields)
		local headline = { rung = rung, title = "T" }
		for key, value in pairs(fields or {}) do
			headline[key] = value
		end
		return { headline = headline }
	end
	local RULER = { old = 1, new = 2, unit = "lb", label = "w" }

	it("is by rung: pencil for toast.low, the plain page for toast, gilt and wax for toast.high", function()
		assert.are.same({ "low", "toast", "high" }, {
			ns.ToastPage(announcement("toast.low")).page,
			ns.ToastPage(announcement("toast")).page,
			ns.ToastPage(announcement("toast.high")).page,
		})
		assert.are.same(
			{ true, true },
			{ ns.ToastPage(announcement("toast.low")).low, ns.ToastPage(announcement("toast.high")).high }
		)
	end)

	it("is ruled for a headline with a record ruler, toast.high's on the toast's ruled page (ANN-R22)", function()
		assert.are.same({ "low-ruled", "toast-ruled", "toast-ruled" }, {
			ns.ToastPage(announcement("toast.low", { ruler = RULER })).page,
			ns.ToastPage(announcement("toast", { ruler = RULER })).page,
			ns.ToastPage(announcement("toast.high", { ruler = RULER })).page,
		})
	end)

	it('is the digest for "While you were fighting" (ANN-R36)', function()
		local fighting = announcement("toast")
		fighting.fighting = {}

		assert.are.same({ "digest", true }, { ns.ToastPage(fighting).page, ns.ToastPage(fighting).digest })
	end)
end)

describe("a banner's seal", function()
	it(
		"presses the headline's number, mark or the Prestige crest, and the waves for none or another (announcements.md › Contracts)",
		function()
			assert.are.same({
				{ number = 12 },
				{ crest = true },
				{ mark = "book" },
				{ mark = "quill" },
				{ mark = "waves" },
				{ mark = "waves" },
			}, {
				ns.BannerSeal({ seal = 12 }),
				ns.BannerSeal({ seal = "crest" }),
				ns.BannerSeal({ seal = "book" }),
				ns.BannerSeal({ seal = "quill" }),
				ns.BannerSeal({}),
				ns.BannerSeal({ seal = "anchor" }),
			})
		end
	)
end)

describe("the art's capitals", function()
	it("put a text in capitals, a link's words too, leaving texture, colour and link escapes as they are", function()
		local star = "|TInterface\\Common\\ReputationStar:12:12:0:0:32:32:0:16:0:16|t"

		assert.are.same({
			"NEW HERE",
			star .. star .. " MASTERY",
			"|cffff2020RED|r WORDS",
			"A |Hitem:6358|h[OILY]|h FISH",
		}, {
			ns.Capitals("New here"),
			ns.Capitals(star .. star .. " Mastery"),
			ns.Capitals("|cffff2020red|r words"),
			ns.Capitals("a |Hitem:6358|h[Oily]|h fish"),
		})
	end)

	it(
		"space a banner's title letter by letter, four spaces between words, a character of several bytes kept whole",
		function()
			assert.are.same(
				{ "Z O N E    M A S T E R", "W E T L A N D S    ·    T I T L E" },
				{ ns.SpacedCaps("Zone Master"), ns.SpacedCaps("Wetlands · Title") }
			)
		end
	)
end)

describe("the sample toast", function()
	it(
		"is a toast in the given style, with sample stamps and Coins, raised by no Module and on no Cast (ANN-R80,"
			.. " SHOP-R25)",
		function()
			local sample = ns.SampleAnnouncement(RIPPLE)

			assert.are.same({ "toast", RIPPLE, nil }, { sample.rung, sample.style, sample.cast })
			assert.are.same(
				{ ns.L.TOAST_SAMPLE_TITLE, ns.L.TOAST_SAMPLE_TEXT },
				{ sample.headline.title, sample.headline.text }
			)
			assert.are.same({ ns.L.TOAST_SAMPLE_STAMP }, sample.stamps)
			assert.are.same({ 0, 5, sample.headline }, { sample.more, sample.coins, sample.moments[1] })
		end
	)
end)
