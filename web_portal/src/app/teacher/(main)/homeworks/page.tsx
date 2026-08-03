"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  CheckSquare, Loader2, Clock, CheckCircle2, XCircle, ChevronDown,
  Users, BookOpen, FileText, Image as ImageIcon, ExternalLink, Award,
  AlertCircle, Search
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { collection, query, where, getDocs, collectionGroup, doc, updateDoc } from "firebase/firestore";
import Image from "next/image";
import { onAuthStateChanged } from "firebase/auth";
import { format } from "date-fns";
import { useTranslation } from "@/hooks/useTranslation";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay, ease: [0.22, 1, 0.36, 1] },
});

type Status = "all" | "submitted" | "graded" | "rejected";



export default function TeacherHomeworksPage() {
  const [assignments, setAssignments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<Status>("all");
  const [search, setSearch] = useState("");
  const [expanded, setExpanded] = useState<string | null>(null);
  const [grading, setGrading] = useState<{ [key: string]: { points: string; feedback: string } }>({});
  const [saving, setSaving] = useState<string | null>(null);
  const { t } = useTranslation();

  const STATUS_META: Record<string, { label: string; color: string; bg: string; icon: any }> = {
    submitted: { label: t('teacher.hw.status_pending'), color: "#FBBF24", bg: "rgba(251,191,36,0.1)", icon: Clock },
    graded: { label: t('teacher.hw.status_graded'), color: "#34D399", bg: "rgba(52,211,153,0.1)", icon: CheckCircle2 },
    rejected: { label: t('teacher.hw.status_returned'), color: "#F87171", bg: "rgba(248,113,113,0.1)", icon: XCircle },
  };

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      try {
        // Get teacher's courses
        const coursesSnap = await getDocs(
          query(collection(db, "courses"), where("teacherId", "==", user.uid))
        );
        const courseList = coursesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        // For each course, get all assignments and their submissions
        const allAssignments: any[] = [];
        for (const course of courseList) {
          const assignmentsSnap = await getDocs(
            collection(db, "courses", course.id, "assignments")
          );
          for (const assignDoc of assignmentsSnap.docs) {
            const submissionsSnap = await getDocs(
              collection(db, "courses", course.id, "assignments", assignDoc.id, "submissions")
            );
            const submissions = submissionsSnap.docs.map(s => ({ id: s.id, ...s.data() }));
            if (submissions.length > 0) {
              allAssignments.push({
                id: assignDoc.id,
                courseId: course.id,
                courseName: course.courseName || course.courseTitle || "Untitled Course",
                ...assignDoc.data(),
                submissions,
              });
            }
          }
        }
        setAssignments(allAssignments);
      } finally {
        setLoading(false);
      }
    });
    return () => unsub();
  }, []);

  const handleGrade = async (courseId: string, assignmentId: string, studentId: string, status: "graded" | "rejected") => {
    const key = `${assignmentId}-${studentId}`;
    setSaving(key);
    try {
      const submissionRef = doc(db, "courses", courseId, "assignments", assignmentId, "submissions", studentId);
      await updateDoc(submissionRef, {
        status,
        points: parseInt(grading[key]?.points || "0"),
        feedback: grading[key]?.feedback || "",
        gradedAt: new Date(),
      });
      // Refresh
      setAssignments(prev => prev.map(a => {
        if (a.id !== assignmentId) return a;
        return {
          ...a,
          submissions: a.submissions.map((s: any) =>
            s.id === studentId
              ? { ...s, status, points: parseInt(grading[key]?.points || "0"), feedback: grading[key]?.feedback || "" }
              : s
          ),
        };
      }));
    } finally {
      setSaving(null);
    }
  };

  if (loading) {
    return (
      <div className="flex h-[70vh] items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
      </div>
    );
  }

  const pendingCount = assignments.reduce((a, asgn) =>
    a + asgn.submissions.filter((s: any) => s.status === "submitted" || !s.status).length, 0);
  const gradedCount = assignments.reduce((a, asgn) =>
    a + asgn.submissions.filter((s: any) => s.status === "graded").length, 0);
  const totalCount = assignments.reduce((a, asgn) => a + asgn.submissions.length, 0);

  const filteredAssignments = assignments.filter(a => {
    if (search) {
      const q = search.toLowerCase();
      if (!(a.courseName || "").toLowerCase().includes(q) && !(a.title || "").toLowerCase().includes(q)) return false;
    }
    if (filter === "all") return true;
    return a.submissions.some((s: any) => {
      if (filter === "submitted") return s.status === "submitted" || !s.status;
      return s.status === filter;
    });
  });

  return (
    <div className="space-y-8 pb-20">

      {/* Header */}
      <motion.div {...fadeUp(0)}>
        <p className="text-white/35 text-sm font-medium mb-1">{t('teacher.studio')}</p>
        <h1 className="text-3xl md:text-4xl font-bold text-white tracking-tight">{t('teacher.hw.title')}</h1>
        <p className="text-white/35 text-sm mt-2">{t('teacher.hw.subtitle')}</p>
      </motion.div>

      {/* Stats */}
      <motion.div {...fadeUp(0.05)} className="grid grid-cols-3 gap-4">
        {[
          { label: t('teacher.hw.pending'), value: pendingCount, color: "#FBBF24", glow: "rgba(251,191,36,0.1)" },
          { label: t('teacher.hw.graded'), value: gradedCount, color: "#34D399", glow: "rgba(52,211,153,0.1)" },
          { label: t('teacher.hw.total'), value: totalCount, color: "#A78BFA", glow: "rgba(167,139,250,0.1)" },
        ].map(({ label, value, color, glow }) => (
          <div key={label} className="rounded-2xl p-5 border border-white/[0.06]" style={{ background: "#232323" }}>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-white/40 text-xs font-medium mt-1">{label}</p>
            <div className="h-0.5 rounded-full mt-3 w-8" style={{ background: color }} />
          </div>
        ))}
      </motion.div>

      {/* Filters + Search */}
      <motion.div {...fadeUp(0.1)} className="flex flex-wrap items-center gap-3">
        {/* Search */}
        <div className="relative flex-1 min-w-[200px] max-w-xs">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
          <input
            type="text"
            placeholder={t('teacher.hw.search')}
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full bg-[#232323] border border-white/[0.08] rounded-xl pl-10 pr-4 py-3 text-sm text-white placeholder-white/25 outline-none focus:border-[#D4AF37]/40 transition-colors"
          />
        </div>
        {/* Status Filters */}
        <div className="flex gap-2">
          {(["all", "submitted", "graded", "rejected"] as Status[]).map(f => (
            <button key={f}
              onClick={() => setFilter(f)}
              className="px-4 py-2.5 rounded-xl text-xs font-bold transition-all capitalize"
              style={filter === f
                ? { background: "#D4AF37", color: "#000" }
                : { background: "#232323", color: "rgba(255,255,255,0.35)", border: "1px solid rgba(255,255,255,0.08)" }
              }
            >{f === "all" ? t('teacher.hw.filter_all') : f === "submitted" ? t('teacher.hw.filter_pending') : f === "graded" ? t('teacher.hw.filter_graded') : t('teacher.hw.filter_returned')}</button>
          ))}
        </div>
      </motion.div>

      {/* Assignment List */}
      {filteredAssignments.length === 0 ? (
        <motion.div {...fadeUp(0.15)} className="rounded-2xl border border-dashed border-white/10 p-16 text-center" style={{ background: "#232323" }}>
          <CheckSquare className="w-10 h-10 text-white/15 mx-auto mb-4" />
          <p className="text-white font-semibold mb-2">{t('teacher.hw.no_submissions')}</p>
          <p className="text-white/35 text-sm max-w-xs mx-auto leading-relaxed">
            {t('teacher.hw.no_submissions_desc')}
          </p>
        </motion.div>
      ) : (
        <div className="space-y-4">
          {filteredAssignments.map((assignment, idx) => {
            const isOpen = expanded === assignment.id;
            const pendingSubs = assignment.submissions.filter((s: any) => s.status === "submitted" || !s.status);

            return (
              <motion.div key={assignment.id} {...fadeUp(0.05 * idx)}
                className="rounded-2xl border border-white/[0.06] overflow-hidden" style={{ background: "#232323" }}>
                {/* Assignment Header */}
                <button
                  className="w-full flex items-center justify-between p-5 text-left hover:bg-white/[0.02] transition-colors"
                  onClick={() => setExpanded(isOpen ? null : assignment.id)}
                >
                  <div className="flex items-start gap-4">
                    <div className="w-10 h-10 rounded-xl bg-[#D4AF37]/10 flex items-center justify-center shrink-0 mt-0.5">
                      <FileText className="w-5 h-5 text-[#D4AF37]" />
                    </div>
                    <div>
                      <h3 className="text-white font-semibold text-sm">{assignment.title || "Untitled Assignment"}</h3>
                      <div className="flex items-center gap-3 mt-1.5">
                        <span className="text-white/35 text-xs flex items-center gap-1">
                          <BookOpen className="w-3 h-3" /> {assignment.courseName}
                        </span>
                        <span className="text-white/35 text-xs flex items-center gap-1">
                          <Users className="w-3 h-3" /> {assignment.submissions.length} submission{assignment.submissions.length !== 1 ? "s" : ""}
                        </span>
                        {pendingSubs.length > 0 && (
                          <span className="flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full"
                            style={{ color: "#FBBF24", background: "rgba(251,191,36,0.1)" }}>
                            <AlertCircle className="w-3 h-3" /> {pendingSubs.length} pending
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                  <ChevronDown className={`w-5 h-5 text-white/30 transition-transform duration-200 ${isOpen ? "rotate-180" : ""}`} />
                </button>

                {/* Submissions */}
                <AnimatePresence>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.25 }}
                      className="overflow-hidden border-t border-white/[0.06]"
                    >
                      <div className="divide-y divide-white/[0.04]">
                        {assignment.submissions.map((sub: any) => {
                          const key = `${assignment.id}-${sub.id}`;
                          const meta = STATUS_META[sub.status] || STATUS_META.submitted;
                          const StatusIcon = meta.icon;
                          const submittedAt = sub.submittedAt?.toDate?.();
                          const isFile = sub.fileUrl;
                          const isImage = isFile && /\.(jpg|jpeg|png|gif|webp)/i.test(sub.fileUrl);

                          return (
                            <div key={sub.id} className="p-5 flex flex-col gap-4">
                              {/* Student Row */}
                              <div className="flex items-start justify-between gap-4">
                                <div className="flex items-center gap-3">
                                  <div className="w-9 h-9 rounded-full overflow-hidden border border-white/10 bg-[#1A1A1A] shrink-0">
                                    {sub.studentImage
                                      ? <Image src={sub.studentImage} alt={sub.studentName || ""} width={36} height={36} className="object-cover w-full h-full" />
                                      : <div className="w-full h-full flex items-center justify-center text-white/30 text-sm font-bold">{sub.studentName?.charAt(0) || "S"}</div>
                                    }
                                  </div>
                                  <div>
                                    <p className="text-white text-sm font-semibold">{sub.studentName || "Student"}</p>
                                    {submittedAt && (
                                      <p className="text-white/30 text-xs mt-0.5">{format(submittedAt, "MMM d, yyyy · h:mm a")}</p>
                                    )}
                                  </div>
                                </div>
                                {/* Status badge */}
                                <span className="flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-full shrink-0"
                                  style={{ color: meta.color, background: meta.bg }}>
                                  <StatusIcon className="w-3.5 h-3.5" /> {meta.label}
                                </span>
                              </div>

                              {/* Student Note */}
                              {sub.note && (
                                <div className="rounded-xl p-3.5 border border-white/[0.05]" style={{ background: "rgba(255,255,255,0.02)" }}>
                                  <p className="text-white/50 text-xs leading-relaxed">{sub.note}</p>
                                </div>
                              )}

                              {/* File / Image */}
                              {isFile && (
                                <div>
                                  {isImage ? (
                                    <div className="relative w-full max-w-sm h-52 rounded-xl overflow-hidden border border-white/10">
                                      <Image src={sub.fileUrl} alt="Submission" fill className="object-cover" />
                                    </div>
                                  ) : (
                                    <a href={sub.fileUrl} target="_blank" rel="noreferrer"
                                      className="flex items-center gap-2 text-xs font-medium px-4 py-2.5 rounded-xl border border-white/10 w-fit hover:border-white/20 transition-colors text-white/60 hover:text-white">
                                      <FileText className="w-4 h-4" />
                                      {sub.fileName || "View File"} <ExternalLink className="w-3 h-3" />
                                    </a>
                                  )}
                                </div>
                              )}

                              {/* Grading Panel */}
                              {(sub.status === "submitted" || !sub.status) && (
                                <div className="rounded-xl p-4 border border-white/[0.06]" style={{ background: "rgba(255,255,255,0.02)" }}>
                                  <p className="text-white/50 text-xs font-semibold uppercase tracking-widest mb-3">{t('teacher.hw.grade_label')}</p>
                                  <div className="flex flex-col sm:flex-row gap-3">
                                    <input
                                      type="number"
                                      placeholder={t('teacher.hw.points_placeholder')}
                                      min={0} max={100}
                                      value={grading[key]?.points || ""}
                                      onChange={e => setGrading(prev => ({ ...prev, [key]: { ...prev[key], points: e.target.value } }))}
                                      className="w-32 bg-[#1A1A1A] border border-white/10 rounded-xl px-3 py-2.5 text-sm text-white placeholder-white/20 outline-none focus:border-[#D4AF37]/40 transition-colors"
                                    />
                                    <input
                                      type="text"
                                      placeholder={t('teacher.hw.feedback_placeholder')}
                                      value={grading[key]?.feedback || ""}
                                      onChange={e => setGrading(prev => ({ ...prev, [key]: { ...prev[key], feedback: e.target.value } }))}
                                      className="flex-1 bg-[#1A1A1A] border border-white/10 rounded-xl px-3 py-2.5 text-sm text-white placeholder-white/20 outline-none focus:border-[#D4AF37]/40 transition-colors"
                                    />
                                    <div className="flex gap-2">
                                      <button
                                        disabled={saving === key}
                                        onClick={() => handleGrade(assignment.courseId, assignment.id, sub.id, "graded")}
                                        className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-xs font-bold text-black transition-all hover:scale-105 disabled:opacity-50"
                                        style={{ background: "linear-gradient(135deg, #34D399, #10B981)" }}
                                      >
                                        {saving === key ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                                        {t('teacher.hw.approve')}
                                      </button>
                                      <button
                                        disabled={saving === key}
                                        onClick={() => handleGrade(assignment.courseId, assignment.id, sub.id, "rejected")}
                                        className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-xs font-bold text-white transition-all hover:scale-105 disabled:opacity-50"
                                        style={{ background: "rgba(248,113,113,0.15)", border: "1px solid rgba(248,113,113,0.2)" }}
                                      >
                                        <XCircle className="w-3.5 h-3.5 text-red-400" />
                                        {t('teacher.hw.return')}
                                      </button>
                                    </div>
                                  </div>
                                </div>
                              )}

                              {/* Already graded info */}
                              {sub.status === "graded" && (
                                <div className="flex items-center gap-3 text-xs">
                                  <span className="flex items-center gap-1.5 font-bold" style={{ color: "#34D399" }}>
                                    <Award className="w-4 h-4" /> {sub.points || 0} pts
                                  </span>
                                  {sub.feedback && <span className="text-white/30">· "{sub.feedback}"</span>}
                                </div>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
