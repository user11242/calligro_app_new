/**
 * Before anyone pays: when the web may open a Whop checkout, at what price,
 * and exactly what we send to Whop (checked against Whop's OpenAPI spec,
 * Api-Version-Date 2026-11-02: `account_id` at the top level, an inline `variant`,
 * and `metadata` that Whop copies onto the payment).
 */
import { describe, it, expect, vi, afterEach } from "vitest";
import { checkoutBlock, isCourseFull } from "../../../src/features/payments/domain/checkoutRules";
import { calculateWebPrice, formatPrice } from "../../../src/features/payments/domain/pricing";
import { createWhopCheckout } from "../../../src/features/payments/server/whop.server";

const course = (o: Record<string, unknown> = {}) => ({ price: 100, teacherId: "t1", enrolledStudents: [], enrolledCount: 0, ...o });
const teacher = (o: Record<string, unknown> = {}) => ({ commissionRate: 0.6, ...o });

describe("checkoutBlock: may this student open a checkout?", () => {
  it("a normal course with a rate set: yes", () => {
    expect(checkoutBlock(course(), teacher(), "s1")).toBeNull();
  });
  it("unknown course: no", () => {
    expect(checkoutBlock(undefined, teacher(), "s1")).toBe("course_not_found");
  });
  it("no price: no", () => {
    expect(checkoutBlock(course({ price: 0 }), teacher(), "s1")).toBe("invalid_price");
    expect(checkoutBlock(course({ price: "abc" }), teacher(), "s1")).toBe("invalid_price");
  });
  it("already enrolled: no (would pay twice)", () => {
    expect(checkoutBlock(course({ enrolledStudents: ["s1"], enrolledCount: 1 }), teacher(), "s1")).toBe("already_enrolled");
  });
  it("course full: no", () => {
    expect(checkoutBlock(course({ maxStudents: 2, enrolledStudents: ["a", "b"], enrolledCount: 2 }), teacher(), "s1")).toBe("course_full");
  });
  it("the admin has not set the teacher's rate in the app yet: no (same rule as the app)", () => {
    expect(checkoutBlock(course(), teacher({ commissionRate: undefined }), "s1")).toBe("commission_not_set");
    expect(checkoutBlock(course(), teacher({ commissionRate: null }), "s1")).toBe("commission_not_set");
  });
  it("a rate of 0 is a rate (the admin set it)", () => {
    expect(checkoutBlock(course(), teacher({ commissionRate: 0 }), "s1")).toBeNull();
  });
});

describe("isCourseFull (same rule as the app's server, functions/purchases.js)", () => {
  it("no limit set: never full", () => {
    expect(isCourseFull(course({ enrolledStudents: ["a", "b", "c"] }), "s1")).toBe(false);
  });
  it("uses the larger of enrolledCount and the list", () => {
    expect(isCourseFull(course({ maxStudents: 3, enrolledStudents: ["a"], enrolledCount: 3 }), "s1")).toBe(true);
    expect(isCourseFull(course({ maxStudents: 3, enrolledStudents: ["a", "b", "c"], enrolledCount: 0 }), "s1")).toBe(true);
    expect(isCourseFull(course({ maxStudents: 3, enrolledStudents: ["a", "b"], enrolledCount: 2 }), "s1")).toBe(false);
  });
  it("someone already in the course is never blocked by it being full", () => {
    expect(isCourseFull(course({ maxStudents: 1, enrolledStudents: ["s1"], enrolledCount: 1 }), "s1")).toBe(false);
  });
});

describe("web price (the 8% fee switch is off)", () => {
  it("is half the course price, to the cent (checkout and the webhook's underpaid check use this same function)", () => {
    expect(calculateWebPrice(100)).toBe(50);
    expect(calculateWebPrice(55)).toBe(27.5);
    expect(calculateWebPrice(19.99)).toBe(9.99);
  });
  it("is shown exactly as charged (the cards used to round $27.50 up to $28)", () => {
    expect(formatPrice(calculateWebPrice(55))).toBe("27.50");
    expect(formatPrice(calculateWebPrice(100))).toBe("50");
    expect(formatPrice(0.1 + 0.2)).toBe("0.30");
  });
});

describe("createWhopCheckout: the request Whop receives", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    delete process.env.WHOP_API_KEY;
    delete process.env.WHOP_COMPANY_ID;
  });

  it("sends account_id, a one-time inline variant at the exact price, and our ids as metadata", async () => {
    process.env.WHOP_API_KEY = "test_key";
    process.env.WHOP_COMPANY_ID = "biz_test";
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ id: "ch_1", purchase_url: "https://whop.com/checkout/ch_1" }), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    const out = await createWhopCheckout({ amount: 27.5, courseId: "c1", courseName: "Thuluth for beginners", userId: "s1", teacherId: "t1", redirectUrl: "https://x/success" });

    expect(out).toEqual({ id: "ch_1", purchaseUrl: "https://whop.com/checkout/ch_1" });
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://api.whop.com/api/v1/checkout_configurations");
    expect((init.headers as Record<string, string>)["Api-Version-Date"]).toBe("2026-11-02");
    const body = JSON.parse(String(init.body));
    expect(body.account_id).toBe("biz_test");
    expect(body.company_id).toBeUndefined();
    expect(body.variant).toEqual({ title: "Thuluth for beginners", billing_type: "one_time", initial_price: 27.5, currency: "usd" });
    expect(body.metadata).toEqual({ courseId: "c1", courseName: "Thuluth for beginners", userId: "s1", teacherId: "t1" });
    expect(body.redirect_url).toBe("https://x/success");
  });

  it("no API key: refuses before calling Whop", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
    await expect(createWhopCheckout({ amount: 10, courseId: "c1", courseName: "x", userId: "s1" })).rejects.toThrow(/WHOP_API_KEY/);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("what the buyer is told when checkout is refused", () => {
  it("every refusal has a message that exists in en, ar and tr", async () => {
    const { BLOCK_MESSAGE_KEY, blockMessageKey } = await import("../../../src/features/payments/domain/checkoutRules");
    const locales = ["en", "ar", "tr"].map((l) => require(`../../../src/shared/i18n/locales/${l}.json`));
    for (const key of Object.values(BLOCK_MESSAGE_KEY)) {
      for (const l of locales) expect(typeof l[key], key).toBe("string");
    }
    expect(blockMessageKey("course_full")).toBe("checkout.blocked_full");
    expect(blockMessageKey("something else")).toBeNull();
    expect(blockMessageKey(undefined)).toBeNull();
  });
});
