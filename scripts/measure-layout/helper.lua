-- busted's helper for the layout harness (tour.lua): every font string the fake client makes measures in its real
-- face (realfont.lua), then spec/support/addon.lua loads as for any spec. MEASURE_REALFONT is the RealFont installed,
-- for the tour to measure with: it keeps the font objects the client's CreateFont makes by name (#620).
MEASURE_REALFONT = dofile("scripts/measure-layout/realfont.lua")
MEASURE_REALFONT.install()
dofile("spec/support/addon.lua")
