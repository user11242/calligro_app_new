"use client";
import { useEffect, useState } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { db } from "@/lib/firebase";
import { collection, query, limit, getDocs, orderBy, where } from "firebase/firestore";
import Image from "next/image";
import { Star, ArrowRight, Play, Layout, Users, Sparkles } from "lucide-react";
import { formatImageUrl } from "@/lib/utils";
import { useTranslation } from "@/hooks/useTranslation";

export default function Home() {
  const [teachers, setTeachers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [mounted, setMounted] = useState(false);
  const { t, locale } = useTranslation();

  useEffect(() => {
    setMounted(true);
    const fetchMasters = async () => {
      try {
        // Fetch teachers from the 'users' collection
        const q = query(
          collection(db, "users"),
          where("role", "==", "teacher"),
          limit(3)
        );
        const snap = await getDocs(q);
        setTeachers(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      } catch (err) {
        console.error("Home fetch error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchMasters();
  }, []);

  if (!mounted) return <div className="min-h-screen bg-[#0a0a0a]" />;

  return (
    <main className="academy-bg min-h-screen font-sans">
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
            src={
              locale === "en" ? "/assets/images/web-hero-en-mobile.png" :
                locale === "tr" ? "/assets/images/web-hero-tr-mobile.png" :
                  "/assets/images/web-hero-ar-mobile.png"
            }
            alt="Calligro Hero"
            fill
            className="block md:hidden object-cover object-center"
            priority
          />
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
            className="relative z-10"
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

        {/* ════ Mobile CTA Buttons (Normal flow below image) ════ */}
        <div className="md:hidden w-full px-6 pt-6 pb-12 flex flex-col items-center z-20 relative bg-gradient-to-b from-[#161616] to-[#0a0a0a]" dir="ltr">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1 }}
            className="w-full max-w-sm flex flex-col gap-4"
          >
            <Link href="/courses" className="w-full">
              <button className="group flex items-center justify-center gap-4 w-full px-8 py-5 rounded-full text-sm font-black uppercase tracking-widest bg-primary text-black hover:scale-105 transition-transform shadow-[0_0_30px_rgba(255,215,0,0.15)]">
                {t("hero.cta.join")}
                <ArrowRight className="w-5 h-5 group-hover:translate-x-2 transition-transform" />
              </button>
            </Link>
            <Link href="/download" className="w-full">
              <button className="w-full px-8 py-5 rounded-full text-sm font-black uppercase tracking-widest text-white border-2 border-white/20 hover:bg-white/10 backdrop-blur-md transition-all">
                {t("hero.cta.app")}
              </button>
            </Link>
          </motion.div>
        </div>

        {/* ════ Desktop Hero Content (Absolutely positioned over image) ════ */}
        <div className="hidden lg:flex absolute right-16 xl:right-32 top-1/2 -translate-y-1/2 z-20 pointer-events-none">
          {/* Ambient gold glow behind text */}
          <div className="hero-ambient-glow" style={{ top: '50%', left: '50%', transform: 'translate(-50%, -50%)' }} />

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6 }}
            className="flex flex-col items-end text-right pointer-events-auto relative"
          >
            {/* "خصم" - animated gold shimmer, large italic */}
            <motion.span
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.8, delay: 0.2 }}
              className="gold-text font-black text-7xl xl:text-8xl leading-none mb-2 font-outfit italic"
            >
              {t("hero.title_top")}
            </motion.span>

            {/* "50%" - force LTR so 50 is before %, massive 3D embossed */}
            <motion.h1
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.8, delay: 0.4, type: "spring", stiffness: 100 }}
              className="leading-[0.82] mb-6 font-outfit flex items-baseline"
              dir="ltr"
              style={{ fontSize: 'clamp(150px, 18vw, 260px)' }}
            >
              <span className="font-black hero-number-3d tracking-tight">50</span>
              <span className="font-black gold-percent-3d" style={{ fontSize: '0.7em', marginLeft: '-4px' }}>%</span>
            </motion.h1>

            {/* Decorative gold line */}
            <motion.div
              initial={{ scaleX: 0 }}
              animate={{ scaleX: 1 }}
              transition={{ duration: 0.6, delay: 0.6 }}
              className="gold-line mb-5 self-end origin-right"
            />

            {/* Subtitle */}
            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.7 }}
              className="text-2xl xl:text-3xl text-white/90 font-semibold leading-relaxed mb-10 tracking-wide"
              style={{ textShadow: '0 2px 10px rgba(0,0,0,0.5)' }}
            >
              {t("hero.subtitle")}
            </motion.p>

            {/* Buttons row */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.9 }}
              className="flex flex-row gap-4 items-center"
              dir="ltr"
            >
              <Link href="/courses">
                <button className="group flex items-center justify-center gap-4 px-12 py-5 rounded-full text-sm font-black uppercase tracking-widest bg-primary text-black hover:scale-105 transition-transform btn-cta-glow">
                  {t("hero.cta.join")}
                  <ArrowRight className="w-5 h-5 group-hover:translate-x-2 transition-transform" />
                </button>
              </Link>
              <Link href="/download">
                <button className="px-12 py-5 rounded-full text-sm font-black uppercase tracking-widest text-white border-2 border-white/20 hover:bg-white/10 hover:border-white/40 backdrop-blur-md transition-all">
                  {t("hero.cta.app")}
                </button>
              </Link>
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* ═══════ Advanced Modern About Section ═══════ */}
      <section className="relative py-32 px-6 overflow-hidden">
        {/* Animated Background Elements */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full pointer-events-none z-0">
          <motion.div
            animate={{
              scale: [1, 1.2, 1],
              opacity: [0.1, 0.2, 0.1],
              rotate: [0, 90, 0]
            }}
            transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
            className="absolute -top-[20%] -left-[10%] w-[600px] h-[600px] bg-primary/10 rounded-full blur-[120px]"
          />
          <motion.div
            animate={{
              scale: [1.2, 1, 1.2],
              opacity: [0.1, 0.15, 0.1],
              rotate: [0, -90, 0]
            }}
            transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
            className="absolute top-[40%] -right-[10%] w-[500px] h-[500px] bg-primary/5 rounded-full blur-[100px]"
          />
        </div>

        <div className="max-w-7xl mx-auto relative z-10">
          <div className="text-center mb-24">
            <motion.span
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="text-xs font-black text-primary uppercase tracking-[0.4em] mb-6 inline-block"
            >
              {t("home.about.title")}
            </motion.span>
            <motion.h2
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="text-5xl md:text-7xl font-black font-outfit tracking-tighter text-white mb-8 leading-none"
            >
              {t("home.about.subtitle")}
            </motion.h2>
            <motion.p
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.2 }}
              className="text-lg md:text-xl text-white/50 max-w-3xl mx-auto font-medium leading-relaxed"
            >
              {t("home.about.desc")}
            </motion.p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 mb-8">
            {/* Mission Card */}
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              whileHover={{ y: -10 }}
              className="lg:col-span-7 glass-premium p-10 md:p-14 rounded-[48px] border border-white/10 bg-black/40 backdrop-blur-3xl flex flex-col justify-between group overflow-hidden relative"
            >
              <div className="absolute top-0 right-0 p-12 opacity-5 group-hover:opacity-10 transition-opacity">
                <Sparkles className="w-48 h-48 text-primary" />
              </div>
              <div>
                <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center border border-primary/20 mb-10 group-hover:scale-110 transition-transform">
                  <Layout className="w-8 h-8 text-primary" />
                </div>
                <h3 className="text-3xl md:text-4xl font-black font-outfit text-white mb-6 tracking-tight uppercase">
                  {t("home.about.mission")}
                </h3>
                <p className="text-white/60 text-lg leading-relaxed max-w-xl">
                  {t("home.about.mission_desc")}
                </p>
              </div>
            </motion.div>

            {/* Vision Card */}
            <motion.div
              initial={{ opacity: 0, x: 30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              whileHover={{ y: -10 }}
              className="lg:col-span-5 glass-premium p-10 md:p-14 rounded-[48px] border border-white/10 bg-primary/[0.03] backdrop-blur-3xl flex flex-col group overflow-hidden relative"
            >
              <div className="w-16 h-16 rounded-2xl bg-primary/20 flex items-center justify-center border border-primary/30 mb-10 group-hover:rotate-12 transition-transform">
                <Users className="w-8 h-8 text-primary" />
              </div>
              <h3 className="text-3xl md:text-4xl font-black font-outfit text-white mb-6 tracking-tight uppercase">
                {t("home.about.vision")}
              </h3>
              <p className="text-white/60 text-lg leading-relaxed">
                {t("home.about.vision_desc")}
              </p>
            </motion.div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Feature 1 */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.1 }}
              whileHover={{ scale: 1.02 }}
              className="glass-premium p-10 rounded-[40px] border border-white/5 bg-white/[0.02] hover:border-primary/40 transition-all group"
            >
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-8 border border-white/10 group-hover:bg-primary group-hover:text-black transition-all">
                <Play className="w-5 h-5" />
              </div>
              <h4 className="text-xl font-black text-white mb-4 uppercase tracking-tight">
                {t("home.about.feature1.title")}
              </h4>
              <p className="text-white/40 text-sm leading-relaxed">
                {t("home.about.feature1.desc")}
              </p>
            </motion.div>

            {/* Feature 2 */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.2 }}
              whileHover={{ scale: 1.02 }}
              className="glass-premium p-10 rounded-[40px] border border-white/5 bg-white/[0.02] hover:border-primary/40 transition-all group"
            >
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-8 border border-white/10 group-hover:bg-primary group-hover:text-black transition-all">
                <Users className="w-5 h-5" />
              </div>
              <h4 className="text-xl font-black text-white mb-4 uppercase tracking-tight">
                {t("home.about.feature2.title")}
              </h4>
              <p className="text-white/40 text-sm leading-relaxed">
                {t("home.about.feature2.desc")}
              </p>
            </motion.div>

            {/* Feature 3 */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.3 }}
              whileHover={{ scale: 1.02 }}
              className="glass-premium p-10 rounded-[40px] border border-white/5 bg-white/[0.02] hover:border-primary/40 transition-all group"
            >
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-8 border border-white/10 group-hover:bg-primary group-hover:text-black transition-all">
                <Sparkles className="w-5 h-5" />
              </div>
              <h4 className="text-xl font-black text-white mb-4 uppercase tracking-tight">
                {t("home.about.feature3.title")}
              </h4>
              <p className="text-white/40 text-sm leading-relaxed">
                {t("home.about.feature3.desc")}
              </p>
            </motion.div>
          </div>
        </div>
      </section>

      {/* ═══════ Modern Teachers Section ═══════ */}
      <section className="relative py-32 px-6 max-w-7xl mx-auto z-10">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="flex flex-col md:flex-row justify-between items-end mb-24 gap-8"
        >
          <div className="text-start">
            <p className="text-[10px] md:text-xs font-black text-primary uppercase tracking-[0.3em] mb-4">{t("home.trending")}</p>
            <h2 className="text-3xl md:text-5xl lg:text-7xl font-black font-outfit tracking-tighter text-white leading-none">
              {t("teachers.title")}
            </h2>
          </div>
          <Link href="/teachers" className="glass-premium px-10 py-5 rounded-full text-xs font-black uppercase tracking-[0.2em] text-white/80 hover:text-primary transition-all border-white/10 shadow-xl flex items-center gap-4 group">
            {t("home.enter_library")}
            <ArrowRight className="w-5 h-5 group-hover:translate-x-2 transition-transform" />
          </Link>
        </motion.div>

        <AnimatePresence mode="wait">
          {loading ? (
            <motion.div
              key="skeletons"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="grid grid-cols-1 md:grid-cols-3 gap-12 col-span-full"
            >
              {Array(3).fill(0).map((_, i) => (
                <div key={i} className="glass-premium rounded-[64px] aspect-[4/5] bg-white/5 border-white/5 animate-pulse" />
              ))}
            </motion.div>
          ) : (
            <motion.div
              key="content"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="grid grid-cols-1 md:grid-cols-3 gap-12 col-span-full"
            >
              {teachers.map((teacher, i) => (
                <motion.div
                  key={teacher.id}
                  initial={{ opacity: 0, scale: 0.9, y: 40 }}
                  whileInView={{ opacity: 1, scale: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: i * 0.2, duration: 0.8, ease: [0.23, 1, 0.32, 1] }}
                  whileHover={{ y: -20 }}
                  className="group relative"
                >
                  {/* Decorative Background Glow */}
                  <div className="absolute inset-0 bg-primary/5 rounded-[64px] blur-2xl group-hover:bg-primary/10 transition-colors duration-500" />

                  <div className="relative glass-premium rounded-[64px] p-10 border border-white/10 bg-black/40 backdrop-blur-3xl overflow-hidden flex flex-col items-center text-center h-full shadow-2xl">

                    {/* Teacher Image with Premium Frame */}
                    <div className="relative w-48 h-48 mb-10">
                      <div className="absolute inset-0 rounded-full border-2 border-primary/20 group-hover:border-primary transition-colors duration-500 animate-[spin_10s_linear_infinite] group-hover:animate-[spin_4s_linear_infinite] border-dashed" />
                      <div className="absolute inset-2 rounded-full border border-white/10" />
                      <div className="absolute inset-4 rounded-full overflow-hidden border-4 border-[#0a0a0a] shadow-2xl">
                        <Image
                          src={formatImageUrl(teacher.photoUrl || teacher.profileImage) || "/assets/images/Logo.png"}
                          alt={teacher.name || "Teacher"}
                          fill
                          className="object-cover grayscale group-hover:grayscale-0 transition-all duration-700 scale-110 group-hover:scale-100"
                        />
                      </div>

                      {/* Certified Badge */}
                      <div className="absolute -bottom-2 right-4 bg-primary text-black p-2 rounded-full shadow-xl border-4 border-[#0a0a0a] group-hover:scale-110 transition-transform">
                        <Sparkles className="w-5 h-5" />
                      </div>
                    </div>

                    <h3 className="text-3xl font-black font-outfit text-white mb-8 tracking-tight group-hover:gold-text transition-all">
                      {teacher.fullName || teacher.name || "Anonymous Master"}
                    </h3>

                    {/* Stats Row */}
                    <div className="grid grid-cols-2 gap-8 w-full py-8 border-y border-white/5 mb-10">
                      <div className="flex flex-col items-center">
                        <span className="text-2xl font-black text-white font-outfit">{teacher.followerCount || 0}</span>
                        <span className="text-[9px] font-black text-primary/60 uppercase tracking-widest">{t("course.students")}</span>
                      </div>
                      <div className="flex flex-col items-center border-l border-white/10">
                        <div className="flex items-center gap-1">
                          <Star className="w-4 h-4 text-primary fill-primary" />
                          <span className="text-2xl font-black text-white font-outfit">{Number(teacher.rating || 5.0).toFixed(1)}</span>
                        </div>
                        <span className="text-[9px] font-black text-primary/60 uppercase tracking-widest">{t("course.rating")}</span>
                      </div>
                    </div>

                    {/* Action Button */}
                    <Link href={`/teachers/${teacher.id}`} className="w-full py-5 rounded-3xl bg-white/5 border border-white/10 text-white font-black uppercase tracking-[0.2em] text-[10px] hover:bg-primary hover:text-black hover:border-primary transition-all shadow-inner">
                      {t("course.learn_more")}
                    </Link>
                  </div>
                </motion.div>
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </section>

      <Footer />
    </main>
  );
}
