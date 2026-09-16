--[[ pixel-plants :: shared drawing library (Aseprite Lua, batch mode)
     Deterministic pixel-art plant tiles. No randomness: a per-item seed
     drives all variation so every rerun reproduces byte-identical output.

     Canvas: every tile is drawn on a 64x64 grid. The composition was tuned
     on a 16px grid (trees on 32px), so every archetype receives a scale
     factor S = w/16 (trees ST = w/32) and multiplies its hand-placed
     pixel constants by it; radii that were already proportional to w/h
     recompute directly at the larger canvas.

     Layer stack (bottom -> top), identical for every tile:
       shadow | stem | leaf | bloom-shade | bloom | core | glint
]]

-- ---------------------------------------------------------------- helpers
local function C(hex, a)
  return Color(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16),
               tonumber(hex:sub(6, 7), 16), a or 255)
end

local function pset(im, x, y, col)
  if col and x >= 0 and y >= 0 and x < im.width and y < im.height then
    im:putPixel(x, y, col)
  end
end

-- s x s block of col with its top-left at (x, y): one tuned pixel, scaled
local function blk(im, x, y, col, s)
  for dy = 0, s - 1 do
    for dx = 0, s - 1 do pset(im, x + dx, y + dy, col) end
  end
end

local function line(im, x0, y0, x1, y1, col)
  local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    pset(im, x0, y0, col)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

-- Bresenham with a centered t x t brush (thick stems / branches)
local function tline(im, x0, y0, x1, y1, col, t)
  if t <= 1 then line(im, x0, y0, x1, y1, col); return end
  local o = math.floor(t / 2)
  local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    for by = 0, t - 1 do
      for bx = 0, t - 1 do pset(im, x0 + bx - o, y0 + by - o, col) end
    end
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

local function disc(im, cx, cy, r, col)
  local rr = r * r + r * 0.4
  for y = cy - r, cy + r do
    for x = cx - r, cx + r do
      local dx, dy = x - cx, y - cy
      if dx * dx + dy * dy <= rr then pset(im, x, y, col) end
    end
  end
end

local function ring(im, cx, cy, r, col, keep)
  local rr = r * r + r * 0.4
  for y = cy - r, cy + r do
    for x = cx - r, cx + r do
      local dx, dy = x - cx, y - cy
      if dx * dx + dy * dy <= rr then
        local inner = (r - 1) * (r - 1) + (r - 1) * 0.4
        if dx * dx + dy * dy > inner then pset(im, x, y, col) end
      end
    end
  end
end

-- elliptical ground shadow: 1 full row + S central rows
local function ground_shadow(I, w, h, cx, col, S)
  local rx1 = math.max(3, math.floor(w * 0.26)) + 1
  local cy = h - 2
  for x = cx - rx1, cx + rx1 do
    local t = (x - cx) / (rx1 + 0.5)
    if t * t <= 1 then
      pset(I.shadow, x, cy, col)
      if t * t <= 0.45 then
        for j = 1, S do pset(I.shadow, x, cy - j, col) end
      end
    end
  end
end

-- ---------------------------------------------------------------- seed
local function rng(seed, i)
  local x = (seed * 1103515245 + i * 12345 + 1013904223) % 2147483648
  return x / 2147483648.0
end

-- ---------------------------------------------------------------- plant parts
local function stem_to(I, x0, y0, x1, y1, col, t)
  tline(I.stem, x0, y0, x1, y1, col, t or 1)
end

-- small side leaf; dir = -1 left, +1 right
local function side_leaf(I, x, y, dir, colD, colL, S)
  blk(I.leaf, x, y, colD, S)
  blk(I.leaf, x + dir * S, y - S, colL, S)
  blk(I.leaf, x + dir * S, y, colL, S)
  blk(I.leaf, x + 2 * dir * S, y, colL, S)
  blk(I.leaf, x + dir * S, y + S, colD, S)
  blk(I.leaf, x + 2 * dir * S, y + S, colD, S)
end

local function blade(I, x, yTop, yBase, lean, colL, colD, S)
  local steps = yBase - yTop
  for i = 0, steps do
    local t = i / math.max(1, steps)
    local x0 = x + math.floor(lean * t + 0.5)
    local wdt = math.max(1, math.floor(S * (0.3 + 0.7 * t) + 0.5))
    for dx = 0, wdt - 1 do
      pset(I.leaf, x0 + dx - math.floor(wdt / 2), yTop + i, (t > 0.6) and colD or colL)
    end
  end
end

-- round bloom head with a shaded lower-right rim, core dot, single glint
local function bloom_round(I, cx, cy, r, P, g)
  disc(I.bloom, cx, cy, r, P.main)
  -- lower-right shade rim (skip for 1px heads: it would erase the main colour)
  if r >= 2 then
    for a = 0, r do
      for b = 0, r do
        if a * a + b * b <= (r + 0.4) * (r + 0.4) and (a + b) >= r + 1 then
          pset(I.bloomShade, cx + a, cy + b, P.accent)
        end
      end
    end
    pset(I.bloomShade, cx + r, cy, P.accent)
    pset(I.bloomShade, cx, cy + r, P.accent)
  end
  -- core must stay strictly smaller than the head, else the dot hides the petal colour
  if r >= 2 then
    disc(I.core, cx, cy, math.floor(r / 3), P.dot)
  else
    blk(I.core, cx, cy, P.dot, g)
  end
  blk(I.glint, cx - 1, cy - 1, P.glint, g)
  if r >= 3 then blk(I.glint, cx - r + 1, cy - 1, P.glint, g) end
end

