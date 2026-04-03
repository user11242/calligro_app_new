"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc, collection, query, where, onSnapshot } from "firebase/firestore";
import { useParams, useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { motion } from "framer-motion";
import { 
  Calendar, Clock, Award, ShieldCheck, CheckCircle2, 
  ArrowLeft, Loader2, Users, Star, BookOpen, 
  Info, Lock, Layout, Pencil, PenTool, Type, Droplets, Ruler, Book, Laptop, Sparkles,
  Smartphone, Apple, Play, Video
} from "lucide-react";
import Link from "next/link";
import { formatImageUrl } from "@/lib/utils";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import { getFlagFromPhoneNumber } from "@/lib/countryUtils";

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

export default function CourseDetailsPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [teacher, setTeacher] = useState<any>(null);
  const [teacherCourseCount, setTeacherCourseCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [isEnrolled, setIsEnrolled] = useState(false);
  const router = useRouter();

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
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const formatTime = (ts: any) => {
    if (!ts) return "TBD";
    const date = ts.toDate ? ts.toDate() : new Date(ts);
    return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
  };

  const mapLevel = (level: string) => {
    const l = level?.toLowerCase() || "";
    if (l.includes("beginner")) return "Beginner";
    if (l.includes("intermediate")) return "Intermediate";
    if (l.includes("advanced")) return "Advanced";
    return level || "Masterclass";
  };

  if (loading) return (
    <div className="min-h-screen bg-secondary-dark flex items-center justify-center">
      <Loader2 className="w-10 h-10 text-primary animate-spin" />
    </div>
  );

  if (!course) return (
    <div className="min-h-screen bg-secondary-dark flex flex-col items-center justify-center gap-6">
      <p className="text-white/40">Course not found.</p>
      <Link href="/courses" className="text-primary hover:underline">Back to Academy</Link>
    </div>
  );

  const lessons = course.curriculumSteps || course.lessons || course.sections || [];
  const tools = course.requiredTools || [];
  const avgRating = teacher ? (teacher.totalStars / (teacher.reviewCount || 1)).toFixed(1) : "0.0";

  return (
    <main className="min-h-screen bg-secondary-dark pb-32">
      <Navbar />
      
      {/* 1. CINEMATIC HERO (Matching App Style) */}
      <div className="relative pt-32 px-6">
        <div className="max-w-7xl mx-auto">
           <Link href="/courses" className="inline-flex items-center gap-2 text-white/40 hover:text-primary transition-colors mb-8 text-sm font-bold uppercase tracking-widest">
            <ArrowLeft className="w-4 h-4" />
            Back to Academy
          </Link>

          <div className="relative aspect-video max-h-[500px] w-full rounded-[40px] overflow-hidden shadow-2xl border border-white/5">
             {course.courseBanner ? (
               <img src={formatImageUrl(course.courseBanner)} alt={course.courseTitle} className="w-full h-full object-cover" />
             ) : (
               <div className="w-full h-full bg-white/5" />
             )}
             <div className="absolute inset-0 bg-black/40" />
             
             {/* Title Overlay */}
             <div className="absolute inset-0 flex flex-col items-center justify-center p-12 text-center">
                <h1 className="text-4xl md:text-6xl font-black font-outfit text-white mb-4 drop-shadow-lg uppercase tracking-tight">
                  <AutoTranslatedText text={course.courseName || course.courseTitle || "Untitled Course"} />
                </h1>
             </div>

             {/* Badges */}
             <div className="absolute top-8 left-8 flex gap-4">
                <span className="glass px-6 py-2.5 rounded-2xl text-xs font-black uppercase tracking-widest border-white/10 bg-black/50">
                  {mapLevel(course.selectedCategory)}
                </span>
             </div>
             <div className="absolute top-8 right-8">
                <span className="bg-primary text-secondary-dark px-6 py-2.5 rounded-2xl text-lg font-black shadow-xl">
                  ${Number(course.price).toFixed(2)}
                </span>
             </div>

             {/* Teacher Floating Card */}
             <div className="absolute bottom-8 left-8 right-8 flex justify-center">
                <div className="glass-gold px-8 py-4 rounded-[32px] flex items-center gap-6 border-white/20">
                    <div className="w-12 h-12 rounded-full border-2 border-primary overflow-hidden">
                      <img src={formatImageUrl(teacher?.photoUrl || course.teacherProfilePic)} className="w-full h-full object-cover" />
                    </div>
                    <div>
                      <h4 className="font-black font-outfit text-xl leading-none mb-1 flex items-center gap-2">
                        {teacher?.name || course.teacherName}
                        <span className="text-lg">{getFlagFromPhoneNumber(teacher?.phone || teacher?.phoneNumber)}</span>
                      </h4>
                      <p className="text-[10px] text-primary font-black uppercase tracking-widest">Master Instructor</p>
                    </div>
                </div>
             </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 mt-16 flex flex-col lg:flex-row gap-16 item-start">
        
        {/* Left Content (Exact App Parity) */}
        <div className="flex-grow max-w-4xl space-y-16">
          
          {/* Unified Stats Row */}
          <div className="grid grid-cols-3 py-8 border-y border-white/5">
              <div className="flex flex-col items-center justify-center text-center">
                 <span className="text-3xl font-black font-outfit">{teacher?.followerCount || 0}</span>
                 <span className="text-[10px] text-white/40 font-black uppercase tracking-widest mt-1">Students</span>
              </div>
              <div className="flex flex-col items-center justify-center text-center border-x border-white/5">
                 <div className="flex items-center gap-1.5">
                    <Star className="w-5 h-5 text-primary fill-primary" />
                    <span className="text-3xl font-black font-outfit">{avgRating}</span>
                 </div>
                 <span className="text-[10px] text-white/40 font-black uppercase tracking-widest mt-1">Rating</span>
              </div>
              <div className="flex flex-col items-center justify-center text-center">
                 <span className="text-3xl font-black font-outfit">{teacherCourseCount}</span>
                 <span className="text-[10px] text-white/40 font-black uppercase tracking-widest mt-1">Courses</span>
              </div>
          </div>

          {/* Description */}
          <section>
            <div className="flex items-center gap-4 mb-8">
                <Info className="w-5 h-5 text-primary/60" />
                <h3 className="text-xs font-black uppercase tracking-[3px]">Description</h3>
                <div className="flex-grow h-[1px] bg-white/5" />
            </div>
            <p className="text-lg text-white/60 leading-relaxed font-medium whitespace-pre-wrap text-start">
              <AutoTranslatedText text={course.courseDescription || course.description || "No description available."} />
            </p>
          </section>

          {/* Schedule Card (Exact App Look) */}
          <section>
            <div className="flex items-center gap-4 mb-8">
                <Calendar className="w-5 h-5 text-primary/60" />
                <h3 className="text-xs font-black uppercase tracking-[3px]">Schedule</h3>
                <div className="flex-grow h-[1px] bg-white/5" />
            </div>

            {/* Timezone Note (Matching App) */}
            <div className="mb-6 flex items-center gap-4 px-6 py-4 rounded-2xl bg-primary/10 border border-primary/20">
                <Info className="w-4 h-4 text-primary" />
                <p className="text-xs font-bold text-primary/90 italic">
                  Note: Session times are displayed based on your current time zone.
                </p>
            </div>

            <div className="glass rounded-[40px] p-10 border-white/5 bg-[#121212]">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-y-12 gap-x-12">
                   <div className="flex items-center gap-4">
                      <Calendar className="w-5 h-5 text-white/20" />
                      <div>
                        <p className="text-[9px] text-white/30 font-black uppercase tracking-widest mb-1">Start Date</p>
                        <p className="text-lg font-bold">{formatDate(course.startDate)}</p>
                      </div>
                   </div>
                   <div className="flex items-center gap-4">
                      <Calendar className="w-5 h-5 text-white/20" />
                      <div>
                        <p className="text-[9px] text-white/30 font-black uppercase tracking-widest mb-1">End Date</p>
                        <p className="text-lg font-bold">{formatDate(course.endDate)}</p>
                      </div>
                   </div>
                   <div className="flex items-center gap-4">
                      <Clock className="w-5 h-5 text-white/20" />
                      <div>
                        <p className="text-[9px] text-white/30 font-black uppercase tracking-widest mb-1">Start Time</p>
                        <p className="text-lg font-bold">{formatTime(course.startTime)}</p>
                      </div>
                   </div>
                   <div className="flex items-center gap-4">
                      <Clock className="w-5 h-5 text-white/20" />
                      <div>
                        <p className="text-[9px] text-white/30 font-black uppercase tracking-widest mb-1">End Time</p>
                        <p className="text-lg font-bold">{formatTime(course.endTime)}</p>
                      </div>
                   </div>
                </div>
                <div className="mt-12 pt-12 border-t border-white/5 flex items-center gap-6">
                   <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                      <Layout className="w-5 h-5 text-primary" />
                   </div>
                   <div>
                    <span className="text-sm font-medium text-white/80">Weekly Sessions: </span>
                    <span className="text-base font-black text-white">{(course.selectedDays || []).join(", ") || "TBD"}</span>
                   </div>
                </div>
            </div>
          </section>

          {/* Curriculum */}
          <section>
            <div className="flex items-center gap-4 mb-8">
                <BookOpen className="w-5 h-5 text-primary/60" />
                <h3 className="text-xs font-black uppercase tracking-[3px]">Curriculum</h3>
                <div className="flex-grow h-[1px] bg-white/5" />
            </div>
            <div className="space-y-4">
              {lessons.length > 0 ? lessons.map((lesson: any, i: number) => {
                const title = lesson.title || lesson.toString();
                return (
                  <div key={i} className="glass p-6 rounded-[24px] flex items-center gap-6 border-white/5 hover:bg-white/5 transition-all">
                    <span className="text-xs font-black text-primary w-6 tracking-widest">
                      {(i + 1).toString().padStart(2, '0')}
                    </span>
                    <p className="font-bold text-lg flex-grow">
                      <AutoTranslatedText text={title} />
                    </p>
                    <Lock className="w-4 h-4 text-white/20" />
                  </div>
                );
              }) : (
                <div className="text-center py-12 glass rounded-[24px] text-white/20 italic">
                  Curriculum details are coming soon.
                </div>
              )}
            </div>
          </section>

          {/* Tools Needed */}
          <section>
            <div className="flex items-center gap-4 mb-8">
                <PenTool className="w-5 h-5 text-primary/60" />
                <h3 className="text-xs font-black uppercase tracking-[3px]">Tools Required</h3>
                <div className="flex-grow h-[1px] bg-white/5" />
            </div>
            <div className="flex flex-wrap gap-4">
               {tools.length > 0 ? tools.map((tool: any, i: number) => {
                 const ToolIcon = ICON_REGISTRY[tool.icon] || PenTool;
                 return (
                   <div key={i} className="bg-[#252525] px-6 py-3 rounded-full flex items-center gap-4 border border-white/10 shadow-lg">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                        <ToolIcon className="w-4 h-4 text-primary" />
                      </div>
                       <span className="font-bold tracking-tight text-sm">
                         <AutoTranslatedText text={tool.name} />
                       </span>
                   </div>
                 );
               }) : (
                 <div className="text-sm text-white/30 italic">No specific tools listed.</div>
               )}
            </div>
          </section>
        </div>

        {/* Right Sticky Pay Section */}
        <div className="w-full lg:w-96 shrink-0">
          <div className="sticky top-40 glass rounded-[44px] p-10 bg-primary/5 border-primary/20 shadow-2xl">
              <div className="text-center mb-10">
                <p className="text-[10px] font-black text-white/30 uppercase tracking-[4px] mb-3">
                  {isEnrolled ? <AutoTranslatedText text="Current Status" /> : <AutoTranslatedText text="Tuition Fee" />}
                </p>
                {isEnrolled ? (
                  <div className="flex flex-col items-center gap-2">
                    <CheckCircle2 className="w-12 h-12 text-primary animate-bounce mb-2" />
                    <h2 className="text-4xl font-black font-outfit text-white tracking-tighter uppercase italic">
                      <AutoTranslatedText text="Lifetime Access" />
                    </h2>
                  </div>
                ) : (
                  <h2 className="text-6xl font-black font-outfit gold-text tracking-tighter">${Number(course.price).toFixed(2)}</h2>
                )}
              </div>

              <div className="space-y-6 mb-10">
                <div className="flex items-center gap-4 text-white/40 text-sm font-bold">
                  <ShieldCheck className="w-5 h-5 text-primary/40" />
                  Direct Academy Enrollment
                </div>
                <div className="flex items-center gap-4 text-white/40 text-sm font-bold">
                  <CheckCircle2 className="w-5 h-5 text-primary/40" />
                  Certified Instructor
                </div>
              </div>

              {isEnrolled ? (
                <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-1000">
                  <div className="p-6 rounded-3xl bg-white/5 border border-white/10 text-center space-y-4">
                    <div className="w-16 h-16 bg-primary/20 rounded-2xl flex items-center justify-center mx-auto mb-4 border border-primary/20">
                      <Video className="w-8 h-8 text-primary" />
                    </div>
                    <h3 className="text-xl font-black font-outfit text-white">
                      <AutoTranslatedText text="Classroom Access" />
                    </h3>
                    <p className="text-xs text-white/40 font-medium leading-relaxed">
                      <AutoTranslatedText text="Join your live session directly from here or use the mobile app for the best interactive experience." />
                    </p>

                    {(course.calligroMeetLink || course.googleMeetLink) && (
                      <Link
                        href={`/courses/${id}/classroom`}
                        className="btn-gold w-full flex items-center justify-center gap-3 py-4 mt-4 shadow-xl text-lg"
                      >
                         <Video className="w-5 h-5" />
                         <AutoTranslatedText text="Join Live Session" />
                      </Link>
                    )}
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <a href="#" className="flex items-center justify-center gap-2 py-3 px-4 rounded-2xl bg-white/5 border border-white/10 text-white/60 font-black text-[10px] uppercase tracking-widest hover:bg-white hover:text-black transition-all">
                      <Apple className="w-4 h-4 fill-current" />
                      App Store
                    </a>
                    <a href="#" className="flex items-center justify-center gap-2 py-3 px-4 rounded-2xl bg-white/5 border border-white/10 text-white/60 font-black text-[10px] uppercase tracking-widest hover:bg-white hover:text-black transition-all">
                      <Play className="w-4 h-4 fill-current" />
                      Play Store
                    </a>
                  </div>

                  <div className="pt-4 text-center">
                    <p className="text-[9px] font-black text-primary/40 uppercase tracking-[3px]">
                      <AutoTranslatedText text="Synced with your account" />
                    </p>
                  </div>
                </div>
              ) : (
                <button 
                  onClick={() => {
                    if (!auth.currentUser) {
                      router.push("/login?redirect=/courses/" + id + "/checkout");
                    } else {
                      router.push(`/courses/${id}/checkout`);
                    }
                  }}
                  className="btn-gold w-full text-xl py-5 shadow-2xl"
                >
                  <AutoTranslatedText text="Join Academy" />
                </button>
              )}

              <div className="mt-8 flex justify-center gap-4 grayscale opacity-20">
                  {/* Payment Icons Placeholder */}
                  <div className="h-6 w-10 bg-white rounded-md" />
                  <div className="h-6 w-10 bg-white rounded-md" />
                  <div className="h-6 w-10 bg-white rounded-md" />
              </div>

              <p className="text-[10px] text-center text-white/20 mt-8 font-black uppercase tracking-[3px]">
                Global Artistic Achievement
              </p>
          </div>
        </div>

      </div>
    </main>
  );
}
