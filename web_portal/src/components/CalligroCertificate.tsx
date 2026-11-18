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
  courseDate?: Date | string | null;
  totalHours?: number | null;
  className?: string;
  style?: React.CSSProperties;
  language?: "ar" | "en" | "tr";
}

// Helper to determine if text is primarily Arabic
const isArabicText = (text: string) => /[\u0600-\u06FF]/.test(text);

// Classical Ottoman Arabesque Illumination Wing (تذهيب إسلامي جانبي متناظر)
function ArabesqueWing({ className = "" }: { className?: string }) {
  return (
    <svg
      className={`w-36 h-14 pointer-events-none select-none text-[#C5A059] ${className}`}
      viewBox="0 0 160 60"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="wing-gold" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#C5A059" stopOpacity="0.1" />
          <stop offset="40%" stopColor="#DFC37C" stopOpacity="0.85" />
          <stop offset="80%" stopColor="#C5A059" stopOpacity="0.95" />
          <stop offset="100%" stopColor="#8C6D23" stopOpacity="0.85" />
        </linearGradient>
      </defs>
      {/* Flowing classical rumi tendril */}
      <path
        d="M2 30 C30 30 50 16 80 18 C110 20 120 38 145 38 C152 38 158 35 160 30 C154 28 145 22 135 24 C120 27 110 12 80 12 C55 12 35 26 2 30 Z"
        fill="url(#wing-gold)"
        opacity="0.22"
      />
      <path
        d="M0 30 C30 30 50 15 80 17 C110 19 125 36 148 36 C155 36 158 33 160 30"
        stroke="url(#wing-gold)"
        strokeWidth="1.4"
        strokeLinecap="round"
      />
      <path
        d="M25 28 C50 24 75 14 100 20 C120 25 135 34 148 36"
        stroke="#2E5A54"
        strokeWidth="0.8"
        strokeDasharray="2.5 1.5"
        opacity="0.6"
      />
      {/* Rumi curling petal motifs */}
      <path
        d="M85 17 C92 10 102 12 100 18 C98 24 88 22 85 17 Z"
        fill="url(#wing-gold)"
        opacity="0.85"
      />
      <path
        d="M120 22 C128 16 136 18 134 25 C131 31 122 28 120 22 Z"
        fill="url(#wing-gold)"
        opacity="0.8"
      />
      <path
        d="M50 25 C44 20 35 22 36 27 C38 32 46 30 50 25 Z"
        fill="url(#wing-gold)"
        opacity="0.75"
      />
      {/* Terminal palmette finial */}
      <path
        d="M152 30 C156 25 160 22 160 30 C160 38 156 35 152 30 Z"
        fill="url(#wing-gold)"
      />
      {/* Accent gems */}
      <circle cx="82" cy="18" r="1.8" fill="#2E5A54" />
      <circle cx="118" cy="22" r="1.6" fill="url(#wing-gold)" />
      <circle cx="148" cy="36" r="1.8" fill="#2E5A54" />
      <circle cx="5" cy="30" r="1.5" fill="url(#wing-gold)" />
    </svg>
  );
}

// Classical Islamic Header Crest / Palmette (تاج الترويسة المذهب)
function TitleCrest() {
  return (
    <svg
      className="w-24 h-7 text-[#C5A059] mb-0.5 select-none pointer-events-none"
      viewBox="0 0 100 30"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="crest-gold" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor="#C5A059" stopOpacity="0.2" />
          <stop offset="30%" stopColor="#DFC37C" stopOpacity="0.9" />
          <stop offset="50%" stopColor="#EAD8A4" stopOpacity="1" />
          <stop offset="70%" stopColor="#DFC37C" stopOpacity="0.9" />
          <stop offset="100%" stopColor="#C5A059" stopOpacity="0.2" />
        </linearGradient>
      </defs>
      <path
        d="M50 2 C50 2 54 10 62 14 C70 17 80 15 84 12 C78 22 66 24 50 25 C34 24 22 22 16 12 C20 15 30 17 38 14 C46 10 50 2 50 2 Z"
        fill="url(#crest-gold)"
        opacity="0.85"
      />
      <path
        d="M50 6 C52 11 58 15 64 16 C58 19 50 20 42 16 C48 15 50 11 50 6 Z"
        fill="#FAF7F2"
        opacity="0.9"
      />
      <circle cx="50" cy="18" r="2" fill="#2E5A54" />
      <circle cx="50" cy="24" r="1.2" fill="#C5A059" />
      <path
        d="M16 12 C10 10 4 14 0 16 C6 18 12 16 16 12 Z"
        fill="url(#crest-gold)"
        opacity="0.6"
      />
      <path
        d="M84 12 C90 10 96 14 100 16 C94 18 88 16 84 12 Z"
        fill="url(#crest-gold)"
        opacity="0.6"
      />
    </svg>
  );
}

