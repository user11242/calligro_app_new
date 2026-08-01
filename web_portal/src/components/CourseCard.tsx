"use client";
import { motion } from "framer-motion";
import { Users, Clock, Calendar, CheckCircle2, Zap, Languages, PlayCircle, Star, ArrowRight, Lock } from "lucide-react";
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
    setTitle(rawTitle);
    if (locale !== "ar" && rawTitle) {
      translateText(rawTitle, locale, "ar").then(setTitle);
    }
  }, [rawTitle, locale]);

  // -- STATE 1: Enrollment --
  const currentUser = auth.currentUser;
  const enrolledStudents = course.enrolledStudents || [];
  const isEnrolled = currentUser && enrolledStudents.includes(currentUser.uid);

  // -- STATE 2: Time Status --
  let isUpcoming = false;
  let isActive = false;
  let isEnded = false;
  let daysRemaining: number | null = null;

  if (course.startDate) {
    const start = course.startDate.toDate ? course.startDate.toDate() : new Date(course.startDate);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
    
    let endDay: Date | null = null;
    if (course.endDate) {
      const end = course.endDate.toDate ? course.endDate.toDate() : new Date(course.endDate);
      endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
    }

    if (today < startDay) {
      isUpcoming = true;
      daysRemaining = Math.ceil((start.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    } else if (endDay && today > endDay) {
      isEnded = true;
    } else {
      isActive = true;
    }
  }

  // -- STATE 3: Difficulty Level --
  let levelRaw = (course.selectedCategory || "Beginner").toLowerCase();
  let difficultyState = { label: "", color: "", bg: "", bars: 1 };
  
  if (levelRaw.includes("begin")) {
    difficultyState = { label: t("categories.beginner"), color: "text-teal-400", bg: "bg-teal-500/10 border-teal-500/30", bars: 1 };
  } else if (levelRaw.includes("inter")) {
    difficultyState = { label: t("categories.intermediate"), color: "text-amber-400", bg: "bg-amber-500/10 border-amber-500/30", bars: 2 };
  } else if (levelRaw.includes("advan")) {
    difficultyState = { label: t("categories.advanced"), color: "text-violet-400", bg: "bg-violet-500/10 border-violet-500/30 shadow-[0_0_15px_rgba(139,92,246,0.2)]", bars: 3 };
  } else {
    difficultyState = { label: course.selectedCategory || "Beginner", color: "text-[#FDFBF7]", bg: "bg-[#FDFBF7]/10 border-[#FDFBF7]/20", bars: 1 };
  }

  const price = Number(course.price || 0);
  const currentEnrollment = enrolledStudents.length;
  const maxStudents = Number(course.maxStudents || 0);

  // Formatting
  const dateLocale = locale === "ar" ? "ar-EG" : locale === "tr" ? "tr-TR" : "en-US";
  const timeLocale = locale === "ar" ? "ar-EG" : "en-US";
  
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

  // Card Outer Classes (Changes if enrolled)
  const cardOuterClass = isEnrolled
    ? "group relative flex flex-col md:flex-row w-full bg-[#1A1814] rounded-[32px] overflow-hidden border border-[#D4B04C]/40 shadow-[0_0_30px_rgba(212,176,76,0.15)] hover:shadow-[0_0_50px_rgba(212,176,76,0.3)] hover:border-[#D4B04C] transition-all duration-500"
    : "group relative flex flex-col md:flex-row w-full bg-[#1A1814] rounded-[32px] overflow-hidden border border-[#FDFBF7]/5 shadow-[0_20px_40px_rgba(0,0,0,0.8)] hover:border-[#FDFBF7]/20 hover:shadow-[0_20px_60px_rgba(253,251,247,0.05)] transition-all duration-500";

  return (
    <motion.div
      whileHover={{ scale: 1.01 }}
      transition={{ type: "spring", stiffness: 300, damping: 20 }}
      className={cardOuterClass}
    >
      <Link href={isEnrolled ? `/courses/${course.id}/classroom` : `/courses/${course.id}`} className="flex flex-col md:flex-row w-full h-full">
        
        {/* ── LEFT: DYNAMIC IMAGE CONTAINER ── */}
        <div className="relative w-full md:w-[45%] h-[280px] md:h-auto overflow-hidden shrink-0 bg-[#13110C]">
          <Image
            src={formatImageUrl(course.courseBanner) || "/images/placeholder.png"}
            alt={title}
            fill
            className={`object-cover transition-transform duration-[2000ms] group-hover:scale-105 ease-out ${
              isEnded ? "grayscale opacity-60" : ""
            } ${isUpcoming ? "blur-md scale-110 opacity-50" : ""}`}
          />
          
          <div className="absolute inset-0 bg-gradient-to-t from-[#13110C] via-[#13110C]/40 to-transparent opacity-80" />
          {isEnrolled && <div className="absolute inset-0 bg-[#D4B04C]/10 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />}

          {/* Difficulty Badge */}
          <div className="absolute top-6 left-6 z-10">
            <div className={`backdrop-blur-md px-3 py-1.5 rounded-full shadow-lg border flex items-center gap-2 ${difficultyState.bg}`}>
              <div className="flex items-end gap-[2px] h-3">
                <div className={`w-1 rounded-sm ${difficultyState.bars >= 1 ? "bg-current h-1.5" : "bg-[#FDFBF7]/20 h-1.5"}`} />
                <div className={`w-1 rounded-sm ${difficultyState.bars >= 2 ? "bg-current h-2.5" : "bg-[#FDFBF7]/20 h-2.5"}`} />
                <div className={`w-1 rounded-sm ${difficultyState.bars >= 3 ? "bg-current h-full" : "bg-[#FDFBF7]/20 h-full"}`} />
              </div>
              <span className={`text-[10px] font-black uppercase tracking-widest ${difficultyState.color}`}>{difficultyState.label}</span>
            </div>
          </div>

          {/* Time State Overlays (Center) */}
          {isUpcoming && daysRemaining !== null && (
            <div className="absolute inset-0 flex flex-col items-center justify-center z-20">
              <div className="text-[#FDFBF7]/60 text-xs font-bold uppercase tracking-[0.3em] mb-2">{t("course.starts_in") || "Starts in"}</div>
              <div className="text-5xl font-black font-outfit text-[#D4B04C] drop-shadow-[0_0_20px_rgba(212,176,76,0.3)]">{daysRemaining}</div>
              <div className="text-[#FDFBF7]/80 text-sm font-bold uppercase tracking-widest mt-1">Days</div>
            </div>
          )}

          {isEnded && (
            <div className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none">
              <div className="px-6 py-2 border-2 border-[#FDFBF7]/20 rounded-lg transform -rotate-12 bg-[#13110C]/40 backdrop-blur-sm">
                <span className="text-[#FDFBF7]/40 font-black uppercase tracking-[0.4em] text-xl">Archived</span>
              </div>
            </div>
          )}

          {/* Hover Overlay Actions */}
          {!isUpcoming && (
            <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-500 z-30">
              {isEnrolled ? (
                <div className="px-6 py-3 rounded-full bg-[#D4B04C] text-[#13110C] font-black uppercase tracking-widest text-xs flex items-center gap-2 shadow-[0_0_30px_rgba(212,176,76,0.5)] transform scale-90 group-hover:scale-100 transition-transform duration-500">
                  Enter Classroom <ArrowRight className="w-4 h-4" />
                </div>
              ) : (
                <div className="w-16 h-16 rounded-full bg-[#13110C]/50 backdrop-blur-md flex items-center justify-center border border-[#FDFBF7]/50 text-[#FDFBF7] transform scale-90 group-hover:scale-100 transition-transform duration-500">
                  {isEnded ? <Lock className="w-6 h-6 text-[#FDFBF7]/50" /> : <PlayCircle className="w-8 h-8" />}
                </div>
              )}
            </div>
          )}

          {/* Premium 50% Off Tag (Only if NOT enrolled and NOT ended) */}
          {!isEnrolled && !isEnded && (
            <div className="absolute -top-1 right-8 md:right-6 z-20 group-hover:rotate-12 transition-transform duration-500 origin-top">
              <div className="w-px h-8 bg-gradient-to-b from-[#FDFBF7]/40 to-transparent mx-auto" />
              <div className="bg-gradient-to-b from-[#D4B04C] to-[#B08D30] shadow-[0_10px_30px_rgba(0,0,0,0.5)] rounded-t-sm rounded-b-xl p-2.5 flex flex-col items-center border border-[#FDFBF7]/30 relative">
                <div className="w-2 h-2 rounded-full bg-[#13110C]/40 border-t border-[#13110C]/80 shadow-inner mb-3" />
                <span className="[writing-mode:vertical-lr] rotate-180 text-[#13110C] font-black text-[12px] tracking-widest uppercase">
                  {t("course.off")} 50%
                </span>
              </div>
            </div>
          )}
        </div>

        {/* ── RIGHT: CONTENT CONTAINER ── */}
        <div className="relative flex-1 p-6 md:p-8 flex flex-col justify-between bg-gradient-to-br from-[#1A1814] to-[#13110C]">
          
          <div className="space-y-4">
            
            {/* Status & Enrollment Row */}
            <div className="flex flex-wrap items-center justify-between gap-4">
              {isActive && (
                <div className="flex items-center gap-2 bg-emerald-500/10 border border-emerald-500/30 px-3 py-1 rounded-full">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-emerald-400">Live Now</span>
                </div>
              )}
              {isUpcoming && (
                <div className="flex items-center gap-2 bg-amber-500/10 border border-amber-500/30 px-3 py-1 rounded-full">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-400" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-amber-400">Enrolling</span>
                </div>
              )}
              {isEnded && (
                <div className="flex items-center gap-2 bg-[#FDFBF7]/5 border border-[#FDFBF7]/10 px-3 py-1 rounded-full">
                  <CheckCircle2 className="w-3 h-3 text-[#FDFBF7]/40" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-[#FDFBF7]/40">Completed</span>
                </div>
              )}
              
              <div className="flex items-center gap-1.5 bg-[#FDFBF7]/5 border border-[#FDFBF7]/5 px-3 py-1 rounded-full">
                <Users className="w-3.5 h-3.5 text-[#FDFBF7]/40" />
                <span className="text-[10px] font-bold text-[#FDFBF7]/60 tracking-wider">
                  {currentEnrollment} {maxStudents > 0 ? `/ ${maxStudents}` : ""} Students
                </span>
              </div>
            </div>

            {/* Title */}
            <h3 className="text-2xl md:text-3xl font-black font-outfit text-[#FDFBF7] leading-[1.2] group-hover:text-[#D4B04C] transition-colors duration-300">
              {title}
            </h3>

            {/* Teacher Row */}
            <div className="flex items-center gap-3 pt-2">
              <div className="w-10 h-10 rounded-full overflow-hidden border border-[#FDFBF7]/10 group-hover:border-[#D4B04C]/50 transition-colors">
                <Image
                  src={formatImageUrl(teacherPic) || "/images/placeholder.png"}
                  alt={teacherName}
                  width={40}
                  height={40}
                  className="w-full h-full object-cover grayscale-[20%] group-hover:grayscale-0 transition-all"
                />
              </div>
              <div>
                <p className="text-sm font-bold text-[#FDFBF7]/90">{teacherName}</p>
                <div className="flex items-center gap-1 text-[#D4B04C]">
                  {[...Array(5)].map((_, i) => (
                    <Star key={i} className="w-3 h-3 fill-current" />
                  ))}
                  <span className="text-[10px] font-bold text-[#FDFBF7]/40 ml-1">(4.9)</span>
                </div>
              </div>
            </div>
          </div>

          {/* Bottom Section: Details & Price */}
          <div className="mt-8 pt-6 border-t border-[#FDFBF7]/5 flex flex-col md:flex-row md:items-end justify-between gap-6">
            
            {/* Meta Details */}
            <div className="space-y-3">
              {formattedDates && (
                <div className="flex items-center gap-3 text-[#FDFBF7]/50">
                  <div className="w-8 h-8 rounded-full bg-[#FDFBF7]/5 flex items-center justify-center">
                    <Calendar className="w-4 h-4 text-[#D4B04C]" />
                  </div>
                  <span className="text-sm font-semibold">{formattedDates}</span>
                </div>
              )}
              {formattedTime && (
                <div className="flex items-center gap-3 text-[#FDFBF7]/50">
                  <div className="w-8 h-8 rounded-full bg-[#FDFBF7]/5 flex items-center justify-center">
                    <Clock className="w-4 h-4 text-[#D4B04C]" />
                  </div>
                  <span className="text-sm font-semibold">{formattedTime}</span>
                </div>
              )}
            </div>

            {/* Price Box OR Ownership Action */}
            <div className="flex flex-col items-end">
              {isEnrolled ? (
                <div className="flex flex-col items-end gap-2">
                  <span className="text-[10px] font-black uppercase tracking-[0.3em] text-[#D4B04C]/60">Your Course</span>
                  <div className="px-6 py-2.5 rounded-xl border border-[#D4B04C]/30 text-[#D4B04C] font-bold text-sm bg-[#D4B04C]/10">
                    {isActive ? "Enter Live Classroom" : "View Course Materials"}
                  </div>
                </div>
              ) : (
                <>
                  {!isEnded && price > 0 && (
                    <span className="text-xs font-bold text-[#FDFBF7]/30 line-through decoration-red-500/50 mb-1">
                      ${price.toFixed(0)}
                    </span>
                  )}
                  {isEnded ? (
                    <div className="px-6 py-2.5 rounded-xl border border-[#FDFBF7]/10 text-[#FDFBF7]/40 font-bold text-sm bg-[#FDFBF7]/5">
                      Enrollment Closed
                    </div>
                  ) : (
                    <div className="flex items-center gap-1 bg-[#D4B04C]/10 border border-[#D4B04C]/20 px-6 py-3 rounded-2xl group-hover:bg-[#D4B04C] group-hover:scale-105 transition-all duration-300">
                      <span className="text-[#D4B04C] group-hover:text-[#13110C] font-black text-sm">$</span>
                      <span className="text-[#D4B04C] group-hover:text-[#13110C] font-black text-3xl font-outfit leading-none">
                        {(price / 2).toFixed(0)}
                      </span>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>
          
        </div>
      </Link>
    </motion.div>
  );
}
