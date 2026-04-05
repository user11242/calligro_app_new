"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc, runTransaction, collection, serverTimestamp } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import { Loader2, ShieldCheck, ArrowLeft, CreditCard, CheckCircle2 } from "lucide-react";
import Link from "next/link";
import { createCheckoutSession } from "@/app/actions/payment";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import Script from "next/script";

export default function CheckoutPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [checkoutId, setCheckoutId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  const handleQuickJoin = async () => {
    try {
      const user = auth.currentUser;
      if (!user) {
        setError("You must be logged in to join.");
        return;
      }

      // 🛡️ SECURITY: Only allow direct join for FREE courses
      if (course?.price && Number(course.price) > 0) {
        setError("Please complete the payment to join this course.");
        return;
      }

      setJoining(true);

      // Perform enrollment via TRANSACTION to match Mobile App exactly
      await runTransaction(db, async (transaction) => {
        const courseRef = doc(db, "courses", id as string);
        const transactionRef = doc(collection(db, "transactions"));

        const courseSnap = await transaction.get(courseRef);
        if (!courseSnap.exists()) throw new Error("Course not found");
        
        const courseData = courseSnap.data()!;
        const enrolledStudents = Array.isArray(courseData.enrolledStudents) ? [...courseData.enrolledStudents] : [];

        if (!enrolledStudents.includes(user.uid)) {
          enrolledStudents.push(user.uid);
          
          // 1. Update Course (Students + Count)
          transaction.update(courseRef, {
            enrolledStudents: enrolledStudents,
            enrolledCount: enrolledStudents.length
          });

          // 2. Record Financial Transaction (EXACT fields from App)
          const grossAmount = Number(courseData.price) || 0;
          transaction.set(transactionRef, {
            studentId: user.uid,
            studentName: user.displayName || user.email?.split('@')[0] || 'Student',
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

      router.push(`/courses/${id}/checkout/result?resourcePath=manual_success`);
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
        // 1. Fetch Course Details
        const docRef = doc(db, "courses", id as string);
        const docSnap = await getDoc(docRef);
        if (!docSnap.exists()) {
          setError("Course not found");
          return;
        }
        const courseData = { id: docSnap.id, ...docSnap.data() as any };
        setCourse(courseData);

        // check if already enrolled
        const user = auth.currentUser;
        if (user && courseData.enrolledStudents?.includes(user.uid)) {
          setIsEnrolled(true);
          // Don't set error, just show "Already Enrolled" in UI
          return;
        }

        // 2. Create Checkout Session (Only if paid)
        if (courseData.price && Number(courseData.price) > 0) {
          const { checkoutId } = await createCheckoutSession(courseData.price.toString());
          setCheckoutId(checkoutId);
        }
      } catch (err) {
        console.error(err);
        setError("Failed to initialize payment system. Please try refreshing.");
      } finally {
        setLoading(false);
      }
    };

    initCheckout();
  }, [id]);

  if (loading) return (
    <div className="min-h-screen bg-secondary-dark flex flex-col items-center justify-center gap-4">
      <Loader2 className="w-10 h-10 text-primary animate-spin" />
      <p className="text-white/40 font-black uppercase tracking-widest text-xs">Initializing Secure Payment...</p>
    </div>
  );

  if (error || !course) return (
    <div className="min-h-screen bg-secondary-dark flex flex-col items-center justify-center gap-6">
      <p className="text-red-400 font-bold">{error || "Something went wrong"}</p>
      <Link href={`/courses/${id}`} className="text-primary hover:underline">Back to Course</Link>
    </div>
  );

  return (
    <main className="min-h-screen bg-secondary-dark pb-32">
      <Navbar />
      
      <div className="pt-32 px-6 max-w-4xl mx-auto">
        <Link href={`/courses/${id}`} className="inline-flex items-center gap-2 text-white/40 hover:text-primary transition-colors mb-12 text-sm font-bold uppercase tracking-widest">
            <ArrowLeft className="w-4 h-4" />
            Cancel & Return
        </Link>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-16">
            {/* Left: Course Summary */}
            <div className="space-y-8">
                <div className="glass-gold p-8 rounded-[32px] border-white/10">
                    <p className="text-[10px] font-black text-primary uppercase tracking-[4px] mb-4">You are enrolling in</p>
                    <h1 className="text-3xl font-black font-outfit text-white mb-2">{course.courseName || course.courseTitle}</h1>
                    <p className="text-white/40 text-sm font-medium">Instructor: {course.teacherName}</p>
                    
                    <div className="mt-8 pt-8 border-t border-white/5 flex justify-between items-end">
                        <span className="text-white/40 text-xs font-black uppercase tracking-widest">
                            <AutoTranslatedText text="Total Tuition" />
                        </span>
                        <span className="text-3xl font-black font-outfit gold-text">${Number(course.price).toFixed(2)}</span>
                    </div>

                    {/* Quick Join Button (Only for FREE) */}
                    {!isEnrolled && (course.price === 0 || Number(course.price) === 0) && (
                        <button 
                            onClick={handleQuickJoin}
                            disabled={joining}
                            className="w-full mt-8 py-4 bg-white/5 hover:bg-white/10 text-white font-black uppercase tracking-[2px] text-xs rounded-2xl border border-white/10 transition-all flex items-center justify-center gap-3 disabled:opacity-50"
                        >
                            {joining ? (
                                <Loader2 className="w-4 h-4 animate-spin" />
                            ) : (
                                <CheckCircle2 className="w-4 h-4 text-primary" />
                            )}
                            <AutoTranslatedText text="Join Course Directly" />
                        </button>
                    )}
                </div>

                {isEnrolled && (
                    <div className="bg-primary/10 border border-primary/20 p-8 rounded-[32px] flex flex-col items-center gap-6 text-center">
                        <div className="w-16 h-16 bg-primary/20 rounded-full flex items-center justify-center">
                          <CheckCircle2 className="w-8 h-8 text-primary" />
                        </div>
                        <div>
                            <h3 className="text-white text-xl font-black font-outfit mb-2">You are already enrolled!</h3>
                            <p className="text-white/40 text-sm mb-6">You have full access to all lectures and materials.</p>
                            <Link 
                              href={`/courses/${id}/classroom`} 
                              className="inline-block py-4 px-8 bg-primary text-black font-black uppercase tracking-[2px] text-xs rounded-2xl hover:scale-105 transition-transform"
                            >
                              Go to Classroom
                            </Link>
                        </div>
                    </div>
                )}

                <div className="space-y-4 px-4">
                    <div className="flex items-center gap-4 text-white/40 text-sm font-bold">
                        <ShieldCheck className="w-5 h-5 text-primary" />
                        Secure 256-bit SSL Encrypted Payment
                    </div>
                    <div className="flex items-center gap-4 text-white/40 text-sm font-bold">
                        <CreditCard className="w-5 h-5 text-primary" />
                        Powered by HyperPay
                    </div>
                </div>
            </div>

            {/* Right: HyperPay Widget */}
            <div className="relative">
                {checkoutId ? (
                   <div key={checkoutId}> {/* Re-render container when checkoutId changes */}
                    <div className="glass p-8 rounded-[40px] border-white/5 bg-[#121212] min-h-[400px]">
                        <h2 className="text-center text-xs font-black uppercase tracking-[3px] mb-8 text-white/60">Select Payment Method</h2>
                        <form action={`/courses/${id}/checkout/result`} className="paymentWidgets" data-brands="VISA MASTER"></form>
                    </div>
                    {/* Inject script only when container is ready */}
                    <script 
                      dangerouslySetInnerHTML={{
                        __html: `
                          (function() {
                            var s = document.createElement('script');
                            s.src = "https://test.oppwa.com/v1/paymentWidgets.js?checkoutId=${checkoutId}&entityId=8ac7a4c77092892901709403328e3532";
                            document.body.appendChild(s);
                          })();
                        `
                      }}
                    />
                   </div>
                ) : (
                    <div className="glass p-8 rounded-[40px] border-white/5 bg-[#121212] flex flex-col items-center justify-center min-h-[400px]">
                         <Loader2 className="w-8 h-8 text-primary animate-spin mb-4" />
                         <p className="text-white/20 text-xs font-black uppercase tracking-[2px]">Initializing Checkout Session...</p>
                    </div>
                )}
            </div>
        </div>
      </div>

      <style jsx global>{`
        .wpwl-form {
            background: transparent !important;
            border: none !important;
            color: white !important;
        }
        .wpwl-label {
            color: rgba(255,255,255,0.6) !important;
            font-size: 12px !important;
            text-transform: uppercase !important;
            font-weight: 900 !important;
            letter-spacing: 1px !important;
        }
        .wpwl-control {
            background: rgba(255,255,255,0.05) !important;
            border: 1px solid rgba(255,255,255,0.1) !important;
            border-radius: 12px !important;
            color: white !important;
            padding: 12px !important;
        }
        .wpwl-button-pay {
            background: #D4AF37 !important;
            color: #1F1F1F !important;
            border: none !important;
            border-radius: 16px !important;
            font-weight: 900 !important;
            text-transform: uppercase !important;
            letter-spacing: 2px !important;
            padding: 16px !important;
            margin-top: 24px !important;
        }
      `}</style>
    </main>
  );
}
