#!/usr/bin/env bash
# rotate-sni.sh — Update SNI directly in 3x-ui SQLite DB, then restart XRay.
# Usage: bash /root/rotate-sni.sh <new_sni>

set -euo pipefail

NEW_SNI="${1:?Usage: $0 <new_sni>}"
DB="/etc/x-ui/x-ui.db"

python3 << PYEOF
import json, subprocess, sys

db = "${DB}"
new_sni = "${NEW_SNI}"

result = subprocess.run(
    ["sqlite3", db, "SELECT stream_settings FROM inbounds WHERE id=1;"],
    capture_output=True, text=True
)
settings = json.loads(result.stdout.strip())

settings["realitySettings"]["target"] = f"{new_sni}:443"
settings["realitySettings"]["serverNames"] = [new_sni]

new_json = json.dumps(settings)
escaped = new_json.replace("'", "''")
sql = f"UPDATE inbounds SET stream_settings='{escaped}' WHERE id=1;"

subprocess.run(["sqlite3", db, sql], check=True)
print(f"DB updated: {new_sni}")
PYEOF

systemctl restart x-ui
sleep 2
systemctl is-active x-ui && echo "XRay restarted OK" || echo "ERROR: XRay restart failed"
