"use server";

export async function createCheckoutSession(amount: string, currency: string = "USD") {
  // Credentials sourced from ENV variables for security
  const ENTITY_ID = process.env.HYPERPAY_ENTITY_ID;
  const ACCESS_TOKEN = process.env.HYPERPAY_ACCESS_TOKEN;
  const URL = process.env.HYPERPAY_URL || "https://test.oppwa.com/v1/checkouts";

  const data = new URLSearchParams();
  data.append("entityId", ENTITY_ID!);
  data.append("amount", amount);
  data.append("currency", currency);

  try {
    const response = await fetch(URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${ACCESS_TOKEN}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: data.toString(),
    });

    if (!response.ok) {
        const errorData = await response.json();
        console.error("HyperPay API Error:", errorData);
        throw new Error("Failed to initialize payment session");
    }

    const result = await response.json();
    console.log("HyperPay Checkout Success:", result);
    return { checkoutId: result.id };
  } catch (error) {
    console.error("Payment action error:", error);
    throw error;
  }
}
