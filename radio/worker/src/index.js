// Fortochka Radio — Cloudflare Worker
// API for server status, VLESS subscription feed, and SNI state sync.
//
// The Worker does NOT touch the 3x-ui panel — Cloudflare Workers cannot reach
// port 2053 (blocked outbound). All panel updates are done by check-connection.sh
// on the RUVDS Moscow box. The Worker is a coordination layer only:
//   - Serves subscription URLs to client apps
//   - Stores current SNI state in KV (written by RUVDS after each rotation)
//   - Stores scan results in KV (written by scan-sni.sh every 4h)

import { SERVERS, PIN, SNI_CANDIDATES } from "./config.js";
import { generateVlessLink } from "./vless.js";
import { checkAllServers } from "./health.js";
import { getCandidates } from "./rotator.js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Pin, X-Scan-Secret",
};

let cachedStatus = null;
let cachedAt = 0;
const CACHE_TTL = 60_000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (url.pathname === "/api/status" && request.method === "GET") {
      return handleStatus(env);
    }

    if (url.pathname === "/api/connect" && request.method === "POST") {
      return handleConnect(request, env);
    }

    if (url.pathname === "/api/sub" && request.method === "GET") {
      return handleSub(env);
    }

    // Receive ranked SNI candidates from the Moscow scanner (scan-sni.sh every 4h).
    if (url.pathname === "/api/scan-results" && request.method === "POST") {
      return handleScanResults(request, env);
    }

    // Called by check-connection.sh after it updates the panel directly.
    // Keeps KV in sync so subscription URLs serve the new SNI immediately.
    if (url.pathname === "/api/set-sni" && request.method === "POST") {
      return handleSetSni(request, env);
    }

    return new Response("Not found", { status: 404 });
  },

  // Cron — run health checks and update status KV for monitoring.
  // No panel touching — just observability.
  async scheduled(event, env) {
    const servers = await Promise.all(
      SERVERS.map(async (s) => {
        const kvSni = env.STATUS_KV ? await env.STATUS_KV.get(`sni:${s.id}`) : null;
        return kvSni ? { ...s, sni: kvSni } : s;
      })
    );

    const results = await checkAllServers(servers);

    const status = buildStatusResponse(results, servers);
    if (env.STATUS_KV) {
      await env.STATUS_KV.put("status", JSON.stringify(status));
    }

    cachedStatus = status;
    cachedAt = Date.now();

    const down = results.filter((r) => r.status === "down").map((r) => r.id);
    if (down.length > 0) {
      console.log(`[cron] Servers down: ${down.join(", ")} — check-connection.sh on RUVDS handles rotation`);
    }
  },
};

async function handleStatus(env) {
  if (env.STATUS_KV) {
    const stored = await env.STATUS_KV.get("status");
    if (stored) return jsonResponse(JSON.parse(stored));
  }

  if (cachedStatus && Date.now() - cachedAt < CACHE_TTL) {
    return jsonResponse(cachedStatus);
  }

  const results = await checkAllServers(SERVERS);
  const status = buildStatusResponse(results);
  cachedStatus = status;
  cachedAt = Date.now();
  return jsonResponse(status);
}

async function handleConnect(request, env) {
  const configPin = env.PIN || PIN;
  if (configPin) {
    const providedPin = request.headers.get("X-Pin") || "";
    if (providedPin !== configPin) {
      return jsonResponse({ error: "Invalid PIN" }, 403);
    }
  }

  let body;
  try { body = await request.json(); }
  catch { return jsonResponse({ error: "Invalid JSON" }, 400); }

  const server = SERVERS.find((s) => s.id === body.id);
  if (!server) return jsonResponse({ error: "Server not found" }, 404);

  return jsonResponse({ vless: generateVlessLink(server) });
}

// Subscription endpoint — base64(vless_link\n...) for v2ray-compatible apps.
// Reads current SNI from KV. Falls back to config.js seed.
async function handleSub(env) {
  const liveServers = await Promise.all(
    SERVERS.map(async (s) => {
      const kvSni = env.STATUS_KV ? await env.STATUS_KV.get(`sni:${s.id}`) : null;
      return kvSni ? { ...s, sni: kvSni } : s;
    })
  );

  const links = liveServers.map((s) => generateVlessLink(s)).join("\n");
  const encoded = btoa(links);

  return new Response(encoded, {
    status: 200,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Profile-Update-Interval": "1",
    },
  });
}

// Receive ranked SNI candidates from scan-sni.sh (Moscow scanner, every 4h).
async function handleScanResults(request, env) {
  const secret = env.SCAN_SECRET;
  if (secret) {
    const provided = request.headers.get("X-Scan-Secret") || "";
    if (provided !== secret) return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body;
  try { body = await request.json(); }
  catch { return jsonResponse({ error: "Invalid JSON" }, 400); }

  if (!Array.isArray(body.candidates) || body.candidates.length === 0) {
    return jsonResponse({ error: "No candidates in payload" }, 400);
  }

  const candidates = body.candidates.map((c) => c.sni).filter(Boolean);

  if (env.STATUS_KV) {
    await env.STATUS_KV.put("sni-candidates", JSON.stringify(candidates), {
      expirationTtl: 60 * 60 * 12,
    });
    await env.STATUS_KV.put("sni-scan-meta", JSON.stringify({
      scanned_at: body.scanned_at,
      total: body.total,
      passed: body.passed,
      received_at: new Date().toISOString(),
    }));
  }

  console.log(`[scan] Received ${candidates.length} candidates`);
  return jsonResponse({ ok: true, stored: candidates.length });
}

// Called by check-connection.sh after it updates the panel directly.
// Just writes the new SNI to KV — subscription URL picks it up immediately.
async function handleSetSni(request, env) {
  const secret = env.SCAN_SECRET;
  if (secret) {
    const provided = request.headers.get("X-Scan-Secret") || "";
    if (provided !== secret) return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body;
  try { body = await request.json(); }
  catch { return jsonResponse({ error: "Invalid JSON" }, 400); }

  const { server_id, sni } = body;
  if (!server_id || !sni) return jsonResponse({ error: "server_id and sni required" }, 400);

  const server = SERVERS.find((s) => s.id === server_id);
  if (!server) return jsonResponse({ error: `Unknown server: ${server_id}` }, 404);

  if (env.STATUS_KV) {
    await env.STATUS_KV.put(`sni:${server_id}`, sni);
  }

  console.log(`[set-sni] ${server_id}: ${sni}`);
  return jsonResponse({ ok: true, server_id, sni });
}

function buildStatusResponse(results, servers = SERVERS) {
  const statusMap = Object.fromEntries(results.map((r) => [r.id, r.status]));
  return {
    ts: new Date().toISOString(),
    servers: servers.map((s) => ({
      id: s.id,
      name: s.name,
      region: s.region,
      regionLabel: s.regionLabel,
      sni: s.sni,
      status: statusMap[s.id] || "unknown",
    })),
  };
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