-- star bloom: n thin petals radiating from a small core
local function bloom_star(I, cx, cy, n, rin, rout, P, g)
  for i = 0, n - 1 do
    local ang = (i / n) * 2 * math.pi + 0.35
    for t = rin, rout do
      local x = cx + math.floor(math.cos(ang) * t + 0.5)
      local y = cy + math.floor(math.sin(ang) * t + 0.5)
      pset((i % 2 == 0) and I.bloom or I.bloomShade, x, y,
           (i % 2 == 0) and P.main or P.accent)
    end
  end
  disc(I.core, cx, cy, g, P.dot)
  blk(I.glint, cx, cy - 1, P.glint, g)
end

-- one bell / trumpet hanging downward (unused by archetypes, kept for parity)
local function bloom_bell(I, cx, cy, P, wide, S)
  local g = math.max(1, math.floor(S / 2 + 0.5))
  for i = 0, 3 do
    local half = math.floor(i * S / 2)
    for yy = 0, S - 1 do
      for x = cx - half, cx + half do pset(I.bloom, x, cy + i * S + yy, P.main) end
    end
  end
  blk(I.bloom, cx, cy + 4 * S, P.dot, g)
  for yy = 0, S - 1 do pset(I.bloomShade, cx + S, cy + 3 * S + yy, P.accent) end
  blk(I.bloomShade, cx, cy, P.accent, S)
  blk(I.glint, cx - S, cy + S, P.glint, g)
end

local function bead(I, cx, cy, r, P, g)
  disc(I.bloom, cx, cy, r, P.main)
  blk(I.bloomShade, cx + r, cy + r, P.accent, g)
  if r >= 1 then blk(I.core, cx, cy, P.dot, g) end
  blk(I.glint, cx - 1, cy - 1, P.glint, g)
end

-- 8 compass directions; y is halved so heads stay round on a square grid
local DIR8 = { { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 } }

local DIR6 = { { 0, -1 }, { 1, -1 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, -1 } }

local function offy(k, dy)
  if dy == 0 then return 0 end
  local v = math.floor(k * 0.8 + 0.5)
  return dy > 0 and v or -v
end

-- one hanging bell (narrow top, wider rim, dot at the mouth)
local function bell_at(I, bx, by, P, S)
  local g = math.max(1, math.floor(S / 2 + 0.5))
  blk(I.bloom, bx, by, P.main, S)
  for row = 1, 2 do
    for yy = 0, S - 1 do
      for x = bx - S, bx + S do pset(I.bloom, x, by + row * S + yy, P.main) end
    end
  end
  for yy = 0, 2 * S - 1 do pset(I.bloomShade, bx + S, by + S + yy, P.accent) end
  blk(I.bloomShade, bx, by, P.accent, S)
  blk(I.core, bx, by + 2 * S, P.dot, S)
  blk(I.glint, bx - S, by + S, P.glint, g)
end

-- rounded two-tone lobe (lithops body, paw pads)
local function lobe(im, cx, cy, r, colTop, colBot, splitY)
  for y = cy - r, cy + r do
    for x = cx - r, cx + r do
      local dx, dy = x - cx, y - cy
      if dx * dx + dy * dy <= r * r + r * 0.4 then
        pset(im, x, y, (splitY and y >= splitY) and colBot or colTop)
      end
    end
  end
end

-- ---------------------------------------------------------------- archetypes
-- Every archetype receives: I (layer images), P (palette), w, h, seed,
-- S (16-grid scale), ST (32-grid scale), g (small-detail unit).
local A = {}

