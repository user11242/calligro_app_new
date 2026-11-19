import { blockMessageKey } from "../domain/checkoutRules";

/** What happened when the buyer pressed "buy". */
export type CheckoutRequestResult =
  | { kind: "redirect"; url: string }
  | { kind: "blocked"; messageKey: string }
  | { kind: "error"; message: string };

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

/**
 * The ONE "buy" step in the browser (the course page and the checkout page each
 * had their own copy): our server checks the course (full, already enrolled,
 * commission set), works out the price and opens a Whop checkout.
 */
export async function requestWhopCheckout(
  { courseId, userId }: { courseId: string; userId: string },
  fetchImpl: FetchLike = fetch,
): Promise<CheckoutRequestResult> {
  try {
    const res = await fetchImpl("/api/whop/create-checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ courseId, userId }),
    });
    const data = await res.json();
    const blocked = blockMessageKey(data.code);
    if (blocked) return { kind: "blocked", messageKey: blocked };
    if (!res.ok || !data.purchaseUrl) {
      const message =
        typeof data.error === "object" && data.error
          ? data.error.message || JSON.stringify(data.error)
          : data.error || "Failed to initialize checkout";
      return { kind: "error", message };
    }
    return { kind: "redirect", url: data.purchaseUrl };
  } catch (err: any) {
    return { kind: "error", message: err?.message || "Failed to open secure checkout" };
  }
}
