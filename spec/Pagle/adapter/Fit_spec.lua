-- Pagle.FitToScreen on the client (core/README.md › Contracts): a big window shrinks to fit the screen, never grows,
-- and fits again when the UI scale or the window's size changes, through Core's one pair of registrations (CORE-R23),
-- made at the first fit, so nothing listens until a window is fitted (CORE-R13). Centred, `lift` up, unless it keeps
-- its place, when it stays where it is on the screen.

-- Core logged in on Forever, on a 1920 × 1080 screen.
local function loadCore()
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }))
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	return loaded
end

-- How many frames listen for `event`.
local function listening(loaded, event)
	local n = 0
	for _, frame in ipairs(loaded.client.frames) do
		if frame.events[event] then
			n = n + 1
		end
	end
	return n
end

-- The frame's first anchor: { point, relativePoint, x, y }.
local function anchor(frame)
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	return { point, relativePoint, x, y }
end

describe("Pagle.FitToScreen", function()
	it("shrinks a window too tall for the screen and centres it, lifted, never growing a small one", function()
		local loaded = loadCore()
		local Pagle, UIParent = loaded.env.Pagle, loaded.env.UIParent
		local tall, small = loaded.env.CreateFrame("Frame"), loaded.env.CreateFrame("Frame")

		local scale = Pagle.FitToScreen(tall, { width = 1000, height = 2064, lift = 10 })
		Pagle.FitToScreen(small, { width = 400, height = 300 })

		assert.are.same({ 0.5, 0.5 }, { scale, tall:GetScale() })
		assert.are.same({ "CENTER", "CENTER", 0, 10 }, anchor(tall))
		assert.are.equal(UIParent, select(2, tall:GetPoint(1)))
		assert.are.same({ 1, { "CENTER", "CENTER", 0, 0 } }, { small:GetScale(), anchor(small) })
	end)

	it("listens for the UI scale and the window's size only from the first fit, and fits again on either", function()
		local loaded = loadCore()
		local Pagle, UIParent = loaded.env.Pagle, loaded.env.UIParent
		local before = { listening(loaded, "UI_SCALE_CHANGED"), listening(loaded, "DISPLAY_SIZE_CHANGED") }
		local book, board = loaded.env.CreateFrame("Frame"), loaded.env.CreateFrame("Frame")
		Pagle.FitToScreen(book, { width = 800, height = 1032 })
		Pagle.FitToScreen(board, { width = 800, height = 600 })

		UIParent:SetSize(1920, 540)
		loaded.client.fire("UI_SCALE_CHANGED")
		local scaled = { book:GetScale(), board:GetScale() }
		UIParent:SetSize(1920, 1080)
		loaded.client.fire("DISPLAY_SIZE_CHANGED")

		assert.are.same({ 0, 0 }, before)
		assert.are.same({ 1, 1 }, { listening(loaded, "UI_SCALE_CHANGED"), listening(loaded, "DISPLAY_SIZE_CHANGED") })
		assert.are.same({ 0.476, 0.82 }, { math.floor(scaled[1] * 1000) / 1000, scaled[2] })
		assert.are.same({ 1, 1 }, { book:GetScale(), board:GetScale() })
	end)

	it("leaves a window at its own size, centred, on a screen not laid out yet", function()
		local loaded = loadCore()
		loaded.env.UIParent:SetSize(0, 0)
		local frame = loaded.env.CreateFrame("Frame")

		local scale = loaded.env.Pagle.FitToScreen(frame, { width = 800, height = 600, lift = 40 })

		assert.are.same({ 1, { "CENTER", "CENTER", 0, 40 } }, { scale, anchor(frame) })
	end)

	it("keeps a window that keeps its place where it is on the screen as its scale changes", function()
		local loaded = loadCore()
		local Pagle, UIParent = loaded.env.Pagle, loaded.env.UIParent
		local frame = loaded.env.CreateFrame("Frame")
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -50)
		Pagle.FitToScreen(frame, { width = 800, height = 600, keepPlace = true })

		UIParent:SetSize(1920, 348) -- (348 - 48) / 600: half size
		loaded.client.fire("UI_SCALE_CHANGED")

		-- A scaled frame's offsets are in its own units: 200 × 0.5 is still 100 on the screen.
		assert.are.same({ 0.5, { "TOPLEFT", "TOPLEFT", 200, -100 } }, { frame:GetScale(), anchor(frame) })
	end)
end)
