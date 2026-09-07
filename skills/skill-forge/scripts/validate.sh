#!/bin/bash
# validate.sh — validación estándar de una skill (agentskills.io + integración Pi + secretos)
# Uso: validate.sh <dir-skill>
set -uo pipefail

DIR="${1:-}"
[ -z "$DIR" ] && { echo "Uso: validate.sh <dir-skill>" >&2; exit 1; }
DIR="${DIR%/}"
FAILS=0

ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; FAILS=$((FAILS+1)); }

echo "== Validación estándar: $DIR =="

# 1. Existe SKILL.md
[ -f "$DIR/SKILL.md" ] && ok "SKILL.md presente" || fail "SKILL.md ausente"

# 2. Validador oficial agentskills.io
if command -v npx >/dev/null 2>&1; then
  OUT=$(npx -y skills-ref validate "$DIR" 2>&1)
  if echo "$OUT" | grep -q "^Valid skill"; then
    ok "skills-ref validate: PASS"
  else
    fail "skills-ref validate: $OUT"
  fi
else
  fail "npx no disponible (no se puede ejecutar el validador oficial)"
fi

# 3. Nombre de directorio == name del frontmatter
NAME_IN_FILE=$(awk '/^name:/{print $2; exit}' "$DIR/SKILL.md" 2>/dev/null)
BASENAME=$(basename "$DIR")
[ "$NAME_IN_FILE" = "$BASENAME" ] && ok "name '$NAME_IN_FILE' == directorio" || fail "name '$NAME_IN_FILE' != directorio '$BASENAME'"

# 4. Disparadores de uso en la description (para que el agente sepa activarla)
# Nota: cubre descriptions de una línea y folded (multi-línea con sangría)
DESC=$(awk '/^description:/{f=1; sub(/^description:[ \t]*/, ""); print; next} f && /^[a-zA-Z_]+:/{f=0} f{print}' "$DIR/SKILL.md" | tr '\n' ' ')
if echo "$DESC" | grep -qiE "usar|use |cuando|when|siempre|always|trigger"; then
  ok "description contiene disparadores de uso"
else
  fail "description sin disparadores de uso (añadir 'Usar SIEMPRE que...' / 'Use when...')"
fi

# 5. Sintaxis de scripts bash
SH_COUNT=0
for s in "$DIR"/scripts/*.sh; do
  [ -f "$s" ] || continue
  SH_COUNT=$((SH_COUNT+1))
  if bash -n "$s" 2>/dev/null; then ok "bash -n: $(basename "$s")"; else fail "bash -n: $(basename "$s")"; fi
done
[ $SH_COUNT -eq 0 ] && ok "sin scripts .sh (nada que validar)"

# 6. Permisos ejecutables en scripts
for s in "$DIR"/scripts/*.sh; do
  [ -f "$s" ] || continue
  [ -x "$s" ] && ok "ejecutable: $(basename "$s")" || { chmod +x "$s" && ok "permiso exec añadido: $(basename "$s")"; }
done

# 7. Escaneo de secretos (gitleaks si existe; fallback: patrones comunes)
if [ -x "$HOME/.pi/agent/skills/secrets-handling/scripts/scan-secrets.sh" ]; then
  if "$HOME/.pi/agent/skills/secrets-handling/scripts/scan-secrets.sh" "$DIR" >/dev/null 2>&1; then
    ok "escaneo de secretos (gitleaks): limpio"
  else
    fail "escaneo de secretos: HALLAZGOS (revisar con scan-secrets.sh $DIR)"
  fi
else
  LEAKS=$(grep -rEn "(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{30,}|xox[bp]-[a-zA-Z0-9-]{10,}|BEGIN (RSA|OPENSSH) PRIVATE KEY)" "$DIR" 2>/dev/null | grep -v "EJEMPLO\|example\|<.*>" | head -3)
  [ -z "$LEAKS" ] && ok "escaneo de secretos (patrones): limpio" || fail "posibles secretos: $LEAKS"
fi

echo "== Resultado validate: $FAILS fallos =="
exit $FAILS
