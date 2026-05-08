"use client";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion } from "framer-motion";
import { ShieldCheck, Lock, Eye, Database } from "lucide-react";
import { useTranslation } from "@/hooks/useTranslation";

export default function PrivacyPage() {
  const { t } = useTranslation();

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
                   {t("privacy.title")}
                </h1>
                <p className="text-[10px] font-black uppercase tracking-[3px] text-white/20 mt-1">
                   {t("privacy.last_updated")}
                </p>
             </div>
          </div>

          <div className="space-y-12 text-white/70 leading-relaxed font-medium">
             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <Database className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      {t("privacy.section1.title")}
                   </h2>
                </div>
                <p>
                   {t("privacy.section1.content")}
                </p>
             </section>

             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <Lock className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      {t("privacy.section2.title")}
                   </h2>
                </div>
                <p>
                   {t("privacy.section2.content")}
                </p>
             </section>

             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <Eye className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      {t("privacy.section3.title")}
                   </h2>
                </div>
                <p>
                   {t("privacy.section3.content")}
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-6">
                   <div className="glass p-6 rounded-[32px] border-white/5">
                      <p className="text-sm font-black text-white mb-2">{t("privacy.firebase.title")}</p>
                      <p className="text-[10px] text-white/40 leading-relaxed">
                         {t("privacy.firebase.content")}
                      </p>
                   </div>
                   <div className="glass p-6 rounded-[32px] border-white/5">
                      <p className="text-sm font-black text-white mb-2">{t("privacy.jitsi.title")}</p>
                      <p className="text-[10px] text-white/40 leading-relaxed">
                         {t("privacy.jitsi.content")}
                      </p>
                   </div>
                </div>
             </section>

             <section className="space-y-4">
                <div className="flex items-center gap-3 text-white mb-4">
                   <ShieldCheck className="w-5 h-5 text-primary" />
                   <h2 className="text-xl font-black font-outfit uppercase tracking-wider">
                      {t("privacy.section4.title")}
                   </h2>
                </div>
                <p>
                   {t("privacy.section4.content")}
                </p>
             </section>

             <div className="pt-12 border-t border-white/5 text-center">
                <div className="inline-flex items-center gap-2 px-6 py-2 rounded-full bg-white/5 border border-white/5">
                   <p className="text-[10px] text-white/40 font-black uppercase tracking-[2px]">
                      {t("privacy.footer")}
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
