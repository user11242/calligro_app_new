import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { AlertCircle, X, Headphones } from "lucide-react";

interface AudioOnlyPromptProps {
  isOpen: boolean;
  onAccept: () => void;
  onDismiss: () => void;
}

export default function AudioOnlyPrompt({ isOpen, onAccept, onDismiss }: AudioOnlyPromptProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0, y: 50, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 20, scale: 0.95 }}
          transition={{ type: "spring", stiffness: 300, damping: 25 }}
          className="absolute bottom-6 left-1/2 -translate-x-1/2 z-[100] max-w-md w-full px-4"
        >
          <div className="bg-[#1C1F26]/95 backdrop-blur-xl border border-white/10 rounded-2xl shadow-2xl p-5 overflow-hidden relative">
            {/* Glow effect */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-primary/10 rounded-full blur-3xl pointer-events-none" />
            
            <button
              onClick={onDismiss}
              className="absolute top-3 right-3 text-white/40 hover:text-white/80 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex gap-4">
              <div className="flex-shrink-0 w-12 h-12 bg-red-500/10 rounded-full flex items-center justify-center border border-red-500/20">
                <AlertCircle className="w-6 h-6 text-red-500" />
              </div>
              
              <div className="flex flex-col">
                <h3 className="text-white font-semibold text-lg font-outfit mb-1">
                  Connection Unstable
                </h3>
                <p className="text-white/60 text-sm leading-relaxed mb-4 font-outfit">
                  Your network is struggling. Switch to Audio-Only mode to save bandwidth and prevent the class from freezing.
                </p>
                
                <div className="flex gap-3">
                  <button
                    onClick={onAccept}
                    className="flex-1 bg-primary hover:bg-primary/90 text-black font-semibold py-2.5 rounded-xl transition-all shadow-[0_0_15px_rgba(212,175,55,0.2)] flex items-center justify-center gap-2 text-sm"
                  >
                    <Headphones className="w-4 h-4" />
                    Switch to Audio-Only
                  </button>
                  <button
                    onClick={onDismiss}
                    className="px-4 py-2.5 bg-white/5 hover:bg-white/10 text-white font-medium rounded-xl border border-white/10 transition-colors text-sm"
                  >
                    Dismiss
                  </button>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
