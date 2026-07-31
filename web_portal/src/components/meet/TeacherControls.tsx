"use client";

import React from "react";
import { TrackToggle, useLocalParticipant } from "@livekit/components-react";
import { Track } from "livekit-client";
import { MicOff } from "lucide-react";
import { motion } from "framer-motion";

export default function TeacherControls() {
  const { localParticipant } = useLocalParticipant();

  const handleMuteAll = async () => {
    const encoder = new TextEncoder();
    const data = encoder.encode(JSON.stringify({ cmd: "mute_all" }));
    await localParticipant.publishData(data, { reliable: true });
  };

  return (
    <div className="flex items-center gap-1.5 lk-custom-toggles">
      
      <TrackToggle source={Track.Source.Microphone} className="lk-toggle-btn" />
      <TrackToggle source={Track.Source.Camera} className="lk-toggle-btn" />
      <TrackToggle source={Track.Source.ScreenShare} className="lk-toggle-btn" />

      <style dangerouslySetInnerHTML={{__html: `
        .lk-custom-toggles .lk-toggle-btn { 
          background-color: rgba(255, 255, 255, 0.05); 
          color: white; 
          border-radius: 9999px; /* Fully rounded pill */
          padding: 0.875rem; /* Larger hit area */
          transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1); 
          border: none;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          position: relative;
          overflow: hidden;
        }
        .lk-custom-toggles .lk-toggle-btn:hover { 
          background-color: rgba(255, 255, 255, 0.1); 
          transform: scale(1.05);
        }
        .lk-custom-toggles .lk-toggle-btn:active {
          transform: scale(0.95);
        }
        .lk-custom-toggles .lk-toggle-btn[data-state="true"] {
          background-color: rgba(235, 185, 55, 0.15); /* Primary tint */
          color: #EBB937;
          box-shadow: 0 0 15px rgba(235, 185, 55, 0.2);
        }
        .lk-custom-toggles .lk-toggle-btn[data-state="false"] { 
          background-color: rgba(239, 68, 68, 0.1); 
          color: rgb(239, 68, 68); 
        }
        .lk-custom-toggles .lk-toggle-btn[data-state="false"]:hover { 
          background-color: rgb(239, 68, 68); 
          color: white; 
          box-shadow: 0 0 20px rgba(239, 68, 68, 0.4);
        }
        .lk-custom-toggles .lk-button-text { display: none; }
        .lk-custom-toggles svg { width: 1.25rem; height: 1.25rem; }
      `}} />

      <div className="w-px h-8 bg-white/10 mx-1" />
      
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={handleMuteAll}
        className="px-4 py-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-full transition-colors duration-300 flex items-center gap-2 text-[13px] font-bold tracking-wide"
      >
        <MicOff className="w-4 h-4" />
        <span className="hidden sm:inline">Mute Class</span>
      </motion.button>
    </div>
  );
}
