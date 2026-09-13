"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc, collection, query, where, onSnapshot, runTransaction, serverTimestamp } from "firebase/firestore";
import { useParams, useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { motion, AnimatePresence } from "framer-motion";
import {
  Calendar, Clock, Award, ShieldCheck, CheckCircle2,
  ArrowLeft, Loader2, Users, Star, BookOpen,
  Info, Lock, Layout, Pencil, PenTool, Type, Droplets, Ruler, Book, Laptop, Sparkles,
  Apple, Play, Video, ChevronDown
} from "lucide-react";
import Link from "next/link";
import { createCheckoutSession } from "@/app/actions/payment";
import { formatImageUrl } from "@/lib/utils";
import { getFlagFromPhoneNumber } from "@/lib/countryUtils";
import { useTranslation } from "@/hooks/useTranslation";
import { translateText } from "@/lib/translateText";
import AutoTranslatedText from "@/components/AutoTranslatedText";

// --- ICON REGISTRY MATCHING APP ---
const ICON_REGISTRY: Record<string, any> = {
  pen: Pencil,
  brush: Sparkles,
  paper: Layout,
  ink: Droplets,
  ruler: Ruler,
  book: Book,
  laptop: Laptop,
  generic: Star,
  architecture: Layout,
  build: PenTool,
};

function CollapsibleSection({ 
  title, 
  icon: Icon, 
  defaultExpanded = false, 
  children,
  isSmallTitle = false
}: { 
  title: string; 
  icon: any; 
  defaultExpanded?: boolean; 
  children: React.ReactNode;
  isSmallTitle?: boolean;
}) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);

  return (
    <motion.section
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      className="mb-12 relative"
    >
      <button 
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full flex items-center gap-6 mb-2 group outline-none"
      >
        <div className={`flex items-center justify-center shadow-[0_0_20px_rgba(238,229,147,0.1)] group-hover:scale-110 transition-transform shrink-0 ${isSmallTitle ? '' : 'w-12 h-12 rounded-2xl bg-primary/10 border border-primary/20'}`}>
          <Icon className={`${isSmallTitle ? 'w-6 h-6 -[0_0_8px_currentColor]' : 'w-6 h-6'} text-primary`} />
        </div>
        <h3 className={`${isSmallTitle ? 'text-sm tracking-[0.3em]' : 'text-xl tracking-tighter'} font-black font-outfit uppercase text-white/90 group-hover:text-primary transition-colors text-left`}>
          {title}
        </h3>
        <div className="flex-grow h-[1px] bg-gradient-to-r from-white/10 to-transparent" />
        <div className={`w-10 h-10 rounded-full bg-white/5 flex items-center justify-center border border-white/10 transition-transform duration-500 shrink-0 ${isExpanded ? 'rotate-180 bg-white/10' : ''}`}>
          <ChevronDown className="w-5 h-5 text-white/50 group-hover:text-white transition-colors" />
        </div>
      </button>

      <AnimatePresence initial={false}>
        {isExpanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.5, ease: [0.04, 0.62, 0.23, 0.98] }}
            className="overflow-hidden"
          >
            <div className="pt-6 pb-2">
              {children}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.section>
  );
}

