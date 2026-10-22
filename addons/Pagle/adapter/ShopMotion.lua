---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Curio Shop's motion and sounds (wallet-and-shop.md › UI: Motion and sound), copied from the shop art kit's
-- Purchase.lua and MOTION.md: the bill of sale dropping in and lifting away, a purchase (the Buy pressed, the wax seal
-- pressed onto the bill, the medallion flying to its row, the purse counting down while its coin turns, the price tag
-- lifting off, IN USE coming in, the row glowing once, the lid's Buy giving way), a Curio crate opening on the stage
-- (SHOP-R55; the kit has none, so it follows the spec's row), and the "N more Coins" note shaking its head. Played by Core's driver (adapter/Motion.lua), so with the Animations setting off each jumps to where it
-- settles. adapter/Shop.lua says what moves: these only move it. Positions are the case's, in UI units from its top
-- left, y growing downward.

-- The shop's sounds (the kit's SOUND.md): the client's own sound kits on the SFX channel (ANN-R73), UI foley the same
-- in every sound set.
local SOUNDS = {
	open = 5274, -- AUCTION_WINDOW_OPEN: the case opens
	close = 5275, -- AUCTION_WINDOW_CLOSE: and closes
	buy = 865, -- IG_BACKPACK_COIN_OK: Buy pressed on the bill of sale
	stamp = 1204, -- PUT_DOWN_GEMS: the wax seal pressed onto the bill
	coin = 120, -- LOOT_WINDOW_COIN_SOUND: the purse counting down
	no = 857, -- IG_MAINMENU_OPTION_CHECKBOX_OFF: Buy without enough Coins, the soft "no"
}

--- Plays one of the shop's sounds: "open", "close", "buy", "stamp", "coin" or "no".
---@param name string
function ns.ShopSound(name)
	PlaySound(SOUNDS[name], "SFX")
end

-- The bill of sale's easings: its drop overshoots a little; its lift and the tag's are CSS's ease-in.
local DROP = ns.Bezier(0.3, 1.3, 0.5, 1)
local EASE_IN = ns.Bezier(0.42, 0, 1, 1)
-- The seal's press, overshooting.
local PRESS = ns.Bezier(0.3, 1.5, 0.5, 1)

--- The bill of sale as the motion moves it.
---@class PagleShopBillMotion: Frame
---@field slip Frame
---@field shade Texture the case's dimming

-- Puts the bill's slip `dy` units below its place at `x`, `y` on the bill.
---@param bill PagleShopBillMotion
---@param x number
---@param y number
---@param dy number
local function placeSlip(bill, x, y, dy)
	bill.slip:ClearAllPoints()
	bill.slip:SetPoint("TOPLEFT", bill, "TOPLEFT", x, -(y + dy))
end

--- Opens the bill of sale, already shown: the case dims (0.2 s) and the slip drops in to `x`, `y` from 24 units up,
--- fading in (0.3 s, overshooting a little).
---@param bill PagleShopBillMotion
---@param x number
---@param y number
function ns.OpenShopBill(bill, x, y)
	ns.StopMotion(bill)
	ns.Animate(bill, {
		{
			dur = 0.2,
			ease = ns.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				bill.shade:SetAlpha(v[1])
			end,
		},
		{
			dur = 0.3,
			ease = DROP,
			keys = { { 0, { -24, 0 } }, { 1, { 0, 1 } } },
			apply = function(v)
				placeSlip(bill, x, y, v[1])
				bill.slip:SetAlpha(math.min(1, v[2]))
			end,
		},
	})
end

--- Closes the bill of sale: the slip lifts 16 units and fades as the case brightens (0.25 s), then the bill hides.
--- `owner` plays it (the bill by default; a purchase plays it on the case's clock).
---@param bill PagleShopBillMotion
---@param x number
---@param y number
---@param owner Frame?
function ns.CloseShopBill(bill, x, y, owner)
	if not owner then
		ns.StopMotion(bill)
	end
	ns.Animate(owner or bill, {
		{
			dur = 0.25,
			ease = EASE_IN,
			keys = { { 0, { 0, 1 } }, { 1, { -16, 0 } } },
			apply = function(v)
				placeSlip(bill, x, y, v[1])
				bill.slip:SetAlpha(v[2])
				bill.shade:SetAlpha(v[2])
				if v[2] <= 0 then
					bill:Hide()
				end
			end,
		},
	})
end

-- Fades each region of `regions` from `from` to `to`.
---@param regions Region[]
---@param from number
---@param to number
---@return fun(v: number[])
local function fade(regions, from, to)
	return function(v)
		for _, region in ipairs(regions) do
			region:SetAlpha(from + (to - from) * v[1])
		end
	end
end

--- What a purchase moves, from adapter/Shop.lua.
---@class PagleShopPurchaseMotion: PagleShopPayMotion
---@field press Frame              the bill's Buy, which gives under the press
---@field seal PagleSprite         the wax seal, hidden, anchored by ns.CenterSpriteAt where it lands on the bill
---@field bezel Frame              the bill's medallion, which lifts off
---@field flyer Frame              the medallion that flies, its icon set, hidden
---@field from number[]            the bill's medallion's top left on the case
---@field to number[]?             the row's medallion's top left on the case; nil with no row to fly to
---@field closeBill fun(owner: Frame) lifts the bill away on `owner`'s clock (ns.CloseShopBill)
---@field row fun(): PagleShopRowMotion? draws the row's new state, faded out; nil with no row
---@field lid fun(): Region[], Region[] draws the lid's new foot, faded out: what goes, and what comes

--- A row's change at delivery: what fades out, what fades in, the glow, and the slot's old good stepping down.
---@class PagleShopRowMotion
---@field out Region[]
---@field into Region[]
---@field glow Texture
---@field stepOut Region[]?
---@field stepIn Region[]?

-- Runs each step of `steps` ({ seconds, fn }, in order) once its time comes, on `owner`'s clock (ns.Cue; a step at 0
-- at once); `onDone` runs once everything `owner` plays has finished, the steps and all they start.
---@param owner Frame
---@param steps { [1]: number, [2]: fun() }[]
---@param onDone fun()
local function timeline(owner, steps, onDone)
	-- onDone goes on the owner's clock first, so every step's cue and animation joins it
	ns.Animate(owner, {}, onDone)
	for _, step in ipairs(steps) do
		if step[1] <= 0 then
			step[2]()
		else
			ns.Cue(owner, step[1], step[2])
		end
	end
end

--- What pays out of the purse as a purchase or a crate is shown: its balance, from and to, and its coin.
---@class PagleShopPayMotion
---@field balance fun(coins: number) writes the purse's balance
---@field balanceFrom number
---@field balanceTo number
---@field coin PagleSprite         the purse's coin, anchored by ns.CenterSpriteAt so it turns about its centre

-- The purse pays out on `owner`'s clock: its coin sound, the balance counting down a Coin at a time (0.9 s) as its coin
-- turns once (0.5 s).
---@param owner Frame
---@param m PagleShopPayMotion
local function payOut(owner, m)
	ns.ShopSound("coin")
	local coin = m.coin
	local coinWidth = coin.w0 or coin:GetWidth()
	ns.Animate(owner, {
		-- the purse counts down, a Coin at a time
		{
			dur = 0.9,
			ease = ns.EASE.out,
			keys = { { 0, { m.balanceFrom } }, { 1, { m.balanceTo } } },
			apply = function(v)
				m.balance(math.floor(v[1] + 0.5))
			end,
		},
		-- and its coin turns once as it pays out
		{
			dur = 0.5,
			ease = ns.EASE.inOut,
			keys = { { 0, { 0 } }, { 1, { 180 } } },
			apply = function(v)
				coin:SetWidth(math.max(0.5, coinWidth * math.abs(math.cos(math.rad(v[1])))))
			end,
		},
	})
end

-- A row takes its new good on `owner`'s clock: its price tag lifts away (0.25 s), IN USE (or Owned) comes in with its
-- wax (0.4 s), the row glows warm once (0.8 s), and the slot's old good steps down (0.4 s). Nothing with no row.
---@param owner Frame
---@param row PagleShopRowMotion?
local function deliverRow(owner, row)
	if not row then
		return
	end
	local animations = {
		-- the price tag lifts away
		{ dur = 0.25, ease = EASE_IN, keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = fade(row.out, 1, 0) },
		-- IN USE (or Owned) comes in, with its wax
		{
			dur = 0.4,
			ease = ns.EASE.out,
			keys = { { 0, { 0 } }, { 0.4, { 0 } }, { 1, { 1 } } },
			apply = fade(row.into, 0, 1),
		},
		-- the row glows warm once
		{
			dur = 0.8,
			ease = ns.EASE.inOut,
			keys = { { 0, { 0 } }, { 0.35, { 0.14 } }, { 1, { 0 } } },
			apply = function(v)
				row.glow:SetAlpha(v[1])
			end,
		},
	}
	if row.stepOut then
		-- the good that was in use in that slot steps down
		local out, into = fade(row.stepOut, 1, 0), fade(row.stepIn, 0, 1)
		animations[#animations + 1] = {
			dur = 0.4,
			ease = ns.EASE.inOut,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				out(v)
				into(v)
			end,
		}
	end
	ns.Animate(owner, animations)
end

--- Plays a purchase on `owner` (the case), whose clock every part joins, as the kit's MOTION.md times it; `onDone`
--- runs once it has all settled (2.2 s, the row's glow last). Only with motion on: with it off there is nothing to play.
---@param owner Frame
---@param m PagleShopPurchaseMotion
---@param onDone fun()
function ns.PlayShopPurchase(owner, m, onDone)
	ns.StopMotion(owner)
	timeline(owner, {
		{
			0,
			function()
				local sealSize = m.seal.w0 or m.seal:GetWidth()
				ns.Animate(owner, {
					-- the Buy button gives under the press
					{
						dur = 0.12,
						ease = ns.EASE.out,
						keys = { { 0, { 1 } }, { 0.5, { 0.96 } }, { 1, { 1 } } },
						apply = function(v)
							m.press:SetAlpha(v[1] < 1 and 0.85 or 1)
						end,
					},
					-- the wax seal pressed on, low on the bill's right: 2.2x down to 0.94x, settling at 1x
					{
						dur = 0.45,
						delay = 0.1,
						ease = PRESS,
						keys = { { 0, { 2.2, 0 } }, { 0.75, { 0.94, 1 } }, { 1, { 1, 1 } } },
						apply = function(v)
							local seal = m.seal
							seal:SetSize(sealSize * v[1], sealSize * v[1])
							seal:SetAlpha(v[2])
						end,
					},
				})
				m.seal:Show()
			end,
		},
		{
			0.4,
			function()
				ns.ShopSound("stamp")
			end,
		},
		{
			0.7,
			function()
				local to = m.to
				if not to then
					return
				end
				-- the medallion lifts off the bill and travels to its row, shrinking from 64 to 34 units
				m.bezel:Hide()
				local flyer, from = m.flyer, m.from
				flyer:Show()
				ns.Animate(owner, {
					{
						dur = 0.7,
						ease = ns.EASE.inOut,
						keys = { { 0, { 0, 1 } }, { 1, { 1, 34 / 64 } } },
						apply = function(v)
							local s = v[2]
							flyer:SetScale(s)
							flyer:ClearAllPoints()
							flyer:SetPoint(
								"TOPLEFT",
								owner,
								"TOPLEFT",
								(from[1] + (to[1] - from[1]) * v[1]) / s,
								-(from[2] + (to[2] - from[2]) * v[1]) / s
							)
							flyer:SetShown(v[1] < 1)
						end,
					},
				})
			end,
		},
		{
			0.75,
			function()
				m.closeBill(owner)
			end,
		},
		{
			0.8,
			function()
				payOut(owner, m)
			end,
		},
		{
			1.4,
			function()
				deliverRow(owner, m.row())
			end,
		},
		{
			1.5,
			function()
				-- the lid's Buy gives way to IN USE (or Owned and Use)
				local out, into = m.lid()
				local fadeOut, fadeIn = fade(out, 1, 0), fade(into, 0, 1)
				ns.Animate(owner, {
					{
						dur = 0.35,
						ease = ns.EASE.out,
						keys = { { 0, { 0 } }, { 1, { 1 } } },
						apply = function(v)
							fadeOut(v)
							fadeIn(v)
						end,
					},
				})
			end,
		},
	}, onDone)
end

-- A crate's opening (SHOP-R55): how far the crate settles into the well as the bill goes, and how far its lid lifts
-- off it; the lid's height as it tips back, from LID_H; the lift's ease, overshooting.
local CRATE_SINK, LID_LIFT, LID_H, LID_TIPPED = 28, 34, 44, 22
local LIFT = ns.Bezier(0.3, 1.4, 0.5, 1)
-- Each wisp of straw that puffs out of the open crate: the way it flies (degrees, 0 to the right, -90 straight up),
-- how far, and how it lies, over its arc and the pull of its fall (FALL units by its end).
local STRAW = {
	{ -158, 40, 20 },
	{ -146, 50, 75 },
	{ -133, 36, 140 },
	{ -121, 52, 35 },
	{ -108, 44, 110 },
	{ -96, 56, 165 },
	{ -84, 46, 60 },
	{ -72, 54, 125 },
	{ -59, 38, 10 },
	{ -47, 50, 95 },
	{ -34, 42, 150 },
	{ -22, 36, 50 },
}
local FALL = 18

--- How many wisps of straw a crate's opening throws (adapter/Shop.lua makes them).
ns.SHOP_STRAW = #STRAW

--- What a Curio crate's opening moves (SHOP-R55), from adapter/Shop.lua: the crate drawn from its medallion on the
--- stage's well, the straw, the good's medallion, and what follows as for a purchase.
---@class PagleShopCrateMotion: PagleShopPayMotion
---@field place fun(region: Region, x: number, y: number, scale: number?) puts `region`'s centre `x`, `y` units from the
--- well's middle (y growing downward), drawn at `scale`
---@field crate Frame               the crate: the medallion's brass rim round its dark inside
---@field lid Frame                 the crate's lid: the medallion's face, LID_H across, its height squashed as it tips
---@field straw Texture[]           the wisps of straw, hidden in the crate
---@field medal Frame               the good's medallion, 64 across, its icon set, hidden
---@field closeBill fun(owner: Frame) lifts the bill away on `owner`'s clock (ns.CloseShopBill)
---@field land fun(): Region[]      draws the good on the stage, what it shows faded out: what fades in
---@field row fun(): PagleShopRowMotion? draws the good's row's new state, faded out; nil with no row

--- Plays a Curio crate's opening on `owner` (the case), every part on its clock (SHOP-R55), the good already bought: the
--- bill lifts away (0.25 s) as the crate settles into the well (0.15 s); the lid lifts off it, tipping back and
--- overshooting (0.15–0.5 s), and fades (0.4–0.6 s); the purse pays out (from 0.25 s); straw puffs out of the open
--- crate and falls away (0.3–0.96 s); the good's medallion rises from the crate to the middle of the well, growing from
--- 34 to 64 units (0.5–1.1 s), as the crate fades (0.8–1.1 s); then the good lands on the stage, its look and words
--- coming in as the medallion gives way to them (1.1 s, 0.35 s), and its row comes in as a purchase's does (1.1 s, its
--- glow last). `onDone` runs once it has all settled (1.9 s). Only with motion on.
---@param owner Frame
---@param m PagleShopCrateMotion
---@param onDone fun()
function ns.PlayShopCrate(owner, m, onDone)
	ns.StopMotion(owner)
	local place, crate, lid, medal = m.place, m.crate, m.lid, m.medal
	timeline(owner, {
		{
			0,
			function()
				m.closeBill(owner)
				ns.Animate(owner, {
					-- the crate settles into the well, and fades once the medallion is out of it
					{
						dur = 1.1,
						keys = {
							{ 0, { 0, 1 }, ease = ns.EASE.out },
							{ 0.15 / 1.1, { CRATE_SINK, 1 } },
							{ 0.8 / 1.1, { CRATE_SINK, 1 }, ease = ns.EASE.inOut },
							{ 1, { CRATE_SINK, 0 } },
						},
						apply = function(v)
							place(crate, 0, v[1])
							crate:SetAlpha(v[2])
						end,
					},
					-- its lid rides down with it, then lifts off, tipping back
					{
						dur = 0.5,
						keys = {
							{ 0, { 0, LID_H }, ease = ns.EASE.out },
							{ 0.3, { CRATE_SINK, LID_H }, ease = LIFT },
							{ 1, { CRATE_SINK - LID_LIFT, LID_TIPPED } },
						},
						apply = function(v)
							place(lid, 0, v[1])
							lid:SetHeight(v[2])
						end,
					},
					-- and fades as it goes
					{
						dur = 0.2,
						delay = 0.4,
						ease = EASE_IN,
						keys = { { 0, { 1 } }, { 1, { 0 } } },
						apply = function(v)
							lid:SetAlpha(v[1])
						end,
					},
				})
			end,
		},
		{
			0.25,
			function()
				payOut(owner, m)
			end,
		},
		{
			0.3,
			function()
				local animations = {}
				for i, wisp in ipairs(STRAW) do
					local straw = m.straw[i]
					straw:SetRotation(math.rad(wisp[3]))
					straw:Show()
					local dx, dy = math.cos(math.rad(wisp[1])) * wisp[2], math.sin(math.rad(wisp[1])) * wisp[2]
					animations[i] = {
						dur = 0.6,
						delay = (i % 3) * 0.03,
						ease = ns.EASE.linear,
						keys = {
							{ 0, { 0, 0 }, ease = ns.EASE.out },
							{ 0.15, { 0.4, 1 }, ease = ns.EASE.out },
							{ 0.65, { 0.85, 1 } },
							{ 1, { 1, 0 } },
						},
						apply = function(v)
							local p = v[1]
							place(straw, dx * p, CRATE_SINK - 8 + dy * p + FALL * p * p)
							straw:SetAlpha(v[2])
						end,
					}
				end
				ns.Animate(owner, animations)
			end,
		},
		{
			0.5,
			function()
				medal:SetAlpha(1)
				medal:Show()
				ns.Animate(owner, {
					-- the good's medallion rises out of the crate to the middle of the well, growing from 34 to 64
					{
						dur = 0.6,
						ease = ns.Bezier(0.2, 0.8, 0.4, 1),
						keys = { { 0, { CRATE_SINK, 34 / 64 } }, { 1, { 0, 1 } } },
						apply = function(v)
							medal:SetScale(v[2])
							place(medal, 0, v[1], v[2])
						end,
					},
				})
			end,
		},
		{
			1.1,
			function()
				ns.ShopSound("stamp")
				local into = fade(m.land(), 0, 1)
				ns.Animate(owner, {
					-- the good lands on the stage, its look taking the medallion's place
					{
						dur = 0.35,
						ease = ns.EASE.out,
						keys = { { 0, { 0 } }, { 1, { 1 } } },
						apply = function(v)
							into(v)
							medal:SetAlpha(1 - v[1])
						end,
					},
				})
				deliverRow(owner, m.row())
			end,
		},
	}, onDone)
end

--- Not enough Coins: the "N more Coins" note shakes its head, 6 units left and right three times, smaller each time
--- (0.4 s), on `owner`'s clock; `offset(dx)` moves it. The soft "no" plays whether or not it moves.
---@param owner Frame
---@param offset fun(dx: number)
function ns.ShakeShopNote(owner, offset)
	ns.ShopSound("no")
	ns.StopMotion(owner)
	ns.Animate(owner, {
		{
			dur = 0.4,
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 0.15, { -6 } }, { 0.35, { 6 } }, { 0.55, { -4 } }, { 0.75, { 3 } }, { 1, { 0 } } },
			apply = function(v)
				offset(v[1])
			end,
		},
	})
end
