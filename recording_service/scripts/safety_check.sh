#!/usr/bin/env bash
# ==============================================================================
# Calligro recording server — safety check (cron, every 5 minutes).
#
#  1. Uploads anything the recorder put in the backup folder (an R2 upload failed)
#     to R2 at its normal path, so the cloud safety net can use it; deletes local
#     copies BACKUP_KEEP_DAYS after a successful upload.
#  2. Alerts the admins (via the recordingServerAlert function) when:
#       - the disk is almost full            (disk_low)
#       - LiveKit or the recorder is down    (recorder_down)
#       - backed-up files cannot be uploaded (backup_waiting)
#     The function sends each problem at most once per hour.
#
# Install: see docs/RECORDING_SAFETY.md (deploy.sh installs the cron entry).
# ==============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
TEST_DISK_ALERT_PERCENT="${DISK_ALERT_PERCENT:-}" # a value given on the command line wins (alert test)
set -a
# shellcheck disable=SC1091
source ./.env
set +a
[[ -n "$TEST_DISK_ALERT_PERCENT" ]] && DISK_ALERT_PERCENT="$TEST_DISK_ALERT_PERCENT"

BACKUP_DIR="${BACKUP_DIR:-/opt/calligro-recordings/backup}"
DISK_ALERT_PERCENT="${DISK_ALERT_PERCENT:-85}"
BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
RCLONE_VERSION="${RCLONE_VERSION:-1.75.2}"

# One run at a time (a slow upload must not overlap the next run).
exec 9>/var/lock/calligro-safety.lock
flock -n 9 || { echo "$(date -Is) previous run still busy"; exit 0; }

log() { echo "$(date -Is) $*"; }

# Signed report → recordingServerAlert (HMAC-SHA256 with the LiveKit API secret,
# computed in Python so the secret never appears in the process list).
alert() {
  local kind="$1" detail="$2"
  local body
  body=$(KIND="$kind" DETAIL="$detail" python3 -c 'import json,os,time; print(json.dumps({"kind":os.environ["KIND"],"detail":os.environ["DETAIL"],"at":int(time.time())}), end="")')
  local sig
  sig=$(BODY="$body" python3 -c 'import hmac,hashlib,os; print(hmac.new(os.environ["LIVEKIT_API_SECRET"].encode(), os.environ["BODY"].encode(), hashlib.sha256).hexdigest(), end="")')
  if curl -fsS -m 20 -X POST -H "Content-Type: application/json" -H "X-Calligro-Signature: $sig" \
       --data "$body" "$ALERT_URL" >/dev/null; then
    log "ALERT sent: $kind — $detail"
  else
    log "ALERT FAILED to send: $kind — $detail"
  fi
}

# ── 1. Disk space ────────────────────────────────────────────────────────────
for mount in / "$BACKUP_DIR"; do
  used=$(df -P "$mount" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
  if [[ -n "${used:-}" && "$used" -ge "$DISK_ALERT_PERCENT" ]]; then
    alert disk_low "$mount is ${used}% full"
  fi
done

# ── 2. LiveKit and the recorder are running ──────────────────────────────────
running=$(docker compose ps --status running --services 2>/dev/null || true)
for svc in livekit egress redis; do
  if ! grep -qx "$svc" <<<"$running"; then
    alert recorder_down "$svc is not running (docker compose ps)"
  fi
done

# ── 3. Upload backed-up files to R2 ──────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
waiting=$(find "$BACKUP_DIR" -type f | wc -l | tr -d ' ')
if [[ "$waiting" -gt 0 ]]; then
  log "$waiting backed-up file(s) found, uploading to R2"
  # --min-age: never upload a file the recorder may still be writing.
  if docker run --rm --network host \
       -v "$BACKUP_DIR:/backup:ro" \
       -e RCLONE_S3_PROVIDER=Cloudflare \
       -e RCLONE_S3_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
       -e RCLONE_S3_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
       -e RCLONE_S3_ENDPOINT="$R2_ENDPOINT" \
       -e RCLONE_S3_NO_CHECK_BUCKET=true \
       "rclone/rclone:${RCLONE_VERSION}" \
       copy /backup ":s3:${R2_BUCKET}" --min-age 2m --retries 3 --log-level NOTICE; then
    log "backup upload OK"
    # Uploaded successfully: local copies are a spare for BACKUP_KEEP_DAYS, then removed.
    find "$BACKUP_DIR" -type f -mtime +"$BACKUP_KEEP_DAYS" -print -delete
    find "$BACKUP_DIR" -mindepth 1 -type d -empty -delete
  else
    oldest=$(find "$BACKUP_DIR" -type f -printf '%T@\n' | sort -n | head -1 | cut -d. -f1)
    age_min=$(( ( $(date +%s) - ${oldest:-$(date +%s)} ) / 60 ))
    alert backup_waiting "$waiting file(s) not uploaded, oldest ${age_min} min old"
  fi
fi

# Keep this log small.
LOG=/var/log/calligro-safety.log
if [[ -f "$LOG" && $(stat -c %s "$LOG") -gt 10485760 ]]; then
  tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
