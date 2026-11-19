"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/shared/firebase/client";
import { doc, getDoc, collection, query, where, getDocs, addDoc, serverTimestamp } from "firebase/firestore";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Loader2, ArrowLeft, Download } from "lucide-react";
import { useTranslation } from "@/shared/i18n/useTranslation";
import Link from "next/link";
import { formatImageUrl } from "@/shared/utils/utils";
import { issueCertificateAction } from "@/app/actions/certificates";
import CalligroCertificate from "@/features/certificates/ui/CalligroCertificate";

export default function CertificatePage() {
  const { id } = useParams();
  const searchParams = useSearchParams();
  const targetStudentId = searchParams?.get("studentId") || null;

  const [course, setCourse] = useState<any>(null);
  const [teacher, setTeacher] = useState<any>(null);
  const [studentName, setStudentName] = useState<string>("");
  const [certificateId, setCertificateId] = useState<string | null>(null);
  const [isTeacherViewer, setIsTeacherViewer] = useState(false);
  const [loading, setLoading] = useState(true);
  const [downloading, setDownloading] = useState(false);
  const { t, locale } = useTranslation();
  const [certLang, setCertLang] = useState<"ar" | "en" | "tr">(
    (locale === "ar" || locale === "en" || locale === "tr" ? locale : "ar") as "ar" | "en" | "tr"
  );
  const router = useRouter();

  const handleDownload = async () => {
    const element = document.getElementById("print-area");
    if (!element) return;
    setDownloading(true);
    try {
      const { toPng } = await import("html-to-image");
      const { jsPDF } = await import("jspdf");
      
      const imgData = await toPng(element, {
        pixelRatio: 3, 
        style: {
          transform: 'scale(1)', 
          transformOrigin: 'top left'
        },
        cacheBust: true,
      });
      
      const pdf = new jsPDF({
        orientation: "landscape",
        unit: "mm",
        format: "a4"
      });
      
      pdf.addImage(imgData, "PNG", 0, 0, 297, 210);
      const safeName = (studentName || "Student").replace(/\s+/g, "_");
      pdf.save(`Calligro_Certificate_${safeName}.pdf`);
    } catch (error) {
      console.error("Error generating certificate PDF:", error);
    } finally {
      setDownloading(false);
    }
  };

  useEffect(() => {
    if (!id) return;
    const unsubscribe = auth.onAuthStateChanged(async (user) => {
      if (!user) {
        router.push(`/login?redirect=/courses/${id}/certificate`);
        return;
      }
      try {
        const docRef = doc(db, "courses", id as string);
        const docSnap = await getDoc(docRef);
        let courseData: any = null;
        if (docSnap.exists()) {
          courseData = docSnap.data();
          setCourse(courseData);
          if (courseData.teacherId) {
            const tRef = doc(db, "users", courseData.teacherId);
            const tSnap = await getDoc(tRef);
            if (tSnap.exists()) {
              setTeacher(tSnap.data());
            }
          }
        }

        const isTeacher = Boolean(courseData && courseData.teacherId === user.uid);
        setIsTeacherViewer(isTeacher);

        // Determine which student's certificate is being viewed
        const effectiveStudentId = (isTeacher && targetStudentId) ? targetStudentId : user.uid;

        if (effectiveStudentId !== user.uid) {
          // Teacher viewing student's certificate: fetch student's profile name
          const sRef = doc(db, "users", effectiveStudentId);
          const sSnap = await getDoc(sRef);
          if (sSnap.exists()) {
            const sData = sSnap.data();
            setStudentName(sData.name || sData.displayName || sData.email?.split('@')[0] || "Student");
          } else {
            setStudentName("Student");
          }
        } else {
          setStudentName(user.displayName || user.email?.split('@')[0] || "Student");
        }

        // Fetch verification ID
        const certsRef = collection(db, "certificates");
        const q = query(certsRef, where("studentId", "==", effectiveStudentId), where("courseId", "==", id));
        const certSnap = await getDocs(q);
        if (!certSnap.empty) {
          setCertificateId(certSnap.docs[0].id);
        } else {
          // Server Action generation: completely circumvents client Firestore permission-denied
          // The server checks who is asking (the student themselves or the teacher) and
          // takes the names from the profile / course.
          const res = await issueCertificateAction(await user.getIdToken(), {
            courseId: id as string,
            studentId: effectiveStudentId,
          });
          if (res.success && res.certificate) {
            setCertificateId(res.certificate.id);
          }
        }
      } catch (err) {
        console.error("Error fetching certificate details:", err);
      } finally {
        setLoading(false);
      }
    });
    return () => unsubscribe();
  }, [id, router, targetStudentId]);

  if (loading) return (
    <div className="min-h-screen bg-[#050505] flex items-center justify-center">
      <Loader2 className="w-12 h-12 text-[#d4af37] animate-spin" />
    </div>
  );

  if (!course) return (
    <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center gap-6">
      <p className="text-white/40">{t("course.not_found")}</p>
      <Link href="/courses" className="btn-gold">{t("course.back")}</Link>
    </div>
  );

  const courseName = course.courseName || course.courseTitle || "Calligraphy Masterclass";
  const teacherName = teacher?.name || course.teacherName || "Master Instructor";

  // Helper to extract the actual last/end date of the course (NOT today's date)
  const getCourseEndDate = (courseData: any): Date => {
    if (!courseData) return new Date();

    // 1. Direct explicit endDate
    if (courseData.endDate) {
      if (typeof courseData.endDate.toDate === "function") {
        return courseData.endDate.toDate();
      }
      if (courseData.endDate.seconds) {
        return new Date(courseData.endDate.seconds * 1000);
      }
      const d = new Date(courseData.endDate);
      if (!isNaN(d.getTime())) return d;
    }

    // 2. Check sessions or schedule list
    const sessionsList = courseData.sessions || courseData.schedule || courseData.classes;
    if (Array.isArray(sessionsList) && sessionsList.length > 0) {
      const dates = sessionsList
        .map((s: any) => {
          if (!s) return null;
          const raw = s.date || s.startTime || s.timestamp || s.sessionDate;
          if (!raw) return null;
          if (typeof raw.toDate === "function") return raw.toDate();
          if (raw.seconds) return new Date(raw.seconds * 1000);
          const d = new Date(raw);
          return isNaN(d.getTime()) ? null : d;
        })
        .filter(Boolean) as Date[];

      if (dates.length > 0) {
        dates.sort((a, b) => b.getTime() - a.getTime());
        return dates[0];
      }
    }

    // 3. Expiry date
    if (courseData.expiryDate) {
      if (typeof courseData.expiryDate.toDate === "function") {
        return courseData.expiryDate.toDate();
      }
      if (courseData.expiryDate.seconds) {
        return new Date(courseData.expiryDate.seconds * 1000);
      }
      const d = new Date(courseData.expiryDate);
      if (!isNaN(d.getTime())) return d;
    }

    // 4. If startDate exists and duration/weeks exist
    if (courseData.startDate) {
      const start = courseData.startDate.toDate
        ? courseData.startDate.toDate()
        : new Date(courseData.startDate.seconds ? courseData.startDate.seconds * 1000 : courseData.startDate);
      if (!isNaN(start.getTime())) {
        if (courseData.durationWeeks) {
          return new Date(start.getTime() + courseData.durationWeeks * 7 * 24 * 60 * 60 * 1000);
        }
        if (courseData.durationDays) {
          return new Date(start.getTime() + courseData.durationDays * 24 * 60 * 60 * 1000);
        }
        return start;
      }
    }

    // 5. Fallback to createdAt or today
    if (courseData.createdAt) {
      if (typeof courseData.createdAt.toDate === "function") {
        return courseData.createdAt.toDate();
      }
      if (courseData.createdAt.seconds) {
        return new Date(courseData.createdAt.seconds * 1000);
      }
      const d = new Date(courseData.createdAt);
      if (!isNaN(d.getTime())) return d;
    }

    return new Date();
  };

  const courseEndDate = course ? getCourseEndDate(course) : new Date();

  // Format date according to active certificate language
  const formatCertificateDate = (date: Date, lang: "ar" | "en" | "tr") => {
    if (lang === "ar") {
      return date.toLocaleDateString("ar-SA", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    } else if (lang === "tr") {
      return date.toLocaleDateString("tr-TR", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    } else {
      return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    }
  };

  const dateStr = formatCertificateDate(courseEndDate, certLang);

  const calculateTotalHours = (courseData: any) => {
    try {
      if (!courseData.startDate || !courseData.endDate || !courseData.selectedDays || !courseData.startTime || !courseData.endTime) return null;
      
      const start = courseData.startDate.toDate ? courseData.startDate.toDate() : new Date(courseData.startDate);
      const end = courseData.endDate.toDate ? courseData.endDate.toDate() : new Date(courseData.endDate);
      const days = courseData.selectedDays.map((d: string) => d.toLowerCase());
      
      const getHoursFromData = (timeData: any) => {
        if (!timeData) return 0;
        if (timeData.toDate || timeData instanceof Date) {
          const date = timeData.toDate ? timeData.toDate() : new Date(timeData);
          return date.getHours() + date.getMinutes() / 60;
        }
        if (typeof timeData === 'string') {
          const match = timeData.match(/(\d+):(\d+)/);
          if (match) return parseInt(match[1]) + parseInt(match[2]) / 60;
        }
        return 0;
      };
      
      const startHour = getHoursFromData(courseData.startTime);
      const endHour = getHoursFromData(courseData.endTime);
      const duration = endHour - startHour;
      
      if (duration <= 0) return null;
      
      const dayMap: Record<string, number> = { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 };
      const selectedIndices = days.map((d: string) => dayMap[d]).filter((idx: number) => idx !== undefined);
      
      let totalSessions = 0;
      let current = new Date(start);
      while (current <= end) {
        if (selectedIndices.includes(current.getDay())) totalSessions++;
        current.setDate(current.getDate() + 1);
      }
      
      const hours = totalSessions * duration;
      return hours > 0 ? Math.round(hours) : null;
    } catch (e) {
      return null;
    }
  };
  
  const totalHours = course ? calculateTotalHours(course) : null;

  return (
    <div className="min-h-screen bg-[#050505] flex flex-col items-center py-10 print:py-0 print:bg-[#ffffff] overflow-x-hidden">
      
      {/* Actions (Hidden on Print) */}
      <div className="w-full max-w-[1123px] flex justify-between items-center mb-8 px-4 print:hidden gap-4">
        <Link href={isTeacherViewer ? `/teacher/courses/${id}` : `/courses/${id}`} className="text-white/70 hover:text-white flex items-center gap-2 transition-colors">
          <ArrowLeft className="w-4 h-4" />
          <span>{isTeacherViewer ? "Back to Course Studio" : t("course.back")}</span>
        </Link>

        {/* Language Selector for Certificate (Pure Arabic / Pure English / Pure Turkish) */}
        <div className="flex items-center gap-1 bg-white/10 p-1 rounded-xl border border-white/15 backdrop-blur-sm" dir="ltr">
          <button
            onClick={() => setCertLang("ar")}
            className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${
              certLang === "ar"
                ? "bg-[#D4AF37] text-black shadow-md"
                : "text-white/70 hover:text-white hover:bg-white/5"
            }`}
          >
            العربية
          </button>
          <button
            onClick={() => setCertLang("en")}
            className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${
              certLang === "en"
                ? "bg-[#D4AF37] text-black shadow-md"
                : "text-white/70 hover:text-white hover:bg-white/5"
            }`}
          >
            English
          </button>
          <button
            onClick={() => setCertLang("tr")}
            className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${
              certLang === "tr"
                ? "bg-[#D4AF37] text-black shadow-md"
                : "text-white/70 hover:text-white hover:bg-white/5"
            }`}
          >
            Türkçe
          </button>
        </div>

        <button 
          onClick={handleDownload} 
          disabled={downloading}
          className="btn-gold flex items-center gap-2 px-6 py-2 text-sm shadow-[0_0_20px_rgba(238,229,147,0.3)] hover:scale-105 transition-transform disabled:opacity-50 disabled:cursor-not-allowed disabled:scale-100"
        >
          {downloading ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : (
            <Download className="w-4 h-4" />
          )}
          {downloading ? t("certificate.downloading") || "Downloading..." : t("course.download_certificate")}
        </button>
      </div>

      {/* EXACT REFERENCE DESIGN CONTAINER */}
      <CalligroCertificate
        id="print-area"
        certificateId={certificateId || "PENDING"}
        studentName={studentName}
        courseName={courseName}
        teacherName={teacherName}
        teacherSignatureUrl={teacher?.signatureUrl}
        courseDate={courseEndDate}
        dateStr={dateStr}
        totalHours={totalHours}
        language={certLang}
        style={{ transform: "scale(0.9)" }}
      />

      <style dangerouslySetInnerHTML={{__html: `
        @media print {
          body * { visibility: hidden; }
          #print-area, #print-area * { visibility: visible; }
          #print-area {
            position: absolute !important;
            left: 0 !important;
            top: 0 !important;
            transform: scale(1) !important;
            box-shadow: none !important;
          }
          @page { size: A4 landscape; margin: 0; }
        }
      `}} />
    </div>
  );
}
