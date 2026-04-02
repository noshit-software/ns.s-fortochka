// Fortochka Radio — Cloudflare Worker
// API for server health status and VLESS link generation.

import { SERVERS, PIN } from "./config.js";
import { generateVlessLink } from "./vless.js";
import { checkAllServers } from "./health.js";

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

    return new Response("Not found", { status: 404 });
  },

  // Cron trigger — run health checks and cache in KV
  async scheduled(event, env) {
    const results = await checkAllServers(SERVERS);
    const status = buildStatusResponse(results);

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

function buildStatusResponse(results) {
  const statusMap = Object.fromEntries(results.map((r) => [r.id, r.status]));

  return {
    ts: new Date().toISOString(),
    servers: SERVERS.map((s) => ({
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
