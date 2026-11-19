/**
 * Certificates on the server (admin key), against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd web_portal && npx vitest run tests/features/certificates"
 *
 * THE HOLE: the server actions used the admin key without checking who was
 * calling, so anyone could issue a certificate for any student or read a
 * teacher's student list. Now every call carries the caller.
 */
import { describe, it, expect, beforeEach, afterAll } from "vitest";
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
import * as admin from "firebase-admin";
import {
  issueCertificate,
  issueAllPendingCertificates,
  loadTeacherCertificates,
  callerFromToken,
  CertificateRefused,
} from "../../../src/features/certificates/server/certificates.server";

const app = admin.initializeApp({ projectId: "demo-calligro-certs" }, "certificates-test");
const db = app.firestore();
const get = async (p: string) => (await db.doc(p).get()).data();
const student = { uid: "s1", isAdmin: false };
const otherStudent = { uid: "s2", isAdmin: false };
const outsider = { uid: "x", isAdmin: false };
const teacher = { uid: "t1", isAdmin: false };
const otherTeacher = { uid: "t2", isAdmin: false };
const platformAdmin = { uid: "a1", isAdmin: true };

async function wipe() {
  for (const c of ["courses", "users", "certificates"]) {
    for (const d of await db.collection(c).listDocuments()) await d.delete();
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc("courses/c1").set({ courseName: "Thuluth", teacherId: "t1", enrolledStudents: ["s1", "s2"] });
  await db.doc("courses/c2").set({ courseName: "Naskh", teacherId: "t2", enrolledStudents: ["s1"] });
  await db.doc("users/s1").set({ name: "Sara", email: "sara@x.com", role: "student" });
  await db.doc("users/s2").set({ name: "Omar", email: "omar@x.com", role: "student" });
  await db.doc("users/t1").set({ name: "Ustadh Ali", role: "teacher" });
  await db.doc("users/a1").set({ name: "Admin", role: "admin" });
});
afterAll(() => app.delete());

describe("issueCertificate", () => {
  it("a student issues THEIR OWN certificate for a course they are in (as before)", async () => {
    const r = await issueCertificate(db, student, { courseId: "c1", studentId: "s1" });
    expect(r).toMatchObject({ success: true, isNew: true });
    const cert = (await db.collection("certificates").get()).docs[0].data();
    expect(cert).toMatchObject({ studentId: "s1", studentName: "Sara", courseId: "c1", courseName: "Thuluth", teacherId: "t1" });
  });

  it("asking again returns the same certificate (no duplicate)", async () => {
    const a = await issueCertificate(db, student, { courseId: "c1", studentId: "s1" });
    const b = await issueCertificate(db, student, { courseId: "c1", studentId: "s1" });
    expect(b).toMatchObject({ success: true, isNew: false });
    expect(b.certificate!.id).toBe(a.certificate!.id);
    expect((await db.collection("certificates").get()).size).toBe(1);
  });

  it("THE HOLE: a student cannot issue one for someone else; an outsider cannot issue at all", async () => {
    await expect(issueCertificate(db, student, { courseId: "c1", studentId: "s2" })).rejects.toBeInstanceOf(CertificateRefused);
    await expect(issueCertificate(db, outsider, { courseId: "c1", studentId: "x" })).rejects.toBeInstanceOf(CertificateRefused);
    expect((await db.collection("certificates").get()).size).toBe(0);
  });

  it("the course teacher and an admin issue for an enrolled student; another teacher cannot", async () => {
    await expect(issueCertificate(db, teacher, { courseId: "c1", studentId: "s2" })).resolves.toMatchObject({ success: true });
    await expect(issueCertificate(db, platformAdmin, { courseId: "c1", studentId: "s1" })).resolves.toMatchObject({ success: true });
    await expect(issueCertificate(db, otherTeacher, { courseId: "c1", studentId: "s1" })).rejects.toBeInstanceOf(CertificateRefused);
  });

  it("only for students enrolled in the course", async () => {
    await expect(issueCertificate(db, teacher, { courseId: "c1", studentId: "x" })).rejects.toBeInstanceOf(CertificateRefused);
  });

  it("the names on the certificate come from the server, not from the browser (no forged names)", async () => {
    await issueCertificate(db, student, { courseId: "c1", studentId: "s1", studentName: "Somebody Famous", courseName: "Fake", teacherId: "t2" } as any);
    const cert = (await db.collection("certificates").get()).docs[0].data();
    expect(cert).toMatchObject({ studentName: "Sara", courseName: "Thuluth", teacherId: "t1" });
  });

  it("unknown course or missing ids: refused", async () => {
    await expect(issueCertificate(db, teacher, { courseId: "nope", studentId: "s1" })).rejects.toBeInstanceOf(CertificateRefused);
    await expect(issueCertificate(db, teacher, { courseId: "", studentId: "s1" })).rejects.toBeInstanceOf(CertificateRefused);
  });
});

