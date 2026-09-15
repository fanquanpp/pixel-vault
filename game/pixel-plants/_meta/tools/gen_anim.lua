--[[ pixel-plants :: build 4-frame sway animations for a representative subset.
     Frame 1 is the still tile; frames 2-4 bake ±1px horizontal offsets into
     the bloom / leaf cels (shadow and stem stay put) so the head sways.
     Duration 150ms per frame, ping-pong loop -> 4 frames / 600ms cycle.
]]
local base = "C:/Atian/Project/pixel-vault/game/pixel-plants/"
local SLUGS = { "ling-lan", "yue-jian-cao", "yang-gan-ju", "man-zhu-sha-hua",
                "xun-yi-cao", "jiang-li", "mi-die-xiang", "ren-dong",
                "pu-ti-shu", "sheng-shi-hua", "fo-zhu", "xuan-cao" }
local TOP = { bloom = true, core = true, glint = true }
local MID = { leaf = true }
local DXS = { 0, 1, 0, -1 }
local DUR = 0.15

local function build(slug)
  local path = base .. slug .. ".aseprite"
  local spr = app.open(path)
  if not spr then return "open-failed" end
  local out = base .. slug .. "-sway.aseprite"

  for i = 1, 3 do spr:newFrame() end
  for _, layer in ipairs(spr.layers) do
    local src = layer:cel(spr.frames[1])
    if src then
      for f = 2, 4 do
        local dx = 0
        if TOP[layer.name] then dx = DXS[f]
        elseif MID[layer.name] then dx = math.floor(DXS[f] / 2) end
        local img = Image(spr.width, spr.height, spr.colorMode)
        img:drawImage(src.image, Point(src.position.x + dx, src.position.y))
        spr:newCel(layer, spr.frames[f], img, Point(0, 0))
      end
    end
  end
  for f = 1, 4 do spr.frames[f].duration = DUR end

  local tag = spr:newTag(1, 4)
  tag.name = "sway"
  tag.aniDir = AniDir.PING_PONG

  spr:saveAs(out)
  print("OK " .. slug .. " frames=" .. #spr.frames)
  return nil
end

local n = 0
for _, slug in ipairs(SLUGS) do
  local ok, err = pcall(build, slug)
  if not ok then print("ERROR " .. slug .. " :: " .. tostring(err))
  else n = n + 1 end
end
print("BUILT " .. n .. "/" .. #SLUGS)
