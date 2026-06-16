# factorio-ai-exporter

Factorio 2.x mod that exports your factory state as a structured JSON file plus map screenshots covering the entire base. Designed to generate rich context for AI analysis — paste the output into a conversation and ask about bottlenecks, module efficiency, research priorities, layout, and so on.

## Installation

Copy the `factorio-ai-exporter/` folder (the one containing `info.json`) to Factorio's mods directory:

| OS      | Path |
|---------|------|
| Windows | `%APPDATA%\Factorio\mods\` |
| macOS   | `~/Library/Application Support/factorio/mods/` |
| Linux   | `~/.factorio/mods/` |

Enable **AI Exporter** from the in-game Mods screen.

## Usage

Open the in-game console (`` ` `` or `~`) and run:

```
/ai-export
```

The mod scans all explored chunks asynchronously (5 chunks per tick to avoid lag spikes) and writes to `script-output/ai-export/`:

- `context.json` — full factory state
- `map_X_Y.png` — screenshots covering the entire base (typically 1–4 images)

A chat message confirms when the export is complete:

```
[AI Exporter] Export complete. 458 entities | 1 screenshots → script-output/ai-export/
```

> `script-output/` lives inside the Factorio data directory, alongside the mods folder.

## JSON structure

```json
{
  "meta": {
    "ticks_played": 2184000,
    "hours_played": 10.1,
    "surface": "nauvis",
    "exported_at_tick": 2184000
  },
  "research": {
    "completed": ["automation", "logistics", "steel-processing"],
    "in_progress": "mining-productivity-3"
  },
  "production_stats": {
    "iron-plate": {
      "produced_total": 480000,
      "consumed_total": 471000,
      "rate_1min_produced": 320,
      "rate_1min_consumed": 318,
      "rate_1h_produced": 18400,
      "rate_1h_consumed": 18100
    }
  },
  "entities": [
    {
      "type": "assembling-machine",
      "name": "assembling-machine-3",
      "position": { "x": 142, "y": -88 },
      "recipe": "advanced-circuit",
      "modules": ["productivity-module", "productivity-module", "speed-module", "speed-module"],
      "crafting_speed": 1.25,
      "productivity_bonus": 0.2
    }
  ],
  "screenshots": ["script-output/ai-export/map_-40_299.png"]
}
```

For large bases, you can extract a single section before pasting into an AI:

```bash
cat context.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['production_stats'], indent=2))"
```

## Architecture

```
factorio-ai-exporter/
  info.json         # Mod metadata
  control.lua       # Entry point: command registration, orchestration, finish_export
  export/
    entities.lua    # Entity collection and serialization
    stats.lua       # LuaFlowStatistics (production/consumption rates)
    research.lua    # Completed and in-progress technologies
    screenshot.lua  # Tiled map screenshots
  util/
    json.lua        # Lua-to-JSON serialization (no dependencies)
    chunks.lua      # Async chunk queue with storage persistence
```

### Key implementation notes

**Async chunk processing (`util/chunks.lua`):** scanning a large surface in a single tick causes a noticeable lag spike. The export divides the surface into 32×32 tile chunks and processes `CHUNKS_PER_TICK = 5` per tick. Progress is stored in `storage.ai_export`, so an export survives save/load without restarting.

**Entity collection (`export/entities.lua`):** collects assemblers, furnaces, mining drills, beacons, labs, rocket silos, train stops, and roboports. Each `LuaEntity` reference is validated before use (`entity.valid`) to discard anything destroyed between ticks.

**Production stats (`export/stats.lua`):** reads `LuaFlowStatistics` from the player force. Exposes total counts plus per-item rates at 1-minute and 1-hour windows via `defines.flow_precision_index`.

**Screenshots (`export/screenshot.lua`):** uses tiled `game.take_screenshot` calls since no single map screenshot API exists. Zoom is derived from the entity bounding box to fit the whole base, clamped between `MIN_ZOOM = 0.1` and `MAX_ZOOM = 1.0`. Silently skipped in headless/dedicated server mode — JSON is still generated normally.

**JSON serialization (`util/json.lua`):** custom implementation with no external dependencies. Handles string escaping, floats (`%.10g`), NaN/Infinity as `null`, and array vs. object distinction via consecutive integer key check.

## Known limitations

- Screenshots are skipped on dedicated servers (headless mode).
- Only the 8 built-in entity types are collected; unknown types are silently ignored.
- Ghost entities (unplaced blueprints) are excluded by default.
- Multi-surface (Space Age): export runs on the surface the player is currently on.
- Large bases (2000+ entities) may produce 1–2 MB JSON files, which can exceed the context window of smaller models.

## License

MIT
