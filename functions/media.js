/**
 * Video tools shared by the recording converter (transcoder.js) and the recording
 * safety net (recording_safety.js): R2 access, running ffmpeg, and joining pieces.
 */
const { S3Client } = require("@aws-sdk/client-s3");
const ffmpegPath = require("ffmpeg-static");
const { spawn } = require("child_process");
const fs = require("fs");
const http = require("http");
const https = require("https");

const BUCKET = "calligro-recordings";

function makeS3(secrets) {
  return new S3Client({
    region: "auto",
    endpoint: secrets.endpoint,
    credentials: { accessKeyId: secrets.accessKey, secretAccessKey: secrets.secretKey },
  });
}

/**
 * The ffmpeg-static Linux build links glibc statically, so it cannot look up host
 * names: given an https:// address it crashes (signal 11) on Cloud Functions.
 * So ffmpeg only ever reads files or this numeric local address, never a host name.
 */
const RELAY_HOST = "127.0.0.1";
const isRemote = (s) => typeof s === "string" && /^https?:\/\//i.test(s) && !s.startsWith(`http://${RELAY_HOST}:`);

/**
 * Runs [fn] with a local relay: `local(url)` gives an http://127.0.0.1 address that
 * forwards ffmpeg's reads (and byte ranges, so seeking works) to [url], resolved by Node.
 * The relay is closed when [fn] settles.
 */
/** Every open relay address → the address it forwards to (read by the tests). */
const relayed = new Map();
const relayTargetOf = (localUrl) => relayed.get(localUrl);

async function withRelay(fn) {
  const targets = new Map();
  const issued = [];
  const server = http.createServer((req, res) => {
    const target = targets.get(req.url.split("/")[1]);
    if (!target || !["GET", "HEAD"].includes(req.method)) {
      res.writeHead(404).end();
      return;
    }
    const headers = req.headers.range ? { range: req.headers.range } : {};
    const client = target.startsWith("https:") ? https : http;
    const upstream = client.request(target, { method: req.method, headers }, (up) => {
      res.writeHead(up.statusCode, up.headers);
      up.pipe(res);
    });
    upstream.on("error", () => res.destroy());
    req.on("close", () => upstream.destroy());
    upstream.end();
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, RELAY_HOST, resolve);
  });
  const { port } = server.address();
  const local = (url) => {
    const id = String(targets.size + 1);
    targets.set(id, url);
    // Keep the file extension: ffmpeg uses it to recognise the format.
    const ext = (/\.([a-z0-9]{1,5})(?:\?|$)/i.exec(new URL(url).pathname) || [])[0] || "";
    const address = `http://${RELAY_HOST}:${port}/${id}/media${ext}`;
    relayed.set(address, url);
    issued.push(address);
    return address;
  };
  try {
    return await fn(local);
  } finally {
    issued.forEach((a) => relayed.delete(a));
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}

/** Runs ffmpeg with [args]; rejects with the end of its error output. */
function runFfmpeg(args) {
  const remote = args.find(isRemote);
  if (remote) return Promise.reject(new Error("ffmpeg must not read a remote address directly: use withRelay()"));
  return new Promise((resolve, reject) => {
    const proc = spawn(ffmpegPath, args);
    let stderr = "";
    proc.stderr.on("data", (d) => { stderr = (stderr + d.toString()).slice(-2000); });
    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited with code ${code}: ${stderr.slice(-300)}`));
    });
  });
}

/** Writes an ffmpeg concat list: one `file '<url>'` line per piece, in order. */
function writeConcatList(listPath, urls) {
  if (urls.some(isRemote)) throw new Error("ffmpeg must not read a remote address directly: use withRelay()");
  const quote = (u) => `file '${u.replace(/'/g, "'\\''")}'`;
  fs.writeFileSync(listPath, urls.map(quote).join("\n") + "\n");
}

/** Joins MPEG-TS pieces listed in [listPath] (in order) into one MP4, without re-encoding. */
function joinParts(listPath, outputPath) {
  return runFfmpeg([
    "-y",
    "-protocol_whitelist", "file,http,https,tcp,tls,crypto",
    "-f", "concat", "-safe", "0",
    "-i", listPath,
    "-c", "copy", "-bsf:a", "aac_adtstoasc",
    "-movflags", "+faststart",
    outputPath,
  ]);
}

/** Removes local temp files, ignoring ones that were never created. */
function removeFiles(...paths) {
  for (const p of paths) {
    try { fs.unlinkSync(p); } catch (_) { /* not created */ }
  }
}

module.exports = { BUCKET, makeS3, runFfmpeg, withRelay, relayTargetOf, writeConcatList, joinParts, removeFiles };
