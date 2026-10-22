-- PagleArtGuide / Views.lua
-- A book's spreads ("views": the Hunts board, a set's pages, the Stats home, This Session...) and the page turn
-- between them. Timings are in MOTION.md.
--
-- Each view owns a content frame on each page, fixed to the page, inside a clip frame whose visible strip can
-- be narrowed from either edge. A page turn is then two complementary wipes, no frame levels involved:
--   forward (to a later ribbon): the right page lifts away toward the spine, uncovering the new right page
--   (0.22 s, ease-in), then lands on the left from the spine outward, covering the old left page (0.28 s,
--   ease-out). Backward is the mirror image. A fold shade darkens the lifting page and a soft shadow falls on
--   the page beside the moving edge; both are plain textures on one frame above the pages.

local ADDON, P = ...

local function pageOf(page)
  local clip = CreateFrame("Frame", nil, page)
  clip:SetClipsChildren(true)
  clip:SetAllPoints()
  local c = CreateFrame("Frame", nil, clip)
  c:SetAllPoints(page)
  c.clip, c.page = clip, page
  return c
end

-- show only the strip [a, b] (fractions of the page's width) of a view's page
local function reveal(c, w, a, b)
  local clip = c.clip
  if b - a <= 0.002 then clip:Hide(); return end
  clip:Show()
  clip:ClearAllPoints()
  clip:SetPoint("TOPLEFT", c.page, "TOPLEFT", a * w, 0)
  clip:SetPoint("BOTTOMLEFT", c.page, "BOTTOMLEFT", a * w, 0)
  clip:SetWidth((b - a) * w)
end

-- the fold: a shade over the turning strip and a cast shadow beside its edge
local function fold(book)
  if book.foldFrame then return book.foldFrame end
  local f = CreateFrame("Frame", nil, book.Pages)
  f:SetAllPoints(); f:SetFrameLevel(book.Pages:GetFrameLevel() + 40)
  f.shade = f:CreateTexture(nil, "OVERLAY", nil, 0); f.shade:SetColorTexture(0.16, 0.08, 0.02, 1)
  f.cast = f:CreateTexture(nil, "OVERLAY", nil, 1); f.cast:SetColorTexture(1, 1, 1, 1)
  f.edge = f:CreateTexture(nil, "OVERLAY", nil, 2); f.edge:SetColorTexture(1, 0.97, 0.85, 1)
  f:Hide()
  book.foldFrame = f
  return f
end

-- place the fold: the turning strip [x0, x1] on `page` (units from the page's left), its moving edge at `ex`,
-- the cast shadow on the side `side` (-1 left of the edge, 1 right of it)
local function placeFold(f, page, x0, x1, ex, side, shade, cast)
  f.shade:ClearAllPoints(); f.shade:SetPoint("TOPLEFT", page, "TOPLEFT", x0, 0); f.shade:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", x0, 0)
  f.shade:SetWidth(math.max(0.01, x1 - x0)); f.shade:SetAlpha(shade)
  local cw = 26
  f.cast:ClearAllPoints()
  f.cast:SetPoint("TOPLEFT", page, "TOPLEFT", side > 0 and ex or ex - cw, 0); f.cast:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", side > 0 and ex or ex - cw, 0)
  f.cast:SetWidth(cw)
  local dark, clear = CreateColor(0.12, 0.06, 0.02, 0.32 * cast), CreateColor(0.12, 0.06, 0.02, 0)
  if side > 0 then f.cast:SetGradient("HORIZONTAL", dark, clear) else f.cast:SetGradient("HORIZONTAL", clear, dark) end
  f.edge:ClearAllPoints(); f.edge:SetPoint("TOPLEFT", page, "TOPLEFT", ex - (side > 0 and 1.5 or 0), 0); f.edge:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", ex - (side > 0 and 1.5 or 0), 0)
  f.edge:SetWidth(1.5); f.edge:SetAlpha(0.55 * cast)
end

local function build(book, v)
  if v.L then return end
  v.L, v.R = pageOf(book.LeftPage), pageOf(book.RightPage)
  v.build(v.L, v.R, book, v)
end

-- views: list of { key, order, ribbon (index or nil), crumbs = {...}, crumbTo = { [i] = key }, build(L, R, book, view),
-- (Ledger: a view can also be added later with P.AddView, and ShowView takes an explicit direction)
-- onShow(view) } ; ribbonList/ribbonOpts as P.Ribbons
function P.InitViews(book, views, ribbonList, ribbonOpts)
  book.views = {}
  for _, v in ipairs(views) do book.views[v.key] = v end
  if ribbonList then -- the Ledger has no ribbons: its continents are tabs on the page
    ribbonOpts.onSelect = function(i)
      for _, v in ipairs(views) do if v.ribbon == i then P.ShowView(book, v.key, true) return end end
    end
    book.ribbons = P.Ribbons(book, ribbonList, ribbonOpts)
  end
  book:SetScript("OnShow", function() P.OpenBook(book) end)
end

local function crumbs(book, v)
  book:SetCrumbs(v.crumbs, function(i)
    local to = v.crumbTo and v.crumbTo[i]
    if to then P.ShowView(book, to, true) end
  end)
end

function P.AddView(book, v) book.views[v.key] = v end

-- dir: optionally force the turn's direction ("fwd" or "back"); otherwise it follows the views' order
function P.ShowView(book, key, animate, dir)
  local to = book.views[key]
  local from = book.view and book.views[book.view]
  if from == to then return end
  build(book, to)
  if book.ribbons and book.ribbons.Select then book.ribbons.Select(to.ribbon, animate) end
  local lw, rw = book.leftW or book.LeftPage:GetWidth(), book.rightW or book.RightPage:GetWidth()
  if to.onShow then to.onShow(to) end
  book.view = key
  if not (animate and from and P.motion) then
    if from then from.L.clip:Hide(); from.R.clip:Hide() end
    reveal(to.L, lw, 0, 1); reveal(to.R, rw, 0, 1)
    crumbs(book, to)
    if animate and from then P.Sound("pageTurn") end
    return
  end

  -- the turn
  P.Sound("pageTurn")
  local fwd = (to.order or 0) > (from.order or 0)
  if dir then fwd = (dir == "fwd") end
  local f = fold(book); f:Show()
  local owner = book.turnOwner or {}; book.turnOwner = owner
  P.StopMotion(owner)
  if fwd then
    reveal(to.L, lw, 1, 1); reveal(from.L, lw, 0, 1)
  else
    reveal(to.R, rw, 0, 0); reveal(from.R, rw, 0, 1)
  end
  local A1, A2 = 0.22, 0.28
  P.Animate(owner, {
    -- first half: the page lifts toward the spine
    { dur = A1, ease = P.Bezier(0.5, 0, 0.9, 0.6), keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = function(v)
      local k = v[1]
      if fwd then
        reveal(from.R, rw, 0, 1 - k); reveal(to.R, rw, 1 - k, 1)
        placeFold(f, book.RightPage, 0, (1 - k) * rw, (1 - k) * rw, 1, 0.28 * k, 1)
      else
        reveal(from.L, lw, k, 1); reveal(to.L, lw, 0, k)
        placeFold(f, book.LeftPage, k * lw, lw, k * lw, -1, 0.28 * k, 1)
      end
    end },
    -- second half: it lands on the other page, from the spine outward
    { dur = A2, delay = A1, ease = P.Bezier(0.1, 0.4, 0.4, 1), keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = function(v)
      local k = v[1]
      if k <= 0 then return end
      if fwd then
        from.R.clip:Hide(); reveal(to.R, rw, 0, 1)
        reveal(to.L, lw, 1 - k, 1); reveal(from.L, lw, 0, 1 - k)
        placeFold(f, book.LeftPage, (1 - k) * lw, lw, (1 - k) * lw, -1, 0.28 * (1 - k), 1 - k)
      else
        from.L.clip:Hide(); reveal(to.L, lw, 0, 1)
        reveal(to.R, rw, 0, k); reveal(from.R, rw, k, 1)
        placeFold(f, book.RightPage, 0, k * rw, k * rw, 1, 0.28 * (1 - k), 1 - k)
      end
    end },
  }, function()
    from.L.clip:Hide(); from.R.clip:Hide()
    reveal(to.L, lw, 0, 1); reveal(to.R, rw, 0, 1)
    f:Hide()
  end)
  -- the crumbs change as the leaf passes the spine
  P.Cue(owner, A1, function() crumbs(book, to) end)
end

-- opening and closing: a short fade, with the book's sounds
function P.OpenBook(book)
  P.Sound("bookOpen")
  if book.onOpen then book.onOpen() end
  P.StopMotion(book)
  P.Animate(book, { { dur = 0.16, ease = P.Ease.out, keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = function(v) book:SetAlpha(v[1]) end } })
end

function P.CloseBook(book)
  P.Sound("bookClose")
  local owner = book.closeOwner or {}; book.closeOwner = owner
  P.Animate(owner, { { dur = 0.12, ease = P.Bezier(0.42, 0, 1, 1), keys = { { 0, { 1 } }, { 1, { 0 } } }, apply = function(v) book:SetAlpha(v[1]) end } },
    function() book:Hide(); book:SetAlpha(1) end)
end
