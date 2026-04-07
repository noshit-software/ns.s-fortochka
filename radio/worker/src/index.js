// Fortochka Radio — Cloudflare Worker
// API for server health status, VLESS link generation, and subscription feed.

import { SERVERS, PIN, SNI_CANDIDATES } from "./config.js";
import { generateVlessLink } from "./vless.js";
import { checkAllServers } from "./health.js";
import { rotateSni, getLiveSni, getCandidates } from "./rotator.js";

// CORS headers
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*", // Lock to Pages domain in production
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Pin",
};

// In-memory cache for health results (persists ~30s between requests in Workers)
let cachedStatus = null;
let cachedAt = 0;
const CACHE_TTL = 60_000; // 1 minute

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // Route requests
    if (url.pathname === "/api/status" && request.method === "GET") {
      return handleStatus(env);
    }

    if (url.pathname === "/api/connect" && request.method === "POST") {
      return handleConnect(request, env);
    }

    // Subscription endpoint — returns base64-encoded VLESS links for v2ray-compatible apps.
    // Stable URL: apps poll this to get the current working config after any rotation.
    if (url.pathname === "/api/sub" && request.method === "GET") {
      return handleSub(env);
    }

    // Scan results ingest — receives ranked SNI candidates from the Moscow scanner box.
    // Scanner is optional — if it goes down, rotator falls back to config.js seed.
    if (url.pathname === "/api/scan-results" && request.method === "POST") {
      return handleScanResults(request, env);
    }

    return new Response("Not found", { status: 404 });
  },

  // Cron trigger — sync SNI from panel, run health checks, rotate if needed
  async scheduled(event, env) {
    // Build live server list: KV is truth, panel is fallback, config.js is seed
    let servers = await Promise.all(
      SERVERS.map(async (s) => {
        // First check KV
        const kvSni = env.STATUS_KV ? await env.STATUS_KV.get(`sni:${s.id}`) : null;
        if (kvSni) return { ...s, sni: kvSni };
        // KV cold — sync from panel and seed KV
        const panelSni = await getLiveSni(s, env);
        if (panelSni && env.STATUS_KV) {
          await env.STATUS_KV.put(`sni:${s.id}`, panelSni);
        }
        return panelSni ? { ...s, sni: panelSni } : s;
      })
    );

    const results = await checkAllServers(servers);

    // Get current candidate list — KV (scanner results) or config.js seed
    const candidates = await getCandidates(SNI_CANDIDATES, env);

    // For any server that's down, attempt SNI rotation
    const rotationPromises = results
      .filter((r) => r.status === "down")
      .map(async (r) => {
        const server = servers.find((s) => s.id === r.id);
        if (!server) return;

        const rotation = await rotateSni(server, candidates, env);
        if (rotation.rotated) {
          console.log(`[cron] Rotated ${server.id} SNI to ${rotation.newSni}`);
          // KV is now truth for this server
          if (env.STATUS_KV) {
            await env.STATUS_KV.put(`sni:${server.id}`, rotation.newSni);
          }
          servers = servers.map((s) =>
            s.id === server.id ? { ...s, sni: rotation.newSni } : s
          );
          r.status = "ok";
        } else {
          console.log(`[cron] Rotation skipped for ${server.id}: ${rotation.reason}`);
        }
      });

    await Promise.allSettled(rotationPromises);

    const status = buildStatusResponse(results, servers);
    if (env.STATUS_KV) {
      await env.STATUS_KV.put("status", JSON.stringify(status));
    }

    cachedStatus = status;
    cachedAt = Date.now();
  },
};

async function handleStatus(env) {
  // Try KV first (most up-to-date from cron)
  if (env.STATUS_KV) {
    const stored = await env.STATUS_KV.get("status");
    if (stored) {
      return jsonResponse(JSON.parse(stored));
    }
  }

  // Try in-memory cache
  if (cachedStatus && Date.now() - cachedAt < CACHE_TTL) {
    return jsonResponse(cachedStatus);
  }

  // Fallback: run checks now
  const results = await checkAllServers(SERVERS);
  const status = buildStatusResponse(results);

  cachedStatus = status;
  cachedAt = Date.now();

  return jsonResponse(status);
}

async function handleConnect(request, env) {
  // Optional PIN check
  const configPin = env.PIN || PIN;
  if (configPin) {
    const providedPin = request.headers.get("X-Pin") || "";
    if (providedPin !== configPin) {
      return jsonResponse({ error: "Invalid PIN" }, 403);
    }
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const server = SERVERS.find((s) => s.id === body.id);
  if (!server) {
    return jsonResponse({ error: "Server not found" }, 404);
  }

  const vless = generateVlessLink(server);
  return jsonResponse({ vless });
}

// Standard v2ray subscription format: base64(link1\nlink2\n...)
// Reads current SNI from KV (written by cron after each rotation).
// Falls back to config.js seed — panel is never hit on this path.
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
      "Profile-Update-Interval": "6",
    },
  });
}

// Receive ranked SNI candidates from the Moscow scanner box.
// Validates the secret, stores ordered list in KV with a TTL.
// If the scanner goes silent, KV expires and rotator falls back to config.js seed.
async function handleScanResults(request, env) {
  const secret = env.SCAN_SECRET;
  if (secret) {
    const provided = request.headers.get("X-Scan-Secret") || "";
    if (provided !== secret) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  if (!Array.isArray(body.candidates) || body.candidates.length === 0) {
    return jsonResponse({ error: "No candidates in payload" }, 400);
  }

  // Store ordered list — rotator reads this, falls back to config.js if absent
  const candidates = body.candidates.map((c) => c.sni).filter(Boolean);

  if (env.STATUS_KV) {
    // TTL: 12 hours — if scanner goes silent, fall back to seed after this window
    await env.STATUS_KV.put("sni-candidates", JSON.stringify(candidates), {
      expirationTtl: 60 * 60 * 12,
    });
    await env.STATUS_KV.put("sni-scan-meta", JSON.stringify({
      scanned_at: body.scanned_at,
      server_ip: body.server_ip,
      total: body.total,
      passed: body.passed,
      received_at: new Date().toISOString(),
    }));
  }

  console.log(`[scan] Received ${candidates.length} candidates from ${body.server_ip}`);
  return jsonResponse({ ok: true, stored: candidates.length });
}

// servers param allows cron to pass a post-rotation copy with updated SNI values
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
      sniLabel: s.sniLabel,
      status: statusMap[s.id] || "unknown",
    })),
  };
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}
