"use client";
import { useEffect, useState, Suspense } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { doc, getDoc, runTransaction, collection, serverTimestamp } from "firebase/firestore";
import { onAuthStateChanged, User } from "firebase/auth";
import Navbar from "@/components/Navbar";
import {
  Loader2,
  ShieldCheck,
  ArrowLeft,
  CreditCard,
  CheckCircle2,
  Zap,
  Layout,
  LogIn,
  AlertCircle,
  Tag,
  Sparkles,
  X,
  Check,
} from "lucide-react";
import Link from "next/link";
import { PayPalScriptProvider, PayPalButtons, usePayPalScriptReducer } from "@paypal/react-paypal-js";
import { useTranslation } from "@/hooks/useTranslation";
import { db as libDb, auth as libAuth } from "@/lib/firebase";

const PAYPAL_CLIENT_ID =
  process.env.NEXT_PUBLIC_PAYPAL_CLIENT_ID ||
  "BAAOp-NbjzhFx9sgtfJ0rAwMpWUVC_O7Wfqr9trbYDAByogKNqri6HvV2zbKT1-7Wi7HOAMDhusI5MZvjI";

function PayPalButtonsContainer({
  courseId,
  userId,
  joining,
  setJoining,
  setError,
  onSuccess,
}: {
  courseId: string;
  userId: string;
  joining: boolean;
  setJoining: (val: boolean) => void;
  setError: (err: string | null) => void;
  onSuccess: () => void;
}) {
  const [{ isPending, isRejected }] = usePayPalScriptReducer();

  if (isPending) {
    return (
      <div className="w-full py-8 flex flex-col items-center justify-center gap-3">
        <Loader2 className="w-8 h-8 text-primary animate-spin" />
        <p className="text-white/40 text-xs font-bold tracking-widest uppercase">
          Initializing secure payment...
        </p>
      </div>
    );
  }

  if (isRejected) {
    return (
      <div className="w-full p-4 rounded-2xl bg-red-500/10 border border-red-500/30 text-center text-red-400 text-xs font-bold">
        Failed to load payment options. Please check your connection and refresh the page.
      </div>
    );
  }

  return (
    <PayPalButtons
      style={{
        layout: "vertical",
        color: "gold",
        shape: "rect",
        label: "pay",
        height: 48,
      }}
      disabled={joining}
      createOrder={async () => {
        try {
          setError(null);
          const res = await fetch("/api/paypal/create-order", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              courseId,
              userId,
            }),
          });
          const orderData = await res.json();
          if (!res.ok || !orderData.id) {
            throw new Error(orderData.error || "Failed to initialize PayPal order");
          }
          return orderData.id;
        } catch (err: any) {
          console.error("Create Order Error:", err);
          setError(err.message || "Failed to initialize payment.");
          throw err;
        }
      }}
      onApprove={async (data) => {
        try {
          setJoining(true);
          setError(null);
          const res = await fetch("/api/paypal/capture-order", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              orderId: data.orderID,
              courseId,
              userId,
            }),
          });
          const captureData = await res.json();
          if (!res.ok || !captureData.success) {
            throw new Error(captureData.error || "Failed to finalize payment capture");
          }
          onSuccess();
        } catch (err: any) {
          console.error("Capture Error:", err);
          setError(
            err.message || "Payment capture failed. Please check your connection or contact support."
          );
          setJoining(false);
        }
      }}
      onError={(err) => {
        console.error("PayPal Error:", err);
        setError("An error occurred during payment processing. Please try again or use another card.");
        setJoining(false);
      }}
      onCancel={() => {
        setJoining(false);
      }}
    />
  );
}

