---@class PagleNS
local ns = select(2, ...)

-- The length unit (LOG-R69): how a length in millimetres reads, in the Angler's unit. Pure logic over the stored
-- unit (PagleDB.profile.lengthUnit) and what GetCurrentRegion() answered; Pagle.FormatLength and the size ruler
-- (ANN-R22) read it through logic/Wiring.lua's ns.WireLength. Only the display changes with the unit: lengths are
-- compared in millimetres.

---@alias PagleLengthUnit "cm"|"in"

--- The length units, in the order the Settings root lists them (SET-R10).
---@type PagleLengthUnit[]
ns.LENGTH_UNITS = { "cm", "in" }

-- Millimetres in one of each unit.
local MILLIMETRES = { cm = 10, ["in"] = 25.4 }

--- The unit lengths show in (LOG-R69): `stored` when it is "cm" or "in"; otherwise the region default, inches on
--- region 1 (Americas and Oceania) and centimetres on any other region or none (GetCurrentRegion missing).
---@param stored string?
---@param region integer?
---@return PagleLengthUnit
function ns.LengthUnitOf(stored, region)
	if stored == "cm" or stored == "in" then
		return stored
	end
	return region == 1 and "in" or "cm"
end

--- `mm` millimetres in `unit`, to 0.1 of it: "34.2 cm", "13.5 in" (LOG-R69).
---@param mm number
---@param unit PagleLengthUnit
---@return string
function ns.FormatLength(mm, unit)
	return ns.L.LENGTH[unit]:format(mm / MILLIMETRES[unit])
end

--- A size record's margin of `mm` millimetres in `unit` (ANN-R22): "+4.2 cm", or "+<0.1 cm" when it rounds to zero
--- at 0.1 of the unit.
---@param mm number
---@param unit PagleLengthUnit
---@return string
function ns.FormatLengthMargin(mm, unit)
	if ("%.1f"):format(mm / MILLIMETRES[unit]) == "0.0" then
		return ns.L.LENGTH_MARGIN_UNDER[unit]
	end
	return "+" .. ns.FormatLength(mm, unit)
end
