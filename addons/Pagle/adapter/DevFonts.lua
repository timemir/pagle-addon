---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- `/pagle dev fonts` on the client (#522, logic/DevFonts.lua): tries a font file on a hidden font string and measures
-- text in it.

--- A meter for the probe: a function that tries SetFont on `path` at the probe's size and answers nil if the client
--- won't load it, else a function that gives the width of a text in that font (GetStringWidth). One hidden font string
--- is made and reused, and is set again for each path.
---@return PagleFontMeter
function ns.DevFontMeter()
	local text = UIParent:CreateFontString(nil, "OVERLAY")
	text:Hide()
	text:SetWordWrap(false)
	return function(path)
		local ok, loaded = pcall(text.SetFont, text, path, ns.DEV_FONT_SIZE, "")
		if not ok or loaded == false then
			return nil
		end
		return function(chars)
			text:SetText(chars)
			return text:GetStringWidth()
		end
	end
end