-- single blossom on a stem with two side leaves
function A.floret(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local by = math.floor(h * 0.38)
  stem_to(I, cx, by + 2 * S, cx, gy, P.leafDark, S)
  stem_to(I, cx, by + 2 * S, cx + S, gy - S, P.leafDark, S)
  side_leaf(I, cx - S, gy - 3 * S, -1, P.leafDark, P.leafLight, S)
  side_leaf(I, cx + S, gy - 5 * S, 1, P.leafDark, P.leafLight, S)
  bloom_round(I, cx, by, math.max(2, math.floor(w * 0.22)), P, g)
end

-- many thin petals, flat head
function A.daisy(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local by = math.floor(h * 0.34)
  stem_to(I, cx, by + 3 * S, cx, gy, P.leafDark, S)
  side_leaf(I, cx - S, gy - 4 * S, -1, P.leafDark, P.leafLight, S)
  side_leaf(I, cx + S, gy - 6 * S, 1, P.leafDark, P.leafLight, S)
  local rout = math.max(3, math.floor(w * 0.24))
  local cr = math.max(1, math.floor(S / 2) + 1)
  local kin = cr + math.max(1, math.floor(S / 2))
  for i = 1, 8 do
    local d = DIR8[i]
    for k = kin, rout do
      local x = cx + d[1] * k
      local y = by + offy(k, d[2])
      if k == rout then
        blk(I.bloomShade, x, y, P.accent, g)
      else
        blk(I.bloom, x, y, P.main, g)
      end
    end
  end
  disc(I.core, cx, by, cr, P.dot)
  blk(I.glint, cx - g, by - g, P.glint, g)
end

-- long thin radiating petals, bare stem (spider lily)
function A.spider(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local by = math.floor(h * 0.36)
  stem_to(I, cx, gy, cx, by + 2 * S, P.leafDark, S)
  local rout = math.max(4, math.floor(w * 0.34))
  local cr = math.max(1, math.floor(S / 2) + 1)
  local kin = cr + math.max(1, math.floor(S / 2))
  for i = 1, 6 do
    local d = DIR6[i]
    for k = kin, rout do
      blk(I.bloom, cx + d[1] * k, by + offy(k, d[2]), P.main, g)
    end
    blk(I.bloomShade, cx + d[1] * (rout + g), by + offy(rout, d[2]) + g, P.accent, g)
  end
  disc(I.core, cx, by, cr, P.dot)
  blk(I.glint, cx - g, by - g, P.glint, g)
  blk(I.core, cx - 2 * S, by - 3 * S, P.dot, g)
  blk(I.core, cx + 2 * S, by - 3 * S, P.dot, g)
end

-- bells hanging from an arched stem
function A.bell(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.24)
  stem_to(I, cx, gy, cx, top, P.leafDark, S)
  side_leaf(I, cx - S, gy - 4 * S, -1, P.leafDark, P.leafLight, S)
  side_leaf(I, cx + S, gy - 6 * S, 1, P.leafDark, P.leafLight, S)
  local n = (w >= 48) and 5 or ((w >= 32) and 4 or 3)
  local gap = (w >= 48) and math.floor(w * 0.14) or ((w >= 32) and 6 or 4)
  for i = 1, n do
    local off = (i - (n + 1) / 2)
    local bx = cx + math.floor(off * gap + (off > 0 and 0.5 or -0.5))
    local by = top + 2 * S + math.floor(math.abs(off) * 0.75 * S + 0.5)
    stem_to(I, cx, top + 2 * S, bx, by, P.leafDark, S)
    bell_at(I, bx, by, P, S)
  end
end

-- vertical spike of florets (lavender / lupin / larkspur)
function A.spike(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.22)
  stem_to(I, cx, gy, cx, top, P.leafDark, S)
  blade(I, cx - 2 * S, gy - 6 * S, gy, -S, P.leafLight, P.leafDark, S)
  blade(I, cx + 2 * S, gy - 6 * S, gy, S, P.leafLight, P.leafDark, S)
  blade(I, cx - 4 * S, gy - 3 * S, gy, -S, P.leafDark, P.leafDark, S)
  local rows = math.max(5, math.floor(h * 0.4))
  for i = 0, rows do
    local y = top + i
    local t = 1 - i / rows
    local half = (t > 0.75) and 0 or (t > 0.35 and S or 2 * S)
    for x = cx - half, cx + half do
      local col = ((x + y) % 3 == 0) and P.accent or P.main
      pset(I.bloom, x, y, col)
    end
  end
  blk(I.core, cx, top, P.dot, g)
  blk(I.glint, cx - g, top + g, P.glint, g)
end

-- 3 small round blooms on branching stems
function A.cluster(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local by = math.floor(h * 0.42)
  stem_to(I, cx, by + 3 * S, cx, gy, P.leafDark, S)
  side_leaf(I, cx - S, gy - 4 * S, -1, P.leafDark, P.leafLight, S)
  side_leaf(I, cx + S, gy - 5 * S, 1, P.leafDark, P.leafLight, S)
  local spots = { { -math.floor(w * 0.18), -S }, { 0, -3 * S }, { math.floor(w * 0.18), 0 } }
  for i, s in ipairs(spots) do
    local bx, byy = cx + s[1], by + s[2]
    stem_to(I, cx, by + 2 * S, bx, byy + 2 * S, P.leafDark, S)
    bloom_round(I, bx, byy, math.max(1, math.floor(w * 0.11)), P, g)
  end
end

-- flat-topped umbel: many tiny heads fanning from one point
function A.umbel(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.36)
  stem_to(I, cx, gy, cx, top, P.leafDark, S)
  side_leaf(I, cx - S, gy - 4 * S, -1, P.leafDark, P.leafLight, S)
  side_leaf(I, cx + S, gy - 6 * S, 1, P.leafDark, P.leafLight, S)
  local n = (w >= 48) and 9 or ((w >= 32) and 7 or 5)
  for i = 1, n do
    local t = (i - (n + 1) / 2) / ((n + 1) / 2)
    local bx = cx + math.floor(t * w * 0.28)
    local by = top - math.floor((1 - math.abs(t)) * h * 0.08)
    stem_to(I, cx, top + S, bx, by, P.leafDark, S)
    bloom_round(I, bx, by - S, math.max(1, math.floor(S / 2) + 1), P, g)
  end
  blk(I.core, cx, top, P.dot, g)
end

-- leafy herbal clump, tiny dots as flowers
function A.herb(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local n = (w >= 48) and 7 or ((w >= 32) and 6 or 5)
  for i = 1, n do
    local t = (i - (n + 1) / 2) / ((n + 1) / 2)
    local lean = t * w * 0.34
    local tall = h * (0.34 + 0.14 * math.abs(t))
    blade(I, cx, math.floor(gy - tall), gy, lean, P.leafLight, P.leafDark, S)
  end
  local k = rng(sd, 7)
  blk(I.bloom, cx - S + math.floor(k * 2 * S), gy - math.floor(h * 0.5), P.main, g)
  blk(I.bloom, cx + 2 * S, gy - math.floor(h * 0.44), P.accent, g)
  blk(I.core, cx + S, gy - math.floor(h * 0.56), P.dot, g)
end

-- pure grass / reed clump
function A.grass(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local n = (w >= 48) and 8 or ((w >= 32) and 7 or 6)
  for i = 1, n do
    local t = (i - (n + 1) / 2) / ((n + 1) / 2)
    local lean = t * w * 0.3
    local tall = h * (0.42 + 0.2 * (1 - math.abs(t)))
    blade(I, cx, math.floor(gy - tall), gy, lean, P.leafLight, P.leafDark, S)
  end
  blade(I, cx, math.floor(gy - h * 0.68), gy, 0, P.leafDark, P.leafDark, S)
  blk(I.bloom, cx, math.floor(gy - h * 0.62), P.main, g)
  blk(I.core, cx, math.floor(gy - h * 0.66), P.dot, g)
end

-- climbing / twining stems with leaves and blooms near the top
function A.vine(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.18)
  local amp = w * 0.16
  local steps = math.max(8, math.floor(h * 0.9))
  local prev = nil
  local at = {}
  for i = 0, steps do
    local t = i / steps
    local x = cx + math.floor(math.sin(t * 5.0) * amp + 0.5)
    local y = gy - math.floor(t * (gy - top))
    at[i] = { x, y }
    if prev then stem_to(I, prev[1], prev[2], x, y, P.leafDark, S) end
    prev = { x, y }
  end
  local stride = math.max(3, math.floor(steps / 5))
  for i = stride, steps - stride, stride do
    local p = at[i]
    side_leaf(I, p[1], p[2], (i % 2 == 0) and 1 or -1, P.leafDark, P.leafLight, S)
  end
  for i = 0, 2 do
    local p = at[math.floor(steps * (0.74 + i * 0.11))]
    if i == 1 then
      bloom_round(I, p[1], p[2] - S, math.max(1, math.floor(w * 0.12)), P, g)
    else
      bell_at(I, p[1], p[2], P, S)
    end
  end
end

-- slender orchid-like bloom on a tall stem
function A.orchid(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local by = math.floor(h * 0.3)
  stem_to(I, cx, gy, cx, by + 2 * S, P.leafDark, S)
  blade(I, cx - 2 * S, gy - 6 * S, gy, -2 * S, P.leafLight, P.leafDark, S)
  blade(I, cx + 2 * S, gy - 6 * S, gy, 2 * S, P.leafLight, P.leafDark, S)
  -- connected bloom in S-blocks: standard top, accent falls, wide side petals, lip
  local rows = {
    { -3, { { 0, "main" } } },
    { -2, { { -1, "accent" }, { 0, "main" }, { 1, "accent" } } },
    { -1, { { -1, "main" }, { 0, "main" }, { 1, "main" } } },
    { 0, { { -3, "main" }, { -2, "main" }, { -1, "main" },
           { 0, "main" }, { 1, "main" }, { 2, "main" }, { 3, "main" } } },
    { 1, { { 0, "main" } } },
  }
  for _, row in ipairs(rows) do
    for _, cell in ipairs(row[2]) do
      blk(I.bloom, cx + cell[1] * S, by + row[1] * S, P[cell[2]], S)
    end
  end
  blk(I.bloom, cx, by + 2 * S, P.dot, S)
  blk(I.bloomShade, cx - 2 * S, by + S, P.accent, S)
  blk(I.bloomShade, cx + 2 * S, by + S, P.accent, S)
  blk(I.glint, cx - g, by - 2 * S - g, P.glint, g)
end

-- berry / fruit cluster
function A.berry(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.4)
  stem_to(I, cx, gy, cx, top, P.leafDark, S)
  side_leaf(I, cx - S, gy - 4 * S, -1, P.leafDark, P.leafLight, S)
  side_leaf(I, cx + S, gy - 6 * S, 1, P.leafDark, P.leafLight, S)
  local pts = { { 0, 0 }, { -1, 1 }, { 1, 1 }, { 0, 2 }, { -1, 3 }, { 1, 3 } }
  local k = (w >= 32) and 6 or 4
  local r = (w >= 48) and S or math.max(1, math.floor(S / 2))
  for i = 1, k do
    local p = pts[i]
    bead(I, cx + p[1] * 2 * S, top + p[2] * 2 * S + S, r, P, g)
  end
end

-- floating aquatic: pads on water + one bloom
function A.aquatic(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local wy = h - 4 * S
  local pad = P.leafLight
  for x = 2 * S, w - 1 - 2 * S do pset(I.stem, x, wy + 2 * S, P.water) end
  for yy = 0, S - 1 do
    pset(I.stem, 2 * S, wy + S + yy, P.waterHi)
    pset(I.stem, w - 1 - 3 * S, wy + S + yy, P.waterHi)
  end
  disc(I.leaf, cx - math.floor(w * 0.2), wy + 2 * S, math.max(2, math.floor(w * 0.16)), pad)
  blk(I.leaf, cx - math.floor(w * 0.2), wy + 2 * S, P.leafDark, g)
  local br = math.max(2, math.floor(w * 0.125))
  local bx = cx + math.floor(w * 0.14)
  disc(I.bloom, bx, wy, br, P.main)
  blk(I.bloomShade, bx + math.floor(br * 0.6), wy + math.floor(br * 0.6), P.accent, g)
  blk(I.core, bx, wy, P.dot, g)
  blk(I.glint, bx - g, wy - g, P.glint, g)
end

-- fungus: cap + stalk, or kidney-shaped bracket with rings
function A.fungus(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local capy = math.floor(h * 0.42)
  for y = capy + S, gy do
    for x = cx - S, cx + S do
      pset(I.stem, x, y, (x > cx) and P.leafDark or P.leafLight)
    end
  end
  local r = math.max(2, math.floor(w * 0.26))
  for y = capy - math.floor(r * 0.7), capy do
    local dy = capy - y
    local half = math.floor(math.sqrt(math.max(0, r * r - (dy * 1.6) * (dy * 1.6))))
    for x = cx - half, cx + half do
      pset((dy > r * 0.45) and I.bloomShade or I.bloom, x, y,
           (dy > r * 0.45) and P.accent or P.main)
    end
  end
  blk(I.core, cx - S - g, capy - S, P.dot, g)
  blk(I.core, cx + S, capy - S, P.dot, g)
  blk(I.glint, cx - g, capy - S, P.glint, g)
end

-- round-canopy tree
function A.tree_round(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2
  local trunkTop = gy - math.floor(h * 0.3)
  local tw = 3 * ST
  for y = trunkTop, gy do
    for i = 0, tw - 1 do
      pset(I.stem, cx - math.floor(tw / 2) + i, y,
           (i >= tw - ST) and P.trunkDark or P.trunk)
    end
  end
  blk(I.stem, cx - math.floor(tw / 2) - ST, gy, P.trunkDark, ST)
  blk(I.stem, cx + math.ceil(tw / 2), gy, P.trunkDark, ST)
  local r = math.floor(w * 0.30)
  local ccy = trunkTop - math.floor(r * 0.9)
  disc(I.leaf, cx, ccy, r, P.leafLight)
  for y = ccy - r, ccy + r do
    for x = cx - r, cx + r do
      local dx, dy = x - cx, y - ccy
      if dx * dx + dy * dy <= r * r + r * 0.4 and (dx + dy) > r * 0.7 then
        pset(I.leaf, x, y, P.leafDark)
      end
    end
  end
  -- fruit dots
  local k = rng(sd, 3)
  for i = 0, 5 do
    local ang = i * 1.05 + k * 4
    local rr = r * 0.55
    local x = cx + math.floor(math.cos(ang) * rr)
    local y = ccy + math.floor(math.sin(ang) * rr * 0.8)
    blk(I.bloom, x, y, (i % 2 == 0) and P.main or P.dot, ST)
  end
  blk(I.glint, cx - math.floor(r * 0.5), ccy - math.floor(r * 0.5), P.glint, ST)
end

-- broad spreading canopy with visible branches
function A.tree_broad(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2
  local trunkTop = gy - math.floor(h * 0.24)
  local tw = 3 * ST
  for y = trunkTop, gy do
    for i = 0, tw - 1 do
      pset(I.stem, cx - math.floor(tw / 2) + i, y,
           (i >= tw - ST) and P.trunkDark or P.trunk)
    end
  end
  tline(I.stem, cx, trunkTop + ST, cx - math.floor(w * 0.22), trunkTop - math.floor(h * 0.14), P.trunkDark, ST)
  tline(I.stem, cx, trunkTop + 2 * ST, cx + math.floor(w * 0.22), trunkTop - math.floor(h * 0.12), P.trunkDark, ST)
  local rx = math.floor(w * 0.38)
  local ry = math.floor(h * 0.22)
  local ccy = trunkTop - ry - math.floor(h * 0.04)
  for y = ccy - ry, ccy + ry do
    for x = cx - rx, cx + rx do
      local dx, dy = (x - cx) / rx, (y - ccy) / ry
      if dx * dx + dy * dy <= 1.05 then
        local col = P.leafLight
        if (dx * 0.9 + dy) > 0.45 then col = P.leafDark end
        pset(I.leaf, x, y, col)
      end
    end
  end
  local k = rng(sd, 5)
  for i = 0, 7 do
    local ang = i * 0.9 + k * 3
    local x = cx + math.floor(math.cos(ang) * rx * 0.6)
    local y = ccy + math.floor(math.sin(ang) * ry * 0.6)
    blk(I.bloom, x, y, (i % 3 == 0) and P.accent or P.main, ST)
  end
  blk(I.core, cx, ccy, P.dot, ST)
  blk(I.glint, cx - math.floor(rx * 0.45), ccy - math.floor(ry * 0.5), P.glint, ST)
end

-- conical conifer
function A.tree_conifer(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2
  local trunkTop = gy - math.floor(h * 0.12)
  local tw = 3 * ST
  for y = trunkTop, gy do
    for i = 0, tw - 1 do
      pset(I.stem, cx - math.floor(tw / 2) + i, y,
           (i >= tw - ST) and P.trunkDark or P.trunk)
    end
  end
  local tiers = 4
  local top = math.floor(h * 0.12)
  local bot = trunkTop
  for t = 0, tiers - 1 do
    local y0 = top + math.floor((bot - top) * t / tiers)
    local y1 = top + math.floor((bot - top) * (t + 1) / tiers)
    local half = math.floor((t + 1) * (w * 0.16))
    for y = y0, y1 do
      local prog = (y - y0) / math.max(1, (y1 - y0))
      local hh = math.floor(half * (0.35 + 0.65 * prog))
      for x = cx - hh, cx + hh do
        local col = P.leafLight
        if (x - cx) > hh * 0.35 or y > y1 - 2 * ST then col = P.leafDark end
        pset(I.leaf, x, y, col)
      end
    end
  end
  blk(I.core, cx, top + ST, P.dot, ST)
  blk(I.glint, cx - 2 * ST, top + math.floor((bot - top) * 0.4), P.glint, ST)
end

-- rosette succulent: filled body, accent rim, radial leaf separation
function A.succ_rosette(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local cy = h - math.floor(h * 0.38)
  local R = math.max(3, math.floor(w * 0.42))
  disc(I.bloom, cx, cy, R, P.main)
  for y = cy - R, cy + R do
    for x = cx - R, cx + R do
      local dx, dy = x - cx, y - cy
      local d2 = dx * dx + dy * dy
      local outer = R * R + R * 0.4
      local inner = (R - 1) * (R - 1) + (R - 1) * 0.4
      if d2 <= outer and d2 > inner then pset(I.bloomShade, x, y, P.accent) end
    end
  end
  for i = 1, 8 do
    local d = DIR8[i]
    for k = 2, R - 1 do
      pset(I.bloomShade, cx + d[1] * k, cy + offy(k, d[2]), P.accent)
    end
  end
  disc(I.core, cx, cy, math.max(1, math.floor(R * 0.3)), P.dot)
  blk(I.glint, cx - g, cy - g, P.glint, g)
  blk(I.glint, cx - math.floor(R * 0.6), cy - math.floor(R * 0.4), P.glint, g)
end

-- trailing bead chain succulent
function A.succ_beads(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.2)
  local pts = {}
  local steps = 9
  for i = 0, steps do
    local t = i / steps
    local x = cx + math.floor(math.sin(t * 3.2 + rng(sd, 2) * 2) * (w * 0.2))
    local y = top + math.floor(t * (gy - top))
    pts[#pts + 1] = { x, y }
  end
  for i = 2, #pts do
    stem_to(I, pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2], P.leafDark, S)
  end
  for i, p in ipairs(pts) do
    bead(I, p[1], p[2], (i % 2 == 0) and math.max(1, math.floor(S / 2))
                        or math.max(2, math.floor(S * 0.75)), P, g)
  end
  blk(I.core, pts[1][1], pts[1][2], P.dot, g)
end

-- bear-paw style stacked pad pairs
function A.succ_paw(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local top = math.floor(h * 0.28)
  stem_to(I, cx, gy, cx, top, P.leafDark, S)
  local n = (w >= 48) and 4 or 3
  local gap = math.max(3 * S, math.floor((gy - top) / (n + 1)))
  local r = math.max(2, math.floor(S * 0.75))
  for i = 0, n - 1 do
    local y = top + S + i * gap
    disc(I.bloom, cx - 2 * S, y, r, P.main)
    disc(I.bloom, cx + 2 * S, y, r, P.main)
    blk(I.core, cx - 3 * S, y - S, P.dot, g)
    blk(I.core, cx + 3 * S, y - S, P.dot, g)
    blk(I.bloomShade, cx - S, y + S, P.accent, g)
    blk(I.bloomShade, cx + S, y + S, P.accent, g)
  end
  blk(I.glint, cx - 3 * S, top, P.glint, g)
end

-- lithops: two split lobes with a mottled top window
function A.succ_lithops(I, P, w, h, sd, S, ST, g)
  local cx = math.floor(w / 2)
  local gy = h - 2 - S
  local cy = gy - math.floor(h * 0.24)
  local r = math.max(3, math.floor(w * 0.22))
  lobe(I.bloom, cx - r, cy, r, P.main, P.accent, cy)
  lobe(I.bloom, cx + r, cy, r, P.main, P.accent, cy)
  tline(I.bloomShade, cx, cy - r, cx, cy + r, P.accent, g)
  blk(I.core, cx - r, cy - g, P.dot, g)
  blk(I.core, cx + r, cy - g, P.dot, g)
  blk(I.core, cx - g, cy - r + g, P.dot, g)
  blk(I.core, cx + g, cy - r + g, P.dot, g)
  blk(I.glint, cx - r + g, cy - r + S, P.glint, g)
  blk(I.glint, cx + r - 2 * g, cy - r + S, P.glint, g)
end

-- ---------------------------------------------------------------- assembly
local LAYER_NAMES = { "shadow", "stem", "leaf", "bloom", "bloom-shade", "core", "glint" }

local function build_tile(item, outDir)
  local w, h = item.w, item.h
  local S = math.max(1, math.floor(w / 16 + 0.5))
  local ST = math.max(1, math.floor(w / 32 + 0.5))
  local g = math.max(1, math.floor(S / 2 + 0.5))
  local spr = Sprite(w, h)
  spr.layers[1].name = LAYER_NAMES[1]
  local L = { shadow = spr.layers[1] }
  for i = 2, #LAYER_NAMES do
    local l = spr:newLayer()
    l.name = LAYER_NAMES[i]
    L[LAYER_NAMES[i]] = l
  end
  L.shadow.opacity = 76 -- 30% ground shadow per spec

  local I = {
    shadow = Image(w, h, spr.colorMode), stem = Image(w, h, spr.colorMode),
    leaf = Image(w, h, spr.colorMode), bloomShade = Image(w, h, spr.colorMode),
    bloom = Image(w, h, spr.colorMode), core = Image(w, h, spr.colorMode),
    glint = Image(w, h, spr.colorMode),
  }
  local P = {
    main = C(item.main), accent = C(item.accent), dot = C(item.dot),
    leafLight = C("#6FA34A"), leafDark = C("#3F6B3A"),
    trunk = C("#7A5A38"), trunkDark = C("#4A3528"),
    water = C("#2E6F96"), waterHi = C("#6FB6D1"),
    glint = C("#FFF3B0"), shadow = C("#1A1A20"),
  }
  ground_shadow(I, w, h, math.floor(w / 2), P.shadow, S)
  local fn = A[item.archetype]
  if not fn then error("unknown archetype: " .. tostring(item.archetype)) end
  fn(I, P, w, h, item.seed or item.index, S, ST, g)

  for _, n in ipairs(LAYER_NAMES) do
    local key = ({ shadow = "shadow", stem = "stem", leaf = "leaf",
                   bloom = "bloom", ["bloom-shade"] = "bloomShade",
                   core = "core", glint = "glint" })[n]
    spr:newCel(L[n], spr.frames[1], I[key], Point(0, 0))
  end

  local ap = outDir .. item.slug .. ".aseprite"
  local pp = outDir .. item.slug .. ".png"
  spr:saveAs(ap)
  spr:saveCopyAs(pp)
  print("OK " .. item.index .. " " .. item.slug .. " " .. w .. "x" .. h .. " " .. item.archetype)
end

local ITEMS = {
{index=11,slug="yue-jian-cao",w=64,h=64,main="#FFD84D",accent="#F2A900",dot="#FF8A00",archetype="floret",seed=80},
{index=17,slug="yue-jian-cao-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#FF8A00",archetype="floret",seed=1110},
{index=12,slug="wu-wang-cao",w=64,h=64,main="#5B8DEF",accent="#3A5FCD",dot="#FFD84D",archetype="cluster",seed=87},
{index=19,slug="wu-wang-cao-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#FFD84D",archetype="cluster",seed=1120},
{index=20,slug="wu-wang-cao-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#FFD84D",archetype="cluster",seed=1121},
{index=13,slug="wu-wang-wo",w=64,h=64,main="#8E7CC3",accent="#F08BB4",dot="#F2C14E",archetype="cluster",seed=94},
{index=22,slug="wu-wang-wo-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F2C14E",archetype="cluster",seed=1130},
{index=23,slug="wu-wang-wo-huang",w=64,h=64,main="#F2C14E",accent="#967830",dot="#F2C14E",archetype="cluster",seed=1131},
{index=14,slug="man-zhu-sha-hua",w=64,h=64,main="#D7263D",accent="#8C1C2A",dot="#F2C14E",archetype="spider",seed=101},
{index=25,slug="man-zhu-sha-hua-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F2C14E",archetype="spider",seed=1140},
{index=15,slug="yu-mei-ren",w=64,h=64,main="#E63946",accent="#A4161A",dot="#1A1A20",archetype="floret",seed=108},
{index=27,slug="yu-mei-ren-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#1A1A20",archetype="floret",seed=1150},
{index=28,slug="yu-mei-ren-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#1A1A20",archetype="floret",seed=1151},
{index=29,slug="yu-mei-ren-huang",w=64,h=64,main="#F2C14E",accent="#967830",dot="#1A1A20",archetype="floret",seed=1152},
{index=16,slug="yuan-wei",w=64,h=64,main="#6A5ACD",accent="#3F3F8C",dot="#F2C14E",archetype="orchid",seed=115},
{index=31,slug="yuan-wei-huang",w=64,h=64,main="#F2C14E",accent="#967830",dot="#F2C14E",archetype="orchid",seed=1160},
{index=32,slug="yuan-wei-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F2C14E",archetype="orchid",seed=1161},
{index=17,slug="xi-yan",w=64,h=64,main="#F6F2E6",accent="#D9D2C0",dot="#F2C14E",archetype="bell",seed=122},
{index=34,slug="xi-yan-huang",w=64,h=64,main="#FFF3B0",accent="#9E976D",dot="#F2C14E",archetype="bell",seed=1170},
{index=18,slug="zhou-yan",w=64,h=64,main="#F6F2E6",accent="#F08BB4",dot="#F2C14E",archetype="bell",seed=129},
{index=19,slug="xue-jian",w=64,h=64,main="#F6F2E6",accent="#A8CF6A",dot="#B8D97A",archetype="floret",seed=136},
{index=20,slug="ling-lan",w=64,h=64,main="#F6F2E6",accent="#D9D2C0",dot="#A8CF6A",archetype="bell",seed=143},
{index=21,slug="xue-di-hua",w=64,h=64,main="#F6F2E6",accent="#A8CF6A",dot="#F2C14E",archetype="bell",seed=150},
{index=22,slug="xue-rong-hua",w=64,h=64,main="#F6F2E6",accent="#E8D9B8",dot="#F2C14E",archetype="floret",seed=157},
{index=23,slug="liu-li-ju",w=64,h=64,main="#4A90E2",accent="#2E5FA3",dot="#F2C14E",archetype="daisy",seed=164},
{index=41,slug="liu-li-ju-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#F2C14E",archetype="daisy",seed=1230},
{index=24,slug="mi-die-xiang",w=64,h=64,main="#6A5ACD",accent="#3F3F8C",dot="#A8CF6A",archetype="herb",seed=171},
{index=25,slug="xun-yi-cao",w=64,h=64,main="#9B7EDE",accent="#6A5ACD",dot="#A8CF6A",archetype="spike",seed=178},
{index=26,slug="yang-gan-ju",w=64,h=64,main="#F6F2E6",accent="#F2C14E",dot="#FFD84D",archetype="daisy",seed=185},
{index=27,slug="pu-gong-ying",w=64,h=64,main="#FFD84D",accent="#F2A900",dot="#F6F2E6",archetype="daisy",seed=192},
{index=28,slug="san-se-jin",w=64,h=64,main="#6A5ACD",accent="#FFD84D",dot="#F6F2E6",archetype="floret",seed=199},
{index=47,slug="san-se-jin-hong",w=64,h=64,main="#E63946",accent="#8F232B",dot="#F6F2E6",archetype="floret",seed=1280},
{index=29,slug="zi-luo-lan",w=64,h=64,main="#7E5AA8",accent="#5D4E8C",dot="#F2C14E",archetype="floret",seed=206},
{index=49,slug="zi-luo-lan-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F2C14E",archetype="floret",seed=1290},
{index=30,slug="shi-che-ju",w=64,h=64,main="#4A90E2",accent="#2E5FA3",dot="#F6F2E6",archetype="daisy",seed=213},
{index=51,slug="shi-che-ju-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#F6F2E6",archetype="daisy",seed=1300},
{index=52,slug="shi-che-ju-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F6F2E6",archetype="daisy",seed=1301},
{index=31,slug="fei-yan-cao",w=64,h=64,main="#5B8DEF",accent="#3F3F8C",dot="#F6F2E6",archetype="spike",seed=220},
{index=54,slug="fei-yan-cao-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#F6F2E6",archetype="spike",seed=1310},
{index=55,slug="fei-yan-cao-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F6F2E6",archetype="spike",seed=1311},
{index=32,slug="cui-que",w=64,h=64,main="#4A90E2",accent="#2E5FA3",dot="#1A1A20",archetype="spike",seed=227},
{index=33,slug="lu-bing-hua",w=64,h=64,main="#8E7CC3",accent="#F08BB4",dot="#F2C14E",archetype="spike",seed=234},
{index=58,slug="lu-bing-hua-lan",w=64,h=64,main="#4A90E2",accent="#2E598C",dot="#F2C14E",archetype="spike",seed=1330},
{index=59,slug="lu-bing-hua-hong",w=64,h=64,main="#E63946",accent="#8F232B",dot="#F2C14E",archetype="spike",seed=1331},
{index=60,slug="lu-bing-hua-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F2C14E",archetype="spike",seed=1332},
{index=34,slug="man-tian-xing",w=64,h=64,main="#F6F2E6",accent="#F08BB4",dot="#A8CF6A",archetype="umbel",seed=241},
{index=35,slug="qing-ren-cao",w=64,h=64,main="#F08BB4",accent="#9B7EDE",dot="#F6F2E6",archetype="umbel",seed=248},
{index=36,slug="shui-jing-cao",w=64,h=64,main="#F6F2E6",accent="#B8D9E8",dot="#A8CF6A",archetype="umbel",seed=255},
{index=37,slug="mai-gan-ju",w=64,h=64,main="#F2C14E",accent="#C75B1A",dot="#F6F2E6",archetype="daisy",seed=262},
{index=65,slug="mai-gan-ju-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#F6F2E6",archetype="daisy",seed=1370},
{index=38,slug="qian-ri-hong",w=64,h=64,main="#D7263D",accent="#8C1C2A",dot="#F2C14E",archetype="cluster",seed=269},
{index=67,slug="qian-ri-hong-zi",w=64,h=64,main="#8E7CC3",accent="#584D79",dot="#F2C14E",archetype="cluster",seed=1380},
{index=39,slug="tu-mi",w=64,h=64,main="#F6F2E6",accent="#D9D2C0",dot="#F2C14E",archetype="floret",seed=276},
{index=40,slug="he-huan",w=64,h=64,main="#F08BB4",accent="#C75B7A",dot="#F2C14E",archetype="cluster",seed=283},
{index=41,slug="hong-dou",w=64,h=64,main="#D7263D",accent="#1A1A20",dot="#F6F2E6",archetype="berry",seed=290},
{index=42,slug="ding-xiang",w=64,h=64,main="#9B7EDE",accent="#6A5ACD",dot="#F6F2E6",archetype="cluster",seed=297},
{index=72,slug="ding-xiang-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F6F2E6",archetype="cluster",seed=1420},
{index=43,slug="zi-wei",w=64,h=64,main="#F08BB4",accent="#9B7EDE",dot="#F2C14E",archetype="cluster",seed=304},
{index=74,slug="zi-wei-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F2C14E",archetype="cluster",seed=1430},
{index=44,slug="zhi-zi",w=64,h=64,main="#F6F2E6",accent="#E8D9B8",dot="#F2C14E",archetype="floret",seed=311},
{index=45,slug="han-xiao",w=64,h=64,main="#F6F2E6",accent="#F2C14E",dot="#A8CF6A",archetype="floret",seed=318},
{index=46,slug="wan-xiang-yu",w=64,h=64,main="#F6F2E6",accent="#D9D2C0",dot="#F2C14E",archetype="spike",seed=325},
{index=47,slug="ye-lai-xiang",w=64,h=64,main="#F2C14E",accent="#A8CF6A",dot="#F6F2E6",archetype="umbel",seed=332},
{index=48,slug="tan-hua",w=64,h=64,main="#F6F2E6",accent="#D9D2C0",dot="#F2C14E",archetype="orchid",seed=339},
{index=49,slug="you-tan-po-luo",w=64,h=64,main="#F6F2E6",accent="#FFF3B0",dot="#F2C14E",archetype="orchid",seed=346},
{index=50,slug="man-tuo-luo",w=64,h=64,main="#F6F2E6",accent="#9B7EDE",dot="#F2C14E",archetype="bell",seed=353},
{index=82,slug="man-tuo-luo-zi",w=64,h=64,main="#6A5ACD",accent="#42387F",dot="#F2C14E",archetype="bell",seed=1500},
{index=51,slug="he-bao-mu-dan",w=64,h=64,main="#F08BB4",accent="#D7263D",dot="#F6F2E6",archetype="bell",seed=360},
{index=52,slug="jie-geng",w=64,h=64,main="#5B8DEF",accent="#3F3F8C",dot="#F6F2E6",archetype="bell",seed=367},
{index=85,slug="jie-geng-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F6F2E6",archetype="bell",seed=1520},
{index=53,slug="feng-ling-cao",w=64,h=64,main="#6A5ACD",accent="#9B7EDE",dot="#F6F2E6",archetype="bell",seed=374},
{index=87,slug="feng-ling-cao-fen",w=64,h=64,main="#F08BB4",accent="#955670",dot="#F6F2E6",archetype="bell",seed=1530},
{index=88,slug="feng-ling-cao-bai",w=64,h=64,main="#F6F2E6",accent="#99968F",dot="#F6F2E6",archetype="bell",seed=1531},
{index=54,slug="lan-xing-hua",w=64,h=64,main="#4A90E2",accent="#2E5FA3",dot="#F6F2E6",archetype="floret",seed=381},
{index=55,slug="fan-lv",w=64,h=64,main="#F6F2E6",accent="#A8CF6A",dot="#F2C14E",archetype="cluster",seed=388},
{index=56,slug="jian-qiu-luo",w=64,h=64,main="#E63946",accent="#F08BB4",dot="#F6F2E6",archetype="floret",seed=395},
{index=57,slug="jian-chun-luo",w=64,h=64,main="#F08BB4",accent="#D7263D",dot="#F6F2E6",archetype="floret",seed=402},
{index=58,slug="jian-xia-luo",w=64,h=64,main="#D7263D",accent="#8C1C2A",dot="#F2C14E",archetype="floret",seed=409},
}
local OUT_DIR = "C:/Atian/Project/pixel-vault/game/pixel-plants/"


local function run()
  for _, item in ipairs(ITEMS) do
    local ok, err = pcall(build_tile, item, OUT_DIR)
    if not ok then print("ERROR " .. item.slug .. " :: " .. tostring(err)) end
  end
  print("TOTAL " .. #ITEMS)
end

run()
