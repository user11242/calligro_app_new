"use client";
import { useEffect, useState, Suspense } from "react";
import { useParams, useRouter } from "next/navigation";
import { doc, getDoc, runTransaction, collection, serverTimestamp } from "firebase/firestore";
import { onAuthStateChanged, User } from "firebase/auth";
import Navbar from "@/components/Navbar";
import {
  Loader2,
  ShieldCheck,
  ArrowLeft,
  CreditCard,
  Layout,
  LogIn,
  AlertCircle,
  Info,
} from "lucide-react";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";
import { db as libDb, auth as libAuth } from "@/lib/firebase";

function CheckoutContent() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [authChecking, setAuthChecking] = useState(true);
  const router = useRouter();
  const { t, locale } = useTranslation();

  // Listen to auth state
  useEffect(() => {
    const unsub = onAuthStateChanged(libAuth, (user) => {
      setCurrentUser(user);
      setAuthChecking(false);
    });
    return () => unsub();
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

  // Whop Dynamic Checkout (Apple Pay, Google Pay, Credit/Debit Cards)
  const handleWhopCheckout = async () => {
    const user = currentUser || libAuth.currentUser;
    if (!user) {
      router.push(`/login?redirect=/courses/${id}/checkout`);
      return;
    }

    setJoining(true);
    setError(null);

    try {
      const res = await fetch("/api/whop/create-checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: id,
          userId: user.uid,
        }),
      });

      const data = await res.json();
      if (!res.ok || !data.purchaseUrl) {
        const errorMsg =
          typeof data.error === "object"
            ? (data.error.message || JSON.stringify(data.error))
            : (data.error || "Failed to initialize Whop checkout");
        throw new Error(errorMsg);
      }

      window.location.href = data.purchaseUrl;
    } catch (err: any) {
      console.error("Whop Checkout Error:", err);
      setError(err.message || "Failed to open secure checkout");
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
  const finalPrice = regularPrice;

  return (
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

                <div className="flex justify-between items-center text-sm font-medium">
                  <span className="text-white/60">{t("checkout.service_fee")}</span>
                  <span className="text-white/90 font-outfit rtl:font-sans">
                    ${serviceFee.toFixed(2)}
                  </span>
                </div>

                {/* 50% Academy Grant Ribbon */}
                <div className="pt-2">
                  <div className="flex items-center justify-between text-xs font-bold text-primary bg-primary/10 border border-primary/20 px-3 py-2 rounded-xl">
                    <span className="flex items-center gap-1.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" />
                      {t("checkout.grant") || "50% ACADEMY GRANT"}
                    </span>
                    <span>-50%</span>
                  </div>
                </div>

                <div className="pt-6 border-t border-white/10 flex justify-between items-center">
                  <div>
                    <span className="text-base font-bold text-white block">
                      {t("checkout.total_due")}
                    </span>
                    <span className="text-xs text-white/40 block">
                      {t("checkout.one_time_payment")}
                    </span>
                  </div>
                  <div className="text-right">
                    <span className="text-3xl md:text-4xl font-black font-outfit text-primary block">
                      ${finalPrice.toFixed(2)}
                    </span>
                  </div>
                </div>
              </div>

              <div className="mt-6 p-4 rounded-2xl bg-white/5 border border-white/10 flex items-start gap-3">
                <Info className="w-4 h-4 text-primary shrink-0 mt-0.5" />
                <p className="text-xs text-white/60 leading-relaxed">
                  <strong className="text-white block mb-0.5">
                    {t("checkout.grant") || "50% Academy Grant"}
                  </strong>
                  {locale === "ar"
                    ? "تم تطبيق منحة أكاديمية بنسبة 50% على جميع الرسوم لدعم طلابنا حول العالم."
                    : "A 50% academy grant has been applied to all tuition fees to support our students worldwide."}
                </p>
              </div>
            </div>

            <div className="space-y-6 px-4">
              <div className="flex items-center gap-5 text-white/50 text-sm font-bold">
                <ShieldCheck className="w-6 h-6 text-primary" />
                {t("checkout.secure_lemon") || (locale === "ar" ? "دفع آمن بالبطاقات و Apple Pay و Google Pay" : "Secure Payment via Apple Pay, Google Pay & Cards")}
              </div>
              <div className="flex items-center gap-5 text-white/50 text-sm font-bold">
                <CreditCard className="w-6 h-6 text-primary" />
                {t("checkout.global_support")}
              </div>
            </div>
          </div>

          <div className="relative">
            {!isEnrolled && (
              <div className="glass-premium p-10 md:p-14 rounded-[48px] border-t border-white/10 border-x border-white/5 bg-[#0a0a0a] flex flex-col items-center shadow-[0_30px_80px_-20px_rgba(0,0,0,0.8)]">
                <div className="w-24 h-24 rounded-[32px] flex items-center justify-center mb-8 border border-primary/20 bg-primary/10 shadow-[0_0_40px_rgba(238,229,147,0.15)]">
                  <CreditCard className="w-10 h-10 text-primary" />
                </div>

                <h2 className="text-center text-sm font-black uppercase tracking-[0.3em] mb-4 text-white/90">
                  {t("checkout.secure_payment")}
                </h2>
                <p className="text-white/40 text-center text-sm md:text-base mb-10 leading-relaxed max-w-xs">
                  {t("checkout.secure_desc")}
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

                  {!currentUser ? (
                    <Link
                      href={`/login?redirect=/courses/${id}/checkout`}
                      className="btn-gold w-full py-5 text-sm flex items-center justify-center gap-3 font-black uppercase tracking-wider"
                    >
                      <LogIn className="w-5 h-5" />
                      {t("checkout.login_error")}
                    </Link>
                  ) : (
                    <div className="w-full space-y-4">
                      {/* Whop Checkout (Apple Pay, Google Pay & Cards) */}
                      <button
                        onClick={handleWhopCheckout}
                        disabled={joining}
                        className="w-full py-5 px-6 rounded-2xl bg-gradient-to-r from-[#D4AF37] via-[#F3E5AB] to-[#AA7C11] hover:from-[#F3E5AB] hover:to-[#D4AF37] text-black font-black text-sm uppercase tracking-wider shadow-[0_15px_40px_rgba(212,175,55,0.35)] hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center gap-3 disabled:opacity-50"
                      >
                        {joining ? (
                          <Loader2 className="w-5 h-5 animate-spin text-black" />
                        ) : (
                          <>
                            <CreditCard className="w-5 h-5 text-black shrink-0" />
                            <span>{t("checkout.pay_whop") || "Pay with Apple Pay, Google Pay & Cards"}</span>
                          </>
                        )}
                      </button>
                    </div>
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

                {/* Card & Wallet Badges */}
                <div className="mt-10 flex items-center gap-6 grayscale opacity-40 hover:grayscale-0 hover:opacity-100 transition-all duration-500">
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
                  <span className="text-[11px] font-black tracking-widest text-white/80 uppercase border border-white/20 px-2 py-0.5 rounded">
                    Apple Pay
                  </span>
                  <span className="text-[11px] font-black tracking-widest text-white/80 uppercase border border-white/20 px-2 py-0.5 rounded">
                    Google Pay
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
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
