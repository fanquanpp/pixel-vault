--[[ pixel-plants :: shared drawing library (Aseprite Lua, batch mode)
     Deterministic pixel-art plant tiles. No randomness: a per-item seed
     drives all variation so every rerun reproduces byte-identical output.

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

-- elliptical shadow blob, 1-2 px tall
local function ground_shadow(I, w, h, cx, col)
  local rx = math.max(3, math.floor(w * 0.26))
  local cy = h - 2
  local rx1 = rx + 1
  for x = cx - rx1, cx + rx1 do
    local t = (x - cx) / (rx1 + 0.5)
    if t * t <= 1 then
      pset(I.shadow, x, cy, col)
      if t * t <= 0.45 then pset(I.shadow, x, cy - 1, col) end
    end
  end
end

-- ---------------------------------------------------------------- seed
local function rng(seed, i)
  local x = (seed * 1103515245 + i * 12345 + 1013904223) % 2147483648
  return x / 2147483648.0
end

-- ---------------------------------------------------------------- plant parts
local function stem_to(I, x0, y0, x1, y1, col)
  line(I.stem, x0, y0, x1, y1, col)
end

-- small side leaf; dir = -1 left, +1 right
local function side_leaf(I, x, y, dir, colD, colL)
  pset(I.leaf, x, y, colD)
  pset(I.leaf, x + dir, y - 1, colL)
  pset(I.leaf, x + dir, y, colL)
  pset(I.leaf, x + 2 * dir, y, colL)
  pset(I.leaf, x + dir, y + 1, colD)
  pset(I.leaf, x + 2 * dir, y + 1, colD)
end

local function blade(I, x, yTop, yBase, lean, colL, colD)
  local steps = yBase - yTop
  for i = 0, steps do
    local t = i / math.max(1, steps)
    local x0 = x + math.floor(lean * t + 0.5)
    pset(I.leaf, x0, yTop + i, (i > steps * 0.6) and colD or colL)
  end
end

-- round bloom head with a shaded lower-right rim, core dot, single glint
local function bloom_round(I, cx, cy, r, P)
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
    pset(I.core, cx, cy, P.dot)
  end
  pset(I.glint, cx - 1, cy - 1, P.glint)
  if r >= 3 then pset(I.glint, cx - r + 1, cy - 1, P.glint) end
end

-- star bloom: n thin petals radiating from a small core
local function bloom_star(I, cx, cy, n, rin, rout, P)
  for i = 0, n - 1 do
    local ang = (i / n) * 2 * math.pi + 0.35
    for t = rin, rout do
      local x = cx + math.floor(math.cos(ang) * t + 0.5)
      local y = cy + math.floor(math.sin(ang) * t + 0.5)
      pset((i % 2 == 0) and I.bloom or I.bloomShade, x, y,
           (i % 2 == 0) and P.main or P.accent)
    end
  end
  disc(I.core, cx, cy, 1, P.dot)
  pset(I.glint, cx, cy - 1, P.glint)
end

-- one bell / trumpet hanging downward
local function bloom_bell(I, cx, cy, P, wide)
  local wdt = wide or 3
  for i = 0, 3 do
    local half = math.floor(i / 2)
    for x = cx - half, cx + half do pset(I.bloom, x, cy + i, P.main) end
  end
  pset(I.bloom, cx, cy + 4, P.dot)
  pset(I.bloomShade, cx + 1, cy + 3, P.accent)
  pset(I.bloomShade, cx, cy, P.accent)
  pset(I.glint, cx - 1, cy + 1, P.glint)
end

local function bead(I, cx, cy, r, P)
  disc(I.bloom, cx, cy, r, P.main)
  pset(I.bloomShade, cx + r, cy + r, P.accent)
  if r >= 1 then pset(I.core, cx, cy, P.dot) end
  pset(I.glint, cx - 1, cy - 1, P.glint)
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
local function bell_at(I, bx, by, P)
  pset(I.bloom, bx, by, P.main)
  for x = bx - 1, bx + 1 do pset(I.bloom, x, by + 1, P.main) end
  for x = bx - 1, bx + 1 do pset(I.bloom, x, by + 2, P.main) end
  pset(I.bloomShade, bx + 1, by + 1, P.accent)
  pset(I.bloomShade, bx + 1, by + 2, P.accent)
  pset(I.core, bx, by + 2, P.dot)
  pset(I.glint, bx - 1, by + 1, P.glint)
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
-- Every archetype receives: I (layer images), P (palette), w, h, and seed.
local A = {}

-- single blossom on a stem with two side leaves
function A.floret(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local by = math.floor(h * 0.38)
  stem_to(I, cx, by + 2, cx, gy, P.leafDark)
  stem_to(I, cx, by + 2, cx + 1, gy - 1, P.leafDark)
  side_leaf(I, cx - 1, gy - 3, -1, P.leafDark, P.leafLight)
  side_leaf(I, cx + 1, gy - 5, 1, P.leafDark, P.leafLight)
  bloom_round(I, cx, by, math.max(2, math.floor(w * 0.22)), P)
end

-- many thin petals, flat head
function A.daisy(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local by = math.floor(h * 0.34)
  stem_to(I, cx, by + 3, cx, gy, P.leafDark)
  side_leaf(I, cx - 1, gy - 4, -1, P.leafDark, P.leafLight)
  side_leaf(I, cx + 1, gy - 6, 1, P.leafDark, P.leafLight)
  local rout = math.max(3, math.floor(w * 0.24))
  for i = 1, 8 do
    local d = DIR8[i]
    for k = 2, rout do
      local x = cx + d[1] * k
      local y = by + offy(k, d[2])
      if k == rout then
        pset(I.bloomShade, x, y, P.accent)
      else
        pset(I.bloom, x, y, P.main)
      end
    end
  end
  disc(I.core, cx, by, 1, P.dot)
  pset(I.glint, cx - 1, by - 1, P.glint)
end

-- long thin radiating petals, bare stem (spider lily)
function A.spider(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local by = math.floor(h * 0.36)
  stem_to(I, cx, gy, cx, by + 2, P.leafDark)
  local rout = math.max(4, math.floor(w * 0.34))
  for i = 1, 6 do
    local d = DIR6[i]
    for k = 2, rout do
      pset(I.bloom, cx + d[1] * k, by + offy(k, d[2]), P.main)
    end
    pset(I.bloomShade, cx + d[1] * (rout + 1), by + offy(rout, d[2]) + 1, P.accent)
  end
  disc(I.core, cx, by, 1, P.dot)
  pset(I.glint, cx - 1, by - 1, P.glint)
  pset(I.core, cx - 2, by - 3, P.dot)
  pset(I.core, cx + 2, by - 3, P.dot)
end

-- bells hanging from an arched stem
function A.bell(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.24)
  stem_to(I, cx, gy, cx, top, P.leafDark)
  side_leaf(I, cx - 1, gy - 4, -1, P.leafDark, P.leafLight)
  side_leaf(I, cx + 1, gy - 6, 1, P.leafDark, P.leafLight)
  local n = (w >= 32) and 4 or 3
  local gap = (w >= 32) and 6 or 4
  for i = 1, n do
    local off = (i - (n + 1) / 2)
    local bx = cx + math.floor(off * gap + (off > 0 and 0.5 or -0.5))
    local by = top + 2 + math.floor(math.abs(off) + 0.5)
    stem_to(I, cx, top + 2, bx, by, P.leafDark)
    bell_at(I, bx, by, P)
  end
end

-- vertical spike of florets (lavender / lupin / larkspur)
function A.spike(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.22)
  stem_to(I, cx, gy, cx, top, P.leafDark)
  blade(I, cx - 2, gy - 6, gy, -1, P.leafLight, P.leafDark)
  blade(I, cx + 2, gy - 6, gy, 1, P.leafLight, P.leafDark)
  blade(I, cx - 4, gy - 3, gy, -1, P.leafDark, P.leafDark)
  local rows = math.max(5, math.floor(h * 0.4))
  for i = 0, rows do
    local y = top + i
    local t = 1 - i / rows
    local half = (t > 0.75) and 0 or (t > 0.35 and 1 or 2)
    for x = cx - half, cx + half do
      local col = ((x + y) % 3 == 0) and P.accent or P.main
      pset(I.bloom, x, y, col)
    end
  end
  pset(I.core, cx, top, P.dot)
  pset(I.glint, cx - 1, top + 1, P.glint)
end

-- 3 small round blooms on branching stems
function A.cluster(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local by = math.floor(h * 0.42)
  stem_to(I, cx, by + 3, cx, gy, P.leafDark)
  side_leaf(I, cx - 1, gy - 4, -1, P.leafDark, P.leafLight)
  side_leaf(I, cx + 1, gy - 5, 1, P.leafDark, P.leafLight)
  local spots = { { -math.floor(w * 0.18), -1 }, { 0, -3 }, { math.floor(w * 0.18), 0 } }
  for i, s in ipairs(spots) do
    local bx, byy = cx + s[1], by + s[2]
    stem_to(I, cx, by + 2, bx, byy + 2, P.leafDark)
    bloom_round(I, bx, byy, math.max(1, math.floor(w * 0.11)), P)
  end
end

-- flat-topped umbel: many tiny heads fanning from one point
function A.umbel(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.36)
  stem_to(I, cx, gy, cx, top, P.leafDark)
  side_leaf(I, cx - 1, gy - 4, -1, P.leafDark, P.leafLight)
  side_leaf(I, cx + 1, gy - 6, 1, P.leafDark, P.leafLight)
  local n = (w >= 32) and 7 or 5
  for i = 1, n do
    local t = (i - (n + 1) / 2) / ((n + 1) / 2)
    local bx = cx + math.floor(t * w * 0.28)
    local by = top - math.floor((1 - math.abs(t)) * h * 0.08)
    stem_to(I, cx, top + 1, bx, by, P.leafDark)
    bloom_round(I, bx, by - 1, 1, P)
  end
  pset(I.core, cx, top, P.dot)
end

-- leafy herbal clump, tiny dots as flowers
function A.herb(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local n = (w >= 32) and 6 or 5
  for i = 1, n do
    local t = (i - (n + 1) / 2) / ((n + 1) / 2)
    local lean = t * w * 0.34
    local tall = h * (0.34 + 0.14 * math.abs(t))
    blade(I, cx, math.floor(gy - tall), gy, lean, P.leafLight, P.leafDark)
  end
  local k = rng(sd, 7)
  pset(I.bloom, cx - 1 + math.floor(k * 2), gy - math.floor(h * 0.5), P.main)
  pset(I.bloom, cx + 2, gy - math.floor(h * 0.44), P.accent)
  pset(I.core, cx + 1, gy - math.floor(h * 0.56), P.dot)
end

-- pure grass / reed clump
function A.grass(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local n = (w >= 32) and 7 or 6
  for i = 1, n do
    local t = (i - (n + 1) / 2) / ((n + 1) / 2)
    local lean = t * w * 0.3
    local tall = h * (0.42 + 0.2 * (1 - math.abs(t)))
    blade(I, cx, math.floor(gy - tall), gy, lean, P.leafLight, P.leafDark)
  end
  blade(I, cx, math.floor(gy - h * 0.68), gy, 0, P.leafDark, P.leafDark)
  pset(I.bloom, cx, math.floor(gy - h * 0.62), P.main)
  pset(I.core, cx, math.floor(gy - h * 0.66), P.dot)
end

-- climbing / twining stems with leaves and blooms near the top
function A.vine(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.18)
  local amp = w * 0.16
  local steps = math.max(8, math.floor(h * 0.7))
  local prev = nil
  local at = {}
  for i = 0, steps do
    local t = i / steps
    local x = cx + math.floor(math.sin(t * 5.0) * amp + 0.5)
    local y = gy - math.floor(t * (gy - top))
    at[i] = { x, y }
    if prev then stem_to(I, prev[1], prev[2], x, y, P.leafDark) end
    prev = { x, y }
  end
  for i = 2, steps - 4, 3 do
    local p = at[i]
    side_leaf(I, p[1], p[2], (i % 2 == 0) and 1 or -1, P.leafDark, P.leafLight)
  end
  for i = 0, 2 do
    local p = at[math.floor(steps * (0.74 + i * 0.11))]
    if i == 1 then
      bloom_round(I, p[1], p[2] - 1, math.max(1, math.floor(w * 0.12)), P)
    else
      bell_at(I, p[1], p[2], P)
    end
  end
end

-- slender orchid-like bloom on a tall stem
function A.orchid(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local by = math.floor(h * 0.3)
  stem_to(I, cx, gy, cx, by + 2, P.leafDark)
  blade(I, cx - 2, gy - 6, gy, -2, P.leafLight, P.leafDark)
  blade(I, cx + 2, gy - 6, gy, 2, P.leafLight, P.leafDark)
  -- two side petals, one top petal, one lip
  pset(I.bloom, cx - 3, by, P.main); pset(I.bloom, cx - 2, by, P.main)
  pset(I.bloom, cx + 3, by, P.main); pset(I.bloom, cx + 2, by, P.main)
  pset(I.bloom, cx - 1, by - 1, P.main); pset(I.bloom, cx + 1, by - 1, P.main)
  pset(I.bloom, cx, by - 2, P.main); pset(I.bloom, cx - 1, by - 2, P.accent)
  pset(I.bloom, cx + 1, by - 2, P.accent)
  pset(I.bloom, cx, by + 1, P.main); pset(I.bloom, cx, by + 2, P.dot)
  pset(I.bloomShade, cx - 2, by + 1, P.accent); pset(I.bloomShade, cx + 2, by + 1, P.accent)
  disc(I.core, cx, by, 0, P.dot)
  pset(I.glint, cx - 1, by - 1, P.glint)
end

-- berry / fruit cluster
function A.berry(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.4)
  stem_to(I, cx, gy, cx, top, P.leafDark)
  side_leaf(I, cx - 1, gy - 4, -1, P.leafDark, P.leafLight)
  side_leaf(I, cx + 1, gy - 6, 1, P.leafDark, P.leafLight)
  local pts = { { 0, 0 }, { -1, 1 }, { 1, 1 }, { 0, 2 }, { -1, 3 }, { 1, 3 } }
  local k = (w >= 32) and 6 or 4
  for i = 1, k do
    local p = pts[i]
    bead(I, cx + p[1] * 2, top + p[2] * 2 + 1, (w >= 32) and 2 or 1, P)
  end
end

-- floating aquatic: pads on water + one bloom
function A.aquatic(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local wy = h - 4
  local pad = P.leafLight
  for x = 2, w - 3 do pset(I.stem, x, wy + 2, P.water) end
  pset(I.stem, 2, wy + 1, P.waterHi)
  pset(I.stem, w - 3, wy + 1, P.waterHi)
  disc(I.leaf, cx - math.floor(w * 0.2), wy + 2, math.max(2, math.floor(w * 0.16)), pad)
  pset(I.leaf, cx - math.floor(w * 0.2), wy + 2, P.leafDark)
  disc(I.bloom, cx + math.floor(w * 0.14), wy, 2, P.main)
  pset(I.bloomShade, cx + math.floor(w * 0.14) + 1, wy + 1, P.accent)
  pset(I.core, cx + math.floor(w * 0.14), wy, P.dot)
  pset(I.glint, cx + math.floor(w * 0.14) - 1, wy - 1, P.glint)
end

-- fungus: cap + stalk, or kidney-shaped bracket with rings
function A.fungus(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local capy = math.floor(h * 0.42)
  for y = capy + 1, gy do
    pset(I.stem, cx - 1, y, P.leafLight)
    pset(I.stem, cx, y, P.leafLight)
    pset(I.stem, cx + 1, y, P.leafDark)
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
  pset(I.core, cx - 1, capy - 1, P.dot)
  pset(I.core, cx + 1, capy - 1, P.dot)
  pset(I.glint, cx, capy - 1, P.glint)
end

-- round-canopy tree
function A.tree_round(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 2
  local trunkTop = gy - math.floor(h * 0.3)
  for y = trunkTop, gy do
    pset(I.stem, cx - 1, y, P.trunk)
    pset(I.stem, cx, y, P.trunk)
    pset(I.stem, cx + 1, y, P.trunkDark)
  end
  pset(I.stem, cx - 2, gy, P.trunkDark)
  pset(I.stem, cx + 2, gy, P.trunkDark)
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
    pset(I.bloom, x, y, (i % 2 == 0) and P.main or P.dot)
  end
  pset(I.glint, cx - math.floor(r * 0.5), ccy - math.floor(r * 0.5), P.glint)
end

-- broad spreading canopy with visible branches
function A.tree_broad(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 2
  local trunkTop = gy - math.floor(h * 0.24)
  for y = trunkTop, gy do
    pset(I.stem, cx - 1, y, P.trunk)
    pset(I.stem, cx, y, P.trunk)
    pset(I.stem, cx + 1, y, P.trunkDark)
  end
  line(I.stem, cx, trunkTop + 1, cx - math.floor(w * 0.22), trunkTop - math.floor(h * 0.14), P.trunkDark)
  line(I.stem, cx, trunkTop + 2, cx + math.floor(w * 0.22), trunkTop - math.floor(h * 0.12), P.trunkDark)
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
    pset(I.bloom, x, y, (i % 3 == 0) and P.accent or P.main)
  end
  pset(I.core, cx, ccy, P.dot)
  pset(I.glint, cx - math.floor(rx * 0.45), ccy - math.floor(ry * 0.5), P.glint)
end

-- conical conifer
function A.tree_conifer(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 2
  local trunkTop = gy - math.floor(h * 0.12)
  for y = trunkTop, gy do
    pset(I.stem, cx - 1, y, P.trunk); pset(I.stem, cx, y, P.trunk)
    pset(I.stem, cx + 1, y, P.trunkDark)
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
        if (x - cx) > hh * 0.35 or y > y1 - 2 then col = P.leafDark end
        pset(I.leaf, x, y, col)
      end
    end
  end
  pset(I.core, cx, top + 1, P.dot)
  pset(I.glint, cx - 2, top + math.floor((bot - top) * 0.4), P.glint)
end

-- rosette succulent: filled body, accent rim, radial leaf separation
function A.succ_rosette(I, P, w, h, sd)
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
  pset(I.glint, cx - 1, cy - 1, P.glint)
  pset(I.glint, cx - math.floor(R * 0.6), cy - math.floor(R * 0.4), P.glint)
end

-- trailing bead chain succulent
function A.succ_beads(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.2)
  local pts = {}
  local steps = (w >= 32) and 7 or 5
  for i = 0, steps do
    local t = i / steps
    local x = cx + math.floor(math.sin(t * 3.2 + rng(sd, 2) * 2) * (w * 0.2))
    local y = top + math.floor(t * (gy - top))
    pts[#pts + 1] = { x, y }
  end
  for i = 2, #pts do
    stem_to(I, pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2], P.leafDark)
  end
  for i, p in ipairs(pts) do
    bead(I, p[1], p[2], (i % 2 == 0) and 1 or 2, P)
  end
  pset(I.core, pts[1][1], pts[1][2], P.dot)
end

-- bear-paw style stacked pad pairs
function A.succ_paw(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local top = math.floor(h * 0.28)
  stem_to(I, cx, gy, cx, top, P.leafDark)
  local n = (w >= 32) and 4 or 3
  local gap = math.max(3, math.floor((gy - top) / (n + 1)))
  for i = 0, n - 1 do
    local y = top + 1 + i * gap
    disc(I.bloom, cx - 2, y, 1, P.main)
    disc(I.bloom, cx + 2, y, 1, P.main)
    pset(I.core, cx - 3, y - 1, P.dot)
    pset(I.core, cx + 3, y - 1, P.dot)
    pset(I.bloomShade, cx - 1, y + 1, P.accent)
    pset(I.bloomShade, cx + 1, y + 1, P.accent)
  end
  pset(I.glint, cx - 3, top, P.glint)
end

-- lithops: two split lobes with a mottled top window
function A.succ_lithops(I, P, w, h, sd)
  local cx = math.floor(w / 2)
  local gy = h - 3
  local cy = gy - math.floor(h * 0.24)
  local r = math.max(3, math.floor(w * 0.22))
  lobe(I.bloom, cx - r, cy, r, P.main, P.accent, cy)
  lobe(I.bloom, cx + r, cy, r, P.main, P.accent, cy)
  line(I.bloomShade, cx, cy - r, cx, cy + r, P.accent)
  pset(I.core, cx - r, cy - 1, P.dot)
  pset(I.core, cx + r, cy - 1, P.dot)
  pset(I.core, cx - 1, cy - r + 1, P.dot)
  pset(I.core, cx + 1, cy - r + 1, P.dot)
  pset(I.glint, cx - r + 1, cy - r + 2, P.glint)
  pset(I.glint, cx + r - 1, cy - r + 2, P.glint)
end

-- ---------------------------------------------------------------- assembly
local LAYER_NAMES = { "shadow", "stem", "leaf", "bloom", "bloom-shade", "core", "glint" }

local function build_tile(item, outDir)
  local w, h = item.w, item.h
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
  ground_shadow(I, w, h, math.floor(w / 2), P.shadow)
  local fn = A[item.archetype]
  if not fn then error("unknown archetype: " .. tostring(item.archetype)) end
  fn(I, P, w, h, item.seed or item.index)

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
{index=59,slug="qing-dai",w=16,h=16,main="#2E4A8C",accent="#1E2E5C",dot="#6A8FD9",archetype="herb",seed=416},
{index=60,slug="ban-xia",w=16,h=16,main="#A8CF6A",accent="#3F6B3A",dot="#F6F2E6",archetype="herb",seed=423},
{index=61,slug="bai-zhi",w=16,h=16,main="#F6F2E6",accent="#A8CF6A",dot="#F2C14E",archetype="umbel",seed=430},
{index=62,slug="pei-lan",w=16,h=16,main="#9B7EDE",accent="#3F6B3A",dot="#F6F2E6",archetype="spike",seed=437},
{index=63,slug="ze-lan",w=16,h=16,main="#6FA34A",accent="#9B7EDE",dot="#F6F2E6",archetype="spike",seed=444},
{index=64,slug="mu-xiang",w=16,h=16,main="#F2C14E",accent="#F6F2E6",dot="#A8CF6A",archetype="floret",seed=451},
{index=65,slug="chen-xiang",w=16,h=16,main="#5A3F2C",accent="#2E221C",dot="#B88952",archetype="tree_round",seed=458},
{index=66,slug="su-he-xiang",w=16,h=16,main="#8C4A2E",accent="#5A2E1A",dot="#F2C14E",archetype="tree_round",seed=465},
{index=67,slug="an-xi-xiang",w=16,h=16,main="#B88952",accent="#7A5A38",dot="#F2C14E",archetype="tree_round",seed=472},
{index=68,slug="dang-gui",w=16,h=16,main="#C49A5A",accent="#8C6440",dot="#F6F2E6",archetype="umbel",seed=479},
{index=69,slug="du-huo",w=16,h=16,main="#F6F2E6",accent="#A8CF6A",dot="#5A3F2C",archetype="umbel",seed=486},
{index=70,slug="yuan-zhi",w=16,h=16,main="#6A5ACD",accent="#3F3F8C",dot="#F2C14E",archetype="floret",seed=493},
{index=71,slug="shi-jun-zi",w=16,h=16,main="#E63946",accent="#F08BB4",dot="#F2C14E",archetype="cluster",seed=500},
{index=72,slug="nv-zhen-zi",w=16,h=16,main="#2E4A2A",accent="#1A1A20",dot="#A8CF6A",archetype="berry",seed=507},
{index=73,slug="ye-jiao-teng",w=16,h=16,main="#6FA34A",accent="#F6F2E6",dot="#F2C14E",archetype="vine",seed=514},
{index=74,slug="ren-dong",w=16,h=16,main="#F6F2E6",accent="#F2C14E",dot="#A8CF6A",archetype="vine",seed=521},
{index=75,slug="ling-xiao",w=16,h=16,main="#F28C28",accent="#C75B1A",dot="#FFD84D",archetype="vine",seed=528},
{index=76,slug="luo-shi",w=16,h=16,main="#F6F2E6",accent="#A8CF6A",dot="#F2C14E",archetype="vine",seed=535},
{index=77,slug="shi-hu",w=16,h=16,main="#9B7EDE",accent="#F6F2E6",dot="#F2C14E",archetype="orchid",seed=542},
{index=78,slug="yu-zhu",w=16,h=16,main="#F6F2E6",accent="#A8CF6A",dot="#B8D97A",archetype="bell",seed=549},
{index=79,slug="huang-jing",w=16,h=16,main="#F2C14E",accent="#A8CF6A",dot="#F6F2E6",archetype="bell",seed=556},
{index=80,slug="ling-zhi",w=16,h=16,main="#A4161A",accent="#5A2E1A",dot="#F2C14E",archetype="fungus",seed=563},
{index=81,slug="fu-ling",w=16,h=16,main="#F6F2E6",accent="#B88952",dot="#5A3F2C",archetype="fungus",seed=570},
{index=82,slug="xue-lian",w=16,h=16,main="#F6F2E6",accent="#B8D9E8",dot="#A8CF6A",archetype="floret",seed=577},
{index=83,slug="hong-jing-tian",w=16,h=16,main="#D7263D",accent="#3F6B3A",dot="#F2C14E",archetype="succ_rosette",seed=584},
{index=84,slug="chong-lou",w=16,h=16,main="#3F6B3A",accent="#6A5ACD",dot="#F2C14E",archetype="herb",seed=591},
{index=85,slug="bai-wei",w=16,h=16,main="#F6F2E6",accent="#9B7EDE",dot="#F2C14E",archetype="floret",seed=598},
{index=86,slug="zi-wan",w=16,h=16,main="#9B7EDE",accent="#6A5ACD",dot="#F2C14E",archetype="daisy",seed=605},
{index=87,slug="kuan-dong",w=16,h=16,main="#F2C14E",accent="#A8CF6A",dot="#F6F2E6",archetype="daisy",seed=612},
{index=88,slug="xuan-fu",w=16,h=16,main="#FFD84D",accent="#F6F2E6",dot="#A8CF6A",archetype="daisy",seed=619},
{index=89,slug="fei-peng",w=16,h=16,main="#F6F2E6",accent="#A8CF6A",dot="#F2C14E",archetype="daisy",seed=626},
{index=90,slug="chang-pu",w=16,h=16,main="#6FA34A",accent="#F2C14E",dot="#5A3F2C",archetype="grass",seed=633},
{index=91,slug="xiang-pu",w=16,h=16,main="#8C6440",accent="#C49A5A",dot="#A8CF6A",archetype="grass",seed=640},
{index=92,slug="qian-shi",w=16,h=16,main="#9B7EDE",accent="#F6F2E6",dot="#A8CF6A",archetype="aquatic",seed=647},
{index=93,slug="chun-cai",w=16,h=16,main="#3F6B3A",accent="#6A5ACD",dot="#B8D9E8",archetype="aquatic",seed=654},
{index=94,slug="shui-su",w=16,h=16,main="#6FA34A",accent="#F6F2E6",dot="#9B7EDE",archetype="spike",seed=661},
{index=95,slug="liu-lan-xiang",w=16,h=16,main="#A8CF6A",accent="#3F6B3A",dot="#F6F2E6",archetype="herb",seed=668},
{index=96,slug="ma-yu-lan",w=16,h=16,main="#6FA34A",accent="#F2C14E",dot="#F6F2E6",archetype="herb",seed=675},
{index=97,slug="shi-cao",w=16,h=16,main="#F6F2E6",accent="#A8CF6A",dot="#F2C14E",archetype="umbel",seed=682},
{index=98,slug="yin-chen",w=16,h=16,main="#A8CF6A",accent="#F6F2E6",dot="#3F6B3A",archetype="herb",seed=689},
{index=99,slug="qing-hao",w=16,h=16,main="#3F6B3A",accent="#6FA34A",dot="#A8CF6A",archetype="herb",seed=696},
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
