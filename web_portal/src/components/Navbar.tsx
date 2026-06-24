"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { auth, db } from "@/lib/firebase";
import { onAuthStateChanged, signOut, User } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { MoveRight, Globe, LogOut, User as UserIcon, Menu, X } from "lucide-react";
import { useLocale } from "@/context/LocaleContext";
import { useTranslation } from "@/hooks/useTranslation";

export default function Navbar() {
  const { locale, setLocale, isRTL } = useLocale();
  const { t } = useTranslation();
  const [user, setUser] = useState<User | null>(null);
  const [userName, setUserName] = useState<string>("");
  const [userPhoto, setUserPhoto] = useState<string>("");
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

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
          // Mobile app uses 'name' and 'photoUrl', web portal was using 'displayName' and 'photoURL'
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

  return (
    <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
      scrolled 
        ? "bg-primary shadow-lg border-b border-white/10" 
        : "bg-transparent"
    }`}>
      <div 
        className={`max-w-[1400px] mx-auto px-4 md:px-10 py-4 md:py-5 flex items-center justify-between md:justify-start gap-4 lg:gap-12 w-full group ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}
      >
        <Link href="/" className="text-xl lg:text-2xl font-black text-white font-outfit tracking-tighter flex-shrink-0">
          CALLIGRO
        </Link>
        
        {/* Desktop Navigation */}
        <div className={`hidden md:flex items-center gap-4 lg:gap-8 text-[10px] lg:text-sm font-bold text-white/90 ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
          <Link href="/courses" className="nav-link whitespace-nowrap">{t("nav.courses")}</Link>
          <Link href="/teachers" className="nav-link whitespace-nowrap">{t("nav.teachers")}</Link>
          <Link href="/about" className="nav-link whitespace-nowrap">{t("nav.about")}</Link>
        </div>

        {/* Desktop Actions */}
        <div className={`hidden md:flex items-center gap-4 lg:gap-8 flex-1 justify-end ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
          {/* Language Switcher */}
          <div className={`flex items-center gap-2 lg:gap-3 border-white/20 ${isRTL ? 'border-r pr-4 lg:pr-10' : 'border-l pl-4 lg:pl-10'}`}>
            <Globe className="w-4 h-4 text-white" />
            <select 
              value={locale} 
              onChange={(e) => setLocale(e.target.value as any)}
              className="bg-transparent text-[10px] font-black uppercase tracking-widest text-white focus:outline-none cursor-pointer hover:text-white/80 transition-colors"
            >
              <option value="en" className="bg-white font-sans tracking-normal text-black">English</option>
              <option value="ar" className="bg-white font-sans tracking-normal text-black">العربية</option>
              <option value="tr" className="bg-white font-sans tracking-normal text-black">Türkçe</option>
            </select>
          </div>

          {user ? (
            <div className={`flex items-center gap-4 lg:gap-6 ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
              <div className={`flex items-center gap-2 lg:gap-3 ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
                <div className="w-8 lg:w-10 h-8 lg:h-10 rounded-full bg-white/20 flex items-center justify-center text-white overflow-hidden border-2 border-white/20 shadow-xl group/avatar">
                  {userPhoto ? (
                    <Image 
                      src={userPhoto || "/images/placeholder.png"} 
                      alt="User" 
                      width={40}
                      height={40}
                      className="w-full h-full object-cover transition-all duration-500"
                    />
                  ) : (
                    <UserIcon className="w-4 h-4" />
                  )}
                </div>
                <span className="text-[10px] lg:text-sm font-bold text-white font-outfit uppercase tracking-wider max-w-[150px] lg:max-w-[300px] truncate">
                  {userName}
                </span>
              </div>
              <button 
                onClick={handleLogout}
                className="text-white hover:text-red-500 transition-colors bg-white/10 p-2 rounded-full"
                title={t("nav.logout")}
              >
                <LogOut className="w-3 h-3 lg:w-4 lg:h-4" />
              </button>
            </div>
          ) : (
            <Link href="/login">
              <button className={`text-[10px] lg:text-sm font-bold flex items-center gap-2 group text-white hover:text-white/80 transition-all whitespace-nowrap ${isRTL ? 'flex-row-reverse' : 'flex-row'}`}>
                {t("nav.student_login")}
                <MoveRight className={`w-3 h-3 lg:w-4 lg:h-4 group-hover:translate-x-1 transition-transform ${isRTL ? 'rotate-180' : ''}`} />
              </button>
            </Link>
          )}
        </div>

        {/* Mobile Toggle */}
        <button 
          onClick={() => setIsOpen(!isOpen)}
          className="md:hidden text-white hover:text-white/80 transition-colors p-2"
        >
          {isOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {/* Mobile Menu Overlay */}
      {isOpen && (
          <div
            className="fixed top-24 left-4 right-4 z-[49] bg-[#0a0a0a]/95 backdrop-blur-3xl border border-white/10 rounded-[32px] p-8 md:hidden shadow-2xl pointer-events-auto"
          >
            <div className="flex flex-col gap-6 text-center text-white">
              <Link href="/courses" className="text-lg font-bold hover:text-white/80 transition-colors" onClick={() => setIsOpen(false)}>{t("nav.courses")}</Link>
              <Link href="/teachers" className="text-lg font-bold hover:text-white/80 transition-colors" onClick={() => setIsOpen(false)}>{t("nav.teachers")}</Link>
              <Link href="/about" className="text-lg font-bold hover:text-white/80 transition-colors" onClick={() => setIsOpen(false)}>{t("nav.about")}</Link>
              
              <div className="h-[1px] bg-white/5 my-2" />
              
              {/* Language Switcher Mobile */}
              <div className="flex items-center justify-center gap-4 py-2">
                <Globe className="w-4 h-4 text-white" />
                <select 
                  value={locale} 
                  onChange={(e) => {
                    setLocale(e.target.value as any);
                    setIsOpen(false);
                  }}
                  className="bg-transparent text-sm font-bold uppercase tracking-widest text-white focus:outline-none"
                >
                  <option value="en" className="text-black">English</option>
                  <option value="ar" className="text-black">العربية</option>
                  <option value="tr" className="text-black">Türkçe</option>
                </select>
              </div>

              {user ? (
                <div className="flex flex-col gap-6 items-center">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-white overflow-hidden border-2 border-white/20">
                      {userPhoto ? (
                        <Image 
                          src={userPhoto || "/images/placeholder.png"} 
                          alt="User" 
                          width={40}
                          height={40}
                          className="w-full h-full object-cover" 
                        />
                      ) : (
                        <UserIcon className="w-4 h-4" />
                      )}
                    </div>
                    <span className="text-sm font-bold text-white font-outfit uppercase tracking-wider">
                      {userName}
                    </span>
                  </div>
                  <button 
                    onClick={handleLogout}
                    className="flex items-center gap-2 text-white bg-red-500/20 px-4 py-2 rounded-full font-bold"
                  >
                    <LogOut className="w-4 h-4" />
                    {t("nav.logout")}
                  </button>
                </div>
              ) : (
                <Link href="/login" onClick={() => setIsOpen(false)}>
                  <button className="bg-white text-primary w-full py-3 rounded-full font-bold flex items-center justify-center gap-2 hover:bg-white/90 transition-colors">
                    {t("nav.student_login")}
                    <MoveRight className={`w-4 h-4 ${isRTL ? 'rotate-180' : ''}`} />
                  </button>
                </Link>
              )}
            </div>
          </div>
        )}
    </nav>
  );
}
