// Fortochka Radio — Server Configuration
// SENSITIVE: Contains server IPs, UUIDs, and keys. Never expose to frontend.
// Update this file when servers are added, removed, or reconfigured.

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
    sni: "yahoo.com",
    sniLabel: "Yahoo",
  },
  // Add more servers here as they come online:
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
  //   sni: "samsung.com",
  //   sniLabel: "Samsung",
  // },
  // {
  //   id: "scaleway-paris",
  //   name: "Paris",
  //   region: "eu-west",
  //   regionLabel: "Europe West",
  //   ip: "...",
  //   port: 443,
  //   uuid: "...",
  //   publicKey: "...",
  //   shortId: "...",
  //   sni: "microsoft.com",
  //   sniLabel: "Microsoft",
  // },
];

// PIN for /api/connect endpoint (optional, set via wrangler secret in prod)
// If empty, no PIN required
export const PIN = "";
