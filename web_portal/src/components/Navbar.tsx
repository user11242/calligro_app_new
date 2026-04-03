"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { auth, db } from "@/lib/firebase";
import { onAuthStateChanged, signOut, User } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { MoveRight, Globe, LogOut, User as UserIcon, Menu, X } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { useLocale } from "@/context/LocaleContext";

export default function Navbar() {
  const { locale, setLocale, isRTL } = useLocale();
  const [user, setUser] = useState<User | null>(null);
  const [userName, setUserName] = useState<string>("");
  const [userPhoto, setUserPhoto] = useState<string>("");
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setUser(user);
      if (user) {
        const userDoc = await getDoc(doc(db, "users", user.uid));
        if (userDoc.exists()) {
          const data = userDoc.data();
          setUserName(data.displayName || user.displayName || "Student");
          setUserPhoto(data.photoURL || user.photoURL || "");
        } else {
          setUserName(user.displayName || "Student");
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

  const labels = {
    en: { courses: "Courses", teachers: "Teachers", about: "About", login: "Student Login", logout: "Logout" },
    ar: { courses: "الدورات", teachers: "المعلمون", about: "عنا", login: "دخول الطلاب", logout: "تسجيل الخروج" },
    tr: { courses: "Kurslar", teachers: "Öğretmenler", about: "Hakkımızda", login: "Öğrenci Girişi", logout: "Çıkış Yap" },
  }[locale];

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 flex justify-center p-4 md:p-8 pointer-events-none">
      <motion.div 
        initial={{ y: -50, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ type: "spring", damping: 20, stiffness: 100 }}
        className={`glass-premium rounded-[24px] md:rounded-[32px] px-6 md:px-10 py-3 md:py-5 flex items-center justify-between md:justify-start gap-4 md:gap-12 pointer-events-auto shadow-[0_30px_60px_-15px_rgba(0,0,0,0.5)] border-white/5 hover:border-primary/20 transition-all group w-full max-w-[1400px] ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}
      >
        <Link href="/" className="text-xl md:text-2xl font-black gold-text font-outfit tracking-tighter hover:scale-105 transition-transform flex-shrink-0">
          CALLIGRO
        </Link>
        
        {/* Desktop Navigation */}
        <div className={`hidden md:flex items-center gap-8 text-sm font-medium text-white/70 ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
          <Link href="/courses" className="hover:text-primary transition-colors">{labels.courses}</Link>
          <Link href="/teachers" className="hover:text-primary transition-colors">{labels.teachers}</Link>
          <Link href="/about" className="hover:text-primary transition-colors">{labels.about}</Link>
        </div>

        {/* Desktop Actions */}
        <div className={`hidden md:flex items-center gap-8 flex-1 justify-end ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
          {/* Language Switcher */}
          <div className={`flex items-center gap-3 border-white/10 ${isRTL ? 'border-r pr-10' : 'border-l pl-10'}`}>
            <Globe className="w-4 h-4 text-primary/60" />
            <select 
              value={locale} 
              onChange={(e) => setLocale(e.target.value as any)}
              className="bg-transparent text-xs font-black uppercase tracking-widest text-white/70 focus:outline-none cursor-pointer hover:text-primary transition-colors"
            >
              <option value="en" className="bg-secondary-light font-sans tracking-normal text-black">English</option>
              <option value="ar" className="bg-secondary-light font-sans tracking-normal text-black">العربية</option>
              <option value="tr" className="bg-secondary-light font-sans tracking-normal text-black">Türkçe</option>
            </select>
          </div>

          {user ? (
            <div className={`flex items-center gap-6 ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
              <div className={`flex items-center gap-3 ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
                <div className="w-10 h-10 rounded-full bg-primary/20 flex items-center justify-center text-primary overflow-hidden border-2 border-primary/20 shadow-xl shadow-primary/10 group/avatar">
                  {userPhoto ? (
                    <img 
                      src={userPhoto} 
                      alt="User" 
                      className="w-full h-full object-cover grayscale-[20%] hover:grayscale-0 transition-all duration-500"
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = 'none';
                        setUserPhoto("");
                      }}
                    />
                  ) : (
                    <UserIcon className="w-4 h-4" />
                  )}
                </div>
                <span className="text-sm font-bold gold-text font-outfit uppercase tracking-wider max-w-[120px] truncate">
                  {userName}
                </span>
              </div>
              <button 
                onClick={handleLogout}
                className="text-white/40 hover:text-red-400 transition-colors"
                title={labels.logout}
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          ) : (
            <Link href="/login">
              <button className={`text-sm font-semibold flex items-center gap-2 group hover:text-primary transition-all ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
                {labels.login}
                <MoveRight className={`w-4 h-4 group-hover:translate-x-1 transition-transform ${isRTL ? 'rotate-180' : ''}`} />
              </button>
            </Link>
          )}
        </div>

        {/* Mobile Toggle */}
        <button 
          onClick={() => setIsOpen(!isOpen)}
          className="md:hidden text-white/70 hover:text-primary transition-colors p-2"
        >
          {isOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </motion.div>

      {/* Mobile Menu Overlay */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="fixed top-24 left-4 right-4 z-[49] glass-premium rounded-[32px] p-8 md:hidden border-white/5 shadow-2xl pointer-events-auto"
          >
            <div className="flex flex-col gap-6 text-center">
              <Link href="/courses" className="text-lg font-bold hover:text-primary transition-colors" onClick={() => setIsOpen(false)}>{labels.courses}</Link>
              <Link href="/teachers" className="text-lg font-bold hover:text-primary transition-colors" onClick={() => setIsOpen(false)}>{labels.teachers}</Link>
              <Link href="/about" className="text-lg font-bold hover:text-primary transition-colors" onClick={() => setIsOpen(false)}>{labels.about}</Link>
              
              <div className="h-[1px] bg-white/5 my-2" />
              
              {/* Language Switcher Mobile */}
              <div className="flex items-center justify-center gap-4 py-2">
                <Globe className="w-4 h-4 text-primary" />
                <select 
                  value={locale} 
                  onChange={(e) => {
                    setLocale(e.target.value as any);
                    setIsOpen(false);
                  }}
                  className="bg-transparent text-sm font-bold uppercase tracking-widest text-primary focus:outline-none"
                >
                  <option value="en" className="text-black">English</option>
                  <option value="ar" className="text-black">العربية</option>
                  <option value="tr" className="text-black">Türkçe</option>
                </select>
              </div>

              {user ? (
                <div className="flex flex-col gap-6 items-center">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-primary/20 flex items-center justify-center text-primary overflow-hidden border-2 border-primary/20">
                      {userPhoto ? (
                        <img src={userPhoto} alt="User" className="w-full h-full object-cover" />
                      ) : (
                        <UserIcon className="w-4 h-4" />
                      )}
                    </div>
                    <span className="text-sm font-bold gold-text font-outfit uppercase tracking-wider">
                      {userName}
                    </span>
                  </div>
                  <button 
                    onClick={handleLogout}
                    className="flex items-center gap-2 text-red-400 font-bold"
                  >
                    <LogOut className="w-4 h-4" />
                    {labels.logout}
                  </button>
                </div>
              ) : (
                <Link href="/login" onClick={() => setIsOpen(false)}>
                  <button className="btn-gold w-full flex items-center justify-center gap-2">
                    {labels.login}
                    <MoveRight className={`w-4 h-4 ${isRTL ? 'rotate-180' : ''}`} />
                  </button>
                </Link>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}
