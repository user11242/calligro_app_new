"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import {
  BookOpen, Users, Star, Play, Video, Award, ChevronRight,
  Globe, Mail, TrendingUp, Calendar, Clock,
  CheckCircle2, Sparkles, BarChart2, Loader2, ArrowUpRight,
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { collection, query, where, getDocs, doc, getDoc } from "firebase/firestore";
import Link from "next/link";
import Image from "next/image";
import { onAuthStateChanged } from "firebase/auth";
import { format, formatDistanceToNow } from "date-fns";
import { useTranslation } from "@/hooks/useTranslation";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.45, delay, ease: "easeOut" as const },
});

export default function TeacherDashboard() {
  const [courses, setCourses] = useState<any[]>([]);
  const [teacher, setTeacher] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const { t } = useTranslation();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      try {
        const [userSnap, coursesSnap] = await Promise.all([
          getDoc(doc(db, "users", user.uid)),
          getDocs(query(collection(db, "courses"), where("teacherId", "==", user.uid))),
        ]);
        if (userSnap.exists()) setTeacher({ ...userSnap.data(), uid: user.uid });
        setCourses(coursesSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      } finally {
        setLoading(false);
      }
    });
    return () => unsub();
  }, []);

  if (loading) {
    return (
      <div className="flex h-[70vh] items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
      </div>
    );
  }

  const totalStudents = courses.reduce((a, c) => a + (c.enrolledStudents?.length || 0), 0);
  const avgRating = courses.length
    ? (courses.reduce((a, c) => a + (c.rating || 0), 0) / courses.length).toFixed(1)
    : "—";
  const totalReviews = courses.reduce((a, c) => a + (c.reviewCount || 0), 0);
  const joinedDate = teacher?.createdAt?.toDate?.();
  const joinedStr = joinedDate ? format(joinedDate, "MMMM yyyy") : "—";
  const memberFor = joinedDate ? formatDistanceToNow(joinedDate, { addSuffix: false }) : "—";
  const h = new Date().getHours();
  const greeting = h < 12 ? t('teacher.dashboard.greeting_morning') : h < 18 ? t('teacher.dashboard.greeting_afternoon') : t('teacher.dashboard.greeting_evening');
  const avatarLetter = teacher?.name?.charAt(0)?.toUpperCase() || "T";

  const stats = [
    { label: t('teacher.dashboard.stat_courses'), value: courses.length, sub: t('teacher.dashboard.stat_courses_sub'), icon: BookOpen, color: "#60A5FA", glow: "rgba(96,165,250,0.15)" },
    { label: t('teacher.dashboard.stat_students'), value: totalStudents, sub: t('teacher.dashboard.stat_students_sub'), icon: Users, color: "#34D399", glow: "rgba(52,211,153,0.15)" },
    { label: t('teacher.dashboard.stat_rating'), value: avgRating, sub: `${totalReviews} ${t('teacher.dashboard.stat_reviews')}`, icon: Star, color: "#D4AF37", glow: "rgba(212,175,55,0.15)" },
    { label: t('teacher.dashboard.stat_followers'), value: teacher?.followersCount || 0, sub: t('teacher.dashboard.stat_followers_sub'), icon: TrendingUp, color: "#A78BFA", glow: "rgba(167,139,250,0.15)" },
  ];

  return (
    <div className="space-y-8 pb-20">

      {/* ─── HERO CARD ─── */}
      <motion.div {...fadeUp(0)} className="relative rounded-3xl overflow-hidden border border-white/[0.08]"
        style={{ background: "linear-gradient(135deg, #252218 0%, #1F1F1F 60%, #1A1A1A 100%)" }}
      >
        {/* Soft gold orb */}
        <div className="absolute -top-16 -right-16 w-64 h-64 rounded-full pointer-events-none"
          style={{ background: "radial-gradient(circle, rgba(212,175,55,0.12) 0%, transparent 70%)" }} />

        <div className="relative z-10 p-8 md:p-10 flex flex-col md:flex-row gap-8 items-start md:items-center">
          {/* Avatar */}
          <div className="relative shrink-0">
            <div className="w-24 h-24 md:w-28 md:h-28 rounded-2xl overflow-hidden border border-[#D4AF37]/30 shadow-2xl"
              style={{ boxShadow: "0 0 40px rgba(212,175,55,0.15)" }}>
              {teacher?.photoUrl
                ? <Image src={teacher.photoUrl} alt="Profile" fill className="object-cover" />
                : (
                  <div className="w-full h-full flex items-center justify-center"
                    style={{ background: "linear-gradient(135deg, rgba(212,175,55,0.2), rgba(212,175,55,0.05))" }}>
                    <span className="text-4xl font-black text-[#D4AF37]">{avatarLetter}</span>
                  </div>
                )
              }
            </div>
            <div className="absolute -bottom-1.5 -right-1.5 flex items-center gap-1 px-2.5 py-1 rounded-full border border-white/10"
              style={{ background: "#1F1F1F" }}>
              <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="text-[9px] font-bold text-emerald-400 tracking-widest uppercase">{t('teacher.dashboard.live')}</span>
            </div>
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <div className="flex flex-wrap items-center gap-3 mb-2">
              <h1 className="text-2xl md:text-3xl font-bold text-white tracking-tight">
                {greeting}, {teacher?.name?.split(" ")[0] || t('teacher.dashboard.teacher')} 👋
              </h1>
              <span className="flex items-center gap-1.5 text-[10px] font-bold tracking-widest uppercase px-3 py-1.5 rounded-full border"
                style={{ color: "#D4AF37", background: "rgba(212,175,55,0.1)", borderColor: "rgba(212,175,55,0.2)" }}>
                <CheckCircle2 className="w-3 h-3" /> {t('teacher.dashboard.verified')}
              </span>
            </div>
            <p className="text-white/40 text-sm mb-5 leading-relaxed max-w-lg">
              {teacher?.bio || t('teacher.dashboard.subtitle')}
            </p>

            <div className="flex flex-wrap gap-x-6 gap-y-2">
              {teacher?.spokenLanguages?.length > 0 && (
                <div className="flex items-center gap-2 text-white/35 text-xs">
                  <Globe className="w-3.5 h-3.5" />
                  <span>{teacher.spokenLanguages.join(", ")}</span>
                </div>
              )}
              {teacher?.email && (
                <div className="flex items-center gap-2 text-white/35 text-xs">
                  <Mail className="w-3.5 h-3.5" />
                  <span>{teacher.email}</span>
                </div>
              )}
              <div className="flex items-center gap-2 text-white/35 text-xs">
                <Calendar className="w-3.5 h-3.5" />
                <span>{t('teacher.dashboard.joined')} <span className="text-white/60 font-semibold">{joinedStr}</span></span>
              </div>
              <div className="flex items-center gap-2 text-white/35 text-xs">
                <Clock className="w-3.5 h-3.5" />
                <span><span className="text-white/60 font-semibold">{memberFor}</span> {t('teacher.dashboard.member_for')}</span>
              </div>
            </div>
          </div>

          {/* CTA */}
          <Link href="/teacher/courses" className="shrink-0">
            <button className="flex items-center gap-2.5 text-sm font-bold px-6 py-3.5 rounded-xl transition-all duration-200 text-black"
              style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)", boxShadow: "0 8px 24px rgba(212,175,55,0.25)" }}
              onMouseEnter={e => (e.currentTarget.style.transform = "scale(1.02)")}
              onMouseLeave={e => (e.currentTarget.style.transform = "scale(1)")}>
              <Play className="w-4 h-4 fill-black" /> {t('teacher.dashboard.start_live')}
            </button>
          </Link>
        </div>
      </motion.div>

      {/* ─── STATS ─── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map(({ label, value, sub, icon: Icon, color, glow }, i) => (
          <motion.div key={label} {...fadeUp(0.05 + i * 0.05)}
            className="relative rounded-2xl p-5 border border-white/[0.06] hover:border-white/10 transition-all duration-300 overflow-hidden group"
            style={{ background: "#232323" }}
          >
            <div className="absolute -top-8 -right-8 w-28 h-28 rounded-full blur-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500"
              style={{ background: glow }} />
            <div className="relative z-10">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center mb-4"
                style={{ background: glow, border: `1px solid ${color}20` }}>
                <Icon className="w-5 h-5" style={{ color }} />
              </div>
              <p className="text-2xl font-bold text-white tracking-tight">{value}</p>
              <p className="text-white/45 text-sm font-medium mt-0.5">{label}</p>
              {sub && <p className="text-white/20 text-[10px] mt-1">{sub}</p>}
            </div>
          </motion.div>
        ))}
      </div>

      {/* ─── COURSES ─── */}
      <motion.section {...fadeUp(0.25)}>
        <div className="flex items-end justify-between mb-5">
          <div>
            <h2 className="text-lg font-bold text-white">{t('teacher.dashboard.courses_title')}</h2>
            <p className="text-white/35 text-sm mt-0.5">{courses.length} {t('teacher.dashboard.stat_courses_sub')}</p>
          </div>
          <Link href="/teacher/courses" className="flex items-center gap-1.5 text-sm font-semibold transition-colors" style={{ color: "#D4AF37" }}>
            {t('teacher.dashboard.courses_view_all')} <ArrowUpRight className="w-4 h-4" />
          </Link>
        </div>

        {courses.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-white/10 p-14 text-center" style={{ background: "#232323" }}>
            <div className="w-14 h-14 rounded-xl bg-white/5 flex items-center justify-center mx-auto mb-5">
              <BookOpen className="w-7 h-7 text-white/15" />
            </div>
            <p className="text-white font-semibold mb-2">{t('teacher.dashboard.no_courses')}</p>
            <p className="text-white/35 text-sm max-w-xs mx-auto leading-relaxed">
              {t('teacher.dashboard.no_courses_desc')}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {courses.slice(0, 6).map((course, idx) => {
              const enrolled = course.enrolledStudents?.length || 0;
              return (
                <motion.div key={course.id} {...fadeUp(0.05 * idx)}
                  className="group rounded-2xl overflow-hidden border border-white/[0.06] hover:border-[#D4AF37]/20 transition-all duration-300 hover:-translate-y-0.5"
                  style={{ background: "#232323" }}
                >
                  <div className="relative h-44 bg-[#1A1A1A] overflow-hidden">
                    {course.courseBanner
                      ? <Image src={course.courseBanner.startsWith("assets/") ? `/${course.courseBanner}` : course.courseBanner} alt={course.courseName || ""} fill className="object-cover group-hover:scale-105 transition-transform duration-500" />
                      : <div className="absolute inset-0 flex items-center justify-center"><BookOpen className="w-10 h-10 text-white/10" /></div>
                    }
                    <div className="absolute inset-0 bg-gradient-to-t from-[#232323] via-transparent to-transparent" />
                    <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-300 bg-black/50 backdrop-blur-sm">
                      <Link href={`/teacher/courses/${course.id}`}>
                        <button className="flex items-center gap-2 text-sm font-bold px-5 py-2.5 rounded-xl text-black transition-all hover:scale-105"
                          style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}>
                          <Play className="w-4 h-4 fill-black" /> {t('teacher.dashboard.open_studio')}
                        </button>
                      </Link>
                    </div>
                    <div className="absolute top-3 left-3 text-white text-xs font-bold px-2.5 py-1 rounded-lg border border-white/10 backdrop-blur-sm"
                      style={{ background: "rgba(0,0,0,0.6)" }}>
                      {course.price ? `$${course.price}` : t('teacher.dashboard.free')}
                    </div>
                    <div className="absolute top-3 right-3 flex items-center gap-1.5 text-white text-xs font-medium px-2.5 py-1 rounded-lg border border-white/10 backdrop-blur-sm"
                      style={{ background: "rgba(0,0,0,0.6)" }}>
                      <Users className="w-3 h-3" />{enrolled}
                    </div>
                  </div>
                  <div className="p-5">
                    <h3 className="text-white font-semibold text-sm leading-snug line-clamp-1 mb-3">
                      {course.courseName || course.courseTitle || "Untitled Course"}
                    </h3>
                    <div className="mb-3">
                      <div className="h-1 bg-white/5 rounded-full overflow-hidden">
                        <div className="h-full rounded-full" style={{
                          width: course.maxStudents ? `${Math.min((enrolled / course.maxStudents) * 100, 100)}%` : "15%",
                          background: "linear-gradient(90deg, #D4AF37, #E0C17E)",
                        }} />
                      </div>
                    </div>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-1 text-xs" style={{ color: "#D4AF37" }}>
                        <Star className="w-3.5 h-3.5" style={{ fill: "#D4AF37" }} />
                        <span className="font-bold">{course.rating?.toFixed(1) || "—"}</span>
                        <span className="text-white/25">({course.reviewCount || 0})</span>
                      </div>
                      <Link href={`/teacher/courses/${course.id}`} className="flex items-center gap-1 text-white/35 hover:text-white text-xs font-semibold transition-colors">
                        {t('teacher.dashboard.manage')} <ChevronRight className="w-3.5 h-3.5" />
                      </Link>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>
        )}
      </motion.section>

      {/* ─── BOTTOM GRID ─── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Quick Actions */}
        <motion.div {...fadeUp(0.3)} className="lg:col-span-2 rounded-2xl border border-white/[0.06] p-6" style={{ background: "#232323" }}>
          <div className="flex items-center gap-2 mb-5">
            <BarChart2 className="w-5 h-5" style={{ color: "#D4AF37" }} />
            <h2 className="text-base font-bold text-white">{t('teacher.dashboard.quick_actions')}</h2>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              { label: t('teacher.dashboard.action_courses'), desc: t('teacher.dashboard.action_courses_desc'), icon: BookOpen, href: "/teacher/courses", color: "#60A5FA", glow: "rgba(96,165,250,0.1)" },
              { label: t('teacher.dashboard.action_homework'), desc: t('teacher.dashboard.action_homework_desc'), icon: Award, href: "/teacher/homeworks", color: "#D4AF37", glow: "rgba(212,175,55,0.1)" },
              { label: t('teacher.dashboard.action_live'), desc: t('teacher.dashboard.action_live_desc'), icon: Video, href: "/teacher/courses", color: "#34D399", glow: "rgba(52,211,153,0.1)" },
            ].map(({ label, desc, icon: Icon, href, color, glow }) => (
              <Link key={label} href={href}>
                <div className="p-4 rounded-xl border border-white/[0.05] hover:border-white/10 transition-all cursor-pointer h-full"
                  style={{ background: "rgba(255,255,255,0.02)" }}>
                  <div className="w-9 h-9 rounded-xl flex items-center justify-center mb-3" style={{ background: glow }}>
                    <Icon className="w-4 h-4" style={{ color }} />
                  </div>
                  <p className="text-white text-sm font-semibold mb-0.5">{label}</p>
                  <p className="text-white/30 text-xs leading-relaxed">{desc}</p>
                </div>
              </Link>
            ))}
          </div>
        </motion.div>

        {/* Tips */}
        <motion.div {...fadeUp(0.35)} className="rounded-2xl border p-6 relative overflow-hidden"
          style={{ background: "linear-gradient(135deg, #252218, #1F1F1F)", borderColor: "rgba(212,175,55,0.15)" }}>
          <div className="absolute -bottom-10 -right-10 w-48 h-48 rounded-full blur-3xl pointer-events-none"
            style={{ background: "radial-gradient(circle, rgba(212,175,55,0.08) 0%, transparent 70%)" }} />
          <div className="flex items-center gap-2 mb-5">
            <Sparkles className="w-5 h-5" style={{ color: "#D4AF37" }} />
            <h2 className="text-base font-bold text-white">{t('teacher.dashboard.tips_title')}</h2>
          </div>
          <ul className="space-y-4">
            {[
              t('teacher.dashboard.tip_1'),
              t('teacher.dashboard.tip_2'),
              t('teacher.dashboard.tip_3'),
            ].map((tip, i) => (
              <li key={i} className="flex items-start gap-3 text-xs text-white/40 leading-relaxed">
                <span className="w-5 h-5 rounded-full text-[10px] font-bold flex items-center justify-center shrink-0 mt-0.5"
                  style={{ background: "rgba(212,175,55,0.15)", color: "#D4AF37" }}>{i + 1}</span>
                {tip}
              </li>
            ))}
          </ul>
        </motion.div>
      </div>
    </div>
  );
}