export default function CourseDetailsPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [teacher, setTeacher] = useState<any>(null);
  const [teacherCourseCount, setTeacherCourseCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const [title, setTitle] = useState("Untitled Course");
  const [desc, setDesc] = useState("No description available.");
  const router = useRouter();
  const { t, locale } = useTranslation();

  // Handle Translations explicitly like CourseCard
  useEffect(() => {
    if (!course) return;
    const rawTitle = course.courseName || course.courseTitle || "Untitled Course";
    const rawDesc = course.courseDescription || course.description || "No description available.";
    
    setTitle(rawTitle);
    setDesc(rawDesc);

    if (locale !== "ar") {
      if (rawTitle) translateText(rawTitle, locale, "ar").then(setTitle);
      if (rawDesc) translateText(rawDesc, locale, "ar").then(setDesc);
    }
  }, [course, locale]);

  useEffect(() => {
    if (!id) return;

    const fetchCourse = async () => {
      try {
        const docRef = doc(db, "courses", id as string);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          const courseData: any = docSnap.data();
          const data = { id: docSnap.id, ...courseData };
          setCourse(data);

          // Check Enrollment
          const user = auth.currentUser;
          if (user && courseData.enrolledStudents?.includes(user.uid)) {
            setIsEnrolled(true);
          }

          // Fetch Teacher Details
          if (data.teacherId) {
            const tRef = doc(db, "users", data.teacherId);
            const tSnap = await getDoc(tRef);
            if (tSnap.exists()) {
              setTeacher(tSnap.data());
            }

            // Fetch Teacher Course Count
            const q = query(collection(db, "courses"), where("teacherId", "==", data.teacherId));
            const unsubscribeCount = onSnapshot(q, (snapshot) => {
              setTeacherCourseCount(snapshot.size);
            });
            return () => unsubscribeCount();
          }
        }
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchCourse();
  }, [id]);

  const formatDate = (ts: any) => {
    if (!ts) return "TBD";
    const date = ts.toDate ? ts.toDate() : new Date(ts);
    const targetLocale = locale === 'ar' ? 'ar-EG' : locale === 'tr' ? 'tr-TR' : 'en-US';
    return date.toLocaleDateString(targetLocale, { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const formatTime = (ts: any) => {
    if (!ts) return "TBD";
    const date = ts.toDate ? ts.toDate() : new Date(ts);
    const targetLocale = locale === 'ar' ? 'ar-EG' : locale === 'tr' ? 'tr-TR' : 'en-US';
    return date.toLocaleTimeString(targetLocale, { hour: 'numeric', minute: '2-digit', hour12: true });
  };

  const handleBuyNow = async () => {
    try {
      const user = auth.currentUser;
      if (!user) {
        router.push(`/login?redirect=/courses/${id}`);
        return;
      }

      setJoining(true);
      setError(null);

      const studentPriceCents = Math.round(((Number(course.price || 0) * 100) / 2) * 1.08);
      const courseName = course.courseName || course.courseTitle || "Untitled Course";
      const bannerUrl = formatImageUrl(course.courseBanner || course.thumbnailUrl);
      const teacherUrl = formatImageUrl(teacher?.photoUrl || course.teacherProfilePic);

      // Use the clean, simplified description to allow dashboard media to show
      const cleanDescription = t("course.payment_desc");
      
      const result = await createCheckoutSession(
        course.lemonSqueezyVariantId,
        user.uid,
        id as string,
        user.email || "",
        courseName,
        studentPriceCents,
        cleanDescription,
        [] // Pass empty array to favor Dashboard images
      );

      if (result.error) {
        setError(result.error);
        setJoining(false);
        return;
      }

      if (!result.checkoutUrl) throw new Error("Failed to generate checkout URL");
      window.location.href = result.checkoutUrl;
    } catch (err: any) {
      console.error("Payment Error:", err);
      setError(err.message || "Failed to initiate payment. Please try again.");
      setJoining(false);
    }
  };

  const handleAdminBypass = async () => {
    if (process.env.NODE_ENV !== "development") return;
    try {
      const user = auth.currentUser;
      if (!user) {
        router.push("/login");
        return;
      }
      setJoining(true);
      setError(null);
      
      await runTransaction(db, async (transaction) => {
        const courseRef = doc(db, "courses", id as string);
        const transactionRef = doc(collection(db, "transactions"));
        const courseSnap = await transaction.get(courseRef);
        if (!courseSnap.exists()) throw new Error("Course not found");

        const courseData = courseSnap.data()!;
        const enrolledStudents = Array.isArray(courseData.enrolledStudents) ? [...courseData.enrolledStudents] : [];
        if (!enrolledStudents.includes(user.uid)) {
          enrolledStudents.push(user.uid);
          transaction.update(courseRef, {
            enrolledStudents,
            enrolledCount: enrolledStudents.length
          });
          transaction.set(transactionRef, {
            studentId: user.uid,
            studentName: user.displayName || user.email?.split('@')[0] || t("nav.student_login").split(' ')[0],
            teacherId: courseData.teacherId || '',
            courseId: id as string,
            amount: 0,
            status: 'completed',
            source: 'admin_bypass',
            createdAt: serverTimestamp(),
          });
        }
      });
      setIsEnrolled(true);
      setJoining(false);
    } catch (err: any) {
      console.error(err);
      setError(`Bypass failed: ${err.message}`);
      setJoining(false);
    }
  };

  const mapLevel = (level: string) => {
    const l = level?.toLowerCase() || "";
    if (l.includes("begin")) return "categories.beginner";
    if (l.includes("inter")) return "categories.intermediate";
    if (l.includes("advanc")) return "categories.advanced";
    return l ? "categories." + l : "categories.all";
  };

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

  const lessons = course.curriculumSteps || course.lessons || course.sections || [];
  const tools = course.requiredTools || [];
  const avgRating = teacher ? (teacher.totalStars / (teacher.reviewCount || 1)).toFixed(1) : "0.0";

  let isEnded = false;
  if (course.endDate) {
    const end = course.endDate.toDate ? course.endDate.toDate() : new Date(course.endDate);
    const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    if (today > endDay) {
      isEnded = true;
    }
  }

  const enrolledCount = course.enrolledStudents?.length || 0;
  const isFull = course.maxStudents > 0 && enrolledCount >= course.maxStudents;

  return (
    <main className="min-h-screen academy-bg pb-40">
      <Navbar />

      {/* CINEMATIC HERO SECTION */}
      <section className="relative pt-32 px-6">
        <div className="max-w-7xl mx-auto">
          {/* Hero Banner Container */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, ease: [0.23, 1, 0.32, 1] }}
            className="relative h-[450px] md:h-[650px] w-full rounded-[3.5rem] overflow-hidden shadow-[0_50px_100px_-20px_rgba(0,0,0,0.9)] border border-white/10 group/hero"
          >
            {/* Background Image with Zoom Effect */}
            <div className="absolute inset-0 transition-transform duration-[4000ms] ease-out group-hover/hero:scale-110">
              {course.courseBanner ? (
                <img 
                  src={formatImageUrl(course.courseBanner)} 
                  alt={course.courseTitle} 
                  className="w-full h-full object-cover grayscale-[20%] group-hover/hero:grayscale-0 transition-all duration-1000"
                />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-[#1a1a1a] to-black" />
              )}
            </div>

            {/* Overlays */}
            <div className="absolute inset-0 bg-gradient-to-t from-black via-black/40 to-black/20" />
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,rgba(0,0,0,0.4)_100%)]" />

            {/* Bottom Content Overlay */}
            <div className="absolute inset-x-0 bottom-0 p-8 md:p-14 md:pb-32 bg-gradient-to-t from-black via-black/90 to-transparent flex flex-col items-center">
              <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.4 }}
                className="flex flex-col gap-16 md:gap-24 items-center text-center w-full"
              >
                {/* Course Name - Higher, Smaller, No Italic */}
                <div className="space-y-6">
                  <h1 className="text-3xl md:text-5xl lg:text-7xl font-black font-outfit text-white uppercase tracking-tighter leading-[0.85] max-w-5xl [text-shadow:0_10px_40px_rgba(0,0,0,0.6)]">
                    {title}
                  </h1>
                  <div className="h-1 w-24 bg-primary mx-auto rounded-full shadow-[0_0_20px_#EEE593] opacity-60" />
                </div>

                {/* Metadata Row: Level | Teacher | Price - Centered & Enhanced visibility */}
                <div className="flex flex-wrap items-center justify-center gap-6 md:gap-16">
                  {/* Course Level */}
                  <div className="flex flex-col items-center gap-3">
                    <span className="text-[10px] font-black text-primary uppercase tracking-[0.4em] mb-1">{t("nav.courses")}</span>
                    <div className="glass-premium px-6 py-2.5 rounded-2xl border-white/5 bg-white/[0.03] flex items-center gap-3">
                      <div className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse shadow-[0_0_10px_#EEE593]" />
                      <span className="text-xs font-black uppercase tracking-[0.2em] text-primary">
                        {t(mapLevel(course.selectedCategory))}
                      </span>
                    </div>
                  </div>

                  <div className="w-[1.5px] h-12 bg-gradient-to-b from-transparent via-primary/40 to-transparent hidden md:block" />

                  {/* Teacher & Image */}
                  <div className="flex flex-col items-center gap-3">
                    <span className="text-[10px] font-black text-primary uppercase tracking-[0.4em] mb-1">{t("course.instructor")}</span>
                    <div className="flex items-center gap-4 group/teacher cursor-default">
                      <div className="relative w-12 h-12 shrink-0">
                        <img 
                          src={formatImageUrl(teacher?.profileImage || course.teacherProfilePic)} 
                          className="w-full h-full object-cover rounded-xl border border-white/20 shadow-2xl"
                          alt="Instructor"
                        />
                        <div className="absolute -top-1 -right-1 w-5 h-5 bg-primary rounded-full flex items-center justify-center border-2 border-black">
                          <CheckCircle2 className="w-3 h-3 text-black" />
                        </div>
                      </div>
                      <span className="text-xl font-black text-white tracking-tighter font-outfit uppercase">
                        {teacher?.name || course.teacherName}
                      </span>
                    </div>
                  </div>

                  <div className="w-[1.5px] h-12 bg-gradient-to-b from-transparent via-primary/40 to-transparent hidden md:block" />

                  {/* Course Price */}
                  <div className="flex flex-col items-center gap-3">
                    <span className="text-[10px] font-black text-primary uppercase tracking-[0.4em] mb-1">Total</span>
                    <div className="flex flex-col items-center">
                      <div className="flex items-center gap-4">
                        <span className="text-white/20 text-sm font-bold line-through">
                          ${(Number(course.price) * 1.08).toFixed(0)}
                        </span>
                        <div className="flex items-center gap-2">
                          <span className="text-4xl font-black font-outfit text-primary tracking-tighter">
                            ${((Number(course.price) / 2) * 1.08).toFixed(0)}
                          </span>
                          <span className="text-[9px] font-black text-black bg-primary px-2 py-1 rounded-full shadow-[0_0_15px_rgba(238,229,147,0.3)]">
                            -50%
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            </div>
          </motion.div>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-6 mt-20 flex flex-col xl:flex-row gap-16 items-start">

        {/* Left Content */}
        <div className="flex-grow w-full max-w-4xl space-y-16">

          {/* Unified Stats Row */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="grid grid-cols-3 py-10 border-y border-white/10 bg-gradient-to-r from-transparent via-white/[0.02] to-transparent rounded-[32px]"
          >
            <div className="flex flex-col items-center justify-center text-center">
              <span className="text-4xl md:text-5xl font-black font-outfit text-white ">{teacher?.followerCount || 0}</span>
              <span className="text-[10px] text-primary/60 font-black uppercase tracking-[0.3em] mt-3">{t("course.students")}</span>
            </div>
            <div className="flex flex-col items-center justify-center text-center border-x border-white/10">
              <div className="flex items-center gap-2">
                <Star className="w-8 h-8 text-primary fill-primary -[0_0_15px_rgba(238,229,147,0.4)]" />
                <span className="text-4xl md:text-5xl font-black font-outfit text-white ">{avgRating}</span>
              </div>
              <span className="text-[10px] text-primary/60 font-black uppercase tracking-[0.3em] mt-3">{t("course.rating")}</span>
            </div>
            <div className="flex flex-col items-center justify-center text-center">
              <span className="text-4xl md:text-5xl font-black font-outfit text-white ">{teacherCourseCount}</span>
              <span className="text-[10px] text-primary/60 font-black uppercase tracking-[0.3em] mt-3">{t("course.courses")}</span>
            </div>
          </motion.div>

          {/* Description */}
          <CollapsibleSection title={t("course.description")} icon={Info} isSmallTitle={true} defaultExpanded={true}>
            <p className="text-lg md:text-xl text-white/50 leading-[1.8] font-medium whitespace-pre-wrap text-start px-2">
              {desc}
            </p>
          </CollapsibleSection>

          {/* Schedule Section */}
          <CollapsibleSection title={t("course.schedule")} icon={Calendar} defaultExpanded={false}>

            <div className="glass-premium rounded-[3.5rem] p-10 md:p-14 border border-white/10 shadow-2xl bg-black/40 backdrop-blur-3xl overflow-hidden group/schedule relative">
              {/* Artistic Background Accent */}
              <div className="absolute -top-20 -right-20 w-64 h-64 bg-primary/5 rounded-full blur-[100px] pointer-events-none" />
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-12 relative z-10">
                <div className="space-y-10">
                  <div className="flex items-center gap-6 group/item">
                    <div className="w-16 h-16 rounded-3xl bg-white/5 flex items-center justify-center border border-white/10 transition-colors group-hover/item:border-primary/40 group-hover/item:bg-primary/5">
                      <Calendar className="w-7 h-7 text-white/20 group-hover/item:text-primary transition-colors" />
                    </div>
                    <div>
                      <p className="text-[10px] text-primary font-black uppercase tracking-[0.3em] mb-2">{t("course.start_date")}</p>
                      <p className="text-2xl font-black font-outfit text-white tracking-tight">{formatDate(course.startDate)}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-6 group/item">
                    <div className="w-16 h-16 rounded-3xl bg-white/5 flex items-center justify-center border border-white/10 transition-colors group-hover/item:border-primary/40 group-hover/item:bg-primary/5">
                      <Clock className="w-7 h-7 text-white/20 group-hover/item:text-primary transition-colors" />
                    </div>
                    <div>
                      <p className="text-[10px] text-primary font-black uppercase tracking-[0.3em] mb-2">{t("course.start_time")}</p>
                      <p className="text-2xl font-black font-outfit text-white tracking-tight">{formatTime(course.startTime)}</p>
                    </div>
                  </div>
                </div>

                <div className="space-y-10">
                  <div className="flex items-center gap-6 group/item">
                    <div className="w-16 h-16 rounded-3xl bg-white/5 flex items-center justify-center border border-white/10 transition-colors group-hover/item:border-primary/40 group-hover/item:bg-primary/5">
                      <Calendar className="w-7 h-7 text-white/20 group-hover/item:text-primary transition-colors" />
                    </div>
                    <div>
                      <p className="text-[10px] text-primary font-black uppercase tracking-[0.3em] mb-2">{t("course.end_date")}</p>
                      <p className="text-2xl font-black font-outfit text-white tracking-tight">{formatDate(course.endDate)}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-6 group/item">
                    <div className="w-16 h-16 rounded-3xl bg-white/5 flex items-center justify-center border border-white/10 transition-colors group-hover/item:border-primary/40 group-hover/item:bg-primary/5">
                      <Clock className="w-7 h-7 text-white/20 group-hover/item:text-primary transition-colors" />
                    </div>
                    <div>
                      <p className="text-[10px] text-primary font-black uppercase tracking-[0.3em] mb-2">{t("course.end_time")}</p>
                      <p className="text-2xl font-black font-outfit text-white tracking-tight">{formatTime(course.endTime)}</p>
                    </div>
                  </div>
                </div>
              </div>

              <div className="mt-16 pt-12 border-t border-white/10">
                <div className="flex flex-col md:flex-row items-start md:items-center gap-8 group/sessions">
                  <div className="w-20 h-20 rounded-[2.5rem] bg-primary/10 flex items-center justify-center border border-primary/30 shadow-[0_15px_35px_-10px_rgba(238,229,147,0.2)] group-hover/sessions:scale-110 transition-transform">
                    <Layout className="w-10 h-10 text-primary" />
                  </div>
                  <div className="space-y-2">
                    <span className="text-sm font-bold text-white/40 uppercase tracking-[0.2em] block">
                      {t("course.weekly_sessions")}
                    </span>
                    <h4 className="text-3xl md:text-4xl font-black font-outfit text-white tracking-tighter">
                      {(course.selectedDays || []).map((day: string) => t(`days.${day.toLowerCase()}`)).join(", ") || "TBD"}
                    </h4>
                  </div>
                </div>
              </div>
            </div>
          </CollapsibleSection>

          {/* Curriculum */}
          <CollapsibleSection title={t("course.curriculum")} icon={BookOpen} defaultExpanded={false}>

            <div className="space-y-6">
              {lessons.length > 0 ? lessons.map((lesson: any, i: number) => {
                const title = lesson.title || lesson.toString();
                return (
                  <motion.div
                    key={i}
                    whileHover={{ x: 10 }}
                    className="glass-premium p-8 rounded-[2.5rem] flex items-center gap-8 border border-white/5 hover:border-primary/30 transition-all duration-500 bg-black/20 group/step cursor-default overflow-hidden relative"
                  >
                    <div className="w-16 h-16 rounded-2xl bg-white/5 flex items-center justify-center border border-white/10 group-hover/step:bg-primary group-hover/step:border-primary transition-all duration-500 shrink-0">
                      <span className="text-2xl font-black font-outfit text-white/20 group-hover/step:text-black transition-colors">
                        {(i + 1).toString().padStart(2, '0')}
                      </span>
                    </div>
                    <div className="flex-grow">
                      <h4 className="text-xl font-bold text-white group-hover:text-primary transition-colors">
                        <AutoTranslatedText text={title} />
                      </h4>
                    </div>
                    <Lock className="w-6 h-6 text-white/10 group-hover:text-primary/40 transition-colors shrink-0" />
                  </motion.div>
                );
              }) : (
                <div className="text-center py-24 glass-premium rounded-[3rem] text-white/20 text-xl border-white/5 bg-black/10 overflow-hidden relative">
                  {t("course.curriculum_coming")}
                </div>
              )}
            </div>
          </CollapsibleSection>

          {/* Tools Needed */}
          <CollapsibleSection title={t("course.tools")} icon={PenTool} defaultExpanded={false}>
            
            <div className="flex flex-wrap gap-6">
              {tools.length > 0 ? tools.map((tool: any, i: number) => {
                const ToolIcon = ICON_REGISTRY[tool.icon] || PenTool;
                return (
                  <motion.div 
                    key={i}
                    whileHover={{ scale: 1.05, y: -5 }}
                    className="glass-premium px-8 py-6 rounded-[2rem] flex items-center gap-6 border border-white/5 hover:border-primary/40 transition-all duration-500 bg-white/[0.02] shadow-xl overflow-hidden relative"
                  >
                    <div className="w-12 h-12 rounded-2xl bg-white/5 flex items-center justify-center border border-white/10 text-primary group-hover:scale-110 transition-transform">
                      <ToolIcon className="w-6 h-6" />
                    </div>
                    <span className="font-black text-white/90 tracking-tight text-lg">
                      <AutoTranslatedText text={tool.name} />
                    </span>
                  </motion.div>
                );
              }) : (
                <div className="text-xl text-white/20 px-6 font-medium bg-white/5 py-8 rounded-[2rem] border border-white/5">
                  {t("course.no_tools")}
                </div>
              )}
            </div>
          </CollapsibleSection>
        </div>

        {/* Right Sticky Checkout Card */}
        <div className="w-full xl:w-[400px] shrink-0 mb-20 xl:mb-0">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="sticky top-32 glass-premium rounded-[3rem] p-1 border border-white/10 shadow-[0_30px_100px_-20px_rgba(238,229,147,0.15)] bg-gradient-to-b from-black/80 to-[#0a0a0a]/90 backdrop-blur-3xl overflow-hidden group/pay"
          >
            {/* Animated Golden Pulse Background */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[300px] h-[300px] bg-primary/20 rounded-full blur-[120px] pointer-events-none group-hover/pay:bg-primary/30 transition-all duration-1000" />
            
            <div className="relative z-10 bg-[#0A0A0A]/80 backdrop-blur-xl rounded-[2.8rem] p-8 md:p-10 h-full flex flex-col border border-white/5 shadow-2xl">
              {isEnrolled ? (
                <div className="flex flex-col items-center text-center mb-8">
                  <div className="w-16 h-16 rounded-full bg-emerald-500/10 flex items-center justify-center border border-emerald-500/20 mb-4 shadow-[0_0_30px_rgba(16,185,129,0.1)]">
                    <CheckCircle2 className="w-8 h-8 text-emerald-400" />
                  </div>
                  <span className="text-sm font-black text-white/50 tracking-[0.2em] uppercase mb-1">
                    {t("course.enrolled")}
                  </span>
                  <h2 className="text-3xl font-black font-outfit text-primary tracking-tighter uppercase">
                    {t("course.lifetime_access")}
                  </h2>
                </div>
              ) : (
                <div className="text-center mb-8">
                  <div className="mb-8 inline-flex flex-col items-center">
                    <div className="w-20 h-20 rounded-full bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center border border-primary/40 mb-4 shadow-[0_0_30px_rgba(238,229,147,0.2)]">
                      <Award className="w-10 h-10 text-primary drop-shadow-[0_0_15px_rgba(238,229,147,0.8)]" />
                    </div>
                  </div>

                  <div className="w-full text-start bg-white/[0.02] rounded-2xl p-6 border border-white/10 shadow-inner mb-6">
                    <div className="flex justify-between items-center text-sm font-medium mb-4">
                      <span className="text-white/60">{t("course.tuition_fee") || "Tuition"}</span>
                      <span className="text-white/90 font-outfit rtl:font-sans">${(Number(course.price) / 2).toFixed(2)}</span>
                    </div>
                    
                    <div className="flex justify-between items-center text-sm font-medium pb-5 border-b border-white/10 mb-5 relative group/tooltip">
                      <div className="flex items-center gap-2 cursor-help">
                        <span className="text-white/60">{t("course.platform_fee") || "Service Fee (8%)"}</span>
                        <Info className="w-4 h-4 text-white/30 group-hover/tooltip:text-primary transition-colors" />
                        <div className="absolute top-8 start-0 w-48 bg-[#111] border border-white/10 rounded-xl p-3 text-[10px] leading-relaxed text-white/70 shadow-2xl opacity-0 group-hover/tooltip:opacity-100 pointer-events-none transition-opacity z-50">
                          {t("course.fee_tooltip") || "Helps cover secure payment processing, global taxes, and platform maintenance."}
                        </div>
                      </div>
                      <span className="text-white/90 font-outfit rtl:font-sans">${((Number(course.price) / 2) * 0.08).toFixed(2)}</span>
                    </div>

                    <div className="flex flex-col items-center gap-2 pt-2">
                      <span className="text-[11px] font-black text-primary uppercase tracking-[0.3em]">{t("course.total_due") || "Total Due"}</span>
                      <div className="flex items-center gap-4">
                        <span className="text-white/30 text-lg font-bold line-through tracking-tighter">${(Number(course.price) * 1.08).toFixed(0)}</span>
                        <h2 className="text-5xl md:text-6xl font-black font-outfit rtl:font-sans text-white tracking-tighter drop-shadow-[0_10px_30_rgba(255,255,255,0.2)]">
                          ${((Number(course.price) / 2) * 1.08).toFixed(2)}
                        </h2>
                      </div>
                    </div>
                  </div>
                  
                  {/* Capacity Progress Bar */}
                  {(course.maxStudents > 0) && (
                    <div className="mt-8 w-full">
                      <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider mb-2">
                        <span className="text-white/40">
                          {course.enrolledStudents?.length || 0} {t("course.enrolled")}
                        </span>
                        <span className="text-primary">
                          {course.maxStudents} {t("course.max") || "Max"}
                        </span>
                      </div>
                      <div className="w-full h-1.5 bg-white/5 rounded-full overflow-hidden shadow-inner">
                        <motion.div 
                          initial={{ width: 0 }}
                          animate={{ width: `${Math.min(100, Math.round(((course.enrolledStudents?.length || 0) / course.maxStudents) * 100))}%` }}
                          transition={{ duration: 1, ease: "easeOut" }}
                          className="h-full bg-gradient-to-r from-primary/50 to-primary rounded-full"
                        />
                      </div>
                      {((course.maxStudents - (course.enrolledStudents?.length || 0)) <= 4) && (
                        <p className="text-center text-[10px] text-red-400 font-bold uppercase tracking-widest mt-3 animate-pulse">
                          {t("course.few_seats_left") || "Only a few seats left!"}
                        </p>
                      )}
                    </div>
                  )}
                </div>
              )}

              {/* Minimalist Feature List */}
              <div className="flex flex-col gap-5 mb-8">
                <div className="flex items-center gap-4 group/feature">
                  <ShieldCheck className="w-5 h-5 text-white/40 group-hover/feature:text-primary transition-colors" />
                  <span className="text-white/70 text-sm font-medium tracking-tight group-hover/feature:text-white transition-colors">{t("course.direct_enrollment")}</span>
                </div>
                {!isEnded && (
                  <div className="flex items-center gap-4 group/feature">
                    <Video className="w-5 h-5 text-white/40 group-hover/feature:text-primary transition-colors" />
                    <span className="text-white/70 text-sm font-medium tracking-tight group-hover/feature:text-white transition-colors">
                      {t("course.meet_feature")}
                    </span>
                  </div>
                )}
                <div className="flex items-center gap-4 group/feature">
                  <Award className="w-5 h-5 text-white/40 group-hover/feature:text-primary transition-colors" />
                  <span className="text-white/70 text-sm font-medium tracking-tight group-hover/feature:text-white transition-colors">{t("course.certified_instructor")}</span>
                </div>
              </div>

              {/* Actions Section */}
              <div className="mt-auto flex flex-col gap-4">
                {isEnrolled ? (
                  <>
                    {!isEnded && (course.calligroMeetLink || course.googleMeetLink) && (
                      <Link
                        href={`/courses/${id}/classroom`}
                        className="w-full flex items-center justify-center gap-3 py-4 rounded-[1.5rem] bg-white/5 border border-white/10 hover:bg-primary/10 hover:border-primary/30 hover:text-primary text-white transition-all group/join"
                      >
                        <Video className="w-5 h-5 group-hover/join:scale-110 transition-transform" />
                        <span className="uppercase tracking-widest font-black text-sm">{t("course.join_live")}</span>
                      </Link>
                    )}

                    {isEnded && (
                      <Link
                        href={`/courses/${id}/certificate`}
                        className="btn-gold w-full flex items-center justify-center gap-3 py-4 text-sm group/cert"
                      >
                        <Award className="w-5 h-5 group-hover/cert:rotate-12 transition-transform" />
                        <span className="uppercase tracking-widest font-black">{t("course.download_certificate")}</span>
                      </Link>
                    )}
                  </>
                ) : (
                  <>
                    {isFull ? (
                      <button
                        disabled
                        className="w-full text-lg py-4 rounded-[1.5rem] bg-white/5 border border-white/10 text-white/40 cursor-not-allowed font-black uppercase tracking-widest flex items-center justify-center gap-3"
                      >
                        <Lock className="w-5 h-5" />
                        {t("course.sold_out")}
                      </button>
                    ) : (
                      <button
                        onClick={handleBuyNow}
                        disabled={joining}
                        className="btn-gold w-full text-lg py-4 rounded-[1.5rem] shadow-[0_20px_50px_-10px_rgba(238,229,147,0.4)] disabled:opacity-50 group/buy flex items-center justify-center"
                      >
                        {joining ? (
                          <Loader2 className="w-6 h-6 animate-spin mx-auto" />
                        ) : (
                          <div className="flex items-center gap-3 group-hover/buy:scale-105 transition-transform">
                            <span className="font-black uppercase tracking-widest">{t("course.buy_now")}</span>
                            <Sparkles className="w-5 h-5 animate-pulse" />
                          </div>
                        )}
                      </button>
                    )}
                  </>
                )}

              </div>

              {process.env.NODE_ENV === "development" && !isEnrolled && (
                <button
                  onClick={handleAdminBypass}
                  disabled={joining}
                  className="w-full mt-6 py-3 bg-white/5 hover:bg-white/10 text-white/30 hover:text-white text-[10px] font-black uppercase tracking-[0.2em] rounded-2xl border border-white/10 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {joining ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShieldCheck className="w-4 h-4 text-green-500" />}
                  [ {t("course.admin_bypass")} ]
                </button>
              )}

              {error && (
                <p className="mt-4 text-center text-red-500 text-xs font-bold animate-pulse bg-red-500/10 py-2 rounded-xl border border-red-500/20">{error}</p>
              )}
            </div>
          </motion.div>
        </div>
      </div>
    </main>
  );
}
