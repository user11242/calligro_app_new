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
  const { t, isRTL } = useTranslation();
  
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
        setTeachers(tSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })));

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

  if (!mounted) return <div className="min-h-screen bg-[#0a0a0a]" />;

  return (
    <main className="min-h-screen font-sans bg-[#050505]">
      <Navbar />

      {/* ═══════ Cinematic Full-Width Hero ═══════ */}
      <section className="relative w-full overflow-hidden bg-[#161616]">
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
                style={{ fontFamily: '"Aref Ruqaa", serif', fontSize: 'clamp(55px, 16vw, 110px)', lineHeight: 1, textShadow: '0 4px 20px rgba(0,0,0,0.5)' }}
              >
                {t("hero.title_top")}
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
              style={{ fontFamily: '"Aref Ruqaa", serif', fontSize: 'clamp(24px, 7vw, 42px)', lineHeight: 1.4 }}
            >
              على جميع الدورات،
              <br />
              لفترة محدودة فقط
              <br />
              <span className="relative inline-block mt-5 px-8 py-4 text-[#14100D] text-3xl font-bold shadow-lg" style={{ fontFamily: '"Aref Ruqaa", serif' }}>
                <svg className="absolute inset-0 w-full h-full text-[#E8C468] -z-10 drop-shadow-md" preserveAspectRatio="none" viewBox="0 0 100 100" fill="currentColor">
                  <path d="M2,4 L12,1 L25,5 L40,2 L60,4 L75,1 L88,5 L97,2 L99,20 L96,40 L100,60 L97,80 L96,96 L85,99 L70,95 L50,98 L30,94 L15,98 L4,95 L1,80 L4,60 L0,40 L3,20 Z" />
                </svg>
                لا تفوّت الفرصة
              </span>
            </div>

            {/* CTA Buttons */}
            <div className="flex flex-col w-full max-w-sm gap-3 mt-6">
              <Link href="/courses">
                <button
                  className="flex items-center justify-center gap-3 w-full px-6 py-5 rounded-2xl font-bold bg-[#E8C468] text-[#211A08] shadow-[0_8px_25px_rgba(232,196,104,0.25)]"
                  style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '20px' }}
                >
                  {t("hero.cta.join")}
                  <ArrowRight className="w-6 h-6 rotate-180" />
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
            dir="rtl"
          >
            <Link href="/courses">
              <button
                className="flex items-center justify-center gap-3 px-10 py-4 rounded-xl font-bold bg-[#E8C468] text-[#211A08] hover:bg-[#F4DE90] transition-all duration-300 shadow-[0_8px_25px_rgba(232,196,104,0.25)] hover:shadow-[0_12px_35px_rgba(232,196,104,0.35)] hover:-translate-y-0.5"
                style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '17px' }}
              >
                {t("hero.cta.join")}
                <ArrowRight className="w-5 h-5 rotate-180" />
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
            className="relative z-10 flex flex-col items-center gap-10"
          >

            {/* ── Row 1: خصم + 50 + ٪ on the same line ── */}
            <div className="flex items-center gap-6" dir="rtl">
              {/* خصم */}
              <div
                className="text-[#E8C468] font-bold"
                style={{
                  fontFamily: '"Aref Ruqaa", serif',
                  fontSize: '140px',
                  fontWeight: 700,
                  textShadow: '0 8px 30px rgba(0,0,0,0.5)',
                  whiteSpace: 'nowrap',
                  lineHeight: 0.9,
                  fontFeatureSettings: '"liga" 1, "calt" 1, "rlig" 1',
                }}
              >
                {t("hero.title_top")}
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
              className="text-center"
              dir="rtl"
              style={{
                fontFamily: '"Aref Ruqaa", serif',
                fontSize: '52px',
                fontWeight: 'normal',
                WebkitTextStroke: '0.8px #FFFFFF',
                color: '#FFFFFF',
                lineHeight: 1.4,
                fontFeatureSettings: '"liga" 1, "calt" 1, "rlig" 1',
                textShadow: '0 4px 15px rgba(0,0,0,0.6)',
              }}
            >
              على جميع الدورات، لفترة محدودة فقط
              <br />
              <span className="relative inline-block mt-3 px-6 py-1 text-[#14100D]" style={{ WebkitTextStroke: '0px', textShadow: 'none' }}>
                {/* Yellow background with rough/scratchy edges */}
                <svg className="absolute inset-0 w-full h-full text-[#E8C468] -z-10 drop-shadow-md" preserveAspectRatio="none" viewBox="0 0 100 100" fill="currentColor">
                  <path d="M2,4 L12,1 L25,5 L40,2 L60,4 L75,1 L88,5 L97,2 L99,20 L96,40 L100,60 L97,80 L96,96 L85,99 L70,95 L50,98 L30,94 L15,98 L4,95 L1,80 L4,60 L0,40 L3,20 Z" />
                </svg>
                لا تفوّت الفرصة
              </span>
            </div>

            {/* ── Row 3: CTA Buttons (centered with content above) ── */}
            <div
              className="flex flex-row gap-5"
              dir="rtl"
            >
              <Link href="/courses">
                <button
                  className="flex items-center justify-center gap-3 px-10 py-4 rounded-xl font-bold bg-[#E8C468] text-[#211A08] hover:bg-[#F4DE90] transition-all duration-300 shadow-[0_8px_25px_rgba(232,196,104,0.25)] hover:shadow-[0_12px_35px_rgba(232,196,104,0.35)] hover:-translate-y-0.5"
                  style={{ fontFamily: 'var(--font-amiri), serif', fontSize: '17px' }}
                >
                  {t("hero.cta.join")}
                  <ArrowRight className="w-5 h-5 rotate-180" />
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

      {/* ═══════ DYNAMIC CATEGORIES BAR ═══════ */}
      <section className="w-full bg-[#0A0A0A] border-y border-white/5 py-4 z-20 relative shadow-2xl">
        <div className="max-w-[1400px] mx-auto px-6 overflow-x-auto hide-scrollbar">
          <div className="flex items-center gap-4 min-w-max" dir={isRTL ? "rtl" : "ltr"}>
            <span className="text-white/40 font-bold uppercase tracking-widest text-xs mr-4">Popular:</span>
            {["Diwani", "Thuluth", "Naskh", "Kufic", "Ruqaa", "Maghrebi", "Nastaliq"].map((cat) => (
              <button key={cat} className="px-6 py-2 rounded-full border border-white/10 bg-white/5 hover:bg-primary hover:text-black hover:border-primary transition-all font-bold text-sm text-white/80">
                {cat}
              </button>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ GLOBAL STATS BANNER ═══════ */}
      <section className="relative py-16 bg-gradient-to-b from-[#050505] to-[#0a0a0a] z-20">
        <div className="max-w-[1400px] mx-auto px-6" dir={isRTL ? "rtl" : "ltr"}>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 divide-x divide-white/10" dir="ltr">
            {[
              { label: "Active Students", value: "10,000+", icon: Users },
              { label: "Masterclasses", value: "50+", icon: Layout },
              { label: "Average Rating", value: "4.9/5", icon: Star },
              { label: "Certified Masters", value: "20+", icon: Medal },
            ].map((stat, i) => (
              <div key={i} className="flex flex-col items-center justify-center text-center px-4">
                <stat.icon className="w-8 h-8 text-primary mb-4" />
                <h4 className="text-3xl md:text-5xl font-black font-outfit text-white mb-2">{stat.value}</h4>
                <p className="text-white/40 uppercase tracking-widest text-xs font-bold">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ FEATURED COURSES SLIDER (Coursera/Udemy style but premium) ═══════ */}
      <section className="relative py-24 bg-[#050505] overflow-hidden z-20">
        <div className="max-w-[1400px] mx-auto px-6 mb-12 flex justify-between items-end" dir={isRTL ? "rtl" : "ltr"}>
          <div>
            <h2 className="text-3xl md:text-5xl font-black font-outfit text-white">Featured Courses</h2>
            <p className="text-primary mt-2 font-bold uppercase tracking-widest text-sm">Start your journey today</p>
          </div>
          <div className="flex gap-3">
            <button onClick={() => scrollSlider(isRTL ? "right" : "left")} className="w-12 h-12 rounded-full border border-white/10 bg-white/5 flex items-center justify-center hover:bg-primary hover:text-black transition-colors">
              <ChevronLeft className="w-6 h-6" />
            </button>
            <button onClick={() => scrollSlider(isRTL ? "left" : "right")} className="w-12 h-12 rounded-full border border-white/10 bg-white/5 flex items-center justify-center hover:bg-primary hover:text-black transition-colors">
              <ChevronRight className="w-6 h-6" />
            </button>
          </div>
        </div>

        {/* Horizontal Slider */}
        <div 
          ref={sliderRef}
          className="flex gap-6 overflow-x-auto hide-scrollbar px-6 max-w-[1400px] mx-auto pb-12 snap-x snap-mandatory"
          dir={isRTL ? "rtl" : "ltr"}
        >
          {loading ? (
            Array(4).fill(0).map((_, i) => (
              <div key={i} className="min-w-[320px] md:min-w-[400px] aspect-[4/5] bg-white/5 animate-pulse rounded-[32px] snap-center" />
            ))
          ) : (
            featuredCourses.map((course) => (
              <Link href={`/courses/${course.id}`} key={course.id} className="min-w-[320px] md:min-w-[400px] snap-center group">
                <GlowCard className="h-full flex flex-col p-6 cursor-pointer">
                  <div className="relative w-full aspect-video rounded-2xl overflow-hidden mb-6">
                    <Image 
                      src={formatImageUrl(course.thumbnailUrl) || "/assets/images/Logo.png"} 
                      alt={course.title} 
                      fill 
                      className="object-cover group-hover:scale-110 transition-transform duration-700" 
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent" />
                    <div className="absolute top-4 left-4 z-10">
                      {/* Bestseller Badge */}
                      <span className="bg-[#E8C468] text-black text-[10px] font-black px-3 py-1.5 rounded-full uppercase tracking-widest flex items-center gap-1 shadow-lg">
                        <Trophy className="w-3 h-3" /> Bestseller
                      </span>
                    </div>
                    <div className="absolute bottom-4 left-4 flex gap-2">
                      <span className="bg-black/60 backdrop-blur-md border border-white/20 text-white text-[10px] font-black px-3 py-1 rounded-full uppercase tracking-widest">
                        {course.level || "Beginner"}
                      </span>
                    </div>
                  </div>
                  <h3 className="text-2xl font-black font-outfit text-white mb-2 line-clamp-2 group-hover:text-primary transition-colors">
                    {course.title}
                  </h3>
                  <div className="flex items-center gap-4 mt-auto pt-6 border-t border-white/10 text-white/50 text-sm font-medium">
                    <div className="flex items-center gap-1">
                      <Clock className="w-4 h-4" />
                      <span>{course.durationWeeks || 4} Weeks</span>
                    </div>
                    <div className="flex items-center gap-1">
                      <BookOpen className="w-4 h-4" />
                      <span>{course.lessonsCount || 12} Lessons</span>
                    </div>
                  </div>
                </GlowCard>
              </Link>
            ))
          )}
        </div>
      </section>

      {/* ═══════ BENTO GRID ABOUT SECTION (Apple Style) ═══════ */}
      <section className="relative py-24 px-6 max-w-[1400px] mx-auto z-20" dir={isRTL ? "rtl" : "ltr"}>
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-6xl font-black font-outfit text-white mb-4">Why Calligro?</h2>
          <p className="text-white/50 max-w-2xl mx-auto text-lg">Experience the most advanced and immersive platform built specifically for learning the ancient arts.</p>
        </div>

        <div className="bento-grid">
          {/* Large Card: Video/Interactive feature */}
          <GlowCard className="bento-card-large p-10 flex flex-col justify-between min-h-[400px] bg-gradient-to-br from-white/5 to-transparent">
            <div>
              <div className="w-14 h-14 rounded-2xl bg-primary/20 flex items-center justify-center border border-primary/30 mb-6">
                <Play className="w-6 h-6 text-primary" />
              </div>
              <h3 className="text-3xl font-black font-outfit text-white mb-4">Interactive 4K Classrooms</h3>
              <p className="text-white/60 text-lg max-w-md">Join live sessions with multiple camera angles. Watch the master&apos;s pen strokes in crystal clear 4K resolution while interacting in real-time.</p>
            </div>
            {/* Abstract visual */}
            <div className="absolute right-0 bottom-0 w-[60%] h-[80%] opacity-20 pointer-events-none">
               <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
                <path fill="#F2E293" d="M42.7,-73.4C55.9,-65.4,67.6,-53.5,76.3,-39.6C85,-25.7,90.7,-9.8,87.9,5C85,19.8,73.6,33.5,61.9,45.1C50.2,56.7,38.2,66.1,23.8,72.4C9.4,78.7,-7.4,81.9,-23.4,79C-39.4,76,-54.6,66.9,-65.4,54.1C-76.2,41.3,-82.6,24.8,-84.9,7.8C-87.2,-9.2,-85.4,-26.7,-77.1,-41.2C-68.8,-55.7,-54,-67.2,-39.3,-74.6C-24.6,-82,-12.3,-85.3,1.9,-88.6C16.1,-91.9,32.2,-95.2,42.7,-73.4Z" transform="translate(100 100)" />
              </svg>
            </div>
          </GlowCard>

          {/* Medium Card: Community */}
          <GlowCard className="bento-card-medium p-10 flex flex-col justify-between bg-gradient-to-bl from-primary/10 to-transparent">
            <div>
               <div className="w-14 h-14 rounded-2xl bg-white/10 flex items-center justify-center border border-white/20 mb-6">
                <Users className="w-6 h-6 text-white" />
              </div>
              <h3 className="text-2xl font-black font-outfit text-white mb-4">Global Community</h3>
              <p className="text-white/60">Share your homework, get feedback from masters, and connect with calligraphy enthusiasts worldwide.</p>
            </div>
          </GlowCard>

          {/* Small Card: Certificate */}
          <GlowCard className="bento-card-small p-10 flex flex-col justify-center items-center text-center bg-white/5">
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-[#D4AF37] to-[#B8860B] flex items-center justify-center mb-6 shadow-[0_0_30px_rgba(212,175,55,0.4)]">
              <Star className="w-8 h-8 text-black fill-black" />
            </div>
            <h3 className="text-xl font-black font-outfit text-white">Verified Certificates</h3>
          </GlowCard>
          
          {/* Bottom Wide Card */}
          <GlowCard className="col-span-full p-10 md:p-14 bg-gradient-to-r from-black via-primary/5 to-black flex flex-col md:flex-row items-center justify-between gap-10">
            <div className="max-w-2xl">
              <h3 className="text-4xl font-black font-outfit text-white mb-4">Ready to start writing?</h3>
              <p className="text-white/60 text-lg">Join Calligro today and get access to our exclusive tools, community, and courses.</p>
            </div>
            <button className="whitespace-nowrap px-10 py-5 rounded-full bg-white text-black font-black uppercase tracking-widest hover:bg-primary transition-colors shadow-2xl">
              Join Now
            </button>
          </GlowCard>
        </div>
      </section>

      {/* ═══════ 3D TEACHERS SHOWCASE ═══════ */}
      <section className="relative py-24 px-6 max-w-[1400px] mx-auto z-20" dir={isRTL ? "rtl" : "ltr"}>
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-6xl font-black font-outfit text-white mb-4">Learn From The Masters</h2>
          <p className="text-primary font-bold uppercase tracking-widest">The best calligraphers in the world</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {teachers.map((teacher, i) => (
            <motion.div
              key={teacher.id}
              whileHover={{ scale: 1.05, rotateY: 10, rotateX: 5 }}
              className="relative perspective-1000"
            >
              <GlowCard className="h-full flex flex-col items-center text-center p-10 bg-black/40">
                <div className="relative w-40 h-40 mb-8">
                  <div className="absolute inset-0 rounded-full border-2 border-primary/30 animate-[spin_8s_linear_infinite] border-dashed" />
                  <div className="absolute inset-2 rounded-full overflow-hidden border-4 border-black">
                    <Image
                      src={formatImageUrl(teacher.photoUrl || teacher.profileImage) || "/assets/images/Logo.png"}
                      alt={teacher.name || "Teacher"}
                      fill
                      className="object-cover"
                    />
                  </div>
                </div>
                <h3 className="text-2xl font-black font-outfit text-white mb-6">
                  {teacher.fullName || teacher.name || "Master Calligrapher"}
                </h3>
                <div className="flex gap-6 border-t border-white/10 w-full pt-6 justify-center">
                  <div className="flex flex-col items-center">
                    <span className="text-xl font-black text-white">{teacher.followerCount || 0}</span>
                    <span className="text-[10px] text-white/40 uppercase tracking-widest">Students</span>
                  </div>
                  <div className="w-px h-10 bg-white/10" />
                  <div className="flex flex-col items-center">
                    <span className="text-xl font-black text-white flex items-center gap-1">
                      {Number(teacher.rating || 5.0).toFixed(1)} <Star className="w-4 h-4 text-primary fill-primary" />
                    </span>
                    <span className="text-[10px] text-white/40 uppercase tracking-widest">Rating</span>
                  </div>
                </div>
              </GlowCard>
            </motion.div>
          ))}
        </div>
      </section>

      {/* ═══════ THE MASTER'S JOURNEY (Learning Paths) ═══════ */}
      <section className="relative py-24 bg-[#050505] border-t border-white/5 z-20" dir={isRTL ? "rtl" : "ltr"}>
        <div className="max-w-[1400px] mx-auto px-6">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-6xl font-black font-outfit text-white mb-4">The Calligrapher&apos;s Journey</h2>
            <p className="text-white/50 max-w-2xl mx-auto text-lg">A structured path from your first stroke to creating timeless masterpieces.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 relative">
            {/* Connecting Line */}
            <div className="hidden md:block absolute top-1/2 left-[10%] right-[10%] h-[2px] bg-gradient-to-r from-primary/0 via-primary/30 to-primary/0 -translate-y-1/2" />
            
            {[
              { step: "01", title: "Foundations", desc: "Master the individual letters, tools preparation, and the correct posture.", icon: BookOpen },
              { step: "02", title: "Compositions", desc: "Learn how to connect letters and balance words in beautiful harmony.", icon: Layout },
              { step: "03", title: "Masterpieces", desc: "Create your own complex artworks and earn your traditional certificate (Ijazah).", icon: Award },
            ].map((path, i) => (
              <GlowCard key={i} className="relative p-10 bg-[#0A0A0A] flex flex-col items-center text-center border-t-4 border-t-primary/50 hover:border-t-primary transition-all z-10">
                <div className="w-16 h-16 rounded-full bg-primary/10 border border-primary/30 flex items-center justify-center text-primary mb-6 shadow-[0_0_20px_rgba(232,196,104,0.15)]">
                  <path.icon className="w-8 h-8" />
                </div>
                <div className="text-primary/50 font-black text-6xl font-outfit absolute -top-8 -left-4 opacity-30 select-none pointer-events-none">{path.step}</div>
                <h3 className="text-2xl font-black font-outfit text-white mb-3">{path.title}</h3>
                <p className="text-white/60">{path.desc}</p>
              </GlowCard>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ INFINITE TESTIMONIALS MARQUEE ═══════ */}
      <section className="relative py-24 bg-gradient-to-b from-[#0a0a0a] to-[#050505] overflow-hidden z-20">
        <div className="text-center mb-16 px-6 relative z-10">
          <h2 className="text-3xl md:text-5xl font-black font-outfit text-white mb-4">Trusted by 10,000+ Students</h2>
          <p className="text-primary font-bold uppercase tracking-widest text-sm">Join a global community of artists</p>
        </div>

        {/* Marquee Container */}
        <div className="relative flex overflow-x-hidden group">
          <div className="absolute inset-y-0 left-0 w-32 bg-gradient-to-r from-[#0a0a0a] to-transparent z-10 pointer-events-none" />
          <div className="absolute inset-y-0 right-0 w-32 bg-gradient-to-l from-[#0a0a0a] to-transparent z-10 pointer-events-none" />
          
          <motion.div 
            className="flex gap-6 px-3"
            animate={{ x: ["0%", "-50%"] }}
            transition={{ duration: 40, ease: "linear", repeat: Infinity }}
            style={{ width: "fit-content" }}
          >
            {/* Array duplicated to make infinite loop seamless */}
            {[...Array(2)].map((_, i) => (
              <div key={i} className="flex gap-6">
                {[
                  { name: "Sarah Ahmed", role: "Beginner", text: "I never thought I could learn calligraphy online, but the 4K multiple camera angles make it feel like the master is sitting right next to me.", rating: 5 },
                  { name: "Omar Youssef", role: "Intermediate", text: "The structured learning paths took me from struggling with basic letters to writing full compositions in just 3 months. Worth every penny.", rating: 5 },
                  { name: "Layla M.", role: "Advanced", text: "Getting direct feedback from world-renowned certified masters is a game changer. The community is incredibly supportive.", rating: 5 },
                  { name: "Tariq K.", role: "Beginner", text: "The Calligro platform is simply beautiful. It's fast, interactive, and the mobile app syncs my progress perfectly.", rating: 5 },
                  { name: "Aisha F.", role: "Intermediate", text: "I achieved my dream of writing the Thuluth script beautifully. Thank you Calligro for this amazing academy!", rating: 5 },
                ].map((testimonial, j) => (
                  <div key={j} className="w-[350px] md:w-[450px] p-8 rounded-3xl bg-white/5 border border-white/10 backdrop-blur-sm hover:bg-white/10 transition-colors shrink-0">
                    <div className="flex items-center gap-2 mb-6">
                      {[...Array(testimonial.rating)].map((_, k) => (
                        <Star key={k} className="w-5 h-5 fill-primary text-primary" />
                      ))}
                    </div>
                    <p className="text-white/80 text-lg italic mb-6 leading-relaxed">"{testimonial.text}"</p>
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-full bg-primary/20 flex items-center justify-center font-bold text-primary border border-primary/30">
                        {testimonial.name.charAt(0)}
                      </div>
                      <div>
                        <h4 className="font-bold text-white font-outfit">{testimonial.name}</h4>
                        <span className="text-xs text-white/40 uppercase tracking-widest">{testimonial.role}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ))}
          </motion.div>
        </div>
      </section>
      
      <Footer />
    </main>
  );
}
