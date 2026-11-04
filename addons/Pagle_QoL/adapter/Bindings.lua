if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The names Key Bindings › AddOns shows for Bindings.xml: its "Pagle" header and the Fishing key (QOL-R1, QOL-R10),
-- and the Swap gear key (QOL-R1, QOL-R46). The client reads these globals when it shows the panel, not when this file
-- loads, so they are set from QoL's OnInitialize, once the Language is applied (CORE-R8).
function ns.NameBindings()
	BINDING_HEADER_PAGLE = ns.L.BINDING_HEADER
	BINDING_NAME_PAGLE_FISHING_KEY = ns.L.BINDING_FISHING_KEY
	BINDING_NAME_PAGLE_SWAP_GEAR = ns.L.BINDING_SWAP_GEAR
end
