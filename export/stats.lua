local M = {}

local WINDOWS = {
  { key = "rate_1min", index = defines.flow_precision_index.one_minute },
  { key = "rate_1h",   index = defines.flow_precision_index.one_hour   },
}

function M.collect(surface_name)
  local stats = game.forces.player.get_item_production_statistics(surface_name)
  local result = {}

  for item_name in pairs(stats.input_counts) do
    local entry = {
      produced_total = stats.input_counts[item_name]  or 0,
      consumed_total = stats.output_counts[item_name] or 0,
    }

    for _, win in ipairs(WINDOWS) do
      entry[win.key .. "_produced"] = stats.get_flow_count{
        name            = item_name,
        input           = true,
        precision_index = win.index,
        sample_index    = 1,
      }
      entry[win.key .. "_consumed"] = stats.get_flow_count{
        name            = item_name,
        input           = false,
        precision_index = win.index,
        sample_index    = 1,
      }
    end

    result[item_name] = entry
  end

  -- Also pick up items that were only ever consumed (output_counts only).
  for item_name in pairs(stats.output_counts) do
    if not result[item_name] then
      local entry = {
        produced_total = 0,
        consumed_total = stats.output_counts[item_name] or 0,
      }
      for _, win in ipairs(WINDOWS) do
        entry[win.key .. "_produced"] = 0
        entry[win.key .. "_consumed"] = stats.get_flow_count{
          name            = item_name,
          input           = false,
          precision_index = win.index,
          sample_index    = 1,
        }
      end
      result[item_name] = entry
    end
  end

  return result
end

return M
