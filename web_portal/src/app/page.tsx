"use client";
import { useEffect, useState, useRef } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, AnimatePresence, useScroll, useTransform } from "framer-motion";
import Link from "next/link";
import { db } from "@/lib/firebase";
import { collection, query, limit, getDocs, orderBy, where } from "firebase/firestore";
import Image from "next/image";
import { Star, ArrowRight, Play, Layout, Users, Sparkles, Search, BookOpen, Clock, ChevronRight, ChevronLeft, CheckCircle, TrendingUp, Quote, Trophy, Medal, Map, Award } from "lucide-react";
import { formatImageUrl } from "@/lib/utils";
import { useTranslation } from "@/hooks/useTranslation";
import AutoTranslatedText from "@/components/AutoTranslatedText";

// Safe date formatter for Firebase Timestamps or strings
const formatCourseDate = (dateVal: any, locale: string) => {
  if (!dateVal) return "";
  try {
    let d: Date;
    if (dateVal instanceof Date) {
      d = dateVal;
    } else if (typeof dateVal.toDate === 'function') {
      d = dateVal.toDate();
    } else if (dateVal.seconds) {
      d = new Date(dateVal.seconds * 1000);
    } else if (dateVal._seconds) {
      d = new Date(dateVal._seconds * 1000);
    } else {
      d = new Date(dateVal);
    }
    if (isNaN(d.getTime())) return "";
    return d.toLocaleDateString(locale === 'ar' ? 'ar-EG' : 'en-US', { day: 'numeric', month: 'short' });
  } catch (err) {
    return "";
  }
};

// Helper for Mouse Glow effect
const GlowCard = ({ children, className = "" }: { children: React.ReactNode, className?: string }) => {
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });
  const cardRef = useRef<HTMLDivElement>(null);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!cardRef.current) return;
    const rect = cardRef.current.getBoundingClientRect();
    setMousePosition({
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
    });
  };

  return (
    <div 
      ref={cardRef}
      onMouseMove={handleMouseMove}
      className={`bento-card group ${className}`}
    >
      <div 
        className="mouse-glow"
        style={{
          left: `${mousePosition.x - 200}px`,
          top: `${mousePosition.y - 200}px`,
        }}
      />
      {children}
    </div>
  );
};

