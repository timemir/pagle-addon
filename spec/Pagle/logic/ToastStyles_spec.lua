-- The toast styles and the announcement art's choices as data (announcements.md › Toast styles, › UI, ANN-R80,
-- ANN-R81; wallet-and-shop.md › SHOP-R25): Core's fifteen and the three the Ledger and the Tackle Board earn in Core's
-- slot, keyed by their good IDs, with Torn Page for any other ID; their medallion rings and inks; the page a toast is
-- drawn on; a banner's seal; and the art's capitals.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local TORN_PAGE = "core.toaststyle.page"
local RIPPLE = "core.toaststyle.ripple"
local LANTERN = "core.toaststyle.lanternglow"
-- The first three styles, at 2 texels a unit with the shared trims, then the expansion's, each with a ring of its own
-- (ANN-R81), by atlas.
local FIRST = { [TORN_PAGE] = "ToastsLedger", [RIPPLE] = "ToastsRipple", [LANTERN] = "ToastsLantern" }
local RINGED = {
	["core.toaststyle.ship"] = "ToastsShip",
	["core.toaststyle.birch"] = "ToastsBirch",
	["core.toaststyle.tidepool"] = "ToastsTidepool",
	["core.toaststyle.chart"] = "ToastsChart",
	["core.toaststyle.frost"] = "ToastsFrost",
	["core.toaststyle.goblin"] = "ToastsGoblin",
	["core.toaststyle.kelp"] = "ToastsKelp",
	["core.toaststyle.moon"] = "ToastsMoon",
	["core.toaststyle.leaf"] = "ToastsLeaf",
	["core.toaststyle.bottle"] = "ToastsBottle",
	["core.toaststyle.rune"] = "ToastsRune",
	["core.toaststyle.folio"] = "ToastsFolio",
	["ledger.toaststyle.legend"] = "ToastsLegend",
	["ledger.toaststyle.prestige"] = "ToastsPrestige",
	["tackleboard.toaststyle.ember"] = "ToastsEmber",
}
local PAGES = { "low", "low-ruled", "toast", "toast-ruled", "high", "digest" }

