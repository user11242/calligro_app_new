#!/usr/bin/env bash
# ==============================================================================
# ONE-TIME move of the Contabo server to the recording safety net. Run ON the server
# (as root) from /opt/calligro-livekit, after the new files were copied there.
# Run it when NO class is running: LiveKit and the recorder restart (a few seconds).
#
# What it does:
#   1. keeps a full copy of the current setup (folder + crontab);
#   2. creates .env from the values the server already uses (config.yaml keys and the
#      old sync_worker.py's R2 keys) — nothing secret is printed;
#   3. switches off the old sync job (it uploaded backups to tmp/, where nothing could
#      find them); scripts/safety_check.sh replaces it;
#   4. runs deploy.sh: fixed versions, the safety check every 5 minutes.
# It never touches config.yaml, livekit.yaml or Caddy.
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
HERE="$(pwd)"
[[ "$HERE" == /opt/calligro-livekit ]] || { echo "Run me from /opt/calligro-livekit"; exit 1; }
[[ $(id -u) -eq 0 ]] || { echo "Run as root"; exit 1; }

echo "This restarts LiveKit and the recorder for a few seconds."
read -r -p "Is it a time with NO class running? Type YES to continue: " ok < /dev/tty
[[ "$ok" == "YES" ]] || { echo "Stopped, nothing changed."; exit 1; }

STAMP=$(date +%F-%H%M)
echo "1/4 Keeping a copy of the current setup → /opt/calligro-livekit.before-safety-$STAMP"
cp -a /opt/calligro-livekit "/opt/calligro-livekit.before-safety-$STAMP"
crontab -l > "/opt/calligro-livekit.before-safety-$STAMP/root-crontab.txt" 2>/dev/null || true

echo "2/4 Creating .env from the values already on this server"
if [[ ! -f .env ]]; then
  val_yaml() { grep -E "^$1:" config.yaml | head -1 | sed -E "s/^$1:[[:space:]]*\"?([^\"]*)\"?.*/\1/"; }
  val_py()   { grep -E "^$1[[:space:]]*=" /opt/calligro-recordings/sync_worker.py | head -1 | sed -E "s/^[^=]*=[[:space:]]*[\"']([^\"']*)[\"'].*/\1/"; }
  LK_KEY=$(val_yaml api_key); LK_SECRET=$(val_yaml api_secret)
  R2_ID=$(val_py R2_ACCESS_KEY); R2_SECRET=$(val_py R2_SECRET_KEY); R2_EP=$(val_py R2_ENDPOINT)
  for v in LK_KEY LK_SECRET R2_ID R2_SECRET R2_EP; do
    [[ -n "${!v}" ]] || { echo "Could not read $v from the current files — fill .env by hand from .env.example"; exit 1; }
  done
  umask 077
  sed -e "s|^LIVEKIT_API_KEY=.*|LIVEKIT_API_KEY=$LK_KEY|" \
      -e "s|^LIVEKIT_API_SECRET=.*|LIVEKIT_API_SECRET=$LK_SECRET|" \
      -e "s|^R2_ACCESS_KEY_ID=.*|R2_ACCESS_KEY_ID=$R2_ID|" \
      -e "s|^R2_SECRET_ACCESS_KEY=.*|R2_SECRET_ACCESS_KEY=$R2_SECRET|" \
      -e "s|^R2_ENDPOINT=.*|R2_ENDPOINT=$R2_EP|" .env.example > .env
  chmod 600 .env
  echo "   .env created (readable by root only)"
else
  echo "   .env already exists — kept as is"
fi

echo "3/4 Switching off the old sync job (replaced by scripts/safety_check.sh)"
if crontab -l 2>/dev/null | grep -q "sync_worker.py"; then
  # "|| true": when it was the only line, grep finds nothing left — that is not an error.
  { crontab -l | grep -v "sync_worker.py" || true; } | crontab -
  echo "   removed from root's crontab (a copy is in the backup above)"
else
  echo "   not in root's crontab (already off)"
fi
if [[ -f /opt/calligro-recordings/sync_worker.py ]]; then
  mv /opt/calligro-recordings/sync_worker.py /opt/calligro-recordings/sync_worker.py.disabled
fi

echo "4/4 Installing (fixed versions + safety check)"
bash ./deploy.sh

echo
echo "✅ Done. To undo: copy back /opt/calligro-livekit.before-safety-$STAMP and restore its root-crontab.txt"
