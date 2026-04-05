"use client";
import { motion } from "framer-motion";
import { Users, Star, Clock, Calendar, CheckCircle2, ChevronRight } from "lucide-react";
import Link from "next/link";
import { formatImageUrl } from "@/lib/utils";
import AutoTranslatedText from "./AutoTranslatedText";
import { auth } from "@/lib/firebase";

interface CourseCardProps {
  course: any;
}

export default function CourseCard({ course }: CourseCardProps) {
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
  const sessionDaysFormatted = sessionDays.join(", ");

  const enrollmentProgress = maxStudents > 0 ? (currentEnrollment / maxStudents) * 100 : 0;
  const isUrgent = maxStudents > 0 && (maxStudents - currentEnrollment) <= 3;

  return (
    <motion.div
      whileHover={{ y: -8 }}
      className="relative h-[380px] rounded-[32px] overflow-hidden group shadow-2xl bg-secondary-dark border border-white/5"
    >
      <Link href={`/courses/${course.id}`}>
        {/* Background Image */}
        <div className="absolute inset-0">
          <img 
            src={formatImageUrl(course.courseBanner)} 
            alt={title}
            className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
          />
          {/* Deep Gradient Overlay */}
          <div className="absolute inset-0 bg-gradient-to-b from-black/20 via-black/40 to-black/95" />
        </div>

        {/* Top Badges */}
        <div className="absolute top-5 left-5 right-5 flex justify-between items-start z-10">
          <div className="glass px-4 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-widest border-white/10">
            <AutoTranslatedText text={level} />
          </div>
          {isEnrolled ? (
            <div className="bg-green-500 text-white px-4 py-1.5 rounded-xl text-xs font-black shadow-lg flex items-center gap-1.5 animate-pulse">
              <CheckCircle2 className="w-3.5 h-3.5" />
              <AutoTranslatedText text="JOINED" />
            </div>
          ) : (
            <div className="bg-primary text-secondary-dark px-4 py-1.5 rounded-xl text-sm font-black shadow-lg">
              ${price.toFixed(0)}
            </div>
          )}
        </div>

        {/* Content Overlay */}
        <div className="absolute inset-x-0 bottom-0 p-6 z-10">
          <div className="glass rounded-[24px] p-5 border-white/10 backdrop-blur-2xl bg-white/5 space-y-4">
            
            <h3 className="text-xl font-black font-outfit text-white leading-tight line-clamp-2 group-hover:text-primary transition-colors">
              <AutoTranslatedText text={title} />
            </h3>

            {/* Info Pills */}
            <div className="flex flex-wrap gap-2">
              {daysRemaining !== null && (
                <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary/20 text-primary border border-primary/20">
                  <Clock className="w-3 h-3" />
                  <span className="text-[10px] font-black uppercase flex gap-1">
                    <AutoTranslatedText text="Starts in" /> {daysRemaining} <AutoTranslatedText text="Days" />
                  </span>
                </div>
              )}
              {sessionDays.length > 0 && (
                <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary/10 text-primary border border-primary/10">
                  <Clock className="w-3 h-3" />
                  <span className="text-[10px] font-black uppercase">
                    <AutoTranslatedText text={sessionDaysFormatted} />
                  </span>
                </div>
              )}
              {course.startDate && (
                <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/5 text-white/50 border border-white/10">
                  <Calendar className="w-3 h-3" />
                  <span className="text-[10px] font-black uppercase">
                    {course.startDate.toDate ? course.startDate.toDate().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ""}
                  </span>
                </div>
              )}
            </div>

            {/* Instructor & Progress */}
            <div className="flex items-center justify-between pt-2">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full border-2 border-primary/30 p-0.5 overflow-hidden">
                  <img src={formatImageUrl(teacherPic)} alt={teacherName} className="w-full h-full object-cover rounded-full" />
                </div>
                <div>
                  <p className="text-[8px] text-primary font-black uppercase tracking-widest">
                    <AutoTranslatedText text="Master" />
                  </p>
                  <p className="text-sm font-bold text-white leading-none">
                    <AutoTranslatedText text={teacherName} />
                  </p>
                </div>
              </div>

              {/* Enrollment Bar */}
              <div className="flex flex-col items-end gap-1.5">
                <div className="flex items-center gap-2">
                  <Users className={`w-3.5 h-3.5 ${isUrgent ? 'text-red-500' : 'text-primary'}`} />
                  <span className="text-xs font-black text-white">{currentEnrollment}/{maxStudents}</span>
                </div>
                <div className="w-20 h-1 bg-white/10 rounded-full overflow-hidden">
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
      </Link>
    </motion.div>
  );
}
