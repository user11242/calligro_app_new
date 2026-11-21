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

describe("feature structure: src/features/<feature>/{domain,data,server,ui}, src/shared, src/app (routes)", () => {
  it("domain code is pure TypeScript: no Firebase, React, Next or other layers", () => {
    for (const f of all.filter((f) => /\/features\/[^/]+\/domain\//.test(f.path))) {
      expect(/from\s+["'](firebase|firebase-admin|react|next)[/"']/.test(f.code), `${f.path}: domain must stay pure`).toBe(false);
      expect(/from\s+["'][^"']*\/(data|server|ui)\//.test(f.code), `${f.path}: domain must not depend on data/server/ui`).toBe(false);
      expect(/@\/shared\/firebase/.test(f.code), `${f.path}: domain must not touch Firebase`).toBe(false);
    }
  });

  it("the admin key is used only in *.server.ts files, API routes and server actions", () => {
    for (const f of all.filter((f) => /firebase-admin|shared\/firebase\/admin\.server/.test(f.code))) {
      const ok = /\.server\.ts$/.test(f.path) || /\/app\/api\/.*\/route\.ts$/.test(f.path) || isServerAction(f.code);
      expect(ok, `${f.path} uses the admin key`).toBe(true);
    }
  });

  it("files in a feature's server/ folder are named *.server.ts", () => {
    for (const f of all.filter((f) => /\/features\/[^/]+\/server\//.test(f.path))) {
      expect(/\.server\.ts$/.test(f.path), f.path).toBe(true);
    }
  });

  it("the old folders do not grow back (lib/components/hooks/context)", () => {
    const old = all.filter((f) => /^src\/(lib|components|hooks|context)\//.test(f.path)).map((f) => f.path);
    // financeService moves into the admin feature in its phase; nothing else may be added here.
    expect(old).toEqual(["src/lib/financeService.ts"]);
  });

  it("pages talking to Firestore directly: a FROZEN list that may only shrink as features move to data/", () => {
    // Moved to feature data layers: checkout + success (payments); home, catalog,
    // course page, teachers list + page (courses / teachers).
    const frozen = new Set([
      "src/app/admin/layout.tsx",
      "src/app/courses/[id]/certificate/page.tsx",
      "src/app/courses/[id]/classroom/page.tsx",
      "src/app/login/page.tsx",
      "src/app/profile/page.tsx",
      "src/app/teacher/(main)/certificates/page.tsx",
      "src/app/teacher/(main)/courses/[id]/page.tsx",
      "src/app/teacher/(main)/courses/page.tsx",
      "src/app/teacher/(main)/dashboard/page.tsx",
      "src/app/teacher/(main)/homeworks/page.tsx",
      "src/app/teacher/(main)/layout.tsx",
      "src/app/teacher/courses/[id]/classroom/page.tsx",
      "src/app/verify/[id]/page.tsx",
      "src/app/verify/page.tsx",
      "src/features/meet/ui/CalligroMeetLayout.tsx",
      "src/shared/ui/Navbar.tsx",
      "src/lib/financeService.ts",
    ]);
    const direct = all
      .filter((f) => /from\s+["']firebase\/firestore["']/.test(f.code))
      .map((f) => f.path)
      .filter((p) => !/\/data\//.test(p) && p !== "src/shared/firebase/client.ts");
    for (const p of direct) expect(frozen.has(p), `${p} talks to Firestore directly: use the feature's data/ layer`).toBe(true);
  });
});


describe("meeting: no weak-connection pop-up", () => {
  it('the "weak connection → switch to audio only?" prompt stays removed (owner\'s decision)', () => {
    const room = fs.readFileSync("src/features/meet/ui/CalligroMeetRoom.tsx", "utf8");
    expect(room).not.toMatch(/ResilienceManager|AudioOnlyPrompt|useConnectionResilience/);
    expect(fs.existsSync("src/features/meet/ui/AudioOnlyPrompt.tsx")).toBe(false);
  });
});
