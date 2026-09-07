#!/bin/bash
# validate-mcp.sh — validación de un MCP server generado (smoke test JSON-RPC real)
# Uso: validate-mcp.sh <dir-mcp>
set -euo pipefail

DIR="${1:-}"
[ -z "$DIR" ] && { echo "Uso: validate-mcp.sh <dir-mcp>" >&2; exit 1; }
DIR="${DIR%/}"

[ -f "$DIR/index.js" ] || { echo "ERROR: $DIR/index.js no existe" >&2; exit 1; }
[ -d "$DIR/node_modules/@modelcontextprotocol/sdk" ] || { echo "ERROR: falta @modelcontextprotocol/sdk (npm install)" >&2; exit 1; }

echo "== Smoke test JSON-RPC: $DIR/index.js =="

# Prueba real: spawn del server, initialize, tools/list y tools/call echo
DIR="$DIR" node --input-type=module -e '
import { spawn } from "node:child_process";
import assert from "node:assert";

const dir = process.env.DIR;
const child = spawn("node", [dir + "/index.js"], { stdio: ["pipe", "pipe", "pipe"] });

let buf = "";
const pending = new Map();
let nextId = 1;

child.stdout.on("data", (chunk) => {
  buf += chunk.toString();
  let idx;
  while ((idx = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id !== undefined && pending.has(msg.id)) {
        pending.get(msg.id)(msg);
        pending.delete(msg.id);
      }
    } catch { /* línea no JSON: ignorar */ }
  }
});

function request(method, params) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, resolve);
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error("timeout " + method)); } }, 15000);
  });
}

const failures = [];
try {
  const init = await request("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "forge-validator", version: "1.0.0" },
  });
  assert.ok(init.result?.serverInfo?.name, "initialize sin serverInfo");
  console.log("  [OK] initialize -> serverInfo: " + init.result.serverInfo.name + " v" + init.result.serverInfo.version);

  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

  const list = await request("tools/list", {});
  const tools = list.result?.tools ?? [];
  assert.ok(tools.length >= 1, "tools/list vacío");
  for (const t of tools) {
    assert.ok(/^[a-z0-9_-]+$/.test(t.name), "nombre de tool inválido: " + t.name);
    assert.ok(t.description && t.description.length > 5, "tool sin description: " + t.name);
    assert.ok(t.inputSchema?.type === "object", "inputSchema no object: " + t.name);
  }
  console.log("  [OK] tools/list -> " + tools.map(t => t.name).join(", "));

  const call = await request("tools/call", { name: "echo", arguments: { text: "ping-forge" } });
  const out = call.result?.content?.[0]?.text;
  assert.strictEqual(out, "ping-forge", "echo no devuelve el texto");
  console.log("  [OK] tools/call echo -> roundtrip correcto");

  const unknown = await request("tools/call", { name: "no_existe", arguments: {} });
  assert.ok(unknown.result?.isError === true || unknown.error, "tool desconocida debería fallar controladamente");
  console.log("  [OK] tool desconocida -> error controlado (sin crash)");
} catch (e) {
  failures.push(e.message);
} finally {
  child.kill("SIGTERM");
}

if (failures.length) { console.error("  [FAIL] " + failures.join("; ")); process.exit(1); }
process.exit(0);
'

echo "== Smoke test: PASS =="
