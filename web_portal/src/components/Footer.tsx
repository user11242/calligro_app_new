"use client";
import Link from "next/link";
import AutoTranslatedText from "./AutoTranslatedText";

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="relative py-24 px-6 border-t border-white/5 overflow-hidden">
      {/* Background Glow */}
      <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[500px] h-[300px] bg-primary/5 blur-[120px] rounded-full pointer-events-none" />

      <div className="max-w-7xl mx-auto relative z-10">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          {/* Left: Branding & Copyright */}
          <div className="text-center md:text-left space-y-6">
            <div className="inline-block">
               <h2 className="text-2xl font-black font-outfit uppercase tracking-tighter gold-text">Calligro</h2>
            </div>
            <p className="text-[10px] font-black uppercase tracking-[5px] text-white/20">
               Academy Portal &copy; {currentYear}
            </p>
          </div>

          {/* Right: Legal Links */}
          <div className="flex flex-wrap justify-center md:justify-end gap-x-10 gap-y-4">
             <Link href="/terms" className="text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-primary transition-colors">
                <AutoTranslatedText text="Terms of Use" />
             </Link>
             <Link href="/privacy" className="text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-primary transition-colors">
                <AutoTranslatedText text="Privacy Policy" />
             </Link>
             <Link href="mailto:support@calligro.com" className="text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-primary transition-colors">
                <AutoTranslatedText text="Contact Support" />
             </Link>
          </div>
        </div>

        {/* Bottom Tagline */}
           <p className="text-[9px] font-medium text-white/10 italic">
              &quot;Beauty of writing is the tongue of the hand.&quot;
           </p>
      </div>
    </footer>
  );
}
