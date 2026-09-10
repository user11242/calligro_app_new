"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { CheckCircle2, PlayCircle, Sparkles, ArrowRight, User } from "lucide-react";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";
import { motion } from "framer-motion";
import { formatImageUrl } from "@/lib/utils";
import Image from "next/image";

export default function SuccessPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [teacher, setTeacher] = useState<any>(null);
  const { locale } = useTranslation();

  // Hardcoded Translations
  const content: any = {
    en: {
      title: "Enrollment Successful!",
      subtitle: "Welcome to the Academy. Your artistic journey starts now.",
      button: "Start Learning!",
      selected: "Selected Course",
      lessons: "LESSONS",
      by: "by"
    },
    ar: {
      title: "تم التسجيل بنجاح!",
      subtitle: "مرحباً بك في الأكاديمية. رحلتك الفنية تبدأ الآن.",
      button: "ابدأ التعلم الآن!",
      selected: "الدورة المختارة",
      lessons: "درس",
      by: "بواسطة"
    },
    tr: {
      title: "Kayıt Başarıyla Tamamlandı!",
      subtitle: "Akademiye hoş geldiniz. Sanatsal yolculuğunuz şimdi başlıyor.",
      button: "Öğrenmeye Başla!",
      selected: "Seçilen Kurs",
      lessons: "DERS",
      by: "tarafından"
    }
  };

  const l = content[locale as string] || content.en;

  useEffect(() => {
    if (!id) return;
    const fetchCourseAndTeacher = async () => {
      const docRef = doc(db, "courses", id as string);
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        const courseData = { id: docSnap.id, ...docSnap.data() };
        setCourse(courseData);

        if (courseData.teacherId) {
          const tRef = doc(db, "users", courseData.teacherId);
          const tSnap = await getDoc(tRef);
          if (tSnap.exists()) {
            setTeacher(tSnap.data());
          }
        }
      }
    };
    fetchCourseAndTeacher();
  }, [id]);

  return (
    <main className="min-h-screen bg-transparent font-sans text-white relative overflow-hidden flex flex-col">
      {/* Background Ambient Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-green-500/10 rounded-full blur-[120px] pointer-events-none -z-10"></div>
      
      <Navbar />

      <section className="pt-40 pb-32 px-6 flex-1 flex flex-col items-center justify-center relative z-10">
        <motion.div 
          initial={{ opacity: 0, y: 30, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
          className="max-w-xl w-full text-center py-14 px-10 bg-white/[0.02] backdrop-blur-2xl border border-white/[0.08] rounded-[40px] shadow-2xl relative overflow-hidden group"
        >
          {/* Subtle shine effect on hover */}
          <div className="absolute inset-0 bg-gradient-to-tr from-white/0 via-white/[0.03] to-white/0 opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none"></div>

          {/* Animated Icon */}
          <motion.div 
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: "spring", stiffness: 200, damping: 15, delay: 0.2 }}
            className="relative w-24 h-24 mx-auto mb-8 flex items-center justify-center"
          >
            <div className="absolute inset-0 bg-green-500/20 rounded-full animate-ping opacity-50"></div>
            <div className="relative w-full h-full bg-gradient-to-b from-green-400/20 to-green-600/10 rounded-full flex items-center justify-center border border-green-500/30 shadow-[0_0_30px_rgba(34,197,94,0.3)]">
               <CheckCircle2 className="w-12 h-12 text-green-400" />
            </div>
            <Sparkles className="absolute -top-2 -right-2 w-6 h-6 text-green-300 animate-pulse" />
          </motion.div>

          <motion.h1 
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="text-4xl md:text-5xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-white via-white to-white/70"
          >
             {l.title}
          </motion.h1>
          
          <motion.p 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="text-white/50 text-lg mb-10 font-light"
          >
             {l.subtitle}
          </motion.p>

          {course && (
            <motion.div 
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="p-2 rounded-[24px] border border-white/10 bg-white/[0.03] mb-10 w-full relative overflow-hidden shadow-2xl flex items-center gap-4"
            >
              {/* Compact Course Banner */}
              <div className="relative w-28 h-28 md:w-32 md:h-32 rounded-[20px] overflow-hidden shrink-0 border border-white/5">
                {course.courseBanner || course.thumbnailUrl ? (
                  <img 
                    src={formatImageUrl(course.courseBanner || course.thumbnailUrl)} 
                    alt={course.courseName || course.courseTitle}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full bg-gradient-to-br from-white/10 to-white/5 flex items-center justify-center">
                    <PlayCircle className="w-8 h-8 text-white/20" />
                  </div>
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-[#0a0a0a]/60 to-transparent"></div>
              </div>

              {/* Course Info */}
              <div className="flex-1 py-1 pr-4 rtl:pr-0 rtl:pl-4 text-left rtl:text-right min-w-0">
                <p className="text-[10px] font-bold text-white/40 uppercase tracking-[2px] mb-1">{l.selected}</p>
                <h2 className="text-lg md:text-xl font-bold text-white mb-4 line-clamp-2">{course.courseName || course.courseTitle}</h2>
                
                {/* Teacher Info */}
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full overflow-hidden bg-white/10 border border-white/20 shrink-0 shadow-sm">
                    {(teacher?.profileImage || teacher?.photoUrl || course.teacherProfilePic) ? (
                      <img 
                        src={formatImageUrl(teacher?.profileImage || teacher?.photoUrl || course.teacherProfilePic)} 
                        alt="Instructor"
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full bg-white/10 flex items-center justify-center">
                        <User className="w-4 h-4 text-white/50" />
                      </div>
                    )}
                  </div>
                  <div className="flex flex-col text-left rtl:text-right min-w-0">
                    <span className="text-[9px] text-white/40 uppercase tracking-[1px] mb-0.5">{l.by}</span>
                    <strong className="text-xs text-white/90 font-bold truncate">{teacher?.name || course.teacherName || "Instructor"}</strong>
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6 }}
          >
            <Link 
              href={`/courses/${id}`}
              className="w-full py-5 bg-gradient-to-r from-[#eeb107] to-[#d69f05] hover:from-[#f5c63d] hover:to-[#eeb107] text-black font-bold uppercase tracking-[2px] text-[13px] rounded-2xl transition-all flex items-center justify-center gap-3 shadow-[0_10px_30px_rgba(238,177,7,0.2)] hover:shadow-[0_10px_40px_rgba(238,177,7,0.4)]"
            >
               {l.button}
               <ArrowRight className="w-4 h-4 rtl:rotate-180" />
            </Link>
          </motion.div>

        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
