"use client";

import React, { useState } from "react";
import { useLocalParticipant, useDataChannel, useRoomContext } from "@livekit/components-react";
import { RoomEvent, type RemoteParticipant } from "livekit-client";
import { Mic, MicOff, Video, VideoOff, Hand } from "lucide-react";
import { motion } from "framer-motion";
import { isFromModerator } from "./moderation";
import { MeetMessages, encodeMeetMessage } from "@/features/meet/domain/meetMessages";

export default function StudentControls() {
  const { localParticipant, isMicrophoneEnabled, isCameraEnabled } = useLocalParticipant();
  const room = useRoomContext();
  const { send } = useDataChannel();
  const [isHandRaised, setIsHandRaised] = useState(false);
  const handleRaiseHand = async () => {
    const newState = !isHandRaised;
    setIsHandRaised(newState);
    const name = localParticipant.name || "Student";
    send(encodeMeetMessage(newState ? MeetMessages.raiseHand(name) : MeetMessages.lowerHand(name)), { reliable: true });
  };
  
  // Listen for teacher force-lowering our hand
  React.useEffect(() => {
    const handleDataReceived = (payload: Uint8Array, participant?: RemoteParticipant) => {
      try {
        const data = JSON.parse(new TextDecoder().decode(payload));
        if (data.cmd === "force_lower_hand" && data.targetId === localParticipant.identity
            && isFromModerator(participant)) {
          setIsHandRaised(false);
          send(encodeMeetMessage(MeetMessages.lowerHand(localParticipant.name || "Student")), { reliable: true });
        }
      } catch (e) {}
    };
    
    room.on(RoomEvent.DataReceived, handleDataReceived);
    return () => {
      room.off(RoomEvent.DataReceived, handleDataReceived);
    };
  }, [localParticipant, send, room]);

  return (
    <div className="flex items-center gap-1.5 lk-custom-toggles">
      
      {/* Custom Mic Toggle */}
      <button
        onClick={() => localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled)}
        className={`lk-toggle-btn ${isMicrophoneEnabled ? '' : 'lk-toggle-btn-muted'}`}
        title={isMicrophoneEnabled ? 'Mute Microphone' : 'Unmute Microphone'}
      >
        {isMicrophoneEnabled ? <Mic style={{ width: '1.25rem', height: '1.25rem' }} /> : <MicOff style={{ width: '1.25rem', height: '1.25rem' }} />}
      </button>

      {/* Custom Camera Toggle */}
      <button
        onClick={() => localParticipant.setCameraEnabled(!isCameraEnabled)}
        className={`lk-toggle-btn ${isCameraEnabled ? '' : 'lk-toggle-btn-muted'}`}
        title={isCameraEnabled ? 'Turn Off Camera' : 'Turn On Camera'}
      >
        {isCameraEnabled ? <Video style={{ width: '1.25rem', height: '1.25rem' }} /> : <VideoOff style={{ width: '1.25rem', height: '1.25rem' }} />}
      </button>
      {/* No screen-share button: the server only lets students publish camera + mic. */}

      <style dangerouslySetInnerHTML={{__html: `
        .lk-custom-toggles .lk-toggle-btn { 
          background-color: rgba(255, 255, 255, 0.05); 
          color: white; 
          border-radius: 9999px;
          padding: 0.875rem;
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
        .lk-custom-toggles .lk-toggle-btn-muted { 
          background-color: rgba(239, 68, 68, 0.1); 
          color: rgb(239, 68, 68); 
        }
        .lk-custom-toggles .lk-toggle-btn-muted:hover { 
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
        onClick={handleRaiseHand}
        className={`px-4 py-3 rounded-full transition-colors duration-300 flex items-center gap-2 text-[13px] font-bold tracking-wide ${
          isHandRaised 
            ? "bg-primary text-black shadow-[0_0_20px_rgba(235,185,55,0.4)]" 
            : "bg-white/10 hover:bg-white/20 text-white"
        }`}
      >
        <Hand className={`w-4 h-4 ${isHandRaised ? "animate-pulse" : ""}`} />
        <span className="hidden sm:inline">{isHandRaised ? "Hand Raised" : "Raise Hand"}</span>
      </motion.button>
    </div>
  );
}
