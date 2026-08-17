"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { db, auth } from "@/lib/firebase";
import { doc, getDoc, collection, query, where, getDocs, orderBy, onSnapshot } from "firebase/firestore";
import { onAuthStateChanged, User } from "firebase/auth";
import Navbar from "@/components/Navbar";
import CourseCard from "@/components/CourseCard";
import { Loader2, ArrowLeft, CheckCircle2 } from "lucide-react";
import { useTranslation } from "@/hooks/useTranslation";
import Image from "next/image";

export default function TeacherProfilePage() {
  const params = useParams();
  const router = useRouter();
  const teacherId = params.id as string;

  const [teacher, setTeacher] = useState<any>(null);
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const { t, locale } = useTranslation();
  const isRTL = locale === "ar";

  // Handle Authentication for Course Filtering logic
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
    });
    return () => unsubscribe();
  }, []);

  // Fetch Teacher & Courses
  useEffect(() => {
    if (!teacherId) return;

    const fetchTeacherData = async () => {
      try {
        const teacherDoc = await getDoc(doc(db, "users", teacherId));
        if (teacherDoc.exists()) {
          setTeacher({ uid: teacherDoc.id, ...teacherDoc.data() });
        } else {
          router.push("/teachers"); // Redirect if not found
          return;
        }

        // Fetch courses where teacherId == this teacher
        const q = query(
          collection(db, "courses"), 
          where("teacherId", "==", teacherId)
        );
        
        const unsubscribe = onSnapshot(q, (snapshot) => {
          const courseList: any[] = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
          }));
          
          // Sort manually since we used where() on a different field
          courseList.sort((a, b) => {
            const dateA = a.createdAt?.seconds || 0;
            const dateB = b.createdAt?.seconds || 0;
            return dateB - dateA; // Descending
          });

          setCourses(courseList);
          setLoading(false);
        });

        return () => unsubscribe();
      } catch (error) {
        console.error("Error fetching teacher:", error);
        setLoading(false);
      }
    };

    fetchTeacherData();
  }, [teacherId, router]);

  const filteredCourses = courses.filter(c => {
    if (c.startDate) {
      const start = c.startDate.toDate ? c.startDate.toDate() : new Date(c.startDate);
      if (!isNaN(start.getTime())) {
        const now = new Date();
        const enrolledStudents = Array.isArray(c.enrolledStudents) ? c.enrolledStudents : [];
        const isEnrolled = currentUser ? enrolledStudents.includes(currentUser.uid) : false;
        
        // Hide if the course has already started AND the user is not enrolled
        if (now.getTime() > start.getTime() && !isEnrolled) {
          return false;
        }
      }
    }
    return true;
  });

  const formatImageUrl = (url?: string) => {
    if (!url) return "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop";
    if (url.startsWith('http')) return url;
    return `https://firebasestorage.googleapis.com/v0/b/calligro-app.appspot.com/o/${encodeURIComponent(url)}?alt=media`;
  };

  if (loading) {
    return (
      <main className="min-h-screen bg-transparent pt-32 pb-24">
        <Navbar />
        <div className="flex flex-col items-center justify-center py-40 gap-6">
          <Loader2 className="w-12 h-12 text-[#E8C468] animate-spin" />
          <p className="text-sm font-black uppercase tracking-[0.3em] text-white/20 animate-pulse">
            {t("teachers.syncing") || "Loading Profile..."}
          </p>
        </div>
      </main>
    );
  }

  if (!teacher) return null;

  return (
    <main className="min-h-screen bg-transparent pt-32 pb-24 text-[#FDFBF7]">
      <Navbar />

      <div className="max-w-7xl mx-auto px-6">
        
        {/* Back Button */}
        <button 
          onClick={() => router.push("/teachers")}
          className="flex items-center gap-2 text-white/50 hover:text-white transition-colors mb-12"
        >
          <ArrowLeft className={`w-5 h-5 ${isRTL ? 'rotate-180' : ''}`} />
          <span className="text-sm font-bold uppercase tracking-widest">
            {t("course.back") || "Back"}
          </span>
        </button>

        {/* Teacher Profile Header */}
        <div className="bg-[#181818] border border-white/5 rounded-[2rem] p-8 md:p-12 mb-16 flex flex-col md:flex-row items-center md:items-start gap-8 md:gap-12">
          
          <div className="relative shrink-0">
            <div className="w-40 h-40 md:w-48 md:h-48 rounded-full overflow-hidden border-4 border-white/5">
              <Image 
                src={formatImageUrl(teacher.photoUrl) || "/images/placeholder.png"} 
                alt={teacher.fullName || teacher.name}
                width={192}
                height={192}
                className="w-full h-full object-cover grayscale-[20%]"
              />
            </div>
            <div className="absolute bottom-2 right-2 bg-[#E8C468] text-black p-2 rounded-full shadow-lg border-[4px] border-[#181818]">
              <CheckCircle2 className="w-6 h-6" />
            </div>
          </div>

          <div className="flex-1 text-center md:text-start space-y-4">
            <h1 className="text-4xl md:text-5xl font-black font-outfit uppercase tracking-wider text-white">
              {teacher.fullName || teacher.name}
            </h1>
            
            {teacher.bio && (
              <p className="text-white/60 text-lg leading-relaxed max-w-3xl pt-4 border-t border-white/5 mt-6">
                {teacher.bio}
              </p>
            )}
          </div>
        </div>

        {/* Available Courses */}
        <div>
          <div className="flex items-center justify-between mb-10 border-b border-white/10 pb-6">
            <h2 className="text-2xl md:text-3xl font-black font-outfit uppercase tracking-wider text-white">
              {t("teachers.available_courses") || "Available Courses"}
            </h2>
            <div className="text-sm font-bold text-white/40 uppercase tracking-widest bg-white/5 px-4 py-2 rounded-xl">
              {filteredCourses.length} {t("course.lessons") || "Courses"}
            </div>
          </div>

          {filteredCourses.length > 0 ? (
            <div className="flex flex-col gap-4 max-w-4xl">
              {filteredCourses.map((course) => (
                <CourseCard key={course.id} course={course} />
              ))}
            </div>
          ) : (
            <div className="bg-[#181818] border border-white/5 rounded-3xl p-16 text-center">
              <p className="text-white/40 text-lg font-medium">
                {t("course.no_courses") || "No available courses at the moment."}
              </p>
            </div>
          )}
        </div>

      </div>
    </main>
  );
}
