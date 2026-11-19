# Calligro live classes + recording server (Contabo)

This folder is what runs on the Contabo server (`194.163.184.20`):

| Container | Job |
|---|---|
| `livekit` | The live classes (video and sound between the teacher and students) |
| `egress` | The recorder: records the teacher and uploads to Cloudflare R2 |
| `redis` | Helper database for the two above |

Every class is recorded **twice at once**: the normal MP4 (uploaded when the class ends)
and 6-second pieces uploaded **during** the class. If anything fails, the cloud safety
net (`functions/recording_safety.js`) rebuilds the lesson from the pieces and alerts the
admins. If an upload to R2 fails, the recorder writes to the backup folder and
`scripts/safety_check.sh` uploads it every 5 minutes.

- **Install / update:** `bash deploy.sh` (after filling `.env` from `.env.example`)
- **Versions** are fixed in `.env`; change them on purpose, after a test class.
- **Everything else** (how it works, the server steps, the test drill, what each alert
  means): [`docs/RECORDING_SAFETY.md`](../docs/RECORDING_SAFETY.md)

Files: `docker-compose.yml`, `livekit.yaml` (LiveKit) and `config.yaml` (recorder) — these two
hold the LiveKit secret, live only on the server and are never committed; the repository has
`livekit.yaml.example` / `config.yaml.example` templates —
`scripts/safety_check.sh` (cron, every 5 min), `scripts/rebuild_recording.sh` (manual
rebuild, only when an alert asks for it).
