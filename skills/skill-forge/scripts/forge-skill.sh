#!/bin/bash
# forge-skill.sh — scaffolding de skills 100% compliant con agentskills.io
# Uso: forge-skill.sh <nombre-skill> "<description con disparadores>" [dir-destino]
set -euo pipefail

NAME="${1:-}"
DESC="${2:-}"
DEST="${3:-$HOME/.pi/agent/skills/${1:-}}"

usage() { echo "Uso: forge-skill.sh <nombre-skill> \"<description>\" [dir-destino]" >&2; exit 1; }

[ -z "$NAME" ] && usage
[ -z "$DESC" ] && { echo "ERROR: description obligatoria (con disparadores: 'Usar SIEMPRE que...')" >&2; exit 1; }

# Reglas del estándar (verificadas contra skills-ref): [a-z0-9-], <=64
if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]{0,63}$'; then
  echo "ERROR: name '$NAME' inválido. Reglas: minúsculas [a-z0-9-], máx 64 chars, empieza por letra/dígito." >&2
  exit 1
fi

# Límite de description: 1024 chars
if [ ${#DESC} -gt 1024 ]; then
  echo "ERROR: description ${#DESC} chars (máx 1024)." >&2
  exit 1
fi

[ -e "$DEST" ] && { echo "ERROR: $DEST ya existe." >&2; exit 1; }

VERSION="1.0.0"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DEST/scripts" "$DEST/references"

cat > "$DEST/SKILL.md" <<EOF
---
name: $NAME
description: $DESC
license: MIT
metadata:
  version: $VERSION
---

# $NAME

Generado por skill-forge el $TODAY. Completar esta sección con:

1. **Propósito** — qué problema resuelve en una frase.
2. **Cuándo activarse** — repetir los disparadores de la description y ampliarlos.
3. **Procedimiento** — pasos concretos y ejecutables (preferir scripts verificables a prosa).
4. **Límites** — qué NO hace este skill y cuándo no debe activarse.

## Procedimiento

TODO: documentar los pasos aquí. Si el procedimiento es automatizable,
ponerlo en scripts/ y llamarlo desde aquí:

\`\`\`bash
scripts/<script>.sh [args]
\`\`\`
EOF

cat > "$DEST/scripts/.gitkeep" <<'EOF'
EOF
cat > "$DEST/references/.gitkeep" <<'EOF'
EOF
chmod +x "$DEST/SKILL.md" 2>/dev/null || true
chmod -R u+rw "$DEST"

echo "Skill andamiada en: $DEST"
echo "Siguiente paso obligatorio: scripts/validate.sh \"$DEST\""
