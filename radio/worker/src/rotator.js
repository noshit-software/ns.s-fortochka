// Fortochka Radio — SNI Candidate Store
//
// The Worker no longer touches the 3x-ui panel directly — Cloudflare Workers
// cannot reach port 2053 (blocked outbound port). All panel updates are done
// by check-connection.sh on the RUVDS Moscow box, which then notifies the
// Worker via /api/set-sni so KV stays in sync.
//
// This module only handles reading/writing SNI state in KV.

// Get the current ranked SNI candidate list.
// Priority: KV (live scanner results) → sniCandidates seed (config.js)
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
  return sniCandidates;
}
