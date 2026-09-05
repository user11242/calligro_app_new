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
  useIsMuted,
  useEnsureTrackRef,
  useLocalParticipant,
  useRoomContext,
} from "@livekit/components-react";
import { Track, ParticipantEvent, ConnectionState, RoomEvent, DisconnectReason } from "livekit-client";
import { Users, MessageSquare, PhoneOff, ShieldCheck, PenTool, Hand, Compass, WifiOff, Loader2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";
import ParticipantsPanel from "./ParticipantsPanel";
import ChatPanel from "./ChatPanel";
import TeacherControls from "./TeacherControls";
import StudentControls from "./StudentControls";
import Whiteboard from "./Whiteboard";
import CalligraphyBoard from "./CalligraphyBoard";
import ProtractorOverlay from "./ProtractorOverlay";
import LocalRecorderWrapper from "./LocalRecorderWrapper";
import { auth, db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";

// Context to pass the local user's avatar down to CustomParticipantTile
// (props don't survive GridLayout cloning reliably)
export const LocalAvatarContext = React.createContext<string | null>(null);
export const RaisedHandsContext = React.createContext<Set<string>>(new Set());

// A wrapper for ParticipantTile that renders our custom avatar on top ONLY when the camera is off,
// without breaking LiveKit's internal children rendering for the video track.
const CustomParticipantTile = React.forwardRef<HTMLDivElement, any>((props, ref) => {
  const { trackRef, className, style, ...rest } = props;
  // Read avatar from context (set by the parent CalligroMeetLayout)
  const localAvatarFromCtx = React.useContext(LocalAvatarContext);
  const raisedHands = React.useContext(RaisedHandsContext);
  
  // Safely ensure we have a trackRef (either from props or LiveKit context)
  // useEnsureTrackRef is provided by LiveKit specifically for this situation
  const safeTrackRef = useEnsureTrackRef(trackRef);
  const participant = safeTrackRef?.participant;
  
  // Use LiveKit's built-in hook which correctly tracks the muted state even for local tracks
  const isMuted = useIsMuted(safeTrackRef);
  const isCameraTrack = safeTrackRef?.source === Track.Source.Camera;
  
  // Only show the avatar overlay if this is a Camera track (not Screen Share) and it is muted
  const shouldShowAvatar = isCameraTrack && isMuted;
  const isHandRaised = participant ? raisedHands.has(participant.identity) : false;
  
  let avatarUrl = null;
  if (participant?.metadata) {
    try {
      const meta = JSON.parse(participant.metadata);
      // Ensure it's not the string "null" or empty
      if (meta.avatar && meta.avatar !== "null" && meta.avatar !== "") {
        avatarUrl = meta.avatar;
      }
    } catch (e) {}
  }

  // Fallback for local participant: use context value (fetched from Firestore) or Firebase Auth photo
  if (!avatarUrl && participant?.isLocal) {
    avatarUrl = localAvatarFromCtx || auth.currentUser?.photoURL || null;
  }

  const [imageError, setImageError] = React.useState(false);
  React.useEffect(() => {
    setImageError(false);
  }, [avatarUrl]);

  return (
    <div ref={ref} className={`relative overflow-hidden shadow-2xl border ${isHandRaised ? 'border-[#EBB937]' : 'border-white/5'} bg-[#13151A] ${className || ""}`} style={style} {...rest}>
      {/* LiveKit natively renders video, audio, name, and connection quality here */}
      <ParticipantTile trackRef={trackRef} className="w-full h-full" />
      
      {/* Hand Raised Badge */}
      <AnimatePresence>
        {isHandRaised && (
          <motion.div
            initial={{ opacity: 0, scale: 0.5 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.5 }}
            className="absolute top-2 right-2 z-20 bg-[#EBB937] p-1.5 rounded-full shadow-[0_0_15px_rgba(235,185,55,0.6)]"
          >
            <Hand className="w-4 h-4 text-black" />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Our custom avatar overlay sitting on top of the native tile, hiding it if camera is disabled */}
      <AnimatePresence>
        {shouldShowAvatar && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="absolute inset-0 z-10 flex flex-col items-center justify-center bg-[#13151A] pointer-events-none p-4"
          >
            {avatarUrl && !imageError ? (
              <img 
                src={avatarUrl} 
                alt={participant?.name || "Participant"} 
                className={`w-20 h-20 sm:w-28 sm:h-28 object-cover rounded-full border-[3px] sm:border-4 ${isHandRaised ? 'border-[#EBB937]' : 'border-white/10'} shadow-[0_0_40px_rgba(0,0,0,0.5)] shrink-0`}
                onError={() => setImageError(true)}
              />
            ) : (
              <div className={`w-20 h-20 sm:w-28 sm:h-28 rounded-full shrink-0 ${isHandRaised ? 'bg-[#EBB937]/20 border-[#EBB937]' : 'bg-primary/20 border-primary/30'} border-[3px] sm:border-4 flex items-center justify-center text-primary font-bold text-2xl sm:text-4xl shadow-[0_0_30px_rgba(235,185,55,0.2)]`}>
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
  userAvatar?: string | null; // kept for backward compat, but context is preferred
  onLeave: () => void;
  isRecordingMode?: boolean;
}

export default function CalligroMeetLayout({
  courseId,
  isTeacher,
  userAvatar: userAvatarProp,
  onLeave,
  isRecordingMode = false,
}: CalligroMeetLayoutProps) {
  const { t } = useTranslation();
  // Fetch the current user's photo from Firestore directly (most reliable source)
  const [localAvatar, setLocalAvatar] = useState<string | null>(userAvatarProp || null);
  useEffect(() => {
    const uid = auth.currentUser?.uid;
    if (!uid) return;
    // If already have an avatar, no need to refetch
    if (localAvatar) return;
    getDoc(doc(db, "users", uid)).then((snap) => {
      if (snap.exists()) {
        const data = snap.data();
        const photo = data.photoUrl || data.photoURL || null;
        if (photo) setLocalAvatar(photo);
      }
    }).catch(() => {});
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const tracks = useTracks(
    [
      { source: Track.Source.Camera, withPlaceholder: true },
      { source: Track.Source.ScreenShare, withPlaceholder: false },
    ],
    { onlySubscribed: false }
  );

  const participants = useParticipants();
  const { localParticipant } = useLocalParticipant();
  
  // Logic to determine the focus track (Main View)
  const screenShareTracks = tracks.filter((t) => t.source === Track.Source.ScreenShare);
  const activeSpeakers = participants.filter(p => p.isSpeaking);
  
  const teacherParticipant = participants.find(p => {
    // Force the local user as teacher if the prop is true
    if (isTeacher && localParticipant && p.identity === localParticipant.identity) return true;
    
    try {
      const meta = JSON.parse(p.metadata || "{}");
      return meta.role === "moderator";
    } catch { return false; }
  });

  // Priority: 1. Screen Share -> 2. Teacher -> 3. Active Speaker -> 4. Local fallback
  let focusTrack: TrackReferenceOrPlaceholder | null = null;
  if (screenShareTracks.length > 0) {
    focusTrack = screenShareTracks[0];
  } else if (teacherParticipant) {
    // The Teacher's camera is ALWAYS the main focus, regardless of who is speaking.
    focusTrack = tracks.find(t => t.participant.identity === teacherParticipant.identity && t.source !== Track.Source.ScreenShare) || null;
  }
  
  if (!focusTrack && activeSpeakers.length > 0) {
    const speaker = activeSpeakers[0];
    focusTrack = tracks.find(t => t.participant.identity === speaker.identity && t.source !== Track.Source.ScreenShare) || null;
  }

  if (!focusTrack && tracks.length > 0) {
    focusTrack = tracks[0];
  }

  const carouselTracks = tracks.filter(t => t !== focusTrack);
  
  let pipTrack: TrackReferenceOrPlaceholder | null = null;
  if (carouselTracks.length > 0) {
    pipTrack = carouselTracks.find(t => t.participant.isSpeaking) || null;
    if (!pipTrack) pipTrack = carouselTracks.find(t => t.source === Track.Source.Camera && t.participant.isCameraEnabled) || null;
    if (!pipTrack) pipTrack = carouselTracks[0];
  }

  const [activeTab, setActiveTab] = useState<"chat" | "participants" | null>(null);
  const [isWhiteboardActive, setIsWhiteboardActive] = useState(false);
  const [whiteboardMode, setWhiteboardMode] = useState<"standard" | "calligraphy">("calligraphy");
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [isProtractorActive, setIsProtractorActive] = useState(false);
  const [protractorAngle, setProtractorAngle] = useState(70);
  const constraintsRef = useRef<HTMLDivElement>(null);

  const [isEnding, setIsEnding] = useState(false);
  const [raisedHands, setRaisedHands] = useState<Set<string>>(new Set());

  // Check if ANY track is a screen share to automatically trigger Focus Mode
  const isScreenSharing = tracks.some((t) => t.source === Track.Source.ScreenShare);
  
  // Focus Mode is active if Whiteboard is ON or someone is Screen Sharing
  const isFocusMode = isWhiteboardActive || isScreenSharing;

  // Listen on the default unnamed channel — Flutter's localParticipant.publishData() sends without a topic
  const { send, message } = useDataChannel();
  const room = useRoomContext();

  // Play join/leave sounds and handle graceful server disconnection
  useEffect(() => {
    const onParticipantConnected = () => {
      new Audio('/sounds/join.wav').play().catch((e) => console.log("Audio play blocked", e));
    };
    const onParticipantDisconnected = () => {
      new Audio('/sounds/leave.wav').play().catch((e) => console.log("Audio play blocked", e));
    };
    const onDisconnected = (reason?: DisconnectReason) => {
      if (reason === DisconnectReason.ROOM_DELETED) {
        setToastMessage(t("meet.teacher_ended"));
        setIsEnding(true);
        setTimeout(() => onLeave(), 2000);
      }
    };

    room.on(RoomEvent.ParticipantConnected, onParticipantConnected);
    room.on(RoomEvent.ParticipantDisconnected, onParticipantDisconnected);
    room.on(RoomEvent.Disconnected, onDisconnected);

    return () => {
      room.off(RoomEvent.ParticipantConnected, onParticipantConnected);
      room.off(RoomEvent.ParticipantDisconnected, onParticipantDisconnected);
      room.off(RoomEvent.Disconnected, onDisconnected);
    };
  }, [room, onLeave]);

  useEffect(() => {
    if (!message) return;
    try {
      const data = JSON.parse(new TextDecoder().decode(message.payload));
      
      const senderIdentity = message.from?.identity;

      if (data.type === "RAISE_HAND" || data.cmd === "raise_hand") {
        setToastMessage(`${data.name} raised their hand! ✋`);
        setTimeout(() => setToastMessage(null), 5000);
        if (senderIdentity) {
          setRaisedHands(prev => new Set(prev).add(senderIdentity));
        }
      }
      if (data.cmd === "lower_hand") {
        if (senderIdentity) {
          setRaisedHands(prev => {
            const newSet = new Set(prev);
            newSet.delete(senderIdentity);
            return newSet;
          });
        }
      }
      
      if (data.cmd === "force_lower_hand" && data.targetId) {
        setRaisedHands(prev => {
          const newSet = new Set(prev);
          newSet.delete(data.targetId);
          return newSet;
        });
      }
      
      // Teacher Commands -> Student Actions
      if (data.cmd === "mute_all" && !isTeacher) {
        localParticipant.setMicrophoneEnabled(false);
      }
      if ((data.cmd === "mute_student" || data.type === "force_mute_mic") && 
          (data.identity === localParticipant.identity || data.targetId === localParticipant.identity)) {
        localParticipant.setMicrophoneEnabled(false);
      }
      if ((data.cmd === "disable_camera" || data.type === "force_mute_camera") && 
          (data.identity === localParticipant.identity || data.targetId === localParticipant.identity)) {
        localParticipant.setCameraEnabled(false);
      }
      if (data.cmd === "kick_student" && data.identity === localParticipant.identity) {
        setToastMessage("You have been removed from the class.");
        setIsEnding(true);
        setTimeout(() => onLeave(), 2000);
      }
      
      if (data.type === "end_meeting_for_all") {
        setToastMessage(t("meet.teacher_ended"));
        setIsEnding(true);
        // Use a small timeout so the user sees the message before unmounting
        setTimeout(() => onLeave(), 2000);
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
    } catch (e) {
      console.error("Data channel parse error:", e);
    }
  }, [message, isTeacher, localParticipant, onLeave]);

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
    <RaisedHandsContext.Provider value={raisedHands}>
    <div className="flex-1 flex overflow-hidden bg-[#0A0A0B] text-white font-outfit selection:bg-primary/30 relative">
      
      {/* Ambient Animated Background */}
      <div className="absolute inset-0 z-0 pointer-events-none overflow-hidden">
        <div className="absolute top-[20%] left-[10%] w-[40vw] h-[40vw] bg-primary/5 rounded-full blur-[100px] animate-pulse" style={{ animationDuration: '4s' }} />
        <div className="absolute bottom-[10%] right-[20%] w-[35vw] h-[35vw] bg-blue-500/5 rounded-full blur-[120px] animate-pulse" style={{ animationDuration: '6s' }} />
      </div>

      {/* Reconnection / Disconnection Overlay */}
      <AnimatePresence>
        {!isEnding && (connectionState === ConnectionState.Reconnecting || connectionState === ConnectionState.Disconnected) && (
          <motion.div
            key="reconnecting"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm"
          >
            <motion.div
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              className="flex flex-col items-center gap-5 bg-[#13151A]/90 border border-white/10 rounded-3xl p-10 shadow-2xl text-center max-w-sm mx-4"
            >
              {connectionState === ConnectionState.Reconnecting ? (
                <>
                  <Loader2 className="w-12 h-12 text-primary animate-spin" />
                  <div>
                    <p className="text-white font-black text-lg tracking-wide mb-1">Reconnecting...</p>
                    <p className="text-white/40 text-sm font-medium">Your connection dropped. Trying to restore the session.</p>
                  </div>
                </>
              ) : (
                <>
                  <div className="w-16 h-16 rounded-full bg-red-500/10 flex items-center justify-center">
                    <WifiOff className="w-8 h-8 text-red-400" />
                  </div>
                  <div>
                    <p className="text-white font-black text-lg tracking-wide mb-1">Connection Lost</p>
                    <p className="text-white/40 text-sm font-medium mb-5">The session could not be restored. Please rejoin.</p>
                    <button
                      onClick={() => window.location.reload()}
                      className="px-6 py-3 bg-primary text-black font-bold rounded-xl hover:bg-primary/90 transition-colors shadow-[0_0_20px_rgba(235,185,55,0.3)]"
                    >
                      Rejoin Classroom
                    </button>
                  </div>
                </>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

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

          {/* Video Grid or Focus Layout */}
          <motion.div 
            layout
            drag={isWhiteboardActive}
            dragConstraints={constraintsRef}
            dragMomentum={false}
            className={`${
              isWhiteboardActive 
                ? "absolute top-24 left-6 w-[280px] sm:w-[350px] max-h-[70vh] z-[70] overflow-y-auto flex flex-col gap-2 rounded-2xl p-2 bg-[#13151A]/80 backdrop-blur-xl border border-white/10 shadow-[0_20px_50px_rgba(0,0,0,0.5)] cursor-grab active:cursor-grabbing" 
                : "flex-1 w-full h-full relative z-10 transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] flex flex-col gap-4"
            } custom-participant-grid`}
          >
             <style dangerouslySetInnerHTML={{__html: `
               .custom-participant-grid .lk-participant-placeholder > svg {
                 display: none !important;
               }
               /* Adjust floating grid for many users */
               ${isWhiteboardActive ? `
                 .custom-participant-grid > div {
                   grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)) !important;
                   gap: 8px !important;
                 }
                 .custom-participant-grid .lk-participant-tile {
                    aspect-ratio: 16/9;
                 }
               ` : ''}
             `}} />
             <LocalAvatarContext.Provider value={localAvatar}>
             {isWhiteboardActive ? (
                <GridLayout 
                  tracks={tracks as TrackReferenceOrPlaceholder[]} 
                  style={{ width: '100%' }}
                >
                  <CustomParticipantTile className="rounded-xl" />
                </GridLayout>
             ) : (
                <div className="w-full h-full relative rounded-3xl overflow-hidden shadow-2xl bg-[#13151A] border border-white/5">
                  {/* Main Focus View (Background) */}
                  {focusTrack && (
                    <div className="absolute inset-0 z-0">
                      <CustomParticipantTile trackRef={focusTrack} className="w-full h-full" />
                    </div>
                  )}

                  {/* Floating Single Participant PiP (App style) */}
                  {pipTrack && (
                    <div className="absolute bottom-24 left-4 md:bottom-8 md:left-8 z-20 w-[100px] h-[130px] sm:w-[140px] sm:h-[180px] pointer-events-auto rounded-2xl overflow-hidden shadow-2xl border-2 border-white/20 bg-[#13151A] transition-all duration-300 hover:border-primary/50 hover:scale-105">
                      <CustomParticipantTile trackRef={pipTrack} className="w-full h-full" />
                    </div>
                  )}
                </div>
             )}
             </LocalAvatarContext.Provider>
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
              <ParticipantsPanel isTeacher={isTeacher} courseId={courseId} />
            ) : (
              <ChatPanel isTeacher={isTeacher} />
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
    </RaisedHandsContext.Provider>
  );
}
