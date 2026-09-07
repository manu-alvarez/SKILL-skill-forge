#!/bin/bash
# adversarial.sh — suite adversarial para skills y MCPs creados con skill-forge
# Uso:   adversarial.sh <dir-skill>          (modo skill, 12 checks)
#        adversarial.sh <dir-mcp> --mcp      (modo mcp, 8 checks)
# Exit 0 = todo PASS. Exit N = N fallos. Nada se da por bueno sin exit 0.
set -uo pipefail

DIR="${1:-}"
MODE="${2:-skill}"
[ "$MODE" = "--mcp" ] && MODE="mcp"
[ -z "$DIR" ] && { echo "Uso: adversarial.sh <dir> [--mcp]" >&2; exit 1; }
DIR="${DIR%/}"
FAILS=0
TMPBASE=$(mktemp -d /tmp/forge-adversarial.XXXXXX)
trap 'rm -rf "$TMPBASE"' EXIT

ok()   { echo "  [PASS] $1"; }
bad()  { echo "  [FAIL] $1"; FAILS=$((FAILS+1)); }

SREF() { npx -y skills-ref validate "$1" 2>&1; }

# =============== MODO SKILL ===============
if [ "$MODE" != "mcp" ]; then
  echo "== Suite adversarial (skill): $DIR =="

  # Nota: capturamos la salida en variable antes de evaluar. Con `set -o pipefail`,
  # `npx ... | grep -q` puede morir por SIGPIPE de forma no determinista.

  # A1: el validador debe RECHAZAR name con mayúsculas (el estándar se cumple de verdad)
  mkdir -p "$TMPBASE/bad_case" && printf -- '---\nname: BadName\ndescription: prueba adversarial de nombre con mayusculas para verificar rechazo.\n---\n# x\n' > "$TMPBASE/bad_case/SKILL.md"
  OUT=$(SREF "$TMPBASE/bad_case"); echo "$OUT" | grep -q "Validation failed" && ok "A1 estándar rechaza name con mayúsculas" || bad "A1 estándar acepta name inválido (mayúsculas): $OUT"

  # A2: rechaza name >64
  LONG=$(python3 -c "print('a'*65)")
  mkdir -p "$TMPBASE/bad_long" && printf -- "---\nname: $LONG\ndescription: prueba adversarial de longitud.\n---\n# x\n" > "$TMPBASE/bad_long/SKILL.md"
  OUT=$(SREF "$TMPBASE/bad_long"); echo "$OUT" | grep -q "Validation failed" && ok "A2 estándar rechaza name >64" || bad "A2 estándar acepta name >64"

  # A3: rechaza description >1024
  BIGD=$(python3 -c "print('d'*1025)")
  mkdir -p "$TMPBASE/bad_desc" && printf -- "---\nname: bad-desc\ndescription: $BIGD\n---\n# x\n" > "$TMPBASE/bad_desc/SKILL.md"
  OUT=$(SREF "$TMPBASE/bad_desc"); echo "$OUT" | grep -q "Validation failed" && ok "A3 estándar rechaza description >1024" || bad "A3 estándar acepta description >1024"

  # A4: rechaza directorio != name
  mkdir -p "$TMPBASE/other-dir" && printf -- '---\nname: otro-nombre\ndescription: prueba adversarial de mismatch directorio nombre.\n---\n# x\n' > "$TMPBASE/other-dir/SKILL.md"
  OUT=$(SREF "$TMPBASE/other-dir"); echo "$OUT" | grep -q "Validation failed" && ok "A4 estándar rechaza dir != name" || bad "A4 estándar acepta dir != name"

  # A5: la skill REAL sigue pasando el validador oficial (estado post-creación)
  OUT=$(SREF "$DIR"); echo "$OUT" | grep -q "Valid skill" && ok "A5 skills-ref valida la skill real" || bad "A5 skills-ref NO valida la skill real: $OUT"

  # A6: frontmatter parseable como YAML con campos obligatorios
  python3 - "$DIR/SKILL.md" <<'PYEOF' && ok "A6 frontmatter YAML válido con name+description" || bad "A6 frontmatter YAML inválido"
