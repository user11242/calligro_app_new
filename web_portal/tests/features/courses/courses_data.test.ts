/**
 * Course and teacher reads in the browser (client SDK on the emulator, real rules):
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd web_portal && npx vitest run tests/features/courses/courses_data.test.ts"
 */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
import * as admin from "firebase-admin";
import { initializeApp, deleteApp } from "firebase/app";
import { getFirestore, connectFirestoreEmulator } from "firebase/firestore";
import {
  getCourse,
  watchCourse,
  watchCatalog,
  getFeaturedCourses,
  watchTeacherCourses,
  watchTeacherCourseCount,
} from "../../../src/features/courses/data/courses";
import { getTeacher, watchTeachers, getFeaturedTeachers } from "../../../src/features/teachers/data/teachers";

const PROJECT = "demo-calligro";
const adminApp = admin.initializeApp({ projectId: PROJECT }, "courses-data-admin");
const adb = adminApp.firestore();
const clientApp = initializeApp({ projectId: PROJECT, apiKey: "demo" }, "courses-data-client");
const db = getFirestore(clientApp);
connectFirestoreEmulator(db, "127.0.0.1", 8080);
const T = (iso: string) => admin.firestore.Timestamp.fromDate(new Date(iso));
const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
const IDS = ["cd1", "cd2", "cd3"];

beforeAll(async () => {
  await adb.doc("users/ct1").set({ name: "Ali", role: "teacher" });
  await adb.doc("users/ct2").set({ name: "Omar", role: "teacher" });
  await adb.doc("courses/cd1").set({ courseName: "Old", teacherId: "ct1", createdAt: T("2026-01-01T00:00:00Z"), enrolledStudents: ["a", "b"] });
  await adb.doc("courses/cd2").set({ courseName: "New", teacherId: "ct1", createdAt: T("2026-06-01T00:00:00Z"), enrolledStudents: ["c"] });
  await adb.doc("courses/cd3").set({ courseName: "Other", teacherId: "ct2", createdAt: T("2026-03-01T00:00:00Z") });
});
afterAll(async () => {
  for (const id of IDS) await adb.doc(`courses/${id}`).delete();
  for (const id of ["ct1", "ct2"]) await adb.doc(`users/${id}`).delete();
  await adminApp.delete();
  await deleteApp(clientApp);
});

describe("courses data (public reads)", () => {
  it("getCourse / missing → null", async () => {
    expect(await getCourse(db, "cd1")).toMatchObject({ id: "cd1", courseName: "Old" });
    expect(await getCourse(db, "nope")).toBeNull();
  });

  it("watchCatalog: every course, newest first, live", async () => {
    let names: string[] = [];
    const stop = watchCatalog(db, (list) => (names = list.filter((c) => IDS.includes(c.id)).map((c) => c.courseName)));
    await wait(400);
    stop();
    expect(names).toEqual(["New", "Other", "Old"]);
  });

  it("getFeaturedCourses: at most N", async () => {
    expect((await getFeaturedCourses(db, 2)).length).toBeLessThanOrEqual(2);
  });

  it("watchTeacherCourses: only that teacher's, newest first", async () => {
    let names: string[] = [];
    const stop = watchTeacherCourses(db, "ct1", (list) => (names = list.map((c) => c.courseName)));
    await wait(400);
    stop();
    expect(names).toEqual(["New", "Old"]);
  });

  it("THE LEAK: after stop() no more updates arrive (the pages never stopped their listeners)", async () => {
    const counts: number[] = [];
    const stop = watchTeacherCourseCount(db, "ct2", (n) => counts.push(n));
    await wait(400);
    stop();
    await adb.doc("courses/cd4").set({ courseName: "Late", teacherId: "ct2" });
    await wait(400);
    await adb.doc("courses/cd4").delete();
    expect(counts).toEqual([1]);
  });

  it("watchCourse: live", async () => {
    const seen: number[] = [];
    const stop = watchCourse(db, "cd3", (c) => seen.push((c?.enrolledStudents ?? []).length));
    await wait(300);
    await adb.doc("courses/cd3").update({ enrolledStudents: ["z"] });
    await wait(400);
    stop();
    expect(seen[0]).toBe(0);
    expect(seen[seen.length - 1]).toBe(1);
  });
});

describe("teachers data (public reads)", () => {
  it("getTeacher: the profile with its uid; none → null", async () => {
    expect(await getTeacher(db, "ct1")).toMatchObject({ uid: "ct1", name: "Ali" });
    expect(await getTeacher(db, "nobody")).toBeNull();
    expect(await getTeacher(db, "")).toBeNull();
  });

  it("watchTeachers: everyone with the teacher role (uid included)", async () => {
    let ids: string[] = [];
    const stop = watchTeachers(db, (list) => (ids = list.map((t) => t.uid).filter((u) => u === "ct1" || u === "ct2")));
    await wait(400);
    stop();
    expect(ids.sort()).toEqual(["ct1", "ct2"]);
  });

  it("getFeaturedTeachers: at most N, each with their student count", async () => {
    const list = await getFeaturedTeachers(db, 10);
    expect(list.find((t) => t.id === "ct1")?.studentsCount).toBe(3);
    expect(list.find((t) => t.id === "ct2")?.studentsCount).toBe(1); // "z" joined cd3 in the watchCourse test above
  });
});
