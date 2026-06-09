# factorio-ai-exporter

Mod para Factorio 2.x que exporta o estado completo da sua fábrica em um arquivo JSON estruturado + screenshots cobrindo toda a base. O objetivo é gerar contexto rico o suficiente para colar numa conversa com um modelo de IA (ChatGPT, Claude, etc.) e receber análises contextualizadas sobre gargalos, uso de módulos, layout, pesquisa, etc.

---

## Instalação

1. Copie a pasta `factorio-ai-exporter/` (a que contém `info.json`) para o diretório de mods do Factorio:

   | Sistema        | Caminho                                              |
   | -------------- | ---------------------------------------------------- |
   | Windows        | `%APPDATA%\Factorio\mods\`                           |
   | macOS          | `~/Library/Application Support/factorio/mods/`      |
   | Linux          | `~/.factorio/mods/`                                  |

2. Inicie o Factorio, vá em **Mods** e certifique-se de que **AI Exporter** está ativado.

3. Carregue um save existente ou inicie uma nova partida.

---

## Como usar

No console do jogo (tecla **`** ou **~**), execute:

```
/ai-export
```

O mod vai:

1. Iniciar a varredura assíncrona de todos os chunks explorados da superfície atual.
2. Processar 5 chunks por tick para não causar lag.
3. Ao terminar, gerar os arquivos em `script-output/ai-export/`:
   - `context.json` — dados completos da fábrica
   - `map_X_Y.png` — screenshots em grade cobrindo toda a base

4. Exibir uma mensagem no chat quando a exportação concluir:
   ```
   [AI Exporter] Export complete. 847 entities | 12 screenshots → script-output/ai-export/
   ```

> O diretório `script-output/` fica dentro do diretório de dados do Factorio (mesmo lugar que os mods).

---

## Usando o JSON com uma IA

Cole o conteúdo de `context.json` numa conversa e faça perguntas como:

- *"Quais são os principais gargalos de produção que você identifica?"*
- *"Estou produzindo circuitos avançados mas o consumo está maior que a produção — o que pode estar causando isso?"*
- *"Com base nas tecnologias pesquisadas, o que eu deveria priorizar agora?"*
- *"Quais montadoras estão com configuração de módulos abaixo do ideal?"*

Para arquivos grandes (bases maiores), você pode extrair só uma seção do JSON:

```bash
# Apenas as estatísticas de produção
cat context.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['production_stats'], indent=2))"
```

---

## Estrutura do JSON de saída

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
    },
    {
      "type": "mining-drill",
      "name": "electric-mining-drill",
      "position": { "x": -300, "y": 120 },
      "resource": "iron-ore",
      "modules": ["efficiency-module"]
    }
  ],
  "screenshots": [
    "script-output/ai-export/map_0_0.png",
    "script-output/ai-export/map_2048_0.png"
  ]
}
```

---

## Guia para desenvolvedores

### Mapa de arquivos

```
factorio-ai-exporter/
├── info.json             # Metadados do mod (nome, versão, dependências)
├── control.lua           # Entry point: comandos, eventos, orquestração
├── export/
│   ├── entities.lua      # Coleta e serializa entidades do surface
│   ├── stats.lua         # Lê LuaFlowStatistics (produção/consumo)
│   ├── research.lua      # Lista tecnologias pesquisadas e em andamento
│   └── screenshot.lua    # Dispara take_screenshot em grade
└── util/
    ├── json.lua          # Serialização Lua → JSON (sem dependências)
    └── chunks.lua        # Fila assíncrona de chunks com storage
```

---

### `control.lua` — orquestrador central

É o único arquivo carregado diretamente pelo Factorio (declarado implicitamente por ser o entry point padrão do runtime). Ele:

- Registra o comando `/ai-export` via `commands.add_command`.
- Quando o comando é executado, chama `chunks.start_export(surface)` para inicializar a fila.
- Registra um handler `on_tick` que chama `chunks.process_tick()` a cada tick enquanto a exportação estiver ativa.
- Quando `process_tick` retorna `true` (fila vazia), chama `finish_export()` que agrega todos os dados, serializa em JSON, escreve em disco, dispara os screenshots e notifica o jogador.

O estado de progresso fica em `storage.ai_export` (tabela global persistente), então o export sobrevive a save/load sem recomeçar do zero.

---

### `util/chunks.lua` — processamento assíncrono

O problema: `surface.find_entities_filtered` numa área enorme em um único tick causa um lag spike perceptível. A solução é dividir o surface em chunks de 32×32 tiles e processar `CHUNKS_PER_TICK = 5` por tick.

**Fluxo:**

```
start_export(surface)
  └─ itera surface.get_chunks() → monta queue = [{x,y}, ...]
  └─ salva queue + index = 1 em storage.ai_export

on_tick → process_tick(surface)
  └─ processa chunks[index .. index+4]
  └─ para cada chunk: find_entities_filtered na área do chunk
  └─ acumula entidades válidas em storage.ai_export.entities
  └─ avança index; retorna true quando index > #queue
