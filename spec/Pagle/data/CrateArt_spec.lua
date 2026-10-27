describe("the Curio crate's art and sounds tables", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	local ns = loaded.ns

	local USES = { tint = true, add = true, fixed = true, cap = true, mirror = true, slice = true }
	local ANCHORS = {
		crate = true,
		plaque = true,
		reel = true,
		line = true,
		bobber = true,
		hook = true,
		card = true,
		centre = true,
		box = true,
	}

	local function read(path, count)
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local file = assert(io.open(path, "rb"), path)
		local bytes = file:read(count)
		file:close()
		return bytes
	end

	local function le32(bytes, at)
		local a, b, c, d = bytes:byte(at, at + 3)
		return a + b * 256 + c * 65536 + d * 16777216
	end

	it("adds one Crate atlas to ns.ATLASES, a power-of-two BLP the package ships, at 1.5 texels a unit", function()
		local atlas = ns.ATLASES.Crate
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\crate\\Crate", atlas.file)
		assert.are.equal(1.5, atlas.scale)
		assert.is_true(atlas.width <= 2048 and atlas.height <= 1024)
		local blp = read("addons/Pagle/media/crate/Crate.blp", 148)
		assert.are.equal("BLP2", blp:sub(1, 4))
		assert.are.equal(2, blp:byte(9), "DXT colour encoding")
		assert.are.equal(7, blp:byte(11), "DXT5 alpha")
		assert.are.equal(1, blp:byte(12), "with mipmaps")
		assert.are.same({ atlas.width, atlas.height }, { le32(blp, 13), le32(blp, 17) })
		for _, side in ipairs({ atlas.width, atlas.height }) do
			local n = side
			while n % 2 == 0 do
				n = n / 2
			end
			assert.are.equal(1, n, "a power of two")
		end
	end)

	it(
		"places every sprite inside the atlas, clear of the others, with what it is for and how big it is meant to be",
		function()
			local atlas = ns.ATLASES.Crate
			local names = {}
			for name in pairs(atlas.sprites) do
				names[#names + 1] = name
			end
			table.sort(names)
			assert.is_true(#names >= 45)
			for _, name in ipairs(names) do
				local s = atlas.sprites[name]
				assert(s.x >= 2 and s.y >= 2 and s.x + s.w + 2 <= atlas.width and s.y + s.h + 2 <= atlas.height, name)
				assert(ANCHORS[s.anchor], name)
				for use in s.use:gmatch("%S+") do
					assert(USES[use], name .. " " .. use)
				end
				assert(#s.box == 4 and #s.size == 2 and #s.at == 2, name)
				assert(s.size[1] > 0 and s.size[2] > 0, name)
				if s.alpha then
					assert(s.alpha > 0 and s.alpha < 1, name)
				end
			end
			for i = 1, #names do
				local a = atlas.sprites[names[i]]
				for j = i + 1, #names do
					local b = atlas.sprites[names[j]]
					local apart = a.x + a.w + 2 <= b.x
						or b.x + b.w + 2 <= a.x
						or a.y + a.h + 2 <= b.y
						or b.y + b.h + 2 <= a.y
					assert(apart, names[i] .. " and " .. names[j] .. " touch")
				end
			end
		end
	)

	it(
		"has the crate in parts, the plaque, the reel, the cards, the emblems, the Curio and coin cards and the effects",
		function()
			local sprites = ns.ATLASES.Crate.sprites
			for _, name in ipairs({
				"crate-body",
				"crate-lid",
				"crate-seal-left",
				"crate-seal-right",
				"crate-ribbon",
				"plaque-cap",
				"plaque-mid",
				"reel-frame-cap",
				"reel-frame-mid",
				"reel-line",
				"reel-bobber",
				"reel-hook",
				"card-base",
				"card-tint",
				"card-curio",
				"card-coin",
				"emblem-toast",
				"emblem-book",
				"emblem-sound",
				"emblem-tracker",
				"emblem-coin",
				"rays-crate",
				"rays-a",
				"rays-b",
				"fx-burst",
				"fx-beam",
				"fx-spark",
				"fx-ember",
				"fx-dust",
				"fx-straw",
				"fx-flash",
			}) do
				assert(type(sprites[name]) == "table", name)
			end
			-- a card is the spec's 120 x 138
			assert.is_true(
				math.abs(sprites["card-base"].size[1] - 120) < 0.5
					and math.abs(sprites["card-base"].size[2] - 138) < 0.5
			)
		end
	)

	it("names a sound for each beat, ogg files the package ships under media/crate/sounds/", function()
		local sounds = ns.CRATE_SOUNDS
		assert.are.equal(3, #sounds.knocks)
		assert.are.equal(3, #sounds.ticks)
		assert.are.equal(6, #sounds.stings, "a sting for each crate tier")
		local paths = { sounds.curio }
		for key, value in pairs(sounds) do
			if type(value) == "string" then
				paths[#paths + 1] = value
			elseif key ~= "curio" then
				for _, path in ipairs(value) do
					paths[#paths + 1] = path
				end
			end
		end
		for _, key in ipairs({
			"crateLand",
			"sealCrack",
			"strapsSnap",
			"lidWhoosh",
			"reelOpen",
			"cardLand",
			"cardTurn",
			"payback",
		}) do
			assert(type(sounds[key]) == "string", key)
		end
		for _, path in ipairs(paths) do
			local file = path:gsub("^Interface\\AddOns\\Pagle\\", "addons/Pagle/"):gsub("\\", "/")
			assert.are.equal("OggS", read(file, 4), path)
		end
	end)
end)
