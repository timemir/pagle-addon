---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Curio Shop's motion and sounds (wallet-and-shop.md › UI: Motion and sound), copied from the shop art kit's
-- Purchase.lua and MOTION.md: the bill of sale dropping in and lifting away, a purchase (the Buy pressed, the wax seal
-- pressed onto the bill, the medallion flying to its row, the purse counting down while its coin turns, the price tag
-- lifting off, IN USE coming in, the row glowing once, the lid's Buy giving way), and the "N more Coins" note shaking
-- its head. Played by Core's driver (adapter/Motion.lua), so with the Animations setting off each jumps to where it
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
---@class PagleShopPurchaseMotion
---@field press Frame              the bill's Buy, which gives under the press
---@field seal PagleSprite         the wax seal, hidden, anchored by ns.CenterSpriteAt where it lands on the bill
---@field bezel Frame              the bill's medallion, which lifts off
---@field flyer Frame              the medallion that flies, its icon set, hidden
---@field from number[]            the bill's medallion's top left on the case
---@field to number[]?             the row's medallion's top left on the case; nil with no row to fly to
---@field closeBill fun(owner: Frame) lifts the bill away on `owner`'s clock (ns.CloseShopBill)
---@field balance fun(coins: number) writes the purse's balance
---@field balanceFrom number
---@field balanceTo number
---@field coin PagleSprite         the purse's coin, anchored by ns.CenterSpriteAt so it turns about its centre
---@field row fun(): PagleShopRowMotion? draws the row's new state, faded out; nil with no row
---@field lid fun(): Region[], Region[] draws the lid's new foot, faded out: what goes, and what comes

--- A row's change at delivery: what fades out, what fades in, the glow, and the slot's old good stepping down.
---@class PagleShopRowMotion
---@field out Region[]
---@field into Region[]
---@field glow Texture
---@field stepOut Region[]?
---@field stepIn Region[]?

-- Runs each step of `steps` ({ seconds, fn }, in order) once its time comes, on `owner`'s clock; `onDone` runs once
-- everything `owner` plays has finished.
---@param owner Frame
---@param steps { [1]: number, [2]: fun() }[]
---@param onDone fun()
local function timeline(owner, steps, onDone)
	local nextStep, last = 1, steps[#steps][1]
	ns.Animate(owner, {
		{
			dur = last,
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { last } } },
			apply = function(v)
				while steps[nextStep] and steps[nextStep][1] <= v[1] + 1e-6 do
					local step = steps[nextStep][2]
					nextStep = nextStep + 1
					step()
				end
			end,
		},
	}, onDone)
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
			end,
		},
		{
			1.4,
			function()
				local row = m.row()
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