```

As entidades são acumuladas como referências `LuaEntity` vivas. Antes de usar cada uma em `finish_export`, o código verifica `entity.valid` para descartar entidades destruídas entre ticks.

---

### `export/entities.lua` — coleta de entidades

Recebe a lista de `LuaEntity` acumulada pelo chunks e filtra pelos tipos relevantes (assembladoras, fornalhas, mineradoras, beacons, labs, silos, train-stops, roboports). Para cada entidade coletada, extrai:

| Campo              | Como é obtido                              |
| ------------------ | ------------------------------------------ |
| `type`, `name`     | `entity.type`, `entity.name`               |
| `position`         | `entity.position.{x,y}`                   |
| `recipe`           | `entity.get_recipe().name` (com pcall)     |
| `modules`          | `entity.get_module_inventory()` → nomes    |
| `crafting_speed`   | `entity.crafting_speed`                    |
| `productivity_bonus` | `entity.productivity_bonus`              |
| `resource`         | `entity.mining_target.name` (drills)       |

Também expõe `bounding_box(entity_list)` que calcula o menor retângulo que contém todas as entidades — usado pelo `screenshot.lua` para saber quantos tiles tirar.

---

### `export/stats.lua` — estatísticas de produção

Lê `LuaFlowStatistics` da força "player" para o surface exportado. Para cada item que aparece em `input_counts` ou `output_counts`, coleta:

- `produced_total` / `consumed_total` — contadores históricos acumulados
- `rate_1min_produced` / `rate_1min_consumed` — média do último minuto
- `rate_1h_produced` / `rate_1h_consumed` — média da última hora

As janelas são definidas via `defines.flow_precision_index` (enum interno do Factorio).

---

### `export/research.lua` — tecnologias

Itera `game.forces.player.technologies` e separa em dois grupos:

- `completed`: todas com `tech.researched == true`, ordenadas alfabeticamente.
- `in_progress`: nome da tecnologia sendo pesquisada no momento (via `force.current_research`).

---

### `export/screenshot.lua` — cobertura visual da base

Não existe `take_map_screenshot` na API do Factorio. O workaround é uma grade de chamadas `game.take_screenshot`:

1. Recebe o `bounding_box` das entidades.
2. Divide em tiles de `2048 × 2048` unidades do mapa.
3. Para cada tile, dispara um screenshot com `zoom = 0.5` e resolução `2048×2048 px`, centrado no meio do tile.
4. Retorna a lista de paths gerados (com prefixo `script-output/`).

Com `zoom = 0.5`, cada pixel cobre 2 unidades de mapa, então cada screenshot cobre uma área de `4096 × 4096` unidades — suficiente para ver detalhes de máquinas individuais sem ser tão próximo que gere dezenas de tiles.

> Screenshots são ignoradas silenciosamente em modo headless (servidor dedicado sem display). O JSON ainda é gerado normalmente.

---

### `util/json.lua` — serialização

Implementação própria sem dependências externas. Suporta:

- `string` → com escape de `"`, `\`, `\n`, `\r`, `\t`, e caracteres de controle (`\uXXXX`)
- `number` → inteiros sem casa decimal; floats com `%.10g`; NaN e Infinity viram `null`
- `boolean` → `true` / `false`
- `nil` → `null`
- `table` densa (array) → `[...]`
- `table` esparsa (objeto) → `{...}`

A distinção array/objeto usa `is_array`: verifica se todas as chaves são inteiros consecutivos começando em 1, sem buracos.

---

### Adicionando novos campos ao export

**Novo tipo de entidade:** em `export/entities.lua`, adicione a chave em `COLLECTED_TYPES` e trate os campos dentro do bloco `if entity.valid and COLLECTED_TYPES[entity.type]`.

**Nova janela de tempo nas stats:** em `export/stats.lua`, adicione uma entrada em `WINDOWS`:
```lua
{ key = "rate_10min", index = defines.flow_precision_index.ten_minutes },
```

**Campo novo no meta:** em `control.lua`, dentro de `finish_export`, adicione ao bloco `meta = { ... }`.

---

## Limitações conhecidas

- **Screenshots em headless:** `game.take_screenshot` é ignorado em servidores dedicados. O JSON é gerado normalmente.
- **Mods de terceiros:** entidades de mods não-vanilla são coletadas normalmente se o tipo coincidir com um dos 8 tipos suportados. Tipos desconhecidos são ignorados silenciosamente.
- **Entidades ghost:** não coletadas por padrão (blueprints não colocados ainda). Para incluí-las, adicione `"entity-ghost"` em `COLLECTED_TYPES` e trate o campo `ghost_name`.
- **Superfícies múltiplas (Space Age):** o export roda na superfície onde o jogador está. Para exportar Vulcanus, Fulgora etc., fique na superfície desejada antes de executar `/ai-export`.
- **Tamanho do JSON:** bases grandes (~2000+ entidades) podem gerar arquivos de 1–2 MB. Modelos com janela de contexto pequena podem precisar de um subconjunto do JSON.
