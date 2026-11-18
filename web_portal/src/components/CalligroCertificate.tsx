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

  const paperBg = "#FAF7F0";

  return (
    <div
      id={id}
      className={`w-[1123px] h-[794px] min-w-[1123px] relative overflow-hidden flex flex-col justify-between shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top select-none p-12 ${className}`}
      style={{
        boxSizing: "border-box",
        background: "radial-gradient(ellipse at 50% 50%, #FCFBF7 0%, #F9F6EE 65%, #F1E9DA 100%)",
        ...style,
      }}
      dir="rtl"
    >
      {/* ─── CLASSICAL BANKNOTE GUILLOCHE DIPLOMA BORDER (CALLIGRO BLACK & GOLD COLORS) ─── */}
      <svg
        className="absolute inset-0 w-full h-full pointer-events-none z-10"
        viewBox="0 0 1123 794"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          {/* Guilloche Weave Pattern for Horizontal Bands (Calligro Charcoal #1A1A1A & Gold #C5A059) */}
          <pattern
            id="calligro-guilloche-h"
            width="20"
            height="16"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M0 8 Q5 0 10 8 T20 8"
              stroke="#1A1A1A"
              strokeWidth="1.2"
              fill="none"
              opacity="0.85"
            />
            <path
              d="M0 8 Q5 16 10 8 T20 8"
              stroke="#C5A059"
              strokeWidth="0.9"
              fill="none"
              opacity="0.75"
            />
          </pattern>

          {/* Scalloped Lace Edge Pattern */}
          <pattern
            id="calligro-scallop-h"
            width="16"
            height="8"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M0 8 Q4 0 8 0 Q12 0 16 8"
              stroke="#1A1A1A"
              strokeWidth="1"
              fill="none"
              opacity="0.8"
            />
          </pattern>
        </defs>

        {/* 1. Outer Fine Hairline Border */}
        <rect
          x="18"
          y="18"
          width="1087"
          height="758"
          stroke="#C5A059"
          strokeWidth="1.2"
          opacity="0.8"
        />

        {/* 2. Outer Scalloped Banknote Ribbon Frame */}
        <rect
          x="23"
          y="23"
          width="1077"
          height="748"
          stroke="#1A1A1A"
          strokeWidth="12"
          strokeDasharray="3 1.5"
          opacity="0.9"
        />

        {/* 3. Gold Separator Line */}
        <rect
          x="30"
          y="30"
          width="1063"
          height="734"
          stroke="#C5A059"
          strokeWidth="1.8"
        />

        {/* 4. Secondary Guilloche Lattice Ribbon */}
        <rect
          x="34"
          y="34"
          width="1055"
          height="726"
          stroke="#1A1A1A"
          strokeWidth="3.5"
          opacity="0.4"
        />

        {/* 5. Inner Engraved Frame */}
        <rect
          x="42"
          y="42"
          width="1039"
          height="710"
          stroke="#1A1A1A"
          strokeWidth="2.5"
        />
        <rect
          x="46"
          y="46"
          width="1031"
          height="702"
          stroke="#C5A059"
          strokeWidth="0.8"
          strokeDasharray="2 2"
          opacity="0.85"
        />

        {/* ─── 4 ORNATE ENGRAVED CORNERS (VICTORIAN ACANTHUS / SCROLLWORK FILIGREE) ─── */}
        {/* Top-Right Corner */}
        <g transform="translate(24, 24)">
          <path
            d="M0 0 L56 0 C44 14 36 28 22 36 C36 44 44 58 56 76 L0 56 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M6 6 L44 6 C34 16 28 26 18 32 C28 38 34 48 44 62 L6 46 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="24" cy="24" r="6" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="1.5" />
          <circle cx="24" cy="24" r="3" fill="#C5A059" />
          <path d="M24 14 L24 34 M14 24 L34 24" stroke="#1A1A1A" strokeWidth="0.8" />
        </g>

        {/* Top-Left Corner */}
        <g transform="translate(1099, 24) scale(-1, 1)">
          <path
            d="M0 0 L56 0 C44 14 36 28 22 36 C36 44 44 58 56 76 L0 56 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M6 6 L44 6 C34 16 28 26 18 32 C28 38 34 48 44 62 L6 46 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="24" cy="24" r="6" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="1.5" />
          <circle cx="24" cy="24" r="3" fill="#C5A059" />
          <path d="M24 14 L24 34 M14 24 L34 24" stroke="#1A1A1A" strokeWidth="0.8" />
        </g>

        {/* Bottom-Right Corner */}
        <g transform="translate(24, 770) scale(1, -1)">
          <path
            d="M0 0 L56 0 C44 14 36 28 22 36 C36 44 44 58 56 76 L0 56 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M6 6 L44 6 C34 16 28 26 18 32 C28 38 34 48 44 62 L6 46 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="24" cy="24" r="6" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="1.5" />
          <circle cx="24" cy="24" r="3" fill="#C5A059" />
          <path d="M24 14 L24 34 M14 24 L34 24" stroke="#1A1A1A" strokeWidth="0.8" />
        </g>

        {/* Bottom-Left Corner */}
        <g transform="translate(1099, 770) scale(-1, -1)">
          <path
            d="M0 0 L56 0 C44 14 36 28 22 36 C36 44 44 58 56 76 L0 56 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M6 6 L44 6 C34 16 28 26 18 32 C28 38 34 48 44 62 L6 46 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="24" cy="24" r="6" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="1.5" />
          <circle cx="24" cy="24" r="3" fill="#C5A059" />
          <path d="M24 14 L24 34 M14 24 L34 24" stroke="#1A1A1A" strokeWidth="0.8" />
        </g>
      </svg>

      {/* ─── TOP TRACKING SERIAL (MATCHING REFERENCE IIPM/SECP/24001) ─── */}
      <div className="absolute top-[54px] left-[62px] z-20 text-left font-mono text-[10px] text-[#8C6D23] tracking-widest font-bold" dir="ltr">
        CLG/REG/{certificateId ? certificateId.slice(0, 10).toUpperCase() : "24001"}
      </div>

      {/* ─── 1. TOP HEADER: CREST & INSTITUTION NAME ─── */}
      <div className="relative z-20 flex flex-col items-center pt-2">
        {/* Circular Institution Crest Logo */}
        <div className="w-16 h-16 rounded-full border-2 border-[#C5A059] p-1 bg-white shadow-md flex items-center justify-center mb-1.5">
          <img
            src="/assets/images/Logo.png"
            alt="Calligro Crest"
            className="w-full h-full object-contain"
          />
        </div>

        {/* Institution Name (Tracked Serif Capital Letters from Reference) */}
        <h3
          className="text-[#1A1A1A] text-base md:text-lg font-bold uppercase font-serif"
          style={{ letterSpacing: "0.22em" }}
        >
          CALLIGRO ACADEMY OF ARABIC CALLIGRAPHY
        </h3>
        <p
          className="text-[#8C6D23] text-sm font-semibold tracking-wide mt-0.5"
          style={{ fontFamily: "'Aref Ruqaa', serif" }}
        >
          أكاديمية كاليغرو لتعليم فنون الخط العربي
        </p>

        {/* ─── CERTIFICATE TITLE (MATCHING REFERENCE "CERTIFICATE OF MASTERY") ─── */}
        <div className="flex flex-col items-center mt-2.5">
          <h1
            className="text-4xl md:text-5xl font-serif text-[#1A1A1A] font-extrabold uppercase"
            style={{ letterSpacing: "0.22em" }}
          >
            CERTIFICATE
          </h1>
          <p
            className="text-2xl md:text-3xl font-serif text-[#8C6D23] font-bold uppercase mt-1"
            style={{ letterSpacing: "0.26em" }}
          >
            OF ATTENDANCE
          </p>
          <span
            className="text-3xl font-bold text-[#1A1A1A] mt-1"
            style={{ fontFamily: "'Thuluth', 'Amiri', 'Aref Ruqaa', serif" }}
          >
            شهادة حضور
          </span>

          {/* Ornate Flourish Divider (Exact Reference Style: — ❧ ❖ ☙ —) */}
          <div className="flex items-center gap-3 my-1.5 w-80">
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
            <span className="text-[#8C6D23] text-sm font-serif">❧ ❖ ☙</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
          </div>
        </div>

        {/* Presented To */}
        <p className="text-[#5A4E3A] text-xs font-serif italic tracking-wider mt-0.5">
          Presented to / تُمنح بكل فخر واعتزاز إلى
        </p>
      </div>

      {/* ─── 2. PARTICIPANT'S NAME (CALLIGRAPHIC SCRIPT WITH THIN BASELINE LINE) ─── */}
      <div className="relative z-20 flex flex-col items-center my-auto py-1">
        <h2
          className="text-5xl md:text-6xl font-bold text-[#1A1A1A] text-center px-12"
          style={{
            fontFamily: isArabicName
              ? "'Diwani Letter', 'Amiri', serif"
              : "'Playfair Display', 'Brush Script MT', 'Great Vibes', Georgia, serif",
            lineHeight: "1.25",
            fontStyle: isArabicName ? "normal" : "italic",
          }}
        >
          {studentName}
        </h2>

        {/* Classic Thin Horizontal Line Under the Name (Exact Match to Reference) */}
        <div className="w-[440px] h-[1px] bg-[#C5A059] mt-2 opacity-90 shadow-sm" />
      </div>

      {/* ─── 3. COURSE ACHIEVEMENT (BOLD TITLE & ISSUED DATE) ─── */}
      <div className="relative z-20 max-w-3xl mx-auto text-center space-y-1 mb-2">
        <p className="text-[#4A3E2D] text-xs font-serif tracking-wider">
          For completing this professional course on / لاجتيازه/ـا متطلبات الدورة التدريبية:
        </p>
        <p
          className="text-2xl md:text-3xl font-bold text-[#1A1A1A] py-0.5"
          style={{ fontFamily: "'Aref Ruqaa', 'Amiri', serif" }}
        >
          « {courseName} »
        </p>
        <p className="text-xs font-serif text-[#5A4E3A]">
          <span>Issued / تاريخ الإصدار: </span>
          <span className="font-semibold text-[#1A1A1A]">{effectiveDateStr}</span>
          {totalHours && (
            <span className="mr-2"> • بواقع {totalHours} ساعات تدريبية معتمدة</span>
          )}
        </p>
      </div>

      {/* ─── 4. BOTTOM SECTION: TWO SIGNATURES + PURE 3D BLIND EMBOSSED PAPER SEAL IN CENTER ─── */}
      <div className="relative z-20 w-full grid grid-cols-3 items-end px-16 pb-2 pt-1">
        
        {/* Left Signature Column: Executive Director / مدرب المساق */}
        <div className="flex flex-col items-center text-center">
          <div className="h-14 flex items-end justify-center w-full pb-1">
            {teacherSignatureUrl ? (
              <img
                src={formatImageUrl(teacherSignatureUrl)}
                alt="Signature"
                className="max-h-14 object-contain mix-blend-multiply"
              />
            ) : (
              <span
                className="text-xl text-[#1A1A1A]"
                style={{
                  fontFamily: isArabicText(teacherName)
                    ? "'Diwani Letter', serif"
                    : "'Playfair Display', cursive, serif",
                }}
              >
                {teacherName}
              </span>
            )}
          </div>
          <div className="w-44 h-[1px] bg-[#1A1A1A]/70 mt-1" />
          <p className="text-[#1A1A1A] text-[11px] font-serif font-bold tracking-wider mt-1 uppercase">
            Executive Director / مدرب المساق
          </p>
        </div>

        {/* Center Pillar: PURE 3D BLIND EMBOSSED PAPER SEAL (PRESSED INSIDE PAPER - NO TREE / NO LOGO) */}
        <div className="flex flex-col items-center justify-center">
          <div
            className="relative w-32 h-32 rounded-full flex items-center justify-center select-none"
            style={{
              background: paperBg,
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
                  id="center-emboss-top"
                  d="M 24, 72 A 48, 48 0 0, 1 120, 72"
                  fill="none"
                />
                <path
                  id="center-emboss-bottom"
                  d="M 120, 72 A 48, 48 0 0, 1 24, 72"
                  fill="none"
                />
              </defs>

              {/* Top Arc Text (Exact Paper Tone) */}
              <text
                className="text-[7.5px] uppercase font-bold tracking-[2.5px]"
                fill={paperBg}
                style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
              >
                <textPath href="#center-emboss-top" startOffset="50%" textAnchor="middle">
                  CALLIGRO ACADEMY
                </textPath>
              </text>

              {/* Bottom Arc Text */}
              <text
                className="text-[7px] uppercase font-bold tracking-[2.2px]"
                fill={paperBg}
                style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
              >
                <textPath href="#center-emboss-bottom" startOffset="50%" textAnchor="middle">
                  OFFICIAL ACCREDITATION
                </textPath>
              </text>

              {/* Left Symmetrical Embossed Dots */}
              <circle cx="23" cy="67" r="1.5" fill={paperBg} />
              <circle cx="22" cy="72" r="1.5" fill={paperBg} />
              <circle cx="23" cy="77" r="1.5" fill={paperBg} />

              {/* Right Symmetrical Embossed Dots */}
              <circle cx="121" cy="67" r="1.5" fill={paperBg} />
              <circle cx="122" cy="72" r="1.5" fill={paperBg} />
              <circle cx="121" cy="77" r="1.5" fill={paperBg} />

              {/* Subtle Central 3D Embossed Star Finial (Clean, Dignified, No tree, No logo) */}
              <circle cx="72" cy="72" r="2.2" fill={paperBg} />
              <circle cx="64" cy="72" r="1.2" fill={paperBg} />
              <circle cx="80" cy="72" r="1.2" fill={paperBg} />
            </svg>
          </div>

          {/* Minimalist Verification Record */}
          <div className="mt-1 flex flex-col items-center text-center">
            <span className="text-[#8C6D23] text-[8.5px] font-mono tracking-widest uppercase font-bold">
              OFFICIAL SEAL
            </span>
            <span className="text-[#1A1A1A]/70 text-[8px] font-mono tracking-wider font-semibold select-all">
              {certificateId ? certificateId.slice(0, 14) : "VERIFIED"}
            </span>
          </div>
        </div>

        {/* Right Signature Column: Academic Registrar / مسجل الأكاديمية */}
        <div className="flex flex-col items-center text-center">
          <div className="h-14 flex items-end justify-center w-full pb-1">
            <span
              className="text-xl text-[#1A1A1A]"
              style={{
                fontFamily: "'Great Vibes', 'Playfair Display', cursive, serif",
                fontStyle: "italic",
              }}
            >
              Academic Registrar
            </span>
          </div>
          <div className="w-44 h-[1px] bg-[#1A1A1A]/70 mt-1" />
          <p className="text-[#1A1A1A] text-[11px] font-serif font-bold tracking-wider mt-1 uppercase">
            Registrar / مسجل الأكاديمية
          </p>
        </div>

      </div>

      {/* ─── 5. BOTTOM ACCREDITATION DISCLAIMER (EXACT MATCH TO REFERENCE FOOTER) ─── */}
      <div className="relative z-20 text-center pt-1 border-t border-[#1A1A1A]/15 mx-16">
        <p className="text-[8.5px] font-serif text-[#1A1A1A]/70 tracking-wider">
          This Institute is accredited by Calligro International Board for Calligraphy Arts & Islamic Heritage • Officially Verified Digital Credential
        </p>
      </div>

    </div>
  );
}
