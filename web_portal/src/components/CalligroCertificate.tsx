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
      className={`w-[1123px] h-[794px] min-w-[1123px] relative overflow-hidden flex flex-col justify-between shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top select-none p-12 ${className}`}
      style={{
        boxSizing: "border-box",
        background: "radial-gradient(ellipse at 50% 50%, #FCFBF7 0%, #F8F5EC 75%, #F0EADB 100%)",
        ...style,
      }}
      dir="rtl"
    >
      {/* ─── VINTAGE BANKNOTE GUILLOCHE DIPLOMA BORDER (MATCHING REFERENCE EXACTLY) ─── */}
      <svg
        className="absolute inset-0 w-full h-full pointer-events-none z-10"
        viewBox="0 0 1123 794"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          {/* Repeating Scallop Wave Pattern for Guilloche Border */}
          <pattern
            id="scallop-h"
            width="24"
            height="18"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M0 9 Q6 0 12 9 Q18 18 24 9"
              stroke="#2E5A54"
              strokeWidth="1.2"
              fill="none"
              opacity="0.85"
            />
            <path
              d="M0 12 Q6 3 12 12 Q18 21 24 12"
              stroke="#3D736B"
              strokeWidth="0.8"
              fill="none"
              opacity="0.6"
            />
          </pattern>
        </defs>

        {/* Outer Fine Border */}
        <rect
          x="18"
          y="18"
          width="1087"
          height="758"
          stroke="#2E5A54"
          strokeWidth="1.5"
          opacity="0.7"
        />

        {/* Main Banknote Scalloped Lace Frame (Teal-Green/Slate Palette from Reference) */}
        <rect
          x="24"
          y="24"
          width="1075"
          height="746"
          stroke="#2E5A54"
          strokeWidth="14"
          strokeDasharray="4 2"
          opacity="0.88"
        />
        <rect
          x="31"
          y="31"
          width="1061"
          height="732"
          stroke="#1F423D"
          strokeWidth="2"
        />

        {/* Inner Guilloche Pinstripe Ribbon */}
        <rect
          x="38"
          y="38"
          width="1047"
          height="718"
          stroke="#2E5A54"
          strokeWidth="1"
          opacity="0.5"
        />
        <rect
          x="44"
          y="44"
          width="1035"
          height="706"
          stroke="#2E5A54"
          strokeWidth="2.5"
        />
        <rect
          x="49"
          y="49"
          width="1025"
          height="696"
          stroke="#3D736B"
          strokeWidth="1"
          strokeDasharray="2 2"
          opacity="0.75"
        />

        {/* 4 Ornate Victorian / Banknote Corner Ornaments */}
        {/* Top-Right */}
        <g transform="translate(24, 24)">
          <path
            d="M0 0 L42 0 C32 14 26 26 14 32 C26 38 32 50 42 64 L0 44 Z"
            fill="#2E5A54"
            opacity="0.9"
          />
          <circle cx="20" cy="20" r="5" fill="#FAF7F0" stroke="#2E5A54" strokeWidth="1.5" />
          <circle cx="20" cy="20" r="2" fill="#2E5A54" />
        </g>
        {/* Top-Left */}
        <g transform="translate(1099, 24) scale(-1, 1)">
          <path
            d="M0 0 L42 0 C32 14 26 26 14 32 C26 38 32 50 42 64 L0 44 Z"
            fill="#2E5A54"
            opacity="0.9"
          />
          <circle cx="20" cy="20" r="5" fill="#FAF7F0" stroke="#2E5A54" strokeWidth="1.5" />
          <circle cx="20" cy="20" r="2" fill="#2E5A54" />
        </g>
        {/* Bottom-Right */}
        <g transform="translate(24, 770) scale(1, -1)">
          <path
            d="M0 0 L42 0 C32 14 26 26 14 32 C26 38 32 50 42 64 L0 44 Z"
            fill="#2E5A54"
            opacity="0.9"
          />
          <circle cx="20" cy="20" r="5" fill="#FAF7F0" stroke="#2E5A54" strokeWidth="1.5" />
          <circle cx="20" cy="20" r="2" fill="#2E5A54" />
        </g>
        {/* Bottom-Left */}
        <g transform="translate(1099, 770) scale(-1, -1)">
          <path
            d="M0 0 L42 0 C32 14 26 26 14 32 C26 38 32 50 42 64 L0 44 Z"
            fill="#2E5A54"
            opacity="0.9"
          />
          <circle cx="20" cy="20" r="5" fill="#FAF7F0" stroke="#2E5A54" strokeWidth="1.5" />
          <circle cx="20" cy="20" r="2" fill="#2E5A54" />
        </g>
      </svg>

      {/* ─── TOP RIGHT SERIAL CODE (MATCHING REFERENCE IIPM/SECP/24001) ─── */}
      <div className="absolute top-[56px] left-[64px] z-20 text-left font-mono text-[10px] text-[#2E5A54]/80 tracking-widest font-semibold" dir="ltr">
        CLG/REG/{certificateId ? certificateId.slice(0, 10).toUpperCase() : "24001"}
      </div>

      {/* ─── 1. TOP HEADER: CREST & INSTITUTION NAME ─── */}
      <div className="relative z-20 flex flex-col items-center pt-2">
        {/* Circular Institution Crest Logo (Exact Position from Reference) */}
        <div className="w-16 h-16 rounded-full border-2 border-[#2E5A54] p-1 bg-white shadow-md flex items-center justify-center mb-2">
          <img
            src="/assets/images/Logo.png"
            alt="Calligro Crest"
            className="w-full h-full object-contain"
          />
        </div>

        {/* Institution Name (Tracked Serif All-Caps from Reference) */}
        <h3
          className="text-[#1F3D38] text-base md:text-lg font-bold tracking-[0.25em] uppercase font-serif mt-1"
          style={{ letterSpacing: "0.22em" }}
        >
          CALLIGRO ACADEMY OF ARABIC CALLIGRAPHY
        </h3>
        <p
          className="text-[#3D736B] text-sm font-semibold tracking-wide mt-0.5"
          style={{ fontFamily: "'Aref Ruqaa', serif" }}
        >
          أكاديمية كاليغرو لتعليم فنون الخط العربي
        </p>

        {/* ─── CERTIFICATE TITLE (MATCHING REFERENCE "CERTIFICATE OF MASTERY") ─── */}
        <div className="flex flex-col items-center mt-3">
          <h1
            className="text-4xl md:text-5xl font-serif tracking-[0.28em] text-[#162D29] font-bold uppercase"
            style={{ letterSpacing: "0.25em" }}
          >
            CERTIFICATE
          </h1>
          <p
            className="text-2xl md:text-3xl font-serif tracking-[0.35em] text-[#2E5A54] font-medium uppercase mt-1"
            style={{ letterSpacing: "0.3em" }}
          >
            OF ATTENDANCE
          </p>
          <span
            className="text-2xl font-bold text-[#8C6D23] mt-1"
            style={{ fontFamily: "'Thuluth', 'Amiri', 'Aref Ruqaa', serif" }}
          >
            شهادة حضور
          </span>

          {/* Ornate Flourish Divider (Exact Reference Style: —❦—) */}
          <div className="flex items-center gap-3 my-2 w-72">
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#2E5A54] to-transparent" />
            <span className="text-[#2E5A54] text-sm">❧ ❖ ☙</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#2E5A54] to-transparent" />
          </div>
        </div>

        {/* Presented To */}
        <p className="text-[#5A4E3A] text-xs font-serif italic tracking-wider mt-1">
          Presented to / تُمنح بكل فخر واعتزاز إلى
        </p>
      </div>

      {/* ─── 2. PARTICIPANT'S NAME (ELEGANT CALLIGRAPHIC SCRIPT WITH BASELINE) ─── */}
      <div className="relative z-20 flex flex-col items-center my-auto py-1">
        <h2
          className="text-5xl md:text-6xl font-bold text-[#142622] text-center px-12"
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
        <div className="w-[420px] h-[1px] bg-[#C5A059] mt-2 opacity-80" />
      </div>

      {/* ─── 3. COURSE ACHIEVEMENT (GOTHIC / BOLD TITLE & ISSUED DATE) ─── */}
      <div className="relative z-20 max-w-3xl mx-auto text-center space-y-1 mb-2">
        <p className="text-[#3A3226] text-xs font-serif tracking-wider">
          For completing this professional course on / لحضوره/ـا ومشاركته/ـا الفاعلة في الدورة التدريبية:
        </p>
        <p
          className="text-2xl md:text-3xl font-bold text-[#1A332F] py-0.5"
          style={{ fontFamily: "'Aref Ruqaa', 'Amiri', serif" }}
        >
          « {courseName} »
        </p>
        <p className="text-xs font-serif text-[#4A4032]">
          <span>Issued / تاريخ الإصدار: </span>
          <span className="font-semibold text-[#1A332F]">{effectiveDateStr}</span>
          {totalHours && (
            <span className="mr-2"> • بواقع {totalHours} ساعات تدريبية معتمدة</span>
          )}
        </p>
      </div>

      {/* ─── 4. BOTTOM SECTION: TWO SIGNATURES + RADIANT GOLD FOIL DIPLOMA SEAL IN CENTER ─── */}
      <div className="relative z-20 w-full grid grid-cols-3 items-end px-16 pb-3 pt-2">
        
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
                className="text-xl text-[#142622]"
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
          <div className="w-44 h-[1px] bg-[#2E5A54]/60 mt-1" />
          <p className="text-[#1A332F] text-[11px] font-serif font-bold tracking-wider mt-1 uppercase">
            Executive Director / مدرب المساق
          </p>
        </div>

        {/* Center Pillar: RADIANT GOLD FOIL METALLIC DIPLOMA SEAL (EXACT POSITION FROM REFERENCE) */}
        <div className="flex flex-col items-center justify-center">
          {/* Metallic Gold Sunburst Rosette Seal */}
          <div
            className="relative w-28 h-28 rounded-full flex items-center justify-center select-none shadow-xl transform hover:scale-105 transition-transform"
            style={{
              background: "conic-gradient(from 45deg, #FFE885, #D4AF37, #A8811A, #F7DE7A, #B88E20, #FFE885, #C99B28, #F7DE7A, #A8811A, #FFE885)",
              boxShadow: "0 6px 18px rgba(0, 0, 0, 0.28), 0 2px 4px rgba(0, 0, 0, 0.15), inset 0 2px 4px rgba(255, 255, 255, 0.8)",
              filter: "drop-shadow(0 4px 8px rgba(135, 100, 20, 0.35))",
            }}
          >
            {/* Outer Serrated Crimp Edge */}
            <div
              className="absolute inset-1 rounded-full pointer-events-none"
              style={{
                border: "2px dashed #FFF3B3",
                opacity: 0.85,
              }}
            />

            {/* Inner Metallic Sunburst Ring */}
            <div
              className="w-20 h-20 rounded-full flex items-center justify-center"
              style={{
                background: "radial-gradient(circle at 35% 35%, #FFFDF0 0%, #F5DE87 35%, #D4AF37 70%, #947112 100%)",
                boxShadow: "inset 0 2px 4px rgba(0, 0, 0, 0.25), 0 1px 2px rgba(255, 255, 255, 0.8)",
                border: "1.5px solid #8C6D23",
              }}
            >
              {/* Central Calligro Pen Nib Emblem in Gold Relief */}
              <div className="w-10 h-10 flex items-center justify-center">
                <svg viewBox="0 0 40 40" className="w-8 h-8 text-[#5A4305]" fill="currentColor">
                  <path d="M20 6 L24 16 C24 21 22 25 21 29 L20 32 L19 29 C18 25 16 21 16 16 Z" />
                  <path d="M20 18 L20 31" stroke="#FFE885" strokeWidth="1" />
                  <circle cx="20" cy="17" r="1.5" fill="#FFE885" />
                  <path d="M12 14 C8 20 9 27 16 31 C13 29 11 24 12 19 C13 16 16 14 19 12 Z" opacity="0.8" />
                </svg>
              </div>
            </div>
          </div>

          {/* Tiny Verified ID Beneath Gold Seal */}
          <span className="text-[#2E5A54] text-[8px] font-mono tracking-widest uppercase font-semibold mt-1">
            SEAL NO. {certificateId ? certificateId.slice(0, 8).toUpperCase() : "VERIFIED"}
          </span>
        </div>

        {/* Right Signature Column: Registrar / مسجل الأكاديمية */}
        <div className="flex flex-col items-center text-center">
          <div className="h-14 flex items-end justify-center w-full pb-1">
            <span
              className="text-xl text-[#142622]"
              style={{
                fontFamily: "'Great Vibes', 'Playfair Display', cursive, serif",
                fontStyle: "italic",
              }}
            >
              Academic Registrar
            </span>
          </div>
          <div className="w-44 h-[1px] bg-[#2E5A54]/60 mt-1" />
          <p className="text-[#1A332F] text-[11px] font-serif font-bold tracking-wider mt-1 uppercase">
            Registrar / مسجل الأكاديمية
          </p>
        </div>

      </div>

      {/* ─── 5. BOTTOM ACCREDITATION DISCLAIMER (EXACT MATCH TO REFERENCE FOOTER) ─── */}
      <div className="relative z-20 text-center pt-1 border-t border-[#2E5A54]/20 mx-16">
        <p className="text-[8.5px] font-serif text-[#2E5A54]/80 tracking-wider">
          This Institute is accredited by Calligro International Board for Calligraphy Arts & Islamic Heritage • Officially Verified Digital Credential
        </p>
      </div>

    </div>
  );
}
