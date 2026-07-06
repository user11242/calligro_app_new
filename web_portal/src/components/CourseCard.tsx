"use client";
import { motion } from "framer-motion";
import { Users, Clock, Calendar, CheckCircle2, Zap, Languages } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useState, useEffect } from "react";
import { formatImageUrl } from "@/lib/utils";
import { auth } from "@/lib/firebase";
import { useTranslation } from "@/hooks/useTranslation";
import { translateText } from "@/lib/translateText";

interface CourseCardProps {
  course: any;
}

export default function CourseCard({ course }: CourseCardProps) {
  const { t, locale } = useTranslation();
  const rawTitle = course.courseName || course.courseTitle || "Untitled Course";
  const [title, setTitle] = useState(rawTitle);
  const teacherName = course.teacherName || "Master Instructor";
  const teacherPic = course.teacherProfilePic || "";

  // Auto-translate Arabic title when locale is not Arabic
  useEffect(() => {
    setTitle(rawTitle); // reset immediately on course change
    if (locale !== "ar" && rawTitle) {
      translateText(rawTitle, locale, "ar").then(setTitle);
    }
  }, [rawTitle, locale]);

  let levelRaw = course.selectedCategory || "Beginner";
  let level = levelRaw;
  if (levelRaw.toLowerCase().includes("begin")) level = t("categories.beginner");
  else if (levelRaw.toLowerCase().includes("inter")) level = t("categories.intermediate");
  else if (levelRaw.toLowerCase().includes("advan")) level = t("categories.advanced");

  const price = Number(course.price || 0);
  const enrolledStudents = course.enrolledStudents || [];
  const currentEnrollment = enrolledStudents.length;
  const maxStudents = Number(course.maxStudents || 0);
  const targetAge = course.ageCategory || course.targetAge || "";
  const teacherLanguages = course.teacherLanguage || course.teacherLanguages || "";

  // Locale-aware date/time formatting
  const dateLocale = locale === "ar" ? "ar-EG" : locale === "tr" ? "tr-TR" : "en-US";
  // Turkish uses 24h time natively — force en-US (12h AM/PM) to match English style
  const timeLocale = locale === "ar" ? "ar-EG" : "en-US";

  // Format Dates & Time
  let formattedDates = "";
  if (course.startDate && course.endDate) {
    const sDate = course.startDate.toDate ? course.startDate.toDate() : new Date(course.startDate);
    const eDate = course.endDate.toDate ? course.endDate.toDate() : new Date(course.endDate);
    const opts: Intl.DateTimeFormatOptions = { month: "short", day: "numeric" };
    formattedDates = `${sDate.toLocaleDateString(dateLocale, opts)} – ${eDate.toLocaleDateString(dateLocale, opts)}`;
  }

  let formattedTime = "";
  const rawTime = course.startTime || course.sessionTime;
  if (rawTime) {
    if (typeof rawTime === "string") formattedTime = rawTime;
    else if (rawTime.toDate) formattedTime = rawTime.toDate().toLocaleTimeString(timeLocale, { hour: "numeric", minute: "2-digit" });
  }

  // Status & Countdown
  let daysRemaining: number | null = null;
  let statusLabel = "";
  let statusBg = "";
  let statusText = "";
  let statusBorder = "";
  let StatusIcon: any = null;

  if (course.startDate) {
    const start = course.startDate.toDate ? course.startDate.toDate() : new Date(course.startDate);
    const now = new Date();
    const diff = Math.ceil((start.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    if (diff >= 0) daysRemaining = diff;

    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
    let endDay: Date | null = null;
    if (course.endDate) {
      const end = course.endDate.toDate ? course.endDate.toDate() : new Date(course.endDate);
      endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
    }

    if (today < startDay) {
      statusLabel = t("course.upcoming");
      statusBg = "bg-amber-500/15";
      statusText = "text-amber-400";
      statusBorder = "border-amber-400/30";
      StatusIcon = Clock;
    } else if (endDay && today > endDay) {
      statusLabel = t("course.ended");
      statusBg = "bg-red-500/15";
      statusText = "text-red-400";
      statusBorder = "border-red-400/30";
      StatusIcon = CheckCircle2;
    } else {
      statusLabel = t("course.active");
      statusBg = "bg-emerald-500/15";
      statusText = "text-emerald-400";
      statusBorder = "border-emerald-500/30";
      StatusIcon = Zap;
    }
  }

  const currentUser = auth.currentUser;
  const isEnrolled = currentUser && enrolledStudents.includes(currentUser.uid);

  const sessionDays = course.selectedDays || [];
  const sessionDaysFormatted = sessionDays.map((d: string) => t(`days.${d.toLowerCase()}`)).join("، ");

  const enrollmentProgress = maxStudents > 0 ? (currentEnrollment / maxStudents) * 100 : 0;
  const isUrgent = maxStudents > 0 && (maxStudents - currentEnrollment) <= 3;

  return (
    <motion.div
      whileHover={{ y: -14, scale: 1.02 }}
      transition={{ type: "spring", stiffness: 260, damping: 20 }}
      className="relative h-[570px] md:h-[590px] group"
    >
      <Link href={`/courses/${course.id}`}>

        {/* ── Background image card ── */}
        <div className="absolute inset-0 rounded-[36px] md:rounded-[48px] overflow-hidden bg-[#050505] border border-white/10 shadow-[0_32px_64px_-16px_rgba(0,0,0,0.6)] z-0">
          <Image
            src={formatImageUrl(course.courseBanner) || "/images/placeholder.png"}
            alt={title}
            fill
            className="object-cover transition-transform duration-[2500ms] group-hover:scale-110 ease-out"
            priority={false}
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black via-black/85 to-transparent" />
          <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-transparent to-transparent opacity-40 group-hover:opacity-70 transition-opacity" />
        </div>

        {/* ── Floating top badges ── */}
        <div className="absolute -top-4 md:-top-6 left-4 md:left-8 right-4 md:right-8 flex justify-between items-start z-10">

          {/* Discount hanging tag (right) */}
          <div className="relative scale-90 md:scale-100">
            <div className="absolute -top-1 left-1/2 -translate-x-1/2 w-6 h-10 border border-white/40 rounded-full" />
            <div className="relative mt-8 bg-primary text-black font-black text-[10px] md:text-[12px] px-2 md:px-2.5 py-3 md:py-4 flex flex-col items-center justify-center shadow-2xl transform rotate-12 transition-all duration-500 group-hover:rotate-0 origin-top rounded-b-lg rounded-t-sm">
              <div className="w-1.5 h-1.5 rounded-full bg-black/20 mb-2 border border-black/10" />
              <span className="[writing-mode:vertical-lr] rotate-180 tracking-[0.2em] whitespace-nowrap">
                {t("course.off")} 50%
              </span>
            </div>
          </div>

          {/* Left: Level + Age (stacked) */}
          <div className="flex flex-col items-end gap-2 pt-8 md:pt-10">
            {/* Level / Enrolled badge */}
            {isEnrolled ? (
              <div className="bg-green-500/20 backdrop-blur-xl border border-green-500/30 px-4 py-2 rounded-2xl shadow-[0_0_20px_rgba(34,197,94,0.2)] flex items-center gap-2 animate-pulse">
                <CheckCircle2 className="w-3.5 h-3.5 text-green-400" />
                <span className="text-[10px] font-black uppercase tracking-widest text-green-400">{t("course.enrolled")}</span>
              </div>
            ) : (
              <div className="bg-white/10 backdrop-blur-xl border border-white/20 px-4 py-2 rounded-2xl shadow-xl">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/90">{level}</span>
              </div>
            )}

            {/* Age badge — creative split-panel range */}
            {targetAge && (() => {
              const hasDash = targetAge.includes("-");
              const [ageStart, ageEnd] = hasDash ? targetAge.split("-") : [targetAge.replace("+",""), "+"];
              const isRtl = locale === "ar";
              return (
                <div dir="ltr" className="flex flex-col rounded-2xl overflow-hidden shadow-[0_4px_24px_rgba(0,0,0,0.5),0_0_0_1px_rgba(255,255,255,0.07)] group-hover:shadow-[0_4px_32px_rgba(238,229,147,0.12),0_0_0_1px_rgba(238,229,147,0.15)] transition-shadow duration-500">

                  {/* Header strip — full width label */}
                  <div className="bg-[rgba(12,12,12,0.98)] border-b border-white/[0.06] flex items-center justify-center gap-1.5 py-1.5 px-3">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="rgba(238,229,147,0.5)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                      <circle cx="9" cy="7" r="4"/>
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                      <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                    <span className="text-[7px] font-black uppercase tracking-[0.25em] text-white/30">
                      {t("course.age_range")}
                    </span>
                  </div>

                  {/* Split panels */}
                  <div className="flex items-stretch">

                    {/* Left panel — dark glass */}
                    <div className="relative bg-[rgba(20,20,20,0.95)] px-4 py-2.5 flex items-center justify-center flex-1">
                      <div className="absolute inset-0 bg-gradient-to-b from-white/[0.04] to-transparent pointer-events-none" />
                      <span className="text-[22px] font-black text-white leading-none tracking-tight tabular-nums">{ageStart}</span>
                    </div>

                    {/* Divider + arrow */}
                    <div className="bg-[rgba(10,10,10,0.9)] flex items-center justify-center w-7 relative">
                      <div className="absolute inset-y-0 left-0 w-px bg-gradient-to-b from-transparent via-white/10 to-transparent" />
                      <div className="absolute inset-y-0 right-0 w-px bg-gradient-to-b from-transparent via-primary/20 to-transparent" />
                      <svg width="14" height="8" viewBox="0 0 14 8" fill="none">
                        <path d="M1 4h10M8 1l3 3-3 3" stroke="rgba(238,229,147,0.55)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    </div>

                    {/* Right panel — glowing primary */}
                    <div className="relative bg-primary px-4 py-2.5 flex items-center justify-center flex-1 overflow-hidden">
                      <div className="absolute inset-0 bg-gradient-to-b from-white/20 via-transparent to-black/10 pointer-events-none" />
                      <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-700 bg-gradient-to-br from-white/10 to-transparent pointer-events-none" />
                      <span className="text-[22px] font-black text-black leading-none tracking-tight tabular-nums relative z-10">{ageEnd}</span>
                    </div>

                  </div>
                </div>
              );
            })()}
          </div>
        </div>

        {/* ── Glass card (bottom) ── */}
        <div className="absolute inset-x-4 md:inset-x-5 bottom-4 md:bottom-5 z-10">
          <div className="bg-[rgba(10,10,10,0.75)] backdrop-blur-[48px] rounded-[26px] md:rounded-[32px] border border-white/10 shadow-2xl group-hover:bg-[rgba(15,15,15,0.85)] transition-all duration-700 overflow-hidden">

            {/* ── STATUS BANNER — prominent, animated, full-width ── */}
            {statusLabel && StatusIcon && (
              <div
                className={`relative w-full flex items-center justify-center gap-3 py-3.5 overflow-hidden ${
                  statusBg
                } border-b ${statusBorder}`}
              >
                {/* Animated shimmer sweep */}
                <motion.div
                  className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent"
                  animate={{ x: ["-100%", "200%"] }}
                  transition={{ duration: 2.4, repeat: Infinity, ease: "linear", repeatDelay: 1.5 }}
                />

                {/* Pulsing glow dot */}
                <span className="relative flex h-2 w-2 shrink-0">
                  <span
                    className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${
                      statusText === "text-emerald-400" ? "bg-emerald-400" :
                      statusText === "text-amber-400"  ? "bg-amber-400"  : "bg-red-400"
                    }`}
                  />
                  <span
                    className={`relative inline-flex rounded-full h-2 w-2 ${
                      statusText === "text-emerald-400" ? "bg-emerald-400" :
                      statusText === "text-amber-400"  ? "bg-amber-400"  : "bg-red-400"
                    }`}
                  />
                </span>

                <span className={`text-[11px] md:text-[12px] font-black uppercase tracking-[0.25em] ${statusText}`}>
                  {statusLabel}
                </span>

                {/* Countdown pill inline */}
                {daysRemaining !== null && (
                  <span
                    className={`text-[9px] md:text-[10px] font-bold ${statusText} opacity-60 border ${statusBorder} px-2.5 py-0.5 rounded-full`}
                  >
                    {t("course.starts_in")} {daysRemaining} {t("course.days")}
                  </span>
                )}
              </div>
            )}

            <div className="p-5 md:p-6 space-y-4">

              {/* Title */}
              <h3 className="text-lg md:text-xl font-bold font-outfit text-white leading-[1.25] line-clamp-2 transition-colors duration-500 group-hover:text-primary">
                {title}
              </h3>

              {/* Metadata row */}
              <div className="flex flex-wrap items-center gap-x-5 gap-y-2.5">
                {formattedDates && (
                  <div className="flex items-center gap-2">
                    <Calendar className="w-3.5 h-3.5 text-primary/70 shrink-0" />
                    <span className="text-[12px] font-semibold text-white/70">{formattedDates}</span>
                  </div>
                )}
                {sessionDaysFormatted && (
                  <div className="flex items-center gap-2">
                    <span className="text-primary/70 text-[10px] font-black">▐▌</span>
                    <span className="text-[12px] font-semibold text-white/70">{sessionDaysFormatted}</span>
                  </div>
                )}
                {formattedTime && (
                  <div className="flex items-center gap-2">
                    <Clock className="w-3.5 h-3.5 text-primary/70 shrink-0" />
                    <span className="text-[12px] font-semibold text-white/70">{formattedTime}</span>
                  </div>
                )}
                {/* Enrollment inline */}
                <div className="flex items-center gap-2">
                  <Users className={`w-3.5 h-3.5 shrink-0 ${isUrgent ? "text-red-400" : "text-primary/70"}`} />
                  <span className={`text-[12px] font-semibold ${isUrgent ? "text-red-400" : "text-white/70"}`}>{currentEnrollment}/{maxStudents}</span>
                  <div className="w-12 h-1 bg-white/10 rounded-full overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${enrollmentProgress}%` }}
                      className={`h-full rounded-full ${isUrgent ? "bg-red-500" : "bg-primary"}`}
                    />
                  </div>
                </div>
              </div>

              {/* Divider */}
              <div className="h-px w-full bg-gradient-to-r from-transparent via-white/10 to-transparent" />

              {/* ── Teacher (prominent) + Price ── */}
              <div className="flex items-center justify-between gap-3">

                {/* Teacher — bigger, bolder */}
                <div className="flex items-center gap-3 min-w-0">
                  <div className="relative shrink-0">
                    <div className="w-14 h-14 md:w-16 md:h-16 rounded-2xl overflow-hidden border-2 border-white/15 group-hover:border-primary/50 transition-colors shadow-lg">
                      <Image
                        src={formatImageUrl(teacherPic) || "/images/placeholder.png"}
                        alt={teacherName}
                        width={64}
                        height={64}
                        className="w-full h-full object-cover grayscale-[40%] group-hover:grayscale-0 transition-all duration-700"
                      />
                    </div>
                    <div className="absolute -bottom-1 -right-1 bg-primary text-black p-0.5 rounded-lg shadow-lg">
                      <CheckCircle2 className="w-3 h-3" />
                    </div>
                  </div>
                  <div className="min-w-0">
                    <p className="text-base md:text-lg font-black text-white leading-tight line-clamp-2">{teacherName}</p>
                    {teacherLanguages && (
                      <div className="flex items-center gap-1 mt-1">
                        <Languages className="w-3 h-3 text-white/30 shrink-0" />
                        <p className="text-[10px] font-medium text-white/40 truncate">{teacherLanguages}</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Price — right-aligned, prominent */}
                <div className="flex flex-col items-end gap-1 shrink-0">
                  {price > 0 && (
                    <span className="relative text-[10px] font-black text-white/20 tracking-tight line-through decoration-primary/60">
                      ${price.toFixed(0)}
                    </span>
                  )}
                  <div className="bg-primary px-4 py-2 rounded-2xl shadow-[0_8px_24px_rgba(238,229,147,0.25)] flex items-center gap-1 group-hover:scale-105 transition-transform">
                    <span className="text-black text-[11px] font-black">$</span>
                    <span className="text-black text-2xl md:text-3xl font-black font-outfit tracking-tighter leading-none">
                      {(price / 2).toFixed(0)}
                    </span>
                  </div>
                </div>

              </div>
            </div>
          </div>
        </div>

        {/* Edge glow */}
        <div className="absolute inset-0 border border-white/5 group-hover:border-primary/20 rounded-[36px] md:rounded-[48px] transition-colors pointer-events-none" />
      </Link>
    </motion.div>
  );
}
