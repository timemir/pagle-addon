---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The text helper (CORE-R8, logic/Text.lua): named {fields}, CLDR plurals and number separators. Here Core gives it to
-- Modules as Pagle.Text.
ns.PublishText(Pagle)
