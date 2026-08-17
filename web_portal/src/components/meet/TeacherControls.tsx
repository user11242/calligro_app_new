"use client";

import React, { useState } from "react";
import { TrackToggle, useDataChannel, useLocalParticipant } from "@livekit/components-react";
import { Track } from "livekit-client";
import { MicOff, Monitor, MonitorOff } from "lucide-react";
import { motion } from "framer-motion";

export default function TeacherControls() {
  const { send } = useDataChannel("classroom-events");
  const { localParticipant } = useLocalParticipant();
  const [isScreenSharing, setIsScreenSharing] = useState(false);

  const handleMuteAll = async () => {
    const encoder = new TextEncoder();
    const data = encoder.encode(JSON.stringify({ cmd: "mute_all" }));
    send(data, { reliable: true });
  };

  const toggleScreenShare = async () => {
    try {
      if (isScreenSharing) {
        await localParticipant.setScreenShareEnabled(false);
        setIsScreenSharing(false);
      } else {
        // Request screen share WITH system audio (browser will show audio checkbox)
        await localParticipant.setScreenShareEnabled(true, {
          audio: true,
          contentHint: "detail",
        });
        setIsScreenSharing(true);
      }
    } catch (err) {
      console.error("Screen share error:", err);
      setIsScreenSharing(false);
    }
  };

  return (
    <div className="flex items-center gap-1.5 lk-custom-toggles">
      
      <TrackToggle source={Track.Source.Microphone} className="lk-toggle-btn" />
      <TrackToggle source={Track.Source.Camera} className="lk-toggle-btn" />
      {/* Custom screen share button that requests audio too */}
      <button
        onClick={toggleScreenShare}
        className={`lk-toggle-btn ${isScreenSharing ? 'lk-toggle-btn-active' : ''}`}
        title={isScreenSharing ? "Stop Sharing" : "Share Screen (with Audio)"}
      >
        {isScreenSharing ? <MonitorOff style={{ width: '1.25rem', height: '1.25rem' }} /> : <Monitor style={{ width: '1.25rem', height: '1.25rem' }} />}
      </button>

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
        .lk-custom-toggles .lk-toggle-btn-active {
          background-color: rgba(235, 185, 55, 0.15);
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
