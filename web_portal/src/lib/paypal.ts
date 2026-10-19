let cachedToken: { token: string; expiresAt: number } | null = null;

const PAYPAL_API = process.env.PAYPAL_API_URL || "https://api-m.paypal.com";

export async function getPayPalAccessToken(): Promise<string> {
  const clientId = process.env.NEXT_PUBLIC_PAYPAL_CLIENT_ID?.trim();
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET?.trim();

  if (!clientId || !clientSecret) {
    throw new Error("Missing PayPal credentials. Please configure NEXT_PUBLIC_PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET in environment variables.");
  }

  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 60000) {
    return cachedToken.token;
  }

  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const response = await fetch(`${PAYPAL_API}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to authenticate with PayPal: ${response.status} ${errorText}`);
  }

  const data = await response.json();
  cachedToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in || 3600) * 1000,
  };

  return data.access_token;
}

export async function createPayPalOrder(params: {
  amount: number;
  courseId: string;
  courseName: string;
  userId: string;
}) {
  const token = await getPayPalAccessToken();

  const formattedAmount = params.amount.toFixed(2);

  const response = await fetch(`${PAYPAL_API}/v2/checkout/orders`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      intent: "CAPTURE",
      purchase_units: [
        {
          reference_id: params.courseId,
          custom_id: `${params.userId}:::${params.courseId}`,
          description: params.courseName.slice(0, 127),
          amount: {
            currency_code: "USD",
            value: formattedAmount,
            breakdown: {
              item_total: {
                currency_code: "USD",
                value: formattedAmount,
              },
            },
          },
          items: [
            {
              name: params.courseName.slice(0, 127),
              unit_amount: {
                currency_code: "USD",
                value: formattedAmount,
              },
              quantity: "1",
              category: "DIGITAL_GOODS",
            },
          ],
        },
      ],
      application_context: {
        brand_name: "Calligro Academy",
        landing_page: "NO_PREFERENCE",
        user_action: "PAY_NOW",
        shipping_preference: "NO_SHIPPING",
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`PayPal Create Order Error: ${response.status} ${errorText}`);
  }

  return response.json();
}

export async function getPayPalOrder(orderId: string) {
  const token = await getPayPalAccessToken();

  const response = await fetch(`${PAYPAL_API}/v2/checkout/orders/${orderId}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`PayPal Get Order Error: ${response.status} ${errorText}`);
  }

  return response.json();
}

export async function capturePayPalOrder(orderId: string) {
  const token = await getPayPalAccessToken();

  const response = await fetch(`${PAYPAL_API}/v2/checkout/orders/${orderId}/capture`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    // If order was already captured, check order status
    if (errorText.includes("ORDER_ALREADY_CAPTURED")) {
      return await getPayPalOrder(orderId);
    }
    throw new Error(`PayPal Capture Order Error: ${response.status} ${errorText}`);
  }

  return response.json();
}
