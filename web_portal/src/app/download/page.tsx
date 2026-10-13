"use client";

import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { useTranslation } from "@/hooks/useTranslation";
import { Smartphone, Download, Sparkles, CheckCircle2 } from "lucide-react";
import Image from "next/image";

export default function DownloadPage() {
  const { t } = useTranslation();

  return (
    <main className="min-h-screen bg-[#0A0A0A] text-[#FDFBF7] selection:bg-[#E8C468]/30 flex flex-col justify-between">
      <Navbar />

      <section className="relative pt-36 md:pt-44 pb-24 px-6 md:px-12 flex-1 flex flex-col items-center justify-center text-center">
        {/* Glow */}
        <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-[#E8C468]/10 rounded-full blur-[140px] pointer-events-none" />

        <div className="relative z-10 max-w-2xl mx-auto flex flex-col items-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 text-xs font-medium text-[#E8C468] mb-6 backdrop-blur-md">
            <Sparkles className="w-4 h-4" />
            <span>تطبيق كاليجرو متاح الآن</span>
          </div>

          <h1
            className="text-4xl md:text-6xl font-black mb-6 tracking-tight text-white leading-tight"
            style={{ fontFamily: "var(--font-amiri), serif" }}
          >
            تعلّم فن الخط العربي <br />
            <span className="text-[#E8C468]">في أي وقت ومن أي مكان</span>
          </h1>

          <p className="text-white/60 text-base md:text-lg mb-10 leading-relaxed max-w-lg">
            حمّل تطبيق كاليجرو الرسمي على هاتفك أو جهازك اللوحي واستمتع بمتابعة دوراتك، والتواصل المباشر مع أساتذة الخط.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 w-full justify-center max-w-md">
            {/* Google Play */}
            <a
              href="https://play.google.com/store/apps/details?id=com.calligro.app"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-3 px-6 py-4 rounded-2xl bg-white/10 hover:bg-white/15 border border-white/15 hover:border-[#E8C468]/50 text-white font-bold transition-all shadow-xl group"
            >
              <Smartphone className="w-5 h-5 text-[#E8C468] group-hover:scale-110 transition-transform" />
              <span>Google Play</span>
            </a>

            {/* App Store */}
            <a
              href="https://apps.apple.com/app/calligro-learn-calligraphy/id6761537808"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-3 px-6 py-4 rounded-2xl bg-[#E8C468] hover:bg-[#d8b458] text-[#211A08] font-bold transition-all shadow-xl group"
            >
              <Download className="w-5 h-5 text-[#211A08] group-hover:scale-110 transition-transform" />
              <span>Apple App Store</span>
            </a>
          </div>

          <div className="mt-12 flex items-center gap-6 text-xs text-white/40">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
              <span>تجربة مجانية للبدء</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
              <span>مزامنة فورية مع حسابك</span>
            </div>
          </div>
        </div>
      </section>

      <Footer />
    </main>
  );
}
