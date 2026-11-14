/**
 * Calligro Meet — Cloud Functions test suite (functions/livekit.js)
 *
 * What is REAL here:
 *   - livekit.js itself (every exported function)
 *   - LiveKit JWT signing (AccessToken) and verification (TokenVerifier)
 *   - LiveKit webhook signature checking (WebhookReceiver) — requests are signed
 *     exactly like the LiveKit server signs them
 *
 * What is FAKE (but stateful and path-accurate):
 *   - Firestore            → test/helpers/fakeFirestore.js
 *   - LiveKit room/egress  → test/helpers/fakeLiveKit.js
 *   - Cloudflare R2 (S3)   → in-memory object sizes + deterministic signed URLs
 *
 * Every test asserts the exact documents written / server state reached.
 */
const crypto = require("crypto");
const { AccessToken, TokenVerifier } = jest.requireActual("livekit-server-sdk");
const { FakeFirestore, Timestamp } = require("./helpers/fakeFirestore");
const { FakeLiveKitServer, EgressStatus, TrackType } = require("./helpers/fakeLiveKit");

// ─────────────────────────────────────────────────────────────────────────────
// Module mocks (names must start with "mock" for jest hoisting)
// ─────────────────────────────────────────────────────────────────────────────
const mockState = {
  db: null,
  lk: null,
  r2: new Map(), // object key -> size in bytes
  delays: [],
  s3Configs: [],
  lkClients: [],
};

const mockSecrets = {
  LIVEKIT_API_KEY: "devkey",
  LIVEKIT_API_SECRET: "test_secret_that_is_long_enough_123456",
  CLOUDFLARE_R2_ACCESS_KEY: "r2-access",
  CLOUDFLARE_R2_SECRET_KEY: "r2-secret",
  CLOUDFLARE_R2_ENDPOINT: "https://r2.example.com",
  CLOUDFLARE_R2_PUBLIC_URL: "https://cdn.example.com/", // trailing slash on purpose
};

jest.mock("firebase-admin", () => {
  const helpers = require("./helpers/fakeFirestore");
  const firestore = () => mockState.db;
  firestore.FieldValue = { serverTimestamp: () => helpers.SERVER_TIMESTAMP };
  firestore.Timestamp = helpers.Timestamp;
  return { firestore };
});

jest.mock("firebase-functions/params", () => ({
  defineSecret: (name) => ({ name, value: () => mockSecrets[name] }),
}));

jest.mock("firebase-functions/v2/https", () => {
  const actual = jest.requireActual("firebase-functions/v2/https");
  const wrap = (opts, handler) => {
    const fn = (...args) => handler(...args);
    fn.__options = opts;
    return fn;
  };
  return { HttpsError: actual.HttpsError, onCall: wrap, onRequest: wrap };
});

jest.mock("livekit-server-sdk", () => {
  const actual = jest.requireActual("livekit-server-sdk");
  return {
    AccessToken: actual.AccessToken,
    WebhookReceiver: actual.WebhookReceiver,
    TrackSource: actual.TrackSource,
    EncodingOptionsPreset: actual.EncodingOptionsPreset,
    RoomServiceClient: function RoomServiceClient(url, key, secret) {
      mockState.lkClients.push({ kind: "room", url, key, secret });
      return mockState.lk;
    },
    EgressClient: function EgressClient(url, key, secret) {
      mockState.lkClients.push({ kind: "egress", url, key, secret });
      return mockState.lk;
    },
  };
});

jest.mock("@aws-sdk/client-s3", () => {
  class Command { constructor(input) { this.input = input; } }
  class PutObjectCommand extends Command {}
  class GetObjectCommand extends Command {}
  class HeadObjectCommand extends Command {}
  class S3Client {
    constructor(config) { mockState.s3Configs.push(config); }
    async send(cmd) {
      if (cmd instanceof HeadObjectCommand) {
        if (!mockState.r2.has(cmd.input.Key)) {
          const err = new Error("NotFound");
          err.name = "NotFound";
          throw err;
        }
        return { ContentLength: mockState.r2.get(cmd.input.Key) };
      }
      throw new Error(`unexpected S3 command ${cmd.constructor.name}`);
    }
  }
  return { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand };
});

jest.mock("@aws-sdk/s3-request-presigner", () => ({
  getSignedUrl: jest.fn(async (client, cmd, opts) =>
    `https://signed.example/${cmd.constructor.name}/${cmd.input.Bucket}/${cmd.input.Key}` +
    `?ct=${cmd.input.ContentType || ""}&exp=${opts.expiresIn}`),
}));

const lk = require("../livekit.js");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
const NOW = Date.UTC(2026, 10, 14, 18, 0, 0); // fixed "now"
const HOUR = 3600 * 1000;
let now;

const roomOf = (courseId) =>
  `CG_${crypto.createHash("sha256").update(`Calligro_SecureSalt2026_${courseId}`).digest("hex").substring(0, 40)}`;
const ROOM = roomOf("c1");
const call = (fn, uid, data = {}) => fn({ auth: uid ? { uid } : null, data });

async function expectHttpsError(promise, code, messagePart) {
  let error;
  try { await promise; } catch (e) { error = e; }
  expect(error).toBeDefined();
  expect(error.code).toBe(code);
  if (messagePart) expect(error.message).toContain(messagePart);
}

async function verifyToken(jwt) {
  return new TokenVerifier(mockSecrets.LIVEKIT_API_KEY, mockSecrets.LIVEKIT_API_SECRET).verify(jwt);
}

/** Builds a webhook request signed exactly like the LiveKit server does. */
async function signedWebhook(event, { secret = mockSecrets.LIVEKIT_API_SECRET, tamper } = {}) {
  const body = JSON.stringify(event);
  const at = new AccessToken(mockSecrets.LIVEKIT_API_KEY, secret);
  at.sha256 = crypto.createHash("sha256").update(body).digest("base64");
  const jwt = await at.toJwt();
  const sent = tamper ? tamper(body) : body;
  return { rawBody: Buffer.from(sent), headers: { authorization: jwt } };
}

async function runWebhook(req) {
  const res = {
    statusCode: null, body: null,
    status(code) { this.statusCode = code; return this; },
    send(body) { this.body = body; return this; },
  };
  await lk.livekitWebhook(req, res);
  return res;
}

function seedWorld(db) {
  db.seed("users/T1", { name: "Teacher One", role: "teacher", photoUrl: "https://img.example/t1.png" });
  db.seed("users/s1", { name: "Student One", role: "student" });
  db.seed("users/s2", { name: "Student Two", role: "student", photoURL: "https://img.example/s2.png" });
  db.seed("users/admin1", { name: "Platform Admin", role: "admin" });
  db.seed("users/outsider", { name: "Not Enrolled", role: "student" });
  db.seed("courses/c1", { teacherId: "T1", enrolledStudents: ["s1", "s2"] });
  db.seed("courses/c2", { teacherId: "T2", enrolledStudents: ["outsider"] });
}

/** Seeds a running recording exactly as startAutomatedRecording stores it. */
function seedActiveRecording({ egressId = "EG_live", startedAt = NOW - 30 * 60 * 1000, filePath, sessionId } = {}) {
  const r2FilePath = filePath || `courses/c1/recordings/recording-c1-${startedAt}.mp4`;
  const sid = sessionId || `c1_${startedAt}`;
  const payload = {
    sessionId: sid, egressId, roomName: ROOM, r2FilePath,
    startedAt: Timestamp.fromMillis(startedAt), teacherId: "T1", courseId: "c1", status: "active",
  };
  mockState.db.seed(`courses/c1/activeSessions/${sid}`, payload);
  mockState.db.seed(`activeRecordings/${egressId}`, payload);
  mockState.db.seed(`activeRooms/${ROOM}`, payload);
  mockState.lk.addEgress(ROOM, EgressStatus.ACTIVE, egressId);
  return { egressId, r2FilePath, sessionId: sid, startedAt };
}

