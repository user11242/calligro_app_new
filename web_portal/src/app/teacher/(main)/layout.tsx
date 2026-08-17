"use client";
import { useEffect, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import { useRouter, usePathname } from "next/navigation";
import { LayoutDashboard, BookOpen, CheckSquare, LogOut, Loader2, Menu, X, GraduationCap } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import Image from "next/image";
import { onAuthStateChanged } from "firebase/auth";
import { useTranslation } from "@/hooks/useTranslation";
import { useLocale } from "@/context/LocaleContext";

export default function TeacherLayout({ children }: { children: React.ReactNode }) {
  const [isTeacher, setIsTeacher] = useState<boolean | null>(null);
  const [teacherData, setTeacherData] = useState<any>(null);
  const [isSidebarOpen, setSidebarOpen] = useState(false);
  const { locale, setLocale, isRTL } = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const { t } = useTranslation();

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) { router.push("/login"); return; }
      try {
        const userDoc = await getDoc(doc(db, "users", user.uid));
        if (userDoc.exists() && userDoc.data()?.role === "teacher") {
          setIsTeacher(true);
          setTeacherData(userDoc.data());
        } else {
          router.push("/courses");
        }
      } catch {
        router.push("/login");
      }
    });
    return () => unsubscribe();
  }, [router]);

  if (isTeacher === null) {
    return (
      <div className="min-h-screen bg-[#1F1F1F] flex flex-col items-center justify-center gap-4">
        <div className="w-16 h-16 rounded-2xl bg-[#D4AF37] flex items-center justify-center animate-pulse">
          <GraduationCap className="w-8 h-8 text-black" />
        </div>
        <p className="text-white/40 tracking-widest uppercase text-xs font-semibold">{t('teacher.studio')}...</p>
      </div>
    );
  }

  const navItems = [
    { name: t('teacher.nav.dashboard'), href: "/teacher/dashboard", icon: LayoutDashboard },
    { name: t('teacher.nav.courses'), href: "/teacher/courses", icon: BookOpen },
    { name: t('teacher.nav.homeworks'), href: "/teacher/homeworks", icon: CheckSquare },
  ];

  const avatarLetter = teacherData?.name?.charAt(0)?.toUpperCase() || "T";

  return (
    <div className="flex h-screen bg-[#1F1F1F] overflow-hidden" dir={isRTL ? "rtl" : "ltr"}>
      {/* Mobile Overlay */}
      <AnimatePresence>
        {isSidebarOpen && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            onClick={() => setSidebarOpen(false)}
            className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40 md:hidden"
          />
        )}
      </AnimatePresence>

      {/* ─── LEFT SIDEBAR ─── */}
      <aside className={`
        fixed md:static top-0 left-0 h-full z-50
        w-64 flex flex-col bg-[#161616] border-r border-white/[0.06]
        transition-transform duration-300 ease-in-out
        ${isSidebarOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"}
      `}>
        {/* Logo */}
        <div className="flex items-center gap-3 px-6 h-[72px] border-b border-white/[0.06] shrink-0">
          <div className="w-9 h-9 rounded-xl bg-[#D4AF37] flex items-center justify-center">
            <GraduationCap className="w-5 h-5 text-black" strokeWidth={2.5} />
          </div>
          <div>
            <p className="font-bold text-white text-sm tracking-wide leading-none">CALLIGRO</p>
            <p className="text-[#D4AF37] text-[10px] font-semibold tracking-widest uppercase mt-0.5">{t('teacher.studio')}</p>
          </div>
          <button className="ml-auto md:hidden text-white/40 hover:text-white" onClick={() => setSidebarOpen(false)}>
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Locale Switcher for Sidebar */}
        <div className="px-6 py-4 border-b border-white/[0.06] shrink-0">
          <div className="relative group/lang">
            <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-white/5 border border-white/10 hover:border-[#D4AF37]/50 transition-colors cursor-pointer">
              <span className="text-white text-sm font-medium">
                {locale === 'en' ? 'ENGLISH' : locale === 'ar' ? 'العربية' : 'TÜRKÇE'}
              </span>
              <svg className="w-4 h-4 ml-auto text-white/50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </div>
            
            <select 
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
              value={locale} 
              onChange={(e) => setLocale(e.target.value as any)}
            >
              <option value="en" className="text-black">English</option>
              <option value="ar" className="text-black">العربية</option>
              <option value="tr" className="text-black">Türkçe</option>
            </select>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
          <p className="text-white/25 text-[10px] font-bold tracking-widest uppercase px-3 mb-3 mt-2">{t('teacher.menu')}</p>
          {navItems.map(({ name, href, icon: Icon }) => {
            const active = pathname === href || pathname?.startsWith(href + "/");
            return (
              <Link key={name} href={href} onClick={() => setSidebarOpen(false)}>
                <div className={`
                  flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200
                  ${active
                    ? "bg-[#D4AF37] text-black font-bold shadow-lg shadow-[#D4AF37]/20"
                    : "text-white/50 hover:text-white hover:bg-white/5"
                  }
                `}>
                  <Icon className="w-4 h-4 shrink-0" />
                  <span>{name}</span>
                </div>
              </Link>
            );
          })}
        </nav>

        {/* User Profile */}
        <div className="p-4 border-t border-white/[0.06] shrink-0">
          <div className="flex items-center gap-3 px-2 mb-3">
            <div className="w-9 h-9 rounded-full overflow-hidden bg-[#D4AF37]/20 border border-[#D4AF37]/30 flex items-center justify-center shrink-0">
              {teacherData?.profilePic
                ? <Image src={teacherData.profilePic} alt="Profile" width={36} height={36} className="object-cover w-full h-full" />
                : <span className="text-[#D4AF37] font-bold text-sm">{avatarLetter}</span>
              }
            </div>
            <div className="min-w-0">
              <p className="text-white text-sm font-semibold truncate">{teacherData?.name || "Teacher"}</p>
              <div className="flex items-center gap-1.5 mt-0.5">
                <div className="w-1.5 h-1.5 rounded-full bg-green-400"></div>
                <p className="text-green-400 text-[10px] font-semibold tracking-wide">{t('teacher.verified')}</p>
              </div>
            </div>
          </div>
          <button
            onClick={() => { auth.signOut(); router.push("/login"); }}
            className="flex items-center gap-2.5 w-full px-4 py-2.5 text-sm text-white/40 hover:text-red-400 hover:bg-red-400/5 rounded-xl transition-all duration-200"
          >
            <LogOut className="w-4 h-4" />
            <span className="font-medium">{t('teacher.sign_out')}</span>
          </button>
        </div>
      </aside>

      {/* ─── MAIN AREA ─── */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Mobile Top Bar */}
        <header className="md:hidden flex items-center justify-between px-5 h-[72px] border-b border-white/[0.06] bg-[#161616] shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-[#D4AF37] flex items-center justify-center">
              <GraduationCap className="w-4 h-4 text-black" />
            </div>
            <span className="font-bold text-white text-sm">{t('teacher.studio')}</span>
          </div>
          <button onClick={() => setSidebarOpen(true)} className="w-10 h-10 flex items-center justify-center rounded-xl bg-white/5 text-white/70 hover:text-white border border-white/10">
            <Menu className="w-5 h-5" />
          </button>
        </header>

        {/* Scrollable Content */}
        <main className="flex-1 overflow-y-auto">
          <div className="p-6 md:p-10 max-w-7xl mx-auto">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
