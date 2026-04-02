// Fortochka Radio — Server Health Probes
// Uses fetch() since Workers can't open raw TCP sockets.
// Reality servers forward HTTPS requests to the real SNI target,
// so any HTTP response = server is alive and Reality is working.

export async function checkServer(server) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    await fetch(`https://${server.ip}:${server.port}/`, {
      signal: controller.signal,
      headers: { Host: server.sni },
      // Don't follow redirects — we just want to know if the server responds
      redirect: "manual",
    });

    clearTimeout(timeout);
    return "ok";
  } catch (e) {
    return "down";
  }
}

export async function checkAllServers(servers) {
  const results = await Promise.allSettled(
    servers.map(async (server) => ({
      id: server.id,
      status: await checkServer(server),
    }))
  );

  return results.map((r) => (r.status === "fulfilled" ? r.value : { id: "unknown", status: "down" }));
}
