"use client";

import React, { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { doc, getDoc, collection, query, orderBy, getDocs, addDoc, serverTimestamp, where, Timestamp } from "firebase/firestore";
import { onAuthStateChanged } from "firebase/auth";
import { db, auth } from "@/lib/firebase";
import { Loader2, PlayCircle, FileText, LayoutList, ChevronLeft, ChevronRight, ChevronDown, ArrowLeft, Menu, X, CheckCircle2, Search, Star, Share2, MoreVertical, ThumbsUp, ThumbsDown, MessageSquare, Bell, Bookmark, Wrench, Clock, Users, Award, Globe } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";
import { useLocale } from "@/context/LocaleContext";

interface Lesson {
  id: string;
  title: string;
  type: "video" | "document" | "quiz";
  contentUrl?: string;
  duration?: string; // stored as seconds string in Firestore
}

interface Section {
  id: string;
  title: string;
  lessons: Lesson[];
}

interface Course {
  id: string;
  courseName: string;
  teacherName: string;
  teacherPhotoUrl?: string;
  curriculum: Section[];
  rating?: number;
  reviewCount?: number;
  studentsCount?: number;
  totalHours?: number;
  description?: string;
  language?: string;
  lastUpdated?: string;
  whatYouWillLearn?: string[];
  requirements?: string[];
}

interface QAItem {
  id: string;
  userId: string;
  userName: string;
  userPhoto?: string;
  question: string;
  createdAt: any;
  upvotes: number;
  answers: { userName: string; text: string; createdAt: any }[];
}

interface ReviewItem {
  id: string;
  userId: string;
  userName: string;
  userPhoto?: string;
  rating: number;
  comment: string;
  createdAt: any;
  helpful: number;
}

export default function CourseLearningPlayer() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { t, locale } = useTranslation();
  const { isRTL } = useLocale();
  const [loading, setLoading] = useState(true);
  const [course, setCourse] = useState<Course | null>(null);
  const [activeLesson, setActiveLesson] = useState<Lesson | null>(null);
  const [activeSectionId, setActiveSectionId] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [activeTab, setActiveTab] = useState("overview");
  const [currentUser, setCurrentUser] = useState<any>(null);

  // Completed lessons state
  const [completedLessons, setCompletedLessons] = useState<Record<string, boolean>>({});

  // Q&A state
  const [qaItems, setQaItems] = useState<QAItem[]>([]);
  const [newQuestion, setNewQuestion] = useState("");
  const [qaFilter, setQaFilter] = useState("all");

  // Reviews state
  const [reviews, setReviews] = useState<ReviewItem[]>([]);
  const [newReviewText, setNewReviewText] = useState("");
  const [newReviewRating, setNewReviewRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);

  // Notes state
  const [notes, setNotes] = useState<{ id: string; text: string; lessonTitle: string; timestamp: string }[]>([]);
  const [newNote, setNewNote] = useState("");

  // Search state
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  // Dynamic durations extracted from video URLs (lessonId -> seconds)
  const [dynamicDurations, setDynamicDurations] = useState<Record<string, number>>({});

  // Tab keys for internal state management (language-independent)
  const TAB_KEYS = ["overview", "qa", "notes", "announcements", "reviews", "learning_tools"] as const;
  const TAB_LABELS: Record<string, string> = {
    overview: t("learn.tab.overview"),
    qa: t("learn.tab.qa"),
    notes: t("learn.tab.notes"),
    announcements: t("learn.tab.announcements"),
    reviews: t("learn.tab.reviews"),
    learning_tools: t("learn.tab.learning_tools"),
  };

  // ---- Duration Formatting (Udemy-style) ----
  const formatDuration = (totalSeconds: number): string => {
    if (!totalSeconds || totalSeconds <= 0 || !isFinite(totalSeconds)) return "0:00";
    const hrs = Math.floor(totalSeconds / 3600);
    const mins = Math.floor((totalSeconds % 3600) / 60);
    const secs = Math.floor(totalSeconds % 60);
    if (hrs > 0) {
      return `${hrs}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }
    return `${mins}:${String(secs).padStart(2, '0')}`;
  };

  const getLessonDurationSeconds = (lesson: Lesson): number => {
    if (lesson.duration) {
      const parsed = parseFloat(lesson.duration);
      if (!isNaN(parsed) && parsed > 0) return parsed;
    }
    if (dynamicDurations[lesson.id]) return dynamicDurations[lesson.id];
    return 0;
  };

  const getLessonDurationFormatted = (lesson: Lesson): string => {
    const secs = getLessonDurationSeconds(lesson);
    if (secs <= 0) return "--:--";
    return formatDuration(secs);
  };

  const getSectionDurationFormatted = (section: Section): string => {
    const totalSecs = section.lessons.reduce((acc, l) => acc + getLessonDurationSeconds(l), 0);
    if (totalSecs <= 0) return "";
    const hrs = Math.floor(totalSecs / 3600);
    const mins = Math.floor((totalSecs % 3600) / 60);
    if (hrs > 0) return `${hrs}${t("learn.duration.hr")} ${mins}${t("learn.duration.min")}`;
    return `${mins}${t("learn.duration.min")}`;
  };

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setCurrentUser(u);
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const fetchCourse = async () => {
      try {
        const docSnap = await getDoc(doc(db, "courses", id));
        if (docSnap.exists()) {
          const data = docSnap.data();
          const loadedCourse: Course = {
            id: docSnap.id,
            courseName: data.title || data.courseName || "Untitled Course",
            teacherName: data.teacherName || "Instructor",
            teacherPhotoUrl: data.teacherPhotoUrl || null,
            curriculum: data.curriculum || [],
            rating: data.averageRating || data.rating || 0,
            reviewCount: data.reviewCount || 0,
            studentsCount: data.enrolledCount || 0,
            totalHours: data.totalHours || 0,
            description: data.description || "",
            language: data.language || "العربية",
            lastUpdated: data.updatedAt ? new Date(data.updatedAt.seconds * 1000).toLocaleDateString(locale) : new Date().toLocaleDateString(locale),
            whatYouWillLearn: data.whatYouWillLearn || [],
            requirements: data.requirements || [],
          };
          setCourse(loadedCourse);
          
          if (loadedCourse.curriculum.length > 0 && loadedCourse.curriculum[0].lessons.length > 0) {
            setActiveLesson(loadedCourse.curriculum[0].lessons[0]);
            setActiveSectionId(loadedCourse.curriculum[0].id);
          }

          try {
            const qaSnap = await getDocs(query(collection(db, "courses", id, "questions"), orderBy("createdAt", "desc")));
            setQaItems(qaSnap.docs.map(d => ({ id: d.id, ...d.data() } as QAItem)));
          } catch (e) { /* collection may not exist yet */ }

          try {
            const revSnap = await getDocs(query(collection(db, "courses", id, "reviews"), orderBy("createdAt", "desc")));
            setReviews(revSnap.docs.map(d => ({ id: d.id, ...d.data() } as ReviewItem)));
          } catch (e) { /* collection may not exist yet */ }
        }
      } catch (error) {
        console.error("Error fetching course for player:", error);
      } finally {
        setLoading(false);
      }
    };

    if (id) fetchCourse();
  }, [id]);

  // Dynamically extract durations from video URLs
  useEffect(() => {
    if (!course) return;
    const lessonsNeedingDuration: Lesson[] = [];
    course.curriculum.forEach(sec => {
      sec.lessons.forEach(lesson => {
        const hasDuration = lesson.duration && parseFloat(lesson.duration) > 0;
        if (lesson.type === 'video' && lesson.contentUrl && !hasDuration && !dynamicDurations[lesson.id]) {
          lessonsNeedingDuration.push(lesson);
        }
      });
    });
    lessonsNeedingDuration.forEach(lesson => {
      const tempVideo = document.createElement('video');
      tempVideo.preload = 'metadata';
      tempVideo.crossOrigin = 'anonymous';
      tempVideo.onloadedmetadata = () => {
        if (tempVideo.duration && isFinite(tempVideo.duration)) {
          setDynamicDurations(prev => ({ ...prev, [lesson.id]: tempVideo.duration }));
        }
        tempVideo.src = '';
      };
      tempVideo.onerror = () => { tempVideo.src = ''; };
      tempVideo.src = lesson.contentUrl!;
    });
  }, [course]);

  const toggleLessonComplete = (lessonId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setCompletedLessons(prev => ({ ...prev, [lessonId]: !prev[lessonId] }));
  };

  const navigateLesson = (direction: 'next' | 'prev') => {
    if (!course || !activeLesson) return;
    let allLessons: { lesson: Lesson, sectionId: string }[] = [];
    course.curriculum.forEach(sec => {
      sec.lessons.forEach(les => {
        allLessons.push({ lesson: les, sectionId: sec.id });
      });
    });
    const currentIndex = allLessons.findIndex(item => item.lesson.id === activeLesson.id);
    if (direction === 'next' && currentIndex < allLessons.length - 1) {
      setActiveLesson(allLessons[currentIndex + 1].lesson);
      setActiveSectionId(allLessons[currentIndex + 1].sectionId);
    } else if (direction === 'prev' && currentIndex > 0) {
      setActiveLesson(allLessons[currentIndex - 1].lesson);
      setActiveSectionId(allLessons[currentIndex - 1].sectionId);
    }
  };

  const handleSubmitQuestion = async () => {
    if (!newQuestion.trim() || !currentUser) return;
    try {
      const docRef = await addDoc(collection(db, "courses", id, "questions"), {
        userId: currentUser.uid,
        userName: currentUser.displayName || "Student",
        userPhoto: currentUser.photoURL || null,
        question: newQuestion,
        createdAt: serverTimestamp(),
        upvotes: 0,
        answers: [],
      });
      setQaItems(prev => [{ id: docRef.id, userId: currentUser.uid, userName: currentUser.displayName || "Student", userPhoto: currentUser.photoURL, question: newQuestion, createdAt: Timestamp.now(), upvotes: 0, answers: [] }, ...prev]);
      setNewQuestion("");
    } catch (e) { console.error("Error submitting question", e); }
  };

  const handleSubmitReview = async () => {
    if (!newReviewText.trim() || !currentUser) return;
    try {
      const docRef = await addDoc(collection(db, "courses", id, "reviews"), {
        userId: currentUser.uid,
        userName: currentUser.displayName || "Student",
        userPhoto: currentUser.photoURL || null,
        rating: newReviewRating,
        comment: newReviewText,
        createdAt: serverTimestamp(),
        helpful: 0,
      });
      setReviews(prev => [{ id: docRef.id, userId: currentUser.uid, userName: currentUser.displayName || "Student", userPhoto: currentUser.photoURL, rating: newReviewRating, comment: newReviewText, createdAt: Timestamp.now(), helpful: 0 }, ...prev]);
      setNewReviewText("");
      setNewReviewRating(5);
    } catch (e) { console.error("Error submitting review", e); }
  };

  const handleAddNote = () => {
    if (!newNote.trim() || !activeLesson) return;
    setNotes(prev => [{ id: Date.now().toString(), text: newNote, lessonTitle: activeLesson.title, timestamp: new Date().toLocaleTimeString(locale) }, ...prev]);
    setNewNote("");
  };

  const totalLessons = course?.curriculum.reduce((acc, sec) => acc + sec.lessons.length, 0) || 0;
  const completedCount = Object.values(completedLessons).filter(Boolean).length;

  const renderStars = (rating: number, size = "w-4 h-4") => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star key={i} className={`${size} ${i < Math.round(rating) ? 'text-[#e59819] fill-[#e59819]' : 'text-[#e59819] fill-transparent'}`} />
    ));
  };

  // Filter label map for Q&A
  const qaFilterLabels: Record<string, string> = {
    all: t("learn.qa.filter_all"),
    recent: t("learn.qa.filter_recent"),
    popular: t("learn.qa.filter_popular"),
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#1c1d1f] flex flex-col items-center justify-center space-y-4">
        <Loader2 className="w-12 h-12 text-white animate-spin" />
      </div>
    );
  }

  if (!course) {
    return (
      <div className="min-h-screen bg-[#1c1d1f] flex flex-col items-center justify-center p-6 text-center text-white">
        <h1 className="text-2xl font-black mb-2">{t("learn.course_not_found")}</h1>
        <Link href="/" className="px-6 py-2 bg-white/10 hover:bg-white/20 rounded-lg mt-4">{t("learn.go_back")}</Link>
      </div>
    );
  }

  // RTL-aware directional classes
  const dirStart = isRTL ? 'right' : 'left';
  const dirEnd = isRTL ? 'left' : 'right';

  return (
    <div dir={isRTL ? "rtl" : "ltr"} className="flex flex-col h-screen bg-white overflow-hidden" style={{ fontFamily: "'udemy sans', 'sf pro text', -apple-system, BlinkMacSystemFont, 'Roboto', 'segoe ui', Helvetica, Arial, sans-serif" }}>
      
      {/* ============ TOP HEADER BAR ============ */}
      <div className="h-[3.5rem] bg-[#1c1d1f] flex items-center justify-between px-4 shrink-0 z-30">
        <div className="flex items-center gap-3 text-white min-w-0">
          <Link href="/" className="shrink-0">
            <img src="/assets/images/Logo.png" alt="Logo" className="w-7 h-7 object-contain" />
          </Link>
          <div className="w-px h-6 bg-white/20 shrink-0"></div>
          <h1 className="text-[15px] font-semibold text-white truncate max-w-[500px]">{course.courseName}</h1>
        </div>

        <div className="flex items-center gap-3 text-white shrink-0">
          <div className="hidden md:flex items-center gap-2 cursor-pointer hover:text-gray-300 transition-colors">
            <CheckCircle2 className="w-4 h-4" />
            <span className="text-sm font-medium">{t("learn.header.your_progress")}</span>
            <ChevronDown className="w-4 h-4" />
          </div>
          <button className="hidden md:flex items-center gap-2 px-3 py-1.5 border border-white rounded-[2px] font-bold hover:bg-white/10 transition-colors text-sm">
            {t("learn.header.share")} <Share2 className="w-4 h-4" />
          </button>
          <button className="hidden md:block p-1.5 border border-white rounded-[2px] hover:bg-white/10 transition-colors">
            <MoreVertical className="w-4 h-4" />
          </button>
          <button 
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="p-2 hover:bg-white/10 rounded transition-colors"
          >
            <Menu className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* ============ MAIN LAYOUT ============ */}
      <div className="flex flex-1 overflow-hidden relative">
        
        {/* ============ MAIN CONTENT SIDE ============ */}
        <div className={`flex-1 flex flex-col overflow-hidden bg-white transition-all duration-300 ${sidebarOpen ? (isRTL ? 'md:ml-[380px]' : 'md:mr-[380px]') : ''}`}>
          
          {/* Video Player */}
          <div className="w-full bg-[#1c1d1f] relative shrink-0">
            <div className="relative w-full aspect-video max-h-[56vh] flex items-center justify-center mx-auto">
              {activeLesson ? (
                activeLesson.type === 'video' ? (
                  activeLesson.contentUrl ? (
                    <video 
                      key={activeLesson.id}
                      src={activeLesson.contentUrl} 
                      controls 
                      controlsList="nodownload"
                      className="w-full h-full object-contain bg-black"
                      autoPlay
                    />
                  ) : (
                    <div className="text-center">
                      <div className="w-[68px] h-[68px] bg-white/10 rounded-full flex items-center justify-center mx-auto mb-3 backdrop-blur-sm cursor-pointer hover:bg-white/20 transition-all hover:scale-110">
                        <PlayCircle className="w-9 h-9 text-white" />
                      </div>
                      <p className="text-white/50 text-sm">{t("learn.video_not_available")}</p>
                    </div>
                  )
                ) : activeLesson.type === 'document' ? (
                  <div className="w-full h-full p-8 flex flex-col items-center justify-center">
                    <FileText className="w-20 h-20 text-gray-500 mb-4" />
                    <h2 className="text-xl font-bold mb-4 text-white">{activeLesson.title}</h2>
                    {activeLesson.contentUrl ? (
                      <a href={activeLesson.contentUrl} target="_blank" rel="noreferrer" className="px-6 py-2.5 bg-[#a435f0] hover:bg-[#8710d8] text-white font-bold rounded-[2px] transition-colors">
                        {t("learn.open_document")}
                      </a>
                    ) : (
                      <p className="text-white/40 text-sm">{t("learn.document_not_uploaded")}</p>
                    )}
                  </div>
                ) : (
                  <div className="w-full h-full p-8 flex flex-col items-center justify-center">
                    <LayoutList className="w-20 h-20 text-gray-500 mb-4" />
                    <h2 className="text-xl font-bold mb-4 text-white">{activeLesson.title}</h2>
                    <button className="px-6 py-2.5 bg-[#a435f0] hover:bg-[#8710d8] text-white font-bold rounded-[2px] transition-colors">
                      {t("learn.start_quiz")}
                    </button>
                  </div>
                )
              ) : (
                <p className="text-white/40">{t("learn.select_lesson")}</p>
              )}
              
              {/* Navigation Arrows - always LTR-aware */}
              <button 
                onClick={() => navigateLesson(isRTL ? 'next' : 'prev')}
                className="absolute left-0 top-1/2 -translate-y-1/2 p-2 bg-black/50 text-white hover:bg-black/80 transition-colors"
              >
                <ChevronLeft className="w-7 h-7" />
              </button>
              <button 
                onClick={() => navigateLesson(isRTL ? 'prev' : 'next')}
                className="absolute right-0 top-1/2 -translate-y-1/2 p-2 bg-black/50 text-white hover:bg-black/80 transition-colors"
              >
                <ChevronRight className="w-7 h-7" />
              </button>
            </div>
          </div>

          {/* Scrollable content area */}
          <div className="flex-1 overflow-y-auto">
            {/* Tabs */}
            <div className="w-full border-b border-[#d1d7dc] bg-white sticky top-0 z-10">
              <div className="flex items-center gap-0 px-6 overflow-x-auto">
                <button onClick={() => setSearchOpen(!searchOpen)} className={`py-4 text-gray-500 hover:text-black shrink-0 ${isRTL ? 'pl-4' : 'pr-4'}`}>
                  <Search className="w-[18px] h-[18px]" />
                </button>
                {TAB_KEYS.map(tabKey => (
                  <button
                    key={tabKey}
                    onClick={() => setActiveTab(tabKey)}
                    className={`px-3 py-4 font-bold text-[14px] whitespace-nowrap transition-colors border-b-[3px] ${
                      activeTab === tabKey ? 'border-[#1c1d1f] text-[#1c1d1f]' : 'border-transparent text-[#6a6f73] hover:text-[#1c1d1f]'
                    }`}
                  >
                    {TAB_LABELS[tabKey]}
                  </button>
                ))}
              </div>
              {searchOpen && (
                <div className="px-6 pb-3">
                  <input 
                    type="text" value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
                    placeholder={t("learn.search_placeholder")}
                    className="w-full border border-[#1c1d1f] px-4 py-2.5 text-sm font-medium outline-none focus:border-[#a435f0]"
                    autoFocus
                    dir={isRTL ? "rtl" : "ltr"}
                  />
                </div>
              )}
            </div>

            {/* ============ TAB CONTENT ============ */}
            <div className="px-6 py-8">
              
              {/* ======== OVERVIEW ======== */}
              {activeTab === "overview" && (
                <div className="max-w-3xl">
                  <h1 className="text-[1.6rem] font-bold text-[#1c1d1f] mb-4 leading-tight">
                    {course.courseName}
                  </h1>
                  
                  <div className="flex flex-wrap items-center gap-6 mb-6">
                    <div className="flex items-center gap-1.5">
                      <span className="text-[#b4690e] font-bold text-base">{(course.rating || 0).toFixed(1)}</span>
                      <div className="flex">{renderStars(course.rating || 0, "w-3.5 h-3.5")}</div>
                    </div>
                    <span className="text-[#5624d0] text-sm font-medium underline cursor-pointer">({(course.reviewCount || 0).toLocaleString(locale)} {t("learn.overview.ratings")})</span>
                    <span className="text-sm text-[#1c1d1f]"><strong>{(course.studentsCount || 0).toLocaleString(locale)}</strong> {t("learn.overview.students")}</span>
                  </div>

                  <div className="flex flex-wrap items-center gap-4 text-sm text-[#6a6f73] mb-8">
                    <div className="flex items-center gap-1.5">
                      <Clock className="w-4 h-4" />
                      <span>{t("learn.overview.last_updated")} {course.lastUpdated}</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <Globe className="w-4 h-4" />
                      <span>{course.language}</span>
                    </div>
                  </div>

                  {course.description && (
                    <div className="border-t border-[#d1d7dc] pt-6 mt-2">
                      <h2 className="text-xl font-bold text-[#1c1d1f] mb-3">{t("learn.overview.description")}</h2>
                      <p className="text-[#1c1d1f] text-[15px] leading-[1.6]">
                        {course.description}
                      </p>
                    </div>
                  )}

                  {course.whatYouWillLearn && course.whatYouWillLearn.length > 0 && (
                    <div className="border border-[#d1d7dc] p-6 mt-8">
                      <h2 className="text-xl font-bold text-[#1c1d1f] mb-4">{t("learn.overview.what_you_learn")}</h2>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        {course.whatYouWillLearn.map((item, i) => (
                          <div key={i} className="flex items-start gap-3">
                            <CheckCircle2 className="w-4 h-4 text-[#1c1d1f] mt-0.5 shrink-0" />
                            <span className="text-sm text-[#1c1d1f]">{item}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {course.requirements && course.requirements.length > 0 && (
                    <div className="mt-8">
                      <h2 className="text-xl font-bold text-[#1c1d1f] mb-3">{t("learn.overview.requirements")}</h2>
                      <ul className={`space-y-1.5 ${isRTL ? 'list-disc list-inside' : 'list-disc list-inside'}`}>
                        {course.requirements.map((req, i) => (
                          <li key={i} className="text-[15px] text-[#1c1d1f]">{req}</li>
                        ))}
                      </ul>
                    </div>
                  )}

                  <div className="border-t border-[#d1d7dc] pt-6 mt-8">
                    <h2 className="text-xl font-bold text-[#1c1d1f] mb-4">{t("learn.overview.instructor")}</h2>
                    <div className="flex items-center gap-4">
                      {course.teacherPhotoUrl ? (
                        <img src={course.teacherPhotoUrl} alt={course.teacherName} className="w-16 h-16 rounded-full object-cover" />
                      ) : (
                        <div className="w-16 h-16 rounded-full bg-[#1c1d1f] flex items-center justify-center text-white text-xl font-bold">
                          {course.teacherName.charAt(0)}
                        </div>
                      )}
                      <div>
                        <h3 className="text-[#5624d0] font-bold text-base underline cursor-pointer">{course.teacherName}</h3>
                        <p className="text-sm text-[#6a6f73] mt-1">{t("learn.overview.course_instructor")}</p>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* ======== Q&A ======== */}
              {activeTab === "qa" && (
                <div className="max-w-3xl">
                  <h2 className="text-xl font-bold text-[#1c1d1f] mb-1">{t("learn.qa.title")}</h2>
                  <p className="text-sm text-[#6a6f73] mb-6">{t("learn.qa.subtitle")}</p>

                  <div className="border border-[#d1d7dc] rounded-[2px] p-4 mb-8">
                    <div className="flex items-start gap-3">
                      <div className="w-10 h-10 rounded-full bg-[#1c1d1f] text-white flex items-center justify-center text-sm font-bold shrink-0">
                        {currentUser?.displayName?.charAt(0) || "?"}
                      </div>
                      <div className="flex-1">
                        <textarea 
                          value={newQuestion}
                          onChange={e => setNewQuestion(e.target.value)}
                          placeholder={t("learn.qa.placeholder")}
                          className="w-full border border-[#d1d7dc] p-3 text-sm outline-none focus:border-[#1c1d1f] resize-none min-h-[80px] placeholder:text-[#6a6f73]"
                          dir={isRTL ? "rtl" : "ltr"}
                        />
                        <div className={`flex mt-2 ${isRTL ? 'justify-start' : 'justify-end'}`}>
                          <button 
                            onClick={handleSubmitQuestion}
                            disabled={!newQuestion.trim()}
                            className="px-4 py-2 bg-[#1c1d1f] text-white font-bold text-sm disabled:opacity-40 disabled:cursor-not-allowed hover:bg-black transition-colors"
                          >
                            {t("learn.qa.submit")}
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 mb-6 text-sm">
                    <span className="text-[#6a6f73]">{t("learn.qa.filter")}</span>
                    {(["all", "recent", "popular"] as const).map(f => (
                      <button key={f} onClick={() => setQaFilter(f)} className={`px-3 py-1 rounded-full border text-sm font-medium transition-colors ${qaFilter === f ? 'border-[#1c1d1f] bg-[#1c1d1f] text-white' : 'border-[#d1d7dc] text-[#6a6f73] hover:border-[#1c1d1f]'}`}>
                        {qaFilterLabels[f]}
                      </button>
                    ))}
                  </div>

                  <div className="space-y-0 divide-y divide-[#d1d7dc]">
                    {qaItems.length === 0 ? (
                      <div className="py-12 text-center">
                        <MessageSquare className="w-12 h-12 text-[#d1d7dc] mx-auto mb-3" />
                        <h3 className="text-lg font-bold text-[#1c1d1f] mb-1">{t("learn.qa.no_questions")}</h3>
                        <p className="text-sm text-[#6a6f73]">{t("learn.qa.no_questions_desc")}</p>
                      </div>
                    ) : (
                      qaItems.map(item => (
                        <div key={item.id} className="py-4">
                          <div className="flex items-start gap-3">
                            <div className="w-10 h-10 rounded-full bg-[#2d2f31] text-white flex items-center justify-center text-sm font-bold shrink-0">
                              {item.userName?.charAt(0) || "?"}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="font-bold text-sm text-[#1c1d1f]">{item.userName}</span>
                                <span className="text-xs text-[#6a6f73]">{item.createdAt?.toDate ? item.createdAt.toDate().toLocaleDateString(locale) : ""}</span>
                              </div>
                              <p className="text-[15px] text-[#1c1d1f] leading-relaxed">{item.question}</p>
                              <div className="flex items-center gap-4 mt-2">
                                <button className="flex items-center gap-1.5 text-xs text-[#6a6f73] hover:text-[#1c1d1f]">
                                  <ThumbsUp className="w-3.5 h-3.5" /> {item.upvotes || 0}
                                </button>
                                <button className="flex items-center gap-1.5 text-xs text-[#6a6f73] hover:text-[#1c1d1f]">
                                  <MessageSquare className="w-3.5 h-3.5" /> {item.answers?.length || 0} {t("learn.qa.answers")}
                                </button>
                              </div>
                              {item.answers?.map((ans, i) => (
                                <div key={i} className={`mt-3 ${isRTL ? 'mr-8 pr-4 border-r-2' : 'ml-8 pl-4 border-l-2'} border-[#d1d7dc]`}>
                                  <span className="font-bold text-sm text-[#1c1d1f]">{ans.userName}</span>
                                  <p className="text-sm text-[#1c1d1f] mt-1">{ans.text}</p>
                                </div>
                              ))}
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}

              {/* ======== NOTES ======== */}
              {activeTab === "notes" && (
                <div className="max-w-3xl">
                  <h2 className="text-xl font-bold text-[#1c1d1f] mb-1">{t("learn.notes.title")}</h2>
                  <p className="text-sm text-[#6a6f73] mb-6">{t("learn.notes.subtitle")}</p>

                  <div className="border border-[#d1d7dc] p-4 mb-6 bg-[#f7f9fa]">
                    <div className="flex items-center gap-2 mb-2 text-xs text-[#6a6f73]">
                      <Bookmark className="w-3.5 h-3.5" />
                      <span>{t("learn.notes.note_for")} <strong className="text-[#1c1d1f]">{activeLesson?.title || t("learn.notes.select_lesson")}</strong></span>
                    </div>
                    <textarea 
                      value={newNote}
                      onChange={e => setNewNote(e.target.value)}
                      placeholder={t("learn.notes.placeholder")}
                      className="w-full border border-[#d1d7dc] p-3 text-sm outline-none focus:border-[#1c1d1f] resize-none min-h-[70px] bg-white"
                      dir={isRTL ? "rtl" : "ltr"}
                    />
                    <div className={`flex mt-2 ${isRTL ? 'justify-start' : 'justify-end'}`}>
                      <button 
                        onClick={handleAddNote}
                        disabled={!newNote.trim()}
                        className="px-4 py-2 bg-[#1c1d1f] text-white font-bold text-sm disabled:opacity-40"
                      >
                        {t("learn.notes.save")}
                      </button>
                    </div>
                  </div>

                  {notes.length === 0 ? (
                    <div className="py-12 text-center">
                      <Bookmark className="w-12 h-12 text-[#d1d7dc] mx-auto mb-3" />
                      <h3 className="text-lg font-bold text-[#1c1d1f] mb-1">{t("learn.notes.no_notes")}</h3>
                      <p className="text-sm text-[#6a6f73]">{t("learn.notes.no_notes_desc")}</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {notes.map(note => (
                        <div key={note.id} className="border border-[#d1d7dc] p-4 bg-white">
                          <div className="flex items-center justify-between mb-2">
                            <span className="text-xs font-bold text-[#a435f0]">{note.lessonTitle}</span>
                            <span className="text-xs text-[#6a6f73]">{note.timestamp}</span>
                          </div>
                          <p className="text-sm text-[#1c1d1f]">{note.text}</p>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* ======== ANNOUNCEMENTS ======== */}
              {activeTab === "announcements" && (
                <div className="max-w-3xl">
                  <h2 className="text-xl font-bold text-[#1c1d1f] mb-1">{t("learn.announcements.title")}</h2>
                  <p className="text-sm text-[#6a6f73] mb-6">{t("learn.announcements.subtitle")}</p>

                  <div className="py-12 text-center">
                    <Bell className="w-12 h-12 text-[#d1d7dc] mx-auto mb-3" />
                    <h3 className="text-lg font-bold text-[#1c1d1f] mb-1">{t("learn.announcements.no_announcements")}</h3>
                    <p className="text-sm text-[#6a6f73]">{t("learn.announcements.no_announcements_desc")}</p>
                  </div>
                </div>
              )}

              {/* ======== REVIEWS ======== */}
              {activeTab === "reviews" && (
                <div className="max-w-3xl">
                  <h2 className="text-xl font-bold text-[#1c1d1f] mb-6">{t("learn.reviews.title")}</h2>

                  <div className={`flex items-start gap-8 mb-8 ${isRTL ? 'flex-row-reverse' : ''}`}>
                    <div className="text-center">
                      <div className="text-6xl font-bold text-[#b4690e]">{(course.rating || 0).toFixed(1)}</div>
                      <div className="flex gap-0.5 mt-1 justify-center">{renderStars(course.rating || 0, "w-4 h-4")}</div>
                      <p className="text-sm text-[#b4690e] font-bold mt-1">{t("learn.reviews.course_rating")}</p>
                    </div>
                    <div className="flex-1 space-y-1.5">
                      {[5, 4, 3, 2, 1].map(star => {
                        const count = reviews.filter(r => Math.round(r.rating) === star).length;
                        const pct = reviews.length > 0 ? (count / reviews.length) * 100 : 0;
                        return (
                          <div key={star} className="flex items-center gap-3">
                            <div className="flex-1 h-[9px] bg-[#d1d7dc] rounded-full overflow-hidden">
                              <div className="h-full bg-[#6a6f73] rounded-full" style={{ width: `${pct}%` }}></div>
                            </div>
                            <div className="flex items-center gap-0.5 shrink-0">
                              {renderStars(star, "w-3 h-3")}
                            </div>
                            <span className="text-xs text-[#5624d0] underline w-8 cursor-pointer" style={{ textAlign: isRTL ? 'left' : 'right' }}>{pct.toFixed(0)}%</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  <div className="border border-[#d1d7dc] p-5 mb-8 bg-[#f7f9fa]">
                    <h3 className="font-bold text-sm text-[#1c1d1f] mb-3">{t("learn.reviews.write")}</h3>
                    <div className="flex items-center gap-1 mb-3">
                      {Array.from({ length: 5 }, (_, i) => (
                        <button 
                          key={i}
                          onMouseEnter={() => setHoverRating(i + 1)}
                          onMouseLeave={() => setHoverRating(0)}
                          onClick={() => setNewReviewRating(i + 1)}
                        >
                          <Star className={`w-7 h-7 cursor-pointer transition-colors ${
                            i < (hoverRating || newReviewRating) ? 'text-[#e59819] fill-[#e59819]' : 'text-[#d1d7dc]'
                          }`} />
                        </button>
                      ))}
                      <span className={`text-sm font-bold text-[#1c1d1f] ${isRTL ? 'mr-2' : 'ml-2'}`}>{newReviewRating}.0</span>
                    </div>
                    <textarea 
                      value={newReviewText}
                      onChange={e => setNewReviewText(e.target.value)}
                      placeholder={t("learn.reviews.placeholder")}
                      className="w-full border border-[#d1d7dc] p-3 text-sm outline-none focus:border-[#1c1d1f] resize-none min-h-[80px] bg-white"
                      dir={isRTL ? "rtl" : "ltr"}
                    />
                    <div className={`flex mt-2 ${isRTL ? 'justify-start' : 'justify-end'}`}>
                      <button 
                        onClick={handleSubmitReview}
                        disabled={!newReviewText.trim()}
                        className="px-5 py-2 bg-[#1c1d1f] text-white font-bold text-sm disabled:opacity-40"
                      >
                        {t("learn.reviews.submit")}
                      </button>
                    </div>
                  </div>

                  <div className="space-y-0 divide-y divide-[#d1d7dc]">
                    {reviews.length === 0 ? (
                      <div className="py-12 text-center">
                        <Star className="w-12 h-12 text-[#d1d7dc] mx-auto mb-3" />
                        <h3 className="text-lg font-bold text-[#1c1d1f] mb-1">{t("learn.reviews.no_reviews")}</h3>
                        <p className="text-sm text-[#6a6f73]">{t("learn.reviews.no_reviews_desc")}</p>
                      </div>
                    ) : (
                      reviews.map(review => (
                        <div key={review.id} className="py-5">
                          <div className="flex items-start gap-3">
                            <div className="w-10 h-10 rounded-full bg-[#1c1d1f] text-white flex items-center justify-center text-sm font-bold shrink-0">
                              {review.userName?.charAt(0) || "?"}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="font-bold text-sm text-[#1c1d1f]">{review.userName}</span>
                              </div>
                              <div className="flex items-center gap-2 mb-2">
                                <div className="flex">{renderStars(review.rating, "w-3.5 h-3.5")}</div>
                                <span className="text-xs text-[#6a6f73]">{review.createdAt?.toDate ? review.createdAt.toDate().toLocaleDateString(locale) : ""}</span>
                              </div>
                              <p className="text-[15px] text-[#1c1d1f] leading-relaxed">{review.comment}</p>
                              <div className="flex items-center gap-4 mt-3">
                                <span className="text-xs text-[#6a6f73]">{t("learn.reviews.helpful")}</span>
                                <button className="p-1 hover:bg-gray-100 rounded"><ThumbsUp className="w-4 h-4 text-[#6a6f73]" /></button>
                                <button className="p-1 hover:bg-gray-100 rounded"><ThumbsDown className="w-4 h-4 text-[#6a6f73]" /></button>
                              </div>
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}

              {/* ======== LEARNING TOOLS ======== */}
              {activeTab === "learning_tools" && (
                <div className="max-w-3xl">
                  <h2 className="text-xl font-bold text-[#1c1d1f] mb-1">{t("learn.tools.title")}</h2>
                  <p className="text-sm text-[#6a6f73] mb-6">{t("learn.tools.subtitle")}</p>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {[
                      { icon: Bookmark, title: t("learn.tools.bookmarks"), desc: t("learn.tools.bookmarks_desc") },
                      { icon: LayoutList, title: t("learn.tools.practice"), desc: t("learn.tools.practice_desc") },
                      { icon: Wrench, title: t("learn.tools.exercises"), desc: t("learn.tools.exercises_desc") },
                      { icon: MessageSquare, title: t("learn.tools.ai"), desc: t("learn.tools.ai_desc") },
                    ].map((tool, i) => (
                      <div key={i} className="border border-[#d1d7dc] p-5 hover:border-[#1c1d1f] transition-colors cursor-pointer group">
                        <tool.icon className="w-8 h-8 text-[#6a6f73] group-hover:text-[#1c1d1f] mb-3 transition-colors" />
                        <h3 className="font-bold text-[15px] text-[#1c1d1f] mb-1">{tool.title}</h3>
                        <p className="text-sm text-[#6a6f73]">{tool.desc}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* ============ RIGHT SIDEBAR (LTR) / LEFT SIDEBAR (RTL) ============ */}
        <AnimatePresence initial={false}>
          {sidebarOpen && (
            <motion.div 
              initial={{ x: isRTL ? "-100%" : "100%" }}
              animate={{ x: 0 }}
              exit={{ x: isRTL ? "-100%" : "100%" }}
              transition={{ type: "spring", damping: 25, stiffness: 200 }}
              className={`fixed top-[3.5rem] bottom-0 w-[380px] bg-white flex flex-col z-20 ${isRTL ? 'left-0 border-r border-[#d1d7dc]' : 'right-0 border-l border-[#d1d7dc]'}`}
            >
              {/* Sidebar Header */}
              <div className="flex items-center justify-between px-4 py-3 border-b border-[#d1d7dc] bg-white shrink-0">
                <h3 className="font-bold text-base text-[#1c1d1f]">{t("learn.sidebar.course_content")}</h3>
                <button onClick={() => setSidebarOpen(false)} className="p-1 hover:bg-gray-100 rounded text-[#6a6f73]">
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Sections list */}
              <div className="flex-1 overflow-y-auto udemy-scrollbar">
                {course.curriculum.map((section, sIdx) => {
                  const isExpanded = activeSectionId === section.id;
                  const sectionCompleted = section.lessons.filter(l => completedLessons[l.id]).length;
                  
                  return (
                    <div key={section.id} className="border-b border-[#d1d7dc]">
                      <button 
                        onClick={() => setActiveSectionId(isExpanded ? null : section.id)}
                        className={`w-full flex items-start justify-between p-4 text-start transition-colors ${isExpanded ? 'bg-[#f7f9fa]' : 'bg-[#f7f9fa] hover:bg-[#efeff0]'}`}
                      >
                        <div className={`flex-1 ${isRTL ? 'pl-4' : 'pr-4'}`}>
                          <h4 className="text-[14px] font-bold text-[#1c1d1f] leading-snug">
                            {t("learn.sidebar.section")} {sIdx + 1}: {section.title}
                          </h4>
                          <div className="text-[12px] text-[#6a6f73] mt-1">
                            {sectionCompleted} / {section.lessons.length}{getSectionDurationFormatted(section) ? ` | ${getSectionDurationFormatted(section)}` : ''}
                          </div>
                        </div>
                        <ChevronDown className={`w-4 h-4 text-[#6a6f73] transition-transform duration-200 mt-1 shrink-0 ${isExpanded ? 'rotate-180' : ''}`} />
                      </button>

                      <AnimatePresence>
                        {isExpanded && (
                          <motion.div 
                            initial={{ height: 0 }}
                            animate={{ height: "auto" }}
                            exit={{ height: 0 }}
                            className="overflow-hidden bg-white"
                          >
                            {section.lessons.map((lesson, lIdx) => {
                              const isActive = activeLesson?.id === lesson.id;
                              const isCompleted = completedLessons[lesson.id];
                              
                              return (
                                <div 
                                  key={lesson.id}
                                  onClick={() => setActiveLesson(lesson)}
                                  className={`flex items-start gap-3 px-4 py-3 cursor-pointer transition-colors ${
                                    isActive ? 'bg-[#d1d7dc]/40' : 'hover:bg-[#f7f9fa]'
                                  }`}
                                >
                                  <button 
                                    onClick={(e) => toggleLessonComplete(lesson.id, e)}
                                    className="mt-0.5 shrink-0"
                                  >
                                    {isCompleted ? (
                                      <CheckCircle2 className="w-[18px] h-[18px] text-[#5624d0]" />
                                    ) : (
                                      <div className="w-[18px] h-[18px] border border-[#6a6f73] rounded-sm" />
                                    )}
                                  </button>
                                  
                                  <div className="flex-1 min-w-0">
                                    <p className={`text-[13px] leading-snug ${isActive ? 'text-[#1c1d1f] font-bold' : 'text-[#1c1d1f]'}`}>
                                      {lIdx + 1}. {lesson.title}
                                    </p>
                                    <div className="flex items-center gap-1 mt-1 text-[12px] text-[#6a6f73]">
                                      {lesson.type === 'video' ? <PlayCircle className="w-3 h-3" /> : 
                                       lesson.type === 'document' ? <FileText className="w-3 h-3" /> : 
                                       <LayoutList className="w-3 h-3" />}
                                      <span>{getLessonDurationFormatted(lesson)}</span>
                                    </div>
                                  </div>
                                </div>
                              );
                            })}
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </div>
                  );
                })}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <style jsx global>{`
        .udemy-scrollbar::-webkit-scrollbar {
          width: 6px;
        }
        .udemy-scrollbar::-webkit-scrollbar-track {
          background: transparent;
        }
        .udemy-scrollbar::-webkit-scrollbar-thumb {
          background: #d1d7dc;
          border-radius: 3px;
        }
        .udemy-scrollbar::-webkit-scrollbar-thumb:hover {
          background: #6a6f73;
        }
      `}</style>
    </div>
  );
}
