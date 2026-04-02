// Fortochka Radio — VLESS Link Generator
// Matches format from scripts/generate-client-config.sh

export function generateVlessLink(server) {
  const params = new URLSearchParams({
    encryption: "none",
    flow: "xtls-rprx-vision",
    security: "reality",
    sni: server.sni,
    fp: "chrome",
    pbk: server.publicKey,
    sid: server.shortId,
    type: "tcp",
  });

  return `vless://${server.uuid}@${server.ip}:${server.port}?${params.toString()}#Fortochka-${server.id}`;
}
