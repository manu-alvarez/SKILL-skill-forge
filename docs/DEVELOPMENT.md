# DEVELOPMENT — diseño y validación de skill-forge

Documento técnico sobre el diseño, la metodología de validación y los casos de
borde detectados durante el desarrollo de skill-forge (2026-09-07).

## 1. Metodología

Antes de implementar se verificó el tooling disponible y el estado del estándar:

- **`skills-ref`** (biblioteca de referencia del estándar abierto
  [Agent Skills / agentskills.io](https://agentskills.io)), disponible vía
  `npx -y skills-ref` con comandos `validate`, `read-properties` y `to-prompt`.
  Es el validador canónico contra el que se comprueba el cumplimiento.
- Revisión de SOTA 2025–2026 sobre generación y validación de skills
  (skill-creator v2 y su pipeline de evals con assertions + A/B ciego +
  held-out; registros con quality-gates por versión) y de la evidencia
  experimental sobre contexto generado por LLM sin validar (ETH Zurich,
  arXiv 2602.11988: −3% de rendimiento).

Conclusión de diseño: la validación adversarial **no es un extra sino parte del
flujo** — ningún artefacto se considera terminado sin exit 0 de la suite.

## 2. Reglas del estándar: verificadas con probes, no de memoria

Se sondeó el validador oficial con casos malformados para extraer las reglas
exactas que implementa el forge:

| Probe | Resultado del validador |
|---|---|
| `name` con mayúsculas (`Bad_Name`) | rechazado: must be lowercase + invalid characters |
| `name` de 65 chars | rechazado: exceeds 64 character limit |
| `description` de 1025 chars | rechazado: exceeds 1024 character limit |
| sin `description` | rechazado: missing required field |
| directorio ≠ `name` | rechazado: Directory name must match skill name |
| campos opcionales (`license`, `metadata.version`) | aceptados |

Estas reglas están plasmadas en `forge-skill.sh` (validación previa) y en
[`references/standard.md`](../skills/skill-forge/references/standard.md).

## 3. Arquitectura

- **Dos modos**: skill (estándar Agent Skills) y MCP (SDK oficial
  `@modelcontextprotocol`, transporte stdio, JSON-RPC por newlines).
- **Registro de MCPs** en `~/.pi/agent/mcp.json` con backup timestamped y
  escritura atómica (`os.replace`), y modo `--no-register` para pruebas.
- **Suite skill (12 checks)**: A1–A4 son sondas adversariales *contra el
  validador oficial* (crean skills malformadas y exigen que las rechace —
  demuestran que el estándar se aplica); A5–A12 examinan la skill real
  (validación oficial, YAML parseable, inyección de prompts, secretos vía
  gitleaks con fallback a patrones, patrones destructivos, sintaxis/permisos,
  tamaño ≤50KB por progressive disclosure, operaciones de sistema no justificadas).
- **Suite MCP (8 checks)**: manifiesto, SDK, smoke test JSON-RPC real
  (spawn → `initialize` → `tools/list` → `tools/call` roundtrip → herramienta
  desconocida con error controlado), patrones peligrosos y validez del registro.

## 4. Eficacia de la suite: casos de borde detectados

Durante la validación, la suite detectó tres casos de borde que fueron
corregidos antes de la publicación. Se documentan como evidencia de que los
checks aportan señal real (detectar defectos, no ruido):

| # | Check | Caso de borde | Causa raíz | Resolución |
|---|---|---|---|---|
| 1 | A1–A4 | Falsos negativos no deterministas al sondear el validador | `set -o pipefail` + `grep -q`: cierre temprano del pipe provoca SIGPIPE (exit 141) aguas arriba | La salida se captura en variable y se evalúa posteriormente (determinista) |
| 2 | A9 | Detección en falso de patrones destructivos | Las expresiones de detección aparecen textualmente en comentarios del propio script validador | El ámbito del grep excluye comentarios y el fichero validador |
| 3 | validate.sh | Falso negativo en el check de disparadores de la description | `awk` con `next` en la línea `description:` descartaba descripciones de una sola línea | El extractor imprime el resto de la línea y soporta descripciones folded |

## 5. Verificación final

| Prueba | Resultado |
|---|---|
| `npx -y skills-ref validate skills/skill-forge` | ✅ `Valid skill` |
| `validate.sh` sobre skill-forge | ✅ 0 fallos |
| `adversarial.sh` sobre skill-forge | ✅ 12/12 PASS |
| Demo end-to-end skill (`forge-skill.sh` → validate → adversarial) | ✅ 0 fallos en ambas |
| Demo end-to-end MCP (`forge-mcp.sh --no-register` → validate-mcp → adversarial) | ✅ 8/8 PASS |
| Portabilidad: suite completa contra un clon fresco del repo | ✅ Valid skill · 0 fallos · 12/12 |

Las demos se ejecutaron en directorios temporales y se eliminaron tras
verificar; ningún registro real de MCPs se modificó durante las pruebas
(`--no-register`).

## 6. Referencias

- Estándar abierto Agent Skills — https://agentskills.io
- Validador de referencia — https://github.com/agentskills/agentskills
- ETH Zurich (arXiv 2602.11988) — contexto LLM sin validar: −3% rendimiento
- ASI (arXiv 2504.06821) — skills verificadas por ejecución antes de promover (+23.5% WebArena)
- skill-creator v2 — evals con assertions, A/B ciego y split 60/40 held-out
