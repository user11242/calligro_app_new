"use client";

import React, { useState, useEffect } from "react";
import {
  useTracks,
  GridLayout,
  ParticipantTile,
  TrackReferenceOrPlaceholder,
  useDataChannel,
  useParticipants,
} from "@livekit/components-react";
import { Track } from "livekit-client";
import { Users, MessageSquare, PhoneOff, ShieldCheck, PenTool, Hand } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import ParticipantsPanel from "./ParticipantsPanel";
import ChatPanel from "./ChatPanel";
import TeacherControls from "./TeacherControls";
import StudentControls from "./StudentControls";
import Whiteboard from "./Whiteboard";

interface CalligroMeetLayoutProps {
  courseId: string;
  isTeacher: boolean;
  onLeave: () => void;
  isRecordingMode?: boolean;
}

export default function CalligroMeetLayout({
  courseId,
  isTeacher,
  onLeave,
  isRecordingMode = false,
}: CalligroMeetLayoutProps) {
  const tracks = useTracks(
    [
      { source: Track.Source.Camera, withPlaceholder: true },
      { source: Track.Source.ScreenShare, withPlaceholder: false },
    ],
    { onlySubscribed: false }
  );

  const participants = useParticipants();
  const [activeTab, setActiveTab] = useState<"chat" | "participants" | null>(null);
  const [isWhiteboardActive, setIsWhiteboardActive] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Check if ANY track is a screen share to automatically trigger Focus Mode
  const isScreenSharing = tracks.some((t) => t.source === Track.Source.ScreenShare);
  
  // Focus Mode is active if Whiteboard is ON or someone is Screen Sharing
  const isFocusMode = isWhiteboardActive || isScreenSharing;

  // Data channel for handling events like "Raise Hand"
  const { send } = useDataChannel("classroom-events", (msg) => {
    try {
      const data = JSON.parse(new TextDecoder().decode(msg.payload));
      if (data.type === "RAISE_HAND") {
        setToastMessage(`${data.name} raised their hand! ✋`);
        setTimeout(() => setToastMessage(null), 5000);
      }
      if (data.cmd === "toggle_whiteboard") {
        setIsWhiteboardActive(data.state);
      }
    } catch (e) {}
  });

  return (
    <div className="flex-1 flex overflow-hidden bg-[#0A0A0B] text-white font-outfit selection:bg-primary/30 relative">
      
      {/* Ambient Animated Background */}
      <div className="absolute inset-0 z-0 pointer-events-none overflow-hidden">
        <div className="absolute top-[20%] left-[10%] w-[40vw] h-[40vw] bg-primary/5 rounded-full blur-[100px] animate-pulse" style={{ animationDuration: '4s' }} />
        <div className="absolute bottom-[10%] right-[20%] w-[35vw] h-[35vw] bg-blue-500/5 rounded-full blur-[120px] animate-pulse" style={{ animationDuration: '6s' }} />
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col relative overflow-hidden z-10 transition-all duration-500">
        
        {/* Toast Notifications */}
        <AnimatePresence>
          {toastMessage && (
            <motion.div
              initial={{ opacity: 0, y: -50, x: "-50%" }}
              animate={{ opacity: 1, y: 0, x: "-50%" }}
              exit={{ opacity: 0, y: -50, x: "-50%" }}
              className="absolute top-6 left-1/2 -translate-x-1/2 z-50 bg-primary text-black px-6 py-3 rounded-full shadow-[0_10px_40px_rgba(235,185,55,0.4)] flex items-center gap-3"
            >
              <Hand className="w-5 h-5 animate-bounce" />
              <span className="font-bold text-sm tracking-wide">{toastMessage}</span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Dynamic Focus Layout */}
        <div className={`flex-1 p-4 pb-28 overflow-hidden flex transition-all duration-700 ${isFocusMode ? "gap-4" : ""}`}>
          
          {/* Main Focus Area (Whiteboard or Screen Share) */}
          <AnimatePresence>
            {isWhiteboardActive && (
              <motion.div 
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.95, display: "none" }}
                transition={{ duration: 0.4 }}
                className="flex-[3] h-full relative"
              >
                <Whiteboard isTeacher={isTeacher} />
              </motion.div>
            )}
          </AnimatePresence>

          {/* Video Grid (Shrinks to sidebar if Focus Mode is active) */}
          <motion.div 
            layout
            className={`h-full transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] ${
              isFocusMode ? (isWhiteboardActive ? "flex-1" : "hidden") : "flex-1 w-full"
            } custom-participant-grid`}
          >
             <style dangerouslySetInnerHTML={{__html: `
               .custom-participant-grid .lk-participant-placeholder > svg {
                 display: none !important;
               }
             `}} />
             <GridLayout 
                tracks={tracks as TrackReferenceOrPlaceholder[]} 
                style={{ height: '100%', width: '100%', gap: '16px' }}
              >
              <ParticipantTile 
                className="rounded-3xl overflow-hidden shadow-2xl border border-white/5 bg-[#13151A]"
              />
            </GridLayout>
          </motion.div>
        </div>

        {/* The "Dynamic Island" Control Bar */}
        {!isRecordingMode && (
          <motion.div 
            initial={{ y: 50, opacity: 0, x: "-50%" }}
            animate={{ y: 0, opacity: 1, x: "-50%" }}
            transition={{ type: "spring", stiffness: 300, damping: 25, delay: 0.3 }}
            className="absolute bottom-8 left-1/2 -translate-x-1/2 bg-[#1A1C23]/80 backdrop-blur-3xl border border-white/10 p-2.5 rounded-full flex items-center gap-2 shadow-[0_20px_60px_rgba(0,0,0,0.6)] z-30"
          >
            {isTeacher ? <TeacherControls /> : <StudentControls />}
            
            <div className="w-px h-8 bg-white/10 mx-1" />
            
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => {
                  const newState = !isWhiteboardActive;
                  setIsWhiteboardActive(newState);
                  // TODO: Send data channel message to sync whiteboard state
                }}
                className={`p-3.5 rounded-full transition-all duration-300 flex items-center justify-center relative group ${
                  isWhiteboardActive ? "bg-primary text-black shadow-[0_0_20px_rgba(235,185,55,0.4)]" : "bg-white/5 hover:bg-white/10 text-white"
                }`}
                title="Toggle Whiteboard"
              >
                <PenTool className="w-5 h-5 relative z-10" />
              </button>

              <button
                onClick={() => setActiveTab(activeTab === "participants" ? null : "participants")}
                className={`p-3.5 rounded-full transition-all duration-300 flex items-center justify-center relative group ${
                  activeTab === "participants" ? "bg-primary text-black shadow-[0_0_20px_rgba(235,185,55,0.4)]" : "bg-white/5 hover:bg-white/10 text-white"
                }`}
              >
                <Users className="w-5 h-5 relative z-10" />
              </button>

              <button
                onClick={() => setActiveTab(activeTab === "chat" ? null : "chat")}
                className={`p-3.5 rounded-full transition-all duration-300 flex items-center justify-center relative group ${
                  activeTab === "chat" ? "bg-primary text-black shadow-[0_0_20px_rgba(235,185,55,0.4)]" : "bg-white/5 hover:bg-white/10 text-white"
                }`}
              >
                <MessageSquare className="w-5 h-5 relative z-10" />
              </button>
            </div>
            
            <div className="w-px h-8 bg-white/10 mx-1" />
            
            <button
              onClick={onLeave}
              className="p-3.5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-full transition-all duration-300 flex items-center justify-center group relative overflow-hidden"
            >
              <div className="absolute inset-0 bg-red-500 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-out" />
              <PhoneOff className="w-5 h-5 relative z-10" />
            </button>
          </motion.div>
        )}
      </div>

      {/* Sidebars (Framer Motion) */}
      <AnimatePresence>
        {activeTab && (
          <motion.div 
            initial={{ x: 400, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: 400, opacity: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="w-80 bg-[#13151A]/80 backdrop-blur-2xl border-l border-white/5 flex flex-col z-30 shadow-[-20px_0_40px_rgba(0,0,0,0.3)] relative"
          >
            {activeTab === "participants" ? (
              <ParticipantsPanel isTeacher={isTeacher} />
            ) : (
              <ChatPanel isTeacher={isTeacher} />
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
