/**
 * The recording safety net (functions/recording_safety.js + its hooks in livekit.js).
 *
 * REAL: recording_safety.js, livekit.js, schedule.js, temp files, HMAC signatures.
 * FAKE (stateful, path-accurate): Firestore, the LiveKit server (rooms + recorders),
 *   R2 (object key → size), the Cloud Tasks queue, ffmpeg, admin notifications.
 *
 * Every scenario ends by asserting what a student would see: a playable recording
 * in the course's list — or, when nothing can be saved, an admin who was told.
 */
const fs = require("fs");
const crypto = require("crypto");
const { FakeFirestore, Timestamp } = require("./helpers/fakeFirestore");
const { FakeLiveKitServer, EgressStatus } = require("./helpers/fakeLiveKit");

const mockState = {
  db: null, lk: null, r2: new Map(), puts: [], deletes: [], enqueued: [], queueNames: [],
  spawns: [], concatLists: [], rawConcatLists: [], ffmpegFail: false, alerts: [],
};

const mockSecrets = {
  LIVEKIT_API_KEY: "devkey",
  LIVEKIT_API_SECRET: "test_secret_that_is_long_enough_123456",
  CLOUDFLARE_R2_ACCESS_KEY: "r2-access",
  CLOUDFLARE_R2_SECRET_KEY: "r2-secret",
  CLOUDFLARE_R2_ENDPOINT: "https://r2.example.com",
  CLOUDFLARE_R2_PUBLIC_URL: "https://cdn.example.com/",
};

jest.mock("firebase-admin", () => {
  const helpers = require("./helpers/fakeFirestore");
  const firestore = () => mockState.db;
  firestore.FieldValue = { serverTimestamp: () => helpers.SERVER_TIMESTAMP };
  firestore.Timestamp = helpers.Timestamp;
  return { firestore };
});
jest.mock("firebase-admin/functions", () => ({
  getFunctions: () => ({
    taskQueue: (name) => {
      mockState.queueNames.push(name);
      return { enqueue: async (data) => { mockState.enqueued.push(data); } };
    },
  }),
}));
jest.mock("../notifications.js", () => ({
  notifyAdmins: jest.fn(async (alert) => { mockState.alerts.push(alert); return 1; }),
}));
jest.mock("firebase-functions/params", () => ({
  defineSecret: (name) => ({ name, value: () => mockSecrets[name] }),
}));
function mockWrap(opts, handler) { const fn = (...a) => handler(...a); fn.__options = opts; return fn; }
jest.mock("firebase-functions/v2/https", () => ({
  HttpsError: jest.requireActual("firebase-functions/v2/https").HttpsError,
  onCall: mockWrap,
  onRequest: mockWrap,
}));
jest.mock("firebase-functions/v2/scheduler", () => ({ onSchedule: mockWrap }));
jest.mock("firebase-functions/v2/tasks", () => ({ onTaskDispatched: mockWrap }));
jest.mock("livekit-server-sdk", () => {
  const actual = jest.requireActual("livekit-server-sdk");
  return {
    AccessToken: actual.AccessToken,
    WebhookReceiver: actual.WebhookReceiver,
    TrackSource: actual.TrackSource,
    EncodingOptionsPreset: actual.EncodingOptionsPreset,
    RoomServiceClient: function RoomServiceClient() { return mockState.lk; },
    EgressClient: function EgressClient() { return mockState.lk; },
  };
});
jest.mock("@aws-sdk/client-s3", () => {
  class Command { constructor(input) { this.input = input; } }
  class PutObjectCommand extends Command {}
  class GetObjectCommand extends Command {}
  class HeadObjectCommand extends Command {}
  class ListObjectsV2Command extends Command {}
  class DeleteObjectCommand extends Command {}
  class S3Client {
    async send(cmd) {
      const key = cmd.input.Key;
      if (cmd instanceof HeadObjectCommand) {
        if (!mockState.r2.has(key)) { const e = new Error("NotFound"); e.name = "NotFound"; throw e; }
        return { ContentLength: mockState.r2.get(key) };
      }
      if (cmd instanceof PutObjectCommand) {
        let bytes = 0;
        for await (const chunk of cmd.input.Body) bytes += chunk.length;
        mockState.puts.push({ key, type: cmd.input.ContentType, bodyPath: cmd.input.Body.path, bytes });
        mockState.r2.set(key, bytes);
        return {};
      }
      if (cmd instanceof ListObjectsV2Command) {
        // Two pages, like real R2 with many objects.
        const all = [...mockState.r2.keys()].filter((k) => k.startsWith(cmd.input.Prefix)).sort();
        const start = cmd.input.ContinuationToken ? Number(cmd.input.ContinuationToken) : 0;
        const page = all.slice(start, start + 3);
        const more = start + 3 < all.length;
        return {
          Contents: page.map((Key) => ({ Key, Size: mockState.r2.get(Key) })),
          IsTruncated: more,
          NextContinuationToken: more ? String(start + 3) : undefined,
        };
      }
      if (cmd instanceof DeleteObjectCommand) {
        mockState.deletes.push(key);
        mockState.r2.delete(key);
        return {};
      }
      throw new Error(`unexpected S3 command ${cmd.constructor.name}`);
    }
  }
  return { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand, ListObjectsV2Command, DeleteObjectCommand };
});
jest.mock("@aws-sdk/s3-request-presigner", () => ({
  getSignedUrl: async (client, cmd) => `https://signed.example/${cmd.input.Key}`,
}));
jest.mock("ffmpeg-static", () => "/fake/ffmpeg");
jest.mock("child_process", () => ({
  spawn: (cmd, args) => {
    // ffmpeg is only ever given local relay addresses; map them back to what they forward to.
    const { relayTargetOf } = require("../media.js");
    const realOf = (text) => text.replace(/http:\/\/127\.0\.0\.1:\d+\/\d+\/media\.\w+/g, (u) => relayTargetOf(u) || `UNRELAYED ${u}`);
    mockState.spawns.push({ cmd, args });
    const { EventEmitter: MockEmitter } = require("events");
    const proc = new MockEmitter();
    proc.stderr = new MockEmitter();
    setImmediate(() => {
      const fsm = require("fs");
      if (args.includes("concat")) {
        const raw = fsm.readFileSync(args[args.indexOf("-i") + 1], "utf8");
        mockState.rawConcatLists.push(raw);
        mockState.concatLists.push(realOf(raw));
      }
      if (mockState.ffmpegFail) {
        proc.stderr.emit("data", Buffer.from("Invalid data found when processing input"));
        proc.emit("close", 1);
      } else {
        fsm.writeFileSync(args[args.length - 1], "x".repeat(4096)); // a real (if tiny) file
        proc.emit("close", 0);
      }
    });
    return proc;
  },
}));

