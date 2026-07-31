"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
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
        if (docSnap.exists()) {
          const courseData = docSnap.data();
          setCourse(courseData);
          if (courseData.teacherId) {
            const tRef = doc(db, "users", courseData.teacherId);
            const tSnap = await getDoc(tRef);
            if (tSnap.exists()) {
              setTeacher(tSnap.data());
            }
          }
        }
      } catch (err) {
        console.error(err);
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
        className="w-[1123px] h-[794px] max-w-[100vw] sm:max-w-[90vw] md:max-w-[1123px] relative overflow-hidden flex flex-col bg-[#ffffff] shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top"
        style={{
          boxSizing: 'border-box',
          transform: 'scale(0.9)',
        }}
        dir="rtl" // Always RTL for Arabic certificate
      >
        
        {/* Large Central Faded Watermark Logo (like the reference) */}
        <div className="absolute inset-0 z-0 flex items-center justify-center opacity-[0.04] pointer-events-none">
          <img src="/assets/images/Logo.png" alt="Watermark" className="w-[500px] h-[500px] object-contain grayscale" />
        </div>

        {/* Top Banner exactly like the reference */}
        <div className="w-full h-32 bg-[#d4af37] flex items-center justify-between relative z-10">
           {/* Islamic Pattern SVG Background for the banner */}
           <div className="absolute inset-0 opacity-20" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23ffffff\' fill-opacity=\'1\'%3E%3Cpath d=\'M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")' }}></div>
           
           {/* Right side Logo & Text (First in DOM for RTL) */}
           <div className="flex items-center gap-4 px-8 z-20">
             <div className="w-20 h-20 flex items-center justify-center">
                <img src="/assets/images/Logo.png" alt="Calligro" className="w-20 h-20 object-contain drop-shadow-md" />
             </div>
             <div className="flex flex-col text-right">
               <span className="text-white text-3xl font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>أكاديمية كاليغرو</span>
               <span className="text-white text-sm opacity-90 font-sans tracking-widest">Calligro Calligraphy Academy</span>
             </div>
           </div>

           {/* Left side white block (Second in DOM for RTL) */}
           <div className="h-full w-[250px] bg-white flex flex-col items-center justify-center px-4 text-center z-20 shrink-0">
              <span className="text-[#1a1a1a] font-bold text-2xl" style={{ fontFamily: "'Aref Ruqaa', serif" }}>أكاديمية كاليغرو</span>
           </div>
        </div>

        {/* Inner Content - Right aligned flow like the reference */}
        <div className="relative z-20 flex flex-col w-full px-16 flex-1 pt-8 pb-4">
          
          {/* Certificate Title (Center) */}
          <div className="w-full text-center mb-8">
            <h1 className="text-7xl font-bold text-[#1a1a1a]" style={{ fontFamily: "'Diwani Letter', serif" }}>
              {t("certificate.title")}
            </h1>
          </div>
          
          {/* Main Body Text (Right Aligned Flow) */}
          <div className="w-full flex flex-col gap-6 text-[#1a1a1a] text-3xl" style={{ fontFamily: "'Aref Ruqaa', serif" }}>
            
            {/* Line 1: Certifies that */}
            <div className="flex items-center gap-4">
               <span className="shrink-0">{t("certificate.presented_to")}</span>
               <div className="flex-1 flex flex-col">
                  <span className="text-5xl text-center text-[#1a1a1a] pb-2 -mt-4" style={{ fontFamily: "'Diwani Letter', serif" }}>{studentName}</span>
                  <div className="w-full h-px bg-[#1a1a1a]"></div>
               </div>
            </div>

            {/* Line 2: Has completed */}
            <div className="flex items-center gap-4 mt-4">
               <span className="shrink-0">{t("certificate.for_completing")}</span>
               <div className="flex-1 flex flex-col">
                  <span className="text-4xl text-center text-[#1a1a1a] pb-2" style={{ fontFamily: "'Diwani Letter', serif" }}>{courseName}</span>
                  <div className="w-full h-px bg-[#1a1a1a]"></div>
               </div>
            </div>

            {/* Line 3: Details */}
            {totalHours && (
              <div className="flex items-center gap-2 mt-4">
                <span>{t("certificate.comprising")}</span>
                <span className="font-bold px-2" style={{ fontFamily: "sans-serif" }}>{totalHours}</span>
                <span>{t("certificate.training_hours")}</span>
              </div>
            )}
            
            {/* Added standard reference text if hours aren't enough */}
            <div className="flex justify-center mt-6">
              <span className="text-2xl">وبناءًا عليه مُنحت هذه الشهادة</span>
            </div>

          </div>

          {/* Spacer */}
          <div className="flex-1"></div>

          {/* Footer Details / Signatures (4 Columns like reference) */}
          <div className="w-full flex justify-between items-end mt-8 relative z-30 px-4">
            
            {/* Column 1: Date */}
            <div className="flex flex-col items-center w-40">
              <span className="text-[#1a1a1a] text-xl mb-4 font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>حرر في</span>
              <span className="text-[#1a1a1a] text-2xl mt-4" style={{ fontFamily: "'Aref Ruqaa', serif" }}>{dateStr}</span>
            </div>

            {/* Column 3: Teacher */}
            <div className="flex flex-col items-center w-40">
              <span className="text-[#1a1a1a] text-xl mb-4 font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>مدرب الدورة</span>
              {teacher?.signatureUrl ? (
                <img src={formatImageUrl(teacher.signatureUrl)} alt="Signature" className="h-16 object-contain mix-blend-multiply" />
              ) : (
                <span className="text-[#1a1a1a] text-3xl mt-4" style={{ fontFamily: "'Diwani Letter', serif" }}>{teacherName}</span>
              )}
            </div>
            
            {/* Column 4: Director */}
            <div className="flex flex-col items-center w-40 relative">
              <span className="text-[#1a1a1a] text-xl mb-4 font-bold" style={{ fontFamily: "'Aref Ruqaa', serif" }}>المدير التنفيذي</span>
              <img src="/assets/images/yazan_signature.png" alt="Yazan Qattous Signature" className="h-20 object-contain absolute top-8 mix-blend-multiply" />
              <span className="text-[#1a1a1a] text-xl mt-8" style={{ fontFamily: "'Aref Ruqaa', serif" }}>يزن قطوس</span>
            </div>

          </div>
        </div>

        {/* Bottom Banner exactly like the reference */}
        <div className="w-full h-24 bg-[#d4af37] flex items-center justify-center relative z-10">
           <div className="absolute inset-0 opacity-20" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23ffffff\' fill-opacity=\'1\'%3E%3Cpath d=\'M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")' }}></div>
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
