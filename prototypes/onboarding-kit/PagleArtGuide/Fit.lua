-- Fit.lua (shared by the Pagle art probes)
-- Big windows (the books, the Tackle Board, the Curio Shop) are drawn at 1 UI unit per canvas px. At a large
-- UI scale on a 16:9 screen UIParent is only 668 units tall (768 / 1.15), less than a book with its ribbons,
-- so a window shrinks itself to fit, never grows, and re-fits when the UI scale or the window size changes.

local ADDON, P = ...

local fitted = {}

-- w, h: the window's whole extent in its own units, including what hangs outside its frame (ribbons, a
-- plate, the wax close button); dy: how far the frame's centre sits above that extent's centre;
-- want: the scale asked for (default 1). Returns the scale used.
function P.FitToScreen(f, w, h, dy, want)
  local margin = 24
  local s = math.min(want or 1, (UIParent:GetHeight() - 2 * margin) / h, (UIParent:GetWidth() - 2 * margin) / w)
  f:SetScale(s)
  f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 0, dy or 0) -- offsets are in f's own (scaled) units
  fitted[f] = { w, h, dy, want }
  return s
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("UI_SCALE_CHANGED"); ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:SetScript("OnEvent", function()
  for f, a in pairs(fitted) do P.FitToScreen(f, a[1], a[2], a[3], a[4]) end
end)
