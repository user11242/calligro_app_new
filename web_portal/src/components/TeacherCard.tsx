"use client";
import { CheckCircle2, BookOpen, ArrowRight } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useTranslation } from "@/hooks/useTranslation";
import AutoTranslatedText from "./AutoTranslatedText";

interface TeacherCardProps {
  teacher: {
    uid: string;
    name: string;
    photoUrl?: string;
    email?: string;
    bio?: string;
    courseCount?: number;
  };
}

export default function TeacherCard({ teacher }: TeacherCardProps) {
  const { t } = useTranslation();

  const formatImageUrl = (url?: string) => {
    if (!url) return "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop";
    if (url.startsWith('http')) return url;
    return `https://firebasestorage.googleapis.com/v0/b/calligro-app.appspot.com/o/${encodeURIComponent(url)}?alt=media`;
  };

  return (
    <div className="group relative">
      {/* Background Glow */}
      <div className="absolute -inset-1 bg-gradient-to-r from-primary/20 to-transparent rounded-[2.5rem] blur-xl opacity-0 group-hover:opacity-100 transition-all duration-700" />
      
      <div className="relative bg-white/[0.03] backdrop-blur-3xl border border-white/10 rounded-[2.5rem] p-8 shadow-2xl overflow-hidden transition-all duration-700 hover:bg-white/[0.05] hover:border-primary/20 hover:-translate-y-2">
        {/* Artistic Backdrop Element */}
        <div className="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2 group-hover:bg-primary/10 transition-colors duration-700" />

        <div className="flex flex-col items-center text-center">
          {/* Avatar Section */}
          <div className="relative mb-6">
            <div className="w-32 h-32 rounded-3xl overflow-hidden border-2 border-white/10 p-1 group-hover:border-primary/40 transition-all duration-700 transform group-hover:rotate-3">
              <Image 
                src={formatImageUrl(teacher.photoUrl) || "/images/placeholder.png"} 
                alt={teacher.name}
                width={128}
                height={128}
                className="w-full h-full object-cover rounded-2xl grayscale-[50%] group-hover:grayscale-0 transition-all duration-700 scale-105 group-hover:scale-115"
              />
            </div>
            <div className="absolute -bottom-2 -right-2 bg-primary text-black p-2 rounded-2xl shadow-2xl border-4 border-secondary-dark ring-4 ring-primary/20">
              <CheckCircle2 className="w-5 h-5" />
            </div>
          </div>

          {/* Name & Title */}
          <div className="space-y-2 mb-6">
            <h3 className="text-2xl font-black font-outfit uppercase tracking-tighter text-white group-hover:text-primary transition-colors duration-500">
              {teacher.name}
            </h3>
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/5 rounded-full border border-white/10">
              <span className="text-[10px] font-black uppercase tracking-[0.2em] text-white/40 group-hover:text-primary/60 transition-colors">
                {t("course.master")}
              </span>
            </div>
          </div>

          {/* Bio / Stats */}
          {teacher.bio && (
            <p className="text-white/40 text-sm line-clamp-2 mb-6 px-4 leading-relaxed">
              <AutoTranslatedText text={teacher.bio} />
            </p>
          )}

          <div className="grid grid-cols-1 w-full gap-4 pt-6 border-t border-white/5">
            <Link 
              href={`/courses?search=${encodeURIComponent(teacher.name)}`}
              className="flex items-center justify-center gap-3 w-full bg-white/5 hover:bg-primary hover:text-black border border-white/10 hover:border-primary px-6 py-4 rounded-2xl transition-all duration-500 group/btn"
            >
              <BookOpen className="w-5 h-5" />
              <span className="text-xs font-black uppercase tracking-widest">
                {t("course.learn_more")}
              </span>
              <ArrowRight className="w-4 h-4 opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0 transition-all" />
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
