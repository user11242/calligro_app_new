# Recording safety net

A class recording must never silently disappear. This page explains how recordings are
protected, what each admin alert means, how to set up the Contabo server, and how to
test it all with a rehearsal.

Code: `functions/recording_safety.js` (cloud), its hooks in `functions/livekit.js`,
`recording_service/` (Contabo server). Tests: `functions/test/recording_safety.test.js`.

---

## 1. How a class is protected

| Layer | What it does | Protects against |
|---|---|---|
| **Live pieces** | The recorder writes the normal MP4 **and** the same video as 6-second pieces, uploaded to R2 **during** the class (`recording-segments/<course>/<time>/`) | The Contabo server or the recorder crashing mid-class (the MP4 only reaches R2 at the end) |
| **Verify, don't trust** | When the recorder says "finished", the server checks the MP4 is really in R2 | A "finished" report for a file that never arrived |
| **Recovery** | Any problem → the recording is hidden (never shown broken) and recovered: first the backed-up MP4, otherwise rebuilt from the pieces | Recorder failures, upload failures, crashes |
| **Backup folder (Contabo)** | If an upload to R2 fails, the recorder writes the file to `/opt/calligro-recordings/backup`; every 5 minutes it is uploaded to R2 at its normal path | Cloudflare R2 being unreachable |
| **Watchdog (every 15 min)** | Checks every recording the recorder never reported on, moves recoveries along, alerts if a scheduled class ended with no recording, deletes pieces 7 days after the lesson is safely stored | Lost reports, stuck recorders, classes nobody recorded |
| **Server self-check (every 5 min)** | Contabo reports: disk almost full, LiveKit/recorder down, backup not uploading | Problems on the server itself |
| **Fixed versions** | LiveKit, recorder and Redis versions are pinned in `.env` | Silent behaviour changes after a restart |

### What happens, case by case

| Case | What the system does | When the lesson is back |
|---|---|---|
| Normal class | MP4 verified in R2 → in the list; pieces deleted after 7 days | Minutes after the class |
| Teacher's phone crashes / call / network drop | Recorder finishes the file when the teacher is gone → verified → in the list | Minutes |
| Recorder's "finished" report never arrives | Watchdog asks LiveKit, finds the file, saves it | ≤ 25 min |
| Recorder fails mid-class | The part before the failure is rebuilt from its pieces; if the teacher is still teaching, a **new recorder starts at once** for the rest (the class shows as two recordings) | First part ≈ 45–75 min; rest after the class |
| Contabo recorder crashes or restarts | Watchdog finds the recorder gone → first part rebuilt from the pieces; new recorder for the rest if the class is still going (at most 3 automatic restarts an hour) | ≈ 45–75 min |
| Whole Contabo server goes down | Every class drops; when the teacher rejoins, a new recording starts. The part before the crash is rebuilt from its pieces | ≈ 45–75 min after the server is back |
| Upload to R2 fails at the end | File goes to the backup folder → uploaded within 5 min → recovery finds it | ≈ 20–45 min |
| Very long class too big to rebuild automatically (> 6 GB of pieces) | Pieces kept; admins told the exact command; the watchdog puts it back once rebuilt | After the manual step |
| Nothing exists at all | Admins told "Recording lost" with the reason | — |
| A scheduled class ended with no recording started | Admins told "Class not recorded" | 30–50 min after the class |

Still possible: if the teacher's phone has no internet, no video reaches the server for
that part (the rest is kept); if the teacher never turns on camera and mic, recording does
not start (admins are told).

---

## 2. Admin alerts — what to do

| Alert | Meaning | Action |
|---|---|---|
| **Recording recovered 🛟** | There was a problem; the lesson was recovered automatically (`backup`, `pieces` or `manual`) | None. Optionally watch it once |
| **Class not recorded ⚠️** | A scheduled class with students ended and no recording was started | Ask the teacher what happened (no camera/mic? class moved without rescheduling?) |
| **Recording lost ⚠️** | Nothing usable exists (reason included) | Tell the teacher/students; check the server log for that time |
| **Recording needs attention 🛠️** | The pieces are safe but must be joined by hand. The alert shows `<pieces folder> → <target file>` | On the Contabo server: `scripts/rebuild_recording.sh <pieces folder> <target file>`. The lesson returns within 15 min |
| **Recording server problem 🖥️** | Disk almost full / LiveKit or recorder down / backup not uploading | SSH to the server: `docker compose ps`, `df -h`, `tail -50 /var/log/calligro-safety.log` |

