// Fortochka Radio — VLESS Link Generator

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

export function generateVlessWsLink(server, cfDomain) {
  const params = new URLSearchParams({
    type: "ws",
    encryption: "none",
    security: "tls",
    host: cfDomain,
    path: "/vless",
    fp: "chrome",
    sni: cfDomain,
  });

  return `vless://${server.uuid}@${cfDomain}:443?${params.toString()}#Fortochka-${server.id}-ws`;
}
