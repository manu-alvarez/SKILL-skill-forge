# Estándar Agent Skills (agentskills.io) — reglas verificadas empíricamente

Reglas confirmadas con probes contra el validador de referencia `skills-ref`
(no sacadas de memoria; verificadas el 2026-09-07 con la versión disponible vía npx).

## Reglas duras (el validador rechaza si se incumplen)

| Regla | Detalle verificado |
|---|---|
| `SKILL.md` obligatorio | En la raíz del directorio de la skill |
| Frontmatter YAML obligatorio | Delimitado por `---` |
| `name` obligatorio | Solo `[a-z0-9-]` (minúsculas, guiones); máx **64** chars |
| `name` == directorio | El validador compara el nombre del frontmatter con el nombre del directorio y falla si difieren |
| `description` obligatoria | Máx **1024** chars |

## Campos opcionales admitidos

| Campo | Uso |
|---|---|
| `license` | Ej: `MIT`, `Apache-2.0` |
| `metadata` | Mapa libre; convención: `version` (semver) y `publisher` |
| `compatibility` | Plataformas/harness donde funciona |
| `allowed-tools` | Restricción de herramientas (experimental en el estándar) |

## Comandos de `skills-ref`

```bash
npx -y skills-ref validate <dir|SKILL.md>   # validar (exit 0 = válido)
npx -y skills-ref read-properties <dir>     # leer frontmatter
npx -y skills-ref to-prompt <dirs...>       # convertir skills a prompt
```

## Integración con Pi

- Pi carga skills desde `~/.pi/agent/skills/<nombre>/SKILL.md` (user scope).
- La `description` es lo que ve el agente en todo momento (progressive disclosure,
  ~1 línea); el cuerpo se carga al activarse; `scripts/` y `references/` bajo demanda.
- Por eso la description DEBE incluir disparadores claros de uso ("Usar SIEMPRE que...").

## MCP (Model Context Protocol) — convenciones usadas por skill-forge

- Server stdio en Node con `@modelcontextprotocol/sdk` (transporte: JSON-RPC
  delimitado por newlines por stdin/stdout).
- Registro en `~/.pi/agent/mcp.json` bajo `mcpServers` con:
  `command`, `args`, `lifecycle: "lazy"`, `directTools: false`
  (mismas convenciones que las entradas existentes: engram, context7, obsidian).
- Escritura del registro SIEMPRE con backup timestamped + `os.replace` atómico.

## Validación adversarial (SOTA)

- El contexto generado por LLM **sin validar** empeora el rendimiento (estudio ETH
  Zurich, arXiv 2602.11988: −3%). Por eso la suite es obligatoria, no opcional.
- SOTA de validación = ejecución real antes de promover: ASI verifica con tests en
  sandbox; skill-creator v2 ejecuta evals con assertions + A/B ciego + held-out.
- Nuestra suite: sondas adversariales contra el validador oficial (A1–A4) para
  probar que el estándar SE cumple, más escaneo de inyecciones/secretos/patrones
  destructivos (A6–A12) y smoke tests JSON-RPC reales con robustez (M3).