const safety = require("../recording_safety.js");
const lk = require("../livekit.js");
const H = safety.helpers;

// ─────────────────────────────────────────────────────────────────────────────
const NOW = Date.UTC(2026, 10, 14, 18, 0, 0);
const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
let now;

const ROOM = `CG_${crypto.createHash("sha256").update("Calligro_SecureSalt2026_c1").digest("hex").substring(0, 40)}`;
const EG = "EG_1";
const STARTED = NOW - 2 * HOUR;
const MP4 = `courses/c1/recordings/recording-c1-${STARTED}.mp4`;
const PREFIX = `recording-segments/c1/${STARTED}/`;
const ns = (ms) => String(BigInt(ms) * 1000000n);

/** A recording exactly as startAutomatedRecording stores it (safety net on). */
function seedRecording(extra = {}) {
  const payload = {
    sessionId: `c1_${STARTED}`, egressId: EG, roomName: ROOM, r2FilePath: MP4,
    startedAt: Timestamp.fromMillis(STARTED), teacherId: "T1", courseId: "c1", status: "active",
    safetyNet: true, segmentsPrefix: PREFIX, ...extra,
  };
  mockState.db.seed(`courses/c1/activeSessions/c1_${STARTED}`, payload);
  mockState.db.seed(`activeRecordings/${EG}`, payload);
  mockState.db.seed(`activeRooms/${ROOM}`, payload);
  return payload;
}
/** n live pieces of ~2 MB, uploaded during the class. */
function seedPieces(n, size = 2_000_000) {
  for (let i = 0; i < n; i++) mockState.r2.set(`${PREFIX}seg_${String(i).padStart(5, "0")}.ts`, size);
  mockState.r2.set(`${PREFIX}index.m3u8`, 900);
}
const egressDoc = () => mockState.db.get(`activeRecordings/${EG}`);
const recordingDoc = () => mockState.db.get(`courses/c1/recordings/${EG}`);
const watchdog = () => safety.recordingWatchdog({});
const rebuildTask = (retryCount = 0) => safety.rebuildRecording({ data: { egressId: EG }, retryCount });
const alertKinds = () => mockState.alerts.map((a) => a.type);

