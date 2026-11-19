"use client";

import React, { useState, useRef } from "react";
import { motion } from "framer-motion";
import { X, Minus, Plus } from "lucide-react";

interface ProtractorOverlayProps {
  angle: number;
  onAngleChange: (newAngle: number) => void;
  onClose: () => void;
  isTeacher: boolean;
}

export default function ProtractorOverlay({
  angle,
  onAngleChange,
  onClose,
  isTeacher,
}: ProtractorOverlayProps) {
  // Common calligraphy angles
  const presets = [45, 60, 70, 90];

  return (
    <div className="absolute inset-0 z-40 pointer-events-none flex items-center justify-center overflow-hidden">
      {/* The glowing protractor crosshair */}
      <div className="relative w-[40vw] h-[40vw] max-w-[600px] max-h-[600px] border-2 border-primary/20 rounded-full flex items-center justify-center pointer-events-auto">
        {/* Horizontal Baseline */}
        <div className="absolute w-full h-px bg-white/30" />
        {/* Vertical Reference */}
        <div className="absolute h-full w-px bg-white/10" />

        {/* The Angle Line */}
        {/* CSS transform rotate uses 0deg at 12 o'clock if it's a vertical line, 
            but for calligraphy, 0deg is usually the horizontal baseline. 
            So if we have a horizontal line and rotate it by -angle, it goes up from the right. */}
        <motion.div
          animate={{ rotate: -angle }}
          transition={{ type: "spring", stiffness: 300, damping: 30 }}
          className="absolute w-[120%] h-1"
        >
          <div className="w-full h-full bg-gradient-to-r from-transparent via-[#E8C468] to-transparent shadow-[0_0_15px_#E8C468]" />
        </motion.div>

        {/* Center Dot */}
        <div className="w-4 h-4 bg-primary rounded-full shadow-[0_0_20px_#E8C468]" />
        
        {/* Angle Text Display */}
        <div className="absolute top-10 text-primary/80 font-black text-2xl font-outfit tracking-widest bg-black/50 px-4 py-1 rounded-full backdrop-blur-sm border border-primary/20">
          {angle}°
        </div>
      </div>

      {/* Control Panel (Hoverable) */}
      <div className="absolute right-8 top-1/2 -translate-y-1/2 pointer-events-auto bg-[#13151A]/90 backdrop-blur-md border border-white/10 rounded-2xl p-4 flex flex-col gap-4 shadow-2xl">
        <div className="flex items-center justify-between">
          <span className="text-white/60 text-xs font-bold uppercase tracking-widest">Qalam Angle</span>
          <button onClick={onClose} className="p-1 hover:bg-white/10 rounded-full text-white/40 hover:text-white transition-colors">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex items-center gap-3 bg-black/50 p-2 rounded-xl border border-white/5">
          <button 
            onClick={() => onAngleChange(Math.max(0, angle - 1))}
            className="p-2 hover:bg-white/10 rounded-lg transition-colors text-white"
          >
            <Minus className="w-4 h-4" />
          </button>
          <div className="w-12 text-center font-bold text-xl text-primary font-outfit">
            {angle}°
          </div>
          <button 
            onClick={() => onAngleChange(Math.min(180, angle + 1))}
            className="p-2 hover:bg-white/10 rounded-lg transition-colors text-white"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-2">
          {presets.map((preset) => (
            <button
              key={preset}
              onClick={() => onAngleChange(preset)}
              className={`py-2 px-3 rounded-lg text-sm font-bold transition-all ${
                angle === preset 
                  ? "bg-primary text-black shadow-[0_0_15px_rgba(232,196,104,0.3)]" 
                  : "bg-white/5 text-white/60 hover:bg-white/10 hover:text-white"
              }`}
            >
              {preset}°
            </button>
          ))}
        </div>
        
        {isTeacher && (
          <div className="text-[10px] text-white/30 text-center uppercase tracking-widest mt-2 border-t border-white/5 pt-3">
            Syncs to Class
          </div>
        )}
      </div>
    </div>
  );
}
