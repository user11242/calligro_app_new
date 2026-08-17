"use client";
import { CheckCircle2, ArrowRight, Star } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useTranslation } from "@/hooks/useTranslation";

interface TeacherCardProps {
  teacher: {
    uid: string;
    name: string;
    fullName?: string;
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
    <Link href={`/teachers/${teacher.uid}`} className="group block h-full">
      <div className="bg-[#181818] border border-white/5 rounded-[2rem] p-8 transition-all duration-500 hover:bg-[#222222] hover:border-white/10 flex flex-col items-center text-center h-full">
        {/* Avatar Section */}
        <div className="relative mb-6">
          <div className="w-28 h-28 rounded-full overflow-hidden border-2 border-white/5 transition-transform duration-500 group-hover:scale-105">
            <Image 
              src={formatImageUrl(teacher.photoUrl) || "/images/placeholder.png"} 
              alt={teacher.fullName || teacher.name}
              width={112}
              height={112}
              className="w-full h-full object-cover grayscale-[20%] group-hover:grayscale-0 transition-all duration-500"
            />
          </div>
          <div className="absolute -bottom-1 -right-1 bg-[#E8C468] text-black p-1.5 rounded-full shadow-lg border-[3px] border-[#181818]">
            <CheckCircle2 className="w-5 h-5" />
          </div>
        </div>

        {/* Name & Title */}
        <div className="space-y-1 mb-6 flex-grow">
          <h3 className="text-2xl font-bold font-outfit uppercase tracking-wider text-white group-hover:text-[#E8C468] transition-colors duration-300">
            {teacher.fullName || teacher.name}
          </h3>
          <div className="flex items-center justify-center gap-1 mt-2">
            {[...Array(5)].map((_, i) => (
              <Star key={i} className="w-4 h-4 fill-[#E8C468] text-[#E8C468]" />
            ))}
            <span className="text-white/40 text-xs font-bold ml-2">5.0</span>
          </div>
        </div>

        {/* Action button */}
        <div className="w-full flex items-center justify-center gap-2 pt-6 border-t border-white/5 text-white/50 group-hover:text-[#E8C468] transition-colors text-xs font-bold uppercase tracking-widest mt-2">
          <span>{t("teachers.view_profile") || "View Profile"}</span>
          <ArrowRight className={`w-4 h-4 opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-300`} />
        </div>
      </div>
    </Link>
  );
}
