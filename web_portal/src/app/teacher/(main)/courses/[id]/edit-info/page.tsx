"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { 
  BookOpen, Type, Tag, Signal, FileText, Target, DollarSign, 
  Plus, X, Loader2, ArrowLeft, ArrowRight, MonitorPlay 
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { doc, getDoc, updateDoc } from "firebase/firestore";
import Link from "next/link";
import { useParams } from "next/navigation";
import { toast } from "react-hot-toast";
import { useTranslation } from "@/hooks/useTranslation";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay, ease: "easeOut" as const },
});

const WRITING_TYPES = [
  "Arabic Calligraphy",
  "Normal Pen Writing"
];

const CALLIGRAPHY_STYLES = [
  "Kufi",
  "Naskh",
  "Ruqah",
  "Thuluth",
  "Jali Thuluth",
  "Diwani",
  "Jali Diwani",
  "Persian (Taliq)",
  "Ijaza",
  "Muhaqqaq",
  "Rayhani"
];

const STYLE_KEYS: Record<string, string> = {
  "Kufi": "kufi",
  "Naskh": "naskh",
  "Ruqah": "ruqah",
  "Thuluth": "thuluth",
  "Jali Thuluth": "jali_thuluth",
  "Diwani": "diwani",
  "Jali Diwani": "jali_diwani",
  "Persian (Taliq)": "persian",
  "Ijaza": "ijaza",
  "Muhaqqaq": "muhaqqaq",
  "Rayhani": "rayhani"
};

const LEVELS = ["Beginner", "Intermediate", "Advanced"];
const PRICE_TIERS = [50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100];

