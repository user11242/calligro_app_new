"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { CheckCircle2, PlayCircle } from "lucide-react";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";

export default function SuccessPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const { locale } = useTranslation();

  // Hardcoded Translations
  const content: any = {
    en: {
      title: "Enrollment Successful!",
      subtitle: "Welcome to the Academy. Your artistic journey starts now.",
      button: "Start Learning!",
      selected: "Selected Course",
      lessons: "LESSONS"
    },
    ar: {
      title: "تم التسجيل بنجاح!",
      subtitle: "مرحباً بك في الأكاديمية. رحلتك الفنية تبدأ الآن.",
      button: "ابدأ التعلم الآن!",
      selected: "الدورة المختارة",
      lessons: "درس"
    },
    tr: {
      title: "Kayıt Başarıyla Tamamlandı!",
      subtitle: "Akademiye hoş geldiniz. Sanatsal yolculuğunuz şimdi başlıyor.",
      button: "Öğrenmeye Başla!",
      selected: "Seçilen Kurs",
      lessons: "DERS"
    }
  };

  const l = content[locale as string] || content.en;

  useEffect(() => {
    if (!id) return;
    const fetchCourse = async () => {
      const docRef = doc(db, "courses", id as string);
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        setCourse({ id: docSnap.id, ...docSnap.data() });
      }
    };
    fetchCourse();
  }, [id]);

  return (
    <main className="min-h-screen bg-[#050505] text-white">
      <Navbar />

      <section className="pt-48 pb-32 px-6 flex flex-col items-center">
        <div className="max-w-xl w-full text-center py-12 px-8 bg-white/[0.02] border border-white/10 rounded-[40px]">
          
          {/* Flat Clean Icon */}
          <div className="w-20 h-20 bg-green-500/10 rounded-full flex items-center justify-center mb-10 mx-auto border border-green-500/20">
             <CheckCircle2 className="w-10 h-10 text-green-500" />
          </div>

          <h1 className="text-4xl md:text-5xl font-bold font-outfit mb-4">
             {l.title}
          </h1>
          
          <p className="text-white/40 text-lg mb-12">
             {l.subtitle}
          </p>

          {course && (
            <div className="p-6 rounded-2xl border border-white/5 bg-white/[0.01] mb-12 w-full text-left flex justify-between items-center group">
              <div>
                <p className="text-[11px] font-bold text-white/30 uppercase tracking-[2px] mb-1">{l.selected}</p>
                <h2 className="text-xl font-bold text-white font-outfit">{course.courseName || course.courseTitle}</h2>
              </div>
              <div className="flex items-center gap-2 text-white/20 text-xs font-bold bg-white/5 px-3 py-1.5 rounded-lg">
                 <PlayCircle className="w-4 h-4" />
                 {course.totalLessons || 0} {l.lessons}
              </div>
            </div>
          )}

          <Link 
            href={`/courses/${id}/classroom`}
            className="w-full py-5 bg-[#EEB107] text-black font-bold uppercase tracking-[2px] text-sm rounded-2xl transition-all flex items-center justify-center gap-2"
          >
             {l.button}
          </Link>

        </div>
      </section>

      <Footer />
    </main>
  );
}
