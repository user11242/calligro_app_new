export interface CreateCheckoutParams {
  courseId: string;
  courseName: string;
  amount: number;
  userId: string;
  teacherId?: string;
  redirectUrl?: string;
}

export async function createWhopCheckout(params: CreateCheckoutParams) {
  const apiKey = process.env.WHOP_API_KEY;
  const companyId = process.env.WHOP_COMPANY_ID || "biz_TtxhlwxC6B0RBZ";

  if (!apiKey) {
    throw new Error("WHOP_API_KEY is not configured in environment variables");
  }

  const appUrl = process.env.NEXT_PUBLIC_APP_URL || "https://calligroacademy.com";
  const redirectUrl = params.redirectUrl || `${appUrl}/courses/${params.courseId}/success`;

  const payload = {
    company_id: companyId,
    variant: {
      title: params.courseName,
      billing_type: "one_time",
      initial_price: Number(params.amount.toFixed(2)),
      currency: "usd",
    },
    metadata: {
      courseId: params.courseId,
      userId: params.userId,
      teacherId: params.teacherId || "",
    },
    redirect_url: redirectUrl,
  };

  const response = await fetch("https://api.whop.com/api/v1/checkout_configurations", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Api-Version-Date": "2026-11-02",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data = await response.json();

  if (!response.ok || !data.purchase_url) {
    console.error("Whop API Error:", data);
    throw new Error(data.message || data.error || "Failed to create Whop checkout configuration");
  }

  return {
    id: data.id,
    purchaseUrl: data.purchase_url,
  };
}
