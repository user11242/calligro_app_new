"use client";
import { motion } from "framer-motion";
import { ArrowRight, PlayCircle, Lock, Calendar, Clock } from "lucide-react";
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

  useEffect(() => {
    setTitle(rawTitle);
    if (locale !== "ar" && rawTitle) {
      translateText(rawTitle, locale, "ar").then(setTitle);
    }
  }, [rawTitle, locale]);

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

  return (
    <Link href={isEnrolled ? `/courses/${course.id}/classroom` : `/courses/${course.id}`} className="block w-full outline-none">
      <motion.div
        whileHover={{ y: -4 }}
        transition={{ type: "spring", stiffness: 400, damping: 30 }}
        className="group relative flex flex-col lg:flex-row w-full gap-8 md:gap-10 p-4 md:p-6 lg:p-8 -mx-4 md:-mx-6 lg:-mx-8 rounded-[40px] transition-colors duration-500 hover:bg-white/[0.02]"
      >
        
        {/* ── CLEAN IMAGE SECTION ── */}
        <div className="relative w-full lg:w-[45%] h-[240px] md:h-[280px] shrink-0 rounded-[32px] overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.5)] border border-white/5">
          <Image
            src={formatImageUrl(course.courseBanner) || "/images/placeholder.png"}
            alt={title}
            fill
            className={`object-cover transition-transform duration-[2000ms] ease-out group-hover:scale-110 ${
              isEnded ? "grayscale opacity-50" : "opacity-90"
            }`}
          />
          
          <div className="absolute inset-0 bg-gradient-to-t from-black via-black/10 to-transparent opacity-60" />
          <div className="absolute inset-0 bg-black/10 group-hover:bg-black/0 transition-colors duration-700" />

          {/* 3D Physical Ribbon 50% Off Tag (The only overlay kept for clarity) */}
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

        {/* ── TEXT SECTION (Strict Top-to-Bottom Flow) ── */}
        <div className="relative flex-1 flex flex-col justify-center lg:py-6">
          
          <div className="flex flex-col flex-1">
            
            {/* 1. TOP BAR: Metadata & Status */}
            <div className="flex flex-wrap items-center gap-4 mb-4">
              <span className="text-[10px] font-black uppercase tracking-widest text-[#E8C468] border border-[#E8C468]/30 bg-[#E8C468]/10 px-3 py-1 rounded-full">
                {course.selectedCategory || "Beginner"}
              </span>
              
              {isActive && (
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse shadow-[0_0_10px_rgba(52,211,153,0.8)]" />
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-emerald-400">Live Now</span>
                </div>
              )}
              {isUpcoming && daysRemaining !== null && (
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-[#E8C468] shadow-[0_0_10px_rgba(232,196,104,0.8)]" />
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-[#E8C468]">{t("course.starts_in") || "Starts in"} {daysRemaining} {t("course.days") || "Days"}</span>
                </div>
              )}
              {isEnrolled && (
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-[#E8C468] shadow-[0_0_10px_rgba(232,196,104,0.8)]" />
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-[#E8C468]">Owned</span>
                </div>
              )}
              {isEnded && (
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-red-400" />
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-red-400">Closed</span>
                </div>
              )}
            </div>

            {/* 2. CORE CONTENT: Massive Title & Description */}
            <div className="mb-6">
              <h3 
                className="text-3xl md:text-4xl font-bold text-white leading-[1.5] group-hover:text-[#E8C468] transition-colors duration-500 line-clamp-2" 
                style={{ fontFamily: '"Aref Ruqaa", serif' }}
              >
                {title}
              </h3>
              
              {course.courseDescription && (
                <p className="text-white/50 text-sm leading-relaxed line-clamp-2 mt-3">
                  {course.courseDescription}
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

          </div>

          {/* 4. BOTTOM BAR: Price & Action */}
          <div className="flex items-end justify-between pt-6 border-t border-white/10">
            
            <div className="flex flex-col">
              {isEnrolled ? (
                <span className="text-sm font-black uppercase tracking-widest text-[#E8C468]">
                  {t("course.access_course") || "Access Course"}
                </span>
              ) : isEnded ? (
                <span className="text-sm font-black uppercase tracking-widest text-white/30">
                  {t("course.enrollment_closed") || "Enrollment Closed"}
                </span>
              ) : (
                <>
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-white/40 mb-1">{t("course.tuition") || "Tuition"}</span>
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
            <div className="w-12 h-12 md:w-14 md:h-14 rounded-full border border-white/20 flex items-center justify-center text-white/50 bg-white/[0.02] group-hover:bg-[#E8C468] group-hover:text-black group-hover:border-[#E8C468] transition-all duration-500 shrink-0">
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