---

## 3. One-time setup

### A. Firebase (done from the repository)
Deploy the functions: `livekit` (start + webhook + reconcile) and `recordingSafety`
(`rebuildRecording`, `recordingWatchdog`, `recordingServerAlert`). The deploy prints the
URL of `recordingSafety-recordingServerAlert` — that is `ALERT_URL` below.

### B. Cloudflare R2 (dashboard)
Bucket `calligro-recordings` → Settings → **Object lifecycle rules** → add:
- Prefix `recording-segments/` → **delete objects 30 days after upload**.

The watchdog already deletes pieces after 7 days; this rule is only a last guard so
pieces can never pile up.

### C. Contabo server
The server keeps its own `config.yaml` and `livekit.yaml` (they hold the keys) and Caddy
(on the host, `/etc/caddy/Caddyfile`); the upgrade never touches them. Its backup setting
was already correct (`backup: prefix: "/opt/calligro-recordings/backup"`); the old
`sync_worker.py` cron job uploaded backups to `tmp/`, where nothing could find them, and is
replaced by `scripts/safety_check.sh`.

Do this **when no class is running** (LiveKit and the recorder restart for a few seconds).
From the project folder on your computer:

1. Copy the new files to the server (asks for the server password):
   ```bash
   COPYFILE_DISABLE=1 tar czf - -C recording_service docker-compose.yml deploy.sh README.md .env.example scripts | ssh root@194.163.184.20 "tar xzf - -C /opt/calligro-livekit"
   ```
2. Run the one-time upgrade (asks for the password, then for YES):
   ```bash
   ssh -t root@194.163.184.20 "cd /opt/calligro-livekit && chown -R root:root . && bash scripts/upgrade_server.sh"
   ```
   It keeps a full copy of the old setup, creates `.env` from the keys already on the
   server, switches off the old sync job, pins the versions and installs the 5-minute
   safety check.
3. Install the waiting Ubuntu updates and restart (classes come back by themselves):
   ```bash
   ssh -t root@194.163.184.20 "apt-get update && apt-get -y upgrade && reboot"
   ```
4. After about 2 minutes, check:
   ```bash
   ssh root@194.163.184.20 "cd /opt/calligro-livekit && docker compose ps && tail -20 /var/log/calligro-safety.log"
   ```

---

## 4. Rehearsal (do it once after setup, with a test course)

Use a test course with a test teacher and one test student.

1. **Normal class.** Teach 5 minutes from the app, end the class.
   - The recording appears in the app.
   - In R2, `recording-segments/<course>/<time>/` contains `seg_*.ts` pieces.
2. **Recorder crash.** Start a test class, wait 3 minutes, then on the server:
   `docker compose restart egress`. Continue 2 minutes, end the class.
   - Within about an hour: admin notice **Recording recovered (pieces)**, and the lesson
     (first ~3 minutes) plays in the app.
3. **Upload failure (backup).** Start a test class. On the server, block R2 for the
   recorder by adding the R2 host (from `R2_ENDPOINT`) to `/etc/hosts` as `127.0.0.1`.
   End the class after 2 minutes, wait 1 minute, then remove the line again.
   - `/opt/calligro-recordings/backup` contains the files, the next safety check uploads
     them (`/var/log/calligro-safety.log`), and the admins get **Recording recovered**.
   - If the backup folder stays empty, the recorder version handles upload failures
     differently — report it; the pieces still recover the lesson.
4. **Server alert.** `DISK_ALERT_PERCENT=1 ./scripts/safety_check.sh` → admins get
   **Recording server problem (disk)**.
5. **Missing class.** Schedule a test class with an enrolled test student and do not
   start it → 30–50 minutes after its end, admins get **Class not recorded**.

---

## 5. Limits worth knowing
- The rebuild joins pieces in the cloud (8 GB memory). Above ~6 GB of pieces (a very long
  1080p class) it asks for the manual script instead; the pieces are never deleted
  until the lesson is safely stored.
- A rebuilt lesson's length is counted from its pieces (±6 seconds).
- The 7-day piece clean-up only runs once the stored lesson is verified in R2; otherwise
  the pieces are kept.