export default function EditCourseInfoPage() {
  const router = useRouter();
  const params = useParams();
  const courseId = params.id as string;
  const { t } = useTranslation();
  
  const [loading, setLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDirty, setIsDirty] = useState(false);
  const [showDraftModal, setShowDraftModal] = useState(false);
  const [initialData, setInitialData] = useState<any>(null);
  
  // Form State
  const [title, setTitle] = useState("");
  const [writingType, setWritingType] = useState(WRITING_TYPES[0]);
  const [calligraphyStyle, setCalligraphyStyle] = useState("Naskh");
  const [level, setLevel] = useState(LEVELS[0]);
  const [description, setDescription] = useState("");
  const [outcomes, setOutcomes] = useState<string[]>(["", "", "", "", ""]);
  const [price, setPrice] = useState(PRICE_TIERS[0].toString());

  useEffect(() => {
    const fetchCourse = async () => {
      try {
        const docRef = doc(db, "courses", courseId);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          const data = docSnap.data();
          const p = (data.price ? data.price / 2 : PRICE_TIERS[0]).toString();
          const w = data.writingType || WRITING_TYPES[0];
          const c = data.calligraphyStyle || "Naskh";
          const l = data.level || LEVELS[0];
          
          let fetchedOutcomes = ["", "", "", "", ""];
          if (data.learningOutcomes && data.learningOutcomes.length > 0) {
            fetchedOutcomes = [...data.learningOutcomes];
            while (fetchedOutcomes.length < 5) fetchedOutcomes.push("");
          }

          setTitle(data.courseName || "");
          setWritingType(w);
          setCalligraphyStyle(c);
          setLevel(l);
          setDescription(data.courseDescription || "");
          setOutcomes(fetchedOutcomes);
          setPrice(p);
          
          setInitialData({
            title: data.courseName || "",
            writingType: w,
            calligraphyStyle: c,
            level: l,
            description: data.courseDescription || "",
            outcomes: fetchedOutcomes,
            price: p
          });
        }
      } catch (error) {
        console.error("Error fetching course:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchCourse();
  }, [courseId]);

  useEffect(() => {
    if (!initialData) return;
    const currentData = { title, writingType, calligraphyStyle, level, description, outcomes, price };
    setIsDirty(JSON.stringify(currentData) !== JSON.stringify(initialData));
  }, [title, writingType, calligraphyStyle, level, description, outcomes, price, initialData]);

  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (isDirty) {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [isDirty]);

  const handleBack = () => {
    if (isDirty) {
      setShowDraftModal(true);
    } else {
      router.push('/teacher/courses');
    }
  };

  const handleAddOutcome = () => setOutcomes([...outcomes, ""]);
  
  const handleUpdateOutcome = (index: number, value: string) => {
    const newOutcomes = [...outcomes];
    newOutcomes[index] = value;
    setOutcomes(newOutcomes);
  };
  
  const handleRemoveOutcome = (index: number) => {
    if (outcomes.length > 5) {
      setOutcomes(outcomes.filter((_, i) => i !== index));
    }
  };

  const handleSubmit = async (e?: React.FormEvent | React.MouseEvent) => {
    if (e) {
      e.preventDefault();
    }
    
    if (!auth.currentUser) {
      toast.error(t('teacher.courses.new.error_login'));
      return;
    }

    if (!title.trim() || !description.trim() || !price) {
      toast.error(t('teacher.courses.new.error_fields'));
      return;
    }

    setIsSubmitting(true);

    try {
      const validOutcomes = outcomes.filter(o => o.trim().length > 0);
      
      if (validOutcomes.length < 5) {
        toast.error(t('teacher.courses.new.error_outcomes'));
        setIsSubmitting(false);
        return;
      }
      const databasePrice = Number(price);

      // Fetch teacher details to ensure structure matches live courses
      const userDoc = await getDoc(doc(db, "users", auth.currentUser!.uid));
      const userData = userDoc.data();
      const teacherName = userData?.name || "Unknown Teacher";
      const teacherProfilePic = userData?.photoUrl || "";

      const courseData = {
        courseName: title.trim(),
        writingType: writingType,
        calligraphyStyle: writingType === "Arabic Calligraphy" ? calligraphyStyle : null,
        level: level,
        selectedCategory: level, // Backwards compatibility for flutter app
        courseDescription: description.trim(),
        learningOutcomes: validOutcomes,
        price: databasePrice,
        iapProductId: `com.yazan.calligro.tier_${databasePrice}`,
        teacherId: auth.currentUser!.uid,
        teacherName: teacherName,
        teacherProfilePic: teacherProfilePic,
        courseType: "recorded",
        status: "draft",
        // Keep original createdAt and enrolledStudents if it's an update, so omit them
      };

      const docRef = doc(db, "courses", courseId);
      await updateDoc(docRef, courseData);
      
      toast.success(t('teacher.courses.new.success'));
      router.push(`/teacher/courses/${courseId}/edit`);
    } catch (error) {
      console.error("Error creating course:", error);
      toast.error(t('teacher.courses.new.error_failed'));
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#13151A]">
        <Loader2 className="w-8 h-8 animate-spin text-[#D4AF37]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-transparent text-white pb-20 relative">
      
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
                onClick={(e) => { setShowDraftModal(false); handleSubmit(e); }}
                className="w-full py-2.5 bg-[#D4AF37] hover:bg-[#E0C17E] text-black font-semibold rounded-xl transition-colors"
              >
                {t('teacher.courses.edit.save_draft')}
              </button>
              <button 
                onClick={() => router.push('/teacher/courses')}
                className="w-full py-2.5 bg-red-500/10 hover:bg-red-500/20 text-red-500 font-medium rounded-xl transition-colors"
              >
                {t('teacher.courses.edit.discard')}
              </button>
              <button 
                onClick={() => setShowDraftModal(false)}
                className="w-full py-2.5 border border-white/10 hover:bg-white/5 text-white/70 rounded-xl transition-colors"
              >
                {t('teacher.courses.new.cancel')}
              </button>
            </div>
          </motion.div>
        </div>
      )}

      {/* Sticky Header */}
      <div className="sticky top-0 z-10 bg-transparent border-b border-white/5">
        <div className="max-w-4xl mx-auto px-6 py-4 grid grid-cols-3 items-center">
          
          {/* Left (RTL: Right): Back Button */}
          <div className="flex justify-start">
            <button 
              type="button"
              onClick={handleBack}
              className="flex items-center gap-2 text-white/50 hover:text-white transition-colors group"
            >
              <ArrowLeft className="w-5 h-5 rtl:rotate-180 transition-transform group-hover:-translate-x-1 rtl:group-hover:translate-x-1" />
              <span className="font-medium text-sm">{t('teacher.courses.edit.back')}</span>
            </button>
          </div>
          
          {/* Center: Title */}
          <div className="text-center">
            <h1 className="text-xl font-bold font-playfair text-[#D4AF37]">
              {t('teacher.courses.new.title')}
            </h1>
            <p className="text-sm text-white/50 mt-1">{t('teacher.courses.new.subtitle')}</p>
          </div>
          
          {/* Right (RTL: Left): Next Button */}
          <div className="flex justify-end">
            <button
              onClick={handleSubmit}
              disabled={isSubmitting}
              className="flex items-center justify-center gap-2 px-6 py-2 rounded-lg bg-[#D4AF37] text-black font-semibold hover:bg-[#E0C17E] transition-colors disabled:opacity-50 text-sm group"
            >
              {t('teacher.courses.edit.next')}
              {isSubmitting ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <ArrowRight className="w-4 h-4 rtl:rotate-180 transition-transform group-hover:translate-x-1 rtl:group-hover:-translate-x-1" />
              )}
            </button>
          </div>
          
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-6 py-8">
        <form onSubmit={handleSubmit} className="space-y-12">
        
        {/* Section 1: Basic Info */}
        <motion.div {...fadeUp(0.05)} className="space-y-8">
          <h2 className="text-xl font-semibold text-white/90 pb-2 border-b border-white/5">
            {t('teacher.courses.new.basic_info')}
          </h2>
          
          <div className="space-y-6 max-w-2xl">
            <div className="space-y-2">
              <label className="text-sm font-medium text-white/70 ml-1 rtl:mr-1 rtl:ml-0 flex items-center gap-1">
                {t('teacher.courses.new.course_title')}
                <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={title}
                onChange={e => setTitle(e.target.value)}
                placeholder={t('teacher.courses.new.course_title_ph')}
                className="w-full bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-3.5 text-white placeholder-white/50 outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all"
                required
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-sm font-medium text-white/70 ml-1 rtl:mr-1 rtl:ml-0">
                  {t('teacher.courses.new.category')}
                </label>
                <div className="relative">
                  <select
                    value={writingType}
                    onChange={e => setWritingType(e.target.value)}
                    className="w-full bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-3.5 text-white outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all appearance-none cursor-pointer"
                  >
                    {WRITING_TYPES.map(c => (
                      <option key={c} value={c}>
                        {t(`teacher.courses.new.types.${c === "Arabic Calligraphy" ? "arabic_calligraphy" : "normal_pen"}`)}
                      </option>
                    ))}
                  </select>
                  <div className="absolute right-4 rtl:right-auto rtl:left-4 top-1/2 -translate-y-1/2 pointer-events-none text-white/40 text-xs">
                    ▼
                  </div>
                </div>
              </div>

              {writingType === "Arabic Calligraphy" && (
                <div className="space-y-2">
                  <label className="text-sm font-medium text-white/70 ml-1 rtl:mr-1 rtl:ml-0">
                    {t('teacher.courses.new.calligraphy_style')}
                  </label>
                  <div className="relative">
                    <select
                      value={calligraphyStyle}
                      onChange={e => setCalligraphyStyle(e.target.value)}
                      className="w-full bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-3.5 text-white outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all appearance-none cursor-pointer"
                    >
                      {CALLIGRAPHY_STYLES.map(s => (
                        <option key={s} value={s}>
                          {t(`teacher.courses.new.styles.${STYLE_KEYS[s]}`)}
                        </option>
                      ))}
                    </select>
                    <div className="absolute right-4 rtl:right-auto rtl:left-4 top-1/2 -translate-y-1/2 pointer-events-none text-white/40 text-xs">
                      ▼
                    </div>
                  </div>
                </div>
              )}
              
              <div className="space-y-2">
                <label className="text-sm font-medium text-white/70 ml-1 rtl:mr-1 rtl:ml-0">
                  {t('teacher.courses.new.level')}
                </label>
                <div className="relative">
                  <select
                    value={level}
                    onChange={e => setLevel(e.target.value)}
                    className="w-full bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-3.5 text-white outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all appearance-none cursor-pointer"
                  >
                    {LEVELS.map(l => (
                      <option key={l} value={l}>
                        {t(`teacher.courses.new.levels.${l.toLowerCase()}`)}
                      </option>
                    ))}
                  </select>
                  <div className="absolute right-4 rtl:right-auto rtl:left-4 top-1/2 -translate-y-1/2 pointer-events-none text-white/40 text-xs">
                    ▼
                  </div>
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Section 2: Details */}
        <motion.div {...fadeUp(0.1)} className="space-y-8">
          <h2 className="text-xl font-semibold text-white/90 pb-2 border-b border-white/5">
            {t('teacher.courses.new.details')}
          </h2>
          
          <div className="space-y-10 max-w-2xl">
            <div className="space-y-2">
              <label className="text-sm font-medium text-white/70 ml-1 rtl:mr-1 rtl:ml-0 flex items-center gap-1">
                {t('teacher.courses.new.description')}
                <span className="text-red-500">*</span>
              </label>
              <textarea
                value={description}
                onChange={e => setDescription(e.target.value)}
                placeholder={t('teacher.courses.new.description_ph')}
                rows={6}
                maxLength={5000}
                className="w-full bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-4 text-white placeholder-white/50 outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all resize-y leading-relaxed"
                required
              />
              <div className="flex justify-end mt-2">
                <span className={`text-xs font-medium ${description.length >= 5000 ? 'text-red-500' : 'text-white/40'}`}>
                  {description.length} / 5000
                </span>
              </div>
            </div>

            <div className="space-y-4">
              <div className="space-y-1 mb-4">
                <label className="text-sm font-medium text-white/90">
                  {t('teacher.courses.new.outcomes')}
                </label>
                <p className="text-white/40 text-sm">{t('teacher.courses.new.outcomes_desc')}</p>
              </div>
              
              <div className="space-y-3">
                {outcomes.map((outcome, index) => (
                  <div key={index} className="flex items-center gap-3">
                    <input
                      type="text"
                      value={outcome}
                      onChange={e => handleUpdateOutcome(index, e.target.value)}
                      placeholder={`${t('teacher.courses.new.outcomes_ph')} ${writingType}`}
                      className="flex-1 bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-3 text-white placeholder-white/50 outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all"
                    />
                    {outcomes.length > 5 && (
                      <button
                        type="button"
                        onClick={() => handleRemoveOutcome(index)}
                        className="p-3 text-white/30 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors shrink-0"
                        title="Remove Outcome"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    )}
                  </div>
                ))}
              </div>
              
              <button
                type="button"
                onClick={handleAddOutcome}
                className="flex items-center gap-2 text-sm text-[#D4AF37] font-medium hover:text-white transition-colors"
              >
                <Plus className="w-4 h-4" /> {t('teacher.courses.new.add_outcome')}
              </button>
            </div>
          </div>
        </motion.div>

        {/* Section 3: Pricing */}
        <motion.div {...fadeUp(0.15)} className="space-y-8">
          <h2 className="text-xl font-semibold text-white/90 pb-2 border-b border-white/5">
            {t('teacher.courses.new.pricing')}
          </h2>
          
          <div className="space-y-6 max-w-2xl">
            <div className="space-y-2">
              <label className="text-sm font-medium text-white/70 ml-1 rtl:mr-1 rtl:ml-0 flex items-center gap-1">
                {t('teacher.courses.new.web_price')}
                <span className="text-red-500">*</span>
              </label>
              <p className="text-white/40 text-xs mb-2">
                {t('teacher.courses.new.web_price_desc')}
              </p>
              <div className="relative w-full max-w-xs">
                <select
                  value={price}
                  onChange={e => setPrice(e.target.value)}
                  className="w-full bg-[#2C2C2C] border border-white/30 rounded-xl px-5 py-3.5 text-white outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all appearance-none cursor-pointer"
                  required
                >
                  {PRICE_TIERS.map(tier => (
                    <option key={tier} value={tier}>${tier}</option>
                  ))}
                </select>
                <div className="absolute right-4 rtl:right-auto rtl:left-4 top-1/2 -translate-y-1/2 pointer-events-none text-white/40 text-xs">
                  ▼
                </div>
              </div>
            </div>
          </div>
        </motion.div>

      </form>
      </div>
    </div>
  );
}
