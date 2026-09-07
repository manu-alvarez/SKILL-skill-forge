# AGENTS.md — reglas para agentes que trabajen en este repo

Proyecto: **skill-forge** — forge de Agent Skills (agentskills.io) y MCP servers
con validación adversarial obligatoria. Fuente canónica de la skill.

## Regla de oro (nunca negociable)

**Nada está terminado sin suite en verde.** Tras cualquier cambio en
`skills/skill-forge/`:

```bash
make validate && make adversarial
```

Exit 0 o no está terminado. Un informe "parece bien" no vale como gate.

## Estructura

```
skills/skill-forge/     ← EL PAQUETE (fuente canónica, estándar agentskills.io)
docs/DEVELOPMENT.md     ← diseño, metodología de validación, casos de borde
README.md / CHANGELOG.md / LICENSE
```

## Convenciones

- **Estándar**: `SKILL.md` conforme a agentskills.io — `name` `[a-z0-9-]` ≤64
  Y == nombre de directorio; `description` ≤1024 con disparadores de uso;
  `license`, `compatibility`, `metadata.version` presentes. Validar con
  `npx -y skills-ref validate skills/skill-forge`.
- **Tres copias desplegadas** que deben mantenerse sincronizadas tras cada
  cambio aprobado: `~/.pi/agent/skills/skill-forge` (Pi),
  `~/.agents/skills/skill-forge` (cross-harness) y este repo (canónica).
  `make sync` hace el despliegue.
- **Versionado**: SemVer. Todo cambio relevante actualiza
  `metadata.version` del frontmatter y `CHANGELOG.md`.
- **Registro de MCPs**: solo con backup timestamped + escritura atómica
  (lo hace `forge-mcp.sh`; nunca a mano sin backup).
- **Secretos**: cero en el repo. La suite los escanea (gitleaks + fallback).
- **Idioma**: skill y scripts en español (es el idioma de uso del autor);
  README en inglés (estándar de GitHub). Commits en español, tono técnico.

## Comandos

```bash
make validate       # skills-ref + validate.sh
make adversarial    # suite adversarial (12 checks)
make test           # validate + adversarial + demo e2e en /tmp (auto-limpieza)
make sync           # despliega skills/skill-forge → Pi + ~/.agents
make check          # validate + adversarial sobre las 3 copias (repo, Pi, ~/.agents)
```

## Definition of done

1. `make check` en verde (las 3 copias).
2. Si se añadió/ cambió comportamiento: demo e2e (`make test`) en verde.
3. `CHANGELOG.md` y `metadata.version` actualizados.
4. Commit + push. Los gates de `/workflow` citan números
   (p. ej. `adversarial: 12/12 PASS`), nunca opiniones.
