local chunks   = require("util.chunks")
local entities = require("export.entities")
local stats    = require("export.stats")
local research = require("export.research")
local screenshot = require("export.screenshot")
local json     = require("util.json")

local function finish_export(surface)
  local entity_list = chunks.get_entities()
  local surface_name = chunks.get_surface_name()

  local entity_data = entities.collect(entity_list)
  local bbox        = entities.bounding_box(entity_list)
  local stat_data   = stats.collect(surface_name)
  local research_data = research.collect()
  local screenshot_paths = screenshot.take(surface, bbox)

  local tick = game.tick
  local output = {
    meta = {
      ticks_played     = tick,
      hours_played     = math.floor((tick / 216000) * 10) / 10,
      surface          = surface_name,
      exported_at_tick = tick,
    },
    research         = research_data,
    production_stats = stat_data,
    entities         = entity_data,
    screenshots      = screenshot_paths,
  }

  local json_string = json.encode(output)
  helpers.write_file("ai-export/context.json", json_string, false)

  chunks.reset()

  -- Notify the player who triggered the export.
  local player = game.get_player(1)
  if player and player.valid then
    player.print("[AI Exporter] Export complete. " ..
      #entity_data .. " entities | " ..
      #screenshot_paths .. " screenshots → script-output/ai-export/")
  end
end

-- Command handler: /ai-export
commands.add_command(
  "ai-export",
  "Export factory state to JSON for AI analysis.",
  function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    if storage.ai_export and not storage.ai_export.done then
      player.print("[AI Exporter] Export already in progress, please wait.")
      return
    end

    local surface = player.surface
    player.print("[AI Exporter] Starting export on surface '" .. surface.name .. "'…")
    chunks.start_export(surface)
  end
)

-- Tick handler: drives the asynchronous chunk processing.
script.on_event(defines.events.on_tick, function(event)
  if not storage.ai_export or storage.ai_export.done then return end

  local surface = game.surfaces[storage.ai_export.surface_name]
  if not surface or not surface.valid then
    chunks.reset()
    return
  end

  local done = chunks.process_tick(surface)
  if done then
    finish_export(surface)
  end
end)
