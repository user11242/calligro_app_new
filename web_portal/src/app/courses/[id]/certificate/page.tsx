"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc, collection, query, where, getDocs, addDoc, serverTimestamp } from "firebase/firestore";
import { useParams, useRouter } from "next/navigation";
import { Loader2, ArrowLeft, Download } from "lucide-react";
import { useTranslation } from "@/hooks/useTranslation";
import Link from "next/link";
import { formatImageUrl } from "@/lib/utils";

export default function CertificatePage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [teacher, setTeacher] = useState<any>(null);
  const [studentName, setStudentName] = useState<string>("");
  const [certificateId, setCertificateId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [downloading, setDownloading] = useState(false);
  const { t, locale } = useTranslation();
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
      pdf.save("Calligro_Certificate.pdf");
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
        setStudentName(user.displayName || user.email?.split('@')[0] || "Student");
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

        // Fetch verification ID
        const certsRef = collection(db, "certificates");
        const q = query(certsRef, where("studentId", "==", user.uid), where("courseId", "==", id));
        const certSnap = await getDocs(q);
        if (!certSnap.empty) {
          setCertificateId(certSnap.docs[0].id);
        } else {
          // Lazy-generate certificate ID for existing enrolled students (acts as a just-in-time backfill)
          const newCertRef = await addDoc(collection(db, "certificates"), {
            studentId: user.uid,
            studentName: user.displayName || user.email?.split('@')[0] || "Student",
            courseId: id,
            courseName: courseData?.courseName || courseData?.courseTitle || courseData?.title || "Untitled Course",
            teacherId: courseData?.teacherId || "",
            issueDate: serverTimestamp()
          });
          setCertificateId(newCertRef.id);
        }
      } catch (err) {
        console.error("Error fetching certificate details:", err);
      } finally {
        setLoading(false);
      }
    });
    return () => unsubscribe();
  }, [id, router]);

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
  const dateStr = new Date().toLocaleDateString('ar-SA', { year: 'numeric', month: 'long', day: 'numeric' });

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
      <div className="w-full max-w-[1123px] flex justify-between items-center mb-8 px-4 print:hidden">
        <Link href={`/courses/${id}`} className="text-white/70 hover:text-white flex items-center gap-2 transition-colors">
          <ArrowLeft className="w-4 h-4" />
          <span>{t("course.back")}</span>
        </Link>
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
      <div 
        id="print-area"
        className="w-[1123px] h-[794px] max-w-[100vw] sm:max-w-[90vw] md:max-w-[1123px] relative overflow-hidden flex flex-col bg-[#fdfcf9] shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top"
        style={{
          boxSizing: 'border-box',
          transform: 'scale(0.9)',
        }}
        dir="rtl" // Always RTL for Arabic certificate
      >
        {/* Dynamic Geometric Shapes */}
        
        {/* Bottom Left Gold Shape (Swapped from Black) */}
        <div 
          className="absolute left-0 bottom-0 w-[55%] h-[80%] bg-gradient-to-br from-[#e6c86a] to-[#b38f20] z-0 shadow-[20px_-20px_60px_rgba(0,0,0,0.1)]" 
          style={{ clipPath: "polygon(0 20%, 100% 100%, 0 100%)" }}
        >
          {/* Subtle dark pattern inside the gold shape */}
          <div className="absolute inset-0 opacity-[0.05]" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23111111\' fill-opacity=\'1\'%3E%3Cpath d=\'M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")' }}></div>
        </div>

        {/* Top Right Black Shape (Swapped from Gold) */}
        <div 
          className="absolute right-0 top-0 w-[40%] h-[45%] bg-[#111111] z-0 shadow-[-10px_10px_30px_rgba(0,0,0,0.2)]" 
          style={{ clipPath: "polygon(100% 0, 100% 100%, 20% 0)" }}
        >
          {/* Gold pattern inside black shape */}
          <div className="absolute inset-0 opacity-[0.04]" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23d4af37\' fill-opacity=\'1\'%3E%3Cpath d=\'M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")' }}></div>
        </div>

        {/* Premium Outer Borders (Top Layer to frame everything) */}
        <div className="absolute inset-[24px] border-[8px] border-[#111111] pointer-events-none z-50 shadow-inner"></div>
        <div className="absolute inset-[36px] border-[2px] border-[#d4af37] pointer-events-none z-50 opacity-80"></div>

        {/* Large Central Faded Watermark Logo inside white area */}
        <div className="absolute inset-0 top-[10%] left-[20%] z-0 flex items-center justify-center opacity-[0.02] pointer-events-none">
          <img src="/assets/images/Logo.png" alt="Watermark" className="w-[500px] h-[500px] object-contain grayscale" />
        </div>

        {/* Main Content Container */}
        <div className="relative z-20 w-full h-full p-20 pt-8 pb-16 flex flex-col items-center">
          
          {/* Header / Logo (Centered) */}
          <div className="flex flex-col items-center mb-10">
            <img src="/assets/images/Logo.png" alt="Calligro" className="w-20 h-20 object-contain drop-shadow-md mb-4 rounded-xl" />
            <span className="text-[#111111] text-3xl font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>أكاديمية كاليغرو</span>
            <span className="text-[#2a2722]/80 text-[10px] uppercase tracking-[0.4em] font-sans font-bold mt-2">Calligro Academy</span>
          </div>

          {/* Certificate Title (Centered) */}
          <h1 className="text-7xl font-bold text-[#111111] tracking-wider drop-shadow-sm mb-12" style={{ fontFamily: "'Thuluth', 'Amiri', 'Aref Ruqaa', serif" }}>
            {t("certificate.title")}
          </h1>

          {/* Presented To (Centered) */}
          <div className="text-[#2a2722]/60 text-sm uppercase font-bold tracking-[0.3em] font-sans mb-4">
            {t("certificate.presented_to")}
          </div>

          {/* Student Name inside a Simple Elegant Box */}
          <div className="relative flex flex-col items-center justify-center mb-10 w-full">
            <div className="px-16 py-4 border border-[#d4af37]/60 rounded-xl bg-gradient-to-r from-transparent via-[#d4af37]/[0.03] to-transparent shadow-sm">
              {/* Name */}
              <h2 className="text-6xl font-bold text-[#d4af37] pb-1 text-center" style={{ fontFamily: "'Diwani Letter', serif" }}>
                {studentName}
              </h2>
            </div>
          </div>

          {/* Description Text (Centered) */}
          <div className="w-full max-w-3xl text-center text-[#2a2722]/90 text-2xl" style={{ fontFamily: "'Aref Ruqaa', serif", lineHeight: "1.8" }}>
            <p>
              لقد أتم/أتمت بنجاح الدورة التدريبية
              <span className="font-bold text-[#111111] mx-3 text-3xl">{courseName}</span>
            </p>
            {totalHours && (
              <p className="mt-2">
                <span>{t("certificate.comprising")}</span>
                <span className="font-bold text-[#111111] px-3 font-sans text-2xl">{totalHours}</span>
                <span>{t("certificate.training_hours")}</span>
              </p>
            )}
          </div>

          {/* Spacer */}
          <div className="flex-1"></div>

          {/* Signatures & Dates Footer */}
          <div className="w-full flex justify-between items-start px-32 mt-12">
            
            {/* Right side (Date) */}
            <div className="flex flex-col items-center w-40">
              <div className="w-full h-8 border-b-2 border-[#111111]/20 pb-2 flex items-end justify-center">
                <span className="text-[#2a2722]/60 text-[12px] font-bold tracking-[0.1em] font-sans leading-none">التاريخ</span>
              </div>
              <div className="h-16 flex items-start justify-center pt-2">
                <span className="text-[#111111] text-2xl" style={{ fontFamily: "'Aref Ruqaa', serif" }}>{dateStr}</span>
              </div>
            </div>
            
            {/* Center (Teacher Signature) */}
            <div className="flex flex-col items-center w-48">
              <div className="w-full h-8 border-b-2 border-[#111111]/20 pb-2 flex items-end justify-center">
                <span className="text-[#2a2722]/60 text-[12px] font-bold tracking-[0.1em] font-sans leading-none">مدرب الدورة</span>
              </div>
              <div className="min-h-[5rem] flex items-start justify-center pt-2 text-center w-full">
                {teacher?.signatureUrl ? (
                  <img src={formatImageUrl(teacher.signatureUrl)} alt="Signature" className="h-20 scale-125 object-contain mix-blend-multiply" />
                ) : (
                  <span className="text-[#111111] text-xl leading-tight mt-1" style={{ fontFamily: "'Diwani Letter', serif" }}>{teacherName}</span>
                )}
              </div>
            </div>

            {/* Left side (CEO Signature) */}
            <div className="flex flex-col items-center w-48">
              <div className="w-full h-8 border-b-2 border-[#111111]/20 pb-2 flex items-end justify-center">
                <span className="text-[#2a2722]/60 text-[12px] font-bold tracking-[0.1em] font-sans leading-none">المدير التنفيذي</span>
              </div>
              <div className="min-h-[5rem] flex items-start justify-center pt-2 w-full">
                <img src="/assets/images/yazan_signature.png" alt="Yazan Qattous Signature" className="h-20 scale-150 object-contain mix-blend-multiply -translate-y-4" />
              </div>
            </div>

          </div>

        </div>

        {/* The Badge (Absolutely positioned on the Left edge, hanging from the top) */}
        <div className="absolute top-0 left-24 w-64 h-full z-30 flex flex-col items-center transform scale-[0.75] origin-top">
          
          {/* Massive Vertical Ribbon */}
          <div className="absolute top-0 w-48 h-[600px] bg-[#1a1a1a] shadow-[0_0_30px_rgba(0,0,0,0.5)] flex flex-col items-center justify-end pb-12 z-0" style={{ clipPath: "polygon(0 0, 100% 0, 100% 100%, 50% 92%, 0 100%)" }}>
              {/* Vertical gold trims */}
              <div className="absolute left-4 top-0 bottom-12 w-[2px] bg-[#d4af37]/40"></div>
              <div className="absolute right-4 top-0 bottom-12 w-[2px] bg-[#d4af37]/40"></div>
              
              {/* Verification text */}
              <div className="flex flex-col items-center text-center z-10 mb-6 w-full px-6">
                <span className="text-[#d4af37] text-[9px] uppercase font-bold tracking-[0.2em] font-sans mb-2 opacity-90">Verification</span>
                <div className="bg-[#fcf8f0] border border-[#d4af37]/60 px-3 py-1.5 rounded flex items-center justify-center w-full shadow-md">
                  <span className="text-[#111111] font-bold text-[10px] font-mono tracking-widest uppercase select-all cursor-text">{certificateId || "PENDING"}</span>
                </div>
              </div>
          </div>

          <div className="relative w-64 h-64 flex flex-col items-center justify-center mt-12 z-20">
            
            {/* Top Loops */}
            <div className="absolute -top-6 w-32 h-16 flex justify-between z-10">
                <div className="w-12 h-full bg-gradient-to-b from-[#e6c86a] to-[#806000] rounded-t-full transform -rotate-12 border-2 border-[#d4af37] shadow-lg"></div>
                <div className="w-12 h-full bg-gradient-to-b from-[#e6c86a] to-[#806000] rounded-t-full transform rotate-12 border-2 border-[#d4af37] shadow-lg"></div>
            </div>

            {/* Hanging Gold Ribbons */}
            <div className="absolute top-[40%] left-1/2 -translate-x-1/2 w-40 h-64 flex justify-center z-10 -ml-2">
              <div className="w-16 h-full bg-gradient-to-b from-[#c2a138] to-[#806000] shadow-xl transform rotate-[15deg] origin-top translate-x-2" style={{ clipPath: "polygon(0 0, 100% 0, 100% 100%, 50% 85%, 0 100%)" }}>
                <div className="absolute left-2 top-0 bottom-0 w-[4px] bg-[#8a1c1c]/90 shadow-sm"></div>
                <div className="absolute right-2 top-0 bottom-0 w-[4px] bg-[#8a1c1c]/90 shadow-sm"></div>
              </div>
              <div className="w-16 h-full bg-gradient-to-b from-[#d4af37] to-[#806000] shadow-xl transform -rotate-[5deg] origin-top -translate-x-2" style={{ clipPath: "polygon(0 0, 100% 0, 100% 100%, 50% 85%, 0 100%)" }}>
                <div className="absolute left-2 top-0 bottom-0 w-[4px] bg-[#8a1c1c]/90 shadow-sm"></div>
                <div className="absolute right-2 top-0 bottom-0 w-[4px] bg-[#8a1c1c]/90 shadow-sm"></div>
              </div>
            </div>

            {/* Gold seal */}
            <div className="w-56 h-56 rounded-full overflow-hidden shadow-[0_20px_40px_rgba(0,0,0,0.9)] transform -rotate-12 border-4 border-[#d4af37] relative z-20 bg-white flex items-center justify-center pointer-events-auto">
              <img src="/assets/images/gold_seal.png" alt="Gold Seal" className="w-full h-full object-cover scale-[1.15]" />
            </div>
          </div>
          
        </div>
      </div>

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
