# factorio-ai-exporter — CLAUDE.md

## Visão geral

Mod para Factorio (Lua) que exporta o estado completo da fábrica em JSON
estruturado + screenshots cobrindo toda a base, com o objetivo de gerar
contexto rico o suficiente para análise por modelos de IA (ex: colar o JSON
numa conversa e receber dicas contextualizadas sobre gargalos, módulos,
layout etc).

Não existe nada com esse propósito específico no mod portal — é um projeto
original.

## Stack e ambiente

- Linguagem: Lua 5.2 modificado (runtime do Factorio)
- API: Factorio Runtime API (lua-api.factorio.com/latest)
- Output: arquivos escritos em `script-output/` via `helpers.write_file()`
- Ativação: comando de console `/ai-export`
- Compatibilidade alvo: Factorio 2.x base game (sem Space Age obrigatório)

## Estrutura de arquivos do mod

factorio-ai-exporter/
├── info.json -- metadados do mod (name, version, dependencies)
├── control.lua -- entry point runtime: registra comandos e eventos
├── export/
│ ├── entities.lua -- coleta assembladoras, fornalhas, mineradoras etc
│ ├── stats.lua -- coleta LuaFlowStatistics (produção/consumo)
│ ├── research.lua -- coleta tecnologias pesquisadas
│ └── screenshot.lua -- dispara take_screenshot em grid cobrindo a base
└── util/
├── json.lua -- serialização Lua -> JSON (serpent ou impl própria)
└── chunks.lua -- processamento assíncrono por tick para evitar lag

## APIs utilizadas

### Iteração de entidades

```lua
local surface = game.surfaces[1]
local entities = surface.find_entities_filtered{
  force = "player",
  area = bounding_box
}
```

Cada `LuaEntity` expõe:

- `entity.name` -- ex: "assembling-machine-3", "electric-furnace"
- `entity.type` -- ex: "assembling-machine", "mining-drill"
- `entity.position` -- { x, y }
- `entity.get_recipe()` -- LuaRecipe ou nil
- `entity.get_module_inventory()` -- LuaInventory com os módulos instalados
- `entity.crafting_speed` -- velocidade atual considerando módulos
- `entity.productivity_bonus` -- bônus de produtividade acumulado

### Estatísticas de produção

```lua
local stats = game.forces.player.get_item_production_statistics("nauvis")
-- input_counts: itens produzidos; output_counts: itens consumidos
for item_name, _ in pairs(stats.input_counts) do
  local rate_1min = stats.get_flow_count{
    name = item_name,
    input = true,
    precision_index = defines.flow_precision_index.one_minute,
    sample_index = 1
  }
end
```

Janelas disponíveis via `defines.flow_precision_index`:
`five_seconds`, `one_minute`, `ten_minutes`, `one_hour`, `ten_hours`,
`fifty_hours`, `two_hundred_fifty_hours`, `one_thousand_hours`

### Tecnologias pesquisadas

```lua
local techs = game.forces.player.technologies
for name, tech in pairs(techs) do
  if tech.researched then
    -- incluir no contexto
  end
end
```

### Escrita em disco

```lua
helpers.write_file("ai-export/context.json", json_string, false)
-- false = sobrescreve; true = append
```

### Screenshots

```lua
game.take_screenshot{
  surface = game.surfaces[1],
  position = { x = cx, y = cy },
  resolution = { x = 2048, y = 2048 },
  zoom = 0.5,
  show_entity_info = true,
  path = "ai-export/map_" .. cx .. "_" .. cy .. ".png"
}
```

Não existe `take_map_screenshot` na API — o workaround é uma grade de
screenshots em zoom baixo cobrindo o bounding box de todas as entidades.
Resolução máxima suportada: 16384x16384 (recomendado: 4096x4096 por tile).

## Schema do JSON de saída

