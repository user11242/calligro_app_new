"use client";

import React, { useState, useCallback, useMemo } from "react";
import {
  LiveKitRoom,
  RoomAudioRenderer,
} from "@livekit/components-react";
import { VideoPresets, RoomOptions } from "livekit-client";
import "@livekit/components-styles";
import CalligroMeetLayout from "./CalligroMeetLayout";
import { motion, AnimatePresence } from "framer-motion";

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

  // Relaxed video settings for maximum hardware compatibility
  const roomOptions = useMemo<RoomOptions>(() => ({
    adaptiveStream: true,
    dynacast: true,
    publishDefaults: {
      videoSimulcastLayers: [
        VideoPresets.h720,
        VideoPresets.h360,
      ],
      screenShareEncoding: {
        maxBitrate: 3000000,
        maxFramerate: 30,
      }
    },
  }), []);

  const requestPermissions = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      stream.getTracks().forEach((t) => t.stop());
      setPermissionsGranted(true);
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
  }, []);

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
            className="absolute inset-0 z-50 flex items-center justify-center overflow-hidden"
          >
            {/* Ambient Background Glow */}
            <div className="absolute inset-0 z-0">
              <div className="absolute top-1/4 left-1/4 w-[500px] h-[500px] bg-primary/20 rounded-full blur-[120px] mix-blend-screen opacity-50 animate-pulse" />
              <div className="absolute bottom-1/4 right-1/4 w-[600px] h-[600px] bg-blue-500/10 rounded-full blur-[150px] mix-blend-screen opacity-40 animate-pulse" style={{ animationDelay: '2s' }} />
            </div>

            {/* Glassmorphism Card */}
            <motion.div 
              initial={{ y: 20, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.1, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
              className="relative z-10 bg-[#13151A]/60 backdrop-blur-3xl p-12 rounded-[2rem] border border-white/10 shadow-[0_0_100px_rgba(0,0,0,0.5)] w-full max-w-md text-center"
            >
              <div className="absolute -top-px left-1/2 -translate-x-1/2 w-1/2 h-px bg-gradient-to-r from-transparent via-primary/50 to-transparent" />
              
              <motion.div 
                whileHover={{ scale: 1.05 }}
                className="w-20 h-20 bg-gradient-to-br from-primary/20 to-primary/5 rounded-2xl flex items-center justify-center mx-auto mb-8 border border-primary/20 shadow-[0_0_30px_rgba(235,185,55,0.15)]"
              >
                <svg className="w-10 h-10 text-primary drop-shadow-[0_0_10px_rgba(235,185,55,0.5)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </motion.div>

              <h2 className="text-2xl font-black text-white tracking-tight mb-2">
                Calligro <span className="text-primary font-normal">Live</span>
              </h2>
              <p className="text-white/40 text-sm mb-10 font-medium leading-relaxed">
                Your browser will ask for camera & microphone access before entering the classroom.
              </p>

              {permissionError && (
                <motion.div 
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  className="bg-red-500/10 border border-red-500/20 rounded-2xl p-4 mb-8 text-left backdrop-blur-md"
                >
                  <p className="text-red-400 text-[13px] font-medium leading-tight">{permissionError}</p>
                </motion.div>
              )}

              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={requestPermissions}
                className="w-full py-4 bg-gradient-to-r from-primary to-primary/90 text-black font-bold text-sm tracking-wide rounded-2xl shadow-[0_0_40px_rgba(235,185,55,0.3)] hover:shadow-[0_0_60px_rgba(235,185,55,0.4)] transition-shadow duration-300 relative overflow-hidden group"
              >
                <div className="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-out" />
                <span className="relative z-10">Allow & Join Classroom</span>
              </motion.button>
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
              video={false}
              audio={false}
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
