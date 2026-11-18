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
      {/* Subtle Islamic Lattice Background */}
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
      {/* 1. Outermost Hairline Gold Border */}
      <div className="absolute inset-[16px] border border-[#C5A059]/40 pointer-events-none z-10" />

      {/* 2. Main Deep Obsidian Regal Frame */}
      <div className="absolute inset-[22px] border-[3px] border-[#161616] pointer-events-none z-10" />

      {/* 3. Inner Decorative Burnished Gold Guilloche Frame */}
      <div className="absolute inset-[28px] border-[1.5px] border-[#D4AF37] pointer-events-none z-10" />

      {/* 4. Fine Inset Pinstripe */}
      <div className="absolute inset-[34px] border border-[#C5A059]/30 pointer-events-none z-10" />

      {/* ─── 4 CLASSICAL ISLAMIC ARABESQUE CORNER ORNAMENTS ─── */}
      {/* Top-Right Corner */}
      <div className="absolute top-[28px] right-[28px] w-20 h-20 pointer-events-none z-20">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      {/* Top-Left Corner */}
      <div className="absolute top-[28px] left-[28px] w-20 h-20 pointer-events-none z-20 transform scale-x-[-1]">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      {/* Bottom-Right Corner */}
      <div className="absolute bottom-[28px] right-[28px] w-20 h-20 pointer-events-none z-20 transform scale-y-[-1]">
        <svg viewBox="0 0 80 80" className="w-full h-full text-[#C5A059]" fill="currentColor">
          <path d="M0 0 L30 0 C25 10 20 20 10 25 C20 30 25 40 30 50 L0 35 Z" opacity="0.8" />
          <path d="M0 0 L0 30 C10 25 20 20 25 10 C30 20 40 25 50 30 L35 0 Z" opacity="0.8" />
          <circle cx="16" cy="16" r="3" fill="#D4AF37" />
          <path d="M2 2 L2 24 L24 2 Z" fill="#161616" opacity="0.9" />
          <circle cx="6" cy="6" r="1.5" fill="#FDFBF8" />
        </svg>
      </div>

      {/* Bottom-Left Corner */}
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
          {/* Logo & Academy Name */}
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

          {/* Decorative Gold Header Swash */}
          <div className="flex items-center gap-3 my-2 w-72">
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
            <span className="text-[#C5A059] text-xs">✦ ❖ ✦</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
          </div>

          {/* Main Certificate Title */}
          <h1
            className="text-6xl font-black text-[#141414] tracking-wider mt-1 drop-shadow-sm"
            style={{
              fontFamily: "'Thuluth', 'Amiri', 'Aref Ruqaa', serif",
              textShadow: "0 1px 2px rgba(140, 109, 35, 0.15)",
            }}
          >
            {t("certificate.title") || "شهادة إتمام معتمدة"}
          </h1>

          {/* Presented To Text */}
          <p className="text-[#5A4E3A] text-sm uppercase tracking-[0.25em] font-sans font-semibold mt-3">
            {t("certificate.presented_to") || "تُمنح هذه الشهادة بكل فخر واعتزاز إلى:"}
          </p>
        </div>

        {/* ─── 2. RECIPIENT NAME (DIWANI LETTER) ─── */}
        <div className="relative my-2 w-full max-w-2xl flex flex-col items-center">
          {/* Top Delicate Gold Flourish */}
          <div className="w-56 h-[1px] bg-gradient-to-r from-transparent via-[#C5A059]/60 to-transparent mb-1" />

          {/* Student Name */}
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

          {/* Bottom Calligraphic Underline with Diamond */}
          <div className="flex items-center gap-2 mt-1 w-80">
            <div className="h-[1.5px] flex-1 bg-gradient-to-l from-[#C5A059] to-transparent" />
            <div className="w-2 h-2 rotate-45 bg-[#D4AF37] border border-[#8C6D23]/40" />
            <div className="h-[1.5px] flex-1 bg-gradient-to-r from-[#C5A059] to-transparent" />
          </div>
        </div>

        {/* ─── 3. COURSE ACHIEVEMENT STATEMENT ─── */}
        <div
          className="max-w-3xl text-center text-[#2A241A] text-xl leading-relaxed"
          style={{ fontFamily: "'Aref Ruqaa', serif" }}
        >
          <p className="text-[#4A3F2C]">
            تقديراً لاجتيازه/ـها بنجاح واقتدار كافة المتطلبات التدريبية المعتمدة لدورة:
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

        {/* ─── 4. BOTTOM PILLARS (SIGNATURES + AUTHENTIC EMBOSSED PAPER SEAL) ─── */}
        <div className="w-full grid grid-cols-4 items-end pt-4 border-t border-[#C5A059]/25 mt-2">
          
          {/* 1. Date Column */}
          <div className="flex flex-col items-center">
            <span className="text-[#7A694F] text-[11px] font-sans font-bold tracking-wider mb-2">
              تاريخ الاعتماد
            </span>
            <div className="h-14 flex items-center justify-center">
              <span className="text-[#141414] text-xl font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>
                {effectiveDateStr}
              </span>
            </div>
            <div className="w-32 h-[1px] bg-[#141414]/20 mt-1" />
            <span className="text-[#8C6D23] text-[9.5px] font-sans font-semibold mt-1">
              أكاديمية كاليغرو الدولية
            </span>
          </div>

          {/* 2. Course Instructor Signature */}
          <div className="flex flex-col items-center">
            <span className="text-[#7A694F] text-[11px] font-sans font-bold tracking-wider mb-2">
              مدرب المساق
            </span>
            <div className="h-14 flex items-center justify-center w-full">
              {teacherSignatureUrl ? (
                <img
                  src={formatImageUrl(teacherSignatureUrl)}
                  alt="Teacher Signature"
                  className="max-h-12 object-contain mix-blend-multiply scale-110"
                />
              ) : (
                <span className="text-[#141414] text-2xl" style={{ fontFamily: "'Diwani Letter', serif" }}>
                  {teacherName}
                </span>
              )}
            </div>
            <div className="w-32 h-[1px] bg-[#141414]/20 mt-1" />
            <span className="text-[#8C6D23] text-[9.5px] font-sans font-semibold mt-1">
              المدرب المعتمد
            </span>
          </div>

          {/* 3. Executive Director (CEO) Signature */}
          <div className="flex flex-col items-center">
            <span className="text-[#7A694F] text-[11px] font-sans font-bold tracking-wider mb-2">
              المدير التنفيذي
            </span>
            <div className="h-14 flex items-center justify-center w-full">
              <img
                src="/assets/images/yazan_signature.png"
                alt="Yazan Qattous Signature"
                className="max-h-14 object-contain mix-blend-multiply scale-125 -translate-y-1"
              />
            </div>
            <div className="w-32 h-[1px] bg-[#141414]/20 mt-1" />
            <span className="text-[#8C6D23] text-[9.5px] font-sans font-semibold mt-1">
              يزن قطوس
            </span>
          </div>

          {/* 4. REAL EMBOSSED PAPER SEAL ("INSIDE THE PAPER ITSELF") */}
          <div className="flex flex-col items-center justify-center relative">
            {/* The 3D Pressed Dry Embossed Seal */}
            <div
              className="relative w-32 h-32 rounded-full flex items-center justify-center select-none"
              style={{
                // Matching paper gradient for true blind-emboss impression
                background: "linear-gradient(135deg, #FCFAF7 0%, #F5F0E4 50%, #ECE4D3 100%)",
                boxShadow: `
                  -3px -3px 6px rgba(255, 255, 255, 0.95),
                  3px 3px 10px rgba(145, 120, 85, 0.35),
                  inset -2.5px -2.5px 5px rgba(255, 255, 255, 0.9),
                  inset 2.5px 2.5px 5px rgba(125, 100, 65, 0.28)
                `,
              }}
            >
              {/* Embossed Notched / Ribbed Ring Outer Edge */}
              <div
                className="absolute inset-1 rounded-full pointer-events-none"
                style={{
                  border: "1.5px solid rgba(165, 138, 98, 0.4)",
                  boxShadow: "inset 1px 1px 2px rgba(120, 95, 65, 0.25), 1px 1px 1px rgba(255, 255, 255, 0.9)",
                }}
              />

              {/* Dotted Crimp Ring (Matching Image 2 Book Embosser) */}
              <div
                className="absolute inset-2.5 rounded-full pointer-events-none"
                style={{
                  border: "1.5px dotted rgba(150, 125, 85, 0.5)",
                }}
              />

              {/* Inner Raised Ring */}
              <div
                className="absolute inset-4 rounded-full pointer-events-none"
                style={{
                  border: "1px solid rgba(165, 138, 98, 0.3)",
                  boxShadow: "1px 1px 2px rgba(120, 95, 65, 0.2), inset 1px 1px 1px rgba(255, 255, 255, 0.8)",
                }}
              />

              {/* Circular Curved Embossed Text (SVG textPath) */}
              <svg className="absolute inset-0 w-full h-full pointer-events-none" viewBox="0 0 128 128">
                <defs>
                  <path
                    id="embossed-seal-circle"
                    d="M 64, 64 m -46, 0 a 46,46 0 1,1 92,0 a 46,46 0 1,1 -92,0"
                    fill="none"
                  />
                </defs>
                <text
                  className="text-[6.5px] uppercase font-bold tracking-[2.2px]"
                  fill="#947444"
                  style={{
                    filter: "drop-shadow(-0.8px -0.8px 0px rgba(255, 255, 255, 0.95)) drop-shadow(0.8px 0.8px 1px rgba(110, 85, 55, 0.4))",
                    fontFamily: "sans-serif",
                  }}
                >
                  <textPath href="#embossed-seal-circle" startOffset="50%" textAnchor="middle">
                    • CALLIGRO ACADEMY • OFFICIAL SEAL OF EXCELLENCE •
                  </textPath>
                </text>
              </svg>

              {/* Center Raised Disc with Embossed Calligro Emblem */}
              <div
                className="relative w-14 h-14 rounded-full flex items-center justify-center"
                style={{
                  background: "linear-gradient(135deg, #FAF7F0 0%, #EFE8DA 100%)",
                  boxShadow: `
                    inset -2px -2px 3px rgba(255, 255, 255, 0.9),
                    inset 2px 2px 3px rgba(130, 105, 70, 0.25),
                    -1px -1px 2px rgba(255, 255, 255, 0.95),
                    1px 1px 3px rgba(120, 95, 65, 0.25)
                  `,
                }}
              >
                {/* The Logo Embossed Inside the Paper */}
                <div
                  className="w-9 h-9 flex items-center justify-center"
                  style={{
                    filter: `
                      drop-shadow(-1.5px -1.5px 0.5px rgba(255, 255, 255, 0.95))
                      drop-shadow(1.5px 1.5px 1.5px rgba(100, 75, 45, 0.5))
                      contrast(1.1)
                    `,
                    opacity: 0.85,
                  }}
                >
                  <img
                    src="/assets/images/Logo.png"
                    alt="Embossed Calligro Stamp"
                    className="w-full h-full object-contain mix-blend-multiply"
                  />
                </div>
              </div>
            </div>

            {/* Official Verification ID below the Embossed Stamp */}
            <div className="mt-1.5 flex flex-col items-center text-center">
              <span className="text-[#8C6D23] text-[8.5px] font-mono tracking-widest uppercase font-bold">
                VERIFIED SEAL
              </span>
              <span className="text-[#141414]/75 text-[8px] font-mono tracking-wider font-semibold select-all">
                {certificateId || "PENDING"}
              </span>
            </div>
          </div>

        </div>

      </div>
    </div>
  );
}
