-- Asynchronous chunk-based export queue.
-- State is kept in storage.ai_export so it survives save/load mid-export.

local M = {}

local CHUNKS_PER_TICK = 5

function M.start_export(surface)
  local queue = {}
  for chunk in surface.get_chunks() do
    queue[#queue + 1] = { x = chunk.x, y = chunk.y }
  end

  storage.ai_export = {
    queue       = queue,
    index       = 1,
    surface_name = surface.name,
    entities    = {},
    done        = false,
  }
end

-- Called each tick. Returns true when all chunks have been processed.
function M.process_tick(surface)
  local state = storage.ai_export
  if not state or state.done then return true end

  local queue     = state.queue
  local limit     = math.min(state.index + CHUNKS_PER_TICK - 1, #queue)

  for i = state.index, limit do
    local chunk   = queue[i]
    local area    = {
      left_top     = { x = chunk.x * 32,      y = chunk.y * 32 },
      right_bottom = { x = chunk.x * 32 + 32, y = chunk.y * 32 + 32 },
    }

    local found = surface.find_entities_filtered{
      force = "player",
      area  = area,
    }

    for _, entity in ipairs(found) do
      if entity.valid then
        state.entities[#state.entities + 1] = entity
      end
    end
  end

  state.index = limit + 1

  if state.index > #queue then
    state.done = true
    return true
  end

  return false
end

function M.is_done()
  return storage.ai_export and storage.ai_export.done == true
end

function M.get_entities()
  return storage.ai_export and storage.ai_export.entities or {}
end

function M.get_surface_name()
  return storage.ai_export and storage.ai_export.surface_name or "nauvis"
end

function M.reset()
  storage.ai_export = nil
end

return M
