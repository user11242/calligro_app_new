"use client";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";

export default function Footer() {
  const currentYear = new Date().getFullYear();
  const { t } = useTranslation();

  return (
    <footer className="bg-primary py-10 px-6 border-t border-white/10 relative overflow-hidden">
      <div className="max-w-[1400px] mx-auto relative z-10">
        <div className="flex flex-col md:flex-row items-start justify-between gap-12 mb-10">
          {/* Left: Brand Identity */}
          <div className="space-y-4">
            <Link href="/" className="text-3xl font-black font-outfit uppercase tracking-tighter text-white hover:opacity-80 transition-opacity">
              Calligro
            </Link>
            <p className="text-[9px] font-black uppercase tracking-[4px] text-white/30">
               Academy Portal &copy; {currentYear}
            </p>
          </div>

          {/* Right: Categorized Links */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-x-12 gap-y-6">
            <div className="space-y-3">
              <h3 className="text-[10px] font-black uppercase tracking-[2px] text-white/40">Academic</h3>
              <ul className="space-y-1.5 flex flex-col">
                <Link href="/courses" className="text-xs font-bold text-white hover:text-white/70 transition-colors uppercase tracking-widest">Courses</Link>
                <Link href="/teachers" className="text-xs font-bold text-white hover:text-white/70 transition-colors uppercase tracking-widest">Teachers</Link>
              </ul>
            </div>
            <div className="space-y-3">
              <h3 className="text-[10px] font-black uppercase tracking-[2px] text-white/40">Support</h3>
              <ul className="space-y-1.5 flex flex-col">
                <Link href="/login" className="text-xs font-bold text-white hover:text-white/70 transition-colors uppercase tracking-widest">Portal</Link>
                <Link href="mailto:support@calligro.com" className="text-xs font-bold text-white hover:text-white/70 transition-colors uppercase tracking-widest">Contact</Link>
              </ul>
            </div>
            <div className="space-y-3">
              <h3 className="text-[10px] font-black uppercase tracking-[2px] text-white/40">Legal</h3>
              <ul className="space-y-1.5 flex flex-col">
                <Link href="/terms" className="text-xs font-bold text-white hover:text-white/70 transition-colors uppercase tracking-widest">{t("footer.terms")}</Link>
                <Link href="/privacy" className="text-xs font-bold text-white hover:text-white/70 transition-colors uppercase tracking-widest">{t("footer.privacy")}</Link>
              </ul>
            </div>
          </div>
        </div>

        {/* Bottom Tagline */}
        <div className="pt-8 border-t border-white/5 flex flex-col sm:flex-row justify-between items-center gap-4">
          <p className="text-[10px] font-medium text-white/20 italic font-serif">
            &quot;Beauty of writing is the tongue of the hand.&quot;
          </p>
          <div className="flex items-center gap-4 text-[9px] font-black text-white/10 tracking-[5px] uppercase">
             Mastery • Excellence • Tradition
          </div>
        </div>
      </div>
    </footer>
  );
}
