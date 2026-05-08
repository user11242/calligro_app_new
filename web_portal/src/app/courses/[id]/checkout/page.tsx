"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { doc, getDoc, runTransaction, collection, serverTimestamp } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import { Loader2, ShieldCheck, ArrowLeft, CreditCard, CheckCircle2, Zap, Layout } from "lucide-react";
import Link from "next/link";
import { createCheckoutSession } from "@/app/actions/payment";
import { useTranslation } from "@/hooks/useTranslation";

// Override firebase import to use local initialized app
import { db as libDb, auth as libAuth } from "@/lib/firebase";

export default function CheckoutPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const { t } = useTranslation();

  const handlePayment = async () => {
    try {
      const user = libAuth.currentUser;
      if (!user) {
        setError(t("checkout.login_error"));
        return;
      }

      setJoining(true);
      setError(null);

      const studentPriceCents = Math.round((Number(course.price || 0) * 100) / 2);
      const courseName = course.courseName || course.courseTitle || "Untitled Course";
      const bannerUrl = course.courseBanner || course.thumbnailUrl;

      const structuredDescription = t("course.payment_desc");

      const { checkoutUrl } = await createCheckoutSession(
        course.lemonSqueezyVariantId,
        user.uid,
        id as string,
        user.email || "",
        courseName,
        studentPriceCents,
        structuredDescription,
        bannerUrl
      );


      if (!checkoutUrl) {
        throw new Error("Failed to generate checkout URL");
      }

      window.location.href = checkoutUrl;
    } catch (err: any) {
      console.error("Payment Error:", err);
      const msg = err.message || "";
      if (msg.includes("Missing Store Configuration") || msg.includes("environment variable")) {
        setError(t("checkout.config_error"));
      } else {
        setError(err.message || "Failed to initiate payment. Please try again.");
      }
      setJoining(false);
    }
  };

  const handleAdminBypass = async () => {
    // Only allow in development
    if (process.env.NODE_ENV !== "development") return;

    try {
      const user = libAuth.currentUser;
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
        const enrolledStudents = Array.isArray(courseData.enrolledStudents) ? [...courseData.enrolledStudents] : [];

        if (!enrolledStudents.includes(user.uid)) {
          enrolledStudents.push(user.uid);

          transaction.update(courseRef, {
            enrolledStudents: enrolledStudents,
            enrolledCount: enrolledStudents.length
          });

          transaction.set(transactionRef, {
            studentId: user.uid,
            studentName: user.displayName || user.email?.split('@')[0] || t("nav.student_login").split(' ')[0],
            teacherId: courseData.teacherId || '',
            teacherName: courseData.teacherName || 'Unknown Teacher',
            courseId: id as string,
            courseName: courseData.courseName || courseData.courseTitle || courseData.title || 'Untitled Course',
            amount: 0,
            currency: 'USD',
            source: 'admin_bypass',
            status: 'completed',
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
      const user = libAuth.currentUser;
      if (!user) {
        setError("You must be logged in to join.");
        return;
      }

      if (course?.price && (Number(course.price) / 2) > 0) {
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
        const enrolledStudents = Array.isArray(courseData.enrolledStudents) ? [...courseData.enrolledStudents] : [];

        if (!enrolledStudents.includes(user.uid)) {
          enrolledStudents.push(user.uid);

          transaction.update(courseRef, {
            enrolledStudents: enrolledStudents,
            enrolledCount: enrolledStudents.length
          });

          const grossAmount = (Number(courseData.price) / 2) || 0;
          transaction.set(transactionRef, {
            studentId: user.uid,
            studentName: user.displayName || user.email?.split('@')[0] || t("nav.student_login").split(' ')[0],
            teacherId: courseData.teacherId || '',
            teacherName: courseData.teacherName || 'Unknown Teacher',
            courseId: id as string,
            courseName: courseData.courseName || courseData.courseTitle || courseData.title || 'Untitled Course',
            amount: grossAmount,
            currency: 'USD',
            source: 'web_portal_quick',
            status: 'completed',
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
        const courseData = { id: docSnap.id, ...docSnap.data() as any };
        setCourse(courseData);

        const user = libAuth.currentUser;
        if (user && courseData.enrolledStudents?.includes(user.uid)) {
          setIsEnrolled(true);
          return;
        }
      } catch (err) {
        console.error(err);
        setError("Failed to load course details. Please try refreshing.");
      } finally {
        setLoading(false);
      }
    };

    initCheckout();
  }, [id]);

  if (loading) return (
    <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center gap-6">
      <Loader2 className="w-12 h-12 text-primary animate-spin" />
      <p className="text-white/40 font-black uppercase tracking-[0.3em] text-xs ">{t("checkout.loading")}</p>
    </div>
  );

  if (error || !course) return (
    <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center gap-6 p-6 text-center">
      <div className="w-20 h-20 bg-red-500/10 rounded-full flex items-center justify-center border border-red-500/20">
        <ShieldCheck className="w-10 h-10 text-red-500" />
      </div>
      <p className="text-red-400 font-bold max-w-xl text-lg">{error || "Something went wrong"}</p>
      <Link href={`/courses/${id}`} className="btn-gold mt-4 py-4 px-10 border border-white/10 hover:bg-white/5 transition-all text-sm font-black tracking-widest text-[#050505] uppercase">
        {t("checkout.cancel")}
      </Link>
    </div>
  );

  return (
    <main className="min-h-screen academy-bg pb-32">
      <Navbar />

      <div className="pt-32 px-6 max-w-5xl mx-auto">
        <Link href={`/courses/${id}`} className="inline-flex items-center gap-3 text-white/50 hover:text-primary transition-colors mb-12 text-[10px] md:text-xs font-black uppercase tracking-[0.3em] group">
          <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
          {t("checkout.cancel")}
        </Link>

        {/* Abstract Glow Layer */}
        <div className="absolute top-[20%] left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-primary/5 blur-[150px] rounded-full pointer-events-none" />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-16 md:gap-24 relative z-10 w-full items-start">
          <div className="space-y-10">
            <div className="glass-premium p-10 md:p-12 rounded-[48px] border-white/10 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.8)] backdrop-blur-3xl bg-[#0a0a0a]">
              <div className="flex items-center gap-4 mb-8">
                <Layout className="w-5 h-5 text-primary" />
                <p className="text-xs font-black text-primary uppercase tracking-[0.3em] -[0_0_8px_rgba(238,229,147,0.3)]">{t("checkout.summary")}</p>
              </div>

              <h1 className="text-3xl md:text-5xl font-black font-outfit text-white mb-4 leading-tight">
                {course.courseName || course.courseTitle}
              </h1>
              <p className="text-white/50 text-base md:text-lg font-medium">{t("checkout.instructor")} {course.teacherName}</p>

              <div className="mt-12 pt-8 border-t border-white/10 flex flex-col md:flex-row justify-between md:items-end gap-4">
                <div className="flex flex-col">
                  <span className="text-white/40 text-[10px] font-black uppercase tracking-[0.2em] mb-1">
                    {t("checkout.total")}
                  </span>
                  <span className="text-white/20 text-sm font-bold line-through px-1">${Number(course.price).toFixed(0)}</span>
                </div>
                <div className="flex flex-col items-end">
                  <span className="bg-primary/20 text-primary px-3 py-1 rounded-lg text-[8px] font-black uppercase tracking-widest mb-2 border border-primary/20">{t("checkout.grant")}</span>
                  <span className="text-5xl md:text-6xl font-black font-outfit gold-text leading-none">${(Number(course.price) / 2).toFixed(0)}</span>
                </div>
              </div>

              {!isEnrolled && (course.price === 0 || Number(course.price) === 0) && (
                <button
                  onClick={handleQuickJoin}
                  disabled={joining}
                  className="w-full mt-10 py-5 bg-white/[0.03] hover:bg-white/10 text-white font-black uppercase tracking-[0.2em] text-xs rounded-[24px] border border-white/10 transition-all flex items-center justify-center gap-4 disabled:opacity-50 shadow-inner"
                >
                  {joining ? <Loader2 className="w-5 h-5 animate-spin" /> : <CheckCircle2 className="w-5 h-5 text-primary -[0_0_8px_rgba(238,229,147,0.4)]" />}
                  {t("checkout.join_direct")}
                </button>
              )}
            </div>

            {isEnrolled && (
              <div className="bg-primary/5 border border-primary/20 p-12 rounded-[48px] flex flex-col items-center gap-6 text-center backdrop-blur-md">
                <div className="w-20 h-20 bg-primary/10 rounded-[32px] flex items-center justify-center border border-primary/30 shadow-[0_0_30px_rgba(238,229,147,0.2)]">
                  <CheckCircle2 className="w-10 h-10 text-primary -[0_0_8px_currentColor]" />
                </div>
                <div>
                  <h3 className="text-white text-3xl font-black font-outfit mb-3">{t("checkout.enrolled")}</h3>
                  <p className="text-white/50 text-base mb-8 max-w-sm mx-auto">{t("checkout.enrolled_desc")}</p>
                  <Link
                    href={`/courses/${id}/classroom`}
                    className="btn-gold w-full text-base py-5 flex items-center justify-center gap-3 shadow-[0_20px_50px_-10px_rgba(238,229,147,0.3)]  hover:animate-none"
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
                <div className="w-24 h-24 bg-primary/10 rounded-[32px] flex items-center justify-center mb-8 border border-primary/20 shadow-[0_0_40px_rgba(238,229,147,0.15)]">
                  <CreditCard className="w-10 h-10 text-primary -[0_0_8px_currentColor]" />
                </div>
                <h2 className="text-center text-sm font-black uppercase tracking-[0.3em] mb-4 text-white/90">{t("checkout.secure_payment")}</h2>
                <p className="text-white/40 text-center text-sm md:text-base mb-12 leading-relaxed max-w-xs">
                  {t("checkout.secure_desc")}
                </p>

                <button
                  onClick={handlePayment}
                  disabled={joining}
                  className="btn-gold w-full py-6 text-sm flex items-center justify-center gap-4 disabled:opacity-50 shadow-[0_20px_50px_-10px_rgba(238,229,147,0.3)]"
                >
                  {joining ? (
                    <Loader2 className="w-6 h-6 animate-spin" />
                  ) : (
                    <>
                      <Zap className="w-6 h-6" />
                      {t("checkout.secure_button")}
                    </>
                  )}
                </button>

                {process.env.NODE_ENV === "development" && (
                  <button
                    onClick={handleAdminBypass}
                    disabled={joining}
                    className="w-full mt-4 py-4 bg-white/5 hover:bg-white/10 text-white/50 hover:text-white text-[10px] font-black uppercase tracking-[0.2em] rounded-[24px] border border-white/10 transition-all flex items-center justify-center gap-3 disabled:opacity-50"
                  >
                    {joining ? <Loader2 className="w-5 h-5 animate-spin" /> : <ShieldCheck className="w-4 h-4 text-green-500" />}
                    [ {t("course.admin_bypass")} ]
                  </button>
                )}

                <div className="mt-12 flex gap-6 grayscale opacity-20 hover:grayscale-0 hover:opacity-100 transition-all duration-500">
                  <img src="https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg" alt="Visa" className="h-4" />
                  <img src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg" alt="Mastercard" className="h-6" />
                  <img src="https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg" alt="PayPal" className="h-5" />
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  );
}
