local M = {}

local TILE_SIZE   = 2048   -- map units per screenshot tile
local RESOLUTION  = 2048   -- pixel resolution of each screenshot
local ZOOM        = 0.5

function M.take(surface, bbox)
  local paths  = {}
  local left   = math.floor(bbox.left_top.x     / TILE_SIZE) * TILE_SIZE
  local top    = math.floor(bbox.left_top.y     / TILE_SIZE) * TILE_SIZE
  local right  = math.ceil(bbox.right_bottom.x  / TILE_SIZE) * TILE_SIZE
  local bottom = math.ceil(bbox.right_bottom.y  / TILE_SIZE) * TILE_SIZE

  local cx = left
  while cx < right do
    local cy = top
    while cy < bottom do
      local path = "ai-export/map_" .. cx .. "_" .. cy .. ".png"

      game.take_screenshot{
        surface          = surface,
        position         = { x = cx + TILE_SIZE / 2, y = cy + TILE_SIZE / 2 },
        resolution       = { x = RESOLUTION, y = RESOLUTION },
        zoom             = ZOOM,
        show_entity_info = true,
        path             = path,
      }

      paths[#paths + 1] = "script-output/" .. path
      cy = cy + TILE_SIZE
    end
    cx = cx + TILE_SIZE
  end

  return paths
end

return M
