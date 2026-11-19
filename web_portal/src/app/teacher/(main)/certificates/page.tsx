"use client";

import { useState, useEffect, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Award, Users, Check, Clock, Search, Filter, ShieldCheck,
  Eye, Copy, ExternalLink, Loader2, BookOpen, Sparkles, AlertCircle, RefreshCw
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { collection, query, where, getDocs, doc, getDoc } from "firebase/firestore";
import { onAuthStateChanged } from "firebase/auth";
import Image from "next/image";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";
import CertificateModal from "@/components/CertificateModal";
import {
  issueCertificateAction,
  issueAllPendingCertificatesAction,
  getTeacherCertificatesDataAction,
} from "@/app/actions/certificates";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay, ease: "easeOut" as const },
});

const formatDateSafe = (d: any) => {
  if (!d) return "—";
  try {
    if (typeof d.toDate === "function") return d.toDate().toLocaleDateString();
    if (d.seconds) return new Date(d.seconds * 1000).toLocaleDateString();
    if (typeof d === "string") return new Date(d).toLocaleDateString();
  } catch {
    // fallback
  }
  return "—";
};

export default function TeacherCertificatesPage() {
  const [teacherUid, setTeacherUid] = useState<string | null>(null);
  const [teacherProfile, setTeacherProfile] = useState<any>(null);
  const [courses, setCourses] = useState<any[]>([]);
  const [selectedCourseId, setSelectedCourseId] = useState<string>("all");
  const [studentsByCourse, setStudentsByCourse] = useState<Record<string, any[]>>({});
  const [certificates, setCertificates] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Filter & Search
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "issued" | "pending">("all");

  // Actions state
  const [issuingKey, setIssuingKey] = useState<string | null>(null);
  const [issuingAll, setIssuingAll] = useState(false);
  const [selectedCertificate, setSelectedCertificate] = useState<any | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const { t, locale } = useTranslation();

  const loadData = useCallback(async (uid: string) => {
    try {
      // 1. Attempt server action via adminDb (bypasses all client security rules & indexing)
      const token = (await auth.currentUser?.getIdToken()) ?? "";
      const res = await getTeacherCertificatesDataAction(token, uid);
      if (res.success && res.courses) {
        setCourses(res.courses || []);
        setCertificates(res.certificates || []);
        setStudentsByCourse(res.studentsByCourse || {});
        return;
      }
    } catch (e) {
      console.warn("Server action fallback to client queries:", e);
    }

    // 2. Client fallback
    try {
      const coursesSnap = await getDocs(
        query(collection(db, "courses"), where("teacherId", "==", uid))
      );
      const courseList: any[] = coursesSnap.docs.map((d) => ({ id: d.id, ...(d.data() as any) }));
      setCourses(courseList);

      const certsSnap = await getDocs(
        query(collection(db, "certificates"), where("teacherId", "==", uid))
      );
      const certList: any[] = certsSnap.docs.map((d) => ({ id: d.id, ...(d.data() as any) }));
      setCertificates(certList);

      const studentMap: Record<string, any[]> = {};
      for (const c of courseList) {
        const enrolledUids: string[] = Array.isArray((c as any).enrolledStudents)
          ? (c as any).enrolledStudents
          : [];
        const sDocs = await Promise.all(
          enrolledUids.map(async (sUid: string) => {
            try {
              const uSnap = await getDoc(doc(db, "users", sUid));
              if (uSnap.exists()) {
                const uData = uSnap.data();
                return {
                  id: sUid,
                  name: uData.name || uData.displayName || "Student",
                  email: uData.email || "",
                  photoUrl: uData.photoUrl || uData.profilePic || uData.avatarUrl || null,
                };
              }
            } catch {
              // fallback
            }
            return { id: sUid, name: "Student", email: "" };
          })
        );
        studentMap[c.id] = sDocs;
      }
      setStudentsByCourse(studentMap);
    } catch (err) {
      console.error("Client fallback error loading certificates:", err);
    }
  }, []);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      setTeacherUid(user.uid);
      setLoading(true);
      try {
        const uDoc = await getDoc(doc(db, "users", user.uid));
        if (uDoc.exists()) setTeacherProfile(uDoc.data());
      } catch (e) {
        // fallback
      }
      await loadData(user.uid);
      setLoading(false);
    });

    return () => unsub();
  }, [loadData]);

  const handleRefresh = async () => {
    if (!teacherUid) return;
    setRefreshing(true);
    await loadData(teacherUid);
    setRefreshing(false);
  };

  // Compute unified list of all items (across selected course or all courses)
  const unifiedItems = useMemo(() => {
    const items: any[] = [];
    const activeCourses =
      selectedCourseId === "all" ? courses : courses.filter((c) => c.id === selectedCourseId);

    // Build index of certificates by `${courseId}_${studentId}`
    const certIndex = new Map<string, any>();
    certificates.forEach((c) => {
      if (c.courseId && c.studentId) {
        certIndex.set(`${c.courseId}_${c.studentId}`, c);
      }
    });

    // Traverse active courses and their students
    activeCourses.forEach((c) => {
      const courseStudents = studentsByCourse[c.id] || [];
      const seenStudentIds = new Set<string>();

      courseStudents.forEach((student: any) => {
        seenStudentIds.add(student.id);
        const cert = certIndex.get(`${c.id}_${student.id}`) || null;
        items.push({
          key: `${c.id}_${student.id}`,
          courseId: c.id,
          courseName: c.courseName || c.courseTitle || c.title || "Untitled Course",
          studentId: student.id,
          studentName: student.name || "Student",
          studentEmail: student.email || "",
          studentPhoto: student.photoUrl || null,
          certificate: cert,
          isIssued: Boolean(cert),
        });
      });

      // Also include certificates for students that might not be in enrolledStudents list
      certificates
        .filter((cert) => cert.courseId === c.id && !seenStudentIds.has(cert.studentId))
        .forEach((cert) => {
          items.push({
            key: `${c.id}_${cert.studentId}`,
            courseId: c.id,
            courseName: c.courseName || cert.courseName || "Untitled Course",
            studentId: cert.studentId,
            studentName: cert.studentName || "Student",
            studentEmail: cert.studentEmail || "",
            studentPhoto: null,
            certificate: cert,
            isIssued: true,
          });
        });
    });

    return items;
  }, [courses, selectedCourseId, studentsByCourse, certificates]);

  // Aggregate stats
  const totalEnrolled = unifiedItems.length;
  const totalIssued = unifiedItems.filter((i) => i.isIssued).length;
  const totalPending = totalEnrolled - totalIssued;
  const completionRate = totalEnrolled > 0 ? Math.round((totalIssued / totalEnrolled) * 100) : 0;

  // Filtered items
  const filteredItems = useMemo(() => {
    return unifiedItems.filter((item) => {
      if (statusFilter === "issued" && !item.isIssued) return false;
      if (statusFilter === "pending" && item.isIssued) return false;

      if (!search.trim()) return true;
      const q = search.toLowerCase();
      const matchName = item.studentName.toLowerCase().includes(q);
      const matchEmail = item.studentEmail.toLowerCase().includes(q);
      const matchCourse = item.courseName.toLowerCase().includes(q);
      const matchCertId = item.certificate?.id?.toLowerCase().includes(q);
      return matchName || matchEmail || matchCourse || matchCertId;
    });
  }, [unifiedItems, statusFilter, search]);

  // Issue single certificate via Server Action
  const handleIssueSingle = async (item: any) => {
    const key = `${item.courseId}_${item.studentId}`;
    setIssuingKey(key);
    try {
      const res = await issueCertificateAction((await auth.currentUser?.getIdToken()) ?? "", {
        courseId: item.courseId,
        studentId: item.studentId,
      });

      if (res.success && res.certificate) {
        setCertificates((prev) => [
          ...prev.filter(
            (c) => !(c.courseId === item.courseId && c.studentId === item.studentId)
          ),
          res.certificate,
        ]);
      } else {
        alert(res.error || "Failed to issue certificate");
      }
    } catch (err: any) {
      console.error("Error issuing certificate:", err);
      alert(err?.message || "Error issuing certificate");
    } finally {
      setIssuingKey(null);
    }
  };

  // Issue all pending certificates via Server Action
  const handleIssueAllPending = async () => {
    if (totalPending === 0) return;
    setIssuingAll(true);
    try {
      const activeCourseIds =
        selectedCourseId === "all" ? courses.map((c) => c.id) : [selectedCourseId];

      const newCertificates: any[] = [];
      for (const cId of activeCourseIds) {
        const res = await issueAllPendingCertificatesAction((await auth.currentUser?.getIdToken()) ?? "", cId);
        if (res.success && Array.isArray(res.certificates)) {
          newCertificates.push(...res.certificates);
        }
      }

      if (newCertificates.length > 0) {
        setCertificates((prev) => {
          const map = new Map(prev.map((c) => [`${c.courseId}_${c.studentId}`, c]));
          newCertificates.forEach((c) => map.set(`${c.courseId}_${c.studentId}`, c));
          return Array.from(map.values());
        });
      }
    } catch (err) {
      console.error("Error issuing all certificates:", err);
    } finally {
      setIssuingAll(false);
    }
  };

  const handleCopy = (idStr: string) => {
    navigator.clipboard.writeText(idStr);
    setCopiedId(idStr);
    setTimeout(() => setCopiedId(null), 2000);
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <div className="w-16 h-16 rounded-2xl bg-[#D4AF37]/10 border border-[#D4AF37]/30 flex items-center justify-center">
          <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
        </div>
        <p className="text-white/60 text-sm font-medium">
          {locale === "ar" ? "جارٍ تحميل بيانات الشهادات..." : "Loading certificates data..."}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-12">
      {/* ─── HEADER ─── */}
      <motion.div {...fadeUp(0)} className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5 mb-1.5">
            <div className="w-8 h-8 rounded-lg bg-[#D4AF37]/10 border border-[#D4AF37]/30 flex items-center justify-center">
              <Award className="w-4 h-4 text-[#D4AF37]" />
            </div>
            <h1 className="text-2xl font-bold text-white tracking-wide">
              {t("teacher.studio.certificates.title") || (locale === "ar" ? "شهادات الطلاب" : "Student Certificates")}
            </h1>
          </div>
          <p className="text-white/50 text-sm">
            {t("teacher.studio.certificates.subtitle") ||
              (locale === "ar"
                ? "إدارة وإصدار وتوثيق شهادات الإجازة لطلاب دوراتك"
                : "Manage, issue, and verify official Ijazah certificates for your students")}
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="flex items-center gap-2 px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white/70 hover:text-white hover:bg-white/10 text-xs font-semibold transition-all disabled:opacity-50"
            title="Refresh"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? "animate-spin text-[#D4AF37]" : ""}`} />
            <span>{locale === "ar" ? "تحديث" : "Refresh"}</span>
          </button>

          {totalPending > 0 && (
            <button
              onClick={handleIssueAllPending}
              disabled={issuingAll}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#D4AF37] hover:bg-[#c49f2f] text-black font-bold text-xs shadow-lg shadow-[#D4AF37]/20 transition-all active:scale-95 disabled:opacity-50"
            >
              {issuingAll ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  <span>{locale === "ar" ? "جارٍ الإصدار..." : "Issuing..."}</span>
                </>
              ) : (
                <>
                  <Sparkles className="w-3.5 h-3.5" />
                  <span>
                    {t("teacher.studio.certificates.btn_issue_all") || (locale === "ar" ? "إصدار للجميع" : "Issue All Pending")} ({totalPending})
                  </span>
                </>
              )}
            </button>
          )}
        </div>
      </motion.div>

      {/* ─── METRIC CARDS ─── */}
      <motion.div {...fadeUp(0.05)} className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Total Enrolled */}
        <div className="p-5 rounded-2xl bg-[#161616] border border-white/[0.08] flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center shrink-0">
            <Users className="w-6 h-6 text-blue-400" />
          </div>
          <div>
            <p className="text-white/40 text-xs font-medium">
              {t("teacher.studio.certificates.total_enrolled") || (locale === "ar" ? "إجمالي الطلاب" : "Total Enrolled")}
            </p>
            <p className="text-2xl font-bold text-white mt-0.5">{totalEnrolled}</p>
          </div>
        </div>

        {/* Total Issued */}
        <div className="p-5 rounded-2xl bg-[#161616] border border-white/[0.08] flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-green-500/10 border border-green-500/20 flex items-center justify-center shrink-0">
            <Check className="w-6 h-6 text-green-400" />
          </div>
          <div>
            <p className="text-white/40 text-xs font-medium">
              {t("teacher.studio.certificates.total_issued") || (locale === "ar" ? "الشهادات الصادرة" : "Certificates Issued")}
            </p>
            <p className="text-2xl font-bold text-white mt-0.5">{totalIssued}</p>
          </div>
        </div>

        {/* Completion Rate */}
        <div className="p-5 rounded-2xl bg-[#161616] border border-white/[0.08] flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-[#D4AF37]/10 border border-[#D4AF37]/20 flex items-center justify-center shrink-0">
            <Award className="w-6 h-6 text-[#D4AF37]" />
          </div>
          <div>
            <p className="text-white/40 text-xs font-medium">
              {t("teacher.studio.certificates.completion_rate") || (locale === "ar" ? "نسبة الإنجاز" : "Completion Rate")}
            </p>
            <p className="text-2xl font-bold text-[#D4AF37] mt-0.5">{completionRate}%</p>
          </div>
        </div>
      </motion.div>

      {/* ─── FILTERS & SEARCH BAR ─── */}
      <motion.div {...fadeUp(0.1)} className="p-5 rounded-2xl bg-[#161616] border border-white/[0.08] space-y-4">
        <div className="flex flex-col lg:flex-row gap-3 items-stretch lg:items-center justify-between">
          {/* Course Selector Dropdown */}
          <div className="flex items-center gap-2 min-w-[240px]">
            <BookOpen className="w-4 h-4 text-[#D4AF37] shrink-0" />
            <select
              value={selectedCourseId}
              onChange={(e) => setSelectedCourseId(e.target.value)}
              className="w-full bg-[#1F1F1F] text-white text-xs font-semibold rounded-xl px-3 py-2.5 border border-white/10 focus:outline-none focus:border-[#D4AF37]"
            >
              <option value="all">
                {locale === "ar" ? "جميع الدورات التدريبية" : "All Masterclasses"} ({courses.length})
              </option>
              {courses.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.courseName || c.courseTitle || c.title || "Course"}
                </option>
              ))}
            </select>
          </div>

          {/* Search Box */}
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-white/40 absolute left-3 rtl:left-auto rtl:right-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={
                t("teacher.studio.certificates.search_placeholder") ||
                (locale === "ar" ? "ابحث باسم الطالب أو الدورة أو رقم الشهادة..." : "Search by student, course, or cert ID...")
              }
              className="w-full bg-[#1F1F1F] text-white text-xs rounded-xl pl-9 pr-4 rtl:pl-4 rtl:pr-9 py-2.5 border border-white/10 placeholder-white/30 focus:outline-none focus:border-[#D4AF37]"
            />
          </div>

          {/* Status Pills */}
          <div className="flex items-center gap-1.5 bg-[#1F1F1F] p-1 rounded-xl border border-white/10 shrink-0 self-start sm:self-auto">
            {(
              [
                { id: "all", label: t("teacher.studio.certificates.filter_all") || (locale === "ar" ? "الكل" : "All") },
                { id: "issued", label: t("teacher.studio.certificates.filter_issued") || (locale === "ar" ? "صادرة" : "Issued") },
                { id: "pending", label: t("teacher.studio.certificates.filter_pending") || (locale === "ar" ? "بانتظار الإصدار" : "Pending") },
              ] as const
            ).map((filter) => (
              <button
                key={filter.id}
                onClick={() => setStatusFilter(filter.id)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  statusFilter === filter.id
                    ? "bg-[#D4AF37] text-black font-bold shadow"
                    : "text-white/50 hover:text-white"
                }`}
              >
                {filter.label}
              </button>
            ))}
          </div>
        </div>
      </motion.div>

      {/* ─── CERTIFICATES TABLE / LIST ─── */}
      <motion.div {...fadeUp(0.15)}>
        {filteredItems.length === 0 ? (
          <div className="p-12 text-center rounded-2xl bg-[#161616] border border-white/[0.08]">
            <Award className="w-12 h-12 text-white/20 mx-auto mb-3" />
            <h3 className="text-white font-semibold text-base mb-1">
              {search.trim()
                ? (locale === "ar" ? "لم يتم العثور على نتائج للبحث" : "No results match your search")
                : (locale === "ar" ? "لا توجد شهادات أو طلاب مسجلين بعد" : "No students or certificates found")}
            </h3>
            <p className="text-white/40 text-xs max-w-sm mx-auto">
              {search.trim()
                ? (locale === "ar" ? "جرّب البحث بكلمة مفتاحية مختلفة." : "Try adjusting your search terms.")
                : (locale === "ar" ? "عند انضمام الطلاب لدوراتك سيظهرون هنا لإصدار شهاداتهم." : "Enrolled students will appear here once they register.")}
            </p>
          </div>
        ) : (
          <div className="rounded-2xl bg-[#161616] border border-white/[0.08] overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-start">
                <thead>
                  <tr className="border-b border-white/[0.08] bg-white/[0.02] text-white/40 text-[11px] font-bold uppercase tracking-wider">
                    <th className="py-4 px-6 text-start">{locale === "ar" ? "الطالب" : "Student"}</th>
                    <th className="py-4 px-6 text-start">{locale === "ar" ? "الدورة التدريبية" : "Masterclass"}</th>
                    <th className="py-4 px-6 text-start">{locale === "ar" ? "الحالة" : "Status"}</th>
                    <th className="py-4 px-6 text-start">{locale === "ar" ? "تاريخ الإصدار" : "Issue Date"}</th>
                    <th className="py-4 px-6 text-start">{locale === "ar" ? "رقم الشهادة" : "Certificate ID"}</th>
                    <th className="py-4 px-6 text-end">{locale === "ar" ? "الإجراءات" : "Actions"}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/[0.04] text-xs">
                  {filteredItems.map((item) => {
                    const isIssuingThis = issuingKey === item.key;
                    return (
                      <tr key={item.key} className="hover:bg-white/[0.02] transition-colors">
                        {/* Student Info */}
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-full overflow-hidden bg-white/5 border border-white/10 flex items-center justify-center shrink-0">
                              {item.studentPhoto ? (
                                <Image
                                  src={item.studentPhoto}
                                  alt={item.studentName}
                                  width={36}
                                  height={36}
                                  className="object-cover w-full h-full"
                                />
                              ) : (
                                <span className="text-[#D4AF37] font-bold text-xs">
                                  {item.studentName.charAt(0).toUpperCase()}
                                </span>
                              )}
                            </div>
                            <div className="min-w-0">
                              <p className="text-white font-semibold truncate">{item.studentName}</p>
                              {item.studentEmail && (
                                <p className="text-white/40 text-[11px] truncate">{item.studentEmail}</p>
                              )}
                            </div>
                          </div>
                        </td>

                        {/* Course Name */}
                        <td className="py-4 px-6">
                          <Link
                            href={`/teacher/courses/${item.courseId}`}
                            className="text-white/80 hover:text-[#D4AF37] font-medium transition-colors"
                          >
                            {item.courseName}
                          </Link>
                        </td>

                        {/* Status Badge */}
                        <td className="py-4 px-6">
                          {item.isIssued ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-500/10 border border-green-500/20 text-green-400 font-semibold text-[11px]">
                              <Check className="w-3 h-3" />
                              <span>{t("teacher.studio.certificates.status_issued") || (locale === "ar" ? "صادرة" : "Issued")}</span>
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-400 font-semibold text-[11px]">
                              <Clock className="w-3 h-3" />
                              <span>{t("teacher.studio.certificates.status_pending") || (locale === "ar" ? "بانتظار الإصدار" : "Pending")}</span>
                            </span>
                          )}
                        </td>

                        {/* Issue Date */}
                        <td className="py-4 px-6 text-white/60">
                          {item.certificate ? formatDateSafe(item.certificate.issueDate) : "—"}
                        </td>

                        {/* Certificate ID & Copy */}
                        <td className="py-4 px-6">
                          {item.certificate ? (
                            <div className="flex items-center gap-2">
                              <code className="text-[#D4AF37] font-mono text-[11px] bg-[#D4AF37]/5 px-2 py-1 rounded border border-[#D4AF37]/20">
                                {item.certificate.id.slice(0, 10)}...
                              </code>
                              <button
                                onClick={() => handleCopy(item.certificate.id)}
                                className="text-white/40 hover:text-white transition-colors"
                                title="Copy ID"
                              >
                                {copiedId === item.certificate.id ? (
                                  <Check className="w-3.5 h-3.5 text-green-400" />
                                ) : (
                                  <Copy className="w-3.5 h-3.5" />
                                )}
                              </button>
                            </div>
                          ) : (
                            <span className="text-white/30 text-[11px]">
                              {locale === "ar" ? "غير صادرة بعد" : "Not yet issued"}
                            </span>
                          )}
                        </td>

                        {/* Actions */}
                        <td className="py-4 px-6 text-end">
                          <div className="flex items-center justify-end gap-2">
                            {item.isIssued ? (
                              <>
                                {/* Preview Modal Trigger */}
                                <button
                                  onClick={() =>
                                    setSelectedCertificate({
                                      ...item.certificate,
                                      courseName: item.courseName,
                                      studentName: item.studentName,
                                      teacherName: teacherProfile?.name || auth.currentUser?.displayName || "مدرب الدورة",
                                      teacherSignatureUrl: teacherProfile?.signatureUrl || null,
                                    })
                                  }
                                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 text-white/80 hover:text-white hover:bg-white/10 font-semibold text-xs transition-all"
                                >
                                  <Eye className="w-3.5 h-3.5" />
                                  <span>{t("teacher.studio.certificates.btn_view") || (locale === "ar" ? "معاينة" : "Preview")}</span>
                                </button>

                                {/* Direct Full View Link */}
                                <Link
                                  href={`/courses/${item.courseId}/certificate?studentId=${item.studentId}`}
                                  target="_blank"
                                  className="p-1.5 rounded-lg bg-white/5 border border-white/10 text-white/60 hover:text-[#D4AF37] transition-all"
                                  title="Open Full Certificate View"
                                >
                                  <ExternalLink className="w-3.5 h-3.5" />
                                </Link>

                                {/* Public Verification Link */}
                                <Link
                                  href={`/verify/${item.certificate.id}`}
                                  target="_blank"
                                  className="p-1.5 rounded-lg bg-[#D4AF37]/10 border border-[#D4AF37]/20 text-[#D4AF37] hover:bg-[#D4AF37]/20 transition-all"
                                  title="Verify Public Record"
                                >
                                  <ShieldCheck className="w-3.5 h-3.5" />
                                </Link>
                              </>
                            ) : (
                              <button
                                onClick={() => handleIssueSingle(item)}
                                disabled={isIssuingThis}
                                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[#D4AF37] hover:bg-[#c49f2f] text-black font-bold text-xs transition-all disabled:opacity-50"
                              >
                                {isIssuingThis ? (
                                  <>
                                    <Loader2 className="w-3 h-3 animate-spin" />
                                    <span>{locale === "ar" ? "إصدار..." : "Issuing..."}</span>
                                  </>
                                ) : (
                                  <>
                                    <Award className="w-3.5 h-3.5" />
                                    <span>{t("teacher.studio.certificates.btn_issue") || (locale === "ar" ? "إصدار الشهادة" : "Issue")}</span>
                                  </>
                                )}
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </motion.div>

      {/* ─── MODAL PREVIEW ─── */}
      {selectedCertificate && (
        <CertificateModal
          isOpen={true}
          certificate={selectedCertificate}
          onClose={() => setSelectedCertificate(null)}
        />
      )}
    </div>
  );
}
