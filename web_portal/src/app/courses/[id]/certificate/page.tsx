"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import { useParams, useRouter } from "next/navigation";
import { Loader2, Printer, ArrowLeft, Download } from "lucide-react";
import { useTranslation } from "@/hooks/useTranslation";
import Link from "next/link";
import { formatImageUrl } from "@/lib/utils";

import { Great_Vibes } from "next/font/google";

const greatVibes = Great_Vibes({ weight: "400", subsets: ["latin"] });

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
        pixelRatio: 3, // equivalent to scale: 3 for high res
        style: {
          transform: 'scale(1)', // capture at normal scale
          transformOrigin: 'top left'
        },
        cacheBust: true,
      });
      
      // Create landscape A4 PDF: 297mm x 210mm
      const pdf = new jsPDF({
        orientation: "landscape",
        unit: "mm",
        format: "a4"
      });
      
      pdf.addImage(imgData, "PNG", 0, 0, 297, 210);
      pdf.save("Calligro Certificate.pdf");
    } catch (error) {
      console.error("Error generating certificate PDF:", error);
    } finally {
      setDownloading(false);
    }
  };

  useEffect(() => {
    if (!id) return;
    
    // Quick auth check
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
      <Loader2 className="w-12 h-12 text-primary animate-spin" />
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
  const dateStr = new Date().toLocaleDateString(locale === 'ar' ? 'ar-SA' : 'en-US', { year: 'numeric', month: 'long', day: 'numeric' });

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
    <div className="min-h-screen bg-[#050505] flex flex-col items-center py-10 print:py-0 print:bg-white overflow-x-hidden">
      
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

      {/* Certificate Container (A4 Landscape aspect ratio approx) */}
      <div 
        id="print-area"
        className="w-[1123px] h-[794px] max-w-[100vw] sm:max-w-[90vw] md:max-w-[1123px] bg-white relative overflow-hidden flex flex-col items-center justify-center shadow-2xl print:w-[1123px] print:h-[794px] print:shadow-none print:max-w-none origin-top"
        style={{
          boxSizing: 'border-box',
          border: '20px solid #1a1a1a',
          transform: 'scale(0.9)',
        }}
        dir={locale === 'ar' ? 'rtl' : 'ltr'}
      >
        {/* Background Patterns */}
        <div className="absolute inset-0 border-[10px] border-[#d4af37] m-4 pointer-events-none opacity-100" />
        
        {/* Corner Ornaments */}
        <div className="absolute top-8 left-8 w-16 h-16 border-t-4 border-l-4 border-[#d4af37]" />
        <div className="absolute top-8 right-8 w-16 h-16 border-t-4 border-r-4 border-[#d4af37]" />
        <div className="absolute bottom-8 left-8 w-16 h-16 border-b-4 border-l-4 border-[#d4af37]" />
        <div className="absolute bottom-8 right-8 w-16 h-16 border-b-4 border-r-4 border-[#d4af37]" />

        <div className="relative z-10 flex flex-col items-center text-center w-full max-w-4xl px-12 mt-4">
          
          {/* Logo Placeholder */}
          <div className="w-24 h-24 mb-6 mt-8 flex items-center justify-center rounded-full border-2 border-[#d4af37] p-2 bg-black shadow-lg">
             <img src="/assets/images/Logo.png" alt="Calligro" className="w-16 h-16 object-contain" />
          </div>

          <h1 className="text-5xl md:text-6xl font-black text-[#1a1a1a] mb-8 font-playfair uppercase tracking-widest text-balance leading-tight">
            {t("certificate.title")}
          </h1>
          
          <p className="text-lg md:text-xl text-gray-600 font-medium italic mb-6 font-serif">
            {t("certificate.presented_to")}
          </p>

          <h2 className="text-4xl md:text-5xl font-bold text-[#d4af37] mb-8 font-marhey px-12 py-3 border-b-2 border-dashed border-[#d4af37]/50 w-3/4">
            {studentName}
          </h2>

          <p className="text-lg md:text-xl text-gray-600 font-medium italic mb-6 font-serif">
            {t("certificate.for_completing")}
          </p>

          <h3 className="text-3xl md:text-4xl font-bold text-[#1a1a1a] mb-4 font-amiri text-balance">
            {courseName}
          </h3>
          
          {totalHours && (
            <div className="flex items-center gap-6 mb-10 mt-4">
              <div className="h-px w-32 bg-gradient-to-r from-transparent via-[#d4af37] to-[#d4af37]" />
              <p className="text-xl md:text-2xl text-[#d4af37] font-bold tracking-widest uppercase font-serif">
                {t("certificate.comprising")} <span className="font-black px-1 text-[#1a1a1a]">{totalHours}</span> {t("certificate.training_hours")}
              </p>
              <div className="h-px w-32 bg-gradient-to-l from-transparent via-[#d4af37] to-[#d4af37]" />
            </div>
          )}
          {!totalHours && <div className="mb-10"></div>}

          {/* Footer Details */}
          <div className="w-full flex justify-between items-end px-4 border-t-2 border-[#1a1a1a]/10 pt-6 mt-4">
            
            {/* Column 1: Teacher */}
            <div className="flex flex-col items-center w-48">
              {teacher?.signatureUrl ? (
                <img src={formatImageUrl(teacher.signatureUrl)} alt="Signature" className="h-16 object-contain mb-2 mix-blend-multiply" />
              ) : (
                <span className="text-[#d4af37] font-playfair italic text-3xl mb-2">{teacherName}</span>
              )}
              <div className="w-full h-px bg-gray-400 mb-2" />
              <span className="text-gray-500 uppercase tracking-widest text-xs font-semibold text-center">{t("certificate.instructor")}</span>
            </div>

            {/* Column 2: Date */}
            <div className="flex flex-col items-center w-40">
              <span className="text-gray-800 font-bold text-xl mb-2 font-marhey">{dateStr}</span>
              <div className="w-full h-px bg-gray-400 mb-2" />
              <span className="text-gray-500 uppercase tracking-widest text-xs font-semibold text-center">{t("certificate.date")}</span>
            </div>
            
            {/* Column 3: Director Signature */}
            <div className="flex flex-col items-center w-48 relative">
              <img src="/assets/images/yazan_signature.png" alt="Yazan Qattous Signature" className="h-40 object-contain absolute -bottom-1 drop-shadow-md mix-blend-multiply" />
              <div className="w-full h-px bg-gray-400 mb-2 mt-20" />
              <span className="text-gray-500 uppercase tracking-widest text-xs font-semibold text-center">{t("certificate.academy_director")}</span>
            </div>

          </div>

          <div className="mt-12 text-xs text-gray-400 tracking-wider">
            {t("certificate.verify")} • ID: {id?.slice(0, 8).toUpperCase()}
          </div>
        </div>
      </div>

      <style dangerouslySetInnerHTML={{__html: `
        @media print {
          body * {
            visibility: hidden;
          }
          #print-area, #print-area * {
            visibility: visible;
          }
          #print-area {
            position: absolute !important;
            left: 0 !important;
            top: 0 !important;
            transform: scale(1) !important;
            border: 20px solid #1a1a1a !important;
          }
          @page {
            size: A4 landscape;
            margin: 0;
          }
        }
      `}} />
    </div>
  );
}
