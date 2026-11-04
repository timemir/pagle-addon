-- A test fixture, never shipped (spec/Pagle/adapter/Fonts_spec.lua): the four Locales whose scripts the bundled faces
-- lack, under their real client codes and with ASCII names, listed so that the Language can choose each.
local ns = select(2, ...)

for _, code in ipairs({ "ruRU", "koKR", "zhCN", "zhTW" }) do
	ns.Locale(code, function() end, {
		name = code,
		listed = true,
		plural = function()
			return "other"
		end,
		decimal = ".",
		thousands = ",",
	})
end
