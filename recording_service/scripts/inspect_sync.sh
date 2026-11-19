#!/usr/bin/env bash
# Read-only: what the existing backup sync on the server does. Secrets masked.
D=/opt/calligro-recordings
echo "== $D"; ls -la "$D"
echo; echo "== backup folder (files, newest first)"; find "$D/backup" -type f -printf '%TY-%Tm-%Td %TH:%TM  %10s  %P\n' 2>/dev/null | sort -r | head -20
echo "files in backup: $(find "$D/backup" -type f 2>/dev/null | wc -l)"
echo; echo "== sync_worker.py (secret-looking values masked)"
sed -E "s/((key|secret|token|password|passwd)[A-Za-z_]*[\"']?[[:space:]]*[:=][[:space:]]*)[\"'][^\"']+[\"']/\1'<hidden>'/I" "$D/sync_worker.py"
echo; echo "== other files"; for f in "$D"/*; do [ -f "$f" ] && [ "$f" != "$D/sync_worker.py" ] && echo "-- $f ($(wc -l < "$f") lines)"; done
echo; echo "== last 30 lines of /var/log/calligro_sync.log"; tail -30 /var/log/calligro_sync.log 2>/dev/null
echo; echo "== python packages"; python3 -c "import boto3; print('boto3', boto3.__version__)" 2>&1
