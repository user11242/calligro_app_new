"use client";

import { useState, useEffect, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Video, Users, Star, DollarSign, Calendar, Clock,
  ChevronLeft, BookOpen, FileText, Loader2, ArrowRight,
  Award, Search, Copy, Check, ShieldCheck, Eye, Download,
  ExternalLink, Sparkles
} from "lucide-react";
import { auth, db } from "@/shared/firebase/client";
import {
  doc, getDoc, collection, getDocs, onSnapshot,
  query, where, addDoc, serverTimestamp
} from "firebase/firestore";
import Link from "next/link";
import Image from "next/image";
import { useParams, useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";
import { useTranslation } from "@/shared/i18n/useTranslation";
import CertificateModal from "@/features/certificates/ui/CertificateModal";
import { issueCertificateAction, issueAllPendingCertificatesAction } from "@/app/actions/certificates";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay, ease: "easeOut" as const },
});

const formatSafe = (val: any) => {
  if (!val) return "TBA";
  if (typeof val === "string") return val;
  if (val.toDate) return val.toDate().toLocaleDateString();
  if (val.seconds) return new Date(val.seconds * 1000).toLocaleDateString();
  return "Unknown";
};

const calculateTotalHours = (courseData: any) => {
  try {
    if (
      !courseData?.startDate ||
      !courseData?.endDate ||
      !courseData?.selectedDays ||
      !courseData?.startTime ||
      !courseData?.endTime
    ) {
      return null;
    }

    const start = courseData.startDate.toDate
      ? courseData.startDate.toDate()
      : new Date(courseData.startDate);
    const end = courseData.endDate.toDate
      ? courseData.endDate.toDate()
      : new Date(courseData.endDate);
    const days = courseData.selectedDays.map((d: string) => d.toLowerCase());

    const getHoursFromData = (timeData: any) => {
      if (!timeData) return 0;
      if (timeData.toDate || timeData instanceof Date) {
        const date = timeData.toDate ? timeData.toDate() : new Date(timeData);
        return date.getHours() + date.getMinutes() / 60;
      }
      if (typeof timeData === "string") {
        const match = timeData.match(/(\d+):(\d+)/);
        if (match) return parseInt(match[1]) + parseInt(match[2]) / 60;
      }
      return 0;
    };

    const startHour = getHoursFromData(courseData.startTime);
    const endHour = getHoursFromData(courseData.endTime);
    const duration = endHour - startHour;
    if (duration <= 0) return null;

    const dayMap: Record<string, number> = {
      sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
    };
    const selectedIndices = days
      .map((d: string) => dayMap[d])
      .filter((idx: number) => idx !== undefined);

    let totalSessions = 0;
    const current = new Date(start);
    while (current <= end) {
      if (selectedIndices.includes(current.getDay())) totalSessions++;
      current.setDate(current.getDate() + 1);
    }

    const hours = totalSessions * duration;
    return hours > 0 ? Math.round(hours) : null;
  } catch {
    return null;
  }
};

