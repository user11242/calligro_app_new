/**
 * Whop purchase → enrolment + accounting, against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd web_portal && npx vitest run tests/features/payments/whop_enrollment.test.ts"
 */
import { describe, it, expect, beforeEach, afterAll } from "vitest";
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
import * as admin from "firebase-admin";
import { recordWhopPurchase } from "../../../src/features/payments/server/enrollment.server";
import { parseWhopPayment } from "../../../src/features/payments/server/whopWebhook.server";

const app = admin.initializeApp({ projectId: "demo-calligro-web" }, "whop-enrollment-test");
const db = app.firestore();
const paid = (o: Partial<{ paymentId: string; courseId: string; userId: string; amount: number | null }> = {}) => ({
  kind: "paid" as const, paymentId: "pay_1", courseId: "c1", userId: "s1", amount: 50, currency: "USD", ...o,
});
const get = async (p: string) => (await db.doc(p).get()).data();

async function wipe() {
  for (const c of ["courses", "users", "orders", "transactions", "commissions"]) {
    const docs = await db.collection(c).listDocuments();
    for (const d of docs) {
      for (const sub of await d.listCollections()) for (const x of await sub.listDocuments()) await x.delete();
      await d.delete();
    }
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc("courses/c1").set({ courseName: "Thuluth", teacherId: "t1", teacherName: "Ali", price: 100, enrolledStudents: [], enrolledCount: 0 });
  await db.doc("users/t1").set({ name: "Ali", role: "teacher", commissionRate: 0.6 });
  await db.doc("users/s1").set({ name: "Sara", email: "s@x.com", role: "student" });
});
afterAll(() => app.delete());

describe("recordWhopPurchase", () => {
  it("enrols the student and records order, transaction and the teacher's commission", async () => {
    expect((await recordWhopPurchase(db, paid())).status).toBe("enrolled");
    const course = await get("courses/c1");
    expect(course!.enrolledStudents).toEqual(["s1"]);
    expect(course!.enrolledCount).toBe(1);
    expect((await get("users/s1"))!.enrolledCourses).toEqual(["c1"]);
    expect((await get("users/s1/enrolledCourses/c1"))!.paymentProvider).toBe("whop");
    const order = await get("orders/pay_1");
    expect(order).toMatchObject({ uid: "s1", courseId: "c1", totalPaid: 50, teacherCommission: 30, academyNet: 20, paymentProvider: "whop" });
    expect((await get("transactions/pay_1"))!.amount).toBe(50);
    expect((await get("commissions/pay_1"))!.amount).toBe(30);
    expect((await get("users/t1"))!.pendingBalance).toBe(30);
  });

  it("the same webhook twice changes nothing the second time (Whop retries)", async () => {
    await recordWhopPurchase(db, paid());
    expect((await recordWhopPurchase(db, paid())).status).toBe("duplicate");
    expect((await get("courses/c1"))!.enrolledCount).toBe(1);
    expect((await get("users/t1"))!.pendingBalance).toBe(30);
  });

  it("paying less than the course's web price enrols nobody", async () => {
    expect((await recordWhopPurchase(db, paid({ amount: 1 }))).status).toBe("underpaid");
    expect((await get("courses/c1"))!.enrolledStudents).toEqual([]);
    expect(await get("orders/pay_1")).toBeUndefined();
  });

  it("an unknown course enrols nobody", async () => {
    expect((await recordWhopPurchase(db, paid({ courseId: "nope" }))).status).toBe("course_not_found");
    expect(await get("orders/pay_1")).toBeUndefined();
  });

  it("already enrolled (another payment): recorded, but no second seat or commission", async () => {
    await recordWhopPurchase(db, paid());
    expect((await recordWhopPurchase(db, paid({ paymentId: "pay_2" }))).status).toBe("already_enrolled");
    expect((await get("courses/c1"))!.enrolledCount).toBe(1);
    expect((await get("users/t1"))!.pendingBalance).toBe(30);
    expect(await get("orders/pay_2")).toBeDefined();
  });

  it("no amount in the webhook: accounting uses the course's web price", async () => {
    await recordWhopPurchase(db, paid({ amount: null }));
    expect((await get("orders/pay_1"))!.totalPaid).toBe(50);
  });

  it("concurrent duplicate deliveries still enrol and pay out once", async () => {
    const results = await Promise.all([recordWhopPurchase(db, paid()), recordWhopPurchase(db, paid()), recordWhopPurchase(db, paid())]);
    expect(results.filter((r) => r.status === "enrolled")).toHaveLength(1);
    expect((await get("courses/c1"))!.enrolledCount).toBe(1);
    expect((await get("users/t1"))!.pendingBalance).toBe(30);
  });

  it("a payment that lands after the last seat filled (race): enrolled anyway (they paid), flagged for the admin", async () => {
    await db.doc("courses/c1").set({ maxStudents: 1, enrolledStudents: ["other"], enrolledCount: 1 }, { merge: true });
    const r = await recordWhopPurchase(db, paid());
    expect(r).toEqual({ status: "enrolled", detail: "over_capacity" });
    expect((await get("courses/c1"))!.enrolledStudents).toEqual(["other", "s1"]);
    expect((await get("orders/pay_1"))!.overCapacity).toBe(true);
  });

  it("Whop's current webhook shape end to end: the real paid amount ($50.00 money object) is recorded", async () => {
    const payment = parseWhopPayment({
      type: "payment.succeeded", api_version: "v1", api_version_date: "2026-11-02",
      data: { id: "pay_live", status: "paid", currency: "usd", total: { amount: "50.00", currency: "usd", decimals: 2 }, metadata: { courseId: "c1", userId: "s1", teacherId: "t1" } },
    });
    expect(payment.kind).toBe("paid");
    expect((await recordWhopPurchase(db, payment as any)).status).toBe("enrolled");
    expect((await get("orders/pay_live"))!.totalPaid).toBe(50);
    expect((await get("transactions/pay_live"))!.teacherShare).toBe(30);
  });

  it("Whop's current webhook shape: an underpaid money object enrols nobody", async () => {
    const payment = parseWhopPayment({
      type: "payment.succeeded",
      data: { id: "pay_low", status: "paid", total: { amount: "20.00", currency: "usd" }, metadata: { courseId: "c1", userId: "s1" } },
    });
    expect((await recordWhopPurchase(db, payment as any)).status).toBe("underpaid");
    expect((await get("courses/c1"))!.enrolledStudents).toEqual([]);
  });
});
