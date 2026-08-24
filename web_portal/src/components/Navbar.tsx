"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { auth, db } from "@/lib/firebase";
import { onAuthStateChanged, signOut, User } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { MoveRight, Globe, LogOut, User as UserIcon, Menu, X, Search } from "lucide-react";
import { useLocale } from "@/context/LocaleContext";
import { useTranslation } from "@/hooks/useTranslation";
import { motion, AnimatePresence } from "framer-motion";

export default function Navbar() {
  const { locale, setLocale, isRTL } = useLocale();
  const { t } = useTranslation();
  const [user, setUser] = useState<User | null>(null);
  const [userName, setUserName] = useState<string>("");
  const [userPhoto, setUserPhoto] = useState<string>("");
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const router = useRouter();

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setUser(user);
      if (user) {
        const userDoc = await getDoc(doc(db, "users", user.uid));
        if (userDoc.exists()) {
          const data = userDoc.data();
          setUserName(data.name || data.displayName || user.displayName || "User");
          setUserPhoto(data.photoUrl || data.photoURL || user.photoURL || "");
        } else {
          setUserName(user.displayName || "User");
          setUserPhoto(user.photoURL || "");
        }
      } else {
        setUserName("");
        setUserPhoto("");
      }
    });
    return () => unsubscribe();
  }, []);

  const handleLogout = async () => {
    await signOut(auth);
    window.location.href = "/";
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/courses?q=${encodeURIComponent(searchQuery.trim())}`);
    }
  };

  return (
    <>
      <motion.nav 
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
        className={`fixed top-4 left-0 right-0 z-[60] flex justify-center pointer-events-none px-4 transition-all duration-500`}
      >
        <motion.div 
          layout
          className={`pointer-events-auto flex items-center justify-between gap-6 px-6 py-3 rounded-full transition-all duration-500 ${
            scrolled 
              ? "bg-[#1F1F1F]/80 backdrop-blur-2xl border border-white/10 shadow-[0_8px_32px_rgba(0,0,0,0.5)] w-full max-w-5xl" 
              : "bg-transparent w-full max-w-7xl"
          }`}
          dir={isRTL ? "rtl" : "ltr"}
        >
          {/* Logo */}
          <Link href="/" className="flex items-center gap-3 group" dir="ltr">
            <Image 
              src="/assets/images/Logo.png"
              alt="Calligro Logo"
              width={32}
              height={32}
              className="w-8 h-8 object-contain drop-shadow-md"
            />
            <span className={`text-xl font-black text-white font-outfit tracking-tighter transition-all ${scrolled ? "hidden sm:block" : "block"}`}>
              CALLIGRO
            </span>
          </Link>
          
          {/* Desktop Center: Links + Full-Size Search */}
          <div className="hidden md:flex items-center flex-1 justify-between px-8 gap-8">
            <div className="flex items-center gap-6 text-sm font-bold text-white/70 shrink-0">
              <Link href="/courses" className="hover:text-white transition-colors relative group">
                {t("nav.courses")}
                <span className="absolute -bottom-2 left-0 w-full h-[2px] bg-primary scale-x-0 group-hover:scale-x-100 transition-transform origin-left rounded-full" />
              </Link>
              <Link href="/teachers" className="hover:text-white transition-colors relative group">
                {t("nav.teachers")}
                <span className="absolute -bottom-2 left-0 w-full h-[2px] bg-primary scale-x-0 group-hover:scale-x-100 transition-transform origin-left rounded-full" />
              </Link>
              <Link href="/about" className="hover:text-white transition-colors relative group">
                {t("nav.about")}
                <span className="absolute -bottom-2 left-0 w-full h-[2px] bg-primary scale-x-0 group-hover:scale-x-100 transition-transform origin-left rounded-full" />
              </Link>
            </div>

            {/* Premium Full-Size Search Bar */}
            <form onSubmit={handleSearch} className="relative w-full max-w-md group" dir={isRTL ? "rtl" : "ltr"}>
              <div className={`absolute inset-y-0 ${isRTL ? 'right-4' : 'left-4'} flex items-center pointer-events-none transition-colors group-focus-within:text-primary text-white/40`}>
                <Search className="w-4 h-4" />
              </div>
              <input 
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder={t("nav.search") || "What do you want to learn today?"}
                className={`w-full bg-black/20 border border-white/10 rounded-full py-2.5 ${isRTL ? 'pr-12 pl-6' : 'pl-12 pr-6'} text-white placeholder:text-white/40 focus:outline-none focus:border-primary/50 focus:bg-black/60 focus:ring-[3px] focus:ring-primary/10 transition-all duration-300 font-medium text-sm shadow-[inset_0_2px_10px_rgba(0,0,0,0.2)] hover:bg-white/5 hover:border-white/20`}
              />
              <div className={`absolute inset-y-0 ${isRTL ? 'left-1.5' : 'right-1.5'} flex items-center`}>
                <button type="submit" className="bg-primary/90 hover:bg-primary text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full transition-all opacity-0 group-focus-within:opacity-100 scale-90 group-focus-within:scale-100 shadow-[0_0_15px_rgba(235,185,55,0.4)] whitespace-nowrap overflow-hidden">
                  {locale === 'ar' ? "بحث" : locale === 'tr' ? "Ara" : "Search"}
                </button>
              </div>
            </form>
          </div>

          {/* Desktop Actions */}
          <div className="hidden md:flex items-center gap-4 shrink-0">

            {/* Language Switcher */}
            <div className={`relative flex items-center justify-center gap-2 px-4 py-2 rounded-full border border-white/10 bg-white/5 hover:bg-white/10 transition-colors cursor-pointer h-[34px]`}>
              <Globe className="w-4 h-4 text-white/70 pointer-events-none" />
              <span className="text-[11px] font-black uppercase tracking-widest text-white pointer-events-none">
                {locale.toUpperCase()}
              </span>
              <select 
                value={locale} 
                onChange={(e) => setLocale(e.target.value as any)}
                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer appearance-none"
              >
                <option value="en" className="text-black">EN</option>
                <option value="ar" className="text-black">AR</option>
                <option value="tr" className="text-black">TR</option>
              </select>
            </div>

            {user ? (
              <div className="flex items-center gap-4">
                <Link href="/profile">
                  <div className="flex items-center gap-3 bg-white/5 pr-4 pl-1 py-1 rounded-full border border-white/10 hover:bg-white/10 transition-colors cursor-pointer" dir={isRTL ? "ltr" : "ltr"}>
                    <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center text-white overflow-hidden border border-primary/40">
                      {userPhoto ? (
                        <Image 
                          src={userPhoto} 
                          alt="User" 
                          width={32}
                          height={32}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <UserIcon className="w-4 h-4 text-primary" />
                      )}
                    </div>
                    <span className="text-[11px] font-bold text-white font-outfit uppercase tracking-wider max-w-[100px] truncate">
                      {userName}
                    </span>
                  </div>
                </Link>
                <button 
                  onClick={handleLogout}
                  className="w-10 h-10 flex items-center justify-center rounded-full bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/20 transition-all"
                  title={t("nav.logout")}
                >
                  <LogOut className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <Link href="/login">
                <button className={`px-6 py-2.5 rounded-full bg-primary text-black text-xs font-black uppercase tracking-widest flex items-center gap-2 hover:scale-105 active:scale-95 transition-all shadow-[0_0_20px_rgba(235,185,55,0.3)]`}>
                  {t("nav.student_login")}
                  <MoveRight className={`w-4 h-4 ${isRTL ? 'rotate-180' : ''}`} />
                </button>
              </Link>
            )}
          </div>

          {/* Mobile Toggle */}
          <button 
            onClick={() => setIsOpen(!isOpen)}
            className="md:hidden w-10 h-10 flex items-center justify-center rounded-full bg-white/10 border border-white/20 text-white"
          >
            {isOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </motion.div>
      </motion.nav>

      {/* Mobile Menu Overlay */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -20, scale: 0.95 }}
            transition={{ duration: 0.3 }}
            className="fixed top-24 left-4 right-4 z-[49] bg-[#1F1F1F]/90 backdrop-blur-3xl border border-white/10 rounded-[32px] p-8 md:hidden shadow-2xl pointer-events-auto"
            dir={isRTL ? "rtl" : "ltr"}
          >
            <div className="flex flex-col gap-6 text-center text-white">
              
              {/* Mobile Search */}
              <div className="relative w-full mb-2">
                <div className="absolute inset-y-0 left-4 flex items-center pointer-events-none">
                  <Search className="w-5 h-5 text-white/50" />
                </div>
                <input 
                  type="text" 
                  placeholder={t("nav.search") || "Search courses..."}
                  className="w-full bg-black/40 border border-white/10 rounded-full py-4 pl-12 pr-6 text-white placeholder:text-white/40 focus:outline-none focus:border-primary/50 focus:bg-black/60 transition-colors font-bold text-sm shadow-[inset_0_2px_10px_rgba(0,0,0,0.3)]"
                />
              </div>

              <Link href="/courses" className="text-xl font-black font-outfit uppercase tracking-wider hover:text-primary transition-colors" onClick={() => setIsOpen(false)}>{t("nav.courses")}</Link>
              <Link href="/teachers" className="text-xl font-black font-outfit uppercase tracking-wider hover:text-primary transition-colors" onClick={() => setIsOpen(false)}>{t("nav.teachers")}</Link>
              <Link href="/about" className="text-xl font-black font-outfit uppercase tracking-wider hover:text-primary transition-colors" onClick={() => setIsOpen(false)}>{t("nav.about")}</Link>
              
              <div className="h-[1px] bg-gradient-to-r from-transparent via-white/20 to-transparent my-4" />
              
              {/* Language Switcher Mobile */}
              <div className="relative flex items-center justify-center gap-4 py-2 cursor-pointer w-40 mx-auto">
                <Globe className="w-5 h-5 text-primary pointer-events-none" />
                <span className="text-sm font-black uppercase tracking-widest text-white pointer-events-none">
                  {locale === 'en' ? 'ENGLISH' : locale === 'ar' ? 'العربية' : 'TÜRKÇE'}
                </span>
                <select 
                  value={locale} 
                  onChange={(e) => {
                    setLocale(e.target.value as any);
                    setIsOpen(false);
                  }}
                  className="absolute inset-0 w-full h-full opacity-0 cursor-pointer appearance-none"
                >
                  <option value="en" className="text-black">English</option>
                  <option value="ar" className="text-black">العربية</option>
                  <option value="tr" className="text-black">Türkçe</option>
                </select>
              </div>

              {user ? (
                <div className="flex flex-col gap-6 items-center mt-4">
                  <Link href="/profile" onClick={() => setIsOpen(false)}>
                    <div className="flex items-center gap-4 bg-white/5 py-2 px-4 rounded-full border border-white/10 hover:bg-white/10 transition-colors">
                      <div className="w-12 h-12 rounded-full bg-primary/20 flex items-center justify-center text-white overflow-hidden border-2 border-primary/40 shadow-[0_0_15px_rgba(235,185,55,0.3)]">
                        {userPhoto ? (
                          <Image src={userPhoto} alt="User" width={48} height={48} className="w-full h-full object-cover" />
                        ) : (
                          <UserIcon className="w-6 h-6 text-primary" />
                        )}
                      </div>
                      <span className="text-lg font-black text-white font-outfit uppercase tracking-wider">
                        {userName}
                      </span>
                    </div>
                  </Link>
                  <button 
                    onClick={handleLogout}
                    className="flex items-center gap-2 text-red-400 bg-red-500/10 border border-red-500/20 px-6 py-3 rounded-full font-bold w-full justify-center"
                  >
                    <LogOut className="w-4 h-4" />
                    {t("nav.logout")}
                  </button>
                </div>
              ) : (
                <Link href="/login" onClick={() => setIsOpen(false)} className="mt-4">
                  <button className="bg-primary text-black w-full py-4 rounded-full font-black text-sm uppercase tracking-widest flex items-center justify-center gap-3 hover:bg-[#F4DE90] shadow-[0_0_20px_rgba(235,185,55,0.4)] transition-colors">
                    {t("nav.student_login")}
                    <MoveRight className={`w-5 h-5 ${isRTL ? 'rotate-180' : ''}`} />
                  </button>
                </Link>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
