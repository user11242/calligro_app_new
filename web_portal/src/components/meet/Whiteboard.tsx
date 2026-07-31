"use client";

import React, { useEffect, useState } from "react";
import { Tldraw } from "@tldraw/tldraw";
import "@tldraw/tldraw/tldraw.css";
import { Loader2 } from "lucide-react";

interface WhiteboardProps {
  isTeacher: boolean;
}

export default function Whiteboard({ isTeacher }: WhiteboardProps) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <div className="w-full h-full flex flex-col items-center justify-center bg-[#13151A] rounded-3xl border border-white/5">
        <Loader2 className="w-8 h-8 text-primary animate-spin mb-4" />
        <p className="text-white/40 text-xs font-bold uppercase tracking-widest">Loading Canvas...</p>
      </div>
    );
  }

  return (
    <div className="w-full h-full relative rounded-3xl overflow-hidden shadow-2xl border border-white/10 whiteboard-container" style={{ zIndex: 10 }}>
      <style dangerouslySetInnerHTML={{__html: `
        .whiteboard-container .tl-watermark_logo,
        .whiteboard-container .tl-watermark_link,
        .whiteboard-container .tlui-layout__watermark,
        .whiteboard-container [class*="watermark"],
        .whiteboard-container a[href*="tldraw"] {
          display: none !important;
          opacity: 0 !important;
          pointer-events: none !important;
        }
      `}} />
      <Tldraw
        inferDarkMode
        readOnly={false}
      />
    </div>
  );
}
