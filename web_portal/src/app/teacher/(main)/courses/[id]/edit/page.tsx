"use client";

import { useState, useEffect, useRef } from "react";
import { useTranslation } from "@/hooks/useTranslation";
import { app, auth, db } from "@/lib/firebase";
import { doc, getDoc, updateDoc } from "firebase/firestore";
import { getFunctions, httpsCallable } from "firebase/functions";
import { useRouter, useParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { 
  ArrowLeft, Plus, GripVertical, Video, ArrowRight,
  Trash2, Loader2, CheckCircle2, CloudUpload, Link as LinkIcon,
  X, FileText, PenTool, LayoutList, Eye, AlertCircle
} from "lucide-react";
import Link from "next/link";
import toast from "react-hot-toast";
import QuizBuilderModal, { QuizQuestion } from "@/components/teacher/QuizBuilderModal";

const GOOGLE_API_KEY = "AIzaSyCGj9JVoKb6bNZjuOKDLiDOqQOjPoS3Dv4";
const GOOGLE_CLIENT_ID = "500166558232-9kshf1l9v33urijg9shdo1agpkq6md4k.apps.googleusercontent.com";

type LessonType = "video" | "document" | "quiz";

const DriveIcon = ({ className }: { className?: string }) => (
  <svg viewBox="0 0 87.3 78" xmlns="http://www.w3.org/2000/svg" className={className}>
    <path d="m6.6 66.85 3.85 6.65c.8 1.4 1.95 2.5 3.3 3.3l13.75-23.8h-27.5c0 1.55.4 3.1 1.2 4.5z" fill="#0066da"/>
    <path d="m43.65 25-13.75-23.8c-1.35.8-2.5 1.9-3.3 3.3l-25.4 44a9.06 9.06 0 0 0 -1.2 4.5h27.5z" fill="#00ac47"/>
    <path d="m73.55 76.8c1.35-.8 2.5-1.9 3.3-3.3l1.6-2.75 7.65-13.25c.8-1.4 1.2-2.95 1.2-4.5h-27.502l5.852 11.5z" fill="#ea4335"/>
    <path d="m43.65 25 13.75-23.8c-1.35-.8-2.9-1.2-4.5-1.2h-18.5c-1.6 0-3.15.45-4.5 1.2z" fill="#00832d"/>
    <path d="m59.8 53h-32.3l-13.75 23.8c1.35.8 2.9 1.2 4.5 1.2h50.8c1.6 0 3.15-.45 4.5-1.2z" fill="#2684fc"/>
    <path d="m73.4 26.5-12.7-22c-.8-1.4-1.95-2.5-3.3-3.3l-13.75 23.8 16.15 28h27.45c0-1.55-.4-3.1-1.2-4.5z" fill="#ffba00"/>
  </svg>
);

type Lesson = {
  id: string;
  title: string;
  type: LessonType;
  contentUrl: string | null;
  duration?: string;
  quizData?: QuizQuestion[];
};

type Section = {
  id: string;
  title: string;
  lessons: Lesson[];
};

type ReviewNote = {
  id: string;
  targetId: string;
  targetType: "field" | "lesson";
  message: string;
  resolved: boolean;
  createdAt: number;
};

export default function CurriculumBuilderPage() {
  const { t } = useTranslation();
  const router = useRouter();
  const params = useParams();
  const courseId = params.id as string;
  
  const [sections, setSections] = useState<Section[]>([]);
  const [isDirty, setIsDirty] = useState(false);
  const [showDraftModal, setShowDraftModal] = useState(false);
  const [saveStatus, setSaveStatus] = useState<"saved" | "saving" | "error" | "idle">("idle");
  const [isLoading, setIsLoading] = useState(true);
  const [previewMedia, setPreviewMedia] = useState<{url: string, type: string} | null>(null);
  
  // Review Notes State
  const [courseStatus, setCourseStatus] = useState<string>("draft");
  const [reviewNotes, setReviewNotes] = useState<ReviewNote[]>([]);
  
  const lastSavedRef = useRef<string>("");
  const autoSaveTimerRef = useRef<NodeJS.Timeout | null>(null);
  const hasFetchedRef = useRef(false);

  // Load existing curriculum from Firestore (once only)
  useEffect(() => {
    if (hasFetchedRef.current) return;
    hasFetchedRef.current = true;

    const fetchCourse = async () => {
      try {
        const docRef = doc(db, "courses", courseId);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          const data = docSnap.data();
          if (data.curriculum && Array.isArray(data.curriculum) && data.curriculum.length > 0) {
            setSections(data.curriculum);
            lastSavedRef.current = JSON.stringify(data.curriculum);
          } else {
            const defaultSections: Section[] = [
              {
                id: "sec-intro",
                title: t('teacher.courses.edit.default_section_1'),
                lessons: [
                  {
                    id: "les-intro-1",
                    title: t('teacher.courses.edit.default_lesson_1'),
                    type: "video" as LessonType,
                    contentUrl: null
                  },
                  {
                    id: "les-intro-2",
                    title: t('teacher.courses.edit.default_lesson_2'),
                    type: "video" as LessonType,
                    contentUrl: null
                  }
                ]
              },
              {
                id: "sec-tools",
                title: t('teacher.courses.edit.default_section_2'),
                lessons: [
                  {
                    id: "les-tools-1",
                    title: t('teacher.courses.edit.default_lesson_3'),
                    type: "video" as LessonType,
                    contentUrl: null
                  }
                ]
              }
            ];
            setSections(defaultSections);
            lastSavedRef.current = JSON.stringify(defaultSections);
          }
          
          if (data.status) setCourseStatus(data.status);
          if (data.reviewNotes) setReviewNotes(data.reviewNotes);
        }
      } catch (err) {
        console.error("Error fetching course:", err);
      } finally {
        setIsLoading(false);
      }
    };
    fetchCourse();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [courseId]);

  // Auto-Save Effect (debounced, no infinite loop)
  useEffect(() => {
    if (isLoading || !lastSavedRef.current) return;
    
    const currentString = JSON.stringify(sections);
    if (currentString === lastSavedRef.current) {
      setIsDirty(false);
      return;
    }

    setIsDirty(true);

    // Clear any pending save
    if (autoSaveTimerRef.current) clearTimeout(autoSaveTimerRef.current);

    autoSaveTimerRef.current = setTimeout(async () => {
      setSaveStatus("saving");
      try {
        const docRef = doc(db, "courses", courseId);
        await updateDoc(docRef, { curriculum: sections });
        lastSavedRef.current = currentString;
        setSaveStatus("saved");
        setIsDirty(false);
        setTimeout(() => setSaveStatus("idle"), 2000);
      } catch (err) {
        console.error("Error auto-saving draft:", err);
        setSaveStatus("error");
        toast.error("Failed to auto-save draft");
      }
    }, 1500);

    return () => {
      if (autoSaveTimerRef.current) clearTimeout(autoSaveTimerRef.current);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sections]);

  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (isDirty || saveStatus === "saving") {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [isDirty, saveStatus]);

  const handleBack = () => {
    if (isDirty) {
      setShowDraftModal(true);
    } else {
      router.push(`/teacher/courses/${courseId}/edit-info`);
    }
  };

  const handleDraftAction = async (action: 'save' | 'discard') => {
    setShowDraftModal(false);
    if (action === 'save') {
      try {
        const docRef = doc(db, "courses", courseId);
        await updateDoc(docRef, { curriculum: sections });
        toast.success(t('teacher.courses.edit.draft_saved'));
      } catch (err) {
        toast.error("Failed to save draft");
        return;
      }
    }
    router.push(`/teacher/courses/${courseId}/edit-info`);
  };

  const [isPublishing, setIsPublishing] = useState(false);
  const [activeAddMenu, setActiveAddMenu] = useState<string | null>(null);
  
  // Quiz Builder State
  const [isQuizModalOpen, setIsQuizModalOpen] = useState(false);
  const [editingQuizLesson, setEditingQuizLesson] = useState<{sectionId: string, lessonId: string} | null>(null);
  const [currentQuizData, setCurrentQuizData] = useState<QuizQuestion[]>([]);

  // File Upload State
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploadingLesson, setUploadingLesson] = useState<{sectionId: string, lessonId: string} | null>(null);
  const [uploadProgress, setUploadProgress] = useState<{ [key: string]: number }>({});
  const functions = getFunctions(app);
  const functionsEast = getFunctions(app, "us-east1");
  
  // Google Drive Picker State
  const [pickerApiLoaded, setPickerApiLoaded] = useState(false);
  const [gisLoaded, setGisLoaded] = useState(false);
  const tokenClientRef = useRef<any>(null);
  const pickerCallbackRef = useRef<((token: string) => void) | null>(null);

  useEffect(() => {
    // Load Google Picker API
    const loadGapi = () => {
      const script = document.createElement("script");
      script.src = "https://apis.google.com/js/api.js";
      script.onload = () => {
        (window as any).gapi.load("picker", () => setPickerApiLoaded(true));
      };
      document.body.appendChild(script);
    };

    // Load Google Identity Services (OAuth)
    const loadGis = () => {
      const script = document.createElement("script");
      script.src = "https://accounts.google.com/gsi/client";
      script.onload = () => {
        tokenClientRef.current = (window as any).google.accounts.oauth2.initTokenClient({
          client_id: GOOGLE_CLIENT_ID,
          scope: "https://www.googleapis.com/auth/drive.readonly",
          callback: (response: any) => {
            if (response.error !== undefined) {
              console.error(response);
              return;
            }
            if (pickerCallbackRef.current) {
              pickerCallbackRef.current(response.access_token);
            }
          },
        });
        setGisLoaded(true);
      };
      document.body.appendChild(script);
    };

    if (typeof window !== "undefined") {
      loadGapi();
      loadGis();
    }
  }, []);

  const triggerUpload = (sectionId: string, lessonId: string, accept: string) => {
    setUploadingLesson({ sectionId, lessonId });
    if (fileInputRef.current) {
      fileInputRef.current.accept = accept;
      fileInputRef.current.click();
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !uploadingLesson) return;
    
    // Enforce 4GB maximum file size limit (Matches Udemy's Limit)
    const MAX_FILE_SIZE = 4 * 1024 * 1024 * 1024; // 4 GB in bytes
    if (file.size > MAX_FILE_SIZE) {
      toast.error("File is too large! The maximum allowed file size is 4.0 GB.");
      e.target.value = ''; // Clear input
      setUploadingLesson(null);
      return;
    }

    e.target.value = ''; // Clear input
    const { sectionId, lessonId } = uploadingLesson;
    setUploadProgress(prev => ({ ...prev, [lessonId]: 0 }));

    try {
      const getUploadUrl = httpsCallable<{courseId: string, lessonId: string, fileName: string, contentType: string}, {uploadUrl: string, r2FilePath: string}>(functionsEast, 'livekit-generateCourseUploadUrl');
      const response = await getUploadUrl({
        courseId,
        lessonId,
        fileName: file.name,
        contentType: file.type || "application/octet-stream"
      });

      const { uploadUrl, r2FilePath } = response.data;

      // Upload directly to Cloudflare R2
      const xhr = new XMLHttpRequest();
      xhr.open("PUT", uploadUrl, true);
      xhr.setRequestHeader("Content-Type", file.type || "application/octet-stream");
      
      xhr.upload.onprogress = (event) => {
        if (event.lengthComputable) {
          const progress = (event.loaded / event.total) * 100;
          setUploadProgress(prev => ({ ...prev, [lessonId]: progress }));
        }
      };

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          // Success! Use the actual Cloudflare R2 Public Dev URL
          const publicUrl = `https://pub-a368b6d04cda405ba215751acbbd17e4.r2.dev/${r2FilePath}`;
          
          setSections(sections.map(sec => {
            if (sec.id === sectionId) {
              return {
                ...sec,
                lessons: sec.lessons.map(l => 
                  l.id === lessonId ? { ...l, contentUrl: publicUrl } : l
                )
              };
            }
            return sec;
          }));
          
          setUploadingLesson(null);
          setUploadProgress(prev => {
            const newProg = { ...prev };
            delete newProg[lessonId];
            return newProg;
          });
          toast.success("File uploaded to Cloudflare successfully!");
        } else {
          throw new Error("Upload failed with status " + xhr.status);
        }
      };

      xhr.onerror = () => { throw new Error("XHR Network Error"); };
      xhr.send(file);
      
    } catch (error) {
      console.error("Upload error:", error);
      toast.error("File upload failed. Please try again.");
      setUploadingLesson(null);
      setUploadProgress(prev => {
        const newProg = { ...prev };
        delete newProg[lessonId];
        return newProg;
      });
    }
  };

  const handleDriveClick = (sectionId: string, lessonId: string, type: LessonType) => {
    if (!pickerApiLoaded || !gisLoaded) {
      toast.error("Google Drive API is still loading. Please wait a moment.");
      return;
    }
    pickerCallbackRef.current = (token: string) => {
      const google = (window as any).google;
      const view = new google.picker.DocsView(google.picker.ViewId.DOCS);
      if (type === "video") {
        view.setMimeTypes("video/mp4,video/x-m4v,video/*");
      } else if (type === "document") {
        view.setMimeTypes("application/pdf");
      }

      const picker = new google.picker.PickerBuilder()
        .addView(view)
        .setOAuthToken(token)
        .setDeveloperKey(GOOGLE_API_KEY)
        .setCallback(async (data: any) => {
          if (data.action === google.picker.Action.PICKED) {
            const doc = data.docs[0];
            const fileId = doc.id;
            const fileName = doc.name;
            const mimeType = doc.mimeType;
            
            // Set loading state
            setUploadProgress(prev => ({ ...prev, [lessonId]: 0 }));
            toast.loading("Importing file from Google Drive...", { id: `drive-${lessonId}` });

            try {
              const importDriveFile = httpsCallable<{courseId: string, lessonId: string, fileId: string, accessToken: string, mimeType: string, fileName: string}, {url: string}>(functionsEast, 'livekit-importDriveFileToR2');
              const res = await importDriveFile({
                courseId,
                lessonId,
                fileId,
                accessToken: token,
                mimeType,
                fileName
              });

              setSections(prevSections => prevSections.map(sec => {
                if (sec.id === sectionId) {
                  return {
                    ...sec,
                    lessons: sec.lessons.map(l => 
                      l.id === lessonId ? { ...l, contentUrl: res.data.url } : l
                    )
                  };
                }
                return sec;
              }));
              
              toast.success("File imported from Google Drive to Cloudflare successfully!", { id: `drive-${lessonId}` });
            } catch (error) {
              console.error("Drive import error:", error);
              toast.error("Failed to import file from Google Drive.", { id: `drive-${lessonId}` });
            } finally {
              setUploadProgress(prev => {
                const newProg = { ...prev };
                delete newProg[lessonId];
                return newProg;
              });
            }
          }
        })
        .build();
      picker.setVisible(true);
    };
    
    tokenClientRef.current.requestAccessToken();
  };

  const handleOpenQuizBuilder = (sectionId: string, lessonId: string, existingData?: QuizQuestion[]) => {
    setEditingQuizLesson({ sectionId, lessonId });
    setCurrentQuizData(existingData || []);
    setIsQuizModalOpen(true);
  };

  const handleSaveQuiz = (questions: QuizQuestion[]) => {
    if (!editingQuizLesson) return;
    setSections(sections.map(sec => {
      if (sec.id === editingQuizLesson.sectionId) {
        return {
          ...sec,
          lessons: sec.lessons.map(l => 
            l.id === editingQuizLesson.lessonId 
              ? { ...l, quizData: questions } 
              : l
          )
        };
      }
      return sec;
    }));
  };

  const handleAddSection = () => {
    const newSection: Section = {
      id: `sec-${Date.now()}`,
      title: `${t('teacher.courses.edit.section')} ${sections.length + 1}`,
      lessons: []
    };
    setSections([...sections, newSection]);
  };

  const handleAddItem = (sectionId: string, type: LessonType) => {
    setSections(sections.map(sec => {
      if (sec.id === sectionId) {
        return {
          ...sec,
          lessons: [
            ...sec.lessons,
            {
              id: `les-${Date.now()}`,
              title: `${t('teacher.courses.edit.lesson')} ${sec.lessons.length + 1}`,
              type: type,
              contentUrl: null
            }
          ]
        };
      }
      return sec;
    }));
    setActiveAddMenu(null);
  };

  const handleDeleteSection = (sectionId: string) => {
    setSections(sections.filter(s => s.id !== sectionId));
  };

  const handleDeleteLesson = (sectionId: string, lessonId: string) => {
    setSections(sections.map(sec => {
      if (sec.id === sectionId) {
        return {
          ...sec,
          lessons: sec.lessons.filter(l => l.id !== lessonId)
        };
      }
      return sec;
    }));
  };

  const handleRemoveContent = (sectionId: string, lessonId: string) => {
    setSections(sections.map(sec => {
      if (sec.id === sectionId) {
        return {
          ...sec,
          lessons: sec.lessons.map(l => l.id === lessonId ? { ...l, contentUrl: null } : l)
        };
      }
      return sec;
    }));
  };

  const handleNext = async () => {
    // Validate curriculum before proceeding
    if (sections.length === 0) {
      toast.error("يرجى إضافة قسم واحد على الأقل للمنهج");
      return;
    }

    let totalLessons = 0;

    for (const section of sections) {
      if (section.lessons.length === 0) {
        toast.error(`القسم "${section.title}" لا يحتوي على محتوى. يرجى إضافة دروس أو حذفه.`);
        return;
      }
      
      totalLessons += section.lessons.length;

      for (const lesson of section.lessons) {
        if (lesson.type !== "quiz" && !lesson.contentUrl) {
          toast.error(`الدرس "${lesson.title}" يفتقد للمحتوى. يرجى رفع الملف أو الحذف.`);
          return;
        }
        if (lesson.type === "quiz" && (!lesson.quizData || lesson.quizData.length === 0)) {
          toast.error(`الاختبار "${lesson.title}" فارغ. يرجى بناء الاختبار.`);
          return;
        }
      }
    }

    // Udemy-style minimum course requirements
    if (totalLessons < 5) {
      toast.error(`يجب أن تحتوي الدورة على 5 دروس على الأقل. (الحالي: ${totalLessons})`);
      return;
    }

    setIsPublishing(true);
    try {
      if (isDirty) {
        const docRef = doc(db, "courses", courseId);
        await updateDoc(docRef, { curriculum: sections });
      }
      setIsPublishing(false);
      router.push(`/teacher/courses/${courseId}/thumbnail`);
    } catch (err) {
      toast.error("Failed to save changes before proceeding");
      setIsPublishing(false);
    }
  };

  const handleResolveNote = async (noteId: string) => {
    const updatedNotes = reviewNotes.map(n => n.id === noteId ? { ...n, resolved: true } : n);
    setReviewNotes(updatedNotes);
    try {
      await updateDoc(doc(db, "courses", courseId), { reviewNotes: updatedNotes });
      toast.success("Marked as resolved!");
    } catch (err) {
      toast.error("Failed to update status in database.");
    }
  };

  const handleResubmitReview = async () => {
    setIsPublishing(true);
    try {
      await updateDoc(doc(db, "courses", courseId), { 
        status: "under_review", 
        lastResubmittedAt: serverTimestamp() 
      });
      setCourseStatus("under_review");
      toast.success("Course successfully re-submitted for review! 🎉");
      router.push(`/teacher/courses`);
    } catch (err) {
      toast.error("Failed to resubmit course.");
    } finally {
      setIsPublishing(false);
    }
  };

  const allResolved = reviewNotes.length > 0 && reviewNotes.every(n => n.resolved);
  const hasUnresolvedNotes = reviewNotes.some(n => !n.resolved);

  return (
    <div className="min-h-screen bg-transparent text-white pb-20">
      {/* Hidden file input for uploads */}
      <input 
        type="file" 
        ref={fileInputRef} 
        onChange={handleFileSelect} 
        className="hidden" 
      />

      {/* Draft Modal */}
      {showDraftModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-[#1C1F26] border border-white/10 rounded-2xl p-6 max-w-sm w-full shadow-2xl"
          >
            <h3 className="text-lg font-bold text-white mb-2">{t('teacher.courses.edit.unsaved_changes')}</h3>
            <p className="text-sm text-white/60 mb-6">{t('teacher.courses.edit.unsaved_desc')}</p>
            <div className="flex flex-col gap-3">
              <button 
                onClick={() => handleDraftAction('save')}
                className="w-full py-2.5 bg-[#D4AF37] hover:bg-[#E0C17E] text-black font-semibold rounded-xl transition-colors"
              >
                {t('teacher.courses.edit.save_draft')}
              </button>
              <button 
                onClick={() => handleDraftAction('discard')}
                className="w-full py-2.5 bg-red-500/10 hover:bg-red-500/20 text-red-500 font-medium rounded-xl transition-colors"
              >
                {t('teacher.courses.edit.discard')}
              </button>
              <button 
                onClick={() => setShowDraftModal(false)}
                className="w-full py-2.5 border border-white/10 hover:bg-white/5 text-white/80 font-medium rounded-xl transition-colors mt-2"
              >
                {t('teacher.courses.new.cancel')}
              </button>
            </div>
          </motion.div>
        </div>
      )}

      {/* Header */}
      <div className="sticky top-0 z-10 bg-transparent border-b border-white/5">
        <div className="max-w-4xl mx-auto px-6 py-4 grid grid-cols-3 items-center">
          
          {/* Left (RTL: Right): Back Button */}
          <div className="flex justify-start">
            <button 
              onClick={handleBack}
              className="flex items-center gap-2 text-white/50 hover:text-white transition-colors group"
            >
              <ArrowLeft className="w-5 h-5 rtl:rotate-180 transition-transform group-hover:-translate-x-1 rtl:group-hover:translate-x-1" />
              <span className="font-medium text-sm">{t('teacher.courses.edit.back')}</span>
            </button>
          </div>
          
          {/* Center: Title */}
          <div className="text-center flex flex-col items-center">
            <h1 className="text-xl font-bold font-playfair text-[#D4AF37]">
              {t('teacher.courses.edit.title')}
            </h1>
            <div className="flex items-center gap-2 mt-1">
              <p className="text-sm text-white/50">{t('teacher.courses.edit.subtitle')}</p>
              
              {/* Auto-Save Indicator */}
              {saveStatus === "saving" && (
                <span className="flex items-center gap-1.5 text-xs text-white/50 bg-white/5 px-2 py-0.5 rounded-full ml-3">
                  <Loader2 className="w-3 h-3 animate-spin" /> 
                  جاري الحفظ...
                </span>
              )}
              {saveStatus === "saved" && (
                <span className="flex items-center gap-1.5 text-xs text-[#00ac47] bg-[#00ac47]/10 px-2 py-0.5 rounded-full ml-3">
                  <CheckCircle2 className="w-3 h-3" /> 
                  تم الحفظ
                </span>
              )}
              {saveStatus === "error" && (
                <span className="flex items-center gap-1.5 text-xs text-red-400 bg-red-400/10 px-2 py-0.5 rounded-full ml-3">
                  <X className="w-3 h-3" /> 
                  خطأ في الحفظ
                </span>
              )}
            </div>
            {courseStatus === "needs_revision" && (
              <div className="mt-4 px-4 py-2 bg-red-500/10 border border-red-500/20 rounded-xl max-w-sm flex items-center justify-center gap-2">
                <X className="w-4 h-4 text-red-500" />
                <span className="text-red-500 text-xs font-bold">{t('teacher.courses.edit.needs_revision') || "Course Requires Revisions"}</span>
              </div>
            )}
          </div>
          
          {/* Right (RTL: Left): Next Button */}
          <div className="flex justify-end gap-3">
            {courseStatus === "needs_revision" && allResolved && (
              <button
                onClick={handleResubmitReview}
                disabled={isPublishing}
                className="flex items-center justify-center gap-2 px-6 py-2 rounded-lg bg-green-500 text-white font-semibold hover:bg-green-600 transition-colors disabled:opacity-50 text-sm group shadow-lg shadow-green-500/20"
              >
                {isPublishing ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
                {t('teacher.courses.edit.resubmit') || "Re-Submit for Review"}
              </button>
            )}
            <button
              onClick={handleNext}
              disabled={isPublishing || (courseStatus === "needs_revision" && hasUnresolvedNotes)}
              className="flex items-center justify-center gap-2 px-6 py-2 rounded-lg bg-[#D4AF37] text-black font-semibold hover:bg-[#E0C17E] transition-colors disabled:opacity-50 text-sm group"
            >
              {t('teacher.courses.edit.next')}
              {isPublishing ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <ArrowRight className="w-4 h-4 rtl:rotate-180 transition-transform group-hover:translate-x-1 rtl:group-hover:-translate-x-1" />
              )}
            </button>
          </div>
          
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-4xl mx-auto px-6 py-8">
        <div className="space-y-6">

          {/* General Feedback Banners */}
          {reviewNotes.filter(n => n.targetId === "general" && !n.resolved).map(note => (
            <div key={note.id} className="w-full mb-2 p-5 bg-red-500/10 border border-red-500/30 rounded-2xl relative overflow-hidden group/note shadow-lg">
              <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-red-500" />
              <div className="flex flex-col gap-3">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-black uppercase tracking-widest text-red-400 flex items-center gap-1.5">
                    <AlertCircle className="w-4 h-4" /> General Admin Feedback
                  </span>
                </div>
                <p className="text-base font-bold text-white/90 leading-relaxed">{note.message}</p>
                <div className="mt-3 flex justify-end">
                  <button 
                    onClick={() => handleResolveNote(note.id)}
                    className="px-5 py-2.5 bg-red-500 text-white rounded-xl text-xs font-bold hover:bg-red-600 transition-colors flex items-center gap-2 shadow-lg shadow-red-500/20"
                  >
                    <CheckCircle2 className="w-4 h-4" /> Mark as Resolved
                  </button>
                </div>
              </div>
            </div>
          ))}

          <AnimatePresence>
            {sections.map((section) => (
              <motion.div
                key={section.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={{ duration: 0.3, ease: "easeInOut" }}
                className="bg-[#1C1F26]/80 backdrop-blur-xl rounded-2xl border border-white/10 overflow-hidden shadow-2xl relative group/section"
              >
                {/* Subtle top highlight for depth */}
                <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/20 to-transparent opacity-50" />
                
                {/* Section Header */}
                <div className="p-5 bg-white/[0.02] border-b border-white/5 flex items-center justify-between group relative overflow-hidden">
                  <div className="absolute inset-0 bg-gradient-to-r from-[#D4AF37]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none" />
                  
                  <div className="flex items-center gap-4 flex-1 relative z-10">
                    <GripVertical className="w-5 h-5 text-white/20 cursor-grab hover:text-white/40 transition-colors" />
                    <input
                      type="text"
                      value={section.title}
                      readOnly={section.id === "sec-intro"}
                      onChange={(e) => {
                        const newTitle = e.target.value;
                        setSections(sections.map(s => s.id === section.id ? { ...s, title: newTitle } : s));
                      }}
                      className={`bg-transparent border-none outline-none text-lg font-semibold w-full focus:ring-0 p-0 text-white placeholder-white/40 ${section.id === "sec-intro" ? 'cursor-default pointer-events-none' : ''}`}
                      placeholder={t('teacher.courses.edit.section_placeholder')}
                    />
                  </div>
                  {section.id !== "sec-intro" && (
                    <button 
                      onClick={() => handleDeleteSection(section.id)}
                      className="p-2 text-white/20 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors opacity-0 group-hover:opacity-100 relative z-10"
                      title="Delete Section"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>

                {/* Lessons List */}
                <div className="p-4 space-y-3">
                  <AnimatePresence>
                    {section.lessons.map((lesson) => (
                      <motion.div
                        key={lesson.id}
                        initial={{ opacity: 0, x: -20, filter: 'blur(4px)' }}
                        animate={{ opacity: 1, x: 0, filter: 'blur(0px)' }}
                        exit={{ opacity: 0, scale: 0.95, filter: 'blur(4px)' }}
                        transition={{ duration: 0.2 }}
                        className="flex items-center gap-4 p-4 rounded-xl bg-white/[0.03] hover:bg-white/[0.06] border border-white/5 hover:border-white/10 shadow-sm transition-all duration-300 group relative overflow-hidden"
                      >
                        {/* Hover accent line */}
                        <div className="absolute left-0 top-0 bottom-0 w-1 bg-[#D4AF37] opacity-0 group-hover:opacity-100 transition-all duration-300 scale-y-50 group-hover:scale-y-100" />
                        
                        <GripVertical className="w-5 h-5 text-white/20 cursor-grab hover:text-white/60 transition-colors ml-2" />
                        
                        <div className="flex-1 flex flex-col gap-1">
                          <input
                            type="text"
                            value={lesson.title}
                            readOnly={section.id === "sec-intro" && (lesson.id === "les-intro-1" || lesson.id === "les-intro-2")}
                            onChange={(e) => {
                              const newTitle = e.target.value;
                              setSections(sections.map(sec => {
                                if (sec.id === section.id) {
                                  return {
                                    ...sec,
                                    lessons: sec.lessons.map(l => l.id === lesson.id ? { ...l, title: newTitle } : l)
                                  };
                                }
                                return sec;
                              }));
                            }}
                            className={`bg-transparent border-none outline-none text-sm font-medium w-full focus:ring-0 p-0 text-white placeholder-white/40 ${section.id === "sec-intro" && (lesson.id === "les-intro-1" || lesson.id === "les-intro-2") ? 'cursor-default pointer-events-none' : ''}`}
                            placeholder={t('teacher.courses.edit.lesson_placeholder')}
                          />
                          <span className="text-xs text-white/40 flex items-center gap-1 mt-1">
                            {lesson.type === "video" && <Video className="w-3 h-3" />}
                            {lesson.type === "document" && <FileText className="w-3 h-3" />}
                            {lesson.type === "quiz" && <LayoutList className="w-3 h-3" />}
                            {lesson.contentUrl ? t('teacher.courses.edit.video_uploaded') : t('teacher.courses.edit.missing_video')}
                          </span>
                        </div>

                        {/* Action Button */}
                        {lesson.type === "video" && !lesson.contentUrl && uploadProgress[lesson.id] === undefined && (
                          <div className="flex items-center gap-2">
                            <button 
                              onClick={() => triggerUpload(section.id, lesson.id, "video/mp4,video/x-m4v,video/*")}
                              className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-[#D4AF37] hover:border-[#D4AF37] hover:bg-[#D4AF37]/10 transition-all text-xs font-medium shrink-0"
                            >
                              <CloudUpload className="w-3 h-3" />
                              {t('teacher.courses.edit.upload_mp4')}
                            </button>
                            <button 
                              onClick={() => handleDriveClick(section.id, lesson.id, "video")}
                              className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-green-400 hover:border-green-400 hover:bg-green-400/10 transition-all text-xs font-medium shrink-0"
                            >
                              <DriveIcon className="w-3.5 h-3.5" />
                              {t('teacher.courses.edit.add_from_drive') || 'Add from Drive'}
                            </button>
                          </div>
                        )}
                        {lesson.type === "document" && !lesson.contentUrl && uploadProgress[lesson.id] === undefined && (
                          <div className="flex items-center gap-2">
                            <button 
                              onClick={() => triggerUpload(section.id, lesson.id, "application/pdf")}
                              className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-blue-400 hover:border-blue-400 hover:bg-blue-400/10 transition-all text-xs font-medium shrink-0"
                            >
                              <CloudUpload className="w-3 h-3" />
                              {t('teacher.courses.edit.upload_pdf')}
                            </button>
                            <button 
                              onClick={() => handleDriveClick(section.id, lesson.id, "document")}
                              className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-green-400 hover:border-green-400 hover:bg-green-400/10 transition-all text-xs font-medium shrink-0"
                            >
                              <DriveIcon className="w-3.5 h-3.5" />
                              {t('teacher.courses.edit.add_from_drive') || 'Add from Drive'}
                            </button>
                          </div>
                        )}
                        {uploadProgress[lesson.id] !== undefined && (
                          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[#D4AF37]/30 bg-[#D4AF37]/10 text-[#D4AF37] text-xs font-medium shrink-0">
                            <Loader2 className="w-3 h-3 animate-spin" />
                            {Math.round(uploadProgress[lesson.id])}%
                          </div>
                        )}
                        {lesson.contentUrl && lesson.type !== "quiz" && (
                          <div className="flex items-center gap-2">
                            <span className="px-3 py-1.5 rounded-lg bg-green-500/10 text-green-400 text-xs font-medium flex items-center gap-1.5 border border-green-500/20 shrink-0">
                              <CheckCircle2 className="w-3 h-3" />
                              {lesson.type === "video" ? t('teacher.courses.edit.video_uploaded') || "تم الرفع" : "تم الرفع"}
                            </span>
                            <button
                              onClick={() => setPreviewMedia({ url: lesson.contentUrl!, type: lesson.type })}
                              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-blue-400 hover:border-blue-400 hover:bg-blue-400/10 transition-all text-xs font-medium shrink-0"
                            >
                              <Eye className="w-3 h-3" />
                              معاينة
                            </button>
                            <button
                              onClick={() => handleRemoveContent(section.id, lesson.id)}
                              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-red-400 hover:border-red-400 hover:bg-red-400/10 transition-all text-xs font-medium shrink-0"
                            >
                              <Trash2 className="w-3 h-3" />
                              إزالة
                            </button>
                          </div>
                        )}
                        {lesson.type === "quiz" && (
                          <button 
                            onClick={() => handleOpenQuizBuilder(section.id, lesson.id, lesson.quizData)}
                            className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-white/10 text-white/60 hover:text-purple-400 hover:border-purple-400 hover:bg-purple-400/10 transition-all text-xs font-medium"
                          >
                            <Plus className="w-3 h-3" />
                            {lesson.quizData && lesson.quizData.length > 0 
                              ? t('teacher.courses.edit.edit_quiz', { count: lesson.quizData.length }) 
                              : t('teacher.courses.edit.build_quiz')}
                          </button>
                        )}

                        {!(section.id === "sec-intro" && (lesson.id === "les-intro-1" || lesson.id === "les-intro-2")) && (
                          <button 
                            onClick={() => handleDeleteLesson(section.id, lesson.id)}
                            className="p-2 text-white/20 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors opacity-0 group-hover:opacity-100"
                            title="Delete Lesson"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                        
                        {/* Display Unresolved Feedback Notes */}
                        {reviewNotes.filter(n => n.targetId === `lesson_${lesson.id}` && !n.resolved).map(note => (
                          <div key={note.id} className="w-full mt-4 p-4 bg-red-500/10 border border-red-500/30 rounded-xl relative overflow-hidden group/note">
                            <div className="absolute left-0 top-0 bottom-0 w-1 bg-red-500" />
                            <div className="flex flex-col gap-2">
                              <div className="flex items-center justify-between">
                                <span className="text-[10px] font-black uppercase tracking-widest text-red-400 flex items-center gap-1.5">
                                  <AlertCircle className="w-3 h-3" /> Admin Feedback
                                </span>
                              </div>
                              <p className="text-sm font-bold text-white/90 leading-relaxed">{note.message}</p>
                              <div className="mt-3 flex justify-end">
                                <button 
                                  onClick={() => handleResolveNote(note.id)}
                                  className="px-4 py-2 bg-red-500 text-white rounded-lg text-xs font-bold hover:bg-red-600 transition-colors flex items-center gap-2"
                                >
                                  <CheckCircle2 className="w-4 h-4" /> Mark as Resolved
                                </button>
                              </div>
                            </div>
                          </div>
                        ))}
                      </motion.div>
                    ))}
                  </AnimatePresence>

                  {activeAddMenu === section.id ? (
                    <motion.div 
                      className="flex flex-col sm:flex-row items-start sm:items-center gap-2 px-4 py-3 w-full rounded-xl border border-white/10 bg-white/5 mt-2"
                    >
                      <span className="text-sm font-medium text-white/60 mr-2">
                        {t('teacher.courses.edit.select_type')}:
                      </span>
                      
                      <div className="flex flex-wrap gap-2 w-full sm:w-auto">
                        <button 
                          onClick={() => handleAddItem(section.id, 'video')} 
                          className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-[#D4AF37]/20 hover:text-[#D4AF37] transition-all text-xs font-medium border border-transparent hover:border-[#D4AF37]/30"
                        >
                          <Video className="w-3 h-3" /> {t('teacher.courses.edit.type_video')}
                        </button>
                        <button 
                          onClick={() => handleAddItem(section.id, 'document')} 
                          className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-blue-400/20 hover:text-blue-400 transition-all text-xs font-medium border border-transparent hover:border-blue-400/30"
                        >
                          <FileText className="w-3 h-3" /> {t('teacher.courses.edit.type_document')}
                        </button>
                        <button 
                          onClick={() => handleAddItem(section.id, 'quiz')} 
                          className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-purple-400/20 hover:text-purple-400 transition-all text-xs font-medium border border-transparent hover:border-purple-400/30"
                        >
                          <LayoutList className="w-3 h-3" /> {t('teacher.courses.edit.type_quiz')}
                        </button>
                      </div>

                      <button 
                        onClick={() => setActiveAddMenu(null)} 
                        className="p-1.5 ms-auto text-white/40 hover:text-white/80 hover:bg-white/10 rounded-lg transition-colors flex-shrink-0"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    </motion.div>
                  ) : (
                    <button
                      onClick={() => setActiveAddMenu(section.id)}
                      className="flex items-center gap-2 px-4 py-2 w-full justify-center rounded-xl border border-dashed border-white/10 text-white/50 hover:text-white/80 hover:border-white/30 hover:bg-white/5 transition-all text-sm font-medium mt-2 group"
                    >
                      <Plus className="w-4 h-4 group-hover:scale-110 transition-transform" />
                      {t('teacher.courses.edit.add_item')}
                    </button>
                  )}
                </div>
              </motion.div>
            ))}
          </AnimatePresence>

            <button
              onClick={handleAddSection}
              className="flex items-center justify-center gap-2 w-full p-5 rounded-2xl border border-dashed border-[#D4AF37]/30 text-[#D4AF37]/80 hover:text-[#D4AF37] hover:border-[#D4AF37]/60 hover:bg-[#D4AF37]/10 hover:shadow-[0_0_20px_rgba(212,175,55,0.1)] transition-all duration-300 font-medium group"
            >
              <Plus className="w-5 h-5 group-hover:scale-125 transition-transform duration-300" />
              {t('teacher.courses.edit.add_section')}
            </button>
        </div>
      </div>

      {/* Quiz Builder Modal */}
      <QuizBuilderModal
        isOpen={isQuizModalOpen}
        onClose={() => setIsQuizModalOpen(false)}
        initialQuestions={currentQuizData}
        onSave={handleSaveQuiz}
      />

      {/* Media Preview Modal */}
      <AnimatePresence>
        {previewMedia && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-4"
          >
            <motion.div
              initial={{ scale: 0.95 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.95 }}
              className="bg-[#1C1F26] border border-white/10 rounded-2xl overflow-hidden w-full max-w-4xl shadow-2xl relative flex flex-col max-h-[90vh]"
            >
              <div className="flex justify-between items-center p-4 border-b border-white/10 bg-white/5">
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <Eye className="w-5 h-5 text-[#D4AF37]" />
                  معاينة المحتوى
                </h3>
                <button 
                  onClick={() => setPreviewMedia(null)} 
                  className="text-white/50 hover:text-white bg-white/5 hover:bg-white/10 p-2 rounded-xl transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="p-4 flex-1 flex justify-center items-center bg-black min-h-[50vh] overflow-hidden">
                {previewMedia.type === "video" ? (
                  <video 
                    src={`${previewMedia.url}?t=${Date.now()}`} 
                    controls 
                    crossOrigin="anonymous"
                    className="w-full h-full max-h-[70vh] object-contain rounded-lg shadow-[0_0_40px_rgba(212,175,55,0.1)]" 
                    autoPlay 
                  />
                ) : (
                  <iframe 
                    src={`${previewMedia.url}?t=${Date.now()}`} 
                    className="w-full h-full min-h-[60vh] rounded-lg bg-white" 
                  />
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