function CheckoutContent() {
  const { id } = useParams();
  const searchParams = useSearchParams();
  const [course, setCourse] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [authChecking, setAuthChecking] = useState(true);
  const router = useRouter();
  const { t, locale } = useTranslation();
  const [clientId, setClientId] = useState<string>(PAYPAL_CLIENT_ID);

  // Coupon state
  const [couponInput, setCouponInput] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState<string | null>(null);
  const [couponLoading, setCouponLoading] = useState(false);
  const [couponError, setCouponError] = useState<string | null>(null);
  const [couponSuccess, setCouponSuccess] = useState<string | null>(null);

  // Listen to auth state
  useEffect(() => {
    const unsub = onAuthStateChanged(libAuth, (user) => {
      setCurrentUser(user);
      setAuthChecking(false);
    });
    return () => unsub();
  }, []);

  // Fetch runtime PayPal client ID
  useEffect(() => {
    fetch("/api/paypal/config")
      .then((res) => res.json())
      .then((data) => {
        if (data?.clientId) setClientId(data.clientId);
      })
      .catch((err) => console.warn("Using default PayPal client ID", err));
  }, []);

  // Fetch course details
  useEffect(() => {
    if (!id) return;

    const initCheckout = async () => {
      try {
        const docRef = doc(libDb, "courses", id as string);
        const docSnap = await getDoc(docRef);
        if (!docSnap.exists()) {
          setError("Course not found");
          return;
        }
        const courseData = { id: docSnap.id, ...(docSnap.data() as any) };
        setCourse(courseData);

        if (currentUser && courseData.enrolledStudents?.includes(currentUser.uid)) {
          setIsEnrolled(true);
        }
      } catch (err) {
        console.error(err);
        setError("Failed to load course details. Please try refreshing.");
      } finally {
        setLoading(false);
      }
    };

    initCheckout();
  }, [id, currentUser]);

  // Apply Coupon Logic
  const handleApplyCoupon = async (codeToApply?: string) => {
    const code = (codeToApply || couponInput).trim().toUpperCase();
    if (!code) return;

    setCouponLoading(true);
    setCouponError(null);
    setCouponSuccess(null);

    try {
      let idToken = null;
      const user = currentUser || libAuth.currentUser;
      if (user) {
        idToken = await user.getIdToken();
      }

      const res = await fetch("/api/coupon/validate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          couponCode: code,
          courseId: id,
          idToken,
        }),
      });

      const data = await res.json();

      if (!res.ok || !data.valid) {
        setAppliedCoupon(null);
        const errMsg =
          locale === "ar"
            ? data.error_ar || data.error || "كود الكوبون غير صحيح"
            : data.error || "Invalid coupon code";
        setCouponError(errMsg);
        return;
      }

      setAppliedCoupon(code);
      setCouponInput(code);
      const succMsg =
        locale === "ar"
          ? data.description_ar || "تم تطبيق خصم 100% بنجاح"
          : data.description || "100% OFF Free Grant Applied!";
      setCouponSuccess(succMsg);
    } catch (err: any) {
      setCouponError(
        locale === "ar"
          ? "فشل التحقق من الكوبون. يرجى المحاولة مرة أخرى."
          : "Failed to validate coupon. Please try again."
      );
    } finally {
      setCouponLoading(false);
    }
  };

  const handleRemoveCoupon = () => {
    setAppliedCoupon(null);
    setCouponInput("");
    setCouponError(null);
    setCouponSuccess(null);
  };

  // Auto-apply from URL query ?coupon=CALLIGRO100 or ?code=CALLIGRO100
  useEffect(() => {
    const queryCode = searchParams?.get("coupon") || searchParams?.get("code");
    if (queryCode && queryCode.trim().toUpperCase() === "CALLIGRO100" && !appliedCoupon) {
      setCouponInput("CALLIGRO100");
      handleApplyCoupon("CALLIGRO100");
    }
  }, [searchParams, currentUser]);

  // Redeem Free Enrollment with Coupon CALLIGRO100
  const handleRedeemFreeCoupon = async () => {
    const user = currentUser || libAuth.currentUser;
    if (!user) {
      router.push(`/login?redirect=/courses/${id}/checkout?coupon=${appliedCoupon || "CALLIGRO100"}`);
      return;
    }

    setJoining(true);
    setError(null);
    setCouponError(null);

    try {
      const idToken = await user.getIdToken(true);
      const res = await fetch("/api/coupon/redeem", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: id,
          couponCode: appliedCoupon || "CALLIGRO100",
          idToken,
        }),
      });

      const data = await res.json();

      if (!res.ok || !data.success) {
        if (data.requiresAuth) {
          router.push(`/login?redirect=/courses/${id}/checkout?coupon=${appliedCoupon || "CALLIGRO100"}`);
          return;
        }
        const errMsg =
          locale === "ar"
            ? data.error_ar || data.error || "فشل تفعيل الكوبون."
            : data.error || "Failed to redeem free enrollment.";
        throw new Error(errMsg);
      }

      router.push(data.redirectUrl || `/courses/${id}/success`);
    } catch (err: any) {
      console.error("Redeem Coupon Error:", err);
      setError(err.message || "Failed to complete free enrollment.");
      setJoining(false);
    }
  };

  const handleAdminBypass = async () => {
    if (process.env.NODE_ENV !== "development") return;

    try {
      const user = currentUser || libAuth.currentUser;
      if (!user) {
        setError("You must be logged in to join.");
        return;
      }

      setJoining(true);

      await runTransaction(libDb, async (transaction) => {
        const courseRef = doc(libDb, "courses", id as string);
        const transactionRef = doc(collection(libDb, "transactions"));

        const courseSnap = await transaction.get(courseRef);
        if (!courseSnap.exists()) throw new Error("Course not found");

        const courseData = courseSnap.data()!;
        const enrolledStudents = Array.isArray(courseData.enrolledStudents)
          ? [...courseData.enrolledStudents]
          : [];

        if (!enrolledStudents.includes(user.uid)) {
          enrolledStudents.push(user.uid);

          transaction.update(courseRef, {
            enrolledStudents: enrolledStudents,
            enrolledCount: enrolledStudents.length,
          });

          transaction.set(transactionRef, {
            studentId: user.uid,
            studentName:
              user.displayName || user.email?.split("@")[0] || t("nav.student_login").split(" ")[0],
            teacherId: courseData.teacherId || "",
            teacherName: courseData.teacherName || "Unknown Teacher",
            courseId: id as string,
            courseName:
              courseData.courseName ||
              courseData.courseTitle ||
              courseData.title ||
              "Untitled Course",
            amount: 0,
            currency: "USD",
            source: "admin_bypass",
            status: "completed",
            createdAt: serverTimestamp(),
          });
        }
      });

      router.push(`/courses/${id}/classroom`);
    } catch (err) {
      console.error(err);
      setError("Failed to bypass. Please check permissions.");
    } finally {
      setJoining(false);
    }
  };

  const handleQuickJoin = async () => {
    try {
      const user = currentUser || libAuth.currentUser;
      if (!user) {
        setError(t("checkout.login_error"));
        return;
      }

      if (course?.price && Number(course.price) / 2 > 0) {
        setError("Please complete the payment to join this course.");
        return;
      }

      setJoining(true);

      await runTransaction(libDb, async (transaction) => {
        const courseRef = doc(libDb, "courses", id as string);
        const transactionRef = doc(collection(libDb, "transactions"));

        const courseSnap = await transaction.get(courseRef);
        if (!courseSnap.exists()) throw new Error("Course not found");

        const courseData = courseSnap.data()!;
        const enrolledStudents = Array.isArray(courseData.enrolledStudents)
          ? [...courseData.enrolledStudents]
          : [];

        if (!enrolledStudents.includes(user.uid)) {
          enrolledStudents.push(user.uid);

          transaction.update(courseRef, {
            enrolledStudents: enrolledStudents,
            enrolledCount: enrolledStudents.length,
          });

          const grossAmount = Number(courseData.price) / 2 || 0;
          transaction.set(transactionRef, {
            studentId: user.uid,
            studentName:
              user.displayName || user.email?.split("@")[0] || t("nav.student_login").split(" ")[0],
            teacherId: courseData.teacherId || "",
            teacherName: courseData.teacherName || "Unknown Teacher",
            courseId: id as string,
            courseName:
              courseData.courseName ||
              courseData.courseTitle ||
              courseData.title ||
              "Untitled Course",
            amount: grossAmount,
            currency: "USD",
            source: "web_portal_quick",
            status: "completed",
            createdAt: serverTimestamp(),
            teacherShare: 0,
            academyProfit: 0,
            storeFee: 0,
          });
        }
      });

      router.push(`/courses/${id}/classroom`);
    } catch (err) {
      console.error(err);
      setError("Failed to enroll student. Please check permissions or contact support.");
    } finally {
      setJoining(false);
    }
  };

  if (loading || authChecking) {
    return (
      <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center gap-6">
        <Loader2 className="w-12 h-12 text-primary animate-spin" />
        <p className="text-white/40 font-black uppercase tracking-[0.3em] text-xs">
          {t("checkout.loading")}
        </p>
      </div>
    );
  }

  if (error && !course) {
    return (
      <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center gap-6 p-6 text-center">
        <div className="w-20 h-20 bg-red-500/10 rounded-full flex items-center justify-center border border-red-500/20">
          <ShieldCheck className="w-10 h-10 text-red-500" />
        </div>
        <p className="text-red-400 font-bold max-w-xl text-lg">{error || "Something went wrong"}</p>
        <Link
          href={`/courses/${id}`}
          className="btn-gold mt-4 py-4 px-10 border border-white/10 hover:bg-white/5 transition-all text-sm font-black tracking-widest text-[#050505] uppercase"
        >
          {t("checkout.cancel")}
        </Link>
      </div>
    );
  }

  const baseTuition = Number(course?.price || 0) / 2;
  const serviceFee = baseTuition * 0.08;
  const regularPrice = baseTuition * 1.08;
  const isFreeWithCoupon = appliedCoupon === "CALLIGRO100";
  const finalPrice = isFreeWithCoupon ? 0 : regularPrice;

  return (
    <PayPalScriptProvider
      key={clientId}
      options={{
        clientId: clientId,
        currency: "USD",
        intent: "capture",
        components: "buttons",
      }}
    >
      <main className="min-h-screen academy-bg pb-32">
        <Navbar />

        <div className="pt-32 px-6 max-w-5xl mx-auto">
          <Link
            href={`/courses/${id}`}
            className="inline-flex items-center gap-3 text-white/50 hover:text-primary transition-colors mb-12 text-[10px] md:text-xs font-black uppercase tracking-[0.3em] group"
          >
            <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
            {t("checkout.cancel")}
          </Link>

          {/* Abstract Glow Layer */}
          <div className="absolute top-[20%] left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-primary/5 blur-[150px] rounded-full pointer-events-none" />

          {error && (
            <div className="mb-8 p-4 rounded-2xl bg-red-500/10 border border-red-500/30 flex items-center gap-4 text-red-400 text-sm font-bold">
              <AlertCircle className="w-5 h-5 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-16 md:gap-24 relative z-10 w-full items-start">
            <div className="space-y-8">
              {/* Summary Card */}
              <div className="glass-premium p-10 md:p-12 rounded-[48px] border-white/10 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.8)] backdrop-blur-3xl bg-[#0a0a0a]">
                <div className="flex items-center gap-4 mb-8">
                  <Layout className="w-5 h-5 text-primary" />
                  <p className="text-xs font-black text-primary uppercase tracking-[0.3em]">
                    {t("checkout.summary")}
                  </p>
                </div>

                <h1 className="text-3xl md:text-5xl font-black font-outfit text-white mb-4 leading-tight">
                  {course.courseName || course.courseTitle}
                </h1>
                <p className="text-white/50 text-base md:text-lg font-medium">
                  {t("checkout.instructor")} {course.teacherName}
                </p>

                <div className="mt-8 pt-6 border-t border-white/10 space-y-4">
                  <div className="flex justify-between items-center text-sm font-medium">
                    <span className="text-white/60">{t("course.tuition_fee") || "Tuition"}</span>
                    <span className="text-white/90 font-outfit rtl:font-sans">
                      ${baseTuition.toFixed(2)}
                    </span>
                  </div>

                  <div className="flex justify-between items-center text-sm font-medium pb-4 border-b border-white/10">
                    <span className="text-white/60">{t("course.platform_fee") || "Service Fee (8%)"}</span>
                    <span className="text-white/90 font-outfit rtl:font-sans">
                      ${serviceFee.toFixed(2)}
                    </span>
                  </div>

                  {/* 100% Promo Coupon Line if applied */}
                  {isFreeWithCoupon && (
                    <div className="flex justify-between items-center text-xs md:text-sm font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-4 py-3 rounded-2xl">
                      <div className="flex items-center gap-2">
                        <Sparkles className="w-4 h-4 text-emerald-400 shrink-0" />
                        <span>{t("checkout.coupon_applied") || "Coupon Applied (CALLIGRO100)"}</span>
                      </div>
                      <span className="font-outfit rtl:font-sans font-black">
                        -${regularPrice.toFixed(2)} (100%)
                      </span>
                    </div>
                  )}

                  <div className="flex flex-col md:flex-row justify-between md:items-end gap-4 pt-2">
                    <div className="flex flex-col">
                      <span className="text-white/40 text-[10px] font-black uppercase tracking-[0.2em] mb-1">
                        {t("checkout.total")}
                      </span>
                      <span className="text-white/20 text-sm font-bold line-through px-1">
                        ${(Number(course.price) * 1.08).toFixed(0)}
                      </span>
                    </div>
                    <div className="flex flex-col items-end">
                      <span
                        className={`px-3 py-1 rounded-lg text-[8px] font-black uppercase tracking-widest mb-2 border ${
                          isFreeWithCoupon
                            ? "bg-emerald-500/20 text-emerald-400 border-emerald-500/30"
                            : "bg-primary/20 text-primary border-primary/20"
                        }`}
                      >
                        {isFreeWithCoupon
                          ? "100% OFF PROMO"
                          : t("checkout.grant") || "50% ACADEMY GRANT"}
                      </span>
                      <span
                        className={`text-5xl md:text-6xl font-black font-outfit leading-none ${
                          isFreeWithCoupon ? "text-emerald-400" : "gold-text"
                        }`}
                      >
                        ${finalPrice.toFixed(2)}
                      </span>
                    </div>
                  </div>
                </div>

                {!isEnrolled && (course.price === 0 || Number(course.price) === 0) && (
                  <button
                    onClick={handleQuickJoin}
                    disabled={joining}
                    className="w-full mt-10 py-5 bg-white/[0.03] hover:bg-white/10 text-white font-black uppercase tracking-[0.2em] text-xs rounded-[24px] border border-white/10 transition-all flex items-center justify-center gap-4 disabled:opacity-50 shadow-inner"
                  >
                    {joining ? (
                      <Loader2 className="w-5 h-5 animate-spin" />
                    ) : (
                      <CheckCircle2 className="w-5 h-5 text-primary" />
                    )}
                    {t("checkout.join_direct")}
                  </button>
                )}
              </div>

              {/* Coupon / Voucher Redemption Card */}
              {!isEnrolled && (
                <div className="glass-premium p-8 rounded-[36px] border-white/10 bg-[#0a0a0a]/90 backdrop-blur-2xl">
                  <div className="flex items-center gap-3 mb-4">
                    <Tag className="w-4 h-4 text-primary" />
                    <h3 className="text-xs font-black uppercase tracking-[0.25em] text-white/90">
                      {t("checkout.coupon_label") || "Promotional Coupon / Voucher"}
                    </h3>
                  </div>

                  {!appliedCoupon ? (
                    <div className="space-y-3">
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <input
                            type="text"
                            value={couponInput}
                            onChange={(e) => {
                              setCouponInput(e.target.value.toUpperCase());
                              if (couponError) setCouponError(null);
                            }}
                            onKeyDown={(e) => {
                              if (e.key === "Enter") {
                                e.preventDefault();
                                handleApplyCoupon();
                              }
                            }}
                            placeholder={
                              t("checkout.coupon_placeholder") || "Enter promo code (e.g. CALLIGRO100)"
                            }
                            className="w-full bg-white/[0.04] border border-white/10 rounded-2xl px-4 py-3.5 text-xs md:text-sm text-white uppercase placeholder:normal-case placeholder:text-white/20 focus:outline-none focus:border-primary/50 transition-colors font-mono tracking-wider"
                          />
                        </div>
                        <button
                          type="button"
                          onClick={() => handleApplyCoupon()}
                          disabled={couponLoading || !couponInput.trim()}
                          className="px-6 py-3.5 bg-primary/20 hover:bg-primary text-primary hover:text-black font-black uppercase text-xs tracking-wider rounded-2xl border border-primary/30 transition-all disabled:opacity-40 disabled:hover:bg-primary/20 disabled:hover:text-primary flex items-center gap-2"
                        >
                          {couponLoading ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            t("checkout.coupon_apply") || "Apply"
                          )}
                        </button>
                      </div>

                      {couponError && (
                        <p className="text-red-400 text-xs font-bold flex items-center gap-2 pt-1">
                          <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                          <span>{couponError}</span>
                        </p>
                      )}

                      <p className="text-[11px] text-white/35 font-medium leading-relaxed pt-1">
                        {t("checkout.coupon_single_use_notice") ||
                          "Special Launch Grant: 100% OFF (Max 1 course per student account)."}
                      </p>
                    </div>
                  ) : (
                    <div className="flex items-center justify-between p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-emerald-500/20 flex items-center justify-center border border-emerald-500/30">
                          <Check className="w-4 h-4 text-emerald-400" />
                        </div>
                        <div>
                          <p className="text-xs font-black text-white uppercase font-mono tracking-wider">
                            {appliedCoupon}
                          </p>
                          <p className="text-[11px] text-emerald-400 font-bold">
                            {couponSuccess || "100% OFF Grant Active"}
                          </p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={handleRemoveCoupon}
                        className="text-white/40 hover:text-white p-2 transition-colors rounded-xl hover:bg-white/5"
                        title={t("checkout.coupon_remove") || "Remove"}
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  )}
                </div>
              )}

              {isEnrolled && (
                <div className="bg-primary/5 border border-primary/20 p-12 rounded-[48px] flex flex-col items-center gap-6 text-center backdrop-blur-md">
                  <div className="w-20 h-20 bg-primary/10 rounded-[32px] flex items-center justify-center border border-primary/30 shadow-[0_0_30px_rgba(238,229,147,0.2)]">
                    <CheckCircle2 className="w-10 h-10 text-primary" />
                  </div>
                  <div>
                    <h3 className="text-white text-3xl font-black font-outfit mb-3">
                      {t("checkout.enrolled")}
                    </h3>
                    <p className="text-white/50 text-base mb-8 max-w-sm mx-auto">
                      {t("checkout.enrolled_desc")}
                    </p>
                    <Link
                      href={`/courses/${id}/classroom`}
                      className="btn-gold w-full text-base py-5 flex items-center justify-center gap-3 shadow-[0_20px_50px_-10px_rgba(238,229,147,0.3)] hover:animate-none"
                    >
                      <Zap className="w-5 h-5" />
                      {t("checkout.enter_classroom")}
                    </Link>
                  </div>
                </div>
              )}

              <div className="space-y-6 px-4">
                <div className="flex items-center gap-5 text-white/50 text-sm font-bold">
                  <ShieldCheck className="w-6 h-6 text-primary" />
                  {t("checkout.secure_lemon")}
                </div>
                <div className="flex items-center gap-5 text-white/50 text-sm font-bold">
                  <CreditCard className="w-6 h-6 text-primary" />
                  {t("checkout.global_support")}
                </div>
              </div>
            </div>

            <div className="relative">
              {!isEnrolled && course.price > 0 && (
                <div className="glass-premium p-10 md:p-14 rounded-[48px] border-t border-white/10 border-x border-white/5 bg-[#0a0a0a] flex flex-col items-center shadow-[0_30px_80px_-20px_rgba(0,0,0,0.8)]">
                  <div
                    className={`w-24 h-24 rounded-[32px] flex items-center justify-center mb-8 border shadow-[0_0_40px_rgba(238,229,147,0.15)] ${
                      isFreeWithCoupon
                        ? "bg-emerald-500/10 border-emerald-500/30"
                        : "bg-primary/10 border-primary/20"
                    }`}
                  >
                    {isFreeWithCoupon ? (
                      <Sparkles className="w-10 h-10 text-emerald-400" />
                    ) : (
                      <CreditCard className="w-10 h-10 text-primary" />
                    )}
                  </div>

                  <h2 className="text-center text-sm font-black uppercase tracking-[0.3em] mb-4 text-white/90">
                    {isFreeWithCoupon
                      ? locale === "ar"
                        ? "التسجيل المجاني بالمنحة الكاملة"
                        : "100% Promotional Grant"
                      : t("checkout.secure_payment")}
                  </h2>
                  <p className="text-white/40 text-center text-sm md:text-base mb-10 leading-relaxed max-w-xs">
                    {isFreeWithCoupon
                      ? locale === "ar"
                        ? "استخدمت كوبون CALLIGRO100 للحصول على الدورة مجاناً وبشكل دائم."
                        : "You applied coupon CALLIGRO100 for 100% free lifetime access."
                      : t("checkout.secure_desc")}
                  </p>

                  <div className="w-full relative min-h-[120px] flex flex-col items-center justify-center">
                    {joining && (
                      <div className="absolute inset-0 bg-[#0a0a0a]/90 backdrop-blur-sm z-30 flex flex-col items-center justify-center gap-4 rounded-2xl">
                        <Loader2 className="w-8 h-8 text-primary animate-spin" />
                        <p className="text-xs font-black text-white/80 uppercase tracking-widest">
                          {t("checkout.loading")}
                        </p>
                      </div>
                    )}

                    {/* FREE ENROLLMENT WITH COUPON FLOW */}
                    {isFreeWithCoupon ? (
                      !currentUser ? (
                        <div className="w-full space-y-4 text-center">
                          <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-300 text-xs font-bold leading-relaxed">
                            {t("checkout.coupon_login_required") ||
                              "Please log in with your account to claim your free course with coupon CALLIGRO100."}
                          </div>
                          <Link
                            href={`/login?redirect=/courses/${id}/checkout?coupon=CALLIGRO100`}
                            className="btn-gold w-full py-5 text-sm flex items-center justify-center gap-3 font-black uppercase tracking-wider shadow-lg"
                          >
                            <LogIn className="w-5 h-5" />
                            {t("checkout.login_error")}
                          </Link>
                        </div>
                      ) : (
                        <div className="w-full space-y-4">
                          <button
                            onClick={handleRedeemFreeCoupon}
                            disabled={joining}
                            className="w-full py-5 rounded-[24px] bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 hover:from-emerald-400 hover:to-teal-500 text-black font-black uppercase tracking-wider text-sm transition-all duration-300 shadow-[0_15px_40px_-10px_rgba(16,185,129,0.5)] hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center gap-3 disabled:opacity-50"
                          >
                            {joining ? (
                              <Loader2 className="w-5 h-5 animate-spin text-black" />
                            ) : (
                              <>
                                <Sparkles className="w-5 h-5 text-black" />
                                <span>
                                  {t("checkout.coupon_claim_free") || "Enroll Now for Free (100% OFF)"}
                                </span>
                              </>
                            )}
                          </button>
                          <p className="text-center text-[11px] text-white/40 font-medium">
                            {t("checkout.coupon_single_use_notice") ||
                              "Limited to 1 course per registered student account."}
                          </p>
                        </div>
                      )
                    ) : (
                      /* STANDARD PAYPAL FLOW */
                      !currentUser ? (
                        <Link
                          href={`/login?redirect=/courses/${id}/checkout`}
                          className="btn-gold w-full py-5 text-sm flex items-center justify-center gap-3 font-black uppercase tracking-wider"
                        >
                          <LogIn className="w-5 h-5" />
                          {t("checkout.login_error")}
                        </Link>
                      ) : (
                        <div className="w-full">
                          <PayPalButtonsContainer
                            courseId={id as string}
                            userId={currentUser.uid}
                            joining={joining}
                            setJoining={setJoining}
                            setError={setError}
                            onSuccess={() => router.push(`/courses/${id}/success`)}
                          />
                        </div>
                      )
                    )}
                  </div>

                  {process.env.NODE_ENV === "development" && (
                    <button
                      onClick={handleAdminBypass}
                      disabled={joining}
                      className="w-full mt-4 py-4 bg-white/5 hover:bg-white/10 text-white/50 hover:text-white text-[10px] font-black uppercase tracking-[0.2em] rounded-[24px] border border-white/10 transition-all flex items-center justify-center gap-3 disabled:opacity-50"
                    >
                      {joining ? (
                        <Loader2 className="w-5 h-5 animate-spin" />
                      ) : (
                        <ShieldCheck className="w-4 h-4 text-green-500" />
                      )}
                      [ {t("course.admin_bypass")} ]
                    </button>
                  )}

                  <div className="mt-10 flex items-center gap-6 grayscale opacity-30 hover:grayscale-0 hover:opacity-100 transition-all duration-500">
                    <img
                      src="https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg"
                      alt="Visa"
                      className="h-4"
                    />
                    <img
                      src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg"
                      alt="Mastercard"
                      className="h-6"
                    />
                    <img
                      src="https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg"
                      alt="PayPal"
                      className="h-5"
                    />
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </main>
    </PayPalScriptProvider>
  );
}

export default function CheckoutPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center gap-6">
          <Loader2 className="w-12 h-12 text-primary animate-spin" />
        </div>
      }
    >
      <CheckoutContent />
    </Suspense>
  );
}