describe("issueAllPendingCertificates", () => {
  it("the course teacher issues for every enrolled student without one", async () => {
    await issueCertificate(db, student, { courseId: "c1", studentId: "s1" });
    const r = await issueAllPendingCertificates(db, teacher, "c1");
    expect(r).toMatchObject({ success: true, count: 1 });
    expect(r.certificates!.map((c) => c.studentId)).toEqual(["s2"]);
    expect(r.certificates![0]).toMatchObject({ studentName: "Omar", teacherId: "t1", courseName: "Thuluth" });
  });

  it("an admin may too; students and other teachers may not", async () => {
    await expect(issueAllPendingCertificates(db, platformAdmin, "c1")).resolves.toMatchObject({ success: true, count: 2 });
    await wipe();
    await db.doc("courses/c1").set({ courseName: "Thuluth", teacherId: "t1", enrolledStudents: ["s1", "s2"] });
    await expect(issueAllPendingCertificates(db, student, "c1")).rejects.toBeInstanceOf(CertificateRefused);
    await expect(issueAllPendingCertificates(db, otherTeacher, "c1")).rejects.toBeInstanceOf(CertificateRefused);
    expect((await db.collection("certificates").get()).size).toBe(0);
  });
});

describe("loadTeacherCertificates", () => {
  it("a teacher loads their own courses, certificates and students (as before)", async () => {
    await issueCertificate(db, teacher, { courseId: "c1", studentId: "s1" });
    const r = await loadTeacherCertificates(db, teacher, "t1");
    expect(r.success).toBe(true);
    expect(r.courses!.map((c: any) => c.id)).toEqual(["c1"]);
    expect(r.certificates).toHaveLength(1);
    expect(r.studentsByCourse!.c1.map((s: any) => s.name)).toEqual(["Sara", "Omar"]);
  });

  it("THE HOLE: nobody else can read a teacher's student list (an admin can)", async () => {
    await expect(loadTeacherCertificates(db, otherTeacher, "t1")).rejects.toBeInstanceOf(CertificateRefused);
    await expect(loadTeacherCertificates(db, student, "t1")).rejects.toBeInstanceOf(CertificateRefused);
    await expect(loadTeacherCertificates(db, platformAdmin, "t1")).resolves.toMatchObject({ success: true });
  });
});

describe("who is calling (the ID token)", () => {
  const fakeAuth = (tokens: Record<string, string>) => ({
    verifyIdToken: async (t: string) => {
      if (!tokens[t]) throw new Error("invalid token");
      return { uid: tokens[t] };
    },
  });

  it("a valid token → that user; admins are recognised from their profile", async () => {
    const auth = fakeAuth({ tok_s1: "s1", tok_a1: "a1" });
    await expect(callerFromToken(auth, db, "tok_s1")).resolves.toEqual({ uid: "s1", isAdmin: false });
    await expect(callerFromToken(auth, db, "tok_a1")).resolves.toEqual({ uid: "a1", isAdmin: true });
  });

  it("no token or a bad one → refused", async () => {
    const auth = fakeAuth({});
    await expect(callerFromToken(auth, db, "")).rejects.toBeInstanceOf(CertificateRefused);
    await expect(callerFromToken(auth, db, "forged")).rejects.toBeInstanceOf(CertificateRefused);
  });
});
