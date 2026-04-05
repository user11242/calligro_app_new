"use client";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import { motion } from "framer-motion";
import { FileText, Shield, ShieldCheck } from "lucide-react";

export default function TermsPage() {
  return (
    <main className="academy-bg min-h-screen font-sans">
      <Navbar />

      <section className="pt-44 pb-24 px-6 max-w-4xl mx-auto">
        <motion.div
           initial={{ opacity: 0, y: 20 }}
           animate={{ opacity: 1, y: 0 }}
           className="glass-premium p-8 md:p-16 rounded-[40px] border-white/5"
        >
          <div className="flex items-center gap-4 mb-8">
             <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center">
                <FileText className="w-6 h-6 text-primary" />
             </div>
             <div>
                <h1 className="text-3xl md:text-4xl font-black font-outfit gold-text">
                   <AutoTranslatedText text="Terms of Use" />
                </h1>
                <p className="text-[10px] font-black uppercase tracking-[3px] text-white/20 mt-1">
                   Last Updated: April 2026
                </p>
             </div>
          </div>

          <div className="space-y-12 text-white/70 leading-relaxed font-medium">
             <section className="space-y-4">
                <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider">
                   <AutoTranslatedText text="1. License & Intellectual Property" />
                </h2>
                <p>
                   <AutoTranslatedText text="Welcome to Calligro Academy. By using our website and mobile application, you agree to these terms. All calligraphy lessons, videos, and downloadable materials are the intellectual property of Calligro and our Master Artists. You are granted a personal, non-transferable license to view these materials. You may not record, redistribute, or sell any content from this platform." />
                </p>
             </section>

             <section className="space-y-4">
                <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider">
                   <AutoTranslatedText text="2. Enrollment & Access" />
                </h2>
                <p>
                   <AutoTranslatedText text="Your enrollment provides lifetime access to the specific course purchased, including all future updates to that course. Access is tied to your personal account and may not be shared." />
                </p>
             </section>

             <section className="space-y-4 rounded-3xl bg-primary/5 p-8 border border-primary/10">
                <h2 className="text-xl font-black font-outfit text-primary uppercase tracking-wider">
                   <AutoTranslatedText text="3. Refund Policy" />
                </h2>
                <ul className="list-disc pl-5 space-y-4 mt-4">
                   <li>
                      <strong><AutoTranslatedText text="Web Portal Purchases" />:</strong> <AutoTranslatedText text="Refunds are only available before the course has officially started and content has been accessed. Once a course session has begun or digital content has been consumed, no refunds will be issued." />
                   </li>
                   <li>
                      <strong><AutoTranslatedText text="In-App Purchases (iOS/Android)" />:</strong> <AutoTranslatedText text="Refunds for purchases made through the Calligro mobile app are managed exclusively by Apple (App Store) and Google (Play Store). Please refer to their respective refund processes." />
                   </li>
                </ul>
             </section>

             <section className="space-y-4">
                <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider">
                   <AutoTranslatedText text="4. User Conduct" />
                </h2>
                <p>
                   <AutoTranslatedText text="Students are expected to maintain a respectful environment in community forums and live sessions. We reserve the right to revoke access for any behavior that violates our community standards or disrupts the learning experience of others." />
                </p>
             </section>

             <div className="pt-12 border-t border-white/5 space-y-4">
                <p className="text-sm font-bold text-white/40">
                   <AutoTranslatedText text="Contact Information" />
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                   <div className="glass p-4 rounded-2xl border-white/5">
                      <p className="text-[10px] text-white/20 uppercase font-black mb-1">Email</p>
                      <p className="text-sm text-primary">support@calligro.com</p>
                   </div>
                   <div className="glass p-4 rounded-2xl border-white/5">
                      <p className="text-[10px] text-white/20 uppercase font-black mb-1">Office</p>
                      <p className="text-sm text-white/60">Amman, Jordan</p>
                   </div>
                </div>
             </div>
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
