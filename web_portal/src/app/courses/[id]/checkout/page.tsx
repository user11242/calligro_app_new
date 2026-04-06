"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc, runTransaction, collection, serverTimestamp } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import { Loader2, ShieldCheck, ArrowLeft, CreditCard, CheckCircle2, Zap } from "lucide-react";
import Link from "next/link";
import { createCheckoutSession } from "@/app/actions/payment";
import AutoTranslatedText from "@/components/AutoTranslatedText";

export default function CheckoutPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  const handlePayment = async () => {
    try {
      const user = auth.currentUser;
      if (!user) {
        setError("You must be logged in to purchase.");
        return;
      }

      setJoining(true);
      setError(null);

      // 1. Get Variant ID (Should be in course doc or mapping)
      // For now, we expect it in the course document, or fallback to a test ID
      const variantId = course.lemonsqueezyVariantId;
      if (!variantId) {
        throw new Error("This course is not yet linked to a Lemon Squeezy product. Please contact the Academy.");
      }

      // 2. Create Checkout Session
      const { checkoutUrl } = await createCheckoutSession(
        variantId,
        user.uid,
        id as string,
        user.email || ""
      );

      if (!checkoutUrl) {
        throw new Error("Failed to generate checkout URL");
      }

      // 3. Redirect to Lemon Squeezy
      window.location.href = checkoutUrl;
    } catch (err: any) {
      console.error("Payment Error:", err);
      // If the error message mentions missing config, give a concrete hint
      const msg = err.message || "";
      if (msg.includes("Missing Store Configuration") || msg.includes("environment variable")) {
        setError("Error: Payments are not configured properly on Vercel yet. Please ensure LEMONSQUEEZY_API_KEY and LEMONSQUEEZY_STORE_ID are set.");
      } else {
        setError(err.message || "Failed to initiate payment. Please try again.");
      }
      setJoining(false);
    }
  };

  const handleQuickJoin = async () => {
    try {
      const user = auth.currentUser;
      if (!user) {
        setError("You must be logged in to join.");
        return;
      }

      if (course?.price && Number(course.price) > 0) {
        setError("Please complete the payment to join this course.");
        return;
      }

      setJoining(true);

      await runTransaction(db, async (transaction) => {
        const courseRef = doc(db, "courses", id as string);
        const transactionRef = doc(collection(db, "transactions"));

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
        const docRef = doc(db, "courses", id as string);
        const docSnap = await getDoc(docRef);
        if (!docSnap.exists()) {
          setError("Course not found");
          return;
        }
        const courseData = { id: docSnap.id, ...docSnap.data() as any };
        setCourse(courseData);

        const user = auth.currentUser;
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
    <div className="min-h-screen bg-secondary-dark flex flex-col items-center justify-center gap-4">
      <Loader2 className="w-10 h-10 text-primary animate-spin" />
      <p className="text-white/40 font-black uppercase tracking-widest text-xs">Initializing Secure Checkout...</p>
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
            <div className="space-y-8">
                <div className="glass-premium p-8 rounded-[32px] border-white/10">
                    <p className="text-[10px] font-black text-primary uppercase tracking-[4px] mb-4">Checkout Summary</p>
                    <h1 className="text-3xl font-black font-outfit text-white mb-2">{course.courseName || course.courseTitle}</h1>
                    <p className="text-white/40 text-sm font-medium">Instructor: {course.teacherName}</p>
                    
                    <div className="mt-8 pt-8 border-t border-white/5 flex justify-between items-end">
                        <span className="text-white/40 text-xs font-black uppercase tracking-widest">
                            <AutoTranslatedText text="Total Tuition" />
                        </span>
                        <span className="text-3xl font-black font-outfit gold-text">${Number(course.price).toFixed(2)}</span>
                    </div>

                    {!isEnrolled && (course.price === 0 || Number(course.price) === 0) && (
                        <button 
                            onClick={handleQuickJoin}
                            disabled={joining}
                            className="w-full mt-8 py-4 bg-white/5 hover:bg-white/10 text-white font-black uppercase tracking-[2px] text-xs rounded-2xl border border-white/10 transition-all flex items-center justify-center gap-3 disabled:opacity-50"
                        >
                            {joining ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4 text-primary" />}
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
                            <h3 className="text-white text-xl font-black font-outfit mb-2">You&apos;re already enrolled!</h3>
                            <p className="text-white/40 text-sm mb-6">Enjoy your learning journey at Calligro Academy.</p>
                            <Link 
                               href={`/courses/${id}/classroom`} 
                               className="btn-gold px-8 py-4 inline-flex items-center gap-2"
                            >
                               <Zap className="w-4 h-4" />
                               Enter Classroom
                            </Link>
                        </div>
                    </div>
                )}

                <div className="space-y-4 px-4">
                    <div className="flex items-center gap-4 text-white/40 text-sm font-bold">
                        <ShieldCheck className="w-5 h-5 text-primary" />
                        Secure Checkout via Lemon Squeezy
                    </div>
                    <div className="flex items-center gap-4 text-white/40 text-sm font-bold">
                        <CreditCard className="w-5 h-5 text-primary" />
                        Global Payments Support
                    </div>
                </div>
            </div>

            <div className="relative">
                {!isEnrolled && course.price > 0 && (
                    <div className="glass-premium p-10 rounded-[40px] border-white/5 bg-[#121212] flex flex-col items-center">
                        <div className="w-20 h-20 bg-primary/10 rounded-3xl flex items-center justify-center mb-8 border border-primary/20">
                            <CreditCard className="w-10 h-10 text-primary" />
                        </div>
                        <h2 className="text-center text-xs font-black uppercase tracking-[3px] mb-4 text-white/60">Secure Payment</h2>
                        <p className="text-white/40 text-center text-xs mb-10 leading-relaxed">
                            Click below to complete your enrollment safely using Apple Pay, Google Pay, or Credit Card.
                        </p>
                        
                        <button
                            onClick={handlePayment}
                            disabled={joining}
                            className="w-full py-5 bg-primary text-black font-black uppercase tracking-[3px] text-xs rounded-2xl hover:scale-[1.02] transition-all flex items-center justify-center gap-3 disabled:opacity-50 shadow-[0_0_30px_rgba(212,175,55,0.2)]"
                        >
                            {joining ? (
                                <Loader2 className="w-5 h-5 animate-spin" />
                            ) : (
                                <>
                                    <Zap className="w-5 h-5" />
                                    Secure Checkout
                                </>
                            )}
                        </button>
                        
                        <div className="mt-8 flex gap-4 opacity-20">
                            <img src="https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg" alt="Visa" className="h-3" />
                            <img src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg" alt="Mastercard" className="h-5" />
                            <img src="https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg" alt="PayPal" className="h-4" />
                        </div>
                    </div>
                )}
            </div>
        </div>
      </div>
    </main>
  );
}
