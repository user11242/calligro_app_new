"use client";

import React, { useState, useRef, useEffect } from "react";
import {
  useTracks,
  GridLayout,
  ParticipantTile,
  TrackReferenceOrPlaceholder,
  useDataChannel,
  useParticipants,
  useParticipantContext,
  useConnectionState,
} from "@livekit/components-react";
import { Track, ParticipantEvent, ConnectionState } from "livekit-client";
import { Users, MessageSquare, PhoneOff, ShieldCheck, PenTool, Hand, Compass } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import ParticipantsPanel from "./ParticipantsPanel";
import ChatPanel from "./ChatPanel";
import TeacherControls from "./TeacherControls";
import StudentControls from "./StudentControls";
import Whiteboard from "./Whiteboard";
import ProtractorOverlay from "./ProtractorOverlay";

// A wrapper for ParticipantTile that renders our custom avatar on top ONLY when the camera is off,
// without breaking LiveKit's internal children rendering for the video track.
const CustomParticipantTile = React.forwardRef<HTMLDivElement, any>((props, ref) => {
  const { trackRef, className, style, ...rest } = props;
  const participant = trackRef?.participant;
  const [isCameraEnabled, setIsCameraEnabled] = useState(participant?.isCameraEnabled ?? false);
  
  useEffect(() => {
    if (!participant) return;
    const updateCameraState = () => setIsCameraEnabled(participant.isCameraEnabled);
    
    participant.on(ParticipantEvent.TrackPublished, updateCameraState);
    participant.on(ParticipantEvent.TrackUnpublished, updateCameraState);
    participant.on(ParticipantEvent.TrackMuted, updateCameraState);
    participant.on(ParticipantEvent.TrackUnmuted, updateCameraState);
    participant.on(ParticipantEvent.LocalTrackPublished, updateCameraState);
    participant.on(ParticipantEvent.LocalTrackUnpublished, updateCameraState);

    updateCameraState();

    return () => {
      participant.off(ParticipantEvent.TrackPublished, updateCameraState);
      participant.off(ParticipantEvent.TrackUnpublished, updateCameraState);
      participant.off(ParticipantEvent.TrackMuted, updateCameraState);
      participant.off(ParticipantEvent.TrackUnmuted, updateCameraState);
      participant.off(ParticipantEvent.LocalTrackPublished, updateCameraState);
      participant.off(ParticipantEvent.LocalTrackUnpublished, updateCameraState);
    };
  }, [participant]);
  
  let avatarUrl = null;
  if (participant?.metadata) {
    try {
      const meta = JSON.parse(participant.metadata);
      avatarUrl = meta.avatar;
    } catch (e) {}
  }

  return (
    <div ref={ref} className={`relative overflow-hidden shadow-2xl border border-white/5 bg-[#13151A] ${className || ""}`} style={style} {...rest}>
      {/* LiveKit natively renders video, audio, name, and connection quality here */}
      <ParticipantTile trackRef={trackRef} className="w-full h-full" />
      
      {/* Our custom avatar overlay sitting on top of the native tile, hiding it if camera is disabled */}
      <AnimatePresence>
        {!isCameraEnabled && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="absolute inset-0 z-10 flex flex-col items-center justify-center bg-[#13151A] pointer-events-none"
          >
            {avatarUrl ? (
              <img 
                src={avatarUrl} 
                alt={participant?.name || "Participant"} 
                className="w-24 h-24 sm:w-32 sm:h-32 rounded-full object-cover border-4 border-white/10 shadow-[0_0_40px_rgba(0,0,0,0.5)]" 
              />
            ) : (
              <div className="w-24 h-24 sm:w-32 sm:h-32 rounded-full bg-primary/20 border-4 border-primary/30 flex items-center justify-center text-primary font-bold text-4xl shadow-[0_0_30px_rgba(235,185,55,0.2)]">
                {participant?.name?.[0]?.toUpperCase() || '?'}
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
});
CustomParticipantTile.displayName = "CustomParticipantTile";

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
  const [whiteboardMode, setWhiteboardMode] = useState<"standard" | "calligraphy">("calligraphy");
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [isProtractorActive, setIsProtractorActive] = useState(false);
  const [protractorAngle, setProtractorAngle] = useState(70);
  const constraintsRef = useRef<HTMLDivElement>(null);

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
        if (data.mode) setWhiteboardMode(data.mode);
      }
      if (data.cmd === "set_whiteboard_mode") {
        setWhiteboardMode(data.mode);
      }
      if (data.type === "PROTRACTOR_STATE") {
        setIsProtractorActive(data.active);
        if (data.angle !== undefined) setProtractorAngle(data.angle);
      }
    } catch (e) {}
  });

  const connectionState = useConnectionState();

  // Re-broadcast state when new participants join (Teacher only)
  useEffect(() => {
    if (isTeacher && connectionState === ConnectionState.Connected) {
      try {
        const p1 = send(new TextEncoder().encode(JSON.stringify({
          cmd: "toggle_whiteboard",
          state: isWhiteboardActive,
          mode: whiteboardMode
        })), { reliable: true });
        if (p1 && p1.catch) p1.catch(() => {});

        const p2 = send(new TextEncoder().encode(JSON.stringify({
          type: "PROTRACTOR_STATE",
          active: isProtractorActive,
          angle: protractorAngle
        })), { reliable: true });
        if (p2 && p2.catch) p2.catch(() => {});
      } catch (e) {
        console.warn("Failed to broadcast state, connection might not be ready", e);
      }
    }
  }, [participants.length, isTeacher, isWhiteboardActive, whiteboardMode, isProtractorActive, protractorAngle, send, connectionState]);

  const handleWhiteboardModeChange = (newMode: "standard" | "calligraphy") => {
    setWhiteboardMode(newMode);
    if (connectionState !== ConnectionState.Connected) return;
    const p = send(new TextEncoder().encode(JSON.stringify({
      cmd: "set_whiteboard_mode",
      mode: newMode
    })), { reliable: true });
    if (p && p.catch) p.catch(() => {});
  };

  const handleProtractorChange = (active: boolean, angle: number) => {
    setIsProtractorActive(active);
    setProtractorAngle(angle);
    if (connectionState !== ConnectionState.Connected) return;
    const p = send(new TextEncoder().encode(JSON.stringify({
      type: "PROTRACTOR_STATE",
      active,
      angle
    })), { reliable: true });
    if (p && p.catch) p.catch(() => {});
  };

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

        {/* Protractor Overlay */}
        <AnimatePresence>
          {isProtractorActive && (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              transition={{ duration: 0.3 }}
              className="absolute inset-0 z-40 pointer-events-none"
            >
              <ProtractorOverlay 
                angle={protractorAngle} 
                onAngleChange={(newAngle) => handleProtractorChange(true, newAngle)}
                onClose={() => handleProtractorChange(false, protractorAngle)}
                isTeacher={isTeacher}
              />
            </motion.div>
          )}
        </AnimatePresence>

        {/* Dynamic Focus Layout */}
        <div ref={constraintsRef} className={`flex-1 p-4 pb-28 overflow-hidden flex transition-all duration-700 relative`}>
          
          {/* Hide page.tsx header when whiteboard is active */}
          {isWhiteboardActive && (
            <style dangerouslySetInnerHTML={{__html: `
              #classroom-header {
                opacity: 0 !important;
                pointer-events: none !important;
                visibility: hidden !important;
              }
            `}} />
          )}

          {/* Main Focus Area (Whiteboard or Screen Share) */}
          <motion.div 
            initial={false}
            animate={
              isWhiteboardActive 
                ? { opacity: 1, scale: 1, pointerEvents: "auto", display: "block" } 
                : { opacity: 0, scale: 0.95, pointerEvents: "none", transitionEnd: { display: "none" } }
            }
            transition={{ duration: 0.4 }}
            className={`absolute inset-0 z-[60] bg-[#0D0D0D] ${!isWhiteboardActive ? 'invisible' : ''}`}
          >
            <Whiteboard 
              isTeacher={isTeacher} 
              mode={whiteboardMode}
              onModeChange={handleWhiteboardModeChange}
            />
          </motion.div>

          {/* Video Grid (Shrinks to small floating box if Whiteboard is active) */}
          <motion.div 
            layout
            drag={isWhiteboardActive}
            dragConstraints={constraintsRef}
            dragMomentum={false}
            className={`${
              isWhiteboardActive 
                ? "absolute top-24 left-6 w-56 max-h-[70vh] z-[70] overflow-y-auto flex flex-col gap-2 rounded-2xl p-2 bg-[#13151A]/80 backdrop-blur-xl border border-white/10 shadow-[0_20px_50px_rgba(0,0,0,0.5)] cursor-grab active:cursor-grabbing" 
                : "flex-1 w-full h-full relative z-10 transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)]"
            } custom-participant-grid`}
          >
             <style dangerouslySetInnerHTML={{__html: `
               .custom-participant-grid .lk-participant-placeholder > svg {
                 display: none !important;
               }
               /* Make grid layout single column when floating */
               ${isWhiteboardActive ? `
                 .custom-participant-grid > div {
                   grid-template-columns: 1fr !important;
                   gap: 8px !important;
                 }
                 .custom-participant-grid .lk-participant-tile {
                    aspect-ratio: 16/9;
                 }
               ` : ''}
             `}} />
             <GridLayout 
                tracks={tracks as TrackReferenceOrPlaceholder[]} 
                style={isWhiteboardActive ? { width: '100%' } : { height: '100%', width: '100%', gap: '16px' }}
              >
              <CustomParticipantTile 
                className={isWhiteboardActive ? "rounded-xl" : "rounded-3xl"}
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
            className={`absolute bottom-8 left-1/2 -translate-x-1/2 bg-[#1A1C23]/80 backdrop-blur-3xl border border-white/10 p-2.5 rounded-full flex items-center gap-2 shadow-[0_20px_60px_rgba(0,0,0,0.6)] ${isWhiteboardActive ? "z-[70]" : "z-30"}`}
          >
            {isTeacher ? <TeacherControls /> : <StudentControls />}
            
            <div className="w-px h-8 bg-white/10 mx-1" />
            
            <div className="flex items-center gap-1.5">
              {isTeacher && (
                <>
                  <button
                    onClick={() => {
                      const newState = !isWhiteboardActive;
                      setIsWhiteboardActive(newState);
                      if (isTeacher) {
                        send(new TextEncoder().encode(JSON.stringify({
                          cmd: "toggle_whiteboard",
                          state: newState,
                          mode: whiteboardMode
                        })), { reliable: true });
                      }
                    }}
                    className={`p-3.5 rounded-full transition-all duration-300 flex items-center justify-center relative group ${
                      isWhiteboardActive ? "bg-primary text-black shadow-[0_0_20px_rgba(235,185,55,0.4)]" : "bg-white/5 hover:bg-white/10 text-white"
                    }`}
                    title="Toggle Whiteboard"
                  >
                    <PenTool className="w-5 h-5 relative z-10" />
                  </button>

                  <button
                    onClick={() => handleProtractorChange(!isProtractorActive, protractorAngle)}
                    className={`p-3.5 rounded-full transition-all duration-300 flex items-center justify-center relative group ${
                      isProtractorActive ? "bg-primary text-black shadow-[0_0_20px_rgba(235,185,55,0.4)]" : "bg-white/5 hover:bg-white/10 text-white"
                    }`}
                    title="Toggle Qalam Protractor"
                  >
                    <Compass className="w-5 h-5 relative z-10" />
                  </button>
                </>
              )}

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
            className={`w-80 bg-[#13151A]/80 backdrop-blur-2xl border-l border-white/5 flex flex-col shadow-[-20px_0_40px_rgba(0,0,0,0.3)] relative ${isWhiteboardActive ? "z-[70]" : "z-30"}`}
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
