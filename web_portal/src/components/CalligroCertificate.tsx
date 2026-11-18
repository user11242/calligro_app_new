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

// Helper to determine if text is primarily Arabic
const isArabicText = (text: string) => /[\u0600-\u06FF]/.test(text);

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

  const isArabicName = isArabicText(studentName || "");

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
      className={`w-[1123px] h-[794px] min-w-[1123px] relative overflow-hidden flex flex-col justify-between shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top select-none p-16 ${className}`}
      style={{
        boxSizing: "border-box",
        background: "#FAF8F5",
        ...style,
      }}
      dir="rtl"
    >
      {/* ─── TIMELESS MINIMALIST DIPLOMA BORDER ─── */}
      {/* Outer Border */}
      <div
        className="absolute inset-[24px] pointer-events-none z-10"
        style={{
          border: "1.5px solid #C5A059",
        }}
      />
      {/* Inner Hairline Frame */}
      <div
        className="absolute inset-[30px] pointer-events-none z-10"
        style={{
          border: "0.5px solid rgba(197, 160, 89, 0.4)",
        }}
      />

      {/* 4 Tasteful Minimalist Corner Accents */}
      <div className="absolute top-[28px] right-[28px] w-3 h-3 border-t-2 border-r-2 border-[#8C6D23] pointer-events-none z-20" />
      <div className="absolute top-[28px] left-[28px] w-3 h-3 border-t-2 border-l-2 border-[#8C6D23] pointer-events-none z-20" />
      <div className="absolute bottom-[28px] right-[28px] w-3 h-3 border-b-2 border-r-2 border-[#8C6D23] pointer-events-none z-20" />
      <div className="absolute bottom-[28px] left-[28px] w-3 h-3 border-b-2 border-l-2 border-[#8C6D23] pointer-events-none z-20" />

      {/* ─── 1. TOP HEADER & CREST ─── */}
      <div className="flex flex-col items-center pt-2">
        {/* Calligro Academy Crest */}
        <div className="flex items-center gap-3 mb-2">
          <div className="w-11 h-11 rounded-full border border-[#C5A059]/60 p-1 bg-white/60 flex items-center justify-center shadow-sm">
            <img
              src="/assets/images/Logo.png"
              alt="Calligro"
              className="w-full h-full object-contain"
            />
          </div>
          <div className="text-right">
            <h3
              className="text-[#1A1A1A] text-xl font-bold tracking-wide leading-none"
              style={{ fontFamily: "'Aref Ruqaa', serif" }}
            >
              أكاديمية كاليغرو لتعليم فنون الخط العربي
            </h3>
            <p className="text-[#8C6D23] text-[9px] uppercase font-sans font-semibold tracking-[0.3em] mt-1">
              CALLIGRO ACADEMY OF ARABIC CALLIGRAPHY
            </p>
          </div>
        </div>

        {/* Minimalist Divider */}
        <div className="w-48 h-[1px] bg-gradient-to-r from-transparent via-[#C5A059] to-transparent my-3" />

        {/* Certificate Title: شهادة حضور */}
        <h1
          className="text-5xl font-black text-[#1A1A1A] tracking-wider mt-1"
          style={{
            fontFamily: "'Thuluth', 'Amiri', 'Aref Ruqaa', serif",
          }}
        >
          شهادة حضور
        </h1>

        {/* Presented To */}
        <p className="text-[#6B5E49] text-xs uppercase tracking-[0.2em] font-sans font-medium mt-3">
          {t("certificate.presented_to") || "تُمنح هذه الشهادة بكل فخر واعتزاز إلى:"}
        </p>
      </div>

      {/* ─── 2. RECIPIENT NAME (PERFECT TYPOGRAPHY) ─── */}
      <div className="flex flex-col items-center my-auto py-2">
        <h2
          className="text-5xl md:text-6xl font-bold text-[#1A1A1A] text-center px-8"
          style={{
            fontFamily: isArabicName
              ? "'Diwani Letter', 'Amiri', serif"
              : "'Playfair Display', 'Cinzel', Georgia, serif",
            lineHeight: "1.3",
            letterSpacing: isArabicName ? "0" : "0.02em",
          }}
        >
          {studentName}
        </h2>

        {/* Elegant Minimalist Accent Underline */}
        <div className="flex items-center gap-2 mt-2 w-72">
          <div className="h-[1px] flex-1 bg-gradient-to-l from-[#C5A059] to-transparent" />
          <div className="w-1.5 h-1.5 rotate-45 bg-[#8C6D23]" />
          <div className="h-[1px] flex-1 bg-gradient-to-r from-[#C5A059] to-transparent" />
        </div>
      </div>

      {/* ─── 3. COURSE ACHIEVEMENT STATEMENT ─── */}
      <div className="max-w-2xl mx-auto text-center space-y-2 mb-2">
        <p
          className="text-[#4A3F2C] text-lg leading-relaxed"
          style={{ fontFamily: "'Aref Ruqaa', serif" }}
        >
          لحضوره/ـا ومشاركته/ـا الفاعلة في الدورة التدريبية:
        </p>
        <p
          className="text-2xl font-bold text-[#8C6D23]"
          style={{ fontFamily: "'Aref Ruqaa', 'Amiri', serif" }}
        >
          « {courseName} »
        </p>
        {totalHours && (
          <p className="text-xs text-[#6B5E49] font-sans">
            <span>{t("certificate.comprising") || "بواقع"}</span>
            <span className="font-bold text-[#1A1A1A] px-1.5 font-mono text-sm">{totalHours}</span>
            <span>{t("certificate.training_hours") || "ساعات تدريبية"}</span>
          </p>
        )}
      </div>

      {/* ─── 4. BOTTOM PILLARS (DATE, INSTRUCTOR & PURE EMBOSSED PAPER SEAL) ─── */}
      <div className="w-full grid grid-cols-3 items-end pt-6 border-t border-[#C5A059]/30 px-8">
        {/* Column 1: Date */}
        <div className="flex flex-col items-center">
          <span className="text-[#7A694F] text-[11px] font-sans font-semibold tracking-wider mb-2">
            تاريخ الاعتماد
          </span>
          <div className="h-14 flex items-center justify-center">
            <span
              className="text-[#1A1A1A] text-lg font-bold"
              style={{ fontFamily: "'Aref Ruqaa', serif" }}
            >
              {effectiveDateStr}
            </span>
          </div>
          <div className="w-32 h-[1px] bg-[#1A1A1A]/15 mt-1" />
          <span className="text-[#8C6D23] text-[9px] font-sans font-medium mt-1">
            أكاديمية كاليغرو الدولية
          </span>
        </div>

        {/* Column 2: Course Instructor Signature */}
        <div className="flex flex-col items-center">
          <span className="text-[#7A694F] text-[11px] font-sans font-semibold tracking-wider mb-2">
            مدرب المساق
          </span>
          <div className="h-14 flex items-center justify-center w-full">
            {teacherSignatureUrl ? (
              <img
                src={formatImageUrl(teacherSignatureUrl)}
                alt="Teacher Signature"
                className="max-h-12 object-contain mix-blend-multiply"
              />
            ) : (
              <span
                className="text-[#1A1A1A] text-xl"
                style={{
                  fontFamily: isArabicText(teacherName)
                    ? "'Diwani Letter', serif"
                    : "'Playfair Display', Georgia, serif",
                }}
              >
                {teacherName}
              </span>
            )}
          </div>
          <div className="w-32 h-[1px] bg-[#1A1A1A]/15 mt-1" />
          <span className="text-[#8C6D23] text-[9px] font-sans font-medium mt-1">
            المدرب المعتمد
          </span>
        </div>

        {/* Column 3: PURE 3D BLIND EMBOSSED PAPER SEAL (CLEAN CENTER - NO TREE / NO LOGO) */}
        <div className="flex flex-col items-center justify-center">
          <div
            className="relative w-36 h-36 rounded-full flex items-center justify-center select-none"
            style={{
              background: "#FAF8F5",
              boxShadow: `
                -3px -3px 6px rgba(255, 255, 255, 0.98),
                3px 3px 8px rgba(135, 110, 75, 0.28),
                inset -2px -2px 4px rgba(255, 255, 255, 0.95),
                inset 2px 2px 4px rgba(115, 90, 55, 0.22)
              `,
            }}
          >
            {/* Outer Debossed Groove */}
            <div
              className="absolute inset-2 rounded-full pointer-events-none"
              style={{
                border: "1px solid rgba(155, 130, 95, 0.28)",
                boxShadow:
                  "inset 1px 1px 2px rgba(110, 85, 55, 0.2), 1px 1px 1px rgba(255, 255, 255, 0.9)",
              }}
            />

            {/* Dotted Crimp Ring */}
            <div
              className="absolute inset-3.5 rounded-full pointer-events-none"
              style={{
                border: "1.5px dotted rgba(145, 120, 85, 0.45)",
              }}
            />

            {/* Inner Fine Pressed Ring */}
            <div
              className="absolute inset-5 rounded-full pointer-events-none"
              style={{
                border: "1px solid rgba(155, 130, 95, 0.25)",
                boxShadow:
                  "1px 1px 2px rgba(110, 85, 55, 0.15), inset 1px 1px 1px rgba(255, 255, 255, 0.85)",
              }}
            />

            {/* Circular Curved 3D Embossed Typography with Clean Smooth Center */}
            <svg
              className="w-full h-full p-2 pointer-events-none"
              viewBox="0 0 144 144"
              style={{
                filter: `
                  drop-shadow(-1px -1px 0.3px rgba(255, 255, 255, 0.98))
                  drop-shadow(1.2px 1.2px 1px rgba(115, 90, 55, 0.38))
                `,
              }}
            >
              <defs>
                <path
                  id="clean-emboss-top"
                  d="M 24, 72 A 48, 48 0 0, 1 120, 72"
                  fill="none"
                />
                <path
                  id="clean-emboss-bottom"
                  d="M 120, 72 A 48, 48 0 0, 1 24, 72"
                  fill="none"
                />
              </defs>

              {/* Top Arc Text (Exact Paper Color) */}
              <text
                className="text-[7.5px] uppercase font-bold tracking-[2.5px]"
                fill="#FAF8F5"
                style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
              >
                <textPath href="#clean-emboss-top" startOffset="50%" textAnchor="middle">
                  CALLIGRO ACADEMY
                </textPath>
              </text>

              {/* Bottom Arc Text (Upright & Clean) */}
              <text
                className="text-[7px] uppercase font-bold tracking-[2.2px]"
                fill="#FAF8F5"
                style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
              >
                <textPath href="#clean-emboss-bottom" startOffset="50%" textAnchor="middle">
                  OFFICIAL ACCREDITATION
                </textPath>
              </text>

              {/* Left Symmetrical Embossed Dots */}
              <circle cx="23" cy="67" r="1.5" fill="#FAF8F5" />
              <circle cx="22" cy="72" r="1.5" fill="#FAF8F5" />
              <circle cx="23" cy="77" r="1.5" fill="#FAF8F5" />

              {/* Right Symmetrical Embossed Dots */}
              <circle cx="121" cy="67" r="1.5" fill="#FAF8F5" />
              <circle cx="122" cy="72" r="1.5" fill="#FAF8F5" />
              <circle cx="121" cy="77" r="1.5" fill="#FAF8F5" />

              {/* Subtle Central 3D Embossed Star Ornament (Clean & Dignified) */}
              <circle cx="72" cy="72" r="2" fill="#FAF8F5" />
              <circle cx="64" cy="72" r="1.2" fill="#FAF8F5" />
              <circle cx="80" cy="72" r="1.2" fill="#FAF8F5" />
            </svg>
          </div>

          {/* Minimalist Verification Record */}
          <div className="mt-1.5 flex flex-col items-center text-center">
            <span className="text-[#8C6D23] text-[8.5px] font-mono tracking-widest uppercase font-bold">
              VERIFIED SEAL
            </span>
            <span className="text-[#1A1A1A]/70 text-[8px] font-mono tracking-wider font-semibold select-all">
              {certificateId || "PENDING"}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
