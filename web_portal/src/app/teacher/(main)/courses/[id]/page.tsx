"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Video, Users, Star, DollarSign, Calendar, Clock,
  ChevronLeft, BookOpen, FileText, Loader2, ArrowRight
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { doc, getDoc, collection, getDocs, onSnapshot } from "firebase/firestore";
import Link from "next/link";
import Image from "next/image";
import { useParams, useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";
import { useTranslation } from "@/hooks/useTranslation";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay, ease: "easeOut" as const },
});

const formatSafe = (val: any) => {
  if (!val) return "TBA";
  if (typeof val === 'string') return val;
  if (val.toDate) return val.toDate().toLocaleDateString();
  if (val.seconds) return new Date(val.seconds * 1000).toLocaleDateString();
  return "Unknown";
};

export default function CourseStudioPage() {
  const params = useParams();
  const router = useRouter();
  const courseId = params.id as string;
  const { t } = useTranslation();

  const [course, setCourse] = useState<any>(null);
  const [assignments, setAssignments] = useState<any[]>([]);
  const [teacherCommission, setTeacherCommission] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<"overview" | "students" | "homeworks">("overview");

    useEffect(() => {
    let userUnsub: any = null;
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      try {
        const courseRef = doc(db, "courses", courseId);
        const courseSnap = await getDoc(courseRef);
        
        if (!courseSnap.exists()) {
          router.push("/teacher/courses");
          return;
        }

        const data = courseSnap.data();
        if (data.teacherId !== user.uid) {
          router.push("/teacher/courses");
          return;
        }

        const userRef = doc(db, "users", user.uid);
        userUnsub = onSnapshot(userRef, (userSnap) => {
          if (userSnap.exists()) {
            const uData = userSnap.data();
            if (uData.commissionRate !== undefined) {
              setTeacherCommission(uData.commissionRate * 100);
            } else if (uData.earningPercentage !== undefined) {
              setTeacherCommission(uData.earningPercentage);
            } else {
              setTeacherCommission(null);
            }
          } else {
            setTeacherCommission(null);
          }
        });

        setCourse({ id: courseSnap.id, ...data });

        // Fetch assignments for this course
        const assignSnap = await getDocs(collection(db, "courses", courseId, "assignments"));
        const assignList = await Promise.all(assignSnap.docs.map(async (d) => {
          const subsSnap = await getDocs(collection(db, "courses", courseId, "assignments", d.id, "submissions"));
          return {
            id: d.id,
            ...d.data(),
            submissionCount: subsSnap.size
          };
        }));
        setAssignments(assignList);

      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    });
    return () => {
      unsub();
      if (userUnsub) userUnsub();
    };
  }, [courseId, router]);

  if (loading) {
    return (
      <div className="flex h-[70vh] items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
      </div>
    );
  }

  if (!course) return null;

  const enrolled = course.enrolledStudents?.length || 0;
  const originalPrice = course.price || 0;
  const actualPrice = originalPrice / 2; // The half rule
  const revenue = teacherCommission !== null ? actualPrice * enrolled * (teacherCommission / 100) : null;
  const rating = course.rating?.toFixed(1) || "—";
  
  const bannerUrl = course.courseBanner?.startsWith("assets/") 
    ? `/${course.courseBanner}` 
    : course.courseBanner;

  return (
    <div className="space-y-8 pb-20">
      
      {/* Back Navigation */}
      <motion.div {...fadeUp(0)}>
        <Link href="/teacher/courses" className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors text-sm font-semibold mb-2">
          <ChevronLeft className="w-4 h-4" /> Back to My Courses
        </Link>
      </motion.div>

      {/* Hero Card */}
      <motion.div {...fadeUp(0.05)} className="relative rounded-3xl overflow-hidden border border-white/[0.08]"
        style={{ background: "#1A1A1A" }}>
        
        {/* Course Banner Background */}
        <div className="absolute inset-0 z-0">
          {bannerUrl && (
            <Image src={bannerUrl} alt={course.courseName || ""} fill className="object-cover opacity-30" />
          )}
          <div className="absolute inset-0 bg-gradient-to-r from-[#1A1A1A] via-[#1A1A1A]/90 to-transparent" />
          <div className="absolute inset-0 bg-gradient-to-t from-[#1A1A1A] via-transparent to-transparent" />
        </div>

        <div className="relative z-10 p-8 md:p-10 flex flex-col md:flex-row gap-8 items-start md:items-end justify-between">
          <div className="flex-1 max-w-2xl">
            <div className="flex items-center gap-2 mb-4">
              <span className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider rounded-lg" style={{ background: "rgba(212,175,55,0.15)", color: "#D4AF37" }}>
                {course.selectedCategory || t('teacher.studio.category')}
              </span>
              <span className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider rounded-lg" style={{ background: "rgba(255,255,255,0.1)", color: "rgba(255,255,255,0.6)" }}>
                {course.ageCategory || t('teacher.studio.age_group')}
              </span>
            </div>
            
            <h1 className="text-3xl md:text-5xl font-bold text-white tracking-tight mb-4 leading-tight">
              {course.courseName || course.courseTitle || "Untitled Course"}
            </h1>
            
            <div className="flex flex-wrap items-center gap-6 text-white/50 text-sm">
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4 text-white/30" />
                <span>
                  {formatSafe(course.startDate)} — {formatSafe(course.endDate)}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-white/30" />
                <span>{formatSafe(course.startTime)} - {formatSafe(course.endTime)}</span>
              </div>
            </div>
          </div>

          {/* CTA */}
          <Link href={`/teacher/courses/${course.id}/classroom`} className="shrink-0 w-full md:w-auto">
            <button className="w-full flex items-center justify-center gap-3 text-sm font-bold px-8 py-4 rounded-xl text-black transition-all hover:scale-105 shadow-2xl"
              style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)", boxShadow: "0 12px 30px rgba(212,175,55,0.3)" }}>
              <Video className="w-5 h-5 fill-black" /> {t('teacher.studio.go_live')}
            </button>
          </Link>
        </div>
      </motion.div>

      {/* Stats Row */}
      <motion.div {...fadeUp(0.1)} className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: t('teacher.studio.students_enrolled'), value: enrolled, icon: Users, color: "#60A5FA" },
          { label: t('teacher.studio.revenue'), value: revenue !== null ? `$${revenue.toLocaleString()}` : 'No Commission', icon: DollarSign, color: "#34D399" },
          { label: t('teacher.studio.price'), value: actualPrice ? `$${actualPrice}` : t('teacher.courses.free'), icon: DollarSign, color: "#D4AF37" },
          { label: t('teacher.studio.rating'), value: rating, icon: Star, color: "#A78BFA" },
        ].map(({ label, value, icon: Icon, color }, i) => (
          <div key={i} className="rounded-2xl p-5 border border-white/[0.06] flex items-center gap-4" style={{ background: "#232323" }}>
            <div className="w-12 h-12 rounded-xl flex items-center justify-center shrink-0" style={{ background: `${color}15` }}>
              <Icon className="w-6 h-6" style={{ color }} />
            </div>
            <div>
              <p className="text-2xl font-bold text-white leading-none">{value}</p>
              <p className="text-white/40 text-[11px] font-semibold uppercase tracking-wider mt-1.5">{label}</p>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Tabs Layout */}
      <motion.div {...fadeUp(0.15)} className="bg-[#232323] rounded-3xl border border-white/[0.06] overflow-hidden min-h-[400px]">
        {/* Tab Headers */}
        <div className="flex items-center gap-6 px-8 pt-6 border-b border-white/[0.06] overflow-x-auto no-scrollbar">
          {(["overview", "students", "homeworks"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className="relative pb-4 text-sm font-bold capitalize transition-colors whitespace-nowrap"
              style={{ color: activeTab === tab ? "#D4AF37" : "rgba(255,255,255,0.4)" }}
            >
              {t(`teacher.studio.tabs.${tab}`)}
              {activeTab === tab && (
                <motion.div
                  layoutId="activeTab"
                  className="absolute bottom-0 left-0 right-0 h-0.5 rounded-t-full"
                  style={{ background: "#D4AF37", boxShadow: "0 -2px 10px rgba(212,175,55,0.5)" }}
                />
              )}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <div className="p-8">
          <AnimatePresence mode="wait">
            
            {/* OVERVIEW TAB */}
            {activeTab === "overview" && (
              <motion.div key="overview"
                initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.2 }}
                className="grid md:grid-cols-2 gap-10"
              >
                <div>
                  <h3 className="text-white font-bold text-lg mb-4">{t('teacher.studio.description')}</h3>
                  <p className="text-white/50 text-sm leading-relaxed">
                    {course.courseDescription || "No description provided."}
                  </p>
                </div>
                <div className="space-y-6">
                  <div>
                    <h3 className="text-white font-bold text-lg mb-4">{t('teacher.studio.schedule')}</h3>
                    <div className="flex flex-wrap gap-2">
                      {course.selectedDays?.map((day: string, idx: number) => (
                        <span key={idx} className="px-4 py-2 rounded-xl text-xs font-bold text-white/70 border border-white/10 bg-[#1A1A1A]">
                          {day}
                        </span>
                      ))}
                    </div>
                  </div>
                  <div>
                    <h3 className="text-white font-bold text-lg mb-4">Course Details</h3>
                    <div className="space-y-3">
                      <div className="flex justify-between items-center py-2 border-b border-white/[0.05]">
                        <span className="text-white/40 text-sm">{t('teacher.studio.writing_type')}</span>
                        <span className="text-white text-sm font-semibold">{course.writingType || "—"}</span>
                      </div>
                      <div className="flex justify-between items-center py-2 border-b border-white/[0.05]">
                        <span className="text-white/40 text-sm">{t('teacher.studio.style')}</span>
                        <span className="text-white text-sm font-semibold">{course.calligraphyStyle || "—"}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {/* STUDENTS TAB */}
            {activeTab === "students" && (
              <motion.div key="students"
                initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.2 }}
              >
                {course.enrolledStudents?.length === 0 ? (
                  <div className="text-center py-16">
                    <Users className="w-12 h-12 text-white/10 mx-auto mb-4" />
                    <p className="text-white/40 font-medium">{t('teacher.studio.no_students')}</p>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {course.enrolledStudents?.map((student: any, idx: number) => (
                      <div key={idx} className="flex items-center gap-4 p-4 rounded-2xl bg-[#1A1A1A] border border-white/[0.05]">
                        <div className="w-12 h-12 rounded-full overflow-hidden bg-white/5 border border-white/10 flex items-center justify-center">
                          {student.photoUrl ? (
                            <Image src={student.photoUrl} alt={student.name || "Student"} width={48} height={48} className="object-cover" />
                          ) : (
                            <span className="text-white/30 font-bold">{student.name?.charAt(0) || "S"}</span>
                          )}
                        </div>
                        <div>
                          <p className="text-white font-bold text-sm">{student.name || "Anonymous Student"}</p>
                          <p className="text-white/30 text-xs mt-0.5">Enrolled</p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </motion.div>
            )}

            {/* HOMEWORKS TAB */}
            {activeTab === "homeworks" && (
              <motion.div key="homeworks"
                initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.2 }}
              >
                {assignments.length === 0 ? (
                  <div className="text-center py-16">
                    <FileText className="w-12 h-12 text-white/10 mx-auto mb-4" />
                    <p className="text-white/40 font-medium">{t('teacher.studio.no_homeworks')}</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {assignments.map((assignment, idx) => (
                      <div key={idx} className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] hover:border-white/10 transition-colors">
                        <div className="flex items-start gap-4">
                          <div className="w-10 h-10 rounded-xl bg-[#D4AF37]/10 flex items-center justify-center shrink-0 mt-0.5">
                            <FileText className="w-5 h-5 text-[#D4AF37]" />
                          </div>
                          <div>
                            <h3 className="text-white font-bold text-sm">{assignment.title || "Untitled Assignment"}</h3>
                            <p className="text-white/40 text-xs mt-1 line-clamp-1 max-w-lg">{assignment.description || "No description provided."}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-4 shrink-0">
                          <div className="text-right">
                            <p className="text-white font-bold text-sm">{assignment.submissionCount}</p>
                            <p className="text-white/30 text-[10px] uppercase tracking-wider font-semibold">Submissions</p>
                          </div>
                          <Link href="/teacher/homeworks">
                            <button className="w-10 h-10 rounded-xl bg-white/5 hover:bg-white/10 flex items-center justify-center transition-colors border border-white/10">
                              <ArrowRight className="w-4 h-4 text-white/70" />
                            </button>
                          </Link>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </motion.div>
            )}

          </AnimatePresence>
        </div>
      </motion.div>
    </div>
  );
}
