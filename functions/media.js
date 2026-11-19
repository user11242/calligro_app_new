/**
 * Video tools shared by the recording converter (transcoder.js) and the recording
 * safety net (recording_safety.js): R2 access, running ffmpeg, and joining pieces.
 */
const { S3Client } = require("@aws-sdk/client-s3");
const ffmpegPath = require("ffmpeg-static");
const { spawn } = require("child_process");
const fs = require("fs");

const BUCKET = "calligro-recordings";

function makeS3(secrets) {
  return new S3Client({
    region: "auto",
    endpoint: secrets.endpoint,
    credentials: { accessKeyId: secrets.accessKey, secretAccessKey: secrets.secretKey },
  });
}

/** Runs ffmpeg with [args]; rejects with the end of its error output. */
function runFfmpeg(args) {
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

module.exports = { BUCKET, makeS3, runFfmpeg, writeConcatList, joinParts, removeFiles };
