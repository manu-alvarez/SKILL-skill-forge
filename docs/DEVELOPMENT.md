# DEVELOPMENT — proceso de desarrollo de skill-forge

Registro del desarrollo real (2026-09-07): investigación previa, diseño,
incidentes cazados por la propia suite adversarial y resultados de verificación.

## 1. Investigación previa

Antes de construir nada se investigó el sistema en busca de tooling existente.
Hallazgos relevantes:

- **`skills-ref`** (biblioteca de referencia del estándar abierto
  [Agent Skills / agentskills.io](https://agentskills.io)) disponible vía
  `npx -y skills-ref` con comandos `validate`, `read-properties`, `to-prompt`.
  Es el validador canónico contra el que se comprueba el cumplimiento.
- Documentación propia previa del autor:
  - `jart-lacp-sota-research/01-e1-skill-factory.md` — informe SOTA 2025–2026:
    lanzamiento de Agent Skills (Anthropic, oct-2025), estándar abierto
    (dic-2025), skill-creator v2 (evals con assertions + A/B ciego + held-out),
    registros (skills.sh, ClawHub, Tessl) y la evidencia clave de ETH Zurich
    (arXiv 2602.11988): contexto generado por LLM **sin validar** empeora el
    rendimiento (−3%).
  - `PI-MULTI-LLM-ROUTER/INVESTIGACION_SKILLS.md` — panorama de skills de
    equipos dev y harnesses.
- No existía ningún creador de skills/MCPs instalado ni cumpliendo el estándar:
  se decidió construir `skill-forge` como skill que se forja y valida a sí misma
  (dogfooding).

## 2. Reglas del estándar: verificadas con probes, no de memoria

Se sondeó el validador oficial con casos malformados para extraer las reglas
exactas que luego implementa el forge:

| Probe | Resultado del validador |
|---|---|
| `name` con mayúsculas (`Bad_Name`) | rechazado: must be lowercase + invalid characters |
| `name` de 65 chars | rechazado: exceeds 64 character limit |
| `description` de 1025 chars | rechazado: exceeds 1024 character limit |
| sin `description` | rechazado: missing required field |
| directorio ≠ `name` | rechazado: Directory name must match skill name |
| campos opcionales (`license`, `metadata.version`) | aceptados |

Estas reglas están plasmadas en `forge-skill.sh` (validación previa) y en
`references/standard.md`.

## 3. Diseño

- **Dos modos**: skill (estándar Agent Skills) y MCP (SDK oficial
  `@modelcontextprotocol`, transporte stdio, JSON-RPC por newlines).
- **Registro de MCPs** en `~/.pi/agent/mcp.json` siguiendo las convenciones
  existentes del usuario (`command`/`args`/`lifecycle: "lazy"`/`directTools:
  false`), siempre con backup timestamped y escritura atómica (`os.replace`),
  y modo `--no-register` para pruebas.
- **La validación adversarial es parte del flujo, no un extra**: nada se
  considera terminado sin exit 0 de `adversarial.sh`.
- **Suite skill (12 checks)**: A1–A4 son sondas adversariales *contra el
  validador oficial* (crean skills malformadas y exigen que las rechace —
  demuestran que el estándar se aplica); A5–A12 examinan la skill real
  (validación oficial, YAML parseable, inyección de prompts, secretos vía
  gitleaks con fallback a patrones, patrones destructivos, sintaxis/permisos,
  tamaño ≤50KB por progressive disclosure, operaciones de sistema no justificadas).
- **Suite MCP (8 checks)**: manifiesto, SDK, smoke test JSON-RPC real
  (spawn → `initialize` → `notifications/initialized` → `tools/list` →
  `tools/call echo` roundtrip → herramienta desconocida con error controlado),
  patrones peligrosos (`eval`, `execSync`, secretos hardcodeados) y validez del
  registro.

## 4. Incidentes cazados por la propia suite (y sus fixes)

El dogfooding funcionó: la suite detectó 3 defectos reales durante el
desarrollo, que es exactamente su función.

### Incidente 1 — Falso FAIL por SIGPIPE (no determinista)

- **Síntoma**: A1–A4 fallaban de forma intermitente ("estándar acepta name
  inválido") aunque el validador sí rechazaba los probes.
- **Causa**: `set -o pipefail` + `cmd | grep -q` — `grep -q` cierra el pipe al
  encontrar coincidencia y el proceso upstream puede morir por SIGPIPE
  (exit 141), making la pipeline fallar a pesar del match.
- **Fix**: capturar la salida en una variable y evaluar después
  (`OUT=$(SREF ...); echo "$OUT" | grep -q ...`). Determinista.

### Incidente 2 — Auto-detección de patrones por el propio validador

- **Síntoma**: A9 reportaba "patrón peligroso" en el propio `adversarial.sh`.
- **Causa**: el grep de patrones destructivos encontraba sus propias expresiones
  escritas en los comentarios del script (`rm -rf /`, `curl|bash`, `/dev/tcp`).
- **Fix**: excluir comentarios (`grep -vE ":\s*#"`) y el fichero del validador
  de la búsqueda.

### Incidente 3 — Extractor de `description` con awk

- **Síntoma**: `validate.sh` reportaba "description sin disparadores" siendo que
  la description los contenía.
- **Causa**: el patrón awk `/^description:/{f=1; next}` descartaba la propia
  línea de la description (fallaba con descriptions de una sola línea, el caso
  más común).
- **Fix**: imprimir el resto de la línea tras `sub()` y soportar descripciones
  folded multi-línea.

## 5. Verificación final (evidencia)

| Prueba | Resultado |
|---|---|
| `npx -y skills-ref validate skills/skill-forge` | ✅ `Valid skill` |
| `validate.sh` sobre skill-forge | ✅ 0 fallos |
| `adversarial.sh` sobre skill-forge | ✅ 12/12 PASS |
| Demo end-to-end skill (`forge-skill.sh` → validate → adversarial) | ✅ 0 fallos en ambas |
| Demo end-to-end MCP (`forge-mcp.sh --no-register` → validate-mcp → adversarial) | ✅ 8/8 PASS |
| Portabilidad: suite completa contra la copia de este repo | ✅ 12/12 PASS |

Las demos se ejecutaron en directorios temporales y se eliminaron tras verificar;
el `mcp.json` real nunca se modificó durante las pruebas (`--no-register`).

## 6. Referencias

- Estándar abierto Agent Skills — https://agentskills.io
- Validador de referencia — https://github.com/agentskills/agentskills
- ETH Zurich (arXiv 2602.11988) — contexto LLM sin validar: −3% rendimiento
- ASI (arXiv 2504.06821) — skills verificadas por ejecución antes de promover (+23.5% WebArena)
- skill-creator v2 — evals con assertions, A/B ciego y split 60/40 held-out
