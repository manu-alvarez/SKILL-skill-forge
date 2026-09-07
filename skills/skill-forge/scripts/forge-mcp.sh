#!/bin/bash
# forge-mcp.sh — scaffolding + registro de MCP servers (SDK oficial, stdio, Node)
# Uso: forge-mcp.sh <nombre-mcp> [dir-destino] [--no-register]
set -euo pipefail

NAME="${1:-}"
SHIFTED="${@:2}"
DEST=""
REGISTER=1

# parsear --no-register y dir destino
for arg in $SHIFTED; do
  case "$arg" in
    --no-register) REGISTER=0 ;;
    *) DEST="$arg" ;;
  esac
done

[ -z "$NAME" ] && { echo "Uso: forge-mcp.sh <nombre-mcp> [dir-destino] [--no-register]" >&2; exit 1; }
if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]{0,63}$'; then
  echo "ERROR: nombre MCP inválido (minúsculas [a-z0-9-], máx 64)." >&2; exit 1
fi
[ -z "$DEST" ] && DEST="$HOME/.pi/agent/mcp-servers/$NAME"
[ -e "$DEST" ] && { echo "ERROR: $DEST ya existe." >&2; exit 1; }

mkdir -p "$DEST"

# ---------- package.json ----------
cat > "$DEST/package.json" <<EOF
{
  "name": "$NAME",
  "version": "1.0.0",
  "type": "module",
  "private": true,
  "description": "MCP server generado por skill-forge",
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
EOF

# ---------- index.js: server stdio con tools echo + health ----------
cat > "$DEST/index.js" <<'EOF'
#!/usr/bin/env node
// MCP server generado por skill-forge. Transporte: stdio (newline-delimited JSON-RPC).
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema, ListToolsRequestSchema,
  InitializeRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: process.env.MCP_SERVER_NAME || "forge-mcp", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(InitializeRequestSchema, async (req) => ({
  protocolVersion: req.params.protocolVersion,
  capabilities: { tools: {} },
  serverInfo: { name: process.env.MCP_SERVER_NAME || "forge-mcp", version: "1.0.0" },
}));

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "echo",
      description: "Devuelve el texto recibido. Util para probar el canal.",
      inputSchema: {
        type: "object",
        properties: { text: { type: "string", description: "Texto a devolver" } },
        required: ["text"],
      },
    },
    {
      name: "health",
      description: "Comprueba que el server esta vivo. No requiere parametros.",
      inputSchema: { type: "object", properties: {} },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  if (name === "echo") {
    return { content: [{ type: "text", text: String(args?.text ?? "") }] };
  }
  if (name === "health") {
    return { content: [{ type: "text", text: "ok " + new Date().toISOString() }] };
  }
  return { content: [{ type: "text", text: "herramienta desconocida: " + name }], isError: true };
});

const transport = new StdioServerTransport();
await server.connect(transport);
EOF

chmod +x "$DEST/index.js"

cat > "$DEST/README.md" <<EOF
# $NAME (MCP server)

Generado por skill-forge. Server MCP stdio con tools de ejemplo (echo, health).

## Alta en Pi (~/.pi/agent/mcp.json)

\`\`\`json
{
  "mcpServers": {
    "$NAME": {
      "command": "node",
      "args": ["$DEST/index.js"],
      "lifecycle": "lazy",
      "directTools": false
    }
  }
}
\`\`\`
EOF

# ---------- npm install ----------
echo "[*] npm install en $DEST ..."
( cd "$DEST" && npm install --no-fund --no-audit --loglevel=error )

# ---------- registro en mcp.json (backup + atomico) ----------
if [ "$REGISTER" -eq 1 ]; then
  MCP_JSON="$HOME/.pi/agent/mcp.json"
  [ -f "$MCP_JSON" ] || { echo "ERROR: no existe $MCP_JSON" >&2; exit 1; }
  BACKUP="${MCP_JSON}.bak.$(date +%Y%m%d_%H%M%S)"
  cp "$MCP_JSON" "$BACKUP"
  echo "[*] backup: $BACKUP"
  MCP_JSON="$MCP_JSON" DEST="$DEST" NAME="$NAME" python3 - <<'PYEOF'
import json, os, tempfile
mp = os.environ["MCP_JSON"]
with open(mp) as f:
    cfg = json.load(f)
cfg.setdefault("mcpServers", {})[os.environ["NAME"]] = {
    "command": "node",
    "args": [os.path.join(os.environ["DEST"], "index.js")],
    "lifecycle": "lazy",
    "directTools": False,
}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(mp))
with os.fdopen(fd, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, mp)
print("[*] mcp.json actualizado atomicamente")
PYEOF
fi

echo "MCP andamiado en: $DEST"
echo "Siguiente paso obligatorio: scripts/validate-mcp.sh \"$DEST\""
