// Fortochka Radio — Server Registry
//
// Single source of truth for all server and SNI configuration.
// Everything in the Worker reads from this — nothing hardcodes its own values.
//
// SNI field is the startup default only. At runtime the Worker reads live SNI
// from the 3x-ui panel API and writes it back here via KV. When the scanner
// finds better candidates it updates KV too. config.js is the seed, KV is truth.
//
// Shape of a server entry:
// {
//   id          — stable identifier, used as KV key prefix
//   name        — human label for the Radio UI
//   region      — machine tag (us-west, eu-east, etc.)
//   regionLabel — human label for the Radio UI
//   ip          — server IP (never changes without a new VPS)
//   port        — always 443
//   uuid        — VLESS UUID (never changes)
//   publicKey   — Reality public key (never changes)
//   shortId     — Reality short ID (never changes)
//   sni         — CURRENT SNI (seed value — runtime reads from panel/KV)
//   panelUrl    — 3x-ui panel base URL for this server
// }

export const SERVERS = [
  {
    id: "oracle-sanjose",
    name: "San Jose",
    region: "us-west",
    regionLabel: "USA West",
    ip: "163.192.34.235",
    port: 443,
    uuid: "cf68f21d-8804-4eb5-8ae9-51c66cde05ed",
    publicKey: "wuOOmeEXNx7XbZaBv8TLteEg8aaq2d6cAYb8PvSpnV8",
    shortId: "3d1343b411ce3c1c",
    sni: "yahoo.com",        // seed — runtime will use panel/KV value
    panelUrl: "PANEL_URL",  // resolved from env secret at runtime
  },
  {
    id: "hetzner-helsinki",
    name: "Helsinki",
    region: "eu-north",
    regionLabel: "Europe North",
    ip: "157.180.45.242",
    port: 443,
    uuid: "6fdf5939-5844-4e03-b4ad-1232bb12f5ce",
    publicKey: "RKU2oLZL1YnlpRApYaRXNKj4QIZfpSh0yacJlL4WLTQ",
    shortId: "3cdd",
    sni: "yahoo.com",
    panelUrl: "PANEL_URL_HELSINKI",
  },
  // Future servers drop in here — same shape, zero other changes needed:
  // {
  //   id: "scaleway-warsaw",
  //   name: "Warsaw",
  //   region: "eu-east",
  //   regionLabel: "Europe East",
  //   ip: "...",
  //   port: 443,
  //   uuid: "...",
  //   publicKey: "...",
  //   shortId: "...",
  //   sni: "microsoft.com",
  //   panelUrl: "PANEL_URL_WARSAW",
  // },
];

// SNI candidates for auto-rotation, ordered by reliability from Russia.
// Rules: major domain Russia can't block, TLS 1.3, NOT behind Cloudflare/Fastly CDN.
// This list is the seed — the scanner will reorder it in KV based on live probe results.
export const SNI_CANDIDATES = [
  "yahoo.com",       // Yahoo — confirmed working from Moscow
  "ya.ru",           // Yandex — owns Russian infrastructure
  "apple.com",       // Apple — large iOS user base, stable IPs
  "microsoft.com",   // Microsoft — enterprise dependency
  "samsung.com",     // Samsung — major phone vendor
  "rbc.ru",          // Russian business news
  "dzen.ru",         // Yandex Zen
  "vkvideo.ru",      // VK Video
  "dl.google.com",   // Google download servers — sometimes passes
];

// Optional PIN for /api/connect (set via `npx wrangler secret put PIN`)
export const PIN = "";
