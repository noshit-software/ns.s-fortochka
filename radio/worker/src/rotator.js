// Fortochka Radio — SNI Auto-Rotator
//
// When the cron health check finds a server is down, this module:
//   1. Tries each SNI candidate from the whitelist in order
//   2. When it finds one that passes the health check, calls the 3x-ui API
//      to update the inbound configuration on the live server
//   3. Returns the new SNI so callers can update KV and in-memory state
//
// Required Worker secrets (set via `npx wrangler secret put`):
//   PANEL_URL    — e.g. http://163.192.34.235:2053/mHdFe3WjFxXacirHi0
//   PANEL_USER   — e.g. admin
//   PANEL_PASS   — panel password
//
// The rotation only changes the SNI/target on the 3x-ui inbound.
// The server IP, UUID, and keys stay the same.

const HEALTH_TIMEOUT_MS = 8000;

// Test if a given SNI passes through to a server IP.
// Sends an HTTPS request with the SNI in the Host header.
// Reality forwards it to the real target — any response = alive.
async function probeSni(ip, port, sni) {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS);
    await fetch(`https://${ip}:${port}/`, {
      signal: controller.signal,
      headers: { Host: sni },
      redirect: "manual",
    });
    clearTimeout(timer);
    return true;
  } catch {
    return false;
  }
}

