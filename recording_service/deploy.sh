#!/usr/bin/env bash
# ==============================================================================
# Calligro live classes + recording server (Contabo): install / update.
# Safe to run again. Full steps and the test drill: docs/RECORDING_SAFETY.md
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")"

echo "== Calligro recording server =="

if ! command -v docker >/dev/null; then
  echo "📦 Installing Docker…"
  curl -fsSL https://get.docker.com | sh
fi
command -v python3 >/dev/null || { echo "python3 is required (apt-get install -y python3)"; exit 1; }

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "⚠️  Created .env from .env.example — fill it in, then run this again."
  exit 1
fi
set -a; source ./.env; set +a
BACKUP_DIR="${BACKUP_DIR:-/opt/calligro-recordings/backup}"

if grep -q "backup_dir" config.yaml; then
  echo "❌ config.yaml still has the old 'storage: backup_dir:' (ignored by the recorder)."
  echo "   Replace it with the top-level 'backup:' section from the repository's config.yaml."
  exit 1
fi

echo "📁 Backup folder: $BACKUP_DIR (on disk, survives restarts)"
mkdir -p "$BACKUP_DIR"
chmod 0777 "$BACKUP_DIR" # the recorder container writes here as its own user

echo "🐳 Pulling the fixed versions: livekit ${LIVEKIT_SERVER_VERSION:-?}, egress ${EGRESS_VERSION:-?}, redis ${REDIS_VERSION:-?}"
docker compose pull
docker pull "rclone/rclone:${RCLONE_VERSION:-1.75.2}"
docker compose up -d

echo "⏱️  Installing the 5-minute safety check (cron)…"
cat > /etc/cron.d/calligro-safety <<CRON
SHELL=/bin/bash
*/5 * * * * root $(pwd)/scripts/safety_check.sh >> /var/log/calligro-safety.log 2>&1
CRON
chmod 0644 /etc/cron.d/calligro-safety

echo "🔎 First safety check now:"
./scripts/safety_check.sh || true

echo
docker compose ps
echo
echo "✅ Done. Logs: docker compose logs -f egress   |   Safety log: tail -f /var/log/calligro-safety.log"
