/**
 * Structure guard-rails for the web portal (fail when the rules are broken).
 */
import { describe, it, expect } from "vitest";
import fs from "fs";
import path from "path";

const SRC = path.join(__dirname, "../src");
function files(dir = SRC): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? files(p) : /\.(ts|tsx)$/.test(e.name) ? [p] : [];
  });
}
const rel = (p: string) => path.relative(path.join(__dirname, ".."), p);
const all = files().map((p) => ({ path: rel(p), code: fs.readFileSync(p, "utf8") }));
const isClient = (code: string) => /^\s*["']use client["']/.test(code);
const isServerAction = (code: string) => /^\s*["']use server["']/.test(code);

describe("the admin key never reaches the browser", () => {
  it("no client file imports admin-key code (firebaseAdmin or *.server)", () => {
    for (const f of all.filter((f) => isClient(f.code))) {
      expect(/from\s+["'][^"']*(firebaseAdmin|\.server)["']/.test(f.code), f.path).toBe(false);
    }
  });
});

describe("server actions check who is calling", () => {
  it("every server action that uses the admin key verifies the caller first", () => {
    for (const f of all.filter((f) => isServerAction(f.code) && /adminDb|adminAuth/.test(f.code))) {
      expect(/callerFromToken|verifyIdToken/.test(f.code), `${f.path} uses the admin key without checking the caller`).toBe(true);
    }
  });

  it("certificate actions take the caller's ID token first", () => {
    const code = fs.readFileSync(path.join(SRC, "app/actions/certificates.ts"), "utf8");
    for (const fn of ["issueCertificateAction", "issueAllPendingCertificatesAction", "getTeacherCertificatesDataAction"]) {
      expect(new RegExp(`export async function ${fn}\\(idToken: string`).test(code), fn).toBe(true);
    }
  });
});
