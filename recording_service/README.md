# 🎥 Calligro LiveKit Automated Recording Worker

This service is the dedicated, open-source recording engine for Calligro classes. It runs 24/7 on a simple $8–$10/month cloud server (Hetzner, DigitalOcean, AWS Lightsail), connects to your LiveKit rooms, encodes pristine 1080p MP4 videos, and deposits them directly into your Cloudflare R2 bucket (`calligro-recordings`).

---

## 🚀 1-Minute Quick Start on Any VPS

1. **Rent a $8/mo VPS** (e.g. Hetzner CPX22 or DigitalOcean 2 vCPU / 4GB RAM Ubuntu Server).
2. **SSH into your server:**
   ```bash
   ssh root@your-server-ip
   ```
3. **Copy this `recording_service` folder to your server:**
   ```bash
   mkdir -p /opt/calligro-recording
   cd /opt/calligro-recording
   ```
4. **Create your `.env` file:**
   ```bash
   nano .env
   ```
   Paste your LiveKit Cloud API Key/Secret and Cloudflare R2 credentials.
5. **Run the 1-click installer:**
   ```bash
   bash deploy.sh
   ```

---

## 🔒 Security & Anti-Piracy Features
- **App-Only Streaming:** Recorded sessions are streamed exclusively to enrolled students through the mobile application.
- **Anti-Screen Recording:** Mobile video playback automatically enables `SecurityService.enableScreenshotProtection()`, causing iOS and Android screen recorders or screenshot tools to capture a black screen.
- **Zero Bandwidth Costs:** Video delivery is routed through Cloudflare R2 with $0 bandwidth egress fees.
