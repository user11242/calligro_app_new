"use client";

import React, { useState, useCallback, useMemo, useRef, useEffect } from "react";
import {
  LiveKitRoom,
  RoomAudioRenderer,
} from "@livekit/components-react";
import { VideoPresets, RoomOptions } from "livekit-client";
import "@livekit/components-styles";
import CalligroMeetLayout from "./CalligroMeetLayout";
import { motion, AnimatePresence } from "framer-motion";
import { Mic, MicOff, Video, VideoOff } from "lucide-react";

interface CalligroMeetRoomProps {
  token: string;
  serverUrl: string;
  courseId: string;
  isTeacher: boolean;
  onLeave: () => void;
}

export default function CalligroMeetRoom({
  token,
  serverUrl,
  courseId,
  isTeacher,
  onLeave,
}: CalligroMeetRoomProps) {
  const [permissionsGranted, setPermissionsGranted] = useState(false);
  const [permissionError, setPermissionError] = useState<string | null>(null);
  
  const videoRef = useRef<HTMLVideoElement>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);

  const [isCamOn, setIsCamOn] = useState(false);
  const [isMicOn, setIsMicOn] = useState(false);

  // High-performance video settings tuned for Calligraphy classes
  const roomOptions = useMemo<RoomOptions>(() => ({
    adaptiveStream: { pixelDensity: 'screen' },
    dynacast: true,
    videoCaptureDefaults: {
      resolution: VideoPresets.h1080.resolution,
    },
    publishDefaults: {
      videoEncoding: {
        maxBitrate: 3000000,
        maxFramerate: 30,
      },
      videoSimulcastLayers: [
        VideoPresets.h1080,
        VideoPresets.h720,
        VideoPresets.h360,
      ],
      screenShareEncoding: {
        maxBitrate: 3000000,
        maxFramerate: 30,
      }
    },
  }), []);

  useEffect(() => {
    if (permissionsGranted) return;
    
    let activeStream: MediaStream;
    async function setupPreview() {
      try {
        // Constrain PreJoin preview to 720p to eliminate local browser lag before joining
        const s = await navigator.mediaDevices.getUserMedia({ 
          video: { 
            width: { ideal: 1280 }, 
            height: { ideal: 720 }, 
            frameRate: { ideal: 30, max: 30 } 
          }, 
          audio: {
            echoCancellation: true,
            noiseSuppression: true
          } 
        });
        s.getVideoTracks().forEach(t => t.enabled = false);
        s.getAudioTracks().forEach(t => t.enabled = false);
        activeStream = s;
        setStream(s);
        if (videoRef.current) {
          videoRef.current.srcObject = s;
        }
      } catch (err: any) {
        console.error("Permission error:", err);
        if (err.name === "NotAllowedError") {
          setPermissionError("You denied camera/mic access. Please click the camera icon in your browser's address bar and allow access, then refresh.");
        } else if (err.name === "NotFoundError") {
          setPermissionError("No camera or microphone found. Please connect one and refresh.");
        } else {
          setPermissionError(`Device error: ${err.message}`);
        }
      }
    }
    setupPreview();
    
    return () => {
      if (activeStream) {
        activeStream.getTracks().forEach(t => t.stop());
      }
    };
  }, [permissionsGranted]);

  const toggleCam = () => {
    if (stream) {
      const newState = !isCamOn;
      stream.getVideoTracks().forEach(t => t.enabled = newState);
      setIsCamOn(newState);
    }
  };

  const toggleMic = () => {
    if (stream) {
      const newState = !isMicOn;
      stream.getAudioTracks().forEach(t => t.enabled = newState);
      setIsMicOn(newState);
    }
  };

  const handleJoin = () => {
    if (stream) {
      stream.getTracks().forEach(t => t.stop());
    }
    setPermissionsGranted(true);
  };

  return (
    <div className="relative flex-1 flex flex-col overflow-hidden bg-black font-outfit selection:bg-primary/30">
      <AnimatePresence mode="wait">
        {!permissionsGranted ? (
          <motion.div 
            key="lobby"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
            className="absolute inset-0 z-50 flex items-center justify-center overflow-hidden bg-[#0A0B0E]"
          >
            {/* Custom Designed PreJoin Card */}
            <motion.div 
              initial={{ y: 20, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.1, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
              className="relative z-10 w-full max-w-[800px] mx-4 p-6 bg-white/[0.02] backdrop-blur-3xl border border-white/[0.08] rounded-[2rem] shadow-2xl flex flex-col md:flex-row items-center gap-8"
            >
              {/* Left Side: Video Preview */}
              <div className="w-full md:w-3/5 aspect-video bg-black/40 rounded-2xl overflow-hidden border border-white/5 relative flex items-center justify-center shadow-inner group">
                {!stream && !permissionError && (
                  <div className="flex flex-col items-center gap-3 text-white/40">
                    <Video className="w-8 h-8 animate-pulse" />
                    <span className="text-sm font-medium tracking-wide">Requesting Camera...</span>
                  </div>
                )}
                
                {(!isCamOn && stream) && (
                  <div className="absolute inset-0 bg-[#13151A] flex flex-col items-center justify-center gap-3 z-10">
                    <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center">
                      <VideoOff className="w-6 h-6 text-white/40" />
                    </div>
                    <span className="text-white/40 text-sm font-medium">Camera is off</span>
                  </div>
                )}

                <video 
                  ref={videoRef} 
                  autoPlay 
                  playsInline 
                  muted 
                  className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-500 ${stream && isCamOn ? 'opacity-100' : 'opacity-0'}`} 
                />
                
                {/* Overlay Controls */}
                {stream && (
                  <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-4 z-20 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                    <button 
                      onClick={toggleMic}
                      className={`flex items-center justify-center w-12 h-12 rounded-full backdrop-blur-md border transition-all shadow-lg ${
                        isMicOn ? 'bg-black/60 border-white/10 text-white hover:bg-black/80' : 'bg-red-500/90 border-red-500 text-white hover:bg-red-600'
                      }`}
                    >
                      {isMicOn ? <Mic className="w-5 h-5" /> : <MicOff className="w-5 h-5" />}
                    </button>
                    <button 
                      onClick={toggleCam}
                      className={`flex items-center justify-center w-12 h-12 rounded-full backdrop-blur-md border transition-all shadow-lg ${
                        isCamOn ? 'bg-black/60 border-white/10 text-white hover:bg-black/80' : 'bg-red-500/90 border-red-500 text-white hover:bg-red-600'
                      }`}
                    >
                      {isCamOn ? <Video className="w-5 h-5" /> : <VideoOff className="w-5 h-5" />}
                    </button>
                  </div>
                )}

                {/* Status Badges overlaying video */}
                {stream && (
                  <div className="absolute top-4 left-4 flex gap-2 z-20 pointer-events-none">
                    <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full backdrop-blur-md border border-white/10 text-white text-[10px] font-semibold tracking-wide ${isCamOn ? 'bg-black/50' : 'bg-red-500/50'}`}>
                      <div className={`w-1.5 h-1.5 rounded-full ${isCamOn ? 'bg-emerald-500 animate-pulse' : 'bg-red-400'}`} />
                      {isCamOn ? 'Camera On' : 'Camera Off'}
                    </div>
                    <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full backdrop-blur-md border border-white/10 text-white text-[10px] font-semibold tracking-wide ${isMicOn ? 'bg-black/50' : 'bg-red-500/50'}`}>
                      <div className={`w-1.5 h-1.5 rounded-full ${isMicOn ? 'bg-emerald-500 animate-pulse' : 'bg-red-400'}`} />
                      {isMicOn ? 'Mic Active' : 'Mic Muted'}
                    </div>
                  </div>
                )}
              </div>

              {/* Right Side: Content & Button */}
              <div className="w-full md:w-2/5 flex flex-col pt-2 pb-4 md:py-4 md:pr-4">
                <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary/10 border border-primary/20 w-max mb-6">
                  <span className="text-[10px] font-bold text-primary tracking-[0.2em] uppercase">Ready to Join</span>
                </div>

                <h2 className="text-3xl font-semibold text-white tracking-tight mb-3 font-outfit">
                  Enter Studio
                </h2>
                
                <p className="text-white/40 text-[14px] font-light leading-relaxed mb-8">
                  Check your camera positioning and microphone before entering the classroom. 
                </p>

                {permissionError && (
                  <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4 mb-6 text-left">
                    <p className="text-red-400 text-[13px] font-medium leading-relaxed">{permissionError}</p>
                  </div>
                )}

                <button
                  onClick={handleJoin}
                  disabled={!stream}
                  className="w-full py-4 bg-primary hover:bg-primary/90 disabled:bg-primary/30 disabled:text-black/30 disabled:cursor-not-allowed text-black font-semibold text-[15px] rounded-xl transition-all duration-200 active:scale-[0.98] shadow-[0_0_20px_rgba(212,175,55,0.2)] hover:shadow-[0_0_30px_rgba(212,175,55,0.4)]"
                >
                  Join Classroom
                </button>
              </div>
            </motion.div>
          </motion.div>
        ) : (
          <motion.div
            key="room"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, ease: "easeOut" }}
            className="flex-1 flex flex-col h-full"
          >
            <LiveKitRoom
              video={isCamOn}
              audio={isMicOn}
              token={token}
              serverUrl={serverUrl}
              connect={true}
              options={roomOptions}
              className="flex-1 flex flex-col overflow-hidden relative"
            >
              <CalligroMeetLayout courseId={courseId} isTeacher={isTeacher} onLeave={onLeave} />
              <RoomAudioRenderer />
            </LiveKitRoom>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
