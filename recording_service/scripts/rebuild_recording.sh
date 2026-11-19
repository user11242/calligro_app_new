#!/usr/bin/env bash
# ==============================================================================
# Manual rebuild of a recording from its live pieces (only needed when the admins
# get a "Recording needs attention" alert: the automatic rebuild could not do it,
# e.g. a very long class). The alert gives both arguments:
#
#   scripts/rebuild_recording.sh <pieces folder> <target file>
#   scripts/rebuild_recording.sh recording-segments/c1/1794672000000/ \
#                                courses/c1/recordings/recording-c1-1794672000000-rebuilt.mp4
#
# It downloads the pieces to this server's disk, joins them in order (no
# re-encoding), and uploads the result to <target file>. Within 15 minutes the
# watchdog sees it and puts the lesson back in the course's list.
# Needs: ffmpeg (apt-get install -y ffmpeg) and Docker.
# ==============================================================================
set -euo pipefail

if [[ $# -ne 2 ]]; then
  sed -n '2,17p' "$0"; exit 1
fi
PREFIX="${1%/}/"
TARGET="$2"
[[ "$PREFIX" == recording-segments/* ]] || { echo "The pieces folder must start with recording-segments/"; exit 1; }
[[ "$TARGET" == courses/*/recordings/*-rebuilt.mp4 ]] || { echo "The target must be courses/<id>/recordings/...-rebuilt.mp4"; exit 1; }
command -v ffmpeg >/dev/null || { echo "Install ffmpeg first: apt-get install -y ffmpeg"; exit 1; }

HERE="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$HERE/.env"; set +a
RCLONE_VERSION="${RCLONE_VERSION:-1.75.2}"

WORK=$(mktemp -d /var/tmp/calligro-rebuild.XXXXXX) # on disk, not RAM
trap 'rm -rf "$WORK"' EXIT

rclone() {
  docker run --rm --network host -v "$WORK:/work" \
    -e RCLONE_S3_PROVIDER=Cloudflare \
    -e RCLONE_S3_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
    -e RCLONE_S3_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    -e RCLONE_S3_ENDPOINT="$R2_ENDPOINT" \
    -e RCLONE_S3_NO_CHECK_BUCKET=true \
    "rclone/rclone:${RCLONE_VERSION}" "$@"
}

echo "Downloading pieces from $PREFIX …"
rclone copy ":s3:${R2_BUCKET}/${PREFIX}" /work/pieces --include "*.ts" --transfers 8
count=$(find "$WORK/pieces" -name '*.ts' | wc -l | tr -d ' ')
[[ "$count" -gt 0 ]] || { echo "No pieces found under $PREFIX"; exit 1; }
echo "$count pieces"

# Recording order = the number in the name (sort -V: seg_9 before seg_10).
find "$WORK/pieces" -name '*.ts' -printf '%f\n' | sort -V | sed "s|^|file '$WORK/pieces/|; s|$|'|" > "$WORK/list.txt"

echo "Joining …"
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$WORK/list.txt" \
  -c copy -bsf:a aac_adtstoasc -movflags +faststart "$WORK/lesson.mp4"
ls -lh "$WORK/lesson.mp4"

echo "Uploading to $TARGET …"
cp "$WORK/lesson.mp4" "$WORK/upload.mp4"
rclone copyto /work/upload.mp4 ":s3:${R2_BUCKET}/${TARGET}"
echo "Done. The lesson returns to the course's list within 15 minutes (the admins get a 'recovered' notice)."
