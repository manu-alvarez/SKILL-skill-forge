# SKILL-skill-forge

**Forge de Agent Skills (estándar agentskills.io) y MCP servers — con validación adversarial obligatoria.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Standard: agentskills.io](https://img.shields.io/badge/standard-agentskills.io-blue)](https://agentskills.io)
[![Validated: skills-ref](https://img.shields.io/badge/validated-skills--ref-success)](#validación)

> Skills y MCPs generados por LLM **sin validar** empeoran el rendimiento (ETH Zurich,
> arXiv 2602.11988: −3%). Este forge no considera nada terminado hasta que su suite
> adversarial pasa al 100%.

## Qué hace

| Modo | Comando | Qué genera | Validación |
|---|---|---|---|
| **Skill** | `forge-skill.sh <nombre> "<descripción>"` | Estructura estándar Agent Skills: `SKILL.md` (frontmatter conforme), `scripts/`, `references/` | `skills-ref validate` + suite adversarial (12 checks) |
| **MCP** | `forge-mcp.sh <nombre> [--no-register]` | Server MCP Node con SDK oficial (`@modelcontextprotocol/sdk`), tools de ejemplo (`echo`, `health`), registro en `~/.pi/agent/mcp.json` con backup atómico | Smoke test JSON-RPC real + suite adversarial (8 checks) |

## Requisitos

- bash 3.2+ (macOS nativo), Node 18+, Python 3, `npx` (ejecuta el validador
  de referencia [`skills-ref`](https://github.com/agentskills/agentskills))
- Opcional: [gitleaks](https://github.com/gitleaks/gitleaks) o el skill
  `secrets-handling` para escaneo de secretos con motor dedicado
  (si no, se usan patrones de fallback)

## Instalación

### Pi (este skill está hecho para [Pi](https://github.com/badlogic/pi-mono))

```bash
git clone https://github.com/manu-alvarez/SKILL-skill-forge.git
cp -r SKILL-skill-forge/skills/skill-forge ~/.pi/agent/skills/
```

El agente lo activará automáticamente ante peticiones de crear/validar skills o MCPs.

### Cualquier otro harness compatible con Agent Skills

La carpeta `skills/skill-forge/` es un paquete estándar: cópiala donde tu harness
espere las skills. Verifica con el validador de referencia:

```bash
npx -y skills-ref validate skills/skill-forge   # → Valid skill
```

## Uso

```bash
# 1) Crear una skill (validación incluida como paso obligatorio)
scripts/forge-skill.sh auditoria-vps \
  "Usar SIEMPRE que se pida auditar un servidor. Ejecuta checks de sistema, seguridad y recursos."

scripts/validate.sh   ~/.pi/agent/skills/auditoria-vps
scripts/adversarial.sh ~/.pi/agent/skills/auditoria-vps   # exit 0 o no está terminado

# 2) Crear un MCP server (sin registrar: --no-register)
scripts/forge-mcp.sh mi-server ~/Code/mi-server --no-register
scripts/validate-mcp.sh ~/Code/mi-server
scripts/adversarial.sh  ~/Code/mi-server --mcp
```

## La suite adversarial

**Modo skill (12 checks):** A1–A4 ejecutan sondas maliciosas contra el validador
oficial para demostrar que el estándar **se aplica de verdad** (rechaza `name` con
mayúsculas, `name` >64, `description` >1024, directorio ≠ `name`); A5–A12 validan la
skill real: pase de `skills-ref`, frontmatter YAML parseable, patrones de inyección
de prompt, secretos (gitleaks), patrones destructivos (`rm -rf /`, `curl|bash`),
sintaxis y permisos de scripts, tamaño (progressive disclosure ≤50KB) y operaciones
de sistema no justificadas.

**Modo MCP (8 checks):** manifiesto JSON válido, SDK presente, smoke test JSON-RPC
real (spawn del server: `initialize` → `tools/list` → `tools/call` → robustez ante
tool desconocida), sin `eval`/`exec`/secretos embebidos, nombre válido para registro
y registro en `mcp.json` con backups presentes.

Exit code 0 = verde. Cualquier `FAIL` = no terminado.

## Resultados de verificación

| Prueba | Resultado |
|---|---|
| `skills-ref validate skills/skill-forge` | ✅ Valid skill |
| Suite adversarial sobre `skill-forge` (autorreferida) | ✅ 12/12 PASS |
| Demo end-to-end: forge de skill + suite | ✅ 12/12 PASS |
| Demo end-to-end: forge de MCP + suite | ✅ 8/8 PASS (initialize, tools/list, echo roundtrip, robustez) |

Detalle del proceso de desarrollo, incidentes cazados por la suite y decisiones de
diseño: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## Compatibilidad

- Pi (`~/.pi/agent/skills/`) · cualquier harness que implemente Agent Skills
- El registro de MCPs sigue las convenciones de `~/.pi/agent/mcp.json`
  (`command` / `args` / `lifecycle: "lazy"` / `directTools: false`)

## Licencia

[MIT](LICENSE)
