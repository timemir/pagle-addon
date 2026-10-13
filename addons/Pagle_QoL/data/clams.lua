if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The clam table (QOL-R57): QoL's own, hand-kept, outside the content data pipeline (qol.md › Shipped tables). It
-- holds only containers that open with a plain item use; locked boxes and other treasure aren't clams. Names come
-- from C_Item at runtime. Opening a clam through PagleQoLActionButton is re-verified in M8 (QOL-R100), which also
-- looks for Forever's own clams; if clams can't open by item use, this file, logic/Clams.lua, adapter/Clams.lua and
-- the ladder's step 5 go.

--- The three Classic clams, by item ID, from the Classic baseline (QOL-R57).
---@type integer[]
ns.CLAMS = {
	5523, -- Small Barnacled Clam
	5524, -- Thick-shelled Clam
	7973, -- Big-mouth Clam
}
