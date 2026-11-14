# Calligro Meet tests

Run everything before and after any change to Calligro Meet:

```bash
flutter test test/features/meet/
cd functions && npx jest test/livekit.test.js
```

Both suites also run in CI (`.github/workflows/calligro_tests.yml`) and block the
TestFlight / Google Play deploy jobs when they fail.

## How the meet code is organised (so it can be tested)

`calligro_meet_page.dart` is UI + LiveKit wiring only. Every **decision** lives in
`lib/features/meet/logic/` and is unit-tested:

| Code | What it decides | Tests |
|---|---|---|
| `logic/meet_protocol.dart` | data-message wire format (shared with the web portal), who counts as teacher/moderator | `meet_protocol_test.dart` |
| `logic/meet_message_handler.dart` | what to do with every incoming data message (end class, mute, kick, hands) and who is allowed to send it | `meet_message_handler_test.dart` |
| `logic/meet_policies.dart` | disconnect handling, when recording starts, camera on background/resume, who is on stage / PiP, grid columns | `meet_policies_test.dart` |
| `logic/meet_backend.dart` | every Cloud Function call: names, payloads, retries | `meet_backend_test.dart` |
| `teacher/services/livekit_meet_service.dart` | the join flow (loading → token → pre-join, errors, double-tap) | `livekit_meet_service_test.dart` (widget tests) |
| `controllers/connection_resilience_controller.dart` | relay retry + audio-only prompt | `connection_resilience_controller_test.dart` |
| the page itself | must keep delegating to the classes above; Flutter ↔ backend contract | `meet_guardrails_test.dart` |
| `functions/livekit.js` | tokens, moderation, recording, webhooks, uploads, playback | `functions/test/livekit.test.js` |

## Rules when you change Calligro Meet

1. **Put new decisions in `logic/`, not in the page**, and add a test there.
   `meet_guardrails_test.dart` fails if the page starts decoding messages,
   checking roles, hard-coding protocol strings or calling Cloud Functions itself.
2. **Changing a protocol string** (`MeetProtocol`) also requires changing the web
   portal (`web_portal/src/components/meet/`), which is not covered by these tests.
3. **Changing a Cloud Function name, action or field** fails the contract tests
   on purpose — update `meet_backend.dart`, `livekit.js` and both test files together.

## What these tests do NOT cover

- Real audio/video, rendering and layout pixels of the meet and pre-join pages.
- The real LiveKit server, Cloudflare R2 and Firebase (they are faked).
- The web portal's meet components.

For those, run a short real class before releases (teacher phone + student phone +
web student): join, raise hand, mute, kick (student can't rejoin), end for all,
then play the recording.
