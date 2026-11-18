"use client";

import { useTranslation } from "@/hooks/useTranslation";
import { formatImageUrl } from "@/lib/utils";

export interface CalligroCertificateProps {
  id?: string;
  certificateId: string;
  studentName: string;
  courseName: string;
  teacherName?: string;
  teacherSignatureUrl?: string | null;
  dateStr?: string;
  totalHours?: number | null;
  className?: string;
  style?: React.CSSProperties;
}

export default function CalligroCertificate({
  id = "print-area",
  certificateId,
  studentName,
  courseName,
  teacherName = "Master Instructor",
  teacherSignatureUrl,
  dateStr,
  totalHours,
  className = "",
  style = {},
}: CalligroCertificateProps) {
  const { t } = useTranslation();

  const effectiveDateStr =
    dateStr ||
    new Date().toLocaleDateString("ar-SA", {
      year: "numeric",
      month: "long",
      day: "numeric",
    });

  return (
    <div
      id={id}
      className={`w-[1123px] h-[794px] min-w-[1123px] relative overflow-hidden flex flex-col shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top select-none ${className}`}
      style={{
        boxSizing: "border-box",
        background: "radial-gradient(ellipse at 50% 45%, #FDFBF8 0%, #F9F5EC 65%, #F2EADB 100%)",
        fontFamily: "'Aref Ruqaa', 'Amiri', serif",
        ...style,
      }}
      dir="rtl"
    >
      {/* ─── LUXURY BACKGROUND WATERMARKS & TEXTURE ─── */}
      <div
        className="absolute inset-0 opacity-[0.025] pointer-events-none"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='80' height='80' viewBox='0 0 80 80' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='%238C6D23' fill-opacity='1'%3E%3Cpath d='M40 0L50 30L80 40L50 50L40 80L30 50L0 40L30 30z'/%3E%3Ccircle cx='40' cy='40' r='6' fill='none' stroke='%238C6D23' stroke-width='1.5'/%3E%3C/g%3E%3C/svg%3E")`,
        }}
      />

      {/* Large Central Watermark of Calligro Logo */}
      <div className="absolute inset-0 flex items-center justify-center opacity-[0.03] pointer-events-none">
        <img
          src="/assets/images/Logo.png"
          alt="Watermark"
          className="w-[520px] h-[520px] object-contain grayscale"
        />
      </div>

      {/* ─── ORNATE DIPLOMA MULTI-TIER BORDERS ─── */}
      <div className="absolute inset-[16px] border border-[#C5A059]/40 pointer-events-none z-10" />
      <div className="absolute inset-[22px] border-[3px] border-[#161616] pointer-events-none z-10" />
      <div className="absolute inset-[28px] border-[1.5px] border-[#D4AF37] pointer-events-none z-10" />
      <div className="absolute inset-[34px] border border-[#C5A059]/30 pointer-events-none z-10" />

      {/* ─── 4 CLASSICAL ISLAMIC ARABESQUE CORNER ORNAMENTS ─── */}
      <div className="absolute top-[28px] right-[28px] w-20 h-20 pointer-events-none z-20">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      <div className="absolute top-[28px] left-[28px] w-20 h-20 pointer-events-none z-20 transform scale-x-[-1]">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      <div className="absolute bottom-[28px] right-[28px] w-20 h-20 pointer-events-none z-20 transform scale-y-[-1]">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      <div className="absolute bottom-[28px] left-[28px] w-20 h-20 pointer-events-none z-20 transform scale-[-1]">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      {/* ─── MAIN CERTIFICATE CONTENT ─── */}
      <div className="relative z-30 w-full h-full px-24 py-14 flex flex-col justify-between items-center text-center">
        
        {/* ─── 1. HEADER SECTION ─── */}
        <div className="flex flex-col items-center">
          <div className="flex items-center gap-3.5 mb-1.5">
            <div className="w-12 h-12 rounded-full border border-[#D4AF37]/50 p-1 bg-white/40 shadow-sm flex items-center justify-center">
              <img
                src="/assets/images/Logo.png"
                alt="Calligro"
                className="w-full h-full object-contain"
              />
            </div>
            <div className="text-right">
              <h3 className="text-[#141414] text-2xl font-bold tracking-wide leading-none" style={{ fontFamily: "'Aref Ruqaa', serif" }}>
                أكاديمية كاليغرو لتعليم فنون الخط العربي
              </h3>
              <p className="text-[#8C6D23] text-[9.5px] uppercase font-sans font-bold tracking-[0.35em] mt-1">
                CALLIGRO ACADEMY OF ARABIC CALLIGRAPHY
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 my-2 w-72">
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
            <span className="text-[#C5A059] text-xs">✦ ❖ ✦</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
          </div>

          {/* Certificate Title: شهادة حضور */}
          <h1
            className="text-6xl font-black text-[#141414] tracking-wider mt-1 drop-shadow-sm"
            style={{
              fontFamily: "'Thuluth', 'Amiri', 'Aref Ruqaa', serif",
              textShadow: "0 1px 2px rgba(140, 109, 35, 0.15)",
            }}
          >
            شهادة حضور
          </h1>

          <p className="text-[#5A4E3A] text-sm uppercase tracking-[0.25em] font-sans font-semibold mt-3">
            {t("certificate.presented_to") || "تُمنح هذه الشهادة بكل فخر واعتزاز إلى:"}
          </p>
        </div>

        {/* ─── 2. RECIPIENT NAME (DIWANI LETTER) ─── */}
        <div className="relative my-2 w-full max-w-2xl flex flex-col items-center">
          <div className="w-56 h-[1px] bg-gradient-to-r from-transparent via-[#C5A059]/60 to-transparent mb-1" />

          <h2
            className="text-6xl md:text-7xl font-bold text-[#141414] py-1 text-center"
            style={{
              fontFamily: "'Diwani Letter', serif",
              lineHeight: "1.2",
              textShadow: "0 2px 4px rgba(0, 0, 0, 0.08)",
            }}
          >
            {studentName}
          </h2>

          <div className="flex items-center gap-2 mt-1 w-80">
            <div className="h-[1.5px] flex-1 bg-gradient-to-l from-[#C5A059] to-transparent" />
            <div className="w-2 h-2 rotate-45 bg-[#D4AF37] border border-[#8C6D23]/40" />
            <div className="h-[1.5px] flex-1 bg-gradient-to-r from-[#C5A059] to-transparent" />
          </div>
        </div>

        {/* ─── 3. ATTENDANCE & COURSE STATEMENT ─── */}
        <div
          className="max-w-3xl text-center text-[#2A241A] text-xl leading-relaxed"
          style={{ fontFamily: "'Aref Ruqaa', serif" }}
        >
          <p className="text-[#4A3F2C]">
            تشهد أكاديمية كاليغرو لتعليم فنون الخط العربي بأن الطالب/ـة قد حضر/ت واجتاز/ت بنجاح الدورة التدريبية:
          </p>
          <p className="text-3xl font-bold text-[#8C6D23] mt-1.5 drop-shadow-sm">
            « {courseName} »
          </p>
          {totalHours && (
            <p className="text-sm text-[#5A4E3A] font-sans mt-1">
              <span>{t("certificate.comprising") || "بواقع"}</span>
              <span className="font-bold text-[#141414] px-2 font-mono text-base">{totalHours}</span>
              <span>{t("certificate.training_hours") || "ساعة تدريبية وتطبيق عملي مكثف"}</span>
            </p>
          )}
        </div>

        {/* ─── 4. BOTTOM PILLARS (DATE, INSTRUCTOR & 3D DRY EMBOSSED PAPER SEAL) ─── */}
        <div className="w-full grid grid-cols-3 items-end pt-4 border-t border-[#C5A059]/25 mt-2 px-6">
          
          {/* 1. Date Column */}
          <div className="flex flex-col items-center">
            <span className="text-[#7A694F] text-[11px] font-sans font-bold tracking-wider mb-2">
              تاريخ الاعتماد
            </span>
            <div className="h-16 flex items-center justify-center">
              <span className="text-[#141414] text-xl font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>
                {effectiveDateStr}
              </span>
            </div>
            <div className="w-36 h-[1px] bg-[#141414]/20 mt-1" />
            <span className="text-[#8C6D23] text-[10px] font-sans font-semibold mt-1">
              أكاديمية كاليغرو الدولية
            </span>
          </div>

          {/* 2. Course Instructor Signature */}
          <div className="flex flex-col items-center">
            <span className="text-[#7A694F] text-[11px] font-sans font-bold tracking-wider mb-2">
              مدرب المساق
            </span>
            <div className="h-16 flex items-center justify-center w-full">
              {teacherSignatureUrl ? (
                <img
                  src={formatImageUrl(teacherSignatureUrl)}
                  alt="Teacher Signature"
                  className="max-h-14 object-contain mix-blend-multiply scale-110"
                />
              ) : (
                <span className="text-[#141414] text-2xl" style={{ fontFamily: "'Diwani Letter', serif" }}>
                  {teacherName}
                </span>
              )}
            </div>
            <div className="w-36 h-[1px] bg-[#141414]/20 mt-1" />
            <span className="text-[#8C6D23] text-[10px] font-sans font-semibold mt-1">
              المدرب المعتمد
            </span>
          </div>

          {/* 3. REAL 3D BLIND EMBOSSED PAPER SEAL (MATCHING EXACT BOOK EMBOSSER IMAGE) */}
          <div className="flex flex-col items-center justify-center relative">
            {/* The Tactile 3D Paper Emboss Stamp */}
            <div
              className="relative w-40 h-40 rounded-full flex items-center justify-center select-none"
              style={{
                // Matching paper texture & tone for pure blind emboss
                background: "radial-gradient(circle at 35% 30%, #FCFAF7 0%, #F5F0E4 60%, #EBE3D2 100%)",
                boxShadow: `
                  -4px -4px 8px rgba(255, 255, 255, 0.98),
                  4px 4px 12px rgba(135, 110, 75, 0.38),
                  inset -3px -3px 6px rgba(255, 255, 255, 0.95),
                  inset 3px 3px 6px rgba(115, 90, 55, 0.30)
                `,
              }}
            >
              {/* Outer Circular Debossed Groove */}
              <div
                className="absolute inset-2 rounded-full pointer-events-none"
                style={{
                  border: "1.5px solid rgba(155, 130, 95, 0.35)",
                  boxShadow: "inset 1px 1px 2px rgba(110, 85, 55, 0.3), 1px 1px 1.5px rgba(255, 255, 255, 0.95)",
                }}
              />

              {/* Dotted Crimp Ring (Matching Image 2) */}
              <div
                className="absolute inset-4 rounded-full pointer-events-none"
                style={{
                  border: "1.5px dotted rgba(145, 120, 85, 0.5)",
                }}
              />

              {/* Inner Fine Pressed Ring */}
              <div
                className="absolute inset-6 rounded-full pointer-events-none"
                style={{
                  border: "1px solid rgba(155, 130, 95, 0.3)",
                  boxShadow: "1px 1px 2px rgba(110, 85, 55, 0.25), inset 1px 1px 1px rgba(255, 255, 255, 0.9)",
                }}
              />

              {/* Pure 3D Vector Embossed Content (NO LOGO, 100% Paper Relief) */}
              <svg
                className="w-full h-full p-2 pointer-events-none"
                viewBox="0 0 160 160"
                style={{
                  // The golden standard 3D paper emboss filter: top-left highlight + bottom-right shadow
                  filter: `
                    drop-shadow(-1.2px -1.2px 0.3px rgba(255, 255, 255, 0.98))
                    drop-shadow(1.4px 1.4px 1.2px rgba(115, 90, 55, 0.42))
                  `,
                }}
              >
                <defs>
                  {/* Top Arc Path (Reads naturally left to right) */}
                  <path
                    id="emboss-path-top"
                    d="M 28, 80 A 52, 52 0 0, 1 132, 80"
                    fill="none"
                  />
                  {/* Bottom Arc Path (Reads naturally upright on the bottom) */}
                  <path
                    id="emboss-path-bottom"
                    d="M 132, 80 A 52, 52 0 0, 1 28, 80"
                    fill="none"
                  />
                </defs>

                {/* Top Arc Curved Text (Color is identical to paper surface) */}
                <text
                  className="text-[8px] uppercase font-bold tracking-[2.8px]"
                  fill="#F5EFE4"
                  style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
                >
                  <textPath href="#emboss-path-top" startOffset="50%" textAnchor="middle">
                    CALLIGRO ACADEMY
                  </textPath>
                </text>

                {/* Bottom Arc Curved Text (Upright, matching Image 2 "MATILDA JOHNSSON") */}
                <text
                  className="text-[7.5px] uppercase font-bold tracking-[2.5px]"
                  fill="#F5EFE4"
                  style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
                >
                  <textPath href="#emboss-path-bottom" startOffset="50%" textAnchor="middle">
                    OFFICIAL ACCREDITATION
                  </textPath>
                </text>

                {/* Left & Right Arched Embossed Dots (Matching Image 2) */}
                {/* Left Dots */}
                <circle cx="27" cy="74" r="1.6" fill="#F5EFE4" />
                <circle cx="26" cy="80" r="1.6" fill="#F5EFE4" />
                <circle cx="27" cy="86" r="1.6" fill="#F5EFE4" />
                
                {/* Right Dots */}
                <circle cx="133" cy="74" r="1.6" fill="#F5EFE4" />
                <circle cx="134" cy="80" r="1.6" fill="#F5EFE4" />
                <circle cx="133" cy="86" r="1.6" fill="#F5EFE4" />

                {/* Center Embossed Emblem: Tree of Knowledge & Art (Exact Match to Image 2) */}
                <g fill="#F5EFE4" stroke="#F5EFE4" strokeLinecap="round" strokeLinejoin="round">
                  {/* Trunk & Main Roots */}
                  <path
                    d="M 77 94 Q 78 82 76 74 Q 74 65 67 60 Q 75 64 79 70 Q 82 64 88 59 Q 84 66 82 74 Q 81 82 83 94 Z"
                    strokeWidth="0.5"
                  />
                  {/* Spreading Roots into Paper */}
                  <path d="M 77 94 Q 73 98 67 101" strokeWidth="1.8" fill="none" />
                  <path d="M 78 95 Q 75 101 71 104" strokeWidth="1.5" fill="none" />
                  <path d="M 80 95 Q 80 102 80 105" strokeWidth="1.6" fill="none" />
                  <path d="M 82 95 Q 85 101 89 104" strokeWidth="1.5" fill="none" />
                  <path d="M 83 94 Q 87 98 93 101" strokeWidth="1.8" fill="none" />

                  {/* Branches */}
                  <path d="M 76 72 Q 70 66 62 65 Q 57 65 53 62" strokeWidth="1.5" fill="none" />
                  <path d="M 72 68 Q 66 61 62 55 Q 58 50 56 45" strokeWidth="1.4" fill="none" />
                  <path d="M 78 68 Q 76 58 74 52 Q 72 46 72 40" strokeWidth="1.5" fill="none" />
                  <path d="M 82 68 Q 84 58 86 52 Q 88 46 88 40" strokeWidth="1.5" fill="none" />
                  <path d="M 84 68 Q 90 61 94 55 Q 98 50 100 45" strokeWidth="1.4" fill="none" />
                  <path d="M 80 72 Q 86 66 94 65 Q 99 65 103 62" strokeWidth="1.5" fill="none" />

                  {/* Embossed Leaves Canopy (Directly pressed into the paper) */}
                  <circle cx="53" cy="62" r="2.2" />
                  <circle cx="57" cy="57" r="2.4" />
                  <circle cx="56" cy="45" r="2.2" />
                  <circle cx="61" cy="49" r="2.5" />
                  <circle cx="62" cy="55" r="2.4" />
                  <circle cx="66" cy="45" r="2.5" />
                  <circle cx="68" cy="52" r="2.3" />
                  <circle cx="72" cy="40" r="2.5" />
                  <circle cx="73" cy="47" r="2.4" />
                  <circle cx="78" cy="38" r="2.6" />
                  <circle cx="80" cy="45" r="2.5" />
                  <circle cx="82" cy="38" r="2.6" />
                  <circle cx="87" cy="40" r="2.5" />
                  <circle cx="87" cy="47" r="2.4" />
                  <circle cx="92" cy="45" r="2.5" />
                  <circle cx="94" cy="55" r="2.4" />
                  <circle cx="99" cy="49" r="2.5" />
                  <circle cx="100" cy="45" r="2.2" />
                  <circle cx="103" cy="62" r="2.2" />
                  <circle cx="99" cy="57" r="2.4" />
                  
                  {/* Subtle Central Accent Star */}
                  <circle cx="80" cy="60" r="1.8" />
                </g>
              </svg>
            </div>

            {/* Official Verification ID below the Embossed Stamp */}
            <div className="mt-2 flex flex-col items-center text-center">
              <span className="text-[#8C6D23] text-[9px] font-mono tracking-widest uppercase font-bold">
                VERIFIED SEAL
              </span>
              <span className="text-[#141414]/75 text-[8.5px] font-mono tracking-wider font-semibold select-all">
                {certificateId || "PENDING"}
              </span>
            </div>
          </div>

        </div>

      </div>
    </div>
  );
}