// Classical Diploma Honor Plaque / Cartouche Box (إطار شرفي مميز)
function DiplomaPlaque({
  children,
  maxWidth = "max-w-[720px]",
  className = "",
}: {
  children: React.ReactNode;
  maxWidth?: string;
  className?: string;
}) {
  return (
    <div className={`relative w-full ${maxWidth} mx-auto px-6 py-2 flex items-center justify-center ${className}`}>
      {/* Soft Warm Parchment Luminous Fill */}
      <div
        className="absolute inset-0 rounded-[2px] pointer-events-none"
        style={{
          background: "linear-gradient(180deg, rgba(255,255,255,0.85) 0%, rgba(246,240,228,0.7) 50%, rgba(255,255,255,0.85) 100%)",
          boxShadow: "0 1px 4px rgba(46,90,84,0.06), inset 0 0 14px rgba(197,160,89,0.14)",
        }}
      />

      {/* Outer Antique Gold Hairline Border */}
      <div className="absolute inset-0 border border-[#C5A059]/80 rounded-[2px] pointer-events-none" />

      {/* Inner Banknote Emerald Hairline Inset Border */}
      <div className="absolute inset-[3px] border border-[#2E5A54]/30 rounded-[1px] pointer-events-none" />

      {/* 4 Vector Corner Diamonds */}
      <div className="absolute -top-[4px] -left-[4px] w-2 h-2 text-[#C5A059] pointer-events-none select-none">
        <svg viewBox="0 0 10 10" fill="currentColor" className="w-full h-full">
          <path d="M5 0 L10 5 L5 10 L0 5 Z" />
        </svg>
      </div>
      <div className="absolute -top-[4px] -right-[4px] w-2 h-2 text-[#C5A059] pointer-events-none select-none">
        <svg viewBox="0 0 10 10" fill="currentColor" className="w-full h-full">
          <path d="M5 0 L10 5 L5 10 L0 5 Z" />
        </svg>
      </div>
      <div className="absolute -bottom-[4px] -left-[4px] w-2 h-2 text-[#C5A059] pointer-events-none select-none">
        <svg viewBox="0 0 10 10" fill="currentColor" className="w-full h-full">
          <path d="M5 0 L10 5 L5 10 L0 5 Z" />
        </svg>
      </div>
      <div className="absolute -bottom-[4px] -right-[4px] w-2 h-2 text-[#C5A059] pointer-events-none select-none">
        <svg viewBox="0 0 10 10" fill="currentColor" className="w-full h-full">
          <path d="M5 0 L10 5 L5 10 L0 5 Z" />
        </svg>
      </div>

      {/* Top & Bottom Center Tiny Diamond Finials */}
      <div className="absolute -top-[3px] left-1/2 -translate-x-1/2 w-1.5 h-1.5 text-[#C5A059] pointer-events-none select-none">
        <svg viewBox="0 0 10 10" fill="currentColor" className="w-full h-full">
          <path d="M5 0 L10 5 L5 10 L0 5 Z" />
        </svg>
      </div>
      <div className="absolute -bottom-[3px] left-1/2 -translate-x-1/2 w-1.5 h-1.5 text-[#C5A059] pointer-events-none select-none">
        <svg viewBox="0 0 10 10" fill="currentColor" className="w-full h-full">
          <path d="M5 0 L10 5 L5 10 L0 5 Z" />
        </svg>
      </div>

      {/* Inner Content */}
      <div className="relative z-10 w-full flex items-center justify-center">
        {children}
      </div>
    </div>
  );
}

