"use client";

import { useState } from "react";
import { useTranslation } from "@/hooks/useTranslation";
import { useRouter, useParams } from "next/navigation";
import { motion } from "framer-motion";
import { 
  ArrowLeft, CheckCircle2, Loader2, Image as ImageIcon, UploadCloud 
} from "lucide-react";
import Link from "next/link";
import toast from "react-hot-toast";
import { db } from "@/lib/firebase";
import { doc, updateDoc } from "firebase/firestore";

export default function CourseThumbnailPage() {
  const { t } = useTranslation();
  const router = useRouter();
  const params = useParams();
  const courseId = params.id as string;
  
  const [isPublishing, setIsPublishing] = useState(false);
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  const handlePublish = async () => {
    if (!previewImage) {
      toast.error(t('teacher.courses.thumbnail.error_no_image') || "يرجى رفع صورة الغلاف أولاً");
      return;
    }

    setIsPublishing(true);
    
    try {
      // If we have an actual file, we would upload it here. 
      // For now, we'll save the data URL directly as a placeholder if it's small,
      // but in production we must upload to R2/Firebase Storage first.
      
      const docRef = doc(db, "courses", courseId);
      await updateDoc(docRef, { 
        status: 'under_review',
        // thumbnail: previewImage // We can save this if it's an uploaded URL, but data URL might be too large for Firestore
      });

      toast.success(t('teacher.courses.edit.publish_success') || "تم إرسال الدورة للمراجعة بنجاح!");
      router.push("/teacher/courses");
    } catch (err) {
      console.error("Error submitting for review:", err);
      toast.error("حدث خطأ أثناء الإرسال للمراجعة");
    } finally {
      setIsPublishing(false);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Create a fake local preview for UI purposes
      const reader = new FileReader();
      reader.onloadend = () => {
        setPreviewImage(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  return (
    <div className="min-h-screen bg-transparent text-white pb-20">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-transparent border-b border-white/5">
        <div className="max-w-4xl mx-auto px-6 py-4 grid grid-cols-3 items-center">
          
          {/* Left (RTL: Right): Back Button */}
          <div className="flex justify-start">
            <button 
              onClick={() => router.push(`/teacher/courses/${courseId}/edit`)}
              className="flex items-center gap-2 text-white/50 hover:text-white transition-colors group"
            >
              <ArrowLeft className="w-5 h-5 rtl:rotate-180 transition-transform group-hover:-translate-x-1 rtl:group-hover:translate-x-1" />
              <span className="font-medium text-sm">{t('teacher.courses.edit.back')}</span>
            </button>
          </div>
          
          {/* Center: Title */}
          <div className="text-center">
            <h1 className="text-xl font-bold font-playfair text-[#D4AF37]">
              {t('teacher.courses.thumbnail.title')}
            </h1>
            <p className="text-sm text-white/50 mt-1">{t('teacher.courses.thumbnail.subtitle')}</p>
          </div>
          
          {/* Right (RTL: Left): Publish Button */}
          <div className="flex justify-end">
            <button
              onClick={handlePublish}
              disabled={isPublishing}
              className="flex items-center justify-center gap-2 px-6 py-2 rounded-lg bg-[#D4AF37] text-black font-semibold hover:bg-[#E0C17E] transition-colors disabled:opacity-50 text-sm"
            >
              {isPublishing ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <CheckCircle2 className="w-4 h-4" />
              )}
              {t('teacher.courses.thumbnail.publish')}
            </button>
          </div>
          
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-4xl mx-auto px-6 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-[#2C2C2C] rounded-3xl border border-white/10 p-8 shadow-2xl"
        >
          <div className="flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 rounded-2xl bg-[#D4AF37]/10 text-[#D4AF37] flex items-center justify-center mb-6">
              <ImageIcon className="w-8 h-8" />
            </div>
            
            <h2 className="text-2xl font-bold mb-2">{t('teacher.courses.thumbnail.inner_title')}</h2>
            <p className="text-white/50 mb-8 max-w-md">
              {t('teacher.courses.thumbnail.inner_desc')}
            </p>

            <div className="w-full relative">
              <input
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
              />
              
              <div className={`
                border-2 border-dashed rounded-2xl transition-all duration-300 overflow-hidden
                ${previewImage ? 'border-[#D4AF37]/50 bg-[#D4AF37]/5' : 'border-white/10 bg-white/5 hover:border-white/30 hover:bg-white/10'}
                flex flex-col items-center justify-center min-h-[300px] relative
              `}>
                {previewImage ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img 
                    src={previewImage} 
                    alt="Course Preview" 
                    className="absolute inset-0 w-full h-full object-cover"
                  />
                ) : (
                  <div className="flex flex-col items-center justify-center text-white/50">
                    <UploadCloud className="w-12 h-12 mb-4 text-white/30" />
                    <p className="font-medium text-white/80">{t('teacher.courses.thumbnail.upload_box')}</p>
                    <p className="text-sm mt-2">{t('teacher.courses.thumbnail.upload_hint')}</p>
                  </div>
                )}
                
                {/* Overlay on hover when image exists */}
                {previewImage && (
                  <div className="absolute inset-0 bg-black/60 opacity-0 hover:opacity-100 transition-opacity flex flex-col items-center justify-center pointer-events-none">
                    <UploadCloud className="w-10 h-10 mb-2 text-white" />
                    <p className="font-medium text-white">{t('teacher.courses.thumbnail.click_replace')}</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
