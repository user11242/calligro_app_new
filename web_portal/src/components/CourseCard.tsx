"use client";
import { motion } from "framer-motion";
import { Users, Star, Clock, Calendar, CheckCircle2, ChevronRight } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { formatImageUrl } from "@/lib/utils";
import AutoTranslatedText from "./AutoTranslatedText";
import { auth } from "@/lib/firebase";
import { useTranslation } from "@/hooks/useTranslation";

interface CourseCardProps {
  course: any;
}

export default function CourseCard({ course }: CourseCardProps) {
  const { t } = useTranslation();
  const title = course.courseName || course.courseTitle || "Untitled Course";
  const teacherName = course.teacherName || "Master Instructor";
  const teacherPic = course.teacherProfilePic || "";
  const level = course.selectedCategory || "Beginner";
  const price = Number(course.price || 0);
  const enrolledStudents = course.enrolledStudents || [];
  const currentEnrollment = enrolledStudents.length;
  const maxStudents = Number(course.maxStudents || 0);
  
  // Countdown Logic
  let daysRemaining: number | null = null;
  if (course.startDate) {
    const start = course.startDate.toDate ? course.startDate.toDate() : new Date(course.startDate);
    const now = new Date();
    const diff = Math.ceil((start.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    if (diff >= 0) daysRemaining = diff;
  }

  const currentUser = auth.currentUser;
  const isEnrolled = currentUser && enrolledStudents.includes(currentUser.uid);

  // Session Days Logic
  const sessionDays = course.selectedDays || [];
  const sessionDaysFormatted = sessionDays
    .map((day: string) => t(`days.${day.toLowerCase()}`))
    .join(", ");

  const enrollmentProgress = maxStudents > 0 ? (currentEnrollment / maxStudents) * 100 : 0;
  const isUrgent = maxStudents > 0 && (maxStudents - currentEnrollment) <= 3;

  return (
    <motion.div
      whileHover={{ y: -16, scale: 1.02 }}
      transition={{ type: "spring", stiffness: 260, damping: 20 }}
      className="relative h-[500px] group"
    >
      <Link href={`/courses/${course.id}`}>
        {/* Inner Bordered Card with Media */}
        <div className="absolute inset-0 rounded-[48px] overflow-hidden bg-[#050505] border border-white/10 shadow-[0_32px_64px_-16px_rgba(0,0,0,0.5)] z-0">
          <Image 
            src={formatImageUrl(course.courseBanner) || "/images/placeholder.png"} 
            alt={title}
            fill
            className="object-cover transition-transform duration-[2500ms] group-hover:scale-110 ease-out"
            priority={false}
          />
          {/* Multi-layered Gradients for Modern Depth */}
          <div className="absolute inset-0 bg-gradient-to-t from-black via-black/80 to-transparent opacity-95" />
          <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-transparent to-transparent opacity-40 group-hover:opacity-60 transition-opacity" />
        </div>

        {/* Floating Header Badges - High-end Synthesis */}
        <div className="absolute -top-6 left-8 right-8 flex justify-between items-start z-10">
          
          {/* Right Block (Physical Right in RTL): The Boutique Hanging Tag */}
          <div className="relative group/tag">
            {/* The "String Loop" */}
            <div className="absolute -top-1 left-1/2 -translate-x-1/2 w-6 h-10 border border-white/40 rounded-full" />
            
            <div className="relative mt-8 bg-primary text-black font-black text-[12px] px-2.5 py-4 flex flex-col items-center justify-center shadow-2xl transform rotate-12 transition-all duration-500 group-hover:rotate-0 origin-top rounded-b-lg rounded-t-sm">
              <div className="w-1.5 h-1.5 rounded-full bg-black/20 mb-2 border border-black/10" />
              <span className="[writing-mode:vertical-lr] rotate-180 tracking-[0.2em] whitespace-nowrap">OFF 50%</span>
            </div>
          </div>

          {/* Left Block (Physical Left in RTL): Level & Price Stack */}
          <div className="flex flex-col items-start gap-4 pt-10">
            <div className="bg-white/10 backdrop-blur-xl border border-white/20 px-5 py-2 rounded-2xl shadow-xl">
              <span className="text-[10px] font-black uppercase tracking-[0.15em] text-white/90">
                <AutoTranslatedText text={level} />
              </span>
            </div>

            <div className="flex flex-col mt-2">
              <div className="relative w-fit mb-1">
                <span className="text-white/20 text-[10px] font-black font-outfit tracking-tighter uppercase whitespace-nowrap">
                  ${price.toFixed(0)}
                </span>
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="w-full h-[1px] bg-primary/40 -rotate-[12deg] scale-x-110" />
                </div>
              </div>
              
              {/* Yellow Price Badge */}
              <div className="bg-primary px-4 py-1.5 rounded-full shadow-[0_10px_20px_rgba(0,0,0,0.4)] flex items-center gap-1 group-hover:scale-105 transition-transform">
                <span className="text-black text-xs font-black  mt-0.5">$</span>
                <span className="text-black text-3xl font-black font-outfit tracking-tighter leading-none">
                  {(price / 2).toFixed(0)}
                </span>
              </div>
            </div>
          </div>

        </div>

        {/* Main Content Card (Floating Glass) */}
        <div className="absolute inset-x-6 bottom-6 z-10">
          <div className="bg-white/[0.03] backdrop-blur-[40px] rounded-[40px] p-7 border border-white/10 shadow-2xl space-y-6 group-hover:bg-white/[0.07] transition-all duration-700">
            
            <div className="space-y-3">
              <h3 className="text-2xl font-bold font-outfit text-white leading-[1.1] line-clamp-2 transition-colors duration-500 group-hover:text-primary">
                <AutoTranslatedText text={title} />
              </h3>

            {/* "Wow UI" Info Capsule Row - Upscaled & Tighter */}
            <div className="flex items-center gap-1.5 mx-auto w-fit bg-white/[0.05] backdrop-blur-3xl border border-white/10 rounded-full p-1 shadow-inner group/info">
              {daysRemaining !== null && (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-primary/20 border border-primary/30 rounded-full shadow-[0_0_15px_rgba(238,229,147,0.2)] animate-pulse transition-all group-hover/info:scale-105">
                  <Clock className="w-3.5 h-3.5 text-primary" />
                  <span className="text-[11px] font-black uppercase tracking-tighter text-primary leading-none whitespace-nowrap shrink-0">
                    {t("course.starts_in")} {daysRemaining} {t("course.days")}
                  </span>
                </div>
              )}
              {daysRemaining !== null && <div className="w-[1px] h-3 bg-white/10" />}
              <div className="flex items-center gap-2 px-3 py-1.5 transition-all group-hover/info:translate-x-1 shrink-0">
                <Calendar className="w-3.5 h-3.5 text-white/60" />
                <span className="text-[11px] font-black uppercase tracking-tighter text-white/60 leading-none truncate max-w-[150px] whitespace-nowrap shrink-0">
                  {sessionDaysFormatted}
                </span>
              </div>
            </div>
            </div>

            <div className="h-px w-full bg-gradient-to-r from-transparent via-white/10 to-transparent" />

            {/* Teacher & Enrollment Footnote */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="relative">
                  <div className="w-14 h-14 rounded-full overflow-hidden border-2 border-white/20 p-0.5 group-hover:border-primary/40 transition-colors shadow-lg">
                    <Image 
                      src={formatImageUrl(teacherPic) || "/images/placeholder.png"} 
                      alt={teacherName} 
                      width={56}
                      height={56}
                      className="w-full h-full object-cover rounded-full grayscale-[50%] group-hover:grayscale-0 transition-all duration-700" 
                    />
                  </div>
                  <div className="absolute -bottom-0.5 -right-0.5 bg-primary text-black p-1 rounded-full shadow-lg">
                    <CheckCircle2 className="w-3 h-3" />
                  </div>
                </div>
                <div>
                  <p className="text-base font-bold text-white leading-tight">{teacherName}</p>
                </div>
              </div>

              {/* Compact Enrollment Progress */}
              <div className="flex flex-col items-end gap-1.5">
                <div className="flex items-center gap-1.5 group-hover:scale-110 transition-transform">
                  <Users className={`w-3.5 h-3.5 ${isUrgent ? 'text-red-400' : 'text-primary/60'}`} />
                  <span className="text-xs font-black text-white">{currentEnrollment}/{maxStudents}</span>
                </div>
                <div className="w-16 h-1 bg-white/5 rounded-full overflow-hidden">
                  <motion.div 
                    initial={{ width: 0 }}
                    animate={{ width: `${enrollmentProgress}%` }}
                    className={`h-full ${isUrgent ? 'bg-red-500' : 'bg-primary'}`}
                  />
                </div>
              </div>
            </div>

          </div>
        </div>
        
        {/* Edge Glow Overlay */}
        <div className="absolute inset-0 border border-white/5 group-hover:border-primary/20 rounded-[48px] transition-colors pointer-events-none" />
      </Link>
    </motion.div>
  );
}
