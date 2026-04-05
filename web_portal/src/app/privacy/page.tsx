"use client";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import { motion } from "framer-motion";
import { ShieldCheck, Lock, Eye, Database } from "lucide-react";

export default function PrivacyPage() {
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
                <ShieldCheck className="w-6 h-6 text-primary" />
             </div>
             <div>
                <h1 className="text-3xl md:text-4xl font-black font-outfit gold-text">
                   <AutoTranslatedText text="Privacy Policy" />
                </h1>
                <p className="text-[10px] font-black uppercase tracking-[3px] text-white/20 mt-1">
                   Last Updated: April 2026
                </p>
             </div>
          </div>

          <div className="space-y-12 text-white/70 leading-relaxed font-medium">
             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <Database className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      <AutoTranslatedText text="1. Data Collection" />
                   </h2>
                </div>
                <p>
                   <AutoTranslatedText text="At Calligro, we value your privacy. We collect minimal data required to provide our services and ensure a secure learning environment. This includes: Account Information (Email, Name, Profile Picture via Google/Apple Sign-In), Device Information for security, and Usage Data such as course progress and quiz results." />
                </p>
             </section>

             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <Lock className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      <AutoTranslatedText text="2. Payment Security" />
                   </h2>
                </div>
                <p>
                   <AutoTranslatedText text="Your financial security is our priority. We do not store credit card details on our servers. All web payments are processed securely by Lemon Squeezy, which acts as our Merchant of Record. Mobile payments are handled directly by Apple and Google. These providers utilize industry-standard encryption to protect your data." />
                </p>
             </section>

             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <Eye className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      <AutoTranslatedText text="3. Service Providers" />
                   </h2>
                </div>
                <p>
                   <AutoTranslatedText text="We utilize the following trusted third-party services to power Calligro Academy:" />
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-6">
                   <div className="glass p-6 rounded-[32px] border-white/5">
                      <p className="text-sm font-black text-white mb-2">Firebase</p>
                      <p className="text-[10px] text-white/40 leading-relaxed">
                         <AutoTranslatedText text="Authentication, Database, and Cloud Function hosting." />
                      </p>
                   </div>
                   <div className="glass p-6 rounded-[32px] border-white/5">
                      <p className="text-sm font-black text-white mb-2">Jitsi</p>
                      <p className="text-[10px] text-white/40 leading-relaxed">
                         <AutoTranslatedText text="Secure video streaming for live masterclass sessions." />
                      </p>
                   </div>
                </div>
             </section>

             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <ShieldCheck className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      <AutoTranslatedText text="4. Your Data Rights" />
                   </h2>
                </div>
                <p>
                   <AutoTranslatedText text="Under global privacy standards, you have the right to access, export, correct, or request the deletion of your personal data at any time. You can manage most of these settings directly through your Account Profile inside the Calligro app or portal." />
                </p>
             </section>

             <div className="pt-12 border-t border-white/5 text-center">
                <div className="inline-flex items-center gap-2 px-6 py-2 rounded-full bg-white/5 border border-white/5">
                   <p className="text-[10px] text-white/40 font-black uppercase tracking-[2px]">
                      <AutoTranslatedText text="Safety & Transparency First" />
                   </p>
                </div>
             </div>
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