beforeEach(() => {
  now = NOW;
  jest.spyOn(Date, "now").mockImplementation(() => now);
  mockState.db = new FakeFirestore();
  mockState.lk = new FakeLiveKitServer();
  mockState.r2 = new Map();
  Object.assign(mockState, { puts: [], deletes: [], enqueued: [], queueNames: [], spawns: [], concatLists: [], rawConcatLists: [], ffmpegFail: false, alerts: [] });
  mockState.db.seed("users/T1", { name: "Teacher", role: "teacher" });
  mockState.db.seed("users/s1", { name: "Student", role: "student" });
  mockState.db.seed("courses/c1", { title: "Thuluth Basics", teacherId: "T1", enrolledStudents: ["s1"] });
  jest.spyOn(console, "log").mockImplementation(() => {});
  jest.spyOn(console, "warn").mockImplementation(() => {});
  jest.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(() => jest.restoreAllMocks());

// ═════════════════════════════════════════════════════════════════════════════
describe("helpers", () => {
  test("pieces are named and ordered by number, not text (seg_10 after seg_9)", () => {
    expect(H.segmentIndex("x/seg_00012.ts")).toBe(12);
    expect(H.segmentIndex("x/seg_7.ts")).toBe(7);
    expect(H.segmentIndex("x/index.m3u8")).toBe(-1);
    expect(H.segmentsPrefixFor("c1", 123)).toBe("recording-segments/c1/123/");
    expect(H.rebuiltPathFor({ r2FilePath: "courses/c1/recordings/recording-c1-5.mp4" })).toBe("courses/c1/recordings/recording-c1-5-rebuilt.mp4");
  });
  test("LiveKit nanosecond times", () => {
    expect(H.nanosToMs(ns(NOW))).toBe(NOW);
    expect(H.nanosToMs("0")).toBeNull();
    expect(H.nanosToMs(undefined)).toBeNull();
    expect(H.fileDurationSeconds({ fileResults: [{ duration: "2712000000000" }] })).toBe(2712);
    expect(H.fileDurationSeconds({})).toBe(0);
  });
  test("resource settings", () => {
    expect(safety.recordingWatchdog.__options.schedule).toBe("every 5 minutes");
    expect(safety.recordingWatchdog.__options.maxInstances).toBe(1);
    const r = safety.rebuildRecording.__options;
    expect(r.timeoutSeconds).toBe(1800); // the Cloud Tasks maximum
    expect(parseInt(r.memory, 10)).toBeGreaterThanOrEqual(8); // a long class is joined in RAM
    expect(r.cpu * r.maxInstances).toBeLessThanOrEqual(4); // leaves CPU quota for the converter
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("watchdog: recordings the recorder never reported on", () => {
  test("a recording started less than 20 minutes ago and still recording is left alone", async () => {
    seedRecording({ startedAt: Timestamp.fromMillis(NOW - 10 * MIN) });
    mockState.lk.addEgress(ROOM, EgressStatus.ACTIVE, EG);
    const before = mockState.db.writes.length;
    await watchdog();
    expect(mockState.db.writes.length).toBe(before);
    expect(mockState.lk.callsTo("stopEgress")).toEqual([]);
  });

  test("a recording started less than 20 minutes ago that already ended is left to its report", async () => {
    seedRecording({ startedAt: Timestamp.fromMillis(NOW - 10 * MIN) });
    await watchdog();
    expect(egressDoc().status).toBe("active");
  });

  describe("the recorder was KILLED (rehearsal Test 2): LiveKit still lists it as active", () => {
    const killedAt = (minutesAgo) => {
      seedRecording({ startedAt: Timestamp.fromMillis(NOW - minutesAgo * MIN) });
      mockState.lk.addEgress(ROOM, EgressStatus.ACTIVE, EG);
      mockState.lk.crashEgress(EG, NOW - minutesAgo * MIN);
    };

    test("class still going → recovery of the first part AND a new recorder for the rest", async () => {
      killedAt(8); // well inside the first 20 minutes: a crash is not waited out
      mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
      await watchdog();
      expect(egressDoc()).toMatchObject({ status: "recovering", recovery: { state: "checking", reason: "recorder_lost" } });
      expect(mockState.lk.callsTo("stopEgress")).toEqual([["stopEgress", EG]]); // LiveKit's stale entry tidied
      const fresh = mockState.lk.egresses.find((e) => e.kind === "participant");
      expect(fresh).toBeDefined();
      expect(mockState.db.get(`activeRecordings/${fresh.egressId}`)).toMatchObject({ status: "active", safetyNet: true });
    });

    test("class already over → recovery only", async () => {
      killedAt(30);
      await watchdog();
      expect(egressDoc().status).toBe("recovering");
      expect(mockState.lk.callsTo("startParticipantEgress")).toEqual([]);
    });

    test("a recorder that started under 2 minutes ago may not have joined yet: left alone", async () => {
      killedAt(1);
      await watchdog();
      expect(egressDoc().status).toBe("active");
      expect(mockState.lk.callsTo("stopEgress")).toEqual([]);
    });

    test("if LiveKit cannot list the room, the recorder is assumed alive (never stop a working one)", async () => {
      killedAt(30);
      mockState.lk.failAlways.listParticipants = new Error("timeout");
      await watchdog();
      expect(egressDoc().status).toBe("active");
      expect(mockState.lk.callsTo("stopEgress")).toEqual([]);
    });

    test("the room is gone (everyone left) → dead", async () => {
      killedAt(30);
      mockState.lk.rooms.delete(ROOM);
      mockState.lk.failAlways.listParticipants = Object.assign(new Error("requested room does not exist"), { code: "not_found" });
      await watchdog();
      expect(egressDoc().status).toBe("recovering");
    });

    test("a LIVE recorder (in the room) with storage unreachable is NOT treated as dead (rehearsal Test 3)", async () => {
      seedRecording({ startedAt: Timestamp.fromMillis(NOW - 30 * MIN) });
      mockState.lk.addEgress(ROOM, EgressStatus.ACTIVE, EG); // no pieces arriving, but it is in the room
      await watchdog();
      expect(egressDoc().status).toBe("active");
      expect(mockState.lk.callsTo("stopEgress")).toEqual([]);
    });
  });

  test("a class still recording after 2 hours is left alone", async () => {
    seedRecording();
    mockState.lk.addEgress(ROOM, EgressStatus.ACTIVE, EG);
    const before = mockState.db.writes.length;
    await watchdog();
    expect(mockState.db.writes.length).toBe(before);
    expect(mockState.lk.callsTo("stopEgress")).toEqual([]);
  });

  test("a recorder still running after 8 hours is stuck: it is stopped (its report then saves the file)", async () => {
    seedRecording({ startedAt: Timestamp.fromMillis(NOW - 9 * HOUR) });
    mockState.lk.addEgress(ROOM, EgressStatus.ACTIVE, EG);
    await watchdog();
    expect(mockState.lk.callsTo("stopEgress")).toEqual([["stopEgress", EG]]);
  });

  test("finished 5 minutes ago: its report may still arrive, so it waits", async () => {
    seedRecording();
    Object.assign(mockState.lk.addEgress(ROOM, EgressStatus.COMPLETE, EG), { endedAt: ns(NOW - 5 * MIN) });
    mockState.r2.set(MP4, 800_000_000);
    await watchdog();
    expect(egressDoc().status).toBe("active");
    expect(recordingDoc()).toBeUndefined();
  });

  test("finished 30 minutes ago, report never came, file is in R2 → saved with its exact length", async () => {
    seedRecording();
    Object.assign(mockState.lk.addEgress(ROOM, EgressStatus.COMPLETE, EG), {
      endedAt: ns(NOW - 30 * MIN), fileResults: [{ duration: "5400000000000" }],
    });
    mockState.r2.set(MP4, 800_000_000);
    await watchdog();
    expect(recordingDoc()).toMatchObject({ status: "ready", r2FilePath: MP4, duration: 5400 });
    expect(egressDoc()).toMatchObject({ status: "completed", segmentsCleanup: "pending", storedAtMs: NOW });
    expect(mockState.db.get(`courses/c1/activeSessions/c1_${STARTED}`).status).toBe("completed");
  });

  test.each([
    ["the recorder vanished (e.g. the Contabo server restarted)", () => {}, "recorder_lost"],
    ["the recorder failed", () => Object.assign(mockState.lk.addEgress(ROOM, EgressStatus.FAILED, EG), { endedAt: ns(NOW - HOUR) }), "recorder_failed"],
    ["it 'finished' but the file never reached R2", () => Object.assign(mockState.lk.addEgress(ROOM, EgressStatus.COMPLETE, EG), { endedAt: ns(NOW - HOUR) }), "file_missing"],
  ])("%s → recovery starts and the broken recording is hidden", async (_, setup, reason) => {
    seedRecording();
    mockState.db.seed(`courses/c1/recordings/${EG}`, { egressId: EG, r2FilePath: MP4, videoUrl: "x" }); // written by stop_recording
    setup();
    await watchdog();
    expect(egressDoc()).toMatchObject({ status: "recovering", recovery: { state: "checking", reason, since: NOW } });
    expect(recordingDoc()).toMatchObject({ status: "failed", recoveryStatus: "checking" });
    expect(mockState.db.get(`activeRooms/${ROOM}`).status).toBe("recovering");
    expect(mockState.db.get(`courses/c1/activeSessions/c1_${STARTED}`).status).toBe("recovering");
  });

  test("the recorder vanished but the class is still going → the rest is recorded by a new recorder", async () => {
    seedRecording();
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    await watchdog();
    expect(egressDoc().status).toBe("recovering"); // the first part comes back from its pieces
    const started = mockState.lk.callsTo("startParticipantEgress");
    expect(started).toHaveLength(1);
    const newId = mockState.lk.egresses.find((e) => e.kind === "participant").egressId;
    expect(mockState.db.get(`activeRecordings/${newId}`)).toMatchObject({ status: "active", safetyNet: true });
  });

  test("LiveKit unreachable → nothing changes (next run tries again)", async () => {
    seedRecording();
    mockState.lk.failNext.listEgress = new Error("connect ECONNREFUSED");
    await watchdog();
    expect(egressDoc().status).toBe("active");
  });

  test("older recordings (before the safety net) are not touched", async () => {
    seedRecording({ safetyNet: undefined });
    mockState.db.seed(`activeRecordings/${EG}`, { ...egressDoc(), safetyNet: false });
    await watchdog();
    expect(mockState.lk.callsTo("listEgress")).toEqual([]);
  });

  test("one broken record never stops the others from being checked", async () => {
    mockState.db.seed("activeRecordings/EG_bad", { safetyNet: true, status: "active", courseId: "c1", startedAt: Timestamp.fromMillis(STARTED) });
    mockState.db.failWritesTo = /EG_bad/; // checked first, and every write for it fails
    seedRecording();
    mockState.r2.set(MP4, 800_000_000);
    Object.assign(mockState.lk.addEgress(ROOM, EgressStatus.COMPLETE, EG), { endedAt: ns(NOW - HOUR) });
    await watchdog();
    expect(recordingDoc()).toMatchObject({ status: "ready" });
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("recovery", () => {
  const recovering = (recovery) => seedRecording({ status: "recovering", recovery: { state: "checking", reason: "recorder_failed", since: NOW - 10 * MIN, ...recovery } });

  test("the MP4 arrives from the Contabo backup → back in the list, marked as recovered", async () => {
    recovering();
    mockState.db.seed(`courses/c1/recordings/${EG}`, { egressId: EG, status: "failed", recoveryStatus: "checking", r2FilePath: MP4 });
    mockState.r2.set(MP4, 700_000_000);
    await watchdog();
    expect(recordingDoc()).toMatchObject({ status: "ready", recovered: true, recoveredFrom: "backup", recoveryStatus: "recovered", r2FilePath: MP4 });
    expect(egressDoc()).toMatchObject({ status: "completed", recovery: { state: "recovered" } });
    expect(mockState.alerts).toEqual([expect.objectContaining({
      type: "recording_recovered", key: `rec_recovered_${EG}`,
      params: { courseName: "Thuluth Basics", time: "2026-11-14 16:00 UTC", detail: "backup" },
      payload: { courseId: "c1" },
    })]);
  });

  test("within 30 minutes and no MP4 yet → keeps waiting for the backup", async () => {
    recovering();
    seedPieces(10);
    await watchdog();
    expect(egressDoc().recovery.state).toBe("checking");
    expect(mockState.enqueued).toEqual([]);
  });

  test("after 30 minutes with pieces in R2 → rebuild queued", async () => {
    recovering({ since: NOW - 31 * MIN });
    seedPieces(7);
    await watchdog();
    expect(mockState.queueNames).toEqual(["locations/us-central1/functions/recordingSafety-rebuildRecording"]);
    expect(mockState.enqueued).toEqual([{ egressId: EG }]);
    expect(egressDoc()).toMatchObject({ status: "recovering", recovery: { state: "rebuilding", rebuildQueuedAt: NOW, segments: 7 } });
  });

  test("after 30 minutes with nothing anywhere → lost, admins told why", async () => {
    recovering({ since: NOW - 31 * MIN });
    await watchdog();
    expect(egressDoc()).toMatchObject({ status: "lost", recovery: { state: "lost" } });
    expect(mockState.db.get(`courses/c1/activeSessions/c1_${STARTED}`).status).toBe("failed");
    expect(mockState.alerts).toEqual([expect.objectContaining({ type: "recording_lost", params: expect.objectContaining({ detail: "recorder_failed" }) })]);
  });

  test("too big to rebuild automatically → kept safe for a manual rebuild, admins told where", async () => {
    recovering({ since: NOW - 31 * MIN });
    seedPieces(4, 2 * 1024 * 1024 * 1024); // 8 GB
    await watchdog();
    expect(egressDoc()).toMatchObject({ status: "needs_manual", recovery: { state: "manual" } });
    expect(mockState.enqueued).toEqual([]);
    const target = `courses/c1/recordings/recording-c1-${STARTED}-rebuilt.mp4`;
    expect(mockState.alerts[0]).toMatchObject({ type: "recording_manual", params: { detail: `${PREFIX} (4) → ${target}` } });
    expect(mockState.r2.has(`${PREFIX}seg_00000.ts`)).toBe(true); // nothing deleted

    // Next run: not rebuilt yet → still waiting, no new alert.
    await watchdog();
    expect(alertKinds()).toEqual(["recording_manual"]);

    // Someone runs scripts/rebuild_recording.sh, which uploads the lesson to the target → back in the list.
    mockState.r2.set(target, 3_000_000_000);
    await watchdog();
    expect(recordingDoc()).toMatchObject({ status: "ready", r2FilePath: target, recoveredFrom: "manual", duration: 24 });
    expect(egressDoc()).toMatchObject({ status: "completed", recovery: { state: "recovered" } });
    expect(alertKinds()).toEqual(["recording_manual", "recording_recovered"]);
  });

  test("a rebuild unfinished after 3 hours is reported once", async () => {
    recovering({ state: "rebuilding", rebuildQueuedAt: NOW - 4 * HOUR });
    await watchdog();
    await watchdog();
    expect(alertKinds()).toEqual(["recording_manual"]);
    expect(egressDoc().recovery.stuckAlerted).toBe(true);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("rebuildRecording (joins the live pieces into the lesson)", () => {
  beforeEach(() => {
    seedRecording({ status: "recovering", recovery: { state: "rebuilding", rebuildQueuedAt: NOW, reason: "recorder_lost" } });
  });

  test("joins every piece in recording order, stores the lesson, students see it again", async () => {
    seedPieces(12);
    await rebuildTask();
    const lines = mockState.concatLists[0].trim().split("\n");
    expect(lines).toHaveLength(12); // the playlist is not a piece
    expect(lines[0]).toBe(`file 'https://signed.example/${PREFIX}seg_00000.ts'`);
    expect(lines[11]).toBe(`file 'https://signed.example/${PREFIX}seg_00011.ts'`);
    expect(mockState.rawConcatLists[0]).not.toContain("https://"); // only relay addresses reach ffmpeg
    const join = mockState.spawns[0].args;
    expect(join).toEqual(expect.arrayContaining(["-c", "copy", "+faststart"]));

    const rebuilt = `courses/c1/recordings/recording-c1-${STARTED}-rebuilt.mp4`;
    expect(mockState.puts).toEqual([expect.objectContaining({ key: rebuilt, type: "video/mp4" })]);
    expect(fs.existsSync(mockState.puts[0].bodyPath)).toBe(false); // temp file removed
    expect(recordingDoc()).toMatchObject({
      status: "ready", r2FilePath: rebuilt, duration: 12 * 6, recovered: true, recoveredFrom: "pieces",
      videoUrl: `https://cdn.example.com/${rebuilt}`,
    });
    expect(egressDoc()).toMatchObject({ status: "completed", recovery: { state: "recovered" }, segmentsCleanup: "pending" });
    expect(mockState.db.get(`courses/c1/activeSessions/c1_${STARTED}`).status).toBe("recovered");
    expect(alertKinds()).toEqual(["recording_recovered"]);

    // A student plays the rebuilt lesson through the normal signed link.
    const { playbackUrl } = await lk.getRecordingPlaybackUrl({ auth: { uid: "s1" }, data: { courseId: "c1", recordingId: EG } });
    expect(playbackUrl).toBe(`https://signed.example/${rebuilt}`);
  });

  test("pieces numbered past 99999 still join in order", async () => {
    for (const i of [2, 100000, 10, 1]) mockState.r2.set(`${PREFIX}seg_${i}.ts`, 10);
    await rebuildTask();
    const order = mockState.concatLists[0].trim().split("\n").map((l) => Number(/seg_(\d+)/.exec(l)[1]));
    expect(order).toEqual([1, 2, 10, 100000]);
  });

  test("a task for a recording not being rebuilt does nothing", async () => {
    mockState.db.seed(`activeRecordings/${EG}`, { ...egressDoc(), status: "completed", recovery: { state: "recovered" } });
    seedPieces(3);
    await rebuildTask();
    expect(mockState.spawns).toEqual([]);
  });

  test("ffmpeg fails → retried; on the last attempt it is kept for a manual rebuild and admins are told", async () => {
    seedPieces(3);
    mockState.ffmpegFail = true;
    await expect(rebuildTask(0)).rejects.toThrow("ffmpeg exited with code 1");
    expect(egressDoc().recovery.state).toBe("rebuilding");
    await expect(rebuildTask(2)).resolves.toBeUndefined();
    expect(egressDoc()).toMatchObject({ status: "needs_manual", recovery: { state: "manual" } });
    expect(alertKinds()).toEqual(["recording_manual"]);
    expect(recordingDoc()).toBeUndefined(); // never shown broken
  });

  test("invalid payload is dropped", async () => {
    await expect(safety.rebuildRecording({ data: {} })).resolves.toBeUndefined();
    expect(mockState.spawns).toEqual([]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("piece clean-up (7 days after the lesson is safely stored)", () => {
  function stored(daysAgo, { fileInR2 = true, status = "ready" } = {}) {
    seedRecording({ status: "completed", segmentsCleanup: "pending", storedAtMs: NOW - daysAgo * DAY });
    mockState.db.seed(`courses/c1/recordings/${EG}`, { status, r2FilePath: MP4 });
    if (fileInR2) mockState.r2.set(MP4, 800_000_000);
    seedPieces(5);
  }

  test("after 7 days, with the lesson verified in R2 → every piece and playlist deleted", async () => {
    stored(8);
    await watchdog();
    expect(mockState.deletes.sort()).toEqual([
      `${PREFIX}index.m3u8`, ...[0, 1, 2, 3, 4].map((i) => `${PREFIX}seg_0000${i}.ts`),
    ]);
    expect(egressDoc()).toMatchObject({ segmentsCleanup: "done", segmentsDeleted: 6 });
    expect(mockState.r2.has(MP4)).toBe(true);
  });

  test("before 7 days → kept", async () => {
    stored(3);
    await watchdog();
    expect(mockState.deletes).toEqual([]);
    expect(egressDoc().segmentsCleanup).toBe("pending");
  });

  test.each([
    ["the lesson file is missing from R2", { fileInR2: false }],
    ["the lesson is not ready", { status: "failed" }],
  ])("%s → pieces are KEPT (they may be the only copy)", async (_, opts) => {
    stored(8, opts);
    await watchdog();
    expect(mockState.deletes).toEqual([]);
    expect(egressDoc().segmentsCleanup).toBe("kept_unverified");
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("a scheduled class that ended with no recording → admins told", () => {
  const ts = (ms) => Timestamp.fromMillis(ms);
  const weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][new Date(NOW).getUTCDay()];
  // Today's class 16:30–17:20 UTC ended 40 minutes before "now" (18:00): its join window
  // (until 30 min after the end) closed 10 minutes ago, so this run checks it.
  function course(extra = {}) {
    mockState.db.seed("courses/c1", {
      title: "Thuluth Basics", teacherId: "T1", enrolledStudents: ["s1"], selectedDays: [weekday],
      startDate: ts(NOW - 10 * DAY), endDate: ts(NOW + 30 * DAY),
      startTime: ts(Date.UTC(2026, 0, 1, 16, 30)), endTime: ts(Date.UTC(2026, 0, 1, 17, 20)),
      scheduleUtcOffsetMinutes: 0, ...extra,
    });
  }

  test("no recording started for today's class → one alert with the class time", async () => {
    course();
    await watchdog();
    expect(mockState.alerts).toEqual([expect.objectContaining({
      type: "recording_missing", key: `rec_missing_c1_${Date.UTC(2026, 10, 14, 16, 30)}`,
      params: expect.objectContaining({ courseName: "Thuluth Basics", time: "2026-11-14 16:30 UTC" }),
    })]);
  });

  test("a recording started during the class → no alert", async () => {
    course();
    mockState.db.seed("courses/c1/activeSessions/c1_x", { startedAt: ts(Date.UTC(2026, 10, 14, 16, 33)) });
    await watchdog();
    expect(mockState.alerts).toEqual([]);
  });

  test("a recording from ANOTHER day does not count", async () => {
    course();
    mockState.db.seed("courses/c1/activeSessions/c1_old", { startedAt: ts(Date.UTC(2026, 10, 7, 16, 33)) });
    await watchdog();
    expect(alertKinds()).toEqual(["recording_missing"]);
  });

  test("no students enrolled → no alert (no class took place)", async () => {
    course({ enrolledStudents: [] });
    await watchdog();
    expect(mockState.alerts).toEqual([]);
  });

  test("a class whose join window closed long ago is not re-reported", async () => {
    course();
    now = NOW + 2 * HOUR;
    await watchdog();
    expect(mockState.alerts).toEqual([]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("recordingServerAlert (the Contabo server reports its own problems)", () => {
  const sign = (body) => crypto.createHmac("sha256", mockSecrets.LIVEKIT_API_SECRET).update(body).digest("hex");
  async function post(payload, { signature, method = "POST" } = {}) {
    const raw = typeof payload === "string" ? payload : JSON.stringify(payload);
    const res = { statusCode: 0, status(c) { this.statusCode = c; return this; }, send() { return this; } };
    await safety.recordingServerAlert({
      method, rawBody: Buffer.from(raw), headers: { "x-calligro-signature": signature ?? sign(raw) },
    }, res);
    return res.statusCode;
  }
  const at = () => Math.floor(now / 1000);

  test("a signed report reaches every admin, at most once per hour per problem", async () => {
    expect(await post({ kind: "disk_low", detail: "/ is 91% full", at: at() })).toBe(200);
    expect(mockState.alerts).toEqual([{
      key: `rec_server_disk_low_${Math.floor(NOW / HOUR)}`, type: "recording_server",
      titleKey: "recording_server_title", bodyKey: "recording_server_disk_low_body",
      params: { detail: "/ is 91% full" }, payload: {},
    }]);
  });

  test.each([
    ["wrong signature", { kind: "disk_low", at: Math.floor(NOW / 1000) }, { signature: "0".repeat(64) }, 401],
    ["no signature", { kind: "disk_low", at: Math.floor(NOW / 1000) }, { signature: "" }, 401],
    ["an old (replayed) report", { kind: "disk_low", at: Math.floor((NOW - HOUR) / 1000) }, {}, 400],
    ["an unknown problem", { kind: "format_disk", at: Math.floor(NOW / 1000) }, {}, 400],
    ["not JSON", "hello", {}, 400],
    ["GET", { kind: "disk_low", at: Math.floor(NOW / 1000) }, { method: "GET" }, 405],
  ])("refused: %s", async (_, payload, opts, code) => {
    expect(await post(payload, opts)).toBe(code);
    expect(mockState.alerts).toEqual([]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("end to end: the Contabo server crashes in the middle of a class", () => {
  test("pieces uploaded during the class become the lesson; students can watch it", async () => {
    // The teacher's app starts recording at 16:00.
    now = STARTED;
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    const { egressId } = await lk.startAutomatedRecording({
      auth: { uid: "T1" }, data: { courseId: "c1", audioTrackId: "a", videoTrackId: "v", orientation: "landscape" },
    });
    const egress = mockState.lk.egresses.find((e) => e.egressId === egressId);
    egress.status = EgressStatus.ACTIVE;
    const session = mockState.db.get(`activeRecordings/${egressId}`);
    expect(session).toMatchObject({ safetyNet: true, segmentsPrefix: PREFIX });

    // 50 minutes of pieces reach R2 (6 s each); then the server dies: the MP4 never uploads,
    // no "finished" report ever arrives, and the restarted server has no record of the recorder.
    for (let i = 0; i < 500; i++) mockState.r2.set(`${PREFIX}seg_${String(i).padStart(5, "0")}.ts`, 2_000_000);
    mockState.lk.egresses = [];

    // Next watchdog run: it asks LiveKit about the recording; the recorder is gone → recovery.
    now = STARTED + 55 * MIN;
    await watchdog();
    expect(mockState.db.get(`activeRecordings/${egressId}`)).toMatchObject({ status: "recovering", recovery: { state: "checking", reason: "recorder_lost" } });

    // Nothing arrives from the backup within 30 minutes → rebuild from the pieces.
    now += 31 * MIN;
    await watchdog();
    expect(mockState.enqueued).toEqual([{ egressId }]);
    await safety.rebuildRecording({ data: { egressId }, retryCount: 0 });

    const rec = mockState.db.get(`courses/c1/recordings/${egressId}`);
    expect(rec).toMatchObject({ status: "ready", duration: 3000, recoveredFrom: "pieces" });
    const { playbackUrl } = await lk.getRecordingPlaybackUrl({ auth: { uid: "s1" }, data: { courseId: "c1", recordingId: egressId } });
    expect(playbackUrl).toContain("-rebuilt.mp4");
    expect(alertKinds()).toEqual(["recording_recovered"]);

    // A week later the pieces are cleaned up — only after the lesson is confirmed in R2.
    now += 8 * DAY;
    await watchdog();
    expect(mockState.r2.has(`${PREFIX}seg_00000.ts`)).toBe(false);
    expect(mockState.r2.has(rec.r2FilePath)).toBe(true);
  });
});