```json
{
  "meta": {
    "ticks_played": 2184000,
    "hours_played": 10.1,
    "surface": "nauvis",
    "exported_at_tick": 2184000
  },
  "research": {
    "completed": ["mining-productivity-1", "productivity-module-2"],
    "in_progress": "mining-productivity-5"
  },
  "production_stats": {
    "iron-plate": {
      "produced_total": 480000,
      "consumed_total": 471000,
      "rate_1min": 320,
      "rate_1h": 18400
    }
  },
  "entities": [
    {
      "type": "assembling-machine-3",
      "name": "assembling-machine-3",
      "position": { "x": 142, "y": -88 },
      "recipe": "advanced-circuit",
      "modules": ["productivity-module", "productivity-module", "speed-module", "speed-module"],
      "crafting_speed": 1.25,
      "productivity_bonus": 0.2
    },
    {
      "type": "electric-furnace",
      "name": "electric-furnace",
      "position": { "x": 80, "y": -40 },
      "recipe": "iron-plate",
      "modules": ["speed-module", "speed-module"]
    },
    {
      "type": "mining-drill",
      "name": "electric-mining-drill",
      "position": { "x": -300, "y": 120 },
      "resource": "iron-ore",
      "modules": ["efficiency-module", "efficiency-module", "speed-module"]
    }
  ],
  "screenshots": ["ai-export/map_0_0.png", "ai-export/map_2048_0.png"]
}
```

## Considerações de performance

O maior risco é lag spike ao iterar milhares de entidades de uma vez.
Solução: processamento assíncrono via `on_tick`.

Padrão recomendado:

1. `/ai-export` envia o comando
2. `control.lua` cria uma fila de chunks do surface a processar
3. A cada tick, processa N chunks e acumula resultados em `storage` (tabela
   global persistente do mod)
4. Quando todos os chunks forem processados, serializa e escreve o JSON
5. Dispara os `take_screenshot` em sequência
6. Notifica o jogador via `game.player.print()`

Tamanho estimado do JSON para uma base de mid game (~500 entidades): < 500KB.

## Tipos de entidade a coletar (prioridade)

| type (API)           | O que coletar                          |
| -------------------- | -------------------------------------- |
| assembling-machine   | recipe, modules, crafting_speed        |
| furnace              | recipe, modules, crafting_speed        |
| mining-drill         | resource alvo, modules                 |
| beacon (transmissor) | modules instalados, área de influência |
| lab                  | modules                                |
| rocket-silo          | recipe, progress                       |
| train-stop           | nome da estação, posição               |
| roboport             | posição (delimita áreas logísticas)    |

Entidades a ignorar: tiles, decorações, recursos (ore patches), biters,
árvores, wires, ghosts (a menos que flag `include_ghosts` ativa).

## Limitações conhecidas

- `take_map_screenshot` não existe na API — workaround com grade de
  `take_screenshot` em zoom baixo
- Factorio rodando headless ignora `take_screenshot` (não afeta uso normal)
- Mods de terceiros podem adicionar entidades com nomes não-vanilla: o
  exporter deve lidar com isso graciosamente (incluir mesmo sem reconhecer)
- `helpers.write_file` só escreve em `script-output/` — sem acesso ao
  filesystem arbitrário

## Referências

- API Runtime: https://lua-api.factorio.com/latest/
- LuaSurface: https://lua-api.factorio.com/latest/classes/LuaSurface.html
- LuaEntity: https://lua-api.factorio.com/latest/classes/LuaEntity.html
- LuaFlowStatistics: https://lua-api.factorio.com/latest/classes/LuaFlowStatistics.html
- LuaHelpers (write_file): https://lua-api.factorio.com/latest/classes/LuaHelpers.html
- LuaGameScript (take_screenshot): https://lua-api.factorio.com/latest/classes/LuaGameScript.html
- Tutorial de modding: https://wiki.factorio.com/Tutorial:Modding_tutorial/Gangsir
- Mod de referência (stats): https://mods.factorio.com/mod/factorioStatExportMod
- Mod de referência (mapshot): https://mods.factorio.com/mod/mapshot
