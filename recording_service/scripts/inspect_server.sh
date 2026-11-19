#!/usr/bin/env bash
# Read-only look at the Contabo server's live-class setup (changes nothing).
# Secrets are masked: only key NAMES are shown, never their values.
D=/opt/calligro-livekit
cd "$D" || { echo "No $D"; exit 1; }
echo "== Files in $D"; ls -la
echo; echo "== docker-compose.yml"; cat docker-compose.yml
echo; echo "== config.yaml (secret values masked)"
sed -E 's/^([[:space:]]*(api_key|api_secret|access_key|secret|key|password)[^:]*:).*/\1 <hidden>/I' config.yaml
echo; echo "== livekit.yaml (keys section masked)"
awk 'BEGIN{k=0} /^keys:/{print "keys: <hidden>"; k=1; next} k && /^[[:space:]]/{next} {k=0; print}' livekit.yaml \
  | sed -E 's/^([[:space:]]*api_key:).*/\1 <hidden>/'
echo; echo "== .env key names (values hidden)"
[ -f .env ] && sed -E 's/=.*/=<hidden>/' .env || echo "(no .env)"
echo; echo "== Caddy"
command -v caddy && caddy version; systemctl is-active caddy 2>/dev/null
docker ps --format '{{.Names}}  {{.Image}}' | grep -i caddy
for f in /etc/caddy/Caddyfile "$D/Caddyfile"; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done
echo; echo "== Cron entries"; ls /etc/cron.d/; crontab -l 2>/dev/null
echo; echo "== Old backup folder"; ls -la /tmp/egress_backup 2>/dev/null | head
echo; echo "== Live rooms right now (LiveKit log, last 10 min)"
docker compose logs --since 10m livekit 2>/dev/null | grep -ciE "participant joined|participant active" || true
