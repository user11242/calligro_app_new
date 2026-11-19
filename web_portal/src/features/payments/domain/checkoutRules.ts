/**
 * When the web may open a Whop checkout for a course. Checked on the server
 * BEFORE the student pays, so nobody is charged for something we would refuse.
 * The capacity and commission rules match the app's server (functions/purchases.js).
 */
export type CheckoutBlock =
  | "course_not_found"
  | "invalid_price"
  | "already_enrolled"
  | "course_full"
  | "commission_not_set";

type Doc = Record<string, any> | undefined | null;

export function enrolledIds(course: Doc): string[] {
  return Array.isArray(course?.enrolledStudents) ? course!.enrolledStudents : [];
}

/** Full when maxStudents is set and reached; someone already enrolled is never blocked by it. */
export function isCourseFull(course: Doc, userId: string): boolean {
  const max = Number(course?.maxStudents || 0);
  if (max <= 0 || enrolledIds(course).includes(userId)) return false;
  return Math.max(Number(course?.enrolledCount || 0), enrolledIds(course).length) >= max;
}

/**
 * Why this student may not buy this course now, or null when they may.
 * [teacher] is the teacher's users/{id} document (undefined when there is none):
 * the commission rate is the one the admin sets in the app.
 */
export function checkoutBlock(course: Doc, teacher: Doc, userId: string): CheckoutBlock | null {
  if (!course) return "course_not_found";
  const price = Number(course.price || 0);
  if (!Number.isFinite(price) || price <= 0) return "invalid_price";
  if (enrolledIds(course).includes(userId)) return "already_enrolled";
  if (isCourseFull(course, userId)) return "course_full";
  if (teacher && (teacher.commissionRate === undefined || teacher.commissionRate === null)) return "commission_not_set";
  return null;
}

/** The message (locale key) a buyer sees for each refusal. "No payment was taken" in each. */
export const BLOCK_MESSAGE_KEY: Record<CheckoutBlock, string> = {
  course_not_found: "checkout.blocked_unavailable",
  invalid_price: "checkout.blocked_unavailable",
  commission_not_set: "checkout.blocked_unavailable",
  course_full: "checkout.blocked_full",
  already_enrolled: "checkout.blocked_enrolled",
};

/** The locale key for a create-checkout refusal code, or null for any other error. */
export function blockMessageKey(code: unknown): string | null {
  return typeof code === "string" && code in BLOCK_MESSAGE_KEY ? BLOCK_MESSAGE_KEY[code as CheckoutBlock] : null;
}
