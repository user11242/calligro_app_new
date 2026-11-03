export interface CreateCheckoutParams {
  courseId: string;
  courseName: string;
  amount: number;
  userId: string;
  teacherId?: string;
  redirectUrl?: string;
}

export async function createWhopCheckout(params: CreateCheckoutParams) {
  const rawApiKey =
    process.env.WHOP_API_KEY ||
    "apik_Ta7ofXZxGNm21_C7847943_C_e8fb6aaf66eef06e22a9af3f54513954dd8425ab230ed3a62dd106f87b577b";
  const apiKey = rawApiKey.replace(/['"]/g, "").trim();

  const rawCompanyId = process.env.WHOP_COMPANY_ID || "biz_TtxhlwxC6B0RBZ";
  const companyId = rawCompanyId.replace(/['"]/g, "").trim();

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
    const errorMessage =
      data.error?.message ||
      data.message ||
      (typeof data.error === "string" ? data.error : JSON.stringify(data.error || data)) ||
      "Failed to create Whop checkout configuration";
    throw new Error(errorMessage);
  }

  return {
    id: data.id,
    purchaseUrl: data.purchase_url,
  };
}