import sys, re
text = open(sys.argv[1]).read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
assert m, "sin frontmatter"
fm = m.group(1)
assert re.search(r"^name:\s*\S", fm, re.M), "sin name"
assert re.search(r"^description:\s*\S", fm, re.M), "sin description"
PYEOF

  # A7: patrones de inyección de prompts en SKILL.md
  INJ=$(grep -inE "ignore (all )?previous instructions|disregard (all )?(previous|prior)|system prompt|exfiltrat|ignore-above|fin del prompt|ignora las instrucciones anteriores" "$DIR/SKILL.md" | head -3)
  [ -z "$INJ" ] && ok "A7 sin patrones de inyección de prompt" || bad "A7 posible inyección: $INJ"

  # A8: secretos (usa el scanner del skill de secretos si existe)
  if [ -x "$HOME/.pi/agent/skills/secrets-handling/scripts/scan-secrets.sh" ]; then
    "$HOME/.pi/agent/skills/secrets-handling/scripts/scan-secrets.sh" "$DIR" >/dev/null 2>&1 \
      && ok "A8 secretos (gitleaks): limpio" || bad "A8 secretos: hallazgos"
  else
    L=$(grep -rEn "(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{30,}|BEGIN (RSA|OPENSSH) PRIVATE KEY)" "$DIR" 2>/dev/null | head -2)
    [ -z "$L" ] && ok "A8 secretos (patrones): limpio" || bad "A8 secretos: $L"
  fi

  # A9: patrones peligrosos en scripts (excluyendo comentarios y este propio validador)
  DANG=$(grep -rnE "rm -rf /[ *]|curl[^|]*\|\s*(ba)?sh|wget[^|]*\|\s*(ba)?sh|/dev/tcp/" "$DIR/scripts" 2>/dev/null | grep -v "\.bak" | grep -vE ":\s*#|adversarial\.sh" | head -2)
  [ -z "$DANG" ] && ok "A9 sin patrones destructivos en scripts" || bad "A9 patrón peligroso: $DANG"

  # A10: scripts con sintaxis válida y ejecutables
  SYNTAX_OK=1
  for s in "$DIR"/scripts/*.sh; do
    [ -f "$s" ] || continue
    bash -n "$s" 2>/dev/null || SYNTAX_OK=0
    [ -x "$s" ] || chmod +x "$s"
  done
  [ $SYNTAX_OK -eq 1 ] && ok "A10 scripts: sintaxis OK y ejecutables" || bad "A10 script con error de sintaxis"

  # A11: tamaño razonable de SKILL.md (progressive disclosure: la metadata es lo que se carga siempre)
  SIZE=$(stat -f%z "$DIR/SKILL.md" 2>/dev/null || stat -c%s "$DIR/SKILL.md")
  [ "$SIZE" -le 51200 ] && ok "A11 SKILL.md tamaño razonable (${SIZE}B ≤ 50KB)" || bad "A11 SKILL.md enorme (${SIZE}B)"

  # A12: sin writes fuera de su ámbito ni sudo embebido sin justificación
  UNSAFE=$(grep -rnE "^\s*sudo |sudo rm|chmod 777|> /etc/|> /usr/" "$DIR/scripts" 2>/dev/null | grep -v "\.bak" | head -2)
  [ -z "$UNSAFE" ] && ok "A12 sin sudo/writes de sistema gratuitos en scripts" || bad "A12 operaciones de sistema agresivas: $UNSAFE"

# =============== MODO MCP ===============
else
  echo "== Suite adversarial (mcp): $DIR =="

  # M1: artefactos presentes y válidos
  if [ -f "$DIR/package.json" ] && python3 -m json.tool "$DIR/package.json" >/dev/null 2>&1; then
    ok "M1 package.json JSON válido"
  else
    bad "M1 package.json ausente o inválido"
  fi

  # M2: SDK instalado
  [ -d "$DIR/node_modules/@modelcontextprotocol/sdk" ] && ok "M2 SDK @modelcontextprotocol instalado" || bad "M2 SDK ausente (npm install)"

  # M3: smoke test JSON-RPC real (initialize + tools/list + call + robustez)
  if bash "$(dirname "$0")/validate-mcp.sh" "$DIR" >/dev/null 2>&1; then
    ok "M3 smoke test JSON-RPC: initialize/list/call/robustez PASS"
  else
    bad "M3 smoke test JSON-RPC FALLA (ejecutar validate-mcp.sh $DIR para detalle)"
  fi

  # M4: patrones peligrosos en el server generado
  DANG=$(grep -nE "eval\(|child_process|execSync\(|/dev/tcp/|process\.env\.[A-Z_]*(KEY|TOKEN|SECRET|PASSWORD)" "$DIR/index.js" 2>/dev/null | grep -v "// " | head -2)
  [ -z "$DANG" ] && ok "M4 sin eval/exec/secretos-hardcode en index.js" || bad "M4 patrón peligroso: $DANG"

  # M5: secretos en todo el proyecto generado
  L=$(grep -rEn "(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{30,}|BEGIN (RSA|OPENSSH) PRIVATE KEY)" "$DIR" --include="*.js" --include="*.json" --include="*.md" 2>/dev/null | grep -v node_modules | head -2)
  [ -z "$L" ] && ok "M5 secretos: limpio" || bad "M5 secretos: $L"

  # M6: nombre del server válido para registro
  SERVER_NAME=$(basename "$DIR")
  echo "$SERVER_NAME" | grep -qE '^[a-z0-9][a-z0-9-]{0,63}$' && ok "M6 nombre '$SERVER_NAME' válido para mcp.json" || bad "M6 nombre '$SERVER_NAME' inválido"

  # M7: si está registrado en mcp.json, la entrada debe ser correcta y haber backup
  MCP_JSON="$HOME/.pi/agent/mcp.json"
  if grep -q "\"$SERVER_NAME\"" "$MCP_JSON" 2>/dev/null; then
    python3 -c "
import json, sys, os
cfg = json.load(open(os.path.expanduser('~/.pi/agent/mcp.json')))
e = cfg['mcpServers'].get('$SERVER_NAME')
assert e, 'sin entrada'
assert e['command'] == 'node', 'command != node'
assert e.get('lifecycle') == 'lazy', 'lifecycle != lazy'
assert os.path.isfile(e['args'][0]), 'index.js no existe: ' + e['args'][0]
" && ok "M7 registro en mcp.json: entrada válida y fichero existe" || bad "M7 registro en mcp.json inválido"
    ls "$MCP_JSON".bak.* >/dev/null 2>&1 && ok "M8 backups de mcp.json presentes" || bad "M8 sin backups de mcp.json"
  else
    ok "M7 no registrado en mcp.json (modo --no-register)"
    ok "M8 sin registro, no aplican backups"
  fi
fi

echo "== Suite adversarial [$MODE]: $FAILS fallos =="
exit $FAILS
