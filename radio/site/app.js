// Fortochka Radio — Frontend
// Fetches server status from Worker API, renders preset buttons,
// handles connection link generation.

const API_BASE = "https://fortochka-radio-api.robertgardunia.workers.dev";

const $ = (sel) => document.querySelector(sel);
const statusText = $("#status-text");
const powerLed = $("#power-led");
const presetsEl = $("#presets");
const outputEl = $("#output");

let servers = [];
let selectedId = null;

// ─── Init ───────────────────────────────────────────────────

async function init() {
  await fetchStatus();
  setInterval(fetchStatus, 60_000); // Refresh every 60s
}

// ─── Fetch Status ───────────────────────────────────────────

async function fetchStatus() {
  try {
    const resp = await fetch(`${API_BASE}/api/status`);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const data = await resp.json();

    servers = data.servers;
    powerLed.className = "power-led online";
    statusText.textContent = `${servers.filter((s) => s.status === "ok").length} of ${servers.length} stations`;

    renderPresets();
  } catch (e) {
    powerLed.className = "power-led offline";
    statusText.textContent = "No signal";
    presetsEl.innerHTML = '<div style="color:#8b7050;font-style:italic;padding:20px;text-align:center;">Cannot reach stations</div>';
  }
}

// ─── Render Preset Buttons ──────────────────────────────────

function renderPresets() {
  presetsEl.innerHTML = "";

  servers.forEach((server) => {
    const btn = document.createElement("button");
    btn.className = `preset-btn ${server.status}`;
    if (server.id === selectedId) btn.classList.add("selected");

    btn.innerHTML = `
      <span class="btn-led"></span>
      <span class="btn-name">${server.name}</span>
      <span class="btn-detail">${server.regionLabel} · ${server.sniLabel}</span>
    `;

    if (server.status === "ok") {
      btn.addEventListener("click", () => tuneIn(server.id));
    }

    presetsEl.appendChild(btn);
  });

  // If no servers at all, show message
  if (servers.length === 0) {
    presetsEl.innerHTML = '<div style="color:#8b7050;font-style:italic;padding:20px;text-align:center;">No stations configured</div>';
  }
}

// ─── Tune In ────────────────────────────────────────────────

async function tuneIn(id) {
  selectedId = id;
  renderPresets();

  outputEl.innerHTML = '<div class="output-idle">Tuning in...</div>';

  try {
    const resp = await fetch(`${API_BASE}/api/connect`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id }),
    });

    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const data = await resp.json();

    // Copy to clipboard
    try {
      await navigator.clipboard.writeText(data.vless);
      outputEl.innerHTML = `
        <div class="output-success">
          Copied!
          <span class="output-link">${data.vless}</span>
        </div>
        <div class="output-instructions">
          Open <strong>v2RayTun</strong> → tap <strong>+</strong> → <strong>Import from clipboard</strong>
        </div>
      `;
    } catch {
      // Clipboard API failed (e.g., not HTTPS) — show the link to copy manually
      outputEl.innerHTML = `
        <div class="output-success">
          Long-press to copy:
          <span class="output-link" id="vless-link">${data.vless}</span>
        </div>
        <div class="output-instructions">
          Copy the link above, then open <strong>v2RayTun</strong> → tap <strong>+</strong> → <strong>Import from clipboard</strong>
        </div>
      `;
      // Select text for easy copying
      const linkEl = $("#vless-link");
      if (linkEl) {
        const range = document.createRange();
        range.selectNodeContents(linkEl);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      }
    }
  } catch (e) {
    outputEl.innerHTML = `<div class="output-error">Failed to tune in. Try another station.</div>`;
  }
}

// ─── Start ──────────────────────────────────────────────────

init();
