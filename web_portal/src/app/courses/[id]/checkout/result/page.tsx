"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { auth } from "@/lib/firebase";
import Navbar from "@/components/Navbar";
import { Loader2, CheckCircle2, XCircle, ArrowRight } from "lucide-react";
import Link from "next/link";
import { checkPaymentStatus } from "@/app/actions/status";

export default function PaymentResultPage() {
  const { id } = useParams();
  const searchParams = useSearchParams();
  const resourcePath = searchParams.get("resourcePath");
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [message, setMessage] = useState("");
  const router = useRouter();

  useEffect(() => {
    if (!resourcePath || !id) return;

    if (resourcePath === "manual_success") {
       setStatus("success");
       return;
    }

    const verify = async () => {
      try {
        const user = auth.currentUser;
        if (!user) {
            setStatus("error");
            setMessage("You must be logged in to complete enrollment.");
            return;
        }

        const result = await checkPaymentStatus(resourcePath, id as string, user.uid);
        if (result.success) {
          setStatus("success");
        } else {
          setStatus("error");
          setMessage(result.message || "Payment verification failed.");
        }
      } catch (err) {
        console.error(err);
        setStatus("error");
        setMessage("An error occurred while verifying your payment.");
      }
    };

    verify();
  }, [resourcePath, id]);

  return (
    <main className="min-h-screen bg-secondary-dark font-sans">
      <Navbar />
      
      <div className="pt-48 px-6 flex flex-col items-center justify-center text-center max-w-2xl mx-auto">
        {status === "loading" && (
          <div className="space-y-6">
            <Loader2 className="w-16 h-16 text-primary animate-spin mx-auto" />
            <h1 className="text-2xl font-black font-outfit uppercase tracking-widest">Verifying Payment...</h1>
            <p className="text-white/40">Please do not refresh or close this page. We are syncing your enrollment.</p>
          </div>
        )}

        {status === "success" && (
          <div className="space-y-8">
            <div className="w-24 h-24 rounded-full bg-green-500/20 flex items-center justify-center mx-auto text-green-500">
                <CheckCircle2 className="w-12 h-12" />
            </div>
            <div className="space-y-4">
                <h1 className="text-4xl font-black font-outfit uppercase tracking-tight text-white">Welcome to the Academy!</h1>
                <p className="text-white/60 text-lg leading-relaxed">
                   Your payment was successful. The course is now unlocked on both your **Web Portal** and your **Mobile App**.
                </p>
            </div>
            <div className="pt-8">
                <Link href="/courses" className="btn-gold px-12 py-4 text-lg inline-flex items-center gap-3">
                    Start Learning
                    <ArrowRight className="w-5 h-5" />
                </Link>
            </div>
          </div>
        )}

        {status === "error" && (
          <div className="space-y-8">
            <div className="w-24 h-24 rounded-full bg-red-500/20 flex items-center justify-center mx-auto text-red-500">
                <XCircle className="w-12 h-12" />
            </div>
            <div className="space-y-4">
                <h1 className="text-4xl font-black font-outfit uppercase tracking-tight text-white">Enrollment Failed</h1>
                <p className="text-white/60 text-lg">
                   {message || "We couldn't verify your payment. If you were charged, please contact support."}
                </p>
            </div>
            <div className="flex gap-4 justify-center pt-8">
                <Link href={`/courses/${id}/checkout`} className="glass px-8 py-4 rounded-2xl text-white font-bold hover:bg-white/5 transition-all">
                    Try Again
                </Link>
                <Link href="/support" className="text-white/40 font-bold hover:text-white transition-colors flex items-center px-8 border-l border-white/5">
                    Contact Support
                </Link>
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
