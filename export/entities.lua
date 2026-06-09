local M = {}

local COLLECTED_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"]            = true,
  ["mining-drill"]       = true,
  ["beacon"]             = true,
  ["lab"]                = true,
  ["rocket-silo"]        = true,
  ["train-stop"]         = true,
  ["roboport"]           = true,
}

local function get_modules(entity)
  local inv = entity.get_module_inventory()
  if not inv then return nil end

  local modules = {}
  for i = 1, #inv do
    local stack = inv[i]
    if stack and stack.valid_for_read then
      modules[#modules + 1] = stack.name
    end
  end

  return #modules > 0 and modules or nil
end

local function get_recipe(entity)
  local ok, recipe = pcall(function() return entity.get_recipe() end)
  if not ok or not recipe then return nil end
  return recipe.name
end

local function get_resource_target(entity)
  -- mining-drill exposes `mining_target` (LuaEntity of the resource being mined)
  if entity.type ~= "mining-drill" then return nil end
  local target = entity.mining_target
  if target and target.valid then
    return target.name
  end
  return nil
end

function M.collect(entity_list)
  local result = {}

  for _, entity in ipairs(entity_list) do
    if entity.valid and COLLECTED_TYPES[entity.type] then
      local record = {
        type     = entity.type,
        name     = entity.name,
        position = { x = entity.position.x, y = entity.position.y },
      }

      local recipe = get_recipe(entity)
      if recipe then record.recipe = recipe end

      local modules = get_modules(entity)
      if modules then record.modules = modules end

      if entity.type == "assembling-machine"
      or entity.type == "furnace"
      or entity.type == "rocket-silo" then
        record.crafting_speed     = entity.crafting_speed
        record.productivity_bonus = entity.productivity_bonus
      end

      if entity.type == "mining-drill" then
        local res = get_resource_target(entity)
        if res then record.resource = res end
      end

      if entity.type == "rocket-silo" then
        record.rocket_parts_progress = entity.rocket_parts
      end

      result[#result + 1] = record
    end
  end

  return result
end

-- Compute the axis-aligned bounding box that covers all collected entities.
function M.bounding_box(entity_list)
  local min_x, min_y =  math.huge,  math.huge
  local max_x, max_y = -math.huge, -math.huge

  for _, entity in ipairs(entity_list) do
    if entity.valid then
      local x, y = entity.position.x, entity.position.y
      if x < min_x then min_x = x end
      if y < min_y then min_y = y end
      if x > max_x then max_x = x end
      if y > max_y then max_y = y end
    end
  end

  if min_x == math.huge then
    return { left_top = { x = -32, y = -32 }, right_bottom = { x = 32, y = 32 } }
  end

  local pad = 32
  return {
    left_top     = { x = min_x - pad, y = min_y - pad },
    right_bottom = { x = max_x + pad, y = max_y + pad },
  }
end

return M