beforeEach(() => {
  now = NOW;
  jest.spyOn(Date, "now").mockImplementation(() => now);
  mockState.db = new FakeFirestore();
  mockState.lk = new FakeLiveKitServer();
  mockState.r2 = new Map();
  mockState.delays = [];
  mockState.s3Configs = [];
  mockState.lkClients = [];
  getSignedUrl.mockClear();
  seedWorld(mockState.db);
  global.setTimeout = (cb, ms) => { mockState.delays.push(ms); cb(); return 0; };
  jest.spyOn(console, "log").mockImplementation(() => {});
  jest.spyOn(console, "warn").mockImplementation(() => {});
  jest.spyOn(console, "error").mockImplementation(() => {});
});

const realSetTimeout = setTimeout;
afterEach(() => {
  global.setTimeout = realSetTimeout;
  jest.restoreAllMocks();
});

// ═════════════════════════════════════════════════════════════════════════════
describe("generateLiveKitToken", () => {
  const token = (uid, data) => call(lk.generateLiveKitToken, uid, { courseId: "c1", ...data });

  test("is configured to handle a whole class joining at once", () => {
    const o = lk.generateLiveKitToken.__options;
    expect(o.cpu).toBeGreaterThanOrEqual(1); // fractional CPU forces concurrency 1
    expect(o.concurrency).toBeGreaterThanOrEqual(40);
    expect(o.maxInstances).toBeGreaterThanOrEqual(10);
  });

  describe("access control", () => {
    test("unauthenticated → unauthenticated", async () => {
      await expectHttpsError(call(lk.generateLiveKitToken, null, { courseId: "c1" }), "unauthenticated");
    });
    test("missing courseId → invalid-argument", async () => {
      await expectHttpsError(call(lk.generateLiveKitToken, "s1", {}), "invalid-argument");
    });
    test("unknown course → not-found", async () => {
      await expectHttpsError(call(lk.generateLiveKitToken, "s1", { courseId: "nope" }), "not-found");
    });
    test("a student not enrolled in THIS course is refused", async () => {
      await expectHttpsError(token("outsider"), "permission-denied", "not enrolled");
    });
    test("the teacher of ANOTHER course is refused", async () => {
      mockState.db.seed("users/T2", { name: "Other Teacher", role: "teacher" });
      await expectHttpsError(token("T2"), "permission-denied");
    });
    test("a course without enrolledStudents refuses students instead of crashing", async () => {
      mockState.db.seed("courses/c3", { teacherId: "T1" });
      await expectHttpsError(call(lk.generateLiveKitToken, "s1", { courseId: "c3" }), "permission-denied");
    });
  });

  describe("student token", () => {
    test("is a valid signed LiveKit JWT with locked-down permissions", async () => {
      const res = await token("s1", { source: "mobile" });
      const claims = await verifyToken(res.token); // throws if the signature is wrong

      expect(claims.sub).toBe("s1");
      expect(claims.name).toBe("Student One");
      expect(claims.exp - claims.nbf).toBe(4 * 3600);
      expect(claims.video).toEqual({
        roomJoin: true,
        room: ROOM,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        roomAdmin: false,
        canUpdateOwnMetadata: false,
        canPublishSources: ["camera", "microphone"],
      });
      expect(JSON.parse(claims.metadata)).toEqual({ role: "participant", teacherId: "T1", uid: "s1", avatar: null });
    });

    test.each([["web"], ["mobile"], [undefined], ["anything"]])(
      "cannot screen-share or edit metadata whatever source the client claims (%s)",
      async (source) => {
        const claims = await verifyToken((await token("s1", { source })).token);
        expect(claims.video.canPublishSources).toEqual(["camera", "microphone"]);
        expect(claims.video.canUpdateOwnMetadata).toBe(false);
        expect(claims.video.roomAdmin).toBe(false);
        expect(claims.sub).toBe("s1"); // students never get the _mobile suffix
      });

    test("avatar comes from photoUrl or photoURL", async () => {
      const claims = await verifyToken((await token("s2")).token);
      expect(JSON.parse(claims.metadata).avatar).toBe("https://img.example/s2.png");
    });

    test("an enrolled user without a profile document still joins", async () => {
      mockState.db.seed("courses/c1", { teacherId: "T1", enrolledStudents: ["ghost"] });
      const claims = await verifyToken((await token("ghost")).token);
      expect(claims.sub).toBe("ghost");
      expect(claims.name).toBe("Unknown User");
    });
  });

  describe("teacher / admin token", () => {
    test("teacher on mobile → identity T1_mobile, room admin, moderator metadata, may screen-share", async () => {
      const claims = await verifyToken((await token("T1", { source: "mobile" })).token);
      expect(claims.sub).toBe("T1_mobile");
      expect(claims.video.roomAdmin).toBe(true);
      expect(claims.video.canPublishSources).toBeUndefined();
      expect(claims.video.canUpdateOwnMetadata).toBe(false);
      expect(JSON.parse(claims.metadata)).toEqual({
        role: "moderator", teacherId: "T1", uid: "T1", avatar: "https://img.example/t1.png",
      });
    });

    test("teacher on web → identity T1 (so both devices can be in the room)", async () => {
      expect((await verifyToken((await token("T1", { source: "web" })).token)).sub).toBe("T1");
      expect((await verifyToken((await token("T1")).token)).sub).toBe("T1");
    });

    test("platform admin may join any course as a moderator (no _mobile suffix)", async () => {
      const claims = await verifyToken((await token("admin1", { source: "mobile" })).token);
      expect(claims.sub).toBe("admin1");
      expect(claims.video.roomAdmin).toBe(true);
      expect(JSON.parse(claims.metadata).role).toBe("moderator");
    });
  });

  describe("response", () => {
    test("returns the server URL, room and teacherId the app needs", async () => {
      const res = await token("s1");
      expect(res).toEqual({ token: expect.any(String), roomName: ROOM, serverUrl: "wss://194.163.184.20.nip.io", teacherId: "T1" });
    });

    test("room names are deterministic per course, different across courses and do not leak the courseId", async () => {
      const a = (await token("s1")).roomName;
      const b = (await token("s2")).roomName;
      const other = (await call(lk.generateLiveKitToken, "outsider", { courseId: "c2" })).roomName;
      expect(a).toBe(b);
      expect(a).not.toBe(other);
      expect(a).toMatch(/^CG_[0-9a-f]{40}$/);
      expect(a).not.toContain("c1");
    });

    test("records which course the room belongs to (attendance works without recording)", async () => {
      await token("s1");
      expect(mockState.db.get(`activeRooms/${ROOM}`)).toEqual({ courseId: "c1", roomName: ROOM });
    });

    test("the room mapping never overwrites an active recording's state", async () => {
      const rec = seedActiveRecording();
      await token("s1");
      const room = mockState.db.get(`activeRooms/${ROOM}`);
      expect(room.status).toBe("active");
      expect(room.egressId).toBe(rec.egressId);
    });

    test("failing to write the room mapping does not block joining", async () => {
      mockState.db.failWritesTo = /^activeRooms\//;
      await expect(token("s1")).resolves.toHaveProperty("token");
    });
  });

  describe("kick block", () => {
    const blockPath = `activeRooms/${ROOM}/blockedParticipants/s1`;

    test("a kicked student cannot get a token while the block is active", async () => {
      mockState.db.seed(blockPath, { expiresAt: Timestamp.fromMillis(NOW + HOUR) });
      await expectHttpsError(token("s1"), "permission-denied", "removed from this classroom");
    });

    test("the block expires (it must not lock the student out of future classes)", async () => {
      mockState.db.seed(blockPath, { expiresAt: Timestamp.fromMillis(NOW - 1) });
      await expect(token("s1")).resolves.toHaveProperty("token");
    });

    test("a block without expiresAt (legacy) is treated as expired", async () => {
      mockState.db.seed(blockPath, { reason: "kicked_by_teacher" });
      await expect(token("s1")).resolves.toHaveProperty("token");
    });

    test("the block only affects the kicked student", async () => {
      mockState.db.seed(blockPath, { expiresAt: Timestamp.fromMillis(NOW + HOUR) });
      await expect(token("s2")).resolves.toHaveProperty("token");
    });

    test("the teacher and admins are never blocked", async () => {
      mockState.db.seed(`activeRooms/${ROOM}/blockedParticipants/T1`, { expiresAt: Timestamp.fromMillis(NOW + HOUR) });
      mockState.db.seed(`activeRooms/${ROOM}/blockedParticipants/admin1`, { expiresAt: Timestamp.fromMillis(NOW + HOUR) });
      await expect(token("T1")).resolves.toHaveProperty("token");
      await expect(token("admin1")).resolves.toHaveProperty("token");
    });
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("moderateParticipant", () => {
  const moderate = (uid, data) => call(lk.moderateParticipant, uid, { courseId: "c1", ...data });

  beforeEach(() => {
    const L = mockState.lk;
    L.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    L.addParticipant(ROOM, { identity: "admin1", role: "moderator" });
    L.addParticipant(ROOM, { identity: "s1" });
    L.addParticipant(ROOM, { identity: "s2" });
  });

  describe("access control", () => {
    test("unauthenticated", async () => {
      await expectHttpsError(call(lk.moderateParticipant, null, { courseId: "c1", action: "kick" }), "unauthenticated");
    });
    test("courseId and action are required", async () => {
      await expectHttpsError(call(lk.moderateParticipant, "T1", { action: "kick" }), "invalid-argument");
      await expectHttpsError(call(lk.moderateParticipant, "T1", { courseId: "c1" }), "invalid-argument");
    });
    test("unknown course", async () => {
      await expectHttpsError(call(lk.moderateParticipant, "T1", { courseId: "nope", action: "kick" }), "not-found");
    });
    test.each(["s1", "admin1", "T2", "outsider"])("%s is not this course's teacher → refused, nothing happens", async (uid) => {
      for (const action of ["kick", "mute_mic", "mute_camera", "mute_all", "stop_recording", "end_room"]) {
        await expectHttpsError(moderate(uid, { action, targetIdentity: "s2" }), "permission-denied");
      }
      expect(mockState.lk.calls).toEqual([]);
      expect(mockState.db.writes).toEqual([]);
    });
    test("unknown action", async () => {
      await expectHttpsError(moderate("T1", { action: "ban_forever", targetIdentity: "s1" }), "invalid-argument", "Unknown action");
    });
    test.each(["mute_mic", "mute_camera", "kick"])("%s without targetIdentity", async (action) => {
      await expectHttpsError(moderate("T1", { action }), "invalid-argument", "targetIdentity");
    });
  });

  describe("mute", () => {
    test("mute_mic mutes ONLY the target's microphone", async () => {
      await expect(moderate("T1", { action: "mute_mic", targetIdentity: "s1" })).resolves.toEqual({ success: true, action: "muted_mic" });
      const L = mockState.lk;
      expect(L.participant(ROOM, "s1").tracks).toEqual([
        { sid: "s1_mic", type: TrackType.AUDIO, muted: true },
        { sid: "s1_cam", type: TrackType.VIDEO, muted: false },
      ]);
      expect(L.participant(ROOM, "s2").tracks.every((t) => !t.muted)).toBe(true);
    });

    test("mute_camera mutes ONLY the target's camera", async () => {
      await expect(moderate("T1", { action: "mute_camera", targetIdentity: "s1" })).resolves.toEqual({ success: true, action: "muted_camera" });
      expect(mockState.lk.participant(ROOM, "s1").tracks.map((t) => t.muted)).toEqual([false, true]);
    });

    test("muting someone with no published mic is a no-op success", async () => {
      mockState.lk.addParticipant(ROOM, { identity: "s3", tracks: [] });
      await expect(moderate("T1", { action: "mute_mic", targetIdentity: "s3" })).resolves.toEqual({ success: true, action: "muted_mic" });
      expect(mockState.lk.callsTo("mutePublishedTrack")).toEqual([]);
    });

    test.each(["T1_mobile", "admin1"])("a moderator (%s) can never be muted or kicked", async (id) => {
      for (const action of ["mute_mic", "mute_camera", "kick"]) {
        await expectHttpsError(moderate("T1", { action, targetIdentity: id }), "permission-denied", "Moderators cannot");
      }
      expect(mockState.lk.participant(ROOM, id)).toBeDefined();
      expect(mockState.lk.participant(ROOM, id).tracks.every((t) => !t.muted)).toBe(true);
      expect(mockState.db.paths(`activeRooms/${ROOM}/blockedParticipants`)).toEqual([]);
    });

    test("target not in the room → internal error, nothing changes", async () => {
      await expectHttpsError(moderate("T1", { action: "mute_mic", targetIdentity: "ghost" }), "internal");
      await expectHttpsError(moderate("T1", { action: "kick", targetIdentity: "ghost" }), "internal");
      expect(mockState.db.writes).toEqual([]);
    });
  });

  describe("mute_all", () => {
    test("mutes every student's live mic, never a moderator's, never cameras", async () => {
      mockState.lk.participant(ROOM, "s2").tracks[0].muted = true; // already muted
      const res = await moderate("T1", { action: "mute_all" });
      expect(res).toEqual({ success: true, action: "muted_all", count: 1 });
      const L = mockState.lk;
      expect(L.participant(ROOM, "s1").tracks.map((t) => t.muted)).toEqual([true, false]);
      expect(L.participant(ROOM, "T1_mobile").tracks.every((t) => !t.muted)).toBe(true);
      expect(L.participant(ROOM, "admin1").tracks.every((t) => !t.muted)).toBe(true);
      expect(L.callsTo("mutePublishedTrack")).toEqual([["mutePublishedTrack", ROOM, "s1", "s1_mic", true]]);
    });

    test("empty room → count 0", async () => {
      mockState.lk.rooms.clear();
      await expect(moderate("T1", { action: "mute_all" })).resolves.toEqual({ success: true, action: "muted_all", count: 0 });
    });

    test("LiveKit failure → internal error", async () => {
      mockState.lk.failNext.listParticipants = new Error("down");
      await expectHttpsError(moderate("T1", { action: "mute_all" }), "internal", "Failed to mute");
    });
  });

  describe("kick", () => {
    const blockPath = (uid) => `activeRooms/${ROOM}/blockedParticipants/${uid}`;

    test("removes the student and blocks them for exactly 4 hours", async () => {
      await expect(moderate("T1", { action: "kick", targetIdentity: "s1" })).resolves.toEqual({ success: true, action: "kicked" });
      expect(mockState.lk.participant(ROOM, "s1")).toBeUndefined();
      expect(mockState.lk.participant(ROOM, "s2")).toBeDefined();
      const block = mockState.db.get(blockPath("s1"));
      expect(block.reason).toBe("kicked_by_teacher");
      expect(block.expiresAt.toMillis()).toBe(NOW + 4 * HOUR);
      expect(block.blockedAt.toMillis()).toBe(NOW);
    });

    test("the block is written BEFORE removal (no window to grab a fresh token)", async () => {
      const L = mockState.lk;
      const original = L.removeParticipant.bind(L);
      let blockedAtRemoval = null;
      L.removeParticipant = async (room, id) => {
        blockedAtRemoval = mockState.db.has(blockPath("s1"));
        return original(room, id);
      };
      await moderate("T1", { action: "kick", targetIdentity: "s1" });
      expect(blockedAtRemoval).toBe(true);
    });

    test("if the block cannot be saved, the student is NOT removed (fail closed)", async () => {
      mockState.db.failWritesTo = /blockedParticipants/;
      await expectHttpsError(moderate("T1", { action: "kick", targetIdentity: "s1" }), "internal");
      expect(mockState.lk.participant(ROOM, "s1")).toBeDefined();
    });

    test("kicked student cannot rejoin, other students can, and after 4h the kicked one can again", async () => {
      await moderate("T1", { action: "kick", targetIdentity: "s1" });
      await expectHttpsError(call(lk.generateLiveKitToken, "s1", { courseId: "c1" }), "permission-denied");
      await expect(call(lk.generateLiveKitToken, "s2", { courseId: "c1" })).resolves.toHaveProperty("token");
      now = NOW + 4 * HOUR + 1;
      await expect(call(lk.generateLiveKitToken, "s1", { courseId: "c1" })).resolves.toHaveProperty("token");
    });

    test("a *_mobile identity is blocked under the bare uid", async () => {
      mockState.lk.addParticipant(ROOM, { identity: "s9_mobile" });
      await moderate("T1", { action: "kick", targetIdentity: "s9_mobile" });
      expect(mockState.db.has(blockPath("s9"))).toBe(true);
    });
  });

  describe("stop_recording (teacher leaves / app closes) — must NOT end the class", () => {
    test("stops the egress, keeps the room and everyone in it, saves the recording", async () => {
      const rec = seedActiveRecording({ startedAt: NOW - 45 * 60 * 1000 });
      const res = await moderate("T1", { action: "stop_recording" });

      expect(res).toEqual({ status: "stopped", count: 1 });
      const L = mockState.lk;
      expect(L.egresses.find((e) => e.egressId === rec.egressId).status).toBe(EgressStatus.ENDING);
      expect(L.callsTo("deleteRoom")).toEqual([]);
      expect(L.participant(ROOM, "s1")).toBeDefined();
      expect(mockState.delays).not.toContain(4000);

      const url = `https://cdn.example.com/${rec.r2FilePath}`;
      expect(mockState.db.get(`courses/c1/recordings/${rec.egressId}`)).toEqual({
        egressId: rec.egressId,
        roomName: ROOM,
        videoUrl: url,
        qualities: { "1080p": url, "720p": url, "480p": url, "360p": url },
        r2FilePath: rec.r2FilePath,
        recordedAt: Timestamp.fromMillis(rec.startedAt),
        duration: 45 * 60,
        sessionId: rec.sessionId,
      });
      expect(mockState.db.get(`activeRecordings/${rec.egressId}`)).toMatchObject({ status: "completed", duration: 45 * 60 });
      expect(mockState.db.get(`courses/c1/activeSessions/${rec.sessionId}`)).toMatchObject({ status: "ended" });
      expect(mockState.db.get(`activeRooms/${ROOM}`)).toMatchObject({ status: "ended" });
    });

    test("two classes on the same day: only the recording actually stopped is saved", async () => {
      const morning = seedActiveRecording({ egressId: "EG_morning", startedAt: NOW - 8 * HOUR });
      mockState.lk.egresses.find((e) => e.egressId === "EG_morning").status = EgressStatus.COMPLETE;
      mockState.db.seed(`courses/c1/recordings/EG_morning`, { egressId: "EG_morning", duration: 3600, r2FilePath: morning.r2FilePath });
      const evening = seedActiveRecording({ egressId: "EG_evening", startedAt: NOW - HOUR });

      await moderate("T1", { action: "stop_recording" });

      expect(mockState.db.get("courses/c1/recordings/EG_morning")).toEqual({ egressId: "EG_morning", duration: 3600, r2FilePath: morning.r2FilePath });
      expect(mockState.db.get("courses/c1/recordings/EG_evening")).toMatchObject({ r2FilePath: evening.r2FilePath, duration: 3600 });
      expect(mockState.lk.callsTo("stopEgress")).toEqual([["stopEgress", "EG_evening"]]);
    });

    test("a recording the webhook already marked FAILED is not re-saved as playable", async () => {
      const rec = seedActiveRecording();
      mockState.db.seed(`activeRecordings/${rec.egressId}`, { ...mockState.db.get(`activeRecordings/${rec.egressId}`), status: "failed" });
      mockState.db.seed(`activeRooms/${ROOM}`, { status: "ended" });
      await moderate("T1", { action: "stop_recording" });
      expect(mockState.db.has(`courses/c1/recordings/${rec.egressId}`)).toBe(false);
    });

    test("egress already gone: falls back to the room's active recording", async () => {
      const rec = seedActiveRecording();
      mockState.lk.egresses = [];
      const res = await moderate("T1", { action: "stop_recording" });
      expect(res.count).toBe(0);
      expect(mockState.db.has(`courses/c1/recordings/${rec.egressId}`)).toBe(true);
    });

    test("nothing was recording: no recording document is invented", async () => {
      const res = await moderate("T1", { action: "stop_recording" });
      expect(res).toEqual({ status: "stopped", count: 0 });
      expect(mockState.db.paths("courses/c1/recordings")).toEqual([]);
    });

    test("an already-ended room record is not saved again", async () => {
      seedActiveRecording();
      mockState.lk.egresses = [];
      mockState.db.seed(`activeRooms/${ROOM}`, { ...mockState.db.get(`activeRooms/${ROOM}`), status: "ended" });
      await moderate("T1", { action: "stop_recording" });
      expect(mockState.db.paths("courses/c1/recordings")).toEqual([]);
    });

    test("failing to save the recording document does not fail the stop", async () => {
      seedActiveRecording();
      mockState.db.failWritesTo = /^courses\/c1\/recordings\//;
      await expect(moderate("T1", { action: "stop_recording" })).resolves.toEqual({ status: "stopped", count: 1 });
    });

    test("LiveKit egress API down → internal error", async () => {
      mockState.lk.failNext.listEgress = new Error("down");
      await expectHttpsError(moderate("T1", { action: "stop_recording" }), "internal", "Failed to stop recording");
    });
  });

  describe("end_room (teacher ends the class for everyone)", () => {
    test("stops the recording, lets it flush 4s, deletes the room (disconnects everyone), saves the recording", async () => {
      const rec = seedActiveRecording();
      const res = await moderate("T1", { action: "end_room" });
      expect(res).toEqual({ status: "stopped", count: 1 });

      const L = mockState.lk;
      const order = L.calls.map((c) => c[0]);
      expect(order.indexOf("stopEgress")).toBeLessThan(order.indexOf("deleteRoom"));
      expect(mockState.delays).toContain(4000);
      expect(L.rooms.has(ROOM)).toBe(false);
      expect(mockState.db.has(`courses/c1/recordings/${rec.egressId}`)).toBe(true);
    });

    test("no recording running → no flush delay, room still deleted", async () => {
      await moderate("T1", { action: "end_room" });
      expect(mockState.delays).not.toContain(4000);
      expect(mockState.lk.rooms.has(ROOM)).toBe(false);
    });

    test("room already gone on LiveKit → still succeeds", async () => {
      mockState.lk.rooms.clear();
      await expect(moderate("T1", { action: "end_room" })).resolves.toEqual({ status: "stopped", count: 0 });
    });
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("startAutomatedRecording", () => {
  const start = (uid, data) => call(lk.startAutomatedRecording, uid, { courseId: "c1", audioTrackId: "TR_a", videoTrackId: "TR_v", ...data });

  test("access control and validation", async () => {
    await expectHttpsError(call(lk.startAutomatedRecording, null, {}), "unauthenticated");
    await expectHttpsError(start("T1", { courseId: undefined }), "invalid-argument");
    await expectHttpsError(start("T1", { audioTrackId: undefined }), "invalid-argument", "Track IDs");
    await expectHttpsError(start("T1", { videoTrackId: undefined }), "invalid-argument", "Track IDs");
    await expectHttpsError(start("T1", { courseId: "nope" }), "not-found");
    for (const uid of ["s1", "admin1", "outsider"]) {
      await expectHttpsError(start(uid), "permission-denied", "Only the teacher");
    }
    expect(mockState.lk.callsTo("startParticipantEgress")).toEqual([]);
  });

  test("never starts a second recording while one is starting or active", async () => {
    for (const status of [EgressStatus.STARTING, EgressStatus.ACTIVE]) {
      mockState.lk.egresses = [];
      mockState.lk.addEgress(ROOM, status, "EG_running");
      await expect(start("T1")).resolves.toEqual({ status: "already_recording", egressId: "EG_running" });
    }
    expect(mockState.lk.callsTo("startParticipantEgress")).toEqual([]);
  });

  test("finished/failed egresses don't block a new recording", async () => {
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    for (const s of [EgressStatus.ENDING, EgressStatus.COMPLETE, EgressStatus.FAILED, EgressStatus.ABORTED]) mockState.lk.addEgress(ROOM, s);
    await expect(start("T1")).resolves.toMatchObject({ status: "started" });
  });

  test("records the teacher's mobile participant to R2 in landscape 1080p", async () => {
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    const res = await start("T1", { orientation: "landscape" });

    expect(res).toEqual({ status: "started", egressId: expect.stringMatching(/^EG_part_/) });
    const [, room, identity, output, opts] = mockState.lk.callsTo("startParticipantEgress")[0];
    expect(room).toBe(ROOM);
    expect(identity).toBe("T1_mobile");
    expect(output).toEqual({
      fileType: 0,
      filepath: `courses/c1/recordings/recording-c1-${NOW}.mp4`,
      output: {
        case: "s3",
        value: {
          accessKey: "r2-access", secret: "r2-secret", endpoint: "https://r2.example.com",
          bucket: "calligro-recordings", region: "auto", forcePathStyle: true,
        },
      },
    });
    const { EncodingOptionsPreset } = jest.requireActual("livekit-server-sdk");
    expect(opts.encodingOptions).toBe(EncodingOptionsPreset.H264_1080P_30);
    expect(opts.screenShare).toBe(false);
    expect(opts.webhooks).toEqual([{ url: "https://livekit-livekitwebhook-yc7sgeqhya-uc.a.run.app" }]);
  });

  test("portrait or missing orientation uses the portrait preset", async () => {
    const { EncodingOptionsPreset } = jest.requireActual("livekit-server-sdk");
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    await start("T1", { orientation: "portrait" });
    mockState.lk.egresses = [];
    await start("T1");
    const presets = mockState.lk.callsTo("startParticipantEgress").map((c) => c[4].encodingOptions);
    expect(presets).toEqual([EncodingOptionsPreset.PORTRAIT_H264_1080P_30, EncodingOptionsPreset.PORTRAIT_H264_1080P_30]);
  });

  test("teacher on the web (identity T1) is recorded under that identity", async () => {
    mockState.lk.addParticipant(ROOM, { identity: "T1", role: "moderator" });
    await start("T1");
    expect(mockState.lk.callsTo("startParticipantEgress")[0][2]).toBe("T1");
  });

  test("falls back to track-composite egress with the given tracks if participant egress fails", async () => {
    // teacher not in the room → participant egress throws
    const res = await start("T1", { orientation: "landscape" });
    expect(res.egressId).toMatch(/^EG_track_/);
    const [, room, output, opts] = mockState.lk.callsTo("startTrackCompositeEgress")[0];
    expect(room).toBe(ROOM);
    expect(output.filepath).toBe(`courses/c1/recordings/recording-c1-${NOW}.mp4`);
    expect(opts.audioTrackId).toBe("TR_a");
    expect(opts.videoTrackId).toBe("TR_v");
  });

  test("can't list participants → assumes the mobile identity", async () => {
    mockState.lk.failNext.listParticipants = new Error("down");
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    await start("T1");
    expect(mockState.lk.callsTo("startParticipantEgress")[0][2]).toBe("T1_mobile");
  });

  test("stores the session under a unique sessionId (never by date) + egress and room indexes", async () => {
    mockState.lk.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    const { egressId } = await start("T1");
    const expected = {
      sessionId: `c1_${NOW}`, egressId, roomName: ROOM, r2FilePath: `courses/c1/recordings/recording-c1-${NOW}.mp4`,
      startedAt: Timestamp.fromMillis(NOW), teacherId: "T1", courseId: "c1", status: "active",
    };
    expect(mockState.db.get(`courses/c1/activeSessions/c1_${NOW}`)).toEqual(expected);
    expect(mockState.db.get(`activeRecordings/${egressId}`)).toEqual(expected);
    expect(mockState.db.get(`activeRooms/${ROOM}`)).toEqual(expected);
    const today = new Date(NOW).toISOString().split("T")[0];
    expect(mockState.db.has(`courses/c1/activeSessions/${today}`)).toBe(false);
  });

  test("both egress types failing → internal error and nothing stored", async () => {
    mockState.lk.failNext.startTrackCompositeEgress = new Error("egress unavailable");
    await expectHttpsError(start("T1"), "internal", "Failed to start");
    expect(mockState.db.paths("activeRecordings")).toEqual([]);
    expect(mockState.db.paths("courses/c1/activeSessions")).toEqual([]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("livekitWebhook", () => {
  describe("signature verification (only LiveKit may call this)", () => {
    const event = { event: "participant_joined", room: { name: ROOM }, participant: { identity: "s1", name: "S" } };

    test("missing body → 400", async () => {
      expect((await runWebhook({ headers: {} })).statusCode).toBe(400);
    });

    test("no Authorization header → 400 and nothing written", async () => {
      const req = await signedWebhook(event);
      delete req.headers.authorization;
      expect((await runWebhook(req)).statusCode).toBe(400);
      expect(mockState.db.writes).toEqual([]);
    });

    test("signed with the wrong secret → 400", async () => {
      const req = await signedWebhook(event, { secret: "attacker_secret_attacker_secret_1234" });
      expect((await runWebhook(req)).statusCode).toBe(400);
      expect(mockState.db.writes).toEqual([]);
    });

    test("body changed after signing → 400", async () => {
      const req = await signedWebhook(event, { tamper: (b) => b.replace('"s1"', '"s2"') });
      expect((await runWebhook(req)).statusCode).toBe(400);
      expect(mockState.db.writes).toEqual([]);
    });

    test("correctly signed → 200", async () => {
      const res = await runWebhook(await signedWebhook(event));
      expect(res.statusCode).toBe(200);
      expect(res.body).toBe("ok");
    });
  });

  describe("egress_ended", () => {
    const ended = (egressId, status, extra = {}) => ({ event: "egress_ended", egressInfo: { egressId, roomName: ROOM, status, ...extra } });

    test.each([["EGRESS_COMPLETE"], ["EGRESS_LIMIT_REACHED"]])("%s → recording saved as ready with the exact file duration", async (status) => {
      const rec = seedActiveRecording();
      const res = await runWebhook(await signedWebhook(ended(rec.egressId, status, { fileResults: [{ filename: "f.mp4", duration: "2712000000000" }] })));
      expect(res.statusCode).toBe(200);
      const url = `https://cdn.example.com/${rec.r2FilePath}`;
      expect(mockState.db.get(`courses/c1/recordings/${rec.egressId}`)).toEqual({
        egressId: rec.egressId, roomName: ROOM, videoUrl: url, r2FilePath: rec.r2FilePath,
        recordedAt: Timestamp.fromMillis(rec.startedAt), duration: 2712,
        qualities: { "1080p": url, "720p": url, "480p": url, "360p": url }, status: "ready",
      });
      expect(mockState.db.get(`activeRecordings/${rec.egressId}`)).toMatchObject({ status: "completed", duration: 2712 });
    });

    test("no file duration → falls back to wall-clock since start", async () => {
      const rec = seedActiveRecording({ startedAt: NOW - 20 * 60 * 1000 });
      await runWebhook(await signedWebhook(ended(rec.egressId, "EGRESS_COMPLETE")));
      expect(mockState.db.get(`courses/c1/recordings/${rec.egressId}`).duration).toBe(20 * 60);
    });

    test.each([["EGRESS_FAILED"], ["EGRESS_ABORTED"]])("%s → an already-saved recording is marked failed (hidden in the app)", async (status) => {
      const rec = seedActiveRecording();
      mockState.db.seed(`courses/c1/recordings/${rec.egressId}`, { egressId: rec.egressId, videoUrl: "x", r2FilePath: rec.r2FilePath });
      await runWebhook(await signedWebhook(ended(rec.egressId, status, { error: "pipeline frozen" })));
      expect(mockState.db.get(`courses/c1/recordings/${rec.egressId}`)).toMatchObject({ status: "failed", error: "pipeline frozen" });
      expect(mockState.db.get(`activeRecordings/${rec.egressId}`)).toMatchObject({ status: "failed" });
    });

    test("failure before any recording document exists → none is created", async () => {
      const rec = seedActiveRecording();
      await runWebhook(await signedWebhook(ended(rec.egressId, "EGRESS_FAILED")));
      expect(mockState.db.has(`courses/c1/recordings/${rec.egressId}`)).toBe(false);
    });

    test("failure then a late stop_recording: the recording stays hidden", async () => {
      const rec = seedActiveRecording();
      await runWebhook(await signedWebhook(ended(rec.egressId, "EGRESS_FAILED")));
      // As on the real server: a failed egress is no longer "active" in listEgress.
      mockState.lk.egresses.find((e) => e.egressId === rec.egressId).status = EgressStatus.FAILED;
      await call(lk.moderateParticipant, "T1", { courseId: "c1", action: "stop_recording" });
      await runWebhook(await signedWebhook({ event: "room_finished", room: { name: ROOM } }));
      expect(mockState.db.has(`courses/c1/recordings/${rec.egressId}`)).toBe(false);
    });

    test("legacy sessions are found through the activeSessions collection-group index", async () => {
      mockState.db.seed("courses/c1/activeSessions/2026-11-14", {
        egressId: "EG_legacy", r2FilePath: "courses/c1/recordings/legacy.mp4", roomName: ROOM, startedAt: Timestamp.fromMillis(NOW - HOUR),
      });
      await runWebhook(await signedWebhook(ended("EG_legacy", "EGRESS_COMPLETE")));
      expect(mockState.db.get("courses/c1/recordings/EG_legacy")).toMatchObject({ status: "ready", r2FilePath: "courses/c1/recordings/legacy.mp4" });
      expect(mockState.db.get("courses/c1/activeSessions/2026-11-14")).toMatchObject({ status: "completed" });
    });

    test("unknown egress → 200, nothing written", async () => {
      const res = await runWebhook(await signedWebhook(ended("EG_unknown", "EGRESS_COMPLETE")));
      expect(res.statusCode).toBe(200);
      expect(mockState.db.writes).toEqual([]);
    });
  });

  describe("room_finished (safety net when the teacher's app died)", () => {
    test("finalizes an active recording and closes the room record", async () => {
      const rec = seedActiveRecording({ startedAt: NOW - 10 * 60 * 1000 });
      await runWebhook(await signedWebhook({ event: "room_finished", room: { name: ROOM } }));
      expect(mockState.db.get(`courses/c1/recordings/${rec.egressId}`)).toMatchObject({ r2FilePath: rec.r2FilePath, duration: 600 });
      expect(mockState.db.get(`activeRooms/${ROOM}`)).toMatchObject({ status: "ended" });
    });

    test("does nothing when the room was already ended properly", async () => {
      seedActiveRecording();
      mockState.db.seed(`activeRooms/${ROOM}`, { ...mockState.db.get(`activeRooms/${ROOM}`), status: "ended" });
      await runWebhook(await signedWebhook({ event: "room_finished", room: { name: ROOM } }));
      expect(mockState.db.paths("courses/c1/recordings")).toEqual([]);
    });

    test("a room with no recording (only the course mapping) is ignored", async () => {
      mockState.db.seed(`activeRooms/${ROOM}`, { courseId: "c1", roomName: ROOM });
      await runWebhook(await signedWebhook({ event: "room_finished", room: { name: ROOM } }));
      expect(mockState.db.paths("courses/c1/recordings")).toEqual([]);
    });
  });

  describe("attendance (participant_joined / participant_left)", () => {
    const today = () => new Date().toISOString().split("T")[0];
    const att = (uid) => `courses/c1/meetingAttendance/${today()}/participants/${uid}`;
    const joined = (identity, name = identity) => ({ event: "participant_joined", room: { name: ROOM }, participant: { identity, name } });
    const left = (identity) => ({ event: "participant_left", room: { name: ROOM }, participant: { identity } });

    beforeEach(() => mockState.db.seed(`activeRooms/${ROOM}`, { courseId: "c1", roomName: ROOM }));

    test("first join, rejoin, leave", async () => {
      await runWebhook(await signedWebhook(joined("s1", "Student One")));
      expect(mockState.db.get(att("s1"))).toEqual({
        name: "Student One", identity: "s1", isOnline: true,
        firstJoinedAt: Timestamp.fromMillis(NOW), lastJoinedAt: Timestamp.fromMillis(NOW),
      });

      now = NOW + 10 * 60 * 1000;
      await runWebhook(await signedWebhook(left("s1")));
      expect(mockState.db.get(att("s1"))).toMatchObject({ isOnline: false, leftAt: Timestamp.fromMillis(now) });

      now = NOW + 20 * 60 * 1000;
      await runWebhook(await signedWebhook(joined("s1", "Student One")));
      const rec = mockState.db.get(att("s1"));
      expect(rec.firstJoinedAt).toEqual(Timestamp.fromMillis(NOW)); // unchanged
      expect(rec.lastJoinedAt).toEqual(Timestamp.fromMillis(now));
      expect(rec.isOnline).toBe(true);
    });

    test("the teacher's mobile identity is recorded under the teacher uid", async () => {
      await runWebhook(await signedWebhook(joined("T1_mobile")));
      expect(mockState.db.has(att("T1"))).toBe(true);
    });

    test("works for a class that is NOT recorded (mapping written at token time)", async () => {
      mockState.db = new FakeFirestore();
      seedWorld(mockState.db);
      await call(lk.generateLiveKitToken, "s1", { courseId: "c1" });
      await runWebhook(await signedWebhook(joined("s1")));
      expect(mockState.db.has(att("s1"))).toBe(true);
    });

    test("a room we don't know is ignored", async () => {
      mockState.db = new FakeFirestore();
      await runWebhook(await signedWebhook(joined("s1")));
      expect(mockState.db.writes).toEqual([]);
    });
  });

  test("other events are acknowledged and ignored", async () => {
    const res = await runWebhook(await signedWebhook({ event: "track_published", room: { name: ROOM } }));
    expect(res.statusCode).toBe(200);
    expect(mockState.db.writes).toEqual([]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("generateR2UploadUrl (web teacher local recording upload)", () => {
  const upload = (uid, data) => call(lk.generateR2UploadUrl, uid, { courseId: "c1", ...data });

  test("access control", async () => {
    await expectHttpsError(call(lk.generateR2UploadUrl, null, {}), "unauthenticated");
    await expectHttpsError(upload("T1", { courseId: undefined }), "invalid-argument");
    await expectHttpsError(upload("T1", { courseId: "nope" }), "not-found");
    for (const uid of ["s1", "admin1"]) await expectHttpsError(upload(uid), "permission-denied");
  });

  test.each(["text/html", "image/svg+xml", "application/javascript", "video/mp4; charset=x", "VIDEO/MP4", ""])(
    "rejects non-video content type %p (no HTML/JS on the public bucket)", async (contentType) => {
      await expectHttpsError(upload("T1", { contentType }), "invalid-argument", "Only video");
      expect(getSignedUrl).not.toHaveBeenCalled();
    });

  test.each([["video/mp4", "mp4"], ["video/webm", "webm"], ["video/quicktime", "mov"], [undefined, "webm"]])(
    "%p → signed PUT inside this course's folder with the .%s extension", async (contentType, ext) => {
      const res = await upload("T1", contentType ? { contentType } : {});
      const key = `courses/c1/recordings/web_recording_${NOW}.${ext}`;
      expect(res.r2FilePath).toBe(key);
      expect(res.uploadUrl).toBe(`https://signed.example/PutObjectCommand/calligro-recordings/${key}?ct=${contentType || "video/webm"}&exp=10800`);
    });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("saveRecordingMetadata", () => {
  const save = (uid, data) => call(lk.saveRecordingMetadata, uid, { courseId: "c1", ...data });

  test("access control", async () => {
    await expectHttpsError(call(lk.saveRecordingMetadata, null, {}), "unauthenticated");
    await expectHttpsError(save("T1", {}), "invalid-argument", "Missing");
    await expectHttpsError(save("s1", { r2FilePath: "courses/c1/recordings/a.webm" }), "permission-denied");
    await expectHttpsError(save("T1", { courseId: "nope", r2FilePath: "courses/nope/recordings/a.webm" }), "not-found");
  });

  test.each([
    "records/lesson1.mp4",
    "courses/c2/recordings/stolen.mp4",
    "courses/c10/recordings/x.mp4",
    "courses/c1/recordings/../../c2/recordings/x.mp4",
    "/courses/c1/recordings/a.mp4",
    "courses/c1/recordings_evil/a.mp4",
    "tmp/recording-c1-1.mp4",
  ])("rejects a path outside this course's folder: %s", async (r2FilePath) => {
    await expectHttpsError(save("T1", { r2FilePath }), "invalid-argument", "Invalid storage path");
    expect(mockState.db.paths("courses/c1/recordings")).toEqual([]);
  });

  test("saves the uploaded recording for the course", async () => {
    const res = await save("T1", { r2FilePath: "courses/c1/recordings/web_recording_1.webm", duration: 1800 });
    const url = "https://cdn.example.com/courses/c1/recordings/web_recording_1.webm";
    expect(res).toEqual({ success: true, videoUrl: url });
    const [path] = mockState.db.paths("courses/c1/recordings/");
    expect(mockState.db.get(path)).toEqual({
      roomName: `CG_Manual_${new Date().toISOString().split("T")[0]}`,
      videoUrl: url, r2FilePath: "courses/c1/recordings/web_recording_1.webm",
      recordedAt: Timestamp.fromMillis(NOW), duration: 1800, source: "web_client",
      qualities: { "1080p": url, "720p": url, "480p": url, "360p": url },
      status: "ready", // upload finished → transcoding may start
    });
  });

  test("duration defaults to 0", async () => {
    await save("T1", { r2FilePath: "courses/c1/recordings/a.webm" });
    expect(mockState.db.get(mockState.db.paths("courses/c1/recordings/")[0]).duration).toBe(0);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("reconcileCourseRecordings (self-healing)", () => {
  const reconcile = (uid, courseId = "c1") => call(lk.reconcileCourseRecordings, uid, { courseId });
  const session = (id, data) => mockState.db.seed(`courses/c1/activeSessions/${id}`, {
    roomName: ROOM, startedAt: Timestamp.fromMillis(NOW - 2 * HOUR), ...data,
  });

  test("access control: teacher, enrolled students and admins only", async () => {
    await expectHttpsError(call(lk.reconcileCourseRecordings, null, { courseId: "c1" }), "unauthenticated");
    await expectHttpsError(call(lk.reconcileCourseRecordings, "s1", {}), "invalid-argument");
    await expectHttpsError(reconcile("s1", "nope"), "not-found");
    await expectHttpsError(reconcile("outsider"), "permission-denied");
    for (const uid of ["T1", "s1", "admin1"]) await expect(reconcile(uid)).resolves.toEqual({ success: true, recoveredCount: 0 });
  });

  test("recovers a finished recording missing from Firestore, with its real duration", async () => {
    session("c1_A", { egressId: "EG_A", r2FilePath: "courses/c1/recordings/a.mp4", endedAt: Timestamp.fromMillis(NOW - HOUR) });
    mockState.r2.set("courses/c1/recordings/a.mp4", 50_000_000);
    await expect(reconcile("s1")).resolves.toEqual({ success: true, recoveredCount: 1 });
    expect(mockState.db.get("courses/c1/recordings/EG_A")).toMatchObject({
      egressId: "EG_A", r2FilePath: "courses/c1/recordings/a.mp4", recovered: true, duration: 3600, status: "ready",
      videoUrl: "https://cdn.example.com/courses/c1/recordings/a.mp4",
    });
    expect(mockState.db.get("courses/c1/activeSessions/c1_A")).toMatchObject({ status: "recovered" });
  });

  test("unknown end time → duration 0 (not 'now minus start', which could be days)", async () => {
    session("c1_A", { egressId: "EG_A", r2FilePath: "courses/c1/recordings/a.mp4" });
    mockState.r2.set("courses/c1/recordings/a.mp4", 50_000_000);
    now = NOW + 3 * 24 * HOUR;
    await reconcile("T1");
    expect(mockState.db.get("courses/c1/recordings/EG_A").duration).toBe(0);
  });

  test("skips: already saved, missing file, tiny/corrupt file, incomplete session", async () => {
    session("c1_saved", { egressId: "EG_saved", r2FilePath: "courses/c1/recordings/saved.mp4" });
    mockState.db.seed("courses/c1/recordings/EG_saved", { title: "Lesson 1" });
    mockState.r2.set("courses/c1/recordings/saved.mp4", 50_000_000);
    session("c1_missing", { egressId: "EG_missing", r2FilePath: "courses/c1/recordings/missing.mp4" });
    session("c1_tiny", { egressId: "EG_tiny", r2FilePath: "courses/c1/recordings/tiny.mp4" });
    mockState.r2.set("courses/c1/recordings/tiny.mp4", 1024);
    session("c1_nopath", { egressId: "EG_nopath" });

    await expect(reconcile("T1")).resolves.toEqual({ success: true, recoveredCount: 0 });
    expect(mockState.db.get("courses/c1/recordings/EG_saved")).toEqual({ title: "Lesson 1" });
    expect(mockState.db.paths("courses/c1/recordings/")).toEqual(["courses/c1/recordings/EG_saved"]);
  });

  test("only the 10 most recent sessions are checked", async () => {
    for (let i = 0; i < 12; i++) {
      session(`c1_${i}`, { egressId: `EG_${i}`, r2FilePath: `courses/c1/recordings/${i}.mp4`, startedAt: Timestamp.fromMillis(NOW - i * HOUR) });
      mockState.r2.set(`courses/c1/recordings/${i}.mp4`, 5_000_000);
    }
    await expect(reconcile("T1")).resolves.toEqual({ success: true, recoveredCount: 10 });
    expect(mockState.db.has("courses/c1/recordings/EG_10")).toBe(false);
    expect(mockState.db.has("courses/c1/recordings/EG_11")).toBe(false);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("getRecordingPlaybackUrl", () => {
  const play = (uid, data) => call(lk.getRecordingPlaybackUrl, uid, { courseId: "c1", recordingId: "EG_1", ...data });

  beforeEach(() => {
    mockState.db.seed("courses/c1/recordings/EG_1", { r2FilePath: "courses/c1/recordings/one.mp4" });
    mockState.db.seed("courses/c2/recordings/EG_2", { r2FilePath: "courses/c2/recordings/two.mp4" });
  });

  test("access control", async () => {
    await expectHttpsError(call(lk.getRecordingPlaybackUrl, null, {}), "unauthenticated");
    await expectHttpsError(play("s1", { recordingId: undefined }), "invalid-argument");
    await expectHttpsError(play("s1", { courseId: "nope" }), "not-found");
    await expectHttpsError(play("outsider"), "permission-denied");
  });

  test.each(["T1", "s1", "admin1"])("%s gets a 3-hour signed GET for exactly that recording's file", async (uid) => {
    const res = await play(uid);
    const url = "https://signed.example/GetObjectCommand/calligro-recordings/courses/c1/recordings/one.mp4?ct=&exp=10800";
    expect(res).toEqual({ success: true, playbackUrl: url, qualities: { "1080p": url } });
  });

  test("transcoded renditions are returned as signed URLs too", async () => {
    mockState.db.seed("courses/c1/recordings/EG_1", {
      r2FilePath: "courses/c1/recordings/one.mp4",
      renditionKeys: { "720p": "courses/c1/recordings/one_720p.mp4", "360p": "courses/c1/recordings/one_360p.mp4" },
    });
    const { qualities } = await play("s1");
    const signed = (k) => `https://signed.example/GetObjectCommand/calligro-recordings/${k}?ct=&exp=10800`;
    expect(qualities).toEqual({
      "1080p": signed("courses/c1/recordings/one.mp4"),
      "720p": signed("courses/c1/recordings/one_720p.mp4"),
      "360p": signed("courses/c1/recordings/one_360p.mp4"),
    });
  });

  test("rendition keys outside this course's folder are never signed", async () => {
    mockState.db.seed("courses/c1/recordings/EG_1", {
      r2FilePath: "courses/c1/recordings/one.mp4",
      renditionKeys: { "720p": "courses/c2/recordings/two.mp4", "480p": "courses/c1/recordings/../../c2/x.mp4", "360p": 5 },
    });
    const { qualities } = await play("s1");
    expect(Object.keys(qualities)).toEqual(["1080p"]);
  });

  test("a client-supplied file path is ignored (no access to other courses' files)", async () => {
    const res = await play("s1", { r2FilePath: "courses/c2/recordings/two.mp4" });
    expect(res.playbackUrl).toContain("courses/c1/recordings/one.mp4");
    expect(res.playbackUrl).not.toContain("c2");
  });

  test("a recording id from ANOTHER course → not-found", async () => {
    await expectHttpsError(play("s1", { recordingId: "EG_2" }), "not-found", "Recording not found");
    expect(getSignedUrl).not.toHaveBeenCalled();
  });

  test("a recording without a file → not-found", async () => {
    mockState.db.seed("courses/c1/recordings/EG_empty", { title: "x" });
    await expectHttpsError(play("s1", { recordingId: "EG_empty" }), "not-found");
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("End-to-end: one complete class", () => {
  test("join → record → kick → mute all → end → webhook → students play the recording", async () => {
    const L = mockState.lk;

    // Everyone gets a token; the room is mapped to the course.
    const teacherTok = await call(lk.generateLiveKitToken, "T1", { courseId: "c1", source: "mobile" });
    expect((await verifyToken(teacherTok.token)).sub).toBe("T1_mobile");
    for (const s of ["s1", "s2"]) await call(lk.generateLiveKitToken, s, { courseId: "c1", source: "mobile" });
    L.addParticipant(ROOM, { identity: "T1_mobile", role: "moderator" });
    L.addParticipant(ROOM, { identity: "s1" });
    L.addParticipant(ROOM, { identity: "s2" });

    // Teacher's app starts recording.
    const { egressId } = await call(lk.startAutomatedRecording, "T1", { courseId: "c1", audioTrackId: "a", videoTrackId: "v", orientation: "landscape" });
    L.egresses.find((e) => e.egressId === egressId).status = EgressStatus.ACTIVE;

    // s1 misbehaves → kicked and can't come back; s2 is muted by mute-all.
    await call(lk.moderateParticipant, "T1", { courseId: "c1", action: "kick", targetIdentity: "s1" });
    await expectHttpsError(call(lk.generateLiveKitToken, "s1", { courseId: "c1" }), "permission-denied");
    await call(lk.moderateParticipant, "T1", { courseId: "c1", action: "mute_all" });
    expect(L.participant(ROOM, "s2").tracks[0].muted).toBe(true);

    // 50 minutes later the teacher ends the class.
    now = NOW + 50 * 60 * 1000;
    await call(lk.moderateParticipant, "T1", { courseId: "c1", action: "end_room" });
    expect(L.rooms.has(ROOM)).toBe(false);

    // LiveKit confirms the file.
    await runWebhook(await signedWebhook({ event: "egress_ended", egressInfo: { egressId, roomName: ROOM, status: "EGRESS_COMPLETE", fileResults: [{ duration: "2995000000000" }] } }));
    const recording = mockState.db.get(`courses/c1/recordings/${egressId}`);
    expect(recording).toMatchObject({ status: "ready", duration: 2995, r2FilePath: `courses/c1/recordings/recording-c1-${NOW}.mp4` });

    // An enrolled student plays it through a signed URL; an outsider can't.
    const { playbackUrl } = await call(lk.getRecordingPlaybackUrl, "s2", { courseId: "c1", recordingId: egressId });
    expect(playbackUrl).toContain(`recording-c1-${NOW}.mp4`);
    await expectHttpsError(call(lk.getRecordingPlaybackUrl, "outsider", { courseId: "c1", recordingId: egressId }), "permission-denied");
  });
});
