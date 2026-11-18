"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Download, ExternalLink, Check, Copy, Loader2, Award, ShieldCheck } from "lucide-react";
import Link from "next/link";

interface CertificateModalProps {
  isOpen: boolean;
  onClose: () => void;
  certificate: {
    id: string;
    studentId?: string;
    studentName: string;
    courseId: string;
    courseName: string;
    teacherName?: string;
    issueDate?: any;
    totalHours?: number | null;
  } | null;
}

export default function CertificateModal({ isOpen, onClose, certificate }: CertificateModalProps) {
  const [downloading, setDownloading] = useState(false);
  const [copied, setCopied] = useState(false);

  if (!isOpen || !certificate) return null;

  const dateStr = certificate.issueDate
    ? (certificate.issueDate.toDate
        ? certificate.issueDate.toDate()
        : new Date(certificate.issueDate.seconds ? certificate.issueDate.seconds * 1000 : certificate.issueDate)
      ).toLocaleDateString("ar-SA", { year: "numeric", month: "long", day: "numeric" })
    : new Date().toLocaleDateString("ar-SA", { year: "numeric", month: "long", day: "numeric" });

  const handleCopyId = () => {
    navigator.clipboard.writeText(certificate.id);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = async () => {
    const element = document.getElementById("certificate-modal-render");
    if (!element) return;
    setDownloading(true);
    try {
      const { toPng } = await import("html-to-image");
      const { jsPDF } = await import("jspdf");

      const imgData = await toPng(element, {
        pixelRatio: 3,
        style: {
          transform: "scale(1)",
          transformOrigin: "top left",
        },
        cacheBust: true,
      });

      const pdf = new jsPDF({
        orientation: "landscape",
        unit: "mm",
        format: "a4",
      });

      pdf.addImage(imgData, "PNG", 0, 0, 297, 210);
      const safeName = (certificate.studentName || "Student").replace(/\s+/g, "_");
      pdf.save(`Calligro_Certificate_${safeName}.pdf`);
    } catch (error) {
      console.error("Error generating certificate PDF:", error);
    } finally {
      setDownloading(false);
    }
  };

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 overflow-y-auto">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="fixed inset-0 bg-black/85 backdrop-blur-md"
        />

        {/* Modal Window */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 16 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 16 }}
          className="relative w-full max-w-5xl bg-[#181818] border border-white/10 rounded-3xl shadow-2xl overflow-hidden z-10 flex flex-col my-auto"
        >
          {/* Header Bar */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-white/10 bg-[#202020]">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-[#D4AF37]/15 flex items-center justify-center">
                <Award className="w-5 h-5 text-[#D4AF37]" />
              </div>
              <div>
                <h3 className="text-white font-bold text-sm sm:text-base leading-snug">
                  Certificate Preview · {certificate.studentName}
                </h3>
                <p className="text-white/40 text-xs font-mono">ID: {certificate.id}</p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={handleCopyId}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-medium border border-white/10 transition-colors"
                title="Copy Certificate ID"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-green-400" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copied ? "Copied" : "Copy ID"}</span>
              </button>

              <Link
                href={`/verify/${certificate.id}`}
                target="_blank"
                rel="noreferrer"
                className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-medium border border-white/10 transition-colors"
              >
                <ShieldCheck className="w-3.5 h-3.5 text-[#D4AF37]" />
                <span>Verify Page</span>
                <ExternalLink className="w-3 h-3 text-white/40" />
              </Link>

              <button
                onClick={handleDownload}
                disabled={downloading}
                className="flex items-center gap-2 px-4 py-1.5 rounded-xl text-black font-bold text-xs shadow-lg transition-transform hover:scale-105 disabled:opacity-50"
                style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}
              >
                {downloading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Download className="w-3.5 h-3.5" />}
                <span>{downloading ? "Generating..." : "Download PDF"}</span>
              </button>

              <button
                onClick={onClose}
                className="p-1.5 rounded-xl text-white/40 hover:text-white hover:bg-white/10 transition-colors ml-2"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Certificate Container with Scroll */}
          <div className="p-4 sm:p-8 bg-[#0F0F0F] flex items-center justify-center overflow-x-auto">
            {/* The Scaled Render Area */}
            <div
              id="certificate-modal-render"
              className="w-[1123px] h-[794px] min-w-[1123px] relative overflow-hidden flex flex-col bg-[#fdfcf9] shadow-2xl origin-top"
              dir="rtl"
            >
              {/* Dynamic Geometric Shapes matching official Calligro Certificate */}
              <div
                className="absolute left-0 bottom-0 w-[55%] h-[80%] bg-gradient-to-br from-[#e6c86a] to-[#b38f20] z-0 shadow-[20px_-20px_60px_rgba(0,0,0,0.1)]"
                style={{ clipPath: "polygon(0 20%, 100% 100%, 0 100%)" }}
              />

              <div
                className="absolute right-0 top-0 w-[40%] h-[45%] bg-[#111111] z-0 shadow-[-10px_10px_30px_rgba(0,0,0,0.2)]"
                style={{ clipPath: "polygon(100% 0, 100% 100%, 20% 0)" }}
              />

              {/* Decorative Borders */}
              <div className="absolute inset-[24px] border-[1px] border-[#d4af37]/40 pointer-events-none z-10" />
              <div className="absolute inset-[30px] border-[2px] border-[#111111]/20 pointer-events-none z-10" />

              {/* Certificate Inner Content */}
              <div className="relative z-20 flex flex-col justify-between h-full p-16 select-none">
                {/* Header */}
                <div className="flex justify-between items-start">
                  <div>
                    <h2 className="text-[#111111] font-bold text-2xl tracking-wider">كاليجرو</h2>
                    <p className="text-[10px] tracking-widest text-[#d4af37] font-semibold uppercase mt-0.5">
                      CALLIGRO ACADEMY
                    </p>
                  </div>
                  <div className="text-left" dir="ltr">
                    <p className="text-[#d4af37] font-mono text-xs font-bold tracking-widest uppercase">
                      CERTIFICATE ID
                    </p>
                    <p className="text-[#111111] font-mono text-xs tracking-wider">{certificate.id}</p>
                  </div>
                </div>

                {/* Main Body */}
                <div className="text-center my-auto px-12">
                  <p className="text-[#a6801e] text-xs font-bold tracking-[0.3em] uppercase mb-3">
                    شهادة إتمام معتمدة
                  </p>
                  <h1 className="text-5xl font-black text-[#111111] tracking-tight mb-8 font-serif">
                    شهادة إنجاز
                  </h1>

                  <p className="text-base text-[#555555] font-medium mb-4">
                    تشهد أكاديمية كاليجرو بأن الطالب / الطالبة:
                  </p>

                  <div className="inline-block relative mb-6">
                    <p className="text-4xl sm:text-5xl font-black text-[#111111] border-b-2 border-[#d4af37] pb-3 px-8 min-w-[320px]">
                      {certificate.studentName}
                    </p>
                  </div>

                  <p className="text-base text-[#555555] font-medium mb-3">
                    قد أتم بنجاح متطلبات الدورة التدريبية المتخصصة:
                  </p>

                  <p className="text-2xl font-black text-[#856404] tracking-wide mb-6">
                    &quot;{certificate.courseName}&quot;
                  </p>

                  {certificate.totalHours && (
                    <p className="text-sm text-[#777777] font-medium">
                      بإجمالي تدريب فعلي مقداره <span className="font-bold text-[#111111]">{certificate.totalHours}</span> ساعة تدريبية معتمدة
                    </p>
                  )}
                </div>

                {/* Signatures & Footer */}
                <div className="grid grid-cols-3 items-end pt-8 border-t border-[#d4af37]/20">
                  <div className="text-center">
                    <div className="w-36 h-12 border-b border-[#111111]/30 mx-auto mb-2 flex items-center justify-center">
                      <span className="font-serif italic text-lg text-[#111111]/70">{certificate.teacherName || "Master Instructor"}</span>
                    </div>
                    <p className="text-xs font-bold text-[#111111]">مدرب المساق</p>
                    <p className="text-[10px] text-[#777777] mt-0.5">{certificate.teacherName || "المدرب المعتمد"}</p>
                  </div>

                  {/* Golden Seal */}
                  <div className="flex flex-col items-center justify-center">
                    <div className="w-20 h-20 rounded-full border-2 border-[#d4af37] bg-gradient-to-br from-[#e6c86a] to-[#b38f20] flex items-center justify-center shadow-lg p-2 text-center text-[#111111]">
                      <div className="w-full h-full rounded-full border border-[#111111]/20 flex flex-col items-center justify-center">
                        <Award className="w-6 h-6 text-[#111111]" />
                        <span className="text-[7px] font-black uppercase tracking-widest mt-0.5">VERIFIED</span>
                      </div>
                    </div>
                    <p className="text-[9px] text-[#777777] font-mono mt-2 tracking-wider">
                      calligroacademy.com/verify
                    </p>
                  </div>

                  <div className="text-center">
                    <div className="w-36 h-12 border-b border-[#111111]/30 mx-auto mb-2 flex items-center justify-center">
                      <span className="text-sm font-semibold text-[#111111]/80">{dateStr}</span>
                    </div>
                    <p className="text-xs font-bold text-[#111111]">تاريخ الإصدار</p>
                    <p className="text-[10px] text-[#777777] mt-0.5">أكاديمية كاليجرو الدولية</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Footer Controls */}
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 px-6 py-4 bg-[#202020] border-t border-white/10 text-xs text-white/50">
            <p>
              Digital Ijazah verified through SHA-256 cryptographically indexed document store.
            </p>
            <div className="flex items-center gap-3">
              <Link
                href={`/courses/${certificate.courseId}/certificate?studentId=${certificate.studentId || ""}`}
                target="_blank"
                className="text-[#D4AF37] hover:underline flex items-center gap-1 font-semibold"
              >
                <span>Full Page View</span>
                <ExternalLink className="w-3 h-3" />
              </Link>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}

