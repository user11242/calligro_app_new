"use client";
import { motion } from "framer-motion";
import { ArrowRight, PlayCircle, Lock, Calendar, Clock, CheckCircle } from "lucide-react";
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
  const rawDesc = course.courseDescription || "";
  const [title, setTitle] = useState(rawTitle);
  const [desc, setDesc] = useState(rawDesc);
  const teacherName = course.teacherName || "Master Instructor";
  const teacherPic = course.teacherProfilePic || "";

  useEffect(() => {
    setTitle(rawTitle);
    setDesc(rawDesc);
    if (locale !== "ar") {
      if (rawTitle) translateText(rawTitle, locale, "ar").then(setTitle);
      if (rawDesc) translateText(rawDesc, locale, "ar").then(setDesc);
    }
  }, [rawTitle, rawDesc, locale]);

  const currentUser = auth.currentUser;
  const enrolledStudents = course.enrolledStudents || [];
  const isEnrolled = currentUser && enrolledStudents.includes(currentUser.uid);

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

  const price = Number(course.price || 0);

  // Dynamic Level Colors
  const levelCategory = course.selectedCategory || "Beginner";
  const levelStyles: Record<string, { dot: string, text: string, border: string }> = {
    Beginner: {
      dot: "bg-teal-400 shadow-[0_0_8px_rgba(45,212,191,0.8)]",
      text: "text-white/80 group-hover:text-teal-400",
      border: "group-hover:border-teal-400/40"
    },
    Intermediate: {
      dot: "bg-orange-400 shadow-[0_0_8px_rgba(251,146,60,0.8)]",
      text: "text-white/80 group-hover:text-orange-400",
      border: "group-hover:border-orange-400/40"
    },
    Advanced: {
      dot: "bg-purple-400 shadow-[0_0_8px_rgba(192,132,252,0.8)]",
      text: "text-white/80 group-hover:text-purple-400",
      border: "group-hover:border-purple-400/40"
    }
  };
  const currentLevelStyle = levelStyles[levelCategory] || levelStyles.Beginner;

  return (
    <Link href={`/courses/${course.id}`} className="block w-full outline-none">
      <motion.div
        whileHover={{ y: -4 }}
        transition={{ type: "spring", stiffness: 400, damping: 30 }}
        className="group relative flex flex-col lg:flex-row w-full gap-8 md:gap-10 p-4 md:p-6 lg:p-8 -mx-4 md:-mx-6 lg:-mx-8 rounded-[40px] transition-colors duration-500 hover:bg-white/[0.02]"
      >
        
        {/* ── LEFT COLUMN (Image & Under-Image Status) ── */}
        <div className="relative w-full lg:w-[45%] flex flex-col shrink-0">
          <div className="relative w-full h-[240px] md:h-[280px] rounded-[32px] overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.5)] border border-white/5 group-hover:shadow-[0_20px_60px_rgba(232,196,104,0.15)] transition-shadow duration-700">
            <Image
              src={formatImageUrl(course.courseBanner) || "/images/placeholder.png"}
              alt={title}
              fill
              className={`object-cover transition-transform duration-[2000ms] ease-out group-hover:scale-110 ${
                isEnded ? "grayscale opacity-30 blur-[2px]" : "opacity-90"
              }`}
            />
            
            <div className={`absolute inset-0 bg-gradient-to-t from-black via-black/10 to-transparent ${isEnded ? 'opacity-90' : 'opacity-60'}`} />
            {!isEnded && <div className="absolute inset-0 bg-black/10 group-hover:bg-black/0 transition-colors duration-700" />}

            {/* MASSIVE FINISHED OVERLAY */}
            {isEnded && (
              <div className="absolute inset-0 flex items-center justify-center bg-black/40 backdrop-blur-[2px] z-20">
                <div className="flex flex-col items-center justify-center px-8 py-6 border border-white/10 bg-white/5 rounded-3xl backdrop-blur-md shadow-2xl transform -rotate-[5deg]">
                  <Lock className="w-8 h-8 text-white/50 mb-3" />
                  <span className="text-xl md:text-2xl font-black uppercase tracking-[0.3em] text-white/70 drop-shadow-lg text-center">
                    {t("course.closed") || "Finished"}
                  </span>
                </div>
              </div>
            )}

            {/* Labels on Image */}
            <div className="absolute top-4 left-4 z-30 flex flex-col gap-2 items-start">
              {/* Owned Label */}
              {isEnrolled && (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-emerald-500/90 backdrop-blur-md rounded-full shadow-[0_4px_15px_rgba(16,185,129,0.4)] border border-white/20">
                  <CheckCircle className="w-4 h-4 text-white" />
                  <span className="text-xs font-bold uppercase tracking-wider text-white">
                    {t("course.owned") || "Owned"}
                  </span>
                </div>
              )}
            </div>

            {/* 3D Physical Ribbon 50% Off Tag */}
            {!isEnrolled && !isEnded && (
              <div className="absolute -top-1 -right-1 z-30 transform group-hover:rotate-6 transition-transform duration-700 origin-top-right drop-shadow-2xl">
                <div className="relative bg-gradient-to-br from-[#F5D880] to-[#B08D30] text-black pt-8 pb-6 px-4 rounded-b-md">
                  <div className="absolute top-0 right-full w-2 h-full bg-[#8A6A1C] -z-10 skew-y-[45deg] origin-top-right transform -translate-y-2 opacity-50" />
                  <div className="absolute top-0 left-0 w-full h-2 bg-[#F5D880] -z-10 -skew-x-[45deg] origin-bottom-left transform -translate-x-2 opacity-50" />
                  
                  <span className="[writing-mode:vertical-lr] rotate-180 font-black text-sm tracking-widest uppercase flex items-center gap-2">
                    <span className="opacity-60 text-[10px]">{t("course.off")}</span> 
                    50%
                  </span>
                  
                  <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-4 h-[1px] bg-black/20 border-b border-white/20" />
                  <div className="absolute bottom-3 left-1/2 -translate-x-1/2 w-4 h-[1px] bg-black/20 border-b border-white/20" />
                </div>
              </div>
            )}
          </div>
          
          {/* Under Image Status */}
          {isUpcoming && daysRemaining !== null && (
            <div className="mt-5 flex items-center justify-center gap-3 py-3.5 px-6 bg-white/[0.03] hover:bg-white/[0.06] border border-white/10 rounded-2xl transition-colors duration-500 overflow-hidden relative group/status mx-2">
              <div className="absolute inset-0 -translate-x-full animate-[shimmer_2.5s_infinite] bg-gradient-to-r from-transparent via-white/5 to-transparent skew-x-12" />
              <span className="w-2.5 h-2.5 rounded-full bg-[#E8C468] animate-pulse shadow-[0_0_12px_rgba(232,196,104,1)]" />
              <span className="text-xs font-black uppercase tracking-[0.25em] text-[#E8C468] drop-shadow-sm">
                {t("course.starts_in") || "Starts in"} {daysRemaining} {t("course.days") || "Days"}
              </span>
            </div>
          )}
        </div>

        {/* ── TEXT SECTION (Strict Top-to-Bottom Flow) ── */}
        <div className={`relative flex-1 flex flex-col justify-center lg:py-6 transition-opacity duration-700 ${isEnded ? 'opacity-60' : 'opacity-100'}`}>
          
          <div className="flex flex-col flex-1">
            
            {/* 1. TOP BAR: Metadata & Status */}
            <div className="flex flex-wrap items-center gap-4 mb-4">
              <div className={`inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-gradient-to-r from-white/10 to-transparent border border-white/10 backdrop-blur-md shadow-lg ${currentLevelStyle.border} transition-colors duration-500`}>
                <span className={`w-1.5 h-1.5 rounded-full animate-pulse ${currentLevelStyle.dot}`} />
                <span className={`text-[9px] font-black uppercase tracking-[0.3em] transition-colors duration-500 ${currentLevelStyle.text}`}>
                  {t(`categories.${levelCategory.toLowerCase()}`) || levelCategory}
                </span>
              </div>
              
              {isActive && (
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse shadow-[0_0_10px_rgba(52,211,153,0.8)]" />
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-emerald-400">{t("course.live_now") || "Live Now"}</span>
                </div>
              )}
            </div>

            {/* 2. CORE CONTENT: Massive Title & Description */}
            <div className="mb-6">
              <h3 
                className="pt-12 pb-4 text-3xl md:text-4xl font-bold text-white leading-[2.5] group-hover:text-[#E8C468] transition-colors duration-500 line-clamp-2" 
                style={{ fontFamily: '"Aref Ruqaa", serif' }}
              >
                {title}
              </h3>
              
              {desc && (
                <p className="text-white/50 text-sm leading-relaxed line-clamp-2 mt-3">
                  {desc}
                </p>
              )}
            </div>

            {/* 3. INFO GRID: Teacher & Date */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 mt-auto mb-6 pt-6 border-t border-white/10">
              
              {/* Instructor */}
              <div className="flex items-center gap-3">
                <Image
                  src={formatImageUrl(teacherPic) || "/images/placeholder.png"}
                  alt={teacherName}
                  width={40}
                  height={40}
                  className="w-10 h-10 rounded-full object-cover border border-white/20 grayscale group-hover:grayscale-0 transition-all duration-500"
                />
                <div className="flex flex-col">
                  <span className="text-[10px] text-white/40 font-black uppercase tracking-[0.2em]">{t("course.instructor") || "Instructor"}</span>
                  <span className="text-sm font-bold tracking-wide text-white/90 uppercase">{teacherName}</span>
                </div>
              </div>

              {/* Date / Time */}
              {course.startDate && (
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center shrink-0 border border-white/10 group-hover:border-[#E8C468]/50 transition-colors duration-500">
                    <Calendar className="w-4 h-4 text-[#E8C468]" />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-[10px] text-white/40 font-black uppercase tracking-[0.2em]">{t("course.schedule") || "Schedule"}</span>
                    <span className="text-xs font-bold tracking-wide text-white/90">
                      {new Date(course.startDate.seconds ? course.startDate.toDate() : course.startDate).toLocaleDateString(locale === 'ar' ? 'ar-EG' : 'en-US', { day: 'numeric', month: 'short' })}
                      {course.endDate && ` - ${new Date(course.endDate.seconds ? course.endDate.toDate() : course.endDate).toLocaleDateString(locale === 'ar' ? 'ar-EG' : 'en-US', { day: 'numeric', month: 'short' })}`}
                    </span>
                  </div>
                </div>
              )}

            </div>

            {/* Course Capacity (For unbought courses) */}
            {!isEnrolled && !isEnded && (course.maxStudents > 0) && (
              <div className="mb-6">
                <div className="flex items-center justify-between text-[10px] font-black uppercase tracking-[0.2em] mb-2">
                  <span className="text-white/40">{enrolledStudents.length} {t("course.enrolled") || "Enrolled"}</span>
                  <span className="text-[#E8C468]">{course.maxStudents} {t("course.max") || "Max"}</span>
                </div>
                <div className="w-full h-1 bg-white/5 rounded-full overflow-hidden">
                  <motion.div 
                    initial={{ width: 0 }}
                    whileInView={{ width: `${Math.min(100, Math.round((enrolledStudents.length / course.maxStudents) * 100))}%` }}
                    viewport={{ once: true }}
                    transition={{ duration: 1, ease: "easeOut" }}
                    className="h-full bg-gradient-to-r from-[#E8C468]/50 to-[#E8C468] rounded-full"
                  />
                </div>
              </div>
            )}

          </div>

          {/* 4. BOTTOM BAR: Price & Action */}
          <div className="flex items-end justify-between pt-6 border-t border-white/10">
            
            <div className="flex flex-col">
              {isEnrolled ? (
                <span className="text-sm font-black uppercase tracking-widest text-[#E8C468]">
                </span>
              ) : isEnded ? (
                <span className="text-sm font-black uppercase tracking-widest text-white/30">
                </span>
              ) : (
                <>
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-white/40 mb-1">{t("course.tuition", "Tuition")}</span>
                  <div className="flex items-end gap-3 group-hover:text-[#E8C468] transition-colors duration-500">
                    <span className="text-3xl md:text-4xl font-black font-outfit leading-none text-white">
                      ${(price / 2).toFixed(0)}
                    </span>
                    {price > 0 && (
                      <span className="text-[10px] md:text-xs font-bold text-white/30 line-through decoration-white/20 mb-1">
                        ${price.toFixed(0)}
                      </span>
                    )}
                  </div>
                </>
              )}
            </div>

            {/* Icon Button */}
            <div className={`w-12 h-12 md:w-14 md:h-14 rounded-full border flex items-center justify-center transition-all duration-500 shrink-0 ${
              isEnded && !isEnrolled 
                ? 'border-white/10 text-white/20 bg-white/[0.01]' 
                : 'border-white/20 text-white/50 bg-white/[0.02] group-hover:bg-[#E8C468] group-hover:text-black group-hover:border-[#E8C468]'
            }`}>
              {isEnrolled ? (
                <PlayCircle className="w-6 h-6" />
              ) : isEnded ? (
                <Lock className="w-6 h-6" />
              ) : (
                <ArrowRight className="w-6 h-6 rtl:rotate-180 group-hover:rtl:-translate-x-1 group-hover:ltr:translate-x-1 transition-transform" />
              )}
            </div>

          </div>
          
        </div>
      </motion.div>
    </Link>
  );
}
