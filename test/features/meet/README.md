# Calligro Meet — architecture & tests

Run before and after any change to Calligro Meet:

```bash
flutter test test/features/meet/
cd functions && npx jest test/livekit.test.js test/transcoder.test.js
```

Both run in CI (`.github/workflows/calligro_tests.yml`) and block the TestFlight /
Google Play deploy jobs when they fail.

## Layers (`lib/features/meet/`)

```
presentation  →  application  →  domain  ←  data
   (UI)          (state/flows)    (rules)    (LiveKit, Cloud Functions, device)
```

| Layer | Files | Job | May depend on |
|---|---|---|---|
| `domain/` | `meet_room.dart` (the `MeetRoom` interface + events), `meet_media.dart` (camera/mic + profile interfaces), `meet_participant.dart`, `meet_protocol.dart`, `meet_message_handler.dart`, `meet_policies.dart` | pure rules: protocol, who is trusted, what each message means, disconnects, recording rule, layout | nothing (pure Dart) |
| `application/` | `meet_controller.dart`, `recording_controller.dart`, `connection_quality_monitor.dart`, `pre_join_controller.dart` | pre-join choices + preview; runs one class: join/relay/rejoin, hands, moderation, leave/end, audio-only, background, recording | `domain`, `data` interfaces |
| `data/` | `livekit_meet_room.dart` (adapter), `livekit_media_devices.dart` (camera/mic/permissions), `firebase_profile_source.dart`, `meet_backend.dart` (Cloud Functions facade), `meet_platform.dart` (wakelock, orientation, background audio, sounds) | talks to the outside world | `domain` |
| `presentation/` | `pages/calligro_meet_page.dart`, `pages/calligro_pre_join_page.dart`, `widgets/*` | UI only: reads controller state, shows effects | everything above |

`meet_guardrails_test.dart` **enforces** these boundaries (e.g. the controller can't
import LiveKit, the UI can't call Cloud Functions or decode messages, protocol strings
live only in `MeetProtocol`).

## Tests (`test/features/meet/`)

| Folder | What it proves |
|---|---|
| `domain/` | wire format, sender trust (every spoofing attempt), what every message does, disconnect/recording/lifecycle/layout rules |
| `data/` | exact Cloud Function names, payloads, retries, response parsing; which LiveKit errors get a relay retry |
| `application/` | pre-join (permissions, preview, double taps, leaving mid-open, join settings) and the whole class flow through `FakeMeetRoom`: join, relay fallback, recording (once, retries, failure), rejoin with a fresh token, kicked/ended/network drops, teacher commands vs forged ones, hands, moderation, leave vs end-for-all, fail-safe stop, audio-only, background camera |
| `presentation/` | the REAL pre-join page (fake camera/permissions/profile) and the REAL meet page with a fake room/backend/device: what users see and tap (stage, grid, hands, REC, dialogs, participants sheet, closing, back gesture, rejoin, connect failure) + the join flow |
| `meet_guardrails_test.dart` | layer boundaries + contract with `functions/livekit.js` |
| `fakes/` | `FakeMeetRoom` (stateful room), `FakeMediaDevices` + `FakeProfileSource` (camera/mic/profile), `FakeFunctions` (Cloud Functions), `FakeMeetPlatform` (device) |

## How to change Calligro Meet (test-first)

1. **Write or adjust the test first** in the matching folder (it should fail).
2. Put the change in the right layer — rules in `domain/`, flow/state in `application/`,
   SDK/network in `data/`, pixels in `presentation/`.
3. Make the test pass; keep `flutter test test/features/meet/` green.
4. New outside dependency? Add an interface in `domain/` + a fake in `fakes/`.
5. Changing a protocol string (`MeetProtocol`) also requires the web portal
   (`web_portal/src/components/meet/`), which these tests don't cover.
6. Changing a Cloud Function name/action/field fails the contract tests on purpose —
   update `meet_backend.dart`, `functions/livekit.js` and both test suites together.

## Not covered (needs a real class)

Real audio/video and rendering, the real camera/permission prompts, the real LiveKit
server / R2 / Firebase, and the web portal. Before releases, run a short class with a teacher
phone, a student phone and a web student: join, raise hand, mute, kick (can't rejoin),
end for all, then play the recording.
