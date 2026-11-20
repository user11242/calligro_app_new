/**
 * Recording transcoding (functions/transcoder.js)
 *
 * REAL: transcoder.js, the file system (temp files are really written and removed).
 * FAKE: Firestore (path-accurate), Cloud Tasks queue, R2 uploads, signed URLs, the ffmpeg process.
 */
const fs = require("fs");
const { FakeFirestore } = require("./helpers/fakeFirestore");

const mockState = { db: null, enqueued: [], queueNames: [], uploads: [], spawns: [], deletes: [], ffmpegFailFor: new Set() };

jest.mock("firebase-admin", () => {
  const helpers = require("./helpers/fakeFirestore");
  const firestore = () => mockState.db;
  firestore.FieldValue = { serverTimestamp: () => helpers.SERVER_TIMESTAMP };
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

jest.mock("firebase-functions/params", () => ({
  defineSecret: (name) => ({
    name,
    value: () => ({
      CLOUDFLARE_R2_ACCESS_KEY: "r2-access",
      CLOUDFLARE_R2_SECRET_KEY: "r2-secret",
      CLOUDFLARE_R2_ENDPOINT: "https://r2.example.com",
      CLOUDFLARE_R2_PUBLIC_URL: "https://cdn.example.com/",
    })[name],
  }),
}));

function mockWrap(opts, handler) { const fn = (...a) => handler(...a); fn.__options = opts; return fn; }
jest.mock("firebase-functions/v2/https", () => ({
  HttpsError: jest.requireActual("firebase-functions/v2/https").HttpsError,
  onCall: mockWrap,
}));
jest.mock("firebase-functions/v2/firestore", () => ({ onDocumentWritten: mockWrap }));
jest.mock("firebase-functions/v2/tasks", () => ({ onTaskDispatched: mockWrap }));

jest.mock("@aws-sdk/client-s3", () => {
  class Command { constructor(input) { this.input = input; } }
  class PutObjectCommand extends Command {}
  class GetObjectCommand extends Command {}
  class DeleteObjectCommand extends Command {}
  class S3Client {
    async send(cmd) {
      if (cmd instanceof PutObjectCommand) {
        // Like the real client: the upload reads the whole file before resolving.
        const { Body, ...rest } = cmd.input;
        let bytes = 0;
        for await (const chunk of Body) bytes += chunk.length;
        mockState.uploads.push({ ...rest, bodyPath: Body.path, bytes });
        return {};
      }
      if (cmd instanceof DeleteObjectCommand) {
        mockState.deletes.push(cmd.input.Key);
        return {};
      }
      throw new Error("unexpected command");
    }
  }
  return { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand };
});

jest.mock("@aws-sdk/s3-request-presigner", () => ({
  getSignedUrl: async (client, cmd, opts) => `https://signed.example/${cmd.input.Key}?exp=${opts.expiresIn}`,
}));

jest.mock("ffmpeg-static", () => "/fake/ffmpeg");

// Fake ffmpeg: writes the output file (last arg) and exits 0, or exits 1 for failing heights.
jest.mock("child_process", () => ({
  spawn: (cmd, args) => {
    // ffmpeg is only ever given local relay addresses; map them back to what they forward to.
    const { relayTargetOf } = require("../media.js");
    const realOf = (text) => text.replace(/http:\/\/127\.0\.0\.1:\d+\/\d+\/media\.\w+/g, (u) => relayTargetOf(u) || `UNRELAYED ${u}`);
    mockState.spawns.push({ cmd, args, input: realOf(args[args.indexOf("-i") + 1] || "") });
    const { EventEmitter: MockEmitter } = require("events");
    const proc = new MockEmitter();
    proc.stderr = new MockEmitter();
    const height = (args[args.indexOf("-vf") + 1] || "").split(":")[1];
    setImmediate(() => {
      if (mockState.ffmpegFailFor.has(height)) {
        proc.stderr.emit("data", Buffer.from("Invalid data found when processing input"));
        proc.emit("close", 1);
      } else {
        const fsm = require("fs");
        const concatList = args.includes("concat") ? args[args.indexOf("-i") + 1] : null;
        if (concatList) {
          const raw = fsm.readFileSync(concatList, "utf8");
          mockState.rawConcatLists.push(raw);
          mockState.concatLists.push(realOf(raw));
        }
        fsm.writeFileSync(args[args.length - 1], "fake mp4 bytes");
        proc.emit("close", 0);
      }
    });
    return proc;
  },
}));

const tx = require("../transcoder.js");
const { renditionKey, missingRenditions, partCount, CHUNK_SECONDS, QUEUE_FUNCTION } = tx._test;

const REC = "courses/c1/recordings/EG_1";
const FILE = "courses/c1/recordings/recording-c1-1000.mp4";

function seedWorld() {
  const db = mockState.db;
  db.seed("users/T1", { role: "teacher" });
  db.seed("users/s1", { role: "student" });
  db.seed("users/admin1", { role: "admin" });
  db.seed("courses/c1", { teacherId: "T1", enrolledStudents: ["s1"] });
}

const written = (before, after) => ({
  params: { courseId: "c1", recordingId: "EG_1" },
  data: {
    before: before ? { exists: true, data: () => before } : { exists: false, data: () => undefined },
    after: after ? { exists: true, data: () => after } : { exists: false, data: () => undefined },
  },
});

beforeEach(() => {
  mockState.db = new FakeFirestore();
  mockState.enqueued = [];
  mockState.queueNames = [];
  mockState.uploads = [];
  mockState.spawns = [];
  mockState.deletes = [];
  mockState.concatLists = [];
  mockState.rawConcatLists = [];
  mockState.ffmpegFailFor = new Set();
  seedWorld();
  jest.spyOn(console, "log").mockImplementation(() => {});
  jest.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(() => jest.restoreAllMocks());

// ═════════════════════════════════════════════════════════════════════════════
describe("helpers", () => {
  test("rendition files sit next to the original with a _<quality> suffix", () => {
    expect(renditionKey(FILE, "720p")).toBe("courses/c1/recordings/recording-c1-1000_720p.mp4");
    expect(renditionKey("courses/c1/recordings/web_recording_1.webm", "360p")).toBe("courses/c1/recordings/web_recording_1_360p.mp4");
    expect(renditionKey("courses/c1/recordings/a.MOV", "480p")).toBe("courses/c1/recordings/a_480p.mp4");
  });

  test("missingRenditions", () => {
    expect(missingRenditions({})).toEqual(["720p", "480p", "360p"]);
    expect(missingRenditions({ renditionKeys: { "480p": "k" } })).toEqual(["720p", "360p"]);
    expect(missingRenditions({ renditionKeys: { "720p": "a", "480p": "b", "360p": "c" } })).toEqual([]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("resource settings (CPU quota is 20 per region)", () => {
  test("the heavy worker is capped so it can never exceed the quota", () => {
    const o = tx.transcodeRendition.__options;
    expect(o.cpu * o.maxInstances).toBeLessThanOrEqual(8);
    expect(o.timeoutSeconds).toBe(1800); // long classes need more than the 9-minute event limit
    expect(o.retryConfig.maxAttempts).toBe(2);
    expect(o.rateLimits.maxConcurrentDispatches).toBeLessThanOrEqual(o.maxInstances);
  });

  test("the trigger and the callable are light (no 2-CPU instances, explicit maxInstances)", () => {
    for (const fn of [tx.onRecordingReady, tx.transcodeRecording]) {
      expect(fn.__options.cpu).toBeUndefined();
      expect(fn.__options.maxInstances).toBeLessThanOrEqual(5);
    }
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("onRecordingReady (starts transcoding only for finished files)", () => {
  const ready = { status: "ready", r2FilePath: FILE };

  test("recording becomes ready → one task per quality on the right queue, marked queued", async () => {
    mockState.db.seed(REC, ready);
    await tx.onRecordingReady(written({ r2FilePath: FILE }, ready));
    expect(mockState.queueNames).toEqual([`locations/us-central1/functions/${QUEUE_FUNCTION}`]);
    expect(QUEUE_FUNCTION).toBe("transcoder-transcodeRendition");
    expect(mockState.enqueued).toEqual([
      { courseId: "c1", recordingId: "EG_1", label: "720p" },
      { courseId: "c1", recordingId: "EG_1", label: "480p" },
      { courseId: "c1", recordingId: "EG_1", label: "360p" },
    ]);
    expect(mockState.db.get(REC).transcodingStatus).toBe("queued");
  });

  test("a document created already ready (web upload / recovered) also triggers", async () => {
    mockState.db.seed(REC, ready);
    await tx.onRecordingReady(written(null, ready));
    expect(mockState.enqueued).toHaveLength(3);
  });

  test.each([
    ["the file is not finished yet (stop path wrote the doc, no status)", { r2FilePath: FILE }, { r2FilePath: FILE, duration: 10 }],
    ["the recording failed", { r2FilePath: FILE }, { status: "failed", r2FilePath: FILE }],
    ["it was already ready (any later edit, e.g. title rename)", ready, { ...ready, title: "Lesson 1" }],
    ["it has no file path", null, { status: "ready" }],
    ["it is already queued", null, { ...ready, transcodingStatus: "queued" }],
    ["it is already processing", null, { ...ready, transcodingStatus: "processing" }],
    ["it is already completed", null, { ...ready, transcodingStatus: "completed" }],
    ["the document was deleted", ready, null],
  ])("does nothing when %s", async (_, before, after) => {
    await tx.onRecordingReady(written(before, after));
    expect(mockState.enqueued).toEqual([]);
  });

  test("only missing qualities are queued", async () => {
    const partial = { ...ready, renditionKeys: { "720p": "x" } };
    mockState.db.seed(REC, partial);
    await tx.onRecordingReady(written(null, partial));
    expect(mockState.enqueued.map((t) => t.label)).toEqual(["480p", "360p"]);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("transcodeRendition (background worker)", () => {
  const task = (label, retryCount = 0) => tx.transcodeRendition({ data: { courseId: "c1", recordingId: "EG_1", label }, retryCount });

  beforeEach(() => mockState.db.seed(REC, { status: "ready", r2FilePath: FILE, transcodingStatus: "queued" }));

  test("reads the original through a SIGNED url (works with a private bucket) at the right size/bitrate", async () => {
    await task("720p");
    const { cmd, args } = mockState.spawns[0];
    expect(cmd).toBe("/fake/ffmpeg");
    // ffmpeg reads a local relay address (it cannot look up host names), forwarding to the signed url.
    expect(args[args.indexOf("-i") + 1]).toMatch(/^http:\/\/127\.0\.0\.1:\d+\/1\/media\.mp4$/);
    expect(mockState.spawns[0].input).toBe(`https://signed.example/${FILE}?exp=7200`);
    expect(args[args.indexOf("-vf") + 1]).toBe("scale=-2:720");
    expect(args[args.indexOf("-b:v") + 1]).toBe("1400k");
    expect(args[args.indexOf("-b:a") + 1]).toBe("128k");
    expect(args).toContain("+faststart");
  });

  test("uploads the rendition next to the original and records it; temp file is removed", async () => {
    await task("480p");
    const key = "courses/c1/recordings/recording-c1-1000_480p.mp4";
    expect(mockState.uploads).toEqual([
      { Bucket: "calligro-recordings", Key: key, ContentType: "video/mp4", bodyPath: expect.stringContaining("transcode_EG_1_480p.mp4"), bytes: 14 },
    ]);
    expect(fs.existsSync(mockState.uploads[0].bodyPath)).toBe(false);
    const rec = mockState.db.get(REC);
    expect(rec.renditionKeys).toEqual({ "480p": key });
    expect(rec.qualities).toEqual({ "480p": `https://cdn.example.com/${key}` });
    expect(rec.transcodingStatus).toBe("processing"); // others still missing
    expect(rec.transcoded).toBeUndefined();
  });

  test("after all three qualities the recording is marked completed (tasks don't overwrite each other)", async () => {
    await task("720p");
    await task("360p");
    await task("480p");
    const rec = mockState.db.get(REC);
    expect(Object.keys(rec.renditionKeys).sort()).toEqual(["360p", "480p", "720p"]);
    expect(rec.transcoded).toBe(true);
    expect(rec.transcodingStatus).toBe("completed");
    expect(rec.transcodeError).toBeNull();
    expect(rec.status).toBe("ready"); // original status untouched
  });

  test("an existing rendition is not redone (idempotent retries)", async () => {
    await task("720p");
    await task("720p");
    expect(mockState.spawns).toHaveLength(1);
    expect(mockState.uploads).toHaveLength(1);
  });

  test.each([
    ["the recording was deleted", () => mockState.db.docs.delete(REC)],
    ["the recording failed", () => mockState.db.seed(REC, { status: "failed", r2FilePath: FILE })],
    ["the recording has no file", () => mockState.db.seed(REC, { status: "ready" })],
  ])("skips without work when %s", async (_, setup) => {
    setup();
    await task("720p");
    expect(mockState.spawns).toEqual([]);
    expect(mockState.uploads).toEqual([]);
  });

  test("invalid payload is dropped (no retry, no work)", async () => {
    await expect(tx.transcodeRendition({ data: { courseId: "c1", recordingId: "EG_1", label: "4k" } })).resolves.toBeUndefined();
    await expect(tx.transcodeRendition({ data: {} })).resolves.toBeUndefined();
    expect(mockState.spawns).toEqual([]);
  });

  test("ffmpeg failure on the first attempt → throws so Cloud Tasks retries; nothing marked failed", async () => {
    mockState.ffmpegFailFor.add("720");
    await expect(task("720p", 0)).rejects.toThrow("ffmpeg exited with code 1");
    const rec = mockState.db.get(REC);
    expect(rec.transcodingStatus).not.toBe("failed");
    expect(rec.renditionKeys).toBeUndefined();
    expect(mockState.uploads).toEqual([]);
  });

  test("failure on the final attempt → marked failed with the reason, original stays playable", async () => {
    mockState.ffmpegFailFor.add("720");
    await expect(task("720p", 1)).resolves.toBeUndefined();
    const rec = mockState.db.get(REC);
    expect(rec.transcodingStatus).toBe("failed");
    expect(rec.transcodeError).toContain("720p: ffmpeg exited with code 1");
    expect(rec.status).toBe("ready");
    expect(rec.r2FilePath).toBe(FILE);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("transcodeRecording (manual trigger)", () => {
  const run = (uid, data) => tx.transcodeRecording({ auth: uid ? { uid } : null, data: { courseId: "c1", recordingId: "EG_1", ...data } });

  async function expectCode(promise, code) {
    await expect(promise).rejects.toMatchObject({ code });
  }

  beforeEach(() => mockState.db.seed(REC, { status: "ready", r2FilePath: FILE }));

  test("access control: only the course teacher or an admin", async () => {
    await expectCode(run(null), "unauthenticated");
    await expectCode(run("T1", { recordingId: undefined }), "invalid-argument");
    await expectCode(run("T1", { courseId: "nope" }), "not-found");
    await expectCode(run("s1"), "permission-denied"); // enrolled student
    await expectCode(run("stranger"), "permission-denied"); // no profile
    expect(mockState.enqueued).toEqual([]);
  });

  test.each(["T1", "admin1"])("%s queues the missing qualities and returns immediately", async (uid) => {
    await expect(run(uid)).resolves.toEqual({ success: true, queued: 3 });
    expect(mockState.enqueued).toHaveLength(3);
    expect(mockState.spawns).toEqual([]); // no heavy work in the callable
  });

  test("unknown recording or recording without file → not-found", async () => {
    await expectCode(run("T1", { recordingId: "nope" }), "not-found");
    mockState.db.seed(REC, { status: "ready" });
    await expectCode(run("T1"), "not-found");
  });

  test("a failed recording cannot be transcoded", async () => {
    mockState.db.seed(REC, { status: "failed", r2FilePath: FILE });
    await expectCode(run("T1"), "failed-precondition");
  });

  test("already transcoded / already queued → nothing new queued", async () => {
    mockState.db.seed(REC, { status: "ready", r2FilePath: FILE, renditionKeys: { "720p": "a", "480p": "b", "360p": "c" } });
    await expect(run("T1")).resolves.toEqual({ success: true, alreadyTranscoded: true, queued: 0 });
    mockState.db.seed(REC, { status: "ready", r2FilePath: FILE, transcodingStatus: "processing" });
    await expect(run("T1")).resolves.toEqual({ success: true, alreadyQueued: true, queued: 0 });
    expect(mockState.enqueued).toEqual([]);
  });

  test("a previously failed transcode can be retried", async () => {
    mockState.db.seed(REC, { status: "ready", r2FilePath: FILE, transcodingStatus: "failed", renditionKeys: { "480p": "b" } });
    await expect(run("T1")).resolves.toEqual({ success: true, queued: 2 });
    expect(mockState.db.get(REC)).toMatchObject({ transcodingStatus: "queued", transcodeError: null });
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe("long classes are converted in 20-minute pieces (a task may run 30 minutes at most)", () => {
  const HOURS_2 = 2 * 3600;
  const part = (label, i, n, retryCount = 0) =>
    tx.transcodeRendition({ data: { courseId: "c1", recordingId: "EG_1", label, part: i, parts: n }, retryCount });

  test("how many pieces", () => {
    expect(CHUNK_SECONDS).toBe(1200);
    expect(partCount({})).toBe(1); // unknown length → one piece, as before
    expect(partCount({ duration: 0 })).toBe(1);
    expect(partCount({ duration: 1200 })).toBe(1);
    expect(partCount({ duration: 1201 })).toBe(2);
    expect(partCount({ duration: HOURS_2 })).toBe(6);
    expect(partCount({ duration: String(HOURS_2) })).toBe(6);
    expect(partCount({ duration: HOURS_2 * 1e9 })).toBe(6); // LiveKit nanoseconds (old documents)
  });

  test("a short class is still one task per quality, exactly as before", async () => {
    const ready = { status: "ready", r2FilePath: FILE, duration: 1100 };
    mockState.db.seed(REC, ready);
    await tx.onRecordingReady(written(null, ready));
    expect(mockState.enqueued).toEqual([
      { courseId: "c1", recordingId: "EG_1", label: "720p" },
      { courseId: "c1", recordingId: "EG_1", label: "480p" },
      { courseId: "c1", recordingId: "EG_1", label: "360p" },
    ]);
  });

  test("a 2-hour class → 6 pieces per quality", async () => {
    const ready = { status: "ready", r2FilePath: FILE, duration: HOURS_2 };
    mockState.db.seed(REC, ready);
    await tx.onRecordingReady(written(null, ready));
    expect(mockState.enqueued).toHaveLength(18);
    expect(mockState.enqueued.filter((t) => t.label === "720p")).toEqual(
      [0, 1, 2, 3, 4, 5].map((i) => ({ courseId: "c1", recordingId: "EG_1", label: "720p", part: i, parts: 6 })));
  });

  test("a retry after a partial run re-queues only the missing pieces", async () => {
    const rec = { status: "ready", r2FilePath: FILE, duration: HOURS_2, transcodingStatus: "failed",
      renditionKeys: { "480p": "b", "360p": "c" }, renditionParts: { "720p": { 0: "p0", 3: "p3" } } };
    mockState.db.seed(REC, rec);
    await expect(tx.transcodeRecording({ auth: { uid: "T1" }, data: { courseId: "c1", recordingId: "EG_1" } }))
      .resolves.toEqual({ success: true, queued: 4 });
    expect(mockState.enqueued.map((t) => t.part)).toEqual([1, 2, 4, 5]);
  });

  describe("pieces", () => {
    beforeEach(() => mockState.db.seed(REC, { status: "ready", r2FilePath: FILE, duration: HOURS_2, transcodingStatus: "queued" }));

    test("each piece converts only its own 20 minutes (seek before reading)", async () => {
      await part("720p", 2, 6);
      const { args } = mockState.spawns[0];
      expect(args.slice(args.indexOf("-ss"), args.indexOf("-ss") + 4)).toEqual(["-ss", "2400", "-t", "1200"]);
      expect(args.indexOf("-ss")).toBeLessThan(args.indexOf("-i"));
      expect(args[args.indexOf("-vf") + 1]).toBe("scale=-2:720");
      expect(args).toContain("mpegts"); // pieces join without re-encoding
      const key = "courses/c1/recordings/recording-c1-1000_720p.part2.ts";
      expect(mockState.uploads).toEqual([expect.objectContaining({ Key: key, ContentType: "video/mp2t" })]);
      expect(fs.existsSync(mockState.uploads[0].bodyPath)).toBe(false);
      const rec = mockState.db.get(REC);
      expect(rec.renditionParts).toEqual({ "720p": { 2: key } });
      expect(rec.renditionKeys).toBeUndefined(); // not finished until every piece exists
    });

    test("the last piece joins them all, in order, into the normal quality file and cleans up", async () => {
      for (const i of [5, 0, 3, 1, 4]) await part("480p", i, 6);
      expect(mockState.concatLists).toEqual([]);
      await part("480p", 2, 6);

      expect(mockState.concatLists).toHaveLength(1);
      const lines = mockState.concatLists[0].trim().split("\n");
      expect(lines).toEqual([0, 1, 2, 3, 4, 5].map((i) =>
        `file 'https://signed.example/courses/c1/recordings/recording-c1-1000_480p.part${i}.ts?exp=7200'`));
      expect(mockState.rawConcatLists[0]).not.toContain("https://"); // only relay addresses reach ffmpeg
      const join = mockState.spawns[mockState.spawns.length - 1].args;
      expect(join).toEqual(expect.arrayContaining(["-c", "copy", "+faststart"]));

      const key = "courses/c1/recordings/recording-c1-1000_480p.mp4";
      expect(mockState.uploads[mockState.uploads.length - 1]).toMatchObject({ Key: key, ContentType: "video/mp4" });
      expect(mockState.db.get(REC).renditionKeys).toEqual({ "480p": key });
      expect(mockState.db.get(REC).qualities).toEqual({ "480p": `https://cdn.example.com/${key}` });
      expect(mockState.deletes.sort()).toEqual([0, 1, 2, 3, 4, 5].map((i) => `courses/c1/recordings/recording-c1-1000_480p.part${i}.ts`));
    });

    test("all pieces of all qualities → completed, original untouched", async () => {
      for (const label of ["720p", "480p", "360p"]) for (let i = 0; i < 6; i++) await part(label, i, 6);
      const rec = mockState.db.get(REC);
      expect(Object.keys(rec.renditionKeys).sort()).toEqual(["360p", "480p", "720p"]);
      expect(rec).toMatchObject({ transcoded: true, transcodingStatus: "completed", status: "ready", r2FilePath: FILE });
    });

    test("a piece already done is not redone (retries are safe)", async () => {
      await part("720p", 0, 6);
      await part("720p", 0, 6);
      expect(mockState.spawns).toHaveLength(1);
    });

    test("a failed piece is retried by Cloud Tasks; on its last attempt the quality is marked failed", async () => {
      mockState.ffmpegFailFor.add("360");
      await expect(part("360p", 1, 6, 0)).rejects.toThrow("ffmpeg exited with code 1");
      await expect(part("360p", 1, 6, 1)).resolves.toBeUndefined();
      expect(mockState.db.get(REC)).toMatchObject({ transcodingStatus: "failed", status: "ready" });
    });
  });

  test("the worker has room for a long class's joined file (temp files live in memory)", () => {
    expect(parseInt(tx.transcodeRendition.__options.memory, 10)).toBeGreaterThanOrEqual(4);
  });
});
