"use client";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion } from "framer-motion";
import { FileText, Shield, ShieldCheck } from "lucide-react";
import { useTranslation } from "@/hooks/useTranslation";

export default function TermsPage() {
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
                <FileText className="w-6 h-6 text-primary" />
             </div>
             <div>
                <h1 className="text-3xl md:text-4xl font-black font-outfit gold-text">
                   {t("terms.title")}
                </h1>
                <p className="text-[10px] font-black uppercase tracking-[3px] text-white/20 mt-1">
                   {t("terms.last_updated")}
                </p>
             </div>
          </div>

          <div className="space-y-12 text-white/70 leading-relaxed font-medium">
             {[1, 2, 3, 4, 5, 6, 7, 8].map((num) => (
               <section key={num} className="space-y-4">
                  <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider">
                     {t(`terms.section${num}.title`)}
                  </h2>
                  <p className="whitespace-pre-line">
                     {t(`terms.section${num}.content`)}
                  </p>
               </section>
             ))}

             <div className="pt-12 border-t border-white/5 space-y-4">
                <p className="text-sm font-bold text-white/40">
                   {t("terms.contact")}
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                   <div className="glass p-4 rounded-2xl border-white/5">
                      <p className="text-[10px] text-white/20 uppercase font-black mb-1">{t("terms.email")}</p>
                      <p className="text-sm text-primary">support@calligro.com</p>
                   </div>
                   <div className="glass p-4 rounded-2xl border-white/5">
                      <p className="text-[10px] text-white/20 uppercase font-black mb-1">{t("terms.office")}</p>
                      <p className="text-sm text-white/60">{t("terms.location")}</p>
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
