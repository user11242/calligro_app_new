"use server";

export async function createCheckoutSession(amount: string, currency: string = "USD") {
  // Test Credentials (to be replaced by ENV variables)
  const ENTITY_ID = "8ac7a4c77092892901709403328e3532";
  const ACCESS_TOKEN = "OGFjN2E0Yzc3MDkyODkyOTAxNzA5NDAzMzI4ZTM1MzJ8SjJmNzlWdU43Ng==";
  const URL = "https://test.oppwa.com/v1/checkouts";

  const data = new URLSearchParams();
  data.append("entityId", ENTITY_ID);
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