export default function CalligroCertificate({
  id = "print-area",
  certificateId,
  studentName,
  courseName,
  teacherName = "Master Instructor",
  teacherSignatureUrl,
  dateStr,
  courseDate,
  totalHours,
  className = "",
  style = {},
  language,
}: CalligroCertificateProps) {
  const { locale } = useTranslation();

  // Active language: use prop if provided, otherwise context locale
  const lang: "ar" | "en" | "tr" =
    language || (locale === "ar" || locale === "en" || locale === "tr" ? locale : "ar");

  const isArabicName = isArabicText(studentName || "");

  // Formatted date string depending on language (uses courseDate if provided, or dateStr, or today)
  const effectiveDateStr = (() => {
    if (courseDate) {
      const d = courseDate instanceof Date ? courseDate : new Date(courseDate);
      if (!isNaN(d.getTime())) {
        if (lang === "ar") {
          return d.toLocaleDateString("ar-SA", {
            year: "numeric",
            month: "long",
            day: "numeric",
          });
        } else if (lang === "tr") {
          return d.toLocaleDateString("tr-TR", {
            year: "numeric",
            month: "long",
            day: "numeric",
          });
        } else {
          return d.toLocaleDateString("en-US", {
            year: "numeric",
            month: "long",
            day: "numeric",
          });
        }
      }
    }

    if (dateStr) {
      return dateStr;
    }

    const now = new Date();
    if (lang === "ar") {
      return now.toLocaleDateString("ar-SA", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    } else if (lang === "tr") {
      return now.toLocaleDateString("tr-TR", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    } else {
      return now.toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    }
  })();

  const isRtl = lang === "ar";

  return (
    <div
      id={id}
      className={`w-[1123px] h-[794px] min-w-[1123px] relative overflow-hidden flex flex-col justify-between shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top select-none ${className}`}
      style={{
        boxSizing: "border-box",
        background: "#FAF7F2",
        ...style,
      }}
      dir={isRtl ? "rtl" : "ltr"}
    >
      {/* ─── 100% IDENTICAL VINTAGE DIPLOMA ENGRAVED FRAME (GREEN VINTAGE WITH SUBTLE GOLD ACCENT) ─── */}
      <img
        src="/assets/images/diploma_frame_vintage_transparent.png"
        alt="Vintage Diploma Frame"
        className="absolute inset-0 w-full h-full object-fill pointer-events-none z-10 select-none"
      />

      {/* ─── SUBTLE GOLD FOIL SHIMMER OVERLAY ON THE FRAME ENGRAVING ─── */}
      <img
        src="/assets/images/diploma_frame_vintage_gold.png"
        alt="Gold Frame Accent"
        className="absolute inset-0 w-full h-full object-fill pointer-events-none z-10 select-none opacity-30 mix-blend-screen"
      />

      {/* ─── OUTER GOLD HAIRLINE PERIMETER RIMMING THE ENGRAVED FRAME ─── */}
      <div className="absolute inset-[16px_22px_18px_22px] border border-[#C5A059]/40 rounded-sm pointer-events-none z-10" />

      {/* ─── LUXURY INSET GOLD HAIRLINE BORDER WITH CORNER FLORETS ─── */}
      <div className="absolute inset-[66px_98px_72px_98px] border border-[#C5A059]/65 rounded-sm pointer-events-none z-10">
        <span className="absolute -top-[5px] -left-[5px] text-[#C5A059] text-[8px] select-none">❖</span>
        <span className="absolute -top-[5px] -right-[5px] text-[#C5A059] text-[8px] select-none">❖</span>
        <span className="absolute -bottom-[5px] -left-[5px] text-[#C5A059] text-[8px] select-none">❖</span>
        <span className="absolute -bottom-[5px] -right-[5px] text-[#C5A059] text-[8px] select-none">❖</span>
      </div>

      {/* ─── INNER CONTENT CONTAINER (PRECISELY CENTERED WITHIN THE ENGRAVED DIPLOMA FRAME) ─── */}
      <div className="absolute inset-[75px_95px_78px_95px] flex flex-col justify-between items-center text-center z-20">
        
        {/* ─── 1. TOP TITLE & ACCREDITATION PREAMBLE (ENRICHED WITH ISLAMIC ARABESQUE ILLUMINATION) ─── */}
        <div className="flex flex-col items-center w-full pt-1">
          {/* Top Classical Ottoman Illumination Crest */}
          <TitleCrest />

          {/* Certificate Title Row Flanked by Symmetrical Arabesque Wings */}
          <div className="flex items-center justify-center w-full max-w-[960px] px-2">
            {/* Left Ornamental Arabesque Wing */}
            <div className="flex-1 flex justify-end pr-2 opacity-90">
              <ArabesqueWing />
            </div>

            {/* Certificate Title in genuine Diwan Thuluth */}
            <div className="flex flex-col items-center flex-shrink-0 px-2">
              {lang === "ar" && (
                <h1
                  className="text-[116px] text-[#112420] leading-none my-0 select-none font-normal text-center whitespace-nowrap"
                  style={{
                    fontFamily: "'Diwan Thuluth', 'Thuluth', serif",
                  }}
                >
                  شهادة حضور
                </h1>
              )}

              {lang === "en" && (
                <>
                  <h1
                    className="text-[44px] font-serif tracking-[0.22em] text-[#162D29] font-bold uppercase leading-tight text-center"
                    style={{ letterSpacing: "0.20em" }}
                  >
                    CERTIFICATE
                  </h1>
                  <p
                    className="text-[22px] font-serif tracking-[0.28em] text-[#2E5A54] font-medium uppercase mt-0.5 text-center"
                    style={{ letterSpacing: "0.26em" }}
                  >
                    OF ATTENDANCE
                  </p>
                </>
              )}

              {lang === "tr" && (
                <>
                  <h1
                    className="text-[42px] font-serif tracking-[0.20em] text-[#162D29] font-bold uppercase leading-tight text-center"
                    style={{ letterSpacing: "0.18em" }}
                  >
                    KATILIM BELGESİ
                  </h1>
                  <p
                    className="text-[17px] font-serif tracking-[0.24em] text-[#2E5A54] font-medium uppercase mt-0.5 text-center"
                    style={{ letterSpacing: "0.22em" }}
                  >
                    RESMİ TAMAMLAMA SERTİFİKASI
                  </p>
                </>
              )}
            </div>

            {/* Right Ornamental Arabesque Wing (Horizontally Mirrored) */}
            <div className="flex-1 flex justify-start pl-2 opacity-90">
              <ArabesqueWing className="transform scale-x-[-1]" />
            </div>
          </div>

          {/* Ornate Flourish Divider with Subtle Gold/Green Accents */}
          <div className="flex items-center gap-4 mt-2 mb-1.5 w-[720px]">
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
            <span className="text-[#C5A059] text-xs">❧ ❖ ☙</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-transparent via-[#C5A059] to-transparent" />
          </div>

          {/* Introductory Certification Statement (Prominent, Larger & Bold) */}
          <p
            className={`text-[#142D28] text-[20px] md:text-[21px] font-bold max-w-3xl mx-auto leading-relaxed mt-2.5 ${lang === "ar" ? "" : "tracking-wider font-serif text-base text-[#142D28]"}`}
            style={{
              fontFamily: lang === "ar" ? "'Amiri', serif" : "'Playfair Display', serif",
              fontWeight: 700,
            }}
          >
            {lang === "ar" && "تشهد أكاديمية كاليغرو لتعليم فنون الخط العربي بأن المتدرب/ـة:"}
            {lang === "en" && "Calligro International Academy of Arabic Calligraphy proudly certifies that:"}
            {lang === "tr" && "Calligro Uluslararası Arap Hat Sanatı Akademisi işbu resmi belge ile onaylar ki:"}
          </p>
        </div>

        {/* ─── 2. MIDDLE BLOCK: PARTICIPANT'S NAME & COURSE ACHIEVEMENT ─── */}
        <div className="flex flex-col items-center my-auto w-full">
          {/* Top Delicate Engraved Rule */}
          <div className="flex items-center justify-center gap-3 w-[720px] mb-1">
            <div className="h-[1px] flex-1 bg-gradient-to-l from-[#C5A059]/75 via-[#2E5A54]/30 to-transparent" />
            <span className="text-[#C5A059] text-[8px] transform rotate-45 opacity-90 select-none">◆</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-[#C5A059]/75 via-[#2E5A54]/30 to-transparent" />
          </div>

          {/* Participant's Name (Normal Upright Clean Typography in Distinctive Rich Gold Tone) */}
          <div className="flex items-center justify-center gap-5 my-0.5 max-w-[840px] px-6">
            <span className="text-[#C5A059]/75 text-sm select-none">❧</span>
            <h2
              className="text-4xl md:text-[48px] text-[#A67822] text-center font-semibold tracking-normal"
              style={{
                fontFamily: isArabicName
                  ? "'Amiri', serif"
                  : "'Playfair Display', Georgia, serif",
                lineHeight: "1.25",
                fontStyle: "normal",
                color: "#A67822",
              }}
            >
              {studentName}
            </h2>
            <span className="text-[#C5A059]/75 text-sm select-none">☙</span>
          </div>

          {/* Bottom Delicate Engraved Rule */}
          <div className="flex items-center justify-center gap-3 w-[720px] mt-1 mb-3.5">
            <div className="h-[1px] flex-1 bg-gradient-to-l from-[#C5A059]/75 via-[#2E5A54]/30 to-transparent" />
            <span className="text-[#C5A059] text-[8px] transform rotate-45 opacity-90 select-none">◆</span>
            <div className="h-[1px] flex-1 bg-gradient-to-r from-[#C5A059]/75 via-[#2E5A54]/30 to-transparent" />
          </div>

          {/* Course Achievement, Student Commitment & Best Wishes */}
          <div className="w-full max-w-[860px] mx-auto text-center space-y-2">
            {/* Image 1: Completion Statement (Matching Image 3 font size & bold styling) */}
            <p
              className={`text-[#142D28] text-[20px] md:text-[21px] font-bold leading-relaxed max-w-3xl mx-auto ${lang === "ar" ? "" : "tracking-wider font-serif text-base text-[#142D28]"}`}
              style={{
                fontFamily: lang === "ar" ? "'Amiri', serif" : "'Playfair Display', serif",
                fontWeight: 700,
              }}
            >
              {lang === "ar" && "قد أتم/ـت بنجاح واقتدار كافة المتطلبات التدريبية والتطبيقات العملية المقررة لدورة:"}
              {lang === "en" && "Has successfully fulfilled all curriculum and practical requirements for the course:"}
              {lang === "tr" && "Aşağıda belirtilen uzmanlık kursunun tüm teorik ve pratik gereksinimlerini başarıyla tamamlamıştır:"}
            </p>

            {/* Course Title in Matching Distinguished Award Cartouche */}
            <DiplomaPlaque maxWidth="max-w-[680px]" className="my-1.5">
              <p
                className="text-2xl md:text-[28px] font-bold text-[#142D28] py-0.5"
                style={{
                  fontFamily: isArabicText(courseName)
                    ? "'Aref Ruqaa', 'Amiri', serif"
                    : "'Playfair Display', serif",
                }}
              >
                <span className="text-[#C5A059] font-serif font-normal text-2xl mx-1.5">«</span>
                {courseName}
                <span className="text-[#C5A059] font-serif font-normal text-2xl mx-1.5">»</span>
              </p>
            </DiplomaPlaque>

            {/* Image 2: Commitment of the student & accredited hours (Matching Image 3 font size & bold styling) */}
            <p
              className={`text-[#142D28] text-[19px] md:text-[20px] font-bold leading-relaxed max-w-[840px] mx-auto ${lang === "ar" ? "" : "tracking-wider font-serif text-base text-[#142D28]"}`}
              style={{
                fontFamily: lang === "ar" ? "'Amiri', serif" : "'Playfair Display', serif",
                fontWeight: 700,
              }}
            >
              {lang === "ar" && (totalHours
                ? `بواقع (${totalHours}) ساعات تدريبية معتمدة؛ وذلك تقديراً لالتزامه/ـا المتميز، وجهودهـ/ـا الدؤوبة، ومثابرتهـ/ـا في دراسة وتطبيق أصول وقواعد الخط العربي الأصيل.`
                : "وذلك تقديراً لالتزامه/ـا المتميز، وجهودهـ/ـا الدؤوبة، ومثابرتهـ/ـا العالية في دراسة وتطبيق أصول وقواعد الخط العربي الأصيل.")}
              {lang === "en" && (totalHours
                ? `Comprising (${totalHours}) accredited training hours; in sincere recognition of outstanding student commitment, disciplined practice, and dedication to classical calligraphy arts.`
                : "In sincere recognition of outstanding student commitment, disciplined practice, and profound dedication to classical calligraphy arts.")}
              {lang === "tr" && (totalHours
                ? `(${totalHours}) saatlik akredite eğitim kapsamında; hat sanatının kadim kurallarını öğrenmedeki üstün gayreti, örnek disiplini ve samimi bağlılığının takdiriyle.`
                : "Hat sanatının kadim kurallarını öğrenmedeki üstün gayreti, örnek disiplini ve samimi bağlılığının takdiriyle.")}
            </p>

            {/* Warm wishes for success (Matching Image 3 font size & bold styling) */}
            <p
              className={`text-[#142D28] text-[18px] md:text-[19px] font-bold leading-relaxed max-w-[800px] mx-auto pt-0.5 ${lang === "ar" ? "" : "tracking-wider font-serif text-base text-[#142D28]"}`}
              style={{
                fontFamily: lang === "ar" ? "'Amiri', serif" : "'Playfair Display', serif",
                fontWeight: 700,
              }}
            >
              {lang === "ar" && "مع أصدق تمنياتنا له/ـا بدوام التوفيق والنجاح، ومزيد من التألق والإبداع في مسيرتهـ/ـا الفنية."}
              {lang === "en" && "With our warmest wishes for continued success, artistic fulfillment, and enduring excellence."}
              {lang === "tr" && "Sanat hayatında daimi muvaffakiyetler, ilham ve üstün başarılar dileriz."}
            </p>
          </div>
        </div>

        {/* ─── 4. BOTTOM SECTION: INSTRUCTOR, 3D BLIND EMBOSSED SEAL & DATE/TIME ─── */}
        <div
          className="w-full grid grid-cols-3 items-end px-10 pb-1 max-w-[880px]"
          dir="ltr"
        >
          {/* Left Column: DATE (TITLE UP, DATE DOWN) */}
          <div className="flex flex-col items-center text-center">
            <p className={`text-[#1A332F] text-[13px] font-serif font-bold mb-1 uppercase ${lang === "ar" ? "" : "tracking-wider"}`}>
              {lang === "ar" && "التاريخ"}
              {lang === "en" && "Date"}
              {lang === "tr" && "Tarih"}
            </p>
            <div className="w-40 h-[1px] bg-gradient-to-r from-transparent via-[#C5A059]/75 to-transparent mb-1" />
            <div className="h-12 flex items-center justify-center w-full">
              <span
                className="text-xl text-[#142622] font-semibold"
                style={{
                  fontFamily: lang === "ar"
                    ? "'Aref Ruqaa', 'Amiri', serif"
                    : "'Playfair Display', Georgia, serif",
                }}
              >
                {effectiveDateStr}
              </span>
            </div>
          </div>

          {/* Center Pillar: EXACT 3D BLIND EMBOSSED PAPER SEAL (PROPORTIONAL TO SIGNATURE & DATE BLOCKS) */}
          <div className="flex flex-col items-center justify-center pb-1">
            {/* The Tactile 3D Paper Emboss Stamp */}
            <div
              className="relative w-[76px] h-[76px] rounded-full flex items-center justify-center select-none"
              style={{
                // Matching paper texture & tone for pure blind emboss
                background: "radial-gradient(circle at 35% 30%, #FCFAF7 0%, #F5F0E4 60%, #EBE3D2 100%)",
                boxShadow: `
                  -2.5px -2.5px 5px rgba(255, 255, 255, 0.98),
                  2.5px 2.5px 7px rgba(135, 110, 75, 0.35),
                  inset -2px -2px 3px rgba(255, 255, 255, 0.95),
                  inset 2px 2px 3px rgba(115, 90, 55, 0.28)
                `,
              }}
            >
              {/* Outer Circular Debossed Groove with subtle Gold Foil Rim */}
              <div
                className="absolute inset-1 rounded-full pointer-events-none"
                style={{
                  border: "1.2px solid rgba(197, 160, 89, 0.45)",
                  boxShadow: "inset 1px 1px 1.5px rgba(140, 109, 35, 0.25), 1px 1px 1px rgba(255, 255, 255, 0.95)",
                }}
              />

              {/* Dotted Crimp Ring with Gold Shimmer */}
              <div
                className="absolute inset-2 rounded-full pointer-events-none"
                style={{
                  border: "1px dotted rgba(197, 160, 89, 0.65)",
                }}
              />

              {/* Inner Fine Pressed Ring */}
              <div
                className="absolute inset-3 rounded-full pointer-events-none"
                style={{
                  border: "0.75px solid rgba(155, 130, 95, 0.3)",
                  boxShadow: "1px 1px 1.5px rgba(110, 85, 55, 0.2), inset 1px 1px 1px rgba(255, 255, 255, 0.9)",
                }}
              />

              {/* Pure 3D Vector Embossed Content (100% Matching Book Embosser Reference) */}
              <svg
                className="w-full h-full p-1.5 pointer-events-none"
                viewBox="0 0 160 160"
                style={{
                  filter: `
                    drop-shadow(-1px -1px 0.3px rgba(255, 255, 255, 0.98))
                    drop-shadow(1.2px 1.2px 1px rgba(115, 90, 55, 0.42))
                  `,
                }}
              >
                <defs>
                  {/* Top Arc Path */}
                  <path
                    id="emboss-path-top"
                    d="M 28, 80 A 52, 52 0 0, 1 132, 80"
                    fill="none"
                  />
                  {/* Bottom Arc Path */}
                  <path
                    id="emboss-path-bottom"
                    d="M 132, 80 A 52, 52 0 0, 1 28, 80"
                    fill="none"
                  />
                </defs>

                {/* Top Arc Curved Text (Pure Paper Relief Tone) */}
                <text
                  className="text-[8.5px] uppercase font-bold tracking-[2.8px]"
                  fill="#F5EFE4"
                  style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
                >
                  <textPath href="#emboss-path-top" startOffset="50%" textAnchor="middle">
                    CALLIGRO ACADEMY
                  </textPath>
                </text>

                {/* Bottom Arc Curved Text (Upright, matching book embosser) */}
                <text
                  className="text-[8px] uppercase font-bold tracking-[2.4px]"
                  fill="#F5EFE4"
                  style={{ fontFamily: "'Montserrat', sans-serif", fontWeight: 800 }}
                >
                  <textPath href="#emboss-path-bottom" startOffset="50%" textAnchor="middle">
                    OFFICIAL ACCREDITATION
                  </textPath>
                </text>

                {/* Left Embossed Beaded Dots (3 dots matching book embosser reference) */}
                <circle cx="27" cy="74" r="1.6" fill="#F5EFE4" />
                <circle cx="26" cy="80" r="1.8" fill="#F5EFE4" />
                <circle cx="27" cy="86" r="1.6" fill="#F5EFE4" />

                {/* Right Embossed Beaded Dots (3 dots matching reference) */}
                <circle cx="133" cy="74" r="1.6" fill="#F5EFE4" />
                <circle cx="134" cy="80" r="1.8" fill="#F5EFE4" />
                <circle cx="133" cy="86" r="1.6" fill="#F5EFE4" />

                {/* Central Clean 3D Embossed Star Finials */}
                <circle cx="80" cy="80" r="2.8" fill="#F5EFE4" />
                <circle cx="68" cy="80" r="1.6" fill="#F5EFE4" />
                <circle cx="92" cy="80" r="1.6" fill="#F5EFE4" />
              </svg>
            </div>
          </div>

          {/* Right Column: INSTRUCTOR (TITLE UP, NAME/SIGNATURE DOWN) */}
          <div className="flex flex-col items-center text-center">
            <p className={`text-[#1A332F] text-[13px] font-serif font-bold mb-1 uppercase ${lang === "ar" ? "" : "tracking-wider"}`}>
              {lang === "ar" && "المدرب"}
              {lang === "en" && "Instructor"}
              {lang === "tr" && "Eğitmen"}
            </p>
            <div className="w-40 h-[1px] bg-gradient-to-r from-transparent via-[#C5A059]/75 to-transparent mb-1" />
            <div className="h-12 flex items-center justify-center w-full">
              {teacherSignatureUrl ? (
                <img
                  src={formatImageUrl(teacherSignatureUrl)}
                  alt="Signature"
                  className="max-h-12 object-contain mix-blend-multiply"
                />
              ) : (
                <span
                  className="text-xl text-[#142622]"
                  style={{
                    fontFamily: isArabicText(teacherName)
                      ? "'Diwani Letter', serif"
                      : "'Great Vibes', 'Playfair Display', cursive, serif",
                  }}
                >
                  {teacherName}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* ─── 5. BOTTOM SERIAL NUMBER ─── */}
        <div className="text-center pt-0.5 border-t border-[#2E5A54]/25 w-full max-w-xl">
          <p className="text-[10px] font-mono text-[#2E5A54]/85 tracking-widest font-semibold uppercase">
            {lang === "ar" && `الرقم التسلسلي: ${certificateId || "PENDING"}`}
            {lang === "en" && `Certificate Serial Number: ${certificateId || "PENDING"}`}
            {lang === "tr" && `Sertifika Seri Numarası: ${certificateId || "PENDING"}`}
          </p>
        </div>
      </div>
    </div>
  );
}
