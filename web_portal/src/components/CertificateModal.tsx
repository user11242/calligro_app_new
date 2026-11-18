"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Download, ExternalLink, Check, Copy, Loader2, Award, ShieldCheck } from "lucide-react";
import Link from "next/link";
import CalligroCertificate from "@/components/CalligroCertificate";

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
    teacherSignatureUrl?: string | null;
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
        : new Date(
            certificate.issueDate.seconds
              ? certificate.issueDate.seconds * 1000
              : certificate.issueDate
          )
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
      <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4 md:p-6 overflow-y-auto">
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
          className="relative w-full max-w-[1200px] bg-[#141414] border border-white/10 rounded-3xl shadow-2xl overflow-hidden z-10 flex flex-col my-auto max-h-[96vh]"
        >
          {/* Header Bar */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-white/10 bg-[#1A1A1A] shrink-0">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-[#D4AF37]/15 flex items-center justify-center">
                <Award className="w-5 h-5 text-[#D4AF37]" />
              </div>
              <div>
                <h3 className="text-white font-bold text-sm sm:text-base leading-snug">
                  شهادة إتمام · {certificate.studentName}
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
                <span>{copied ? "تم النسخ" : "نسخ المعرف"}</span>
              </button>

              <Link
                href={`/verify/${certificate.id}`}
                target="_blank"
                rel="noreferrer"
                className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-medium border border-white/10 transition-colors"
              >
                <ShieldCheck className="w-3.5 h-3.5 text-[#D4AF37]" />
                <span>صفحة التحقق</span>
                <ExternalLink className="w-3 h-3 text-white/40" />
              </Link>

              <button
                onClick={handleDownload}
                disabled={downloading}
                className="flex items-center gap-2 px-4 py-1.5 rounded-xl text-black font-bold text-xs shadow-lg transition-transform hover:scale-105 disabled:opacity-50"
                style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}
              >
                {downloading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Download className="w-3.5 h-3.5" />}
                <span>{downloading ? "جارٍ التحميل..." : "تحميل الشهادة PDF"}</span>
              </button>

              <button
                onClick={onClose}
                className="p-1.5 rounded-xl text-white/40 hover:text-white hover:bg-white/10 transition-colors ml-2"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Certificate Container with Scroll and Exact Rendering */}
          <div className="p-4 sm:p-6 bg-[#0a0a0a] flex items-center justify-center overflow-auto flex-1">
            <div className="relative overflow-visible flex items-center justify-center scale-[0.65] sm:scale-[0.75] md:scale-[0.85] lg:scale-[0.95] origin-center my-[-80px] sm:my-[-40px]">
              <CalligroCertificate
                id="certificate-modal-render"
                certificateId={certificate.id}
                studentName={certificate.studentName}
                courseName={certificate.courseName}
                teacherName={certificate.teacherName}
                teacherSignatureUrl={certificate.teacherSignatureUrl}
                dateStr={dateStr}
                totalHours={certificate.totalHours}
              />
            </div>
          </div>

          {/* Footer Controls */}
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 px-6 py-3.5 bg-[#1A1A1A] border-t border-white/10 text-xs text-white/50 shrink-0">
            <p>
              الشهادة الرسمية المعتمدة لطلاب أكاديمية كاليغرو (Official Calligro Academy Certificate)
            </p>
            <div className="flex items-center gap-3">
              <Link
                href={`/courses/${certificate.courseId}/certificate?studentId=${certificate.studentId || ""}`}
                target="_blank"
                className="text-[#D4AF37] hover:underline flex items-center gap-1 font-semibold"
              >
                <span>عرض في صفحة كاملة</span>
                <ExternalLink className="w-3 h-3" />
              </Link>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
