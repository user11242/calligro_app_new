"use client";

import { useState, useEffect } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, AnimatePresence } from "framer-motion";
import { auth, db } from "@/lib/firebase";
import { onAuthStateChanged, signOut, User as FirebaseUser } from "firebase/auth";
import { doc, getDoc, collection, query, where, getDocs } from "firebase/firestore";
import { useTranslation } from "@/hooks/useTranslation";
import { formatImageUrl } from "@/lib/utils";
import Image from "next/image";
import Link from "next/link";
import { 
  User as UserIcon, 
  Award, 
  Clock, 
  BookOpen, 
  Settings, 
  LogOut, 
  ShieldCheck, 
  Camera,
  ChevronRight,
  ArrowRight
} from "lucide-react";
import { useRouter } from "next/navigation";

export default function ProfilePage() {
  const { t, locale } = useTranslation();
  const isRTL = locale === "ar";
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<"courses" | "certificates" | "settings">("courses");

  // Firebase auth state
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [userName, setUserName] = useState<string>("");
  const [userPhoto, setUserPhoto] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<string>("student");
  
  // Real data state
  const [myCourses, setMyCourses] = useState<any[]>([]);
  const [myCertificates, setMyCertificates] = useState<any[]>([]);
  const [loadingData, setLoadingData] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      setUser(currentUser);
      if (currentUser) {
        // 1. Fetch User Data
        const userDoc = await getDoc(doc(db, "users", currentUser.uid));
        if (userDoc.exists()) {
          const data = userDoc.data();
          setUserName(data.name || data.displayName || currentUser.displayName || "User");
          setUserPhoto(data.photoUrl || data.photoURL || currentUser.photoURL || null);
          setUserRole(data.role || "student");
        } else {
          setUserName(currentUser.displayName || "User");
          setUserPhoto(currentUser.photoURL || null);
        }

        // 2. Fetch Enrolled Courses
        try {
          const coursesRef = collection(db, "courses");
          const qCourses = query(coursesRef, where("enrolledStudents", "array-contains", currentUser.uid));
          const coursesSnap = await getDocs(qCourses);
          const loadedCourses = coursesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
          setMyCourses(loadedCourses);
        } catch (error) {
          console.error("Error fetching courses:", error);
        }

        // 3. Fetch Certificates
        try {
          const certsRef = collection(db, "certificates");
          const qCerts = query(certsRef, where("studentId", "==", currentUser.uid));
          const certsSnap = await getDocs(qCerts);
          const loadedCerts = certsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
          setMyCertificates(loadedCerts);
        } catch (error) {
          console.error("Error fetching certificates:", error);
        }

        setLoadingData(false);
      }
    });
    return () => unsubscribe();
  }, []);

  // Calculate dynamic stats
  const coursesEnrolled = myCourses.length;
  // Just a fun dummy calculation for hours since we don't track it explicitly yet
  const hoursPracticed = coursesEnrolled * 45; 
  const certificatesEarned = myCertificates.length;

  const stats = [
    { icon: <BookOpen className="w-5 h-5" />, label: t("profile.stats.courses") || "Courses Enrolled", value: coursesEnrolled },
    { icon: <Clock className="w-5 h-5" />, label: t("profile.stats.hours") || "Hours Practiced", value: hoursPracticed },
    { icon: <Award className="w-5 h-5" />, label: t("profile.stats.certificates") || "Certificates Earned", value: certificatesEarned },
  ];

  const handleLogout = async () => {
    await signOut(auth);
    router.push("/");
  };

  const tabs = [
    { id: "courses", icon: <BookOpen className="w-4 h-4" />, label: t("profile.tabs.collection") || "My Courses" },
    { id: "certificates", icon: <Award className="w-4 h-4" />, label: t("profile.tabs.certificates") || "Certificates" },
    { id: "settings", icon: <Settings className="w-4 h-4" />, label: t("profile.tabs.settings") || "Settings" },
  ] as const;

  return (
    <main className={`min-h-screen bg-[#1F1F1F] text-[#FDFBF7] selection:bg-[#E8C468] selection:text-black ${isRTL ? 'font-arabic' : 'font-sans'}`} dir={isRTL ? "rtl" : "ltr"}>
      <Navbar />

      <div className="flex flex-col md:flex-row pt-28 md:pt-36 max-w-7xl mx-auto px-6 gap-8 pb-16 min-h-screen">
        
        {/* ══ SIDEBAR ══ */}
        <aside className="w-full md:w-80 flex-shrink-0 flex flex-col gap-6 md:sticky md:top-32 h-fit z-10">
          
          {/* Identity Card */}
          <div className="bg-white/[0.03] border border-white/10 rounded-[2rem] p-8 flex flex-col items-center text-center shadow-2xl relative overflow-hidden">
            {/* Subtle glow behind avatar */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[150%] h-32 bg-gradient-to-b from-[#E8C468]/10 to-transparent blur-2xl pointer-events-none" />
            
            <div className="relative group mb-5">
              <div className="w-24 h-24 rounded-full bg-black flex items-center justify-center text-white overflow-hidden border-2 border-[#E8C468]/30 shadow-[0_0_20px_rgba(232,196,104,0.2)]">
                {userPhoto ? (
                  <Image src={userPhoto} alt="User" width={96} height={96} className="w-full h-full object-cover" />
                ) : (
                  <UserIcon className="w-10 h-10 text-[#E8C468]" />
                )}
              </div>
              {/* Edit Photo Hover Overlay */}
              <button className="absolute inset-0 bg-black/60 rounded-full flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer">
                <Camera className="w-5 h-5 text-white mb-1" />
              </button>
            </div>

            <h1 className="text-xl md:text-2xl font-black font-outfit uppercase tracking-wider text-white line-clamp-1">
              {userName || "..."}
            </h1>
          </div>

          {/* Navigation Menu */}
          <nav className="bg-white/[0.03] border border-white/10 rounded-[2rem] p-4 flex flex-col gap-2 shadow-xl">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`w-full flex items-center gap-4 px-6 py-4 rounded-xl font-bold uppercase tracking-widest text-sm transition-all duration-300 ${
                  activeTab === tab.id 
                    ? "bg-[#E8C468] text-black shadow-[0_0_20px_rgba(232,196,104,0.3)] scale-[1.02]" 
                    : "text-white/50 hover:text-white hover:bg-white/5"
                }`}
              >
                {tab.icon}
                <span className={`flex-1 ${isRTL ? "text-right" : "text-left"}`}>{tab.label}</span>
                {activeTab === tab.id && (
                  <ChevronRight className={`w-4 h-4 ${isRTL ? "rotate-180" : ""}`} />
                )}
              </button>
            ))}

            <div className="h-px bg-white/10 my-2 mx-4" />

            <button 
              onClick={handleLogout}
              className="w-full flex items-center gap-4 px-6 py-4 rounded-xl font-bold uppercase tracking-widest text-sm text-red-400/80 hover:text-red-400 hover:bg-red-500/10 transition-colors"
            >
              <LogOut className="w-4 h-4" />
              <span className={`flex-1 ${isRTL ? "text-right" : "text-left"}`}>{t("profile.signout") || "Sign Out"}</span>
            </button>
          </nav>

        </aside>

        {/* ══ MAIN CONTENT ══ */}
        <div className="flex-1 flex flex-col gap-6 min-w-0 z-10">
          
          {/* Stats Header Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
            {stats.map((stat, i) => (
              <div key={i} className="bg-white/[0.03] border border-white/10 rounded-[2rem] p-6 flex flex-col items-center sm:items-start sm:flex-row gap-4 hover:bg-white/[0.05] hover:border-white/20 transition-all group shadow-lg">
                <div className="w-12 h-12 flex-shrink-0 rounded-2xl bg-white/5 border border-white/10 text-[#E8C468] flex items-center justify-center group-hover:scale-110 group-hover:bg-[#E8C468]/10 group-hover:border-[#E8C468]/30 transition-all duration-500">
                  {stat.icon}
                </div>
                <div className="text-center sm:text-left">
                  <p className="text-3xl font-black text-white leading-none mb-1">{loadingData ? "-" : stat.value}</p>
                  <p className="text-white/40 text-[10px] uppercase tracking-widest font-bold">{stat.label}</p>
                </div>
              </div>
            ))}
          </div>

          {/* Dynamic Tab Area */}
          <div className="bg-white/[0.03] border border-white/10 rounded-[2.5rem] p-8 md:p-12 min-h-[500px] shadow-2xl relative overflow-hidden">
            {/* Subtle inner glow */}
            <div className="absolute top-0 right-0 w-64 h-64 bg-[#E8C468]/5 blur-3xl pointer-events-none" />

            <AnimatePresence mode="wait">
              
              {/* COURSES TAB */}
              {activeTab === "courses" && (
                <motion.div
                  key="courses"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.3 }}
                >
                  <div className="flex items-center justify-between mb-8">
                    <div>
                      <h2 className="text-2xl font-black font-outfit uppercase tracking-wider text-white">
                        {t("profile.collection.title") || "My Courses"}
                      </h2>
                      <p className="text-white/50 text-sm mt-1">
                        {t("profile.collection.subtitle") || "Continue where you left off."}
                      </p>
                    </div>
                  </div>

                  {!loadingData && myCourses.length === 0 ? (
                    <div className="flex flex-col items-center justify-center py-20 text-center">
                      <BookOpen className="w-16 h-16 text-white/10 mb-4" />
                      <p className="text-white/50 mb-6">{t("profile.collection.empty") || "You have not enrolled in any courses yet."}</p>
                      <Link href="/courses" className="px-8 py-3 rounded-full bg-white/5 border border-white/10 text-white font-bold text-xs hover:bg-white/10 hover:border-white/20 transition-all uppercase tracking-widest">
                        {t("profile.collection.explore") || "Explore Courses"}
                      </Link>
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                      {myCourses.map(course => (
                        <Link href={`/courses/${course.id}`} key={course.id}>
                          <div className="group rounded-3xl overflow-hidden bg-black/40 border border-white/10 hover:border-[#E8C468]/40 transition-colors cursor-pointer">
                            <div className="w-full aspect-[16/9] relative overflow-hidden bg-white/5">
                              {course.courseBanner || course.coverImage || course.imageUrl ? (
                                <Image 
                                  src={formatImageUrl(course.courseBanner || course.coverImage || course.imageUrl) || "/assets/images/bg_calligraphy.png"} 
                                  alt={course.title || course.courseTitle || course.courseName || "Course"} 
                                  fill 
                                  className="object-cover group-hover:scale-105 transition-transform duration-700 opacity-80" 
                                />
                              ) : (
                                <div className="absolute inset-0 flex items-center justify-center opacity-20">
                                  <Image src="/assets/images/bg_calligraphy.png" alt="Course" fill className="object-cover" />
                                </div>
                              )}
                              <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent" />
                            </div>
                            <div className="p-6 relative">
                              <h3 className="text-lg font-bold text-white mb-2 line-clamp-1 group-hover:text-[#E8C468] transition-colors">
                                {course.title || course.courseTitle || course.courseName || "Course"}
                              </h3>
                              <p className="text-white/50 text-xs mb-5 line-clamp-2">
                                {course.description || course.courseDescription || course.desc || "Learn the art of Arabic calligraphy."}
                              </p>
                            </div>
                          </div>
                        </Link>
                      ))}
                    </div>
                  )}
                </motion.div>
              )}

              {/* CERTIFICATES TAB */}
              {activeTab === "certificates" && (
                <motion.div
                  key="certificates"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.3 }}
                >
                  <div className="flex items-center justify-between mb-8">
                    <div>
                      <h2 className="text-2xl font-black font-outfit uppercase tracking-wider text-white">
                        {t("profile.tabs.certificates") || "Certificates"}
                      </h2>
                    </div>
                  </div>

                  {!loadingData && myCertificates.length === 0 ? (
                    <div className="flex flex-col items-center justify-center h-full min-h-[350px] text-center">
                      <div className="w-28 h-28 mb-8 relative">
                        <Image src="/assets/images/gold_seal.png" alt="Seal" fill className="object-contain drop-shadow-[0_0_40px_rgba(232,196,104,0.2)] opacity-50 grayscale hover:grayscale-0 hover:opacity-100 transition-all duration-500" />
                      </div>
                      <h3 className="text-2xl font-black font-outfit uppercase text-white mb-3 tracking-widest">
                        {t("profile.certificates.empty_title") || "No Certificates Yet"}
                      </h3>
                      <p className="text-white/40 max-w-sm mx-auto mb-8 text-sm leading-relaxed">
                        {t("profile.certificates.empty_desc") || "Complete your masterclass courses and submit your final artwork for review to earn your traditional digital Ijazah."}
                      </p>
                      <Link href="/courses" className="px-8 py-3 rounded-full bg-white/5 border border-white/10 text-white font-bold text-xs hover:bg-white/10 hover:border-white/20 transition-all uppercase tracking-widest">
                        {t("profile.certificates.view_eligible") || "View Eligible Courses"}
                      </Link>
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 gap-8">
                      {myCertificates.map(cert => {
                        const dateLocale = locale === 'ar' ? 'ar-SA' : locale === 'tr' ? 'tr-TR' : 'en-US';
                        const issueDate = cert.issueDate?.seconds 
                          ? new Date(cert.issueDate.seconds * 1000).toLocaleDateString(dateLocale, { year: 'numeric', month: 'long', day: 'numeric' }) 
                          : new Date().toLocaleDateString(dateLocale, { year: 'numeric', month: 'long', day: 'numeric' });

                        return (
                          <div key={cert.id} className="group relative overflow-hidden bg-gradient-to-r from-black/60 to-black/30 border border-[#E8C468]/20 hover:border-[#E8C468]/60 shadow-[0_0_20px_rgba(0,0,0,0.5)] transition-all duration-500 p-8 rounded-3xl flex flex-col md:flex-row items-center md:items-start gap-8">
                            {/* Decorative Background Elements */}
                            <div className="absolute top-0 right-0 w-48 h-48 bg-[#E8C468]/10 blur-3xl pointer-events-none group-hover:bg-[#E8C468]/20 transition-colors duration-700" />
                            <div className="absolute top-0 left-0 w-2 h-full bg-gradient-to-b from-[#E8C468]/50 via-[#E8C468] to-[#E8C468]/50 opacity-80" />

                            {/* Left: Glowing Icon / Seal Area */}
                            <div className="flex-shrink-0 relative z-10 pl-4 md:pl-8">
                              <div className="w-24 h-24 rounded-full bg-gradient-to-br from-[#E8C468]/20 to-black border border-[#E8C468]/40 flex items-center justify-center shadow-[0_0_30px_rgba(232,196,104,0.2)] group-hover:shadow-[0_0_60px_rgba(232,196,104,0.4)] transition-all duration-500 group-hover:scale-105">
                                <Award className="w-12 h-12 text-[#E8C468]" />
                              </div>
                            </div>

                            {/* Center: Certificate Details */}
                            <div className={`flex-1 flex flex-col justify-center z-10 ${isRTL ? "text-right md:pr-4" : "text-left md:pl-4"} text-center md:text-start`}>
                              <p className="text-[#E8C468] text-[10px] font-bold uppercase tracking-[0.3em] mb-2">
                                {t("profile.certificates.official_ijazah") || "Official Ijazah"}
                              </p>
                              <h3 className="text-2xl font-black font-arabic text-white mb-2 leading-tight">
                                {cert.courseName || "Calligraphy Masterclass"}
                              </h3>
                              
                              <div className="flex flex-col sm:flex-row items-center md:items-start gap-4 sm:gap-8 mt-6">
                                <div>
                                  <p className="text-white/40 text-[10px] uppercase tracking-widest font-bold mb-1">
                                    {t("profile.certificates.issue_date") || "Issue Date"}
                                  </p>
                                  <p className="text-white text-sm font-medium">{issueDate}</p>
                                </div>
                                <div className="h-8 w-px bg-white/10 hidden sm:block" />
                                <div>
                                  <p className="text-white/40 text-[10px] uppercase tracking-widest font-bold mb-1">
                                    {t("profile.certificates.certificate_id") || "Certificate ID"}
                                  </p>
                                  <p className="text-[#E8C468] text-sm font-mono tracking-wider">{cert.id}</p>
                                </div>
                              </div>
                            </div>

                            {/* Right: Action Button */}
                            <div className="flex-shrink-0 flex items-center justify-center md:self-stretch z-10 pr-4 md:pr-8">
                              <Link 
                                href={`/courses/${cert.courseId}/certificate`}
                                className="group/btn flex flex-col items-center justify-center gap-2 px-8 py-6 rounded-2xl bg-[#E8C468]/10 border border-[#E8C468]/20 text-[#E8C468] hover:bg-[#E8C468] hover:text-black hover:border-[#E8C468] transition-all duration-300 hover:scale-105 hover:shadow-[0_0_20px_rgba(232,196,104,0.3)]"
                              >
                                <Award className="w-6 h-6 group-hover/btn:text-black transition-colors" />
                                <span className="font-bold text-xs uppercase tracking-widest text-center">
                                  {t("profile.certificates.view_button") || "View"}
                                </span>
                              </Link>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </motion.div>
              )}

              {/* SETTINGS TAB */}
              {activeTab === "settings" && (
                <motion.div
                  key="settings"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.3 }}
                >
                  <div className="flex items-center gap-4 mb-8">
                    <div className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/50">
                      <Settings className="w-5 h-5" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-black font-outfit uppercase tracking-wider text-white">
                        {t("profile.settings.title") || "Account Settings"}
                      </h2>
                      <p className="text-white/50 text-sm mt-1">
                        {t("profile.settings.subtitle") || "Manage your personal information."}
                      </p>
                    </div>
                  </div>
                  
                  <div className="space-y-6 max-w-xl">
                    <div className="group">
                      <label className="block text-[10px] uppercase tracking-widest font-bold text-white/40 mb-2 pl-1 group-focus-within:text-[#E8C468] transition-colors">
                        {t("profile.settings.name_label") || "Display Name"}
                      </label>
                      <input type="text" defaultValue={userName} disabled className="w-full bg-black/20 border border-white/5 rounded-2xl px-5 py-4 text-white/30 cursor-not-allowed shadow-inner" />
                    </div>
                    <div className="group">
                      <label className="block text-[10px] uppercase tracking-widest font-bold text-white/40 mb-2 pl-1 group-focus-within:text-[#E8C468] transition-colors">
                        {t("profile.settings.email_label") || "Email Address"}
                      </label>
                      <input type="email" defaultValue={user?.email || "student@calligroacademy.com"} disabled className="w-full bg-black/20 border border-white/5 rounded-2xl px-5 py-4 text-white/30 cursor-not-allowed shadow-inner" />
                    </div>
                  </div>
                </motion.div>
              )}

            </AnimatePresence>
          </div>
        </div>

      </div>
      
      <Footer />
    </main>
  );
}
