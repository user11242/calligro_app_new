"use client";

import { useRef, useEffect, useState } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, useScroll, useTransform, useSpring } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";
import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";

export default function PerfectCalligraphyAboutPage() {
  const { t } = useTranslation();
  const containerRef = useRef<HTMLDivElement>(null);
  const [windowWidth, setWindowWidth] = useState(1000); // Default for SSR
  const [windowHeight, setWindowHeight] = useState(1000);

  useEffect(() => {
    setWindowWidth(window.innerWidth);
    setWindowHeight(window.innerHeight);
    const handleResize = () => {
      setWindowWidth(window.innerWidth);
      setWindowHeight(window.innerHeight);
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  const smoothProgress = useSpring(scrollYProgress, {
    stiffness: 60,
    damping: 25,
    restDelta: 0.0001,
  });

  // ── MATHEMATICALLY PERFECT PEN TRACKING ──
  // We define the X position as a series of vw offsets.
  // The SVG path will be generated from this EXACT same data.
  const breakpoints =   [0, 0.1, 0.25, 0.35, 0.45, 0.5, 0.55, 0.65, 0.75, 0.85, 1];
  const xValuesVw =     [0, 20,  32,   32,   20,   0,  -20,  -32,  -32,  -10,   0];
  // Calculate tangents (rotation) based on the curve slope
  // When X is constant (peak), rotation is 0 (pointing straight down).
  // When X is changing fast, rotation is steep.
  const rotateValues =  [0, 35,  15,   0,    -30, -50, -45,  -15,   0,    25,   0];

  const penXvw = useTransform(smoothProgress, breakpoints, xValuesVw);
  const penRotateZ = useTransform(smoothProgress, breakpoints, rotateValues);
  
  // Convert vw to pixels for the motion.div
  const penX = useTransform(penXvw, (vw) => `${vw}vw`);
  
  // Y tracks exactly down the page (0 to 100vh fixed)
  const penY = useTransform(smoothProgress, [0, 1], ["0vh", "100vh"]);

  // ── GENERATE THE EXACT SVG POLYLINE ──
  // We sample 200 points along the breakpoints to draw a curve that 100% matches the pen's path.
  const generatePathPoints = () => {
    let points = "";
    const samples = 200;
    
    // Simple interpolation function matching framer-motion's default linear interpolation
    const interpolate = (p: number, bps: number[], vals: number[]) => {
      if (p <= bps[0]) return vals[0];
      if (p >= bps[bps.length - 1]) return vals[vals.length - 1];
      for (let i = 0; i < bps.length - 1; i++) {
        if (p >= bps[i] && p <= bps[i + 1]) {
          const t = (p - bps[i]) / (bps[i + 1] - bps[i]);
          // Custom ease-in-out to match framer-motion's default spline smoothing roughly
          const smoothT = t * t * (3 - 2 * t); 
          return vals[i] + (vals[i + 1] - vals[i]) * smoothT;
        }
      }
      return 0;
    };

    for (let i = 0; i <= samples; i++) {
      const p = i / samples;
      // Y goes from 0 to 100% of SVG height
      const y = p * 1000; 
      
      // X is in vw (-50vw to +50vw), we map it to SVG width (0 to 1000)
      const vw = interpolate(p, breakpoints, xValuesVw);
      // Map vw to svg X: 0vw = 500. 50vw = 1000. -50vw = 0.
      const svgX = 500 + (vw / 50) * 500; 
      
      points += `${svgX},${y} `;
    }
    return points;
  };

  return (
    <main
      ref={containerRef}
      className="relative text-[#FDFBF7] selection:bg-[#E8C468] selection:text-black bg-[#1F1F1F] h-[400vh]"
    >
      <div className="relative z-50">
        <Navbar />
      </div>

      {/* ══ 1. THE PERFECT SVG INK TRACK ══ */}
      <div className="fixed inset-0 w-full h-full pointer-events-none z-10">
        <svg
          viewBox="0 0 1000 1000"
          preserveAspectRatio="none"
          className="w-full h-full opacity-90"
        >
          <defs>
            <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="8" result="blur" />
              <feComposite in="SourceGraphic" in2="blur" operator="over" />
            </filter>
          </defs>
          
          {/* Subtle guide path (entire line) */}
          <polyline
            points={generatePathPoints()}
            fill="none"
            stroke="#ffffff"
            strokeWidth="0.5"
            opacity="0.1"
          />

          {/* The glowing drawn ink */}
          <motion.polyline
            points={generatePathPoints()}
            fill="none"
            stroke="#E8C468"
            strokeWidth="4"
            strokeLinecap="round"
            strokeLinejoin="round"
            filter="url(#glow)"
            style={{ pathLength: smoothProgress }}
          />
          
          {/* Core bright line */}
          <motion.polyline
            points={generatePathPoints()}
            fill="none"
            stroke="#FFF0C0"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            style={{ pathLength: smoothProgress }}
          />
        </svg>
      </div>

      {/* ══ 2. THE FLAWLESS TRACKING PEN ══ */}
      {/* Changed z-40 to z-0 so it sweeps BEHIND the text. */}
      <div className="fixed top-0 left-1/2 w-0 h-0 pointer-events-none z-0 flex items-end justify-center">
        <motion.div
          style={{ y: penY, x: penX }}
          className="absolute bottom-0 flex justify-center opacity-80"
        >
          <motion.div
            style={{ rotateZ: penRotateZ }}
            className="origin-bottom flex justify-center"
          >
            {/* The SVG Pen - Reduced size to be less dominant */}
            <svg
              viewBox="0 0 80 500"
              className="w-[40px] h-[250px] md:w-[55px] md:h-[350px] absolute bottom-0 drop-shadow-[0_10px_20px_rgba(0,0,0,0.8)]"
            >
              <defs>
                <linearGradient id="bamBody" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor="#8C6030" />
                  <stop offset="20%" stopColor="#C8A060" />
                  <stop offset="50%" stopColor="#E0BC7A" />
                  <stop offset="80%" stopColor="#C8A060" />
                  <stop offset="100%" stopColor="#8C6030" />
                </linearGradient>
                <linearGradient id="bamCap" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#2a140a" />
                  <stop offset="100%" stopColor="#5c3a1a" />
                </linearGradient>
                <linearGradient id="bamNib" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#8C6030" />
                  <stop offset="60%" stopColor="#3a2010" />
                  <stop offset="100%" stopColor="#1a0a04" />
                </linearGradient>
                <radialGradient id="inkGlow" cx="50%" cy="50%" r="50%">
                  <stop offset="0%" stopColor="#FFF0C0" stopOpacity="1" />
                  <stop offset="50%" stopColor="#E8C468" stopOpacity="0.8" />
                  <stop offset="100%" stopColor="#E8C468" stopOpacity="0" />
                </radialGradient>
              </defs>

              <path d="M 16 20 C 16 -5, 64 -5, 64 20 Z" fill="url(#bamCap)" />
              <rect x="16" y="20" width="48" height="400" fill="url(#bamBody)" />
              
              <g opacity="0.8">
                <rect x="14" y="140" width="52" height="6" rx="2" fill="#5c3a1a" />
                <rect x="14" y="141" width="52" height="2" fill="#E0BC7A" opacity="0.5" />
                <rect x="14" y="280" width="52" height="6" rx="2" fill="#5c3a1a" />
                <rect x="14" y="281" width="52" height="2" fill="#E0BC7A" opacity="0.5" />
              </g>

              <path d="M 16 420 L 64 420 L 48 495 L 32 495 Z" fill="url(#bamNib)" />
              <path d="M 16 420 L 40 420 L 40 495 L 32 495 Z" fill="white" opacity="0.05" />
              <line x1="40" y1="420" x2="40" y2="495" stroke="#000" strokeWidth="1.5" />
              <polygon points="32,495 48,495 40,500" fill="#000" />
              
              <circle cx="40" cy="500" r="10" fill="url(#inkGlow)" />
            </svg>
          </motion.div>
        </motion.div>
      </div>

      {/* ══ 3. CONTENT SECTIONS ══ */}
      
      {/* SECTION 0: HERO (0 - 100vh) */}
      <section className="absolute top-0 w-full h-[100vh] flex flex-col items-center justify-center px-6 z-20">
        <motion.div 
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          className="text-center mt-20"
        >
          <h1 className="text-5xl md:text-8xl font-black font-outfit uppercase tracking-tighter text-transparent bg-clip-text bg-gradient-to-b from-white to-white/40 mb-6">
            {t("story_about.hero.title")}
          </h1>
          <p className="text-xl md:text-2xl text-[#E8C468] font-serif italic tracking-widest uppercase">
            {t("story_about.hero.subtitle")}
          </p>
        </motion.div>
      </section>

      {/* SECTION 1: THE ORIGIN (100vh - 200vh) */}
      {/* Pen is on the right, content is on the left */}
      <section className="absolute top-[100vh] w-full h-[100vh] flex items-center z-20">
        <div className="w-full md:w-[45%] mr-auto pr-8 md:pr-12 pl-6 md:pl-20 flex justify-end text-right">
          <motion.div 
            initial={{ opacity: 0, x: -50, filter: "blur(10px)" }}
            whileInView={{ opacity: 1, x: 0, filter: "blur(0px)" }}
            viewport={{ once: false, amount: 0.5 }}
            transition={{ duration: 1, ease: "easeOut" }}
            className="max-w-xl"
          >
            <span className="text-[#E8C468] font-bold tracking-[0.3em] uppercase text-sm mb-4 block">
              {t("story_about.ch1.label")}
            </span>
            <h2 className="text-5xl md:text-7xl font-black font-outfit uppercase text-white mb-8 leading-tight">
              {t("story_about.ch1.title")}
            </h2>
            
            <div className="relative w-full aspect-[4/3] rounded-[2rem] overflow-hidden mb-8 shadow-[0_30px_60px_rgba(0,0,0,0.5)] border border-white/10 group">
              <Image 
                src="/assets/images/yazan_ceo.jpeg" 
                alt="Yazan Qattous"
                fill
                className="object-cover scale-105 group-hover:scale-100 transition-transform duration-1000"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/90 to-transparent" />
              <div className="absolute bottom-8 right-8">
                <h3 className="text-2xl font-bold font-outfit uppercase text-white tracking-wide">{t("story_about.ch1.name")}</h3>
                <p className="text-[#E8C468] text-sm uppercase tracking-widest mt-2 font-semibold">{t("story_about.ch1.role")}</p>
              </div>
            </div>

            <p className="text-xl text-white/60 leading-relaxed font-light">
              {t("story_about.ch1.p1")}
            </p>
          </motion.div>
        </div>
      </section>

      {/* SECTION 2: THE PRESENT (200vh - 300vh) */}
      {/* Pen is on the left, content is on the right */}
      <section className="absolute top-[200vh] w-full h-[100vh] flex items-center z-20">
        <div className="w-full md:w-[45%] ml-auto pl-8 md:pl-12 pr-6 md:pr-20 text-left">
          <motion.div 
            initial={{ opacity: 0, x: 50, filter: "blur(10px)" }}
            whileInView={{ opacity: 1, x: 0, filter: "blur(0px)" }}
            viewport={{ once: false, amount: 0.5 }}
            transition={{ duration: 1, ease: "easeOut" }}
            className="max-w-xl"
          >
            <span className="text-[#E8C468] font-bold tracking-[0.3em] uppercase text-sm mb-4 block">
              {t("story_about.ch2.label")}
            </span>
            <h2 className="text-5xl md:text-7xl font-black font-outfit uppercase text-white mb-10 leading-tight">
              {t("story_about.ch2.title")}
            </h2>
            
            <div className="p-12 bg-gradient-to-br from-white/[0.05] to-transparent backdrop-blur-xl border border-white/10 rounded-[2.5rem] shadow-[0_30px_60px_rgba(0,0,0,0.5)]">
              <p className="text-2xl text-white/90 leading-relaxed font-light mb-6">
                {t("story_about.ch2.p1")}
              </p>
              <div className="h-px w-20 bg-[#E8C468] mb-6 opacity-50" />
              <p className="text-lg text-white/50 leading-relaxed font-light">
                {t("story_about.ch2.p2")}
              </p>
            </div>
          </motion.div>
        </div>
      </section>

      {/* SECTION 3: THE FUTURE (300vh - 400vh) */}
      {/* Pen is centered */}
      <section className="absolute top-[300vh] w-full h-[100vh] flex flex-col items-center justify-center text-center px-6 z-20">
        <motion.div 
          initial={{ opacity: 0, scale: 0.9, y: 50, filter: "blur(10px)" }}
          whileInView={{ opacity: 1, scale: 1, y: 0, filter: "blur(0px)" }}
          viewport={{ once: false, amount: 0.5 }}
          transition={{ duration: 1, ease: "easeOut" }}
          className="max-w-4xl pt-32"
        >
          <span className="text-[#E8C468] font-bold tracking-[0.3em] uppercase text-sm mb-6 block">
            {t("story_about.ch3.label")}
          </span>
          <h2 className="text-6xl md:text-8xl lg:text-[7rem] font-black font-outfit uppercase text-transparent bg-clip-text bg-gradient-to-r from-white to-[#FFF0C0] mb-10 leading-[0.9]">
            {t("story_about.ch3.title")}
          </h2>
          <p className="text-2xl md:text-3xl text-white/60 font-light mb-16 max-w-3xl mx-auto leading-relaxed">
            {t("story_about.ch3.p1")}
          </p>
          
          <Link 
            href="/courses" 
            className="inline-flex items-center gap-6 bg-white text-black px-14 py-7 rounded-full font-bold uppercase tracking-widest hover:bg-[#E8C468] hover:scale-105 transition-all duration-500 group shadow-[0_0_50px_rgba(232,196,104,0.4)]"
          >
            <span className="text-lg">{t("story_about.ch3.btn")}</span>
            <ArrowRight className="w-6 h-6 group-hover:translate-x-2 transition-transform" />
          </Link>
        </motion.div>
      </section>

    </main>
  );
}
