local M = {}

local RESOLUTION = 4096
local MIN_ZOOM   = 0.1
local MAX_ZOOM   = 1.0
local PAD        = 64  -- game units de margem ao redor da fábrica

-- tile_size (game units) a partir de zoom e resolução:
--   cada pixel = 1/(zoom*32) game units
--   → tile_size = RESOLUTION / (zoom * 32)
function M.take(surface, bbox)
  local x1 = bbox.left_top.x     - PAD
  local y1 = bbox.left_top.y     - PAD
  local x2 = bbox.right_bottom.x + PAD
  local y2 = bbox.right_bottom.y + PAD

  local w = x2 - x1
  local h = y2 - y1

  local ideal_zoom = RESOLUTION / (math.max(w, h) * 32)
  local zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, ideal_zoom))
  zoom = math.floor(zoom * 1000 + 0.5) / 1000

  local tile_size = math.floor(RESOLUTION / (zoom * 32))

  local paths = {}
  local tx = x1
  while tx < x2 do
    local ty = y1
    while ty < y2 do
      local cx = tx + tile_size / 2
      local cy = ty + tile_size / 2
      local path = string.format("ai-export/map_%d_%d.png",
        math.floor(cx), math.floor(cy))

      game.take_screenshot{
        surface          = surface,
        position         = { x = cx, y = cy },
        resolution       = { x = RESOLUTION, y = RESOLUTION },
        zoom             = zoom,
        show_entity_info = true,
        path             = path,
      }

      paths[#paths + 1] = "script-output/" .. path
      ty = ty + tile_size
    end
    tx = tx + tile_size
  end

  return paths
end

return M
