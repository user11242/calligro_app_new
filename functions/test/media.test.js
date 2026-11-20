/**
 * The ffmpeg relay (media.js). The ffmpeg-static Linux build cannot look up host names
 * (glibc linked statically): given an https:// address it crashes with signal 11 on
 * Cloud Functions. So ffmpeg must only read files or the numeric local relay.
 *
 * REAL: a local "storage" HTTP server, the relay, and the real ffmpeg binary.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const http = require("http");
const { spawnSync } = require("child_process");
const ffmpegPath = require("ffmpeg-static");
const { withRelay, relayTargetOf, runFfmpeg, writeConcatList, joinParts } = require("../media.js");

jest.setTimeout(60000);

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "media-test-"));
const clip = path.join(tmp, "clip.mp4");
let storage;
let storageUrl;
const requests = [];

beforeAll(async () => {
  // A 6-second test video with sound, moov at the END (like the recorder's MP4), so seeking needs ranges.
  const made = spawnSync(ffmpegPath, ["-y", "-v", "error",
    "-f", "lavfi", "-i", "testsrc=size=320x240:rate=25", "-f", "lavfi", "-i", "sine=frequency=440",
    "-t", "6", "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", clip]);
  if (made.status !== 0) throw new Error(String(made.stderr));
  const bytes = fs.readFileSync(clip);

  // Stands in for R2: serves the clip, honours byte ranges, logs each request.
  storage = http.createServer((req, res) => {
    requests.push({ url: req.url, range: req.headers.range });
    if (!req.url.startsWith("/courses/c1/recordings/clip.mp4")) return res.writeHead(404).end();
    const m = /bytes=(\d+)-(\d*)/.exec(req.headers.range || "");
    if (!m) {
      res.writeHead(200, { "content-length": bytes.length, "accept-ranges": "bytes", "content-type": "video/mp4" });
      return res.end(req.method === "HEAD" ? undefined : bytes);
    }
    const start = Number(m[1]);
    const end = m[2] ? Number(m[2]) : bytes.length - 1;
    res.writeHead(206, {
      "content-length": end - start + 1, "content-range": `bytes ${start}-${end}/${bytes.length}`,
      "accept-ranges": "bytes", "content-type": "video/mp4",
    });
    res.end(req.method === "HEAD" ? undefined : bytes.subarray(start, end + 1));
  });
  // Reached by host NAME (like R2), so it is "remote" to the relay guard.
  await new Promise((r) => storage.listen(0, "127.0.0.1", r));
  storageUrl = `http://localhost:${storage.address().port}/courses/c1/recordings/clip.mp4?X-Amz-Signature=abc`;
});

afterAll(async () => {
  await new Promise((r) => storage.close(r));
  fs.rmSync(tmp, { recursive: true, force: true });
});
beforeEach(() => { requests.length = 0; });

const durationOf = (file) => {
  const out = String(spawnSync(ffmpegPath, ["-i", file]).stderr);
  const m = /Duration: (\d+):(\d+):([\d.]+)/.exec(out);
  return Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]);
};

describe("ffmpeg never reads a remote address directly", () => {
  test("runFfmpeg refuses an https:// input (it would crash the function)", async () => {
    await expect(runFfmpeg(["-i", "https://bucket.r2.example/x.mp4", "-f", "null", "-"]))
      .rejects.toThrow("use withRelay()");
  });

  test("a concat list with https:// lines is refused", () => {
    expect(() => writeConcatList(path.join(tmp, "l.txt"), ["https://bucket.r2.example/seg_00000.ts"]))
      .toThrow("use withRelay()");
  });
});

describe("withRelay", () => {
  test("gives a numeric local address that keeps the file type, and forgets it afterwards", async () => {
    let local;
    await withRelay(async (toLocal) => {
      local = toLocal(storageUrl);
      expect(local).toMatch(/^http:\/\/127\.0\.0\.1:\d+\/1\/media\.mp4$/);
      expect(relayTargetOf(local)).toBe(storageUrl);
    });
    expect(relayTargetOf(local)).toBeUndefined();
  });

  test("forwards byte ranges both ways (needed for seeking)", async () => {
    await withRelay(async (toLocal) => {
      const res = await fetch(toLocal(storageUrl), { headers: { range: "bytes=10-19" } });
      expect(res.status).toBe(206);
      expect(res.headers.get("content-range")).toMatch(/^bytes 10-19\//);
      expect((await res.arrayBuffer()).byteLength).toBe(10);
    });
    expect(requests).toEqual([{ url: "/courses/c1/recordings/clip.mp4?X-Amz-Signature=abc", range: "bytes=10-19" }]);
  });

  test("passes storage errors through and refuses unknown addresses", async () => {
    await withRelay(async (toLocal) => {
      const missing = toLocal(storageUrl.replace("clip.mp4", "gone.mp4"));
      expect((await fetch(missing)).status).toBe(404);
      const base = missing.replace(/\/\d+\/media\.mp4$/, "");
      expect((await fetch(`${base}/99/media.mp4`)).status).toBe(404);
    });
  });

  test("is closed after the work, even when the work fails", async () => {
    let local;
    await expect(withRelay(async (toLocal) => {
      local = toLocal(storageUrl);
      throw new Error("ffmpeg failed");
    })).rejects.toThrow("ffmpeg failed");
    await expect(fetch(local)).rejects.toThrow();
  });
});

describe("the real ffmpeg through the relay", () => {
  test("converts a slice from the middle (seek before -i, like the 20-minute pieces)", async () => {
    const out = path.join(tmp, "slice.ts");
    await withRelay((toLocal) => runFfmpeg(["-y", "-v", "error",
      "-ss", "2", "-t", "3", "-i", toLocal(storageUrl),
      "-vf", "scale=-2:120", "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", "-f", "mpegts", out]));
    expect(durationOf(out)).toBeGreaterThan(2.5);
    expect(durationOf(out)).toBeLessThan(3.6);
    expect(requests.some((r) => r.range && r.range !== "bytes=0-")).toBe(true); // it really seeked
  });

  test("joins pieces listed by relay address into one MP4 (the rebuild / final join)", async () => {
    const pieces = [0, 1].map((i) => path.join(tmp, `piece${i}.ts`));
    for (const [i, p] of pieces.entries()) {
      await withRelay((toLocal) => runFfmpeg(["-y", "-v", "error", "-ss", String(i * 3), "-t", "3",
        "-i", toLocal(storageUrl), "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", "-f", "mpegts", p]));
    }
    // Serve the two pieces from "storage" too, then join them through the relay.
    const pieceServer = http.createServer((req, res) => {
      const file = pieces[Number(/piece(\d)/.exec(req.url)[1])];
      res.writeHead(200, { "content-type": "video/mp2t" });
      res.end(fs.readFileSync(file));
    });
    await new Promise((r) => pieceServer.listen(0, "127.0.0.1", r));
    const base = `http://localhost:${pieceServer.address().port}/recording-segments/c1/1/`;
    const list = path.join(tmp, "list.txt");
    const joined = path.join(tmp, "joined.mp4");
    try {
      await withRelay((toLocal) => {
        writeConcatList(list, [`${base}piece0.ts?sig=1`, `${base}piece1.ts?sig=2`].map(toLocal));
        return joinParts(list, joined);
      });
    } finally {
      await new Promise((r) => pieceServer.close(r));
    }
    expect(durationOf(joined)).toBeGreaterThan(5.5);
  });
});
