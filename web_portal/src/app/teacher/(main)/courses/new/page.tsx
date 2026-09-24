"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { 
  BookOpen, Type, Tag, Signal, FileText, Target, DollarSign, 
  Plus, X, Loader2, ArrowLeft, ArrowRight, MonitorPlay 
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { collection, addDoc, serverTimestamp, doc, getDoc } from "firebase/firestore";
import Link from "next/link";
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

export default function CreateRecordedCoursePage() {
  const router = useRouter();
  const { t } = useTranslation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  // Form State
  const [title, setTitle] = useState("");
  const [writingType, setWritingType] = useState(WRITING_TYPES[0]);
  const [calligraphyStyle, setCalligraphyStyle] = useState("Naskh");
  const [level, setLevel] = useState(LEVELS[0]);
  const [description, setDescription] = useState("");
  const [outcomes, setOutcomes] = useState<string[]>(["", "", "", "", ""]);
  const [price, setPrice] = useState(PRICE_TIERS[0].toString());

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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
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
        createdAt: serverTimestamp(),
        enrolledStudents: [],
        enrolledCount: 0,
        rating: 0,
        reviewCount: 0,
        isPublished: false,
      };

      const docRef = await addDoc(collection(db, "courses"), courseData);
      
      toast.success(t('teacher.courses.new.success'));
      router.push(`/teacher/courses/${docRef.id}/edit`);
    } catch (error) {
      console.error("Error creating course:", error);
      toast.error(t('teacher.courses.new.error_failed'));
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-12 pb-32 pt-10 px-4 sm:px-0">
      
      {/* Minimalist Header */}
      <motion.div {...fadeUp(0)} className="flex items-center justify-between border-b border-white/10 pb-8">
        <div className="flex items-center gap-6">
          <Link href="/teacher/courses">
            <button className="w-10 h-10 flex items-center justify-center text-white/50 hover:text-white hover:bg-white/5 rounded-lg transition-all">
              <ArrowLeft className="w-5 h-5 rtl:rotate-180" />
            </button>
          </Link>
          <div>
            <p className="text-[#D4AF37] text-sm font-medium tracking-wide mb-1 flex items-center gap-2">
              <MonitorPlay className="w-4 h-4" />
              {t('teacher.courses.new.subtitle')}
            </p>
            <h1 className="text-3xl font-bold text-white">
              {t('teacher.courses.new.title')}
            </h1>
          </div>
        </div>
      </motion.div>

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

        {/* Submit Actions */}
        <motion.div {...fadeUp(0.2)} className="flex items-center gap-4 pt-12">
          <button
            type="submit"
            disabled={isSubmitting}
            className="flex items-center justify-center gap-2 px-6 py-3 rounded-lg bg-[#D4AF37] text-black font-semibold hover:bg-[#E0C17E] transition-colors disabled:opacity-50"
          >
            <span>{t('teacher.courses.new.save')}</span>
            {isSubmitting ? (
              <Loader2 className="w-5 h-5 animate-spin" />
            ) : (
              <ArrowRight className="w-5 h-5 rtl:rotate-180" />
            )}
          </button>
          <Link href="/teacher/courses">
            <button type="button" className="px-6 py-3 rounded-lg border border-white/10 text-white/70 hover:text-white hover:bg-white/5 transition-colors">
              {t('teacher.courses.new.cancel')}
            </button>
          </Link>
        </motion.div>
      </form>
    </div>
  );
}
