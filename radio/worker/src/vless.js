// Fortochka Radio — VLESS Link Generator
// Matches format from scripts/generate-client-config.sh

export function generateVlessLink(server) {
  const params = new URLSearchParams({
    type: "tcp",
    encryption: "none",
    security: "reality",
    pbk: server.publicKey,
    fp: "chrome",
    sni: server.sni,
    sid: server.shortId,
    spx: "/",
    flow: "xtls-rprx-vision",
  });

  return `vless://${server.uuid}@${server.ip}:${server.port}?${params.toString()}#Fortochka-${server.id}`;
}
