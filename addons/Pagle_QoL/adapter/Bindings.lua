if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The names Key Bindings › AddOns shows for Bindings.xml: its "Pagle" header and the Fishing key (QOL-R1, QOL-R10).
BINDING_HEADER_PAGLE = ns.L.BINDING_HEADER
BINDING_NAME_PAGLE_FISHING_KEY = ns.L.BINDING_FISHING_KEY
-- Swap gear (QOL-R1, QOL-R46).
BINDING_NAME_PAGLE_SWAP_GEAR = ns.L.BINDING_SWAP_GEAR
