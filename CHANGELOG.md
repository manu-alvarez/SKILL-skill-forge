# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y [SemVer](https://semver.org/lang/es/).

## [1.0.0] - 2026-09-07

### Added

- `forge-skill.sh`: scaffolding de skills conforme al estándar abierto
  Agent Skills (agentskills.io) con validación integrada.
- `forge-mcp.sh`: scaffolding de MCP servers Node (SDK oficial, stdio) con
  registro en `~/.pi/agent/mcp.json` (backup timestamped + escritura atómica)
  y modo `--no-register`.
- `validate.sh`: validación de skills (validador oficial `skills-ref`,
  integración Pi, escaneo de secretos, sintaxis y permisos de scripts).
- `validate-mcp.sh`: smoke test JSON-RPC real (spawn: `initialize`,
  `tools/list`, `tools/call`, robustez ante herramienta desconocida).
- `adversarial.sh`: suite adversarial — 12 checks para skills y 8 para MCPs,
  incluidas sondas que verifican que el validador oficial aplica el estándar.
- `references/standard.md`: reglas del estándar verificadas empíricamente
  con probes contra `skills-ref`.
- `docs/DEVELOPMENT.md`: diseño, metodología de validación, casos de borde
  detectados y resultados de verificación.