export default function CourseStudioPage() {
  const params = useParams();
  const router = useRouter();
  const courseId = params.id as string;
  const { t } = useTranslation();

  const [course, setCourse] = useState<any>(null);
  const [assignments, setAssignments] = useState<any[]>([]);
  const [students, setStudents] = useState<any[]>([]);
  const [certificates, setCertificates] = useState<any[]>([]);
  const [teacherProfile, setTeacherProfile] = useState<any>(null);
  const [teacherCommission, setTeacherCommission] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);

  // Tabs
  const [activeTab, setActiveTab] = useState<"overview" | "students" | "certificates" | "homeworks">("overview");

  // Certificate Controls
  const [certSearch, setCertSearch] = useState("");
  const [certFilter, setCertFilter] = useState<"all" | "issued" | "pending">("all");
  const [issuingStudentId, setIssuingStudentId] = useState<string | null>(null);
  const [issuingAll, setIssuingAll] = useState(false);
  const [selectedCertificate, setSelectedCertificate] = useState<any | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

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
            setTeacherProfile(uData);
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

        // 1. Fetch assignments for this course
        const assignSnap = await getDocs(collection(db, "courses", courseId, "assignments"));
        const assignList = await Promise.all(
          assignSnap.docs.map(async (d) => {
            const subsSnap = await getDocs(
              collection(db, "courses", courseId, "assignments", d.id, "submissions")
            );
            return {
              id: d.id,
              ...d.data(),
              submissionCount: subsSnap.size,
            };
          })
        );
        setAssignments(assignList);

        // 2. Fetch certificates for this course
        const certsSnap = await getDocs(
          query(collection(db, "certificates"), where("courseId", "==", courseId))
        );
        const certList = certsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
        setCertificates(certList);

        // 3. Fetch real student profiles
        const enrolledUids: string[] = Array.isArray(data.enrolledStudents)
          ? data.enrolledStudents
          : [];

        const studentDocs = await Promise.all(
          enrolledUids.map(async (uid: string) => {
            try {
              const uSnap = await getDoc(doc(db, "users", uid));
              if (uSnap.exists()) {
                const uData = uSnap.data();
                return {
                  id: uid,
                  name: uData.name || uData.displayName || "Student",
                  email: uData.email || "",
                  photoUrl: uData.photoUrl || uData.profilePic || uData.avatarUrl || null,
                  ...uData,
                };
              }
            } catch (e) {
              console.error("Error fetching student profile for", uid, e);
            }
            return { id: uid, name: "Student", email: "" };
          })
        );
        setStudents(studentDocs);
      } catch (err) {
        console.error("Error loading Course Studio:", err);
      } finally {
        setLoading(false);
      }
    });

    return () => {
      unsub();
      if (userUnsub) userUnsub();
    };
  }, [courseId, router]);

  // Derived mappings
  const certMap = useMemo(() => {
    const map = new Map<string, any>();
    certificates.forEach((c) => {
      if (c.studentId) map.set(c.studentId, c);
    });
    return map;
  }, [certificates]);

  // Unified student certificate items
  const studentCertItems = useMemo(() => {
    // Collect enrolled students
    const items = students.map((s) => {
      const cert = certMap.get(s.id);
      return {
        studentId: s.id,
        studentName: s.name || s.displayName || s.email?.split("@")[0] || "Student",
        email: s.email || "",
        photoUrl: s.photoUrl || null,
        certificate: cert || null,
        isIssued: Boolean(cert),
      };
    });

    // Also include any certificates for students not in enrolledStudents array
    certificates.forEach((c) => {
      if (c.studentId && !students.some((s) => s.id === c.studentId)) {
        items.push({
          studentId: c.studentId,
          studentName: c.studentName || "Student",
          email: "",
          photoUrl: null,
          certificate: c,
          isIssued: true,
        });
      }
    });

    return items;
  }, [students, certificates, certMap]);

  // Filtered certificates list
  const filteredCertItems = useMemo(() => {
    const queryStr = certSearch.trim().toLowerCase();
    return studentCertItems.filter((item) => {
      const matchesSearch =
        !queryStr ||
        item.studentName.toLowerCase().includes(queryStr) ||
        item.email.toLowerCase().includes(queryStr) ||
        (item.certificate?.id && item.certificate.id.toLowerCase().includes(queryStr));

      const matchesFilter =
        certFilter === "all" ||
        (certFilter === "issued" && item.isIssued) ||
        (certFilter === "pending" && !item.isIssued);

      return matchesSearch && matchesFilter;
    });
  }, [studentCertItems, certSearch, certFilter]);

  const totalEnrolled = students.length || course?.enrolledStudents?.length || 0;
  const totalIssued = certificates.length;
  const pendingCount = Math.max(0, totalEnrolled - totalIssued);
  const completionRate = totalEnrolled > 0 ? Math.round((totalIssued / totalEnrolled) * 100) : 0;
  const totalHours = course ? calculateTotalHours(course) : null;

  // Issue single certificate via Server Action (guaranteed adminDb permissions)
  const handleIssueCertificate = async (item: { studentId: string; studentName: string }) => {
    if (!course) return;
    setIssuingStudentId(item.studentId);
    try {
      const res = await issueCertificateAction((await auth.currentUser?.getIdToken()) ?? "", {
        courseId: course.id,
        studentId: item.studentId,
      });

      if (res.success && res.certificate) {
        setCertificates((prev) => [
          ...prev.filter((c) => c.studentId !== item.studentId),
          res.certificate,
        ]);
      } else {
        alert(res.error || "Failed to issue certificate");
      }
    } catch (err: any) {
      console.error("Failed to issue certificate:", err);
      alert(err?.message || "Failed to issue certificate");
    } finally {
      setIssuingStudentId(null);
    }
  };

  // Bulk issue certificates for all pending students via Server Action
  const handleIssueAllCertificates = async () => {
    if (!course || pendingCount === 0) return;
    setIssuingAll(true);
    try {
      const res = await issueAllPendingCertificatesAction((await auth.currentUser?.getIdToken()) ?? "", course.id);
      if (res.success && res.certificates) {
        setCertificates((prev) => {
          const map = new Map(prev.map((c) => [c.studentId, c]));
          res.certificates!.forEach((c: any) => map.set(c.studentId, c));
          return Array.from(map.values());
        });
      } else if (!res.success) {
        alert(res.error || "Failed to issue certificates");
      }
    } catch (err: any) {
      console.error("Failed to issue all certificates:", err);
      alert(err?.message || "Failed to issue certificates");
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
      <div className="flex h-[70vh] items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
      </div>
    );
  }

  if (!course) return null;

  const originalPrice = course.price || 0;
  const actualPrice = originalPrice / 2; // The half rule
  const revenue = teacherCommission !== null ? actualPrice * totalEnrolled * (teacherCommission / 100) : null;
  const rating = course.rating?.toFixed(1) || "—";

  const bannerUrl = course.courseBanner?.startsWith("assets/")
    ? `/${course.courseBanner}`
    : course.courseBanner;

  return (
    <div className="space-y-8 pb-20">
      {/* Certificate Modal */}
      <CertificateModal
        isOpen={Boolean(selectedCertificate)}
        onClose={() => setSelectedCertificate(null)}
        certificate={selectedCertificate}
      />

      {/* Back Navigation */}
      <motion.div {...fadeUp(0)}>
        <Link
          href="/teacher/courses"
          className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors text-sm font-semibold mb-2"
        >
          <ChevronLeft className="w-4 h-4" /> Back to My Courses
        </Link>
      </motion.div>

      {/* Hero Card */}
      <motion.div
        {...fadeUp(0.05)}
        className="relative rounded-3xl overflow-hidden border border-white/[0.08]"
        style={{ background: "#1A1A1A" }}
      >
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
              <span
                className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider rounded-lg"
                style={{ background: "rgba(212,175,55,0.15)", color: "#D4AF37" }}
              >
                {course.selectedCategory || t("teacher.studio.category")}
              </span>
              <span
                className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider rounded-lg"
                style={{ background: "rgba(255,255,255,0.1)", color: "rgba(255,255,255,0.6)" }}
              >
                {course.ageCategory || t("teacher.studio.age_group")}
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
                <span>
                  {formatSafe(course.startTime)} - {formatSafe(course.endTime)}
                </span>
              </div>
            </div>
          </div>

          {/* CTA */}
          <Link href={`/teacher/courses/${course.id}/classroom`} className="shrink-0 w-full md:w-auto">
            <button
              className="w-full flex items-center justify-center gap-3 text-sm font-bold px-8 py-4 rounded-xl text-black transition-all hover:scale-105 shadow-2xl"
              style={{
                background: "linear-gradient(135deg, #D4AF37, #B58C28)",
                boxShadow: "0 12px 30px rgba(212,175,55,0.3)",
              }}
            >
              <Video className="w-5 h-5 fill-black" /> {t("teacher.studio.go_live")}
            </button>
          </Link>
        </div>
      </motion.div>

      {/* Stats Row */}
      <motion.div {...fadeUp(0.1)} className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: t("teacher.studio.students_enrolled"), value: totalEnrolled, icon: Users, color: "#60A5FA" },
          { label: t("teacher.studio.revenue"), value: revenue !== null ? `$${revenue.toLocaleString()}` : "No Commission", icon: DollarSign, color: "#34D399" },
          { label: t("teacher.studio.price"), value: actualPrice ? `$${actualPrice}` : t("teacher.courses.free"), icon: DollarSign, color: "#D4AF37" },
          { label: t("teacher.studio.rating"), value: rating, icon: Star, color: "#A78BFA" },
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
          {(["overview", "students", "certificates", "homeworks"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className="relative pb-4 text-sm font-bold capitalize transition-colors whitespace-nowrap flex items-center gap-2"
              style={{ color: activeTab === tab ? "#D4AF37" : "rgba(255,255,255,0.4)" }}
            >
              <span>{t(`teacher.studio.tabs.${tab}`) || (tab === "certificates" ? "Certificates" : tab)}</span>
              {tab === "certificates" && certificates.length > 0 && (
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#D4AF37]/20 text-[#D4AF37]">
                  {certificates.length}
                </span>
              )}
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
              <motion.div
                key="overview"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
                className="grid md:grid-cols-2 gap-10"
              >
                <div>
                  <h3 className="text-white font-bold text-lg mb-4">{t("teacher.studio.description")}</h3>
                  <p className="text-white/50 text-sm leading-relaxed">
                    {course.courseDescription || "No description provided."}
                  </p>
                </div>
                <div className="space-y-6">
                  <div>
                    <h3 className="text-white font-bold text-lg mb-4">{t("teacher.studio.schedule")}</h3>
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
                        <span className="text-white/40 text-sm">{t("teacher.studio.writing_type")}</span>
                        <span className="text-white text-sm font-semibold">{course.writingType || "—"}</span>
                      </div>
                      <div className="flex justify-between items-center py-2 border-b border-white/[0.05]">
                        <span className="text-white/40 text-sm">{t("teacher.studio.style")}</span>
                        <span className="text-white text-sm font-semibold">{course.calligraphyStyle || "—"}</span>
                      </div>
                      <div className="flex justify-between items-center py-2 border-b border-white/[0.05]">
                        <span className="text-white/40 text-sm">Total Training Hours</span>
                        <span className="text-white text-sm font-semibold">{totalHours ? `${totalHours} hrs` : "Calculated at end"}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {/* STUDENTS TAB */}
            {activeTab === "students" && (
              <motion.div
                key="students"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
              >
                {studentCertItems.length === 0 ? (
                  <div className="text-center py-16">
                    <Users className="w-12 h-12 text-white/10 mx-auto mb-4" />
                    <p className="text-white/40 font-medium">{t("teacher.studio.no_students")}</p>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {studentCertItems.map((item, idx) => (
                      <div
                        key={idx}
                        className="flex flex-col justify-between p-4 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] hover:border-white/10 transition-colors"
                      >
                        <div className="flex items-center gap-4">
                          <div className="w-12 h-12 rounded-full overflow-hidden bg-white/5 border border-white/10 flex items-center justify-center shrink-0">
                            {item.photoUrl ? (
                              <Image
                                src={item.photoUrl}
                                alt={item.studentName || "Student"}
                                width={48}
                                height={48}
                                className="object-cover w-full h-full"
                              />
                            ) : (
                              <span className="text-[#D4AF37] font-bold text-base">
                                {item.studentName?.charAt(0)?.toUpperCase() || "S"}
                              </span>
                            )}
                          </div>
                          <div className="min-w-0 flex-1">
                            <p className="text-white font-bold text-sm truncate">{item.studentName}</p>
                            {item.email && <p className="text-white/30 text-xs truncate mt-0.5">{item.email}</p>}
                          </div>
                        </div>

                        {/* Certificate Status Footer */}
                        <div className="mt-4 pt-3 border-t border-white/[0.05] flex items-center justify-between">
                          {item.isIssued ? (
                            <button
                              onClick={() =>
                                setSelectedCertificate({
                                  ...item.certificate,
                                  studentName: item.studentName,
                                  courseName: course.courseName || course.courseTitle || "Course",
                                  teacherName: teacherProfile?.name || auth.currentUser?.displayName || "Instructor",
                                  teacherSignatureUrl: teacherProfile?.signatureUrl || null,
                                  totalHours,
                                })
                              }
                              className="inline-flex items-center gap-1.5 text-xs font-semibold text-green-400 hover:text-green-300 transition-colors"
                            >
                              <Award className="w-3.5 h-3.5" />
                              <span>Certificate Issued</span>
                            </button>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 text-xs text-white/30">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-400/50" />
                              <span>Certificate Pending</span>
                            </span>
                          )}

                          <button
                            onClick={() => setActiveTab("certificates")}
                            className="text-xs text-[#D4AF37] hover:underline"
                          >
                            Manage
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </motion.div>
            )}

            {/* CERTIFICATES TAB */}
            {activeTab === "certificates" && (
              <motion.div
                key="certificates"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
                className="space-y-6"
              >
                {/* Header Banner */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 rounded-2xl bg-[#1A1A1A] border border-white/[0.06]">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <Award className="w-5 h-5 text-[#D4AF37]" />
                      <h3 className="text-white font-bold text-lg">
                        {t("teacher.studio.certificates.title") || "Course Certificates"}
                      </h3>
                    </div>
                    <p className="text-white/40 text-xs sm:text-sm">
                      {t("teacher.studio.certificates.subtitle") ||
                        "View, issue and verify completion certificates for students in this masterclass."}
                    </p>
                  </div>

                  {pendingCount > 0 && (
                    <div className="flex items-center gap-3">
                      <button
                        onClick={handleIssueAllCertificates}
                        disabled={issuingAll}
                        className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-black font-bold text-xs shadow-lg transition-transform hover:scale-105 disabled:opacity-50"
                        style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}
                      >
                        {issuingAll ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
                        <span>
                          {issuingAll
                            ? "Issuing All..."
                            : t("teacher.studio.certificates.btn_issue_all") || `Issue All Pending (${pendingCount})`}
                        </span>
                      </button>
                    </div>
                  )}
                </div>

                {/* Metrics Row */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div className="p-4 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] flex items-center justify-between">
                    <div>
                      <p className="text-white/40 text-[11px] font-semibold uppercase tracking-wider">
                        {t("teacher.studio.certificates.total_enrolled") || "Enrolled Students"}
                      </p>
                      <p className="text-2xl font-bold text-white mt-1">{totalEnrolled}</p>
                    </div>
                    <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400">
                      <Users className="w-5 h-5" />
                    </div>
                  </div>

                  <div className="p-4 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] flex items-center justify-between">
                    <div>
                      <p className="text-white/40 text-[11px] font-semibold uppercase tracking-wider">
                        {t("teacher.studio.certificates.total_issued") || "Certificates Issued"}
                      </p>
                      <p className="text-2xl font-bold text-white mt-1">{totalIssued}</p>
                    </div>
                    <div className="w-10 h-10 rounded-xl bg-green-500/10 flex items-center justify-center text-green-400">
                      <Award className="w-5 h-5" />
                    </div>
                  </div>

                  <div className="p-4 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] flex items-center justify-between">
                    <div>
                      <p className="text-white/40 text-[11px] font-semibold uppercase tracking-wider">
                        {t("teacher.studio.certificates.completion_rate") || "Issuance Rate"}
                      </p>
                      <p className="text-2xl font-bold text-white mt-1">{completionRate}%</p>
                    </div>
                    <div className="w-10 h-10 rounded-xl bg-[#D4AF37]/10 flex items-center justify-center text-[#D4AF37]">
                      <ShieldCheck className="w-5 h-5" />
                    </div>
                  </div>
                </div>

                {/* Search & Filter Bar */}
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
                  <div className="relative flex-1 max-w-md">
                    <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
                    <input
                      type="text"
                      placeholder={
                        t("teacher.studio.certificates.search_placeholder") || "Search student or certificate ID..."
                      }
                      value={certSearch}
                      onChange={(e) => setCertSearch(e.target.value)}
                      className="w-full bg-[#1A1A1A] border border-white/[0.08] rounded-xl pl-10 pr-4 py-2.5 text-sm text-white placeholder-white/25 outline-none focus:border-[#D4AF37]/40 transition-colors"
                    />
                  </div>

                  <div className="flex items-center gap-1.5 bg-[#1A1A1A] p-1 rounded-xl border border-white/[0.06]">
                    {(["all", "issued", "pending"] as const).map((filter) => (
                      <button
                        key={filter}
                        onClick={() => setCertFilter(filter)}
                        className={`px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition-colors ${
                          certFilter === filter
                            ? "bg-[#D4AF37] text-black shadow-md font-bold"
                            : "text-white/40 hover:text-white"
                        }`}
                      >
                        {filter === "all"
                          ? t("teacher.studio.certificates.filter_all") || "All"
                          : filter === "issued"
                          ? t("teacher.studio.certificates.filter_issued") || "Issued"
                          : t("teacher.studio.certificates.filter_pending") || "Not Issued"}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Certificates List */}
                {filteredCertItems.length === 0 ? (
                  <div className="text-center py-16 bg-[#1A1A1A] rounded-2xl border border-dashed border-white/10">
                    <Award className="w-12 h-12 text-white/10 mx-auto mb-4" />
                    <p className="text-white/40 font-medium">
                      {certSearch
                        ? t("teacher.studio.certificates.no_search") || "No students match your search."
                        : t("teacher.studio.certificates.empty") || "No enrolled students or certificates found."}
                    </p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {filteredCertItems.map((item, idx) => {
                      const isIssuing = issuingStudentId === item.studentId;
                      const cert = item.certificate;
                      const issueDateStr = cert?.issueDate ? formatSafe(cert.issueDate) : "—";

                      return (
                        <div
                          key={idx}
                          className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-5 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] hover:border-white/10 transition-colors"
                        >
                          {/* Student Info */}
                          <div className="flex items-center gap-4 min-w-[240px]">
                            <div className="w-12 h-12 rounded-full overflow-hidden bg-white/5 border border-white/10 flex items-center justify-center shrink-0">
                              {item.photoUrl ? (
                                <Image
                                  src={item.photoUrl}
                                  alt={item.studentName}
                                  width={48}
                                  height={48}
                                  className="object-cover w-full h-full"
                                />
                              ) : (
                                <span className="text-[#D4AF37] font-bold text-base">
                                  {item.studentName?.charAt(0)?.toUpperCase() || "S"}
                                </span>
                              )}
                            </div>
                            <div className="min-w-0">
                              <h4 className="text-white font-bold text-sm truncate">{item.studentName}</h4>
                              <p className="text-white/30 text-xs truncate mt-0.5">{item.email || "Enrolled Student"}</p>
                            </div>
                          </div>

                          {/* Certificate Details */}
                          <div className="flex flex-wrap items-center gap-6 text-xs text-white/60">
                            <div>
                              <p className="text-white/30 text-[10px] uppercase font-semibold tracking-wider">Status</p>
                              <div className="mt-1">
                                {item.isIssued ? (
                                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] font-bold bg-green-500/10 text-green-400 border border-green-500/20">
                                    <Check className="w-3 h-3" />
                                    <span>Issued</span>
                                  </span>
                                ) : (
                                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/20">
                                    <Clock className="w-3 h-3" />
                                    <span>Not Issued</span>
                                  </span>
                                )}
                              </div>
                            </div>

                            {item.isIssued && (
                              <>
                                <div>
                                  <p className="text-white/30 text-[10px] uppercase font-semibold tracking-wider">
                                    Certificate ID
                                  </p>
                                  <div className="flex items-center gap-1.5 mt-1">
                                    <code className="text-xs text-[#D4AF37] font-mono bg-white/5 px-2 py-0.5 rounded">
                                      {cert.id.slice(0, 10)}...
                                    </code>
                                    <button
                                      onClick={() => handleCopy(cert.id)}
                                      className="p-1 text-white/30 hover:text-white transition-colors"
                                      title="Copy ID"
                                    >
                                      {copiedId === cert.id ? (
                                        <Check className="w-3.5 h-3.5 text-green-400" />
                                      ) : (
                                        <Copy className="w-3.5 h-3.5" />
                                      )}
                                    </button>
                                  </div>
                                </div>

                                <div>
                                  <p className="text-white/30 text-[10px] uppercase font-semibold tracking-wider">
                                    Issue Date
                                  </p>
                                  <p className="text-white/70 mt-1 font-medium">{issueDateStr}</p>
                                </div>
                              </>
                            )}
                          </div>

                          {/* Actions */}
                          <div className="flex items-center gap-2 shrink-0">
                            {item.isIssued ? (
                              <>
                                <button
                                  onClick={() =>
                                    setSelectedCertificate({
                                      ...cert,
                                      studentName: item.studentName,
                                      courseName: course.courseName || course.courseTitle || "Course",
                                      teacherName: teacherProfile?.name || auth.currentUser?.displayName || "Instructor",
                                      teacherSignatureUrl: teacherProfile?.signatureUrl || null,
                                      totalHours,
                                    })
                                  }
                                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-black font-bold text-xs transition-transform hover:scale-105 shadow"
                                  style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}
                                >
                                  <Eye className="w-3.5 h-3.5" />
                                  <span>{t("teacher.studio.certificates.btn_view") || "View"}</span>
                                </button>

                                <Link
                                  href={`/verify/${cert.id}`}
                                  target="_blank"
                                  className="flex items-center gap-1 px-3 py-2 rounded-xl text-white/70 hover:text-white bg-white/5 hover:bg-white/10 text-xs font-semibold border border-white/10 transition-colors"
                                >
                                  <span>{t("teacher.studio.certificates.btn_verify") || "Verify"}</span>
                                  <ExternalLink className="w-3 h-3 text-white/40" />
                                </Link>
                              </>
                            ) : (
                              <button
                                onClick={() => handleIssueCertificate(item)}
                                disabled={isIssuing}
                                className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-black font-bold text-xs transition-transform hover:scale-105 disabled:opacity-50"
                                style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}
                              >
                                {isIssuing ? (
                                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                                ) : (
                                  <Award className="w-3.5 h-3.5" />
                                )}
                                <span>
                                  {isIssuing
                                    ? "Issuing..."
                                    : t("teacher.studio.certificates.btn_issue") || "Issue Certificate"}
                                </span>
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </motion.div>
            )}

            {/* HOMEWORKS TAB */}
            {activeTab === "homeworks" && (
              <motion.div
                key="homeworks"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
              >
                {assignments.length === 0 ? (
                  <div className="text-center py-16">
                    <FileText className="w-12 h-12 text-white/10 mx-auto mb-4" />
                    <p className="text-white/40 font-medium">{t("teacher.studio.no_homeworks")}</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {assignments.map((assignment, idx) => (
                      <div
                        key={idx}
                        className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-2xl bg-[#1A1A1A] border border-white/[0.05] hover:border-white/10 transition-colors"
                      >
                        <div className="flex items-start gap-4">
                          <div className="w-10 h-10 rounded-xl bg-[#D4AF37]/10 flex items-center justify-center shrink-0 mt-0.5">
                            <FileText className="w-5 h-5 text-[#D4AF37]" />
                          </div>
                          <div>
                            <h3 className="text-white font-bold text-sm">{assignment.title || "Untitled Assignment"}</h3>
                            <p className="text-white/40 text-xs mt-1 line-clamp-1 max-w-lg">
                              {assignment.description || "No description provided."}
                            </p>
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
