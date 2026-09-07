---
name: skill-forge
description: Forge de skills y MCP servers para Pi. Usar SIEMPRE que se pida crear, andamiar (scaffold), validar o auditar una skill nueva o un MCP server nuevo, o antes de dar por buena una skill o MCP creado a mano. Dos modos - (1) create skill - genera estructura estandar agentskills.io (SKILL.md con frontmatter valido, scripts/, references/) y la valida con skills-ref; (2) create mcp - genera un MCP server Node con el SDK oficial, herramientas de ejemplo, lo registra en ~/.pi/agent/mcp.json con backup atomico y le pasa smoke test JSON-RPC. Ambos modos terminan ejecutando la suite adversarial (scripts/adversarial.sh) que debe pasar al 100 por cien antes de dar nada por terminado.
license: MIT
compatibility: bash 3.2+, Node 18+, Python 3, npx (skills-ref); diseñado para Pi (~/.pi/agent/skills) pero portable a cualquier harness Agent Skills
metadata:
  version: 1.0.0
  publisher: manu-alvarez
---

# Skill Forge — skills y MCPs estándar, verificados y validados adversarialmente

Crea skills compatibles 100% con el estándar abierto **Agent Skills** (agentskills.io,
validadas con el validador de referencia `skills-ref`) y **MCP servers** (SDK oficial
de Model Context Protocol), validando todo con una suite adversarial antes de dar
cualquier cosa por terminada.

## Reglas de oro (nunca negociables)

1. **Nada se considera terminado sin validación en verde.** Tras crear, ejecutar
   SIEMPRE `scripts/validate.sh` (skills) o `scripts/validate-mcp.sh` (MCPs) y
   después `scripts/adversarial.sh`. Si algo falla, corregir y repetir.
2. **El nombre manda**: `name` en minúsculas `[a-z0-9-]`, ≤64 chars, y DEBE coincidir
   con el nombre del directorio (el validador oficial lo exige).
3. **description** obligatoria, ≤1024 chars, y debe incluir disparadores de uso
   ("Usar SIEMPRE que...", "Use when...") para que el agente sepa activarla.
4. **Nunca incrustar secretos** en skills/MCPs generados. La suite adversarial los
   escanea; ante cualquier hallazgo, rodar y regenerar.
5. **Registrar un MCP en `mcp.json` requiere backup con timestamp + escritura
   atómica** (el script lo hace; no editar a mano sin backup).

## Crear una skill (modo 1)

```bash
scripts/forge-skill.sh <nombre-skill> "<description con disparadores>" [dir-destino]
# dir-destino por defecto: ~/.pi/agent/skills/<nombre-skill>
```

La estructura generada cumple el estándar:

```
<nombre-skill>/
├── SKILL.md        # frontmatter: name, description, license, metadata.version
├── scripts/        # código ejecutable (preferible a prosa: verificado por ejecución)
└── references/     # documentación adicional cargada bajo demanda
```

## Crear un MCP server (modo 2)

```bash
scripts/forge-mcp.sh <nombre-mcp> [dir-destino] [--no-register]
# genera package.json + index.js (SDK @modelcontextprotocol, stdio, tools echo/health),
# hace npm install, smoke test JSON-RPC (initialize + tools/list + tools/call)
# y registra en ~/.pi/agent/mcp.json con backup (omitir registro: --no-register)
```

## Validación (obligatoria tras crear)

```bash
scripts/validate.sh <dir-skill>       # estándar + pi + secretos + sintaxis scripts
scripts/validate-mcp.sh <dir-mcp>     # build + JSON-RPC initialize/tools-list/call
scripts/adversarial.sh <dir-skill>    # suite adversarial de skills (12 checks)
scripts/adversarial.sh <dir-mcp> --mcp  # suite adversarial de MCPs (8 checks)
```

Exit code 0 = verde. Cualquier FAIL = no terminado.

## Detalle del estándar verificado con probes contra `skills-ref`

Ver `references/standard.md` para las reglas exactas (confirmadas empíricamente,
no de memoria): límites, campos obligatorios/opcionales y comportamiento del
validador de referencia.