export default function Home() {
  const [teachers, setTeachers] = useState<any[]>([]);
  const [featuredCourses, setFeaturedCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [mounted, setMounted] = useState(false);
  const { t, locale } = useTranslation();
  const isRTL = locale === "ar";
  
  // Parallax scroll effects
  const { scrollYProgress } = useScroll();
  const heroY = useTransform(scrollYProgress, [0, 1], ["0%", "50%"]);
  
  // Slider ref
  const sliderRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setMounted(true);
    const fetchData = async () => {
      try {
        // Fetch teachers
        const tQuery = query(collection(db, "users"), where("role", "==", "teacher"), limit(3));
        const tSnap = await getDocs(tQuery);
        
        const teachersData = await Promise.all(tSnap.docs.map(async (docSnap) => {
          const tData = docSnap.data();
          let studentsCount = 0;
          try {
            const courseQuery = query(collection(db, "courses"), where("teacherId", "==", docSnap.id));
            const courseSnap = await getDocs(courseQuery);
            courseSnap.docs.forEach(cDoc => {
              const cData = cDoc.data();
              if (cData.enrolledStudents && Array.isArray(cData.enrolledStudents)) {
                studentsCount += cData.enrolledStudents.length;
              }
              if (cData.studentsEnrolled) {
                studentsCount += Number(cData.studentsEnrolled);
              }
            });
          } catch (e) {
            console.error("Error fetching courses for teacher:", e);
          }
          return { id: docSnap.id, ...tData, studentsCount };
        }));
        
        setTeachers(teachersData);

        // Fetch courses for the slider
        const cQuery = query(collection(db, "courses"), limit(6));
        const cSnap = await getDocs(cQuery);
        setFeaturedCourses(cSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      } catch (err) {
        console.error("Home fetch error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  const scrollSlider = (direction: "left" | "right") => {
    if (sliderRef.current) {
      const scrollAmount = direction === "left" ? -400 : 400;
      sliderRef.current.scrollBy({ left: scrollAmount, behavior: "smooth" });
    }
  };

  if (!mounted) return <div className="min-h-screen bg-[#1F1F1F]" />;

  return (
    <main className="min-h-screen font-sans bg-transparent">
      <Navbar />

      {/* ═══════ Cinematic Full-Width Hero ═══════ */}
      <section className="relative w-full overflow-hidden bg-transparent">
        {/* Match the container's aspect ratio exactly to the generated images to completely eliminate zooming/cropping */}
        <div className="relative w-full aspect-[9/16] md:aspect-[11/10] lg:aspect-auto lg:h-[100dvh]">
          {/* Desktop Image */}
          <Image
            src="/assets/images/web-hero.png"
            alt="Calligro Hero"
            fill
            className="hidden lg:block object-cover object-center"
            priority
          />
          {/* Tablet Image */}
          <Image
            src="/web_hero_tablet.png"
            alt="Calligro Hero"
            fill
            className="hidden md:block lg:hidden object-cover object-center"
            priority
          />
          {/* Mobile Image */}
          <Image
            src="/mobile_version_vertical.png"
            alt="Calligro Hero"
            fill
            className="block md:hidden object-cover object-center"
            priority
          />
        </div>




        {/* ════ Mobile Hero — Clean Stacked Layout ════ */}
        <div className="flex md:hidden absolute inset-0 z-10 flex-col justify-center items-center px-6 text-center" dir="rtl">
          {/* Dark overlay for contrast */}
          <div className="absolute inset-0 bg-black/50 z-[1] pointer-events-none" />
          
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="relative z-10 flex flex-col items-center gap-3 mt-10"
          >
            {/* The 50% خصم block */}
            <div className="flex flex-col items-center ml-10">
              <div 
                className="text-[#E8C468] font-bold" 
                style={{ 
                  fontFamily: locale === 'ar' ? '"Aref Ruqaa", serif' : 'var(--font-outfit), sans-serif', 
                  fontSize: 'clamp(55px, 16vw, 110px)', 
                  lineHeight: 1, 
                  textShadow: '0 4px 20px rgba(0,0,0,0.5)' 
                }}
              >
                {t("hero.promo.get")}
              </div>
              <div className="relative flex items-center justify-center -mt-3" dir="ltr">
                <div className="relative flex items-center justify-center">
                  {/* Watermark ghosted 50 */}
                  <div
                    className="absolute text-transparent pointer-events-none select-none"
                    style={{
                      fontFamily: 'var(--font-outfit), sans-serif',
                      fontSize: 'clamp(200px, 52vw, 360px)',
                      fontWeight: '900',
                      WebkitTextStroke: '2px rgba(255,255,255,0.07)',
                      lineHeight: 1,
                      letterSpacing: '-0.05em',
                      top: '50%',
                      left: '50%',
                      transform: 'translate(-50%, -50%)',
                    }}
                  >
                    50
                  </div>
                  {/* Solid white 50 with shine effect */}
                  <div className="relative overflow-hidden">
                    <span 
                      className="text-white font-black drop-shadow-2xl relative z-10 block" 
                      style={{ fontFamily: 'var(--font-outfit), sans-serif', fontSize: 'clamp(130px, 38vw, 220px)', lineHeight: 1 }}
                    >
                      50
                    </span>
                    <div
                      className="absolute inset-0 z-20 shine-sweep pointer-events-none"
                      style={{
                        background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.15), transparent)',
                        width: '60%',
                        height: '100%',
                      }}
                    />
                  </div>
                </div>
                
                {/* % badge absolutely positioned so it doesn't shift the centering of the 50 */}
                <div className="absolute right-full mr-2 top-1/2 -translate-y-1/2 flex items-center justify-center w-20 h-20 drop-shadow-xl seal-float z-20">
                  <div className="absolute inset-0 bg-[#E8C468] rounded-[6px]" />
                  <div className="absolute inset-0 bg-[#E8C468] rounded-[6px] rotate-45" />
                  <span className="absolute text-[#14100D] font-black text-4xl -mt-1" style={{ transform: 'rotate(-10deg)' }}>٪</span>
                </div>
              </div>
            </div>

            {/* Subtext */}
            <div 
              className="text-white drop-shadow-lg mt-1"
              style={{ 
                fontFamily: locale === 'ar' ? '"Aref Ruqaa", serif' : 'var(--font-outfit), sans-serif', 
                fontSize: locale === 'ar' ? 'clamp(24px, 7vw, 42px)' : 'clamp(18px, 5vw, 28px)', 
                lineHeight: 1.4 
              }}
            >
              {t("hero.promo.on_all_courses_limited")}
              <br />
              <span 
                className="relative inline-block mt-5 px-8 py-4 text-[#14100D] font-bold shadow-lg" 
                style={{ 
                  fontFamily: locale === 'ar' ? '"Aref Ruqaa", serif' : 'var(--font-outfit), sans-serif', 
                  fontSize: locale === 'ar' ? '30px' : '22px' 
                }}
              >
                <svg className="absolute inset-0 w-full h-full text-[#E8C468] -z-10 drop-shadow-md" preserveAspectRatio="none" viewBox="0 0 100 100" fill="currentColor">
                  <path d="M2,4 L12,1 L25,5 L40,2 L60,4 L75,1 L88,5 L97,2 L99,20 L96,40 L100,60 L97,80 L96,96 L85,99 L70,95 L50,98 L30,94 L15,98 L4,95 L1,80 L4,60 L0,40 L3,20 Z" />
                </svg>
                {t("hero.promo.dont_miss")}
              </span>
            </div>

            {/* CTA Buttons */}
            <div className="flex flex-col w-full max-w-sm gap-3 mt-6" dir={isRTL ? 'rtl' : 'ltr'}>
              <Link href="/courses">
                <button
                  className="flex items-center justify-center gap-3 w-full px-6 py-5 rounded-2xl font-bold bg-[#E8C468] text-[#211A08] shadow-[0_8px_25px_rgba(232,196,104,0.25)]"
                  style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '20px' }}
                >
                  {t("hero.cta.join")}
                  <ArrowRight className={`w-6 h-6 ${isRTL ? 'rotate-180' : ''}`} />
                </button>
              </Link>
              <Link href="/download">
                <button
                  className="w-full px-6 py-5 rounded-2xl font-medium text-white/90 border-2 border-white/30 bg-black/20 backdrop-blur-md"
                  style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '20px' }}
                >
                  {t("hero.cta.app")}
                </button>
              </Link>
            </div>
          </motion.div>
        </div>

        {/* ════ Tablet Hero — Diagonal Composition ════ */}
        <div className="hidden md:flex lg:hidden absolute inset-0 z-10 flex-col justify-center items-center overflow-hidden" dir="rtl">
          
          {/* Dark overlay for better contrast */}
          <div className="absolute inset-0 bg-black/40 z-[1] pointer-events-none" />

          {/* Subtle ornamental background pattern */}
          <svg className="absolute inset-0 w-full h-full pointer-events-none z-0" xmlns="http://www.w3.org/2000/svg">
            {/* Diagonal lines pattern */}
            <defs>
              <pattern id="diagLines" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(-45)">
                <line x1="0" y1="0" x2="0" y2="40" stroke="rgba(232,196,104,0.04)" strokeWidth="0.5" />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#diagLines)" />
            {/* Concentric circles — top right */}
            <circle cx="85%" cy="20%" r="80" fill="none" stroke="rgba(232,196,104,0.06)" strokeWidth="0.5" />
            <circle cx="85%" cy="20%" r="120" fill="none" stroke="rgba(232,196,104,0.04)" strokeWidth="0.5" />
            <circle cx="85%" cy="20%" r="160" fill="none" stroke="rgba(232,196,104,0.03)" strokeWidth="0.5" />
            {/* Concentric circles — bottom left */}
            <circle cx="15%" cy="75%" r="60" fill="none" stroke="rgba(232,196,104,0.05)" strokeWidth="0.5" />
            <circle cx="15%" cy="75%" r="100" fill="none" stroke="rgba(232,196,104,0.035)" strokeWidth="0.5" />
          </svg>



          {/* ── Diagonal Composition Container (600×400) ── */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.15, ease: "easeOut" }}
            className="relative z-10 scale-[0.6] min-[800px]:scale-75 md:scale-100 origin-center"
            style={{ width: '620px', height: '380px' }}
          >


            {/* ── "خصم" — top right, largest element ── */}
            <div
              className="absolute z-20 text-[#E8C468] font-bold"
              style={{
                fontFamily: '"Aref Ruqaa", serif',
                fontSize: '150px',
                fontWeight: 700,
                transform: 'rotate(-5deg)',
                textShadow: '0 8px 30px rgba(0,0,0,0.5)',
                whiteSpace: 'nowrap',
                lineHeight: 0.7,
                fontFeatureSettings: '"liga" 1, "calt" 1, "rlig" 1',
                top: '-30px',
                right: '120px',
              }}
            >
              {t("hero.title_top")}
            </div>

            {/* ── "50" — center, with watermark + shine sweep ── */}
            <div
              className="absolute z-10"
              style={{ top: '110px', left: '100px' }}
            >
              {/* Watermark ghosted 50 */}
              <div
                className="absolute text-transparent pointer-events-none select-none"
                style={{
                  fontFamily: 'var(--font-outfit), sans-serif',
                  fontSize: '280px',
                  fontWeight: '900',
                  WebkitTextStroke: '1.5px rgba(255,255,255,0.07)',
                  lineHeight: 1,
                  letterSpacing: '-0.05em',
                  top: '-55%',
                  left: '-30%',
                }}
                dir="ltr"
              >
                50
              </div>

              {/* Solid white 50 with shine effect */}
              <div className="relative overflow-hidden" dir="ltr">
                <span
                  className="text-white relative z-10 block"
                  style={{
                    fontFamily: 'var(--font-outfit), sans-serif',
                    fontSize: '150px',
                    fontWeight: '900',
                    lineHeight: 0.9,
                    letterSpacing: '-0.04em',
                    textShadow: '0 6px 20px rgba(0,0,0,0.4)',
                  }}
                >
                  50
                </span>
                {/* Shine sweep bar */}
                <div
                  className="absolute inset-0 z-20 shine-sweep pointer-events-none"
                  style={{
                    background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.15), transparent)',
                    width: '60%',
                    height: '100%',
                  }}
                />
              </div>
            </div>

            {/* ── Percent Seal — bottom left, smallest, floating ── */}
            <div
              className="absolute z-10 seal-float"
              style={{ bottom: '20px', left: '-50px' }}
            >
              <div
                className="relative flex items-center justify-center"
                style={{ width: '125px', height: '125px' }}
              >
                {/* 8-point star: two rotated squares */}
                <div className="absolute inset-0 bg-[#E8C468] rounded-[4px]" />
                <div className="absolute inset-0 bg-[#E8C468] rounded-[4px] rotate-45" />
                {/* ٪ stamp */}
                <span
                  className="absolute text-[#14100D] font-black select-none"
                  style={{ fontSize: '42px', transform: 'rotate(-12deg)', marginTop: '2px' }}
                >
                  ٪
                </span>
              </div>
            </div>

            {/* ── Subtext — Ruqaa style, in the space below خصم on the right ── */}
            <div
              className="absolute z-20 text-center"
              dir="rtl"
              style={{
                fontFamily: '"Aref Ruqaa", serif',
                fontSize: '54px',
                fontWeight: 'normal',
                WebkitTextStroke: '0.8px #FFFFFF',
                color: '#FFFFFF',
                lineHeight: 1.3,
                fontFeatureSettings: '"liga" 1, "calt" 1, "rlig" 1',
                top: '90px',
                right: '-140px',
                width: '450px',
                textShadow: '0 4px 15px rgba(0,0,0,0.6)',
              }}
            >
              على
              <br />
              جميع الدورات،
              <br />
              لفترة محدودة فقط
              <br />
              <span className="relative inline-block mt-3 px-6 py-1 text-[#14100D]" style={{ WebkitTextStroke: '0px', textShadow: 'none' }}>
                {/* Yellow background with rough/scratchy edges */}
                <svg className="absolute inset-0 w-full h-full text-[#E8C468] -z-10 drop-shadow-md" preserveAspectRatio="none" viewBox="0 0 100 100" fill="currentColor">
                  <path d="M2,4 L12,1 L25,5 L40,2 L60,4 L75,1 L88,5 L97,2 L99,20 L96,40 L100,60 L97,80 L96,96 L85,99 L70,95 L50,98 L30,94 L15,98 L4,95 L1,80 L4,60 L0,40 L3,20 Z" />
                </svg>
                لا تفوّت الفرصة
              </span>
            </div>
          </motion.div>



          {/* ── CTA Buttons ── */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.55, ease: "easeOut" }}
            className="flex flex-row gap-5 relative z-20 mt-24 translate-y-40"
            dir={isRTL ? 'rtl' : 'ltr'}
          >
            <Link href="/courses">
              <button
                className="flex items-center justify-center gap-3 px-10 py-4 rounded-xl font-bold bg-[#E8C468] text-[#211A08] hover:bg-[#F4DE90] transition-all duration-300 shadow-[0_8px_25px_rgba(232,196,104,0.25)] hover:shadow-[0_12px_35px_rgba(232,196,104,0.35)] hover:-translate-y-0.5"
                style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '17px' }}
              >
                {t("hero.cta.join")}
                <ArrowRight className={`w-5 h-5 ${isRTL ? 'rotate-180' : ''}`} />
              </button>
            </Link>
            <Link href="/download">
              <button
                className="px-10 py-4 rounded-xl font-medium text-white/90 border border-white/[0.35] bg-transparent hover:bg-white/10 hover:border-white/50 transition-all duration-300 backdrop-blur-sm"
                style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '17px' }}
              >
                {t("hero.cta.app")}
              </button>
            </Link>
          </motion.div>

          {/* Scroll indicator */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 0.5, y: [0, 6, 0] }}
            transition={{ opacity: { delay: 1.5, duration: 0.5 }, y: { delay: 1.5, duration: 2, repeat: Infinity } }}
            className="absolute bottom-6 left-1/2 -translate-x-1/2 z-20"
          >
            <svg width="20" height="28" viewBox="0 0 20 28" fill="none"><path d="M10 2v16m0 0l-5-5m5 5l5-5" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" opacity="0.6"/></svg>
          </motion.div>
        </div>


        {/* ════ Desktop Hero Content — Diagonal Composition (same as tablet, scaled up) ════ */}
        <div className="hidden lg:flex absolute inset-0 z-10 flex-col justify-center items-start pr-24 xl:pr-32 overflow-hidden" dir="rtl">
          
          {/* Dark overlay for better contrast on the desktop background */}
          <div className="absolute inset-0 bg-black/20 z-[1] pointer-events-none" />

          {/* Subtle ornamental background pattern */}
          <svg className="absolute inset-0 w-full h-full pointer-events-none z-[2]" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern id="diagLinesDesktop" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(-45)">
                <line x1="0" y1="0" x2="0" y2="40" stroke="rgba(232,196,104,0.04)" strokeWidth="0.5" />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#diagLinesDesktop)" />
            <circle cx="85%" cy="20%" r="100" fill="none" stroke="rgba(232,196,104,0.06)" strokeWidth="0.5" />
            <circle cx="85%" cy="20%" r="150" fill="none" stroke="rgba(232,196,104,0.04)" strokeWidth="0.5" />
            <circle cx="85%" cy="20%" r="200" fill="none" stroke="rgba(232,196,104,0.03)" strokeWidth="0.5" />
            <circle cx="15%" cy="75%" r="80" fill="none" stroke="rgba(232,196,104,0.05)" strokeWidth="0.5" />
            <circle cx="15%" cy="75%" r="120" fill="none" stroke="rgba(232,196,104,0.035)" strokeWidth="0.5" />
          </svg>

          {/* ── Desktop Composition — Horizontal Layout ── */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.15, ease: "easeOut" }}
            className="relative z-10 flex flex-col items-start gap-10"
          >

            {/* ── Row 1: خصم + 50 + ٪ on the same line ── */}
            <div className="flex items-center gap-6" dir={locale === 'ar' ? 'rtl' : 'ltr'}>
              {/* GET / خصم / İNDİRİM */}
              <div
                className="text-[#E8C468] font-bold tracking-widest"
                style={{
                  fontFamily: locale === 'ar' ? '"Aref Ruqaa", serif' : 'var(--font-outfit), sans-serif',
                  fontSize: locale === 'ar' ? '140px' : locale === 'tr' ? 'clamp(40px, 6vw, 75px)' : 'clamp(60px, 9vw, 110px)',
                  fontWeight: 900,
                  textShadow: '0 8px 30px rgba(0,0,0,0.5)',
                  whiteSpace: 'nowrap',
                  lineHeight: 0.9,
                  fontFeatureSettings: '"liga" 1, "calt" 1, "rlig" 1',
                  paddingTop: locale === 'ar' ? '0' : '1rem',
                }}
              >
                {t("hero.promo.get")}
              </div>

              {/* 50 */}
              <div className="relative" dir="ltr">
                {/* Watermark ghosted 50 */}
                <div
                  className="absolute text-transparent pointer-events-none select-none"
                  style={{
                    fontFamily: 'var(--font-outfit), sans-serif',
                    fontSize: '300px',
                    fontWeight: '900',
                    WebkitTextStroke: '1.5px rgba(255,255,255,0.07)',
                    lineHeight: 1,
                    letterSpacing: '-0.05em',
                    top: '-50%',
                    left: '-25%',
                  }}
                >
                  50
                </div>
                <div className="relative overflow-hidden">
                  <span
                    className="text-white relative z-10 block"
                    style={{
                      fontFamily: 'var(--font-outfit), sans-serif',
                      fontSize: '160px',
                      fontWeight: '900',
                      lineHeight: 0.9,
                      letterSpacing: '-0.04em',
                      textShadow: '0 6px 20px rgba(0,0,0,0.4)',
                    }}
                  >
                    50
                  </span>
                  {/* Shine sweep bar */}
                  <div
                    className="absolute inset-0 z-20 shine-sweep pointer-events-none"
                    style={{
                      background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.15), transparent)',
                      width: '60%',
                      height: '100%',
                    }}
                  />
                </div>
              </div>

              {/* Percent Seal */}
              <div className="seal-float">
                <div
                  className="relative flex items-center justify-center"
                  style={{ width: '120px', height: '120px' }}
                >
                  <div className="absolute inset-0 bg-[#E8C468] rounded-[4px]" />
                  <div className="absolute inset-0 bg-[#E8C468] rounded-[4px] rotate-45" />
                  <span
                    className="absolute text-[#14100D] font-black select-none"
                    style={{ fontSize: '42px', transform: 'rotate(-12deg)', marginTop: '2px' }}
                  >
                    ٪
                  </span>
                </div>
              </div>
            </div>

            {/* ── Row 2: Subtext in 2 lines ── */}
            <div
              className="text-white drop-shadow-lg mt-2 mb-8 max-w-[800px]"
              style={{
                fontFamily: locale === 'ar' ? '"Aref Ruqaa", serif' : 'var(--font-outfit), sans-serif',
                fontSize: locale === 'ar' ? '52px' : 'clamp(24px, 4vw, 36px)',
                fontWeight: locale === 'ar' ? 'normal' : '500',
                WebkitTextStroke: locale === 'ar' ? '0.8px #FFFFFF' : '0px',
                color: '#FFFFFF',
                lineHeight: 1.4,
                fontFeatureSettings: '"liga" 1, "calt" 1, "rlig" 1',
                textShadow: '0 4px 15px rgba(0,0,0,0.6)',
              }}
            >
              {t("hero.promo.on_all_courses_limited")}
              <br />
              <span className="relative inline-block mt-3 px-6 py-1 text-[#14100D]" style={{ WebkitTextStroke: '0px', textShadow: 'none' }}>
                {/* Yellow background with rough/scratchy edges */}
                <svg className="absolute inset-0 w-full h-full text-[#E8C468] -z-10 drop-shadow-md" preserveAspectRatio="none" viewBox="0 0 100 100" fill="currentColor">
                  <path d="M2,4 L12,1 L25,5 L40,2 L60,4 L75,1 L88,5 L97,2 L99,20 L96,40 L100,60 L97,80 L96,96 L85,99 L70,95 L50,98 L30,94 L15,98 L4,95 L1,80 L4,60 L0,40 L3,20 Z" />
                </svg>
                {t("hero.promo.dont_miss")}
              </span>
            </div>

            {/* ── Row 3: CTA Buttons (centered with content above) ── */}
            <div
              className="flex flex-row gap-5"
              dir={isRTL ? 'rtl' : 'ltr'}
            >
              <Link href="/courses">
                <button
                  className="flex items-center justify-center gap-3 px-10 py-4 rounded-xl font-bold bg-[#E8C468] text-[#211A08] hover:bg-[#F4DE90] transition-all duration-300 shadow-[0_8px_25px_rgba(232,196,104,0.25)] hover:shadow-[0_12px_35px_rgba(232,196,104,0.35)] hover:-translate-y-0.5"
                  style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '17px' }}
                >
                  {t("hero.cta.join")}
                  <ArrowRight className={`w-5 h-5 ${isRTL ? 'rotate-180' : ''}`} />
                </button>
              </Link>
              <Link href="/download">
                <button
                  className="px-10 py-4 rounded-xl font-medium text-white/90 border border-white/[0.35] bg-transparent hover:bg-white/10 hover:border-white/50 transition-all duration-300 backdrop-blur-sm"
                  style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '17px' }}
                >
                  {t("hero.cta.app")}
                </button>
              </Link>
            </div>
          </motion.div>
        </div>
      </section>



      {/* ═══════ 1. THE INTERACTIVE BENTO GRID (Stats) ═══════ */}
      <section className="relative w-full bg-[#1F1F1F] py-32 z-20 overflow-hidden">
        <div className="max-w-[1400px] mx-auto px-6">
          <div className="text-center mb-20 relative z-10">
            <h2 className="text-5xl md:text-7xl font-black font-outfit text-transparent bg-clip-text bg-gradient-to-r from-white to-[#FFF0C0] mb-6 tracking-tighter">
              {t("home.vision.title")}
            </h2>
            <p className="text-white/50 text-xl max-w-2xl mx-auto">{t("home.vision.desc")}</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              { front: t("home.vision.1.front"), reveal: t("home.vision.1.reveal"), color: "from-blue-600 to-cyan-400", colSpan: "md:col-span-2" },
              { front: t("home.vision.2.front"), reveal: t("home.vision.2.reveal"), color: "from-primary to-orange-400", colSpan: "md:col-span-1" },
              { front: t("home.vision.3.front"), reveal: t("home.vision.3.reveal"), color: "from-purple-600 to-pink-500", colSpan: "md:col-span-1" },
              { front: t("home.vision.4.front"), reveal: t("home.vision.4.reveal"), color: "from-emerald-500 to-teal-400", colSpan: "md:col-span-2" },
            ].map((stat, i) => (
              <div 
                key={i} 
                className={`group relative overflow-hidden rounded-[40px] bg-white/[0.02] border border-white/5 p-12 min-h-[300px] cursor-default transition-all duration-500 ${stat.colSpan}`}
              >
                {/* Default State (Front Container) */}
                <div className="absolute inset-0 p-12 flex flex-col justify-between z-10 transition-transform duration-700 ease-[cubic-bezier(0.25,1,0.5,1)] group-hover:-translate-y-[120%]">
                  <h4 className="text-4xl md:text-5xl font-black font-outfit text-white tracking-tighter max-w-[80%] leading-tight">{stat.front}</h4>
                  <div className="flex items-center gap-4">
                    <div className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center">
                      <ArrowRight className="w-4 h-4 text-white -rotate-45" />
                    </div>
                  </div>
                </div>

                {/* Hidden Hover State (Inner Container Reveal) */}
                <div className={`absolute inset-0 p-12 flex flex-col justify-center bg-gradient-to-br ${stat.color} translate-y-full group-hover:translate-y-0 transition-transform duration-700 ease-[cubic-bezier(0.25,1,0.5,1)] z-20`}>
                  <p className="text-black uppercase tracking-[0.2em] text-xs font-black mb-4">{stat.front}</p>
                  <h4 className="text-2xl md:text-3xl font-black font-outfit text-black leading-tight max-w-lg">{stat.reveal}</h4>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ 2. THE INTERACTIVE ACCORDION (Courses) ═══════ */}
      <section className="relative w-full bg-[#1F1F1F] py-24 z-20">
        <div className="max-w-[1600px] mx-auto px-6">
          <div className="flex flex-col md:flex-row justify-between items-end mb-16 gap-6">
            <div>
              <h2 className="text-4xl md:text-6xl font-black font-outfit text-white tracking-tighter">{t("home.courses.title")}</h2>
              <p className="text-primary mt-4 font-bold uppercase tracking-[0.2em] text-sm">{t("home.courses.subtitle")}</p>
            </div>
            <Link href="/courses">
              <button className="flex items-center gap-3 px-8 py-4 rounded-full border border-white/10 hover:border-primary/50 hover:bg-primary/10 text-white transition-all group">
                <span className="font-bold tracking-widest uppercase text-xs">{t("home.courses.view_all")}</span>
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </button>
            </Link>
          </div>

          {/* Pure CSS Expanding Accordion Gallery */}
          <div className="flex flex-col md:flex-row h-[80vh] md:h-[60vh] gap-4 w-full">
            {loading ? (
              <div className="w-full h-full flex items-center justify-center text-white/50">{t("home.courses.loading")}</div>
            ) : (
              featuredCourses.slice(0, 5).map((course) => (
                <Link 
                  href={`/courses/${course.id}`} 
                  key={course.id} 
                  className="relative flex-1 md:flex-[1] hover:flex-[3] md:hover:flex-[4] overflow-hidden rounded-[32px] group transition-all duration-700 ease-[cubic-bezier(0.25,1,0.5,1)]"
                >
                  <div className="absolute inset-0 bg-black/80 z-10 group-hover:bg-black/20 transition-colors duration-700" />
                  <Image 
                    src={formatImageUrl(course.courseBanner || course.thumbnailUrl) || "/assets/images/Logo.png"} 
                    alt={course.courseName || course.title || "Course"} 
                    fill 
                    className="object-cover scale-125 group-hover:scale-100 transition-transform duration-1000" 
                  />
                  
                  {/* Default State (Collapsed) */}
                  <div className="absolute inset-0 z-20 flex flex-col justify-end p-4 md:p-6 opacity-100 group-hover:opacity-0 transition-opacity duration-300 bg-gradient-to-t from-black/90 via-black/40 to-transparent">
                    <h3 className="text-white font-bold font-outfit text-xl line-clamp-3 leading-snug text-center md:text-right">
                      <AutoTranslatedText text={course.courseName || course.title || t("home.courses.title")} />
                    </h3>
                  </div>

                  {/* Hover State (Expanded) */}
                  <div className="absolute inset-0 z-20 p-6 md:p-10 flex flex-col justify-end opacity-0 group-hover:opacity-100 transition-opacity duration-700 delay-100">
                    <div className="bg-white/10 backdrop-blur-xl border border-white/20 p-6 md:p-8 rounded-3xl translate-y-10 group-hover:translate-y-0 transition-transform duration-700">
                      {course.courseLevel && (
                        <span className="bg-primary text-black text-[10px] md:text-xs font-black px-3 py-1.5 rounded-full uppercase tracking-widest inline-flex items-center gap-1 mb-3 shadow-lg">
                          <Award className="w-3 h-3" /> {course.courseLevel}
                        </span>
                      )}
                      <h3 className="text-2xl md:text-3xl font-black font-outfit text-white mb-4 leading-tight line-clamp-3">
                        <AutoTranslatedText text={course.courseName || course.title} />
                      </h3>
                      <div className="flex flex-wrap items-center gap-4 text-white/80 font-medium text-sm md:text-base">
                        {course.teacherName && (
                          <div className="flex items-center gap-2">
                            <span className="w-4 h-4 text-primary flex items-center justify-center">
                              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
                            </span>
                            <span>{course.teacherName}</span>
                          </div>
                        )}
                        {course.startDate && formatCourseDate(course.startDate, locale) && (
                          <div className="flex items-center gap-2">
                            <Clock className="w-4 h-4 text-primary" />
                            <span>
                              {formatCourseDate(course.startDate, locale)}
                              {course.endDate && formatCourseDate(course.endDate, locale) && ` - ${formatCourseDate(course.endDate, locale)}`}
                            </span>
                          </div>
                        )}
                        {course.price != null && course.price > 0 && (
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-[#E8C468]">${course.price}</span>
                          </div>
                        )}
                        {course.price === 0 && (
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-[#E8C468]">{t("course.free") || "Free"}</span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </Link>
              ))
            )}
          </div>
        </div>
      </section>

      {/* ═══════ 3. THE STICKY CANVAS (Why Calligro) ═══════ */}
      <section className="relative w-full bg-[#1F1F1F] py-32 z-20 border-y border-white/5">
        <div className="max-w-7xl mx-auto px-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-20">
            {/* Sticky Left Visual */}
            <div className="hidden md:block relative z-10">
              <div className="sticky top-40 h-[60vh] border border-white/10 rounded-[40px] overflow-hidden group shadow-2xl">
                <Image 
                  src="/assets/images/premium_experience.png"
                  alt="Premium Experience"
                  fill
                  className="object-cover group-hover:scale-110 transition-transform duration-1000"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent" />
                <div className="absolute inset-0 bg-primary/10 mix-blend-overlay pointer-events-none" />
                
                <div className="relative w-full h-full flex flex-col items-center justify-end p-12 text-center z-10">
                  <div className="w-16 h-16 rounded-full border border-primary/30 flex items-center justify-center mb-6 backdrop-blur-md bg-black/40 shadow-xl">
                    <Sparkles className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="text-4xl font-black font-outfit text-white mb-4">{t("home.premium.title")}</h3>
                  <p className="text-white/70 text-lg font-medium drop-shadow-md">{t("home.premium.desc")}</p>
                </div>
              </div>
            </div>

            {/* Scrolling Right Content */}
            <div className="flex flex-col gap-32 py-20 relative">
              {[
                { title: t("home.features.video.title"), icon: Play, desc: t("home.features.video.desc") },
                { title: t("home.features.community.title"), icon: Users, desc: t("home.features.community.desc") },
                { title: t("home.features.certificates.title"), icon: Award, desc: t("home.features.certificates.desc") }
              ].map((feature, i) => (
                <div key={i} className="flex flex-col sm:flex-row gap-8 group relative z-10 items-start">
                  
                  {/* Large Ghost Number Background */}
                  <div className="absolute -top-16 -right-10 text-[140px] font-black text-white/[0.02] group-hover:text-primary/[0.05] transition-colors duration-700 pointer-events-none font-outfit select-none -z-10">
                    0{i + 1}
                  </div>

                  {/* Icon Timeline Node */}
                  <div className="relative shrink-0 mt-2">
                    <div className="absolute inset-0 bg-primary/20 blur-xl rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-700" />
                    <div className="w-16 h-16 rounded-full bg-[#121212] border border-white/10 flex items-center justify-center group-hover:border-primary/50 group-hover:scale-110 transition-all duration-700 relative z-10">
                      <feature.icon className="w-7 h-7 text-white/50 group-hover:text-primary transition-colors duration-700" />
                    </div>
                  </div>
                  
                  <div className="flex flex-col pt-3">
                    <h3 className="text-3xl md:text-5xl font-black font-outfit text-white mb-6 tracking-tight group-hover:text-primary transition-colors duration-700">{feature.title}</h3>
                    <p className="text-white/50 text-lg md:text-xl leading-relaxed max-w-lg group-hover:text-white/80 transition-colors duration-700">{feature.desc}</p>
                    
                    {/* Animated Expanding Divider */}
                    <div className="w-12 h-px bg-white/20 mt-10 group-hover:w-full group-hover:bg-primary/50 transition-all duration-1000 ease-out" />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ═══════ 4. THE MASTERS' HALL (Teachers) ═══════ */}
      <section className="relative w-full bg-[#1F1F1F] py-40 z-20 overflow-hidden">
        <div className="max-w-7xl mx-auto px-6 mb-16 flex flex-col md:flex-row items-center justify-between gap-8">
          <div className="text-center md:text-start">
            <h2 className="text-5xl md:text-7xl font-black font-outfit text-white mb-4 tracking-tight">{t("home.teachers.title")}</h2>
            <p className="text-white/40 text-sm font-medium uppercase tracking-[0.3em]">{t("home.teachers.subtitle")}</p>
          </div>
          
          <Link href="/teachers">
            <button className="px-6 py-3 rounded-full bg-white/5 border border-white/10 text-white font-bold hover:bg-white/10 hover:border-white/20 transition-all duration-300 flex items-center gap-3">
              <span>{t("home.teachers.view_all") || (isRTL ? "عرض جميع الأساتذة" : "View All Masters")}</span>
              <div className="w-6 h-6 rounded-full bg-[#E8C468]/20 flex items-center justify-center">
                <span className="text-[#E8C468] text-sm leading-none">{isRTL ? '←' : '→'}</span>
              </div>
            </button>
          </Link>
        </div>

        <div className="w-full max-w-[1400px] mx-auto px-6 pb-12 overflow-x-auto hide-scrollbar snap-x snap-mandatory cursor-grab active:cursor-grabbing">
          <div className="flex items-center justify-center gap-6 min-w-full w-max py-10" dir="ltr"> {/* ltr ensures smooth carousel behavior universally */}
            {teachers.map((teacher, i) => (
              <motion.div 
                key={teacher.id}
                initial={{ opacity: 0, scale: 0.95 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: i * 0.1 }}
                className="w-[280px] md:w-[320px] snap-center shrink-0 bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 flex flex-col items-center text-center relative group hover:bg-white/10 transition-colors duration-500 shadow-2xl"
              >
                {/* Elegant Circular Avatar */}
                <div className="w-32 h-32 rounded-full overflow-hidden mb-6 relative border border-white/20 group-hover:border-[#E8C468]/50 transition-colors duration-500 shadow-[0_0_30px_rgba(0,0,0,0.5)] group-hover:shadow-[0_0_40px_rgba(232,196,104,0.15)]">
                  <Image 
                    src={formatImageUrl(teacher.photoUrl || teacher.profileImage) || "/assets/images/Logo.png"}
                    alt={teacher.name || "Teacher"}
                    fill 
                    className="object-cover" 
                  />
                </div>
                
                {/* Badge */}
                <span className="bg-[#E8C468]/10 text-[#E8C468] px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest mb-4">
                  {t("home.teachers.certified")}
                </span>
                
                {/* Name */}
                <h3 className="text-2xl font-black font-outfit text-white mb-6 leading-tight">
                  {teacher.fullName || teacher.name || t("home.teachers.title")}
                </h3>
                
                {/* Stats */}
                <div className="flex items-center justify-center gap-4 w-full pt-5 border-t border-white/10">
                  <div className="flex items-center gap-1.5">
                    <Star className="w-4 h-4 fill-[#E8C468] text-[#E8C468]" />
                    <span className="text-white font-bold">{Number(teacher.rating || 5.0).toFixed(1)}</span>
                  </div>
                  <div className="w-1 h-1 rounded-full bg-white/20" />
                  <div className="flex items-center gap-1.5">
                    <Users className="w-4 h-4 text-white/40" />
                    <span className="text-white/50 text-sm font-medium">
                      {teacher.studentsCount || 0} {t("home.teachers.students").toLowerCase()}
                    </span>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ 5. THE FINAL CALL (Refined CTA) ═══════ */}
      <section className="relative w-full bg-[#1F1F1F] py-40 z-20 pb-48">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 1 }}
            className="flex flex-col items-center"
          >
            <h2 className="text-6xl md:text-8xl font-black font-outfit text-white mb-8 tracking-tighter leading-tight">
              {t("home.cta.title")}
            </h2>
            <p className="text-white/50 text-xl md:text-2xl mb-16 font-light max-w-2xl">
              {t("home.cta.desc")}
            </p>
            
            <Link href="/login">
              <button className="px-12 py-5 rounded-full bg-white text-black font-semibold text-sm hover:scale-105 transition-transform duration-300">
                {t("home.cta.btn")}
              </button>
            </Link>
          </motion.div>
        </div>
      </section>
      
      <Footer />
    </main>
  );
}
