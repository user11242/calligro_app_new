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

const SCALLOP_BORDER_PATH = "M 24 24 Q 32.958333333333336 19.5 41.9 24 Q 50.875 19.5 59.8 24 Q 68.79166666666667 19.5 77.8 24 Q 86.70833333333334 19.5 95.7 24 Q 104.625 19.5 113.6 24 Q 122.54166666666667 19.5 131.5 24 Q 140.45833333333334 19.5 149.4 24 Q 158.375 19.5 167.3 24 Q 176.29166666666669 19.5 185.3 24 Q 194.20833333333334 19.5 203.2 24 Q 212.125 19.5 221.1 24 Q 230.04166666666669 19.5 239.0 24 Q 247.95833333333334 19.5 256.9 24 Q 265.875 19.5 274.8 24 Q 283.7916666666667 19.5 292.8 24 Q 301.70833333333337 19.5 310.7 24 Q 319.625 19.5 328.6 24 Q 337.5416666666667 19.5 346.5 24 Q 355.45833333333337 19.5 364.4 24 Q 373.375 19.5 382.3 24 Q 391.2916666666667 19.5 400.3 24 Q 409.20833333333337 19.5 418.2 24 Q 427.125 19.5 436.1 24 Q 445.0416666666667 19.5 454.0 24 Q 462.95833333333337 19.5 471.9 24 Q 480.875 19.5 489.8 24 Q 498.79166666666674 19.5 507.8 24 Q 516.7083333333334 19.5 525.7 24 Q 534.625 19.5 543.6 24 Q 552.5416666666667 19.5 561.5 24 Q 570.4583333333334 19.5 579.4 24 Q 588.375 19.5 597.3 24 Q 606.2916666666667 19.5 615.3 24 Q 624.2083333333334 19.5 633.2 24 Q 642.125 19.5 651.1 24 Q 660.0416666666667 19.5 669.0 24 Q 677.9583333333334 19.5 686.9 24 Q 695.875 19.5 704.8 24 Q 713.7916666666667 19.5 722.8 24 Q 731.7083333333334 19.5 740.7 24 Q 749.625 19.5 758.6 24 Q 767.5416666666667 19.5 776.5 24 Q 785.4583333333334 19.5 794.4 24 Q 803.375 19.5 812.3 24 Q 821.2916666666667 19.5 830.3 24 Q 839.2083333333334 19.5 848.2 24 Q 857.125 19.5 866.1 24 Q 875.0416666666667 19.5 884.0 24 Q 892.9583333333334 19.5 901.9 24 Q 910.875 19.5 919.8 24 Q 928.7916666666667 19.5 937.8 24 Q 946.7083333333335 19.5 955.7 24 Q 964.625 19.5 973.6 24 Q 982.5416666666667 19.5 991.5 24 Q 1000.4583333333335 19.5 1009.4 24 Q 1018.3750000000001 19.5 1027.3 24 Q 1036.2916666666667 19.5 1045.3 24 Q 1054.2083333333335 19.5 1063.2 24 Q 1072.125 19.5 1081.1 24 Q 1090.0416666666667 19.5 1099.0 24 Q 1103.5 33.325 1099 42.6 Q 1103.5 51.974999999999994 1099 61.3 Q 1103.5 70.625 1099 79.9 Q 1103.5 89.27499999999999 1099 98.6 Q 1103.5 107.925 1099 117.3 Q 1103.5 126.57499999999999 1099 135.9 Q 1103.5 145.22499999999997 1099 154.5 Q 1103.5 163.875 1099 173.2 Q 1103.5 182.52499999999998 1099 191.8 Q 1103.5 201.175 1099 210.5 Q 1103.5 219.825 1099 229.1 Q 1103.5 238.47499999999997 1099 247.8 Q 1103.5 257.125 1099 266.4 Q 1103.5 275.775 1099 285.1 Q 1103.5 294.42499999999995 1099 303.8 Q 1103.5 313.075 1099 322.4 Q 1103.5 331.72499999999997 1099 341.0 Q 1103.5 350.375 1099 359.7 Q 1103.5 369.025 1099 378.3 Q 1103.5 387.67499999999995 1099 397.0 Q 1103.5 406.325 1099 415.6 Q 1103.5 424.97499999999997 1099 434.3 Q 1103.5 443.625 1099 452.9 Q 1103.5 462.275 1099 471.6 Q 1103.5 480.92499999999995 1099 490.2 Q 1103.5 499.57499999999993 1099 508.9 Q 1103.5 518.2249999999999 1099 527.5 Q 1103.5 536.875 1099 546.2 Q 1103.5 555.5249999999999 1099 564.8 Q 1103.5 574.175 1099 583.5 Q 1103.5 592.825 1099 602.1 Q 1103.5 611.4749999999999 1099 620.8 Q 1103.5 630.125 1099 639.4 Q 1103.5 648.7749999999999 1099 658.1 Q 1103.5 667.425 1099 676.8 Q 1103.5 686.075 1099 695.4 Q 1103.5 704.7249999999999 1099 714.0 Q 1103.5 723.375 1099 732.7 Q 1103.5 742.0249999999999 1099 751.3 Q 1103.5 760.675 1099 770.0 Q 1090.0416666666667 774.5 1081.1 770 Q 1072.125 774.5 1063.2 770 Q 1054.2083333333335 774.5 1045.3 770 Q 1036.2916666666667 774.5 1027.3 770 Q 1018.3750000000001 774.5 1009.4 770 Q 1000.4583333333335 774.5 991.5 770 Q 982.5416666666667 774.5 973.6 770 Q 964.625 774.5 955.7 770 Q 946.7083333333335 774.5 937.8 770 Q 928.7916666666667 774.5 919.8 770 Q 910.875 774.5 901.9 770 Q 892.9583333333334 774.5 884.0 770 Q 875.0416666666667 774.5 866.1 770 Q 857.125 774.5 848.2 770 Q 839.2083333333334 774.5 830.3 770 Q 821.2916666666667 774.5 812.3 770 Q 803.375 774.5 794.4 770 Q 785.4583333333334 774.5 776.5 770 Q 767.5416666666667 774.5 758.6 770 Q 749.625 774.5 740.7 770 Q 731.7083333333334 774.5 722.8 770 Q 713.7916666666667 774.5 704.8 770 Q 695.875 774.5 686.9 770 Q 677.9583333333334 774.5 669.0 770 Q 660.0416666666667 774.5 651.1 770 Q 642.125 774.5 633.2 770 Q 624.2083333333334 774.5 615.3 770 Q 606.2916666666667 774.5 597.3 770 Q 588.375 774.5 579.4 770 Q 570.4583333333334 774.5 561.5 770 Q 552.5416666666667 774.5 543.6 770 Q 534.625 774.5 525.7 770 Q 516.7083333333334 774.5 507.8 770 Q 498.79166666666674 774.5 489.8 770 Q 480.875 774.5 471.9 770 Q 462.95833333333337 774.5 454.0 770 Q 445.0416666666667 774.5 436.1 770 Q 427.125 774.5 418.2 770 Q 409.20833333333337 774.5 400.3 770 Q 391.2916666666667 774.5 382.3 770 Q 373.375 774.5 364.4 770 Q 355.45833333333337 774.5 346.5 770 Q 337.5416666666667 774.5 328.6 770 Q 319.625 774.5 310.7 770 Q 301.70833333333337 774.5 292.8 770 Q 283.7916666666667 774.5 274.8 770 Q 265.875 774.5 256.9 770 Q 247.95833333333334 774.5 239.0 770 Q 230.04166666666669 774.5 221.1 770 Q 212.125 774.5 203.2 770 Q 194.20833333333334 774.5 185.3 770 Q 176.29166666666669 774.5 167.3 770 Q 158.375 774.5 149.4 770 Q 140.45833333333334 774.5 131.5 770 Q 122.54166666666667 774.5 113.6 770 Q 104.625 774.5 95.7 770 Q 86.70833333333334 774.5 77.8 770 Q 68.79166666666667 774.5 59.8 770 Q 50.875 774.5 41.9 770 Q 32.958333333333336 774.5 24.0 770 Q 19.5 760.675 24 751.3 Q 19.5 742.0249999999999 24 732.7 Q 19.5 723.375 24 714.0 Q 19.5 704.7249999999999 24 695.4 Q 19.5 686.075 24 676.8 Q 19.5 667.425 24 658.1 Q 19.5 648.7749999999999 24 639.4 Q 19.5 630.125 24 620.8 Q 19.5 611.4749999999999 24 602.1 Q 19.5 592.825 24 583.5 Q 19.5 574.175 24 564.8 Q 19.5 555.5249999999999 24 546.2 Q 19.5 536.875 24 527.5 Q 19.5 518.2249999999999 24 508.9 Q 19.5 499.57499999999993 24 490.2 Q 19.5 480.92499999999995 24 471.6 Q 19.5 462.275 24 452.9 Q 19.5 443.625 24 434.3 Q 19.5 424.97499999999997 24 415.6 Q 19.5 406.325 24 397.0 Q 19.5 387.67499999999995 24 378.3 Q 19.5 369.025 24 359.7 Q 19.5 350.375 24 341.0 Q 19.5 331.72499999999997 24 322.4 Q 19.5 313.075 24 303.8 Q 19.5 294.42499999999995 24 285.1 Q 19.5 275.775 24 266.4 Q 19.5 257.125 24 247.8 Q 19.5 238.47499999999997 24 229.1 Q 19.5 219.825 24 210.5 Q 19.5 201.175 24 191.8 Q 19.5 182.52499999999998 24 173.2 Q 19.5 163.875 24 154.5 Q 19.5 145.22499999999997 24 135.9 Q 19.5 126.57499999999999 24 117.3 Q 19.5 107.925 24 98.6 Q 19.5 89.27499999999999 24 79.9 Q 19.5 70.625 24 61.3 Q 19.5 51.974999999999994 24 42.6 Q 19.5 33.325 24 24.0 Z";

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
        background: "radial-gradient(ellipse at 50% 50%, #FCFBF7 0%, #F9F6EE 65%, #F0E8D8 100%)",
        ...style,
      }}
      dir="rtl"
    >
      {/* ─── AUTHENTIC BANKNOTE DIPLOMA BORDER (CALLIGRO BLACK & GOLD PALETTE) ─── */}
      <svg
        className="absolute inset-0 w-full h-full pointer-events-none z-10"
        viewBox="0 0 1123 794"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          {/* Interlocking Guilloche Wave Lattice for Banknote Ribbon */}
          <pattern
            id="guilloche-lattice"
            width="28"
            height="18"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M 0 9 Q 7 0 14 9 T 28 9"
              fill="none"
              stroke="#1A1A1A"
              strokeWidth="1.2"
              opacity="0.8"
            />
            <path
              d="M 0 9 Q 7 18 14 9 T 28 9"
              fill="none"
              stroke="#1A1A1A"
              strokeWidth="1.2"
              opacity="0.8"
            />
            <path
              d="M 0 4.5 Q 7 13.5 14 4.5 T 28 4.5"
              fill="none"
              stroke="#C5A059"
              strokeWidth="0.8"
              opacity="0.75"
            />
            <path
              d="M 0 13.5 Q 7 4.5 14 13.5 T 28 13.5"
              fill="none"
              stroke="#C5A059"
              strokeWidth="0.8"
              opacity="0.75"
            />
            <circle cx="14" cy="9" r="1.5" fill="#C5A059" />
          </pattern>
        </defs>

        {/* 1. Outermost Continuous Banknote Scalloped Wave Frame */}
        <path
          d={SCALLOP_BORDER_PATH}
          fill="none"
          stroke="#1A1A1A"
          strokeWidth="1.8"
          opacity="0.9"
        />
        <path
          d={SCALLOP_BORDER_PATH}
          fill="none"
          stroke="#C5A059"
          strokeWidth="0.8"
          opacity="0.5"
          transform="scale(0.996) translate(2.2, 1.5)"
        />

        {/* 2. Outer Fine Hairline Border */}
        <rect
          x="28"
          y="28"
          width="1067"
          height="738"
          stroke="#C5A059"
          strokeWidth="1"
          opacity="0.85"
        />

        {/* 3. Authentic Guilloche Ribbon Band (18px wide band around perimeter) */}
        <path
          fillRule="evenodd"
          d="M 33 33 H 1090 V 761 H 33 Z M 51 51 H 1072 V 743 H 51 Z"
          fill="url(#guilloche-lattice)"
          stroke="#1A1A1A"
          strokeWidth="1.5"
        />
        <rect
          x="33"
          y="33"
          width="1057"
          height="728"
          stroke="#C5A059"
          strokeWidth="0.75"
        />
        <rect
          x="51"
          y="51"
          width="1021"
          height="692"
          stroke="#C5A059"
          strokeWidth="0.75"
        />

        {/* 4. Inner Fine Double Pinstripe Frame */}
        <rect
          x="57"
          y="57"
          width="1009"
          height="680"
          stroke="#1A1A1A"
          strokeWidth="1.5"
        />
        <rect
          x="61"
          y="61"
          width="1001"
          height="672"
          stroke="#C5A059"
          strokeWidth="0.75"
          strokeDasharray="4 2"
          opacity="0.75"
        />

        {/* ─── 4 ORNATE CORNER VICTORIAN SCROLLWORK FILIGREES (MATCHING REFERENCE) ─── */}
        {/* Top-Right Corner */}
        <g transform="translate(26, 26)">
          <path
            d="M 0 0 C 35 0 60 12 70 32 C 55 42 42 55 32 70 C 12 60 0 35 0 0 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M 7 7 C 30 7 50 16 58 32 C 46 40 36 50 28 62 C 14 50 7 30 7 7 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="28" cy="28" r="8" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="2" />
          <circle cx="28" cy="28" r="4.5" fill="#C5A059" />
          <circle cx="28" cy="28" r="2" fill="#1A1A1A" />
        </g>

        {/* Top-Left Corner */}
        <g transform="translate(1097, 26) scale(-1, 1)">
          <path
            d="M 0 0 C 35 0 60 12 70 32 C 55 42 42 55 32 70 C 12 60 0 35 0 0 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M 7 7 C 30 7 50 16 58 32 C 46 40 36 50 28 62 C 14 50 7 30 7 7 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="28" cy="28" r="8" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="2" />
          <circle cx="28" cy="28" r="4.5" fill="#C5A059" />
          <circle cx="28" cy="28" r="2" fill="#1A1A1A" />
        </g>

        {/* Bottom-Right Corner */}
        <g transform="translate(26, 768) scale(1, -1)">
          <path
            d="M 0 0 C 35 0 60 12 70 32 C 55 42 42 55 32 70 C 12 60 0 35 0 0 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M 7 7 C 30 7 50 16 58 32 C 46 40 36 50 28 62 C 14 50 7 30 7 7 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="28" cy="28" r="8" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="2" />
          <circle cx="28" cy="28" r="4.5" fill="#C5A059" />
          <circle cx="28" cy="28" r="2" fill="#1A1A1A" />
        </g>

        {/* Bottom-Left Corner */}
        <g transform="translate(1097, 768) scale(-1, -1)">
          <path
            d="M 0 0 C 35 0 60 12 70 32 C 55 42 42 55 32 70 C 12 60 0 35 0 0 Z"
            fill="#1A1A1A"
            opacity="0.95"
          />
          <path
            d="M 7 7 C 30 7 50 16 58 32 C 46 40 36 50 28 62 C 14 50 7 30 7 7 Z"
            fill="#C5A059"
            opacity="0.85"
          />
          <circle cx="28" cy="28" r="8" fill="#FCFBF7" stroke="#1A1A1A" strokeWidth="2" />
          <circle cx="28" cy="28" r="4.5" fill="#C5A059" />
          <circle cx="28" cy="28" r="2" fill="#1A1A1A" />
        </g>
      </svg>

      {/* ─── TOP TRACKING SERIAL (MATCHING REFERENCE IIPM/SECP/24001) ─── */}
      <div className="absolute top-[68px] left-[78px] z-20 text-left font-mono text-[10px] text-[#8C6D23] tracking-widest font-bold" dir="ltr">
        CLG/REG/{certificateId ? certificateId.slice(0, 10).toUpperCase() : "24001"}
      </div>

      {/* ─── 1. TOP HEADER: CREST & INSTITUTION NAME ─── */}
      <div className="relative z-20 flex flex-col items-center pt-3">
        {/* Circular University Crest Emblem Badge */}
        <div
          className="w-16 h-16 rounded-full flex items-center justify-center p-1 shadow-md mb-2"
          style={{
            background: "radial-gradient(circle at 35% 35%, #FFFFFF 0%, #FAF8F5 60%, #E8DFCE 100%)",
            border: "2px solid #C5A059",
            boxShadow: "0 2px 6px rgba(0, 0, 0, 0.12)",
          }}
        >
          <div className="w-13 h-13 rounded-full border border-[#1A1A1A]/30 p-1 flex items-center justify-center">
            <img
              src="/assets/images/Logo.png"
              alt="Calligro Crest"
              className="w-full h-full object-contain"
            />
          </div>
        </div>

        {/* Institution Name (Tracked Serif Capital Letters from Reference) */}
        <h3
          className="text-[#1A1A1A] text-lg font-bold uppercase font-serif tracking-[0.24em]"
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
            className="text-4xl md:text-5xl font-serif text-[#1A1A1A] font-extrabold uppercase tracking-[0.24em]"
          >
            CERTIFICATE
          </h1>
          <p
            className="text-2xl md:text-3xl font-serif text-[#8C6D23] font-bold uppercase tracking-[0.28em] mt-1"
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
        <div className="w-[460px] h-[1px] bg-[#C5A059] mt-2 opacity-90 shadow-sm" />
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
      {/* Enforce dir="ltr" so Left = Executive Director, Center = Seal, Right = Registrar (matching reference) */}
      <div
        className="relative z-20 w-full grid grid-cols-3 items-end px-20 pb-2 pt-1"
        dir="ltr"
      >
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
              background: "radial-gradient(circle at 35% 35%, #FFFFFF 0%, #FAF8F5 60%, #EFE8DC 100%)",
              boxShadow: `
                -3px -3px 6px rgba(255, 255, 255, 0.98),
                3px 3px 8px rgba(135, 110, 75, 0.28),
                inset -2px -2px 4px rgba(255, 255, 255, 0.95),
                inset 2px 2px 4px rgba(115, 90, 55, 0.25)
              `,
            }}
          >
            {/* Outer Debossed Groove */}
            <div
              className="absolute inset-2 rounded-full pointer-events-none"
              style={{
                border: "1px solid rgba(155, 130, 95, 0.35)",
                boxShadow:
                  "inset 1.5px 1.5px 2px rgba(110, 85, 55, 0.22), 1px 1px 1px rgba(255, 255, 255, 0.9)",
              }}
            />

            {/* Dotted Crimp Ring */}
            <div
              className="absolute inset-3.5 rounded-full pointer-events-none"
              style={{
                border: "1.5px dotted rgba(145, 120, 85, 0.55)",
              }}
            />

            {/* Inner Fine Pressed Ring */}
            <div
              className="absolute inset-5 rounded-full pointer-events-none"
              style={{
                border: "1px solid rgba(155, 130, 95, 0.3)",
                boxShadow:
                  "1px 1px 2px rgba(110, 85, 55, 0.18), inset 1px 1px 1px rgba(255, 255, 255, 0.9)",
              }}
            />

            {/* Circular Curved 3D Embossed Typography with Clean Smooth Center */}
            <svg
              className="w-full h-full p-2 pointer-events-none"
              viewBox="0 0 144 144"
              style={{
                filter: "drop-shadow(-1px -1px 0px rgba(255, 255, 255, 0.95)) drop-shadow(1.2px 1.2px 0.8px rgba(110, 85, 45, 0.45))",
              }}
            >
              <defs>
                <path
                  id="final-emboss-top"
                  d="M 24, 72 A 48, 48 0 0, 1 120, 72"
                  fill="none"
                />
                <path
                  id="final-emboss-bottom"
                  d="M 120, 72 A 48, 48 0 0, 1 24, 72"
                  fill="none"
                />
              </defs>

              {/* Top Arc Text (Warm Embossed Paper Tone) */}
              <text
                className="text-[7.5px] uppercase font-bold tracking-[2.5px]"
                fill="#9B7D46"
                style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
              >
                <textPath href="#final-emboss-top" startOffset="50%" textAnchor="middle">
                  CALLIGRO ACADEMY
                </textPath>
              </text>

              {/* Bottom Arc Text */}
              <text
                className="text-[7px] uppercase font-bold tracking-[2.2px]"
                fill="#9B7D46"
                style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
              >
                <textPath href="#final-emboss-bottom" startOffset="50%" textAnchor="middle">
                  OFFICIAL ACCREDITATION
                </textPath>
              </text>

              {/* Left Symmetrical Embossed Dots */}
              <circle cx="23" cy="67" r="1.5" fill="#9B7D46" />
              <circle cx="22" cy="72" r="1.5" fill="#9B7D46" />
              <circle cx="23" cy="77" r="1.5" fill="#9B7D46" />

              {/* Right Symmetrical Embossed Dots */}
              <circle cx="121" cy="67" r="1.5" fill="#9B7D46" />
              <circle cx="122" cy="72" r="1.5" fill="#9B7D46" />
              <circle cx="121" cy="77" r="1.5" fill="#9B7D46" />

              {/* Central 3D Embossed Star Finials (Clean, Dignified, No tree, No logo) */}
              <circle cx="72" cy="72" r="2.5" fill="#9B7D46" />
              <circle cx="62" cy="72" r="1.5" fill="#9B7D46" />
              <circle cx="82" cy="72" r="1.5" fill="#9B7D46" />
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