-- The page `name` (logic/ToastStyles.lua's pages), from a headline on its rung.
local function pageOf(name)
	local rung = ({ low = "toast.low", toast = "toast", high = "toast.high" })[name]
	return ns.ToastPage({ headline = { rung = rung, title = "T" } })
end

-- An ink of the palette, by role.
local function ink(role)
	local color = ns.ANNOUNCE_COLORS[role]
	return color and { color[1], color[2], color[3] }
end

describe("the toast styles", function()
	it(
		"are Core's fifteen and the three earned in Core's slot by the Ledger and the Tackle Board, by SHOP-R25's good"
			.. " IDs (ANN-R80, ANN-R81, SHOP-R25)",
		function()
			local ids, expected = {}, {}
			for id, style in pairs(ns.TOAST_STYLES) do
				ids[#ids + 1] = id
				assert.are.equal(id, style.id)
			end
			for _, atlases in ipairs({ FIRST, RINGED }) do
				for id in pairs(atlases) do
					expected[#expected + 1] = id
				end
			end
			table.sort(ids)
			table.sort(expected)

			assert.are.same(expected, ids)
			assert.are.equal(18, #ids)
			assert.are.same({ "core.toaststyle", TORN_PAGE }, { ns.TOAST_STYLE_SLOT, ns.TOAST_STYLE_DEFAULT })
		end
	)

	it(
		"each draw the toasts and Nods from an atlas of their own, which has every page and the strip, the expansion's"
			.. " at 1.5 texels a unit with a medallion ring at each bezel size (ANN-R80, ANN-R81, Tunables)",
		function()
			for _, atlases in ipairs({ FIRST, RINGED }) do
				for id, atlasName in pairs(atlases) do
					local style = ns.ToastStyleOf(id)
					assert.are.equal(atlasName, style.atlas)
					local atlas = ns.ATLASES[style.atlas]
					for _, name in ipairs(PAGES) do
						assert.is_table(atlas.sprites["toast-" .. name])
					end
					assert.is_table(atlas.sprites["nod-strip"])
					assert.are.equal(atlases == RINGED and 1.5 or 2, atlas.scale, id)
					assert.are.equal(atlases == RINGED, style.ring == true, id)
					if style.ring then
						for _, size in ipairs({ 22, 34, 64, 84 }) do
							local ring = atlas.sprites["bezel-" .. size]
							assert.are.same({ size, size }, { ring.box[3], ring.box[4] }, id)
						end
					end
				end
			end
		end
	)

	it(
		"find each announcement atlas's texture in Pagle's media/announce as a BLP the package ships (announcements.md"
			.. " › UI, ANN-R81)",
		function()
			local names = { "Announce", "Splash" }
			for _, atlases in ipairs({ FIRST, RINGED }) do
				for _, name in pairs(atlases) do
					names[#names + 1] = name
				end
			end
			for _, name in ipairs(names) do
				local atlas = ns.ATLASES[name]
				assert.are.equal("Interface\\AddOns\\Pagle\\media\\announce\\" .. name, atlas.file)
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local file = io.open("addons/Pagle/media/announce/" .. name .. ".blp", "rb")
				assert.is_not_nil(file)
				assert.are.equal("BLP2", file:read(4))
				file:close()
			end
			assert.are.equal(20, #names)
		end
	)

	it(
		"name medallions, a stamp and inks the atlases and the palette have, on every page (ANN-R80, ANN-R81)",
		function()
			for id, style in pairs(ns.TOAST_STYLES) do
				for _, size in ipairs({ 22, 34, 64, 84 }) do
					for _, high in ipairs({ false, true }) do
						local ring = ns.BezelRing(style, size, high)
						assert.is_table(ns.ATLASES[ring.atlas].sprites[ring.sprite])
					end
				end
				assert.is_table(ns.ATLASES.Announce.sprites[style.stamp])
				local roles = { style.stampInk }
				for _, page in ipairs({ pageOf("low"), pageOf("toast"), pageOf("high"), nil }) do
					local inks = ns.ToastInks(style, page)
					for _, role in ipairs({ inks.what, inks.name, inks.amt, inks.label, inks.value }) do
						roles[#roles + 1] = role
					end
				end
				roles[#roles + 1] = ns.ToastInks(style).what
				for _, role in ipairs(roles) do
					assert.are.equal(3, #ns.ANNOUNCE_COLORS[role], ("%s's %s"):format(id, role))
				end
				if style.wax then
					assert.are.equal(3, #ns.ANNOUNCE_COLORS[style.wax], id)
				end
			end
		end
	)

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
			assert.are.same(
				{ { atlas = "Announce", sprite = "bezel-gold-84" }, { atlas = "Announce", sprite = "bezel-bronze-84" } },
				{ ns.BezelRing(tornPage, 84, false), ns.BezelRing(tornPage, 84, true) }
			)
		end
	)

	it(
		"give each of the expansion's styles its own ring at every size, toast.high's too, in place of the trims"
			.. " (ANN-R81)",
		function()
			local legend = ns.ToastStyleOf("ledger.toaststyle.legend")

			assert.are.same({
				{ atlas = "ToastsLegend", sprite = "bezel-84" },
				{ atlas = "ToastsLegend", sprite = "bezel-84" },
				{ atlas = "ToastsLegend", sprite = "bezel-22" },
			}, { ns.BezelRing(legend, 84, false), ns.BezelRing(legend, 84, true), ns.BezelRing(legend, 22) })
		end
	)

	it(
		"ink the expansion's styles as the kit's goods.json has them: kicker, name, stamp and Coins, and its own"
			.. " toast.high and toast.low inks where it has them (ANN-R81)",
		function()
			local ship = ns.ToastStyleOf("core.toaststyle.ship")
			local moon = ns.ToastStyleOf("core.toaststyle.moon")
			local folio = ns.ToastStyleOf("core.toaststyle.folio")
			local function inksOf(style, page)
				local inks = ns.ToastInks(style, page)
				return { ink(inks.what), ink(inks.name), ink(inks.amt) }
			end

			assert.are.same({ ns.Rgb("1F3A5A"), ns.Rgb("14202E"), ns.Rgb("7A5410") }, inksOf(ship, pageOf("toast")))
			assert.are.same({ ns.Rgb("1F3A6A"), "stamp-blue" }, { ink(ship.stampInk), ship.stamp })
			-- Ship's Log has no toast.high or toast.low inks of its own: the gilt kicker, and pencil.
			assert.are.same({ ink("giltDeep"), ink("pencil"), ink("pencilName"), ink("amtLow") }, {
				ink(ns.ToastInks(ship, pageOf("high")).what),
				ink(ns.ToastInks(ship, pageOf("low")).what),
				ink(ns.ToastInks(ship, pageOf("low")).name),
				ink(ns.ToastInks(ship, pageOf("low")).amt),
			})
			-- Moonlit Vellum writes in silver on night-blue: its own inks on every page, the Nod's too.
			assert.are.same({ ns.Rgb("C8D0E8"), ns.Rgb("E8ECF8"), ns.Rgb("C8D0E8") }, inksOf(moon, pageOf("low")))
			assert.are.same({ ns.Rgb("E8EEFF"), ns.Rgb("F2F4FF"), ns.Rgb("E8D080") }, inksOf(moon, pageOf("high")))
			assert.are.same({ ns.Rgb("B8C8F0"), ns.Rgb("F2F4FF"), ns.Rgb("E8D080") }, inksOf(moon))
			assert.are.same(ns.Rgb("E8B830"), ink(ns.ToastInks(folio, pageOf("high")).what))
			-- Torn Page keeps the ledger's own.
			assert.are.same({ ink("red"), ink("ink"), ink("amt") }, inksOf(ns.ToastStyleOf(TORN_PAGE), pageOf("toast")))
		end
	)

	it(
		"write the size ruler's label and number in each expansion style's own `small` ink on every page and the Nod,"
			.. " and in the ledger's inks for a style without one (ANN-R81)",
		function()
			local function rulerInks(id)
				local style, out = ns.ToastStyleOf(id), {}
				for _, page in ipairs({ pageOf("low"), pageOf("toast"), pageOf("high") }) do
					local inks = ns.ToastInks(style, page)
					out[#out + 1] = { ink(inks.label), ink(inks.value) }
				end
				local nod = ns.ToastInks(style)
				out[#out + 1] = { ink(nod.label), ink(nod.value) }
				return out
			end
			local function each(label, value)
				return { { label, value }, { label, value }, { label, value }, { label, value } }
			end

			-- Moonlit Vellum and Oxblood Vellum: light ink on a dark page.
			assert.are.same(each(ns.Rgb("B0BCD8"), ns.Rgb("B0BCD8")), rulerInks("core.toaststyle.moon"))
			assert.are.same(each(ns.Rgb("E0C8A0"), ns.Rgb("E0C8A0")), rulerInks("ledger.toaststyle.prestige"))
			-- Ship's Log, on a light page: its own dark navy, the kit's #14202e.
			assert.are.same(each(ns.Rgb("14202E"), ns.Rgb("14202E")), rulerInks("core.toaststyle.ship"))
			-- Torn Page, one of the first three, has none: the ledger's brown.
			assert.are.same(each(ink("ink2"), ink("ink")), rulerInks(TORN_PAGE))
		end
	)

	it(
		"tint toast.high's wax close to the board's: shaded for a style that keeps its red, tinted over grey for one"
			.. " that turns it, as is for Torn Page, Sea Chart and Illuminated Folio (ANN-R81)",
		function()
			local function wax(id)
				local style = ns.ToastStyleOf(id)
				return { style.wax and ink(style.wax) or false, style.waxDesaturated == true }
			end

			assert.are.same({
				{ false, false },
				{ false, false },
				{ false, false },
				{ ns.Rgb("47AEFF"), true },
				{ ns.Rgb("D9D9D9"), false },
			}, {
				wax(TORN_PAGE),
				wax("core.toaststyle.chart"),
				wax("core.toaststyle.folio"),
				wax("core.toaststyle.ship"),
				wax("ledger.toaststyle.prestige"),
			})
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
				{ crest = true, icon = "crests\\fish\\6359" },
				{ mark = "book" },
				{ mark = "quill" },
				{ mark = "waves" },
				{ mark = "waves" },
			}, {
				ns.BannerSeal({ seal = 12 }),
				ns.BannerSeal({ seal = "crest" }),
				ns.BannerSeal({ seal = "crest", crest = "crests\\fish\\6359" }),
				ns.BannerSeal({ seal = "book" }),
				ns.BannerSeal({ seal = "quill" }),
				ns.BannerSeal({}),
				ns.BannerSeal({ seal = "anchor" }),
			})
		end
	)
end)

describe("a moment's art in a medallion", function()
	it(
		"is cropped to the fish's head: a square at the left of the art, inset from its snout (VAR-R25, VAR-R26)",
		function()
			-- A 192 × 96 variety at (384, 192) on a 2048 atlas.
			local art = { texture = 1, left = 384 / 2048, right = 576 / 2048, top = 192 / 2048, bottom = 288 / 2048 }
			local left, right, top, bottom = ns.HeadCrop(art)

			-- 72 texels square: 5.76 to 77.76 across, 12 to 84 down.
			assert.are.same({ 389.76, 461.76, 204, 276 }, {
				math.floor(left * 2048 * 100 + 0.5) / 100,
				math.floor(right * 2048 * 100 + 0.5) / 100,
				math.floor(top * 2048 * 100 + 0.5) / 100,
				math.floor(bottom * 2048 * 100 + 0.5) / 100,
			})
		end
	)
end)

describe("a catch Nod's variety", function()
	-- A catch Nod's headline naming a variety of `rarity` (VAR-R26), as Core raises it.
	local function nod(rarity)
		return {
			catchNod = true,
			title = "Firefin Snapper · Coral · Decent · 34.2 cm",
			variety = { name = "Coral", rarity = rarity, before = "Firefin Snapper ·", after = "· Decent · 34.2 cm" },
		}
	end

	it(
		"draws the name in the rarity's ink after a gem in its colour, the ring in its colour but Common's the"
			.. " style's own, and a gleam for Rare and Epic (VAR-R26, ANN-R80)",
		function()
			local looks = {}
			for _, rarity in ipairs(ns.VARIETY_RARITIES) do
				local look = ns.CatchNodVarietyLook(nod(rarity.key)) --[[@as PagleNodVarietyLook]]
				assert.are.same({ "Coral", "Firefin Snapper ·", "· Decent · 34.2 cm", rarity.color, rarity.ink }, {
					look.name,
					look.before,
					look.after,
					look.color,
					look.ink,
				})
				looks[#looks + 1] = { look.ring ~= nil, look.gleam }
			end
			assert.are.same({ { false, false }, { true, false }, { true, true }, { true, true } }, looks)
			-- Common's ink is the parchment's own brown, so most catches stay calm (core/varieties.md › UI).
			local common = ns.CatchNodVarietyLook(nod("common")) --[[@as PagleNodVarietyLook]]
			assert.are.same(ns.Rgb("6a5a44"), common.ink)
		end
	)

	it("is nil for a headline that isn't a catch Nod naming a variety, or names an unknown rarity", function()
		local module = nod("rare")
		module.catchNod = nil
		local plain = nod("rare")
		plain.variety = nil
		assert.are.same({}, {
			ns.CatchNodVarietyLook(module),
			ns.CatchNodVarietyLook(plain),
			ns.CatchNodVarietyLook(nod("mythic")),
		})
	end)
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
