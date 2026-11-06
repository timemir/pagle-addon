-- busted's helper for the layout harness (tour.lua): every font string the fake client makes measures in its real
-- face (realfont.lua), then spec/support/addon.lua loads as for any spec.
dofile("scripts/measure-layout/realfont.lua").install()
dofile("spec/support/addon.lua")
