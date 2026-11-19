/**
 * The browser's reads for buying (Firestore client SDK against the emulator,
 * through the real security rules):
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd web_portal && npx vitest run tests/features/payments/payment_courses_data.test.ts"
 */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
import * as admin from "firebase-admin";
import { initializeApp, deleteApp } from "firebase/app";
import { getFirestore, connectFirestoreEmulator } from "firebase/firestore";
import { getCourse, getTeacher, watchCourse } from "../../../src/features/payments/data/paymentCourses";

const PROJECT = "demo-calligro";
const adminApp = admin.initializeApp({ projectId: PROJECT }, "payment-courses-admin");
const clientApp = initializeApp({ projectId: PROJECT, apiKey: "demo" }, "payment-courses-client");
const db = getFirestore(clientApp);
connectFirestoreEmulator(db, "127.0.0.1", 8080);

beforeAll(async () => {
  await adminApp.firestore().doc("courses/pc1").set({ courseName: "Thuluth", teacherId: "pt1", price: 100, enrolledStudents: [] });
  await adminApp.firestore().doc("users/pt1").set({ name: "Ustadh Ali", role: "teacher" });
});
afterAll(async () => {
  await adminApp.firestore().doc("courses/pc1").delete();
  await adminApp.firestore().doc("users/pt1").delete();
  await adminApp.delete();
  await deleteApp(clientApp);
});

describe("paymentCourses (signed out — courses and profiles are public)", () => {
  it("getCourse: the course with its id; a missing course → null", async () => {
    expect(await getCourse(db, "pc1")).toMatchObject({ id: "pc1", courseName: "Thuluth", teacherId: "pt1", price: 100 });
    expect(await getCourse(db, "nope")).toBeNull();
  });

  it("getTeacher: the teacher's profile; none → null", async () => {
    expect(await getTeacher(db, "pt1")).toMatchObject({ name: "Ustadh Ali" });
    expect(await getTeacher(db, "")).toBeNull();
  });

  it("watchCourse: live updates (the success page waits for the enrolment to appear)", async () => {
    const seen: string[][] = [];
    const stop = watchCourse(db, "pc1", (c) => seen.push(c?.enrolledStudents ?? []));
    await new Promise((r) => setTimeout(r, 300));
    await adminApp.firestore().doc("courses/pc1").update({ enrolledStudents: ["s1"] });
    await new Promise((r) => setTimeout(r, 500));
    stop();
    expect(seen[0]).toEqual([]);
    expect(seen[seen.length - 1]).toEqual(["s1"]);
  });
});