// Log into the 3x-ui panel and return a session cookie.
async function panelLogin(panelUrl, user, pass) {
  const res = await fetch(`${panelUrl}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: user, password: pass }),
  });
  if (!res.ok) throw new Error(`Panel login HTTP ${res.status}`);
  const data = await res.json();
  if (!data.success) throw new Error(`Panel login failed: ${data.msg}`);

  // Extract session cookie
  const setCookie = res.headers.get("set-cookie") || "";
  const cookie = setCookie.split(";")[0]; // "3x-ui=..."
  if (!cookie) throw new Error("No session cookie in panel login response");
  return cookie;
}

// Fetch the current inbound list from 3x-ui.
async function getInbounds(panelUrl, cookie) {
  const res = await fetch(`${panelUrl}/xui/inbound/list`, {
    headers: { Cookie: cookie },
  });
  if (!res.ok) throw new Error(`Get inbounds HTTP ${res.status}`);
  const data = await res.json();
  if (!data.success) throw new Error(`Get inbounds failed: ${data.msg}`);
  return data.obj; // array of inbound objects
}

// Find the VLESS inbound on port 443.
function findVlessInbound(inbounds) {
  return inbounds.find((ib) => ib.protocol === "vless" && ib.port === 443);
}

// Update the SNI/target on a 3x-ui inbound.
// streamSettings.realitySettings.serverNames and dest are what we change.
async function updateInboundSni(panelUrl, cookie, inbound, newSni) {
  const settings = JSON.parse(inbound.streamSettings);

  settings.realitySettings.serverNames = [newSni];
  settings.realitySettings.dest = `${newSni}:443`;

  const updated = {
    ...inbound,
    streamSettings: JSON.stringify(settings),
  };

  const res = await fetch(`${panelUrl}/xui/inbound/update/${inbound.id}`, {
    method: "POST",
    headers: {
      Cookie: cookie,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(updated),
  });

  if (!res.ok) throw new Error(`Update inbound HTTP ${res.status}`);
  const data = await res.json();
  if (!data.success) throw new Error(`Update inbound failed: ${data.msg}`);
}

// Restart XRay via the 3x-ui API so the new SNI takes effect.
async function restartXray(panelUrl, cookie) {
  const res = await fetch(`${panelUrl}/xui/inbound/restart`, {
    method: "POST",
    headers: { Cookie: cookie },
  });
  // Best-effort — don't throw if this endpoint doesn't exist on all versions
  if (!res.ok) {
    console.warn(`XRay restart returned HTTP ${res.status} — may need manual restart`);
  }
}

// Resolve the panel URL for a server.
// server.panelUrl is a key name into env (e.g. "PANEL_URL", "PANEL_URL_WARSAW").
// This lets each server have its own panel credentials without hardcoding URLs.
function resolvePanelUrl(server, env) {
  return env[server.panelUrl] || env.PANEL_URL || null;
}

// Pick a random candidate from KV (not the current SNI) and apply it to the panel.
// Called by /api/rotate-now — triggered by the Moscow scanner when it detects a block.
export async function rotateNow(server, env) {
  const panelUrl = resolvePanelUrl(server, env);
  const panelUser = env.PANEL_USER;
  const panelPass = env.PANEL_PASS;

  if (!panelUrl || !panelUser || !panelPass) {
    return { ok: false, reason: "Panel credentials not configured" };
  }

  const currentSni = env.STATUS_KV ? await env.STATUS_KV.get(`sni:${server.id}`) : server.sni;
  const stored = env.STATUS_KV ? await env.STATUS_KV.get("sni-candidates") : null;
  const candidates = stored ? JSON.parse(stored) : [];

  const others = candidates.filter((s) => s !== currentSni);
  if (others.length === 0) {
    return { ok: false, reason: "No alternative candidates in KV" };
  }

  const newSni = others[Math.floor(Math.random() * others.length)];

  try {
    const cookie = await panelLogin(panelUrl, panelUser, panelPass);
    const inbounds = await getInbounds(panelUrl, cookie);
    const inbound = findVlessInbound(inbounds);
    if (!inbound) return { ok: false, reason: "No VLESS inbound found on port 443" };

    await updateInboundSni(panelUrl, cookie, inbound, newSni);
    await restartXray(panelUrl, cookie);

    if (env.STATUS_KV) {
      await env.STATUS_KV.put(`sni:${server.id}`, newSni);
    }

    console.log(`[rotate-now] ${server.id}: ${currentSni} → ${newSni}`);
    return { ok: true, newSni, previousSni: currentSni };
  } catch (err) {
    return { ok: false, reason: `Panel error: ${err.message}` };
  }
}

// Fetch the current SNI from the live 3x-ui inbound config.
// Returns the SNI string, or null if panel is unreachable or misconfigured.
export async function getLiveSni(server, env) {
  const panelUrl = resolvePanelUrl(server, env);
  const panelUser = env.PANEL_USER;
  const panelPass = env.PANEL_PASS;

  if (!panelUrl || !panelUser || !panelPass) return null;

  try {
    const cookie = await panelLogin(panelUrl, panelUser, panelPass);
    const inbounds = await getInbounds(panelUrl, cookie);
    const inbound = findVlessInbound(inbounds);
    if (!inbound) return null;

    const settings = JSON.parse(inbound.streamSettings);
    const serverNames = settings?.realitySettings?.serverNames;
    return Array.isArray(serverNames) && serverNames.length > 0 ? serverNames[0] : null;
  } catch {
    return null;
  }
}

// Get the current ranked SNI candidate list.
// Priority: KV (live scanner results) → sniCandidates arg (config.js seed)
// If scanner goes offline and KV expires, seed keeps everything working.
export async function getCandidates(sniCandidates, env) {
  if (env.STATUS_KV) {
    const stored = await env.STATUS_KV.get("sni-candidates");
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      } catch { /* fall through */ }
    }
  }
  return sniCandidates; // config.js seed fallback
}

// Main rotation function.
// Tries each SNI candidate until one works, then updates the panel.
// Returns { rotated: true, newSni } or { rotated: false, reason }.
export async function rotateSni(server, sniCandidates, env) {
  const panelUrl = resolvePanelUrl(server, env);
  const panelUser = env.PANEL_USER;
  const panelPass = env.PANEL_PASS;

  if (!panelUrl || !panelUser || !panelPass) {
    return { rotated: false, reason: "Panel credentials not configured (set PANEL_URL, PANEL_USER, PANEL_PASS secrets)" };
  }

  // Find a working SNI — skip the current one, shuffle the rest, fall back to current
  const currentSni = server.sni;
  const others = sniCandidates.filter((s) => s !== currentSni);
  // Fisher-Yates shuffle so DPI can't learn a fixed rotation pattern
  for (let i = others.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [others[i], others[j]] = [others[j], others[i]];
  }
  const candidates = [...others, currentSni];

  let workingSni = null;
  for (const sni of candidates) {
    const alive = await probeSni(server.ip, server.port, sni);
    if (alive) {
      workingSni = sni;
      break;
    }
  }

  if (!workingSni) {
    return { rotated: false, reason: "All SNI candidates failed — server may be down" };
  }

  if (workingSni === currentSni) {
    return { rotated: false, reason: "Current SNI is already the best option" };
  }

  // Update the panel
  try {
    const cookie = await panelLogin(panelUrl, panelUser, panelPass);
    const inbounds = await getInbounds(panelUrl, cookie);
    const inbound = findVlessInbound(inbounds);

    if (!inbound) {
      return { rotated: false, reason: "No VLESS inbound found on port 443" };
    }

    await updateInboundSni(panelUrl, cookie, inbound, workingSni);
    await restartXray(panelUrl, cookie);

    console.log(`[rotator] SNI rotated: ${currentSni} → ${workingSni}`);
    return { rotated: true, newSni: workingSni };
  } catch (err) {
    return { rotated: false, reason: `Panel API error: ${err.message}` };
  }
}
