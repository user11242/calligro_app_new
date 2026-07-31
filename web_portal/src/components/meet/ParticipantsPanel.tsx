"use client";

import React from "react";
import { useParticipants } from "@livekit/components-react";
import { Users, Mic, MicOff, Video, VideoOff, UserCheck } from "lucide-react";
import { motion } from "framer-motion";

interface ParticipantsPanelProps {
  isTeacher: boolean;
}

export default function ParticipantsPanel({ isTeacher }: ParticipantsPanelProps) {
  const participants = useParticipants();

  return (
    <div className="flex flex-col h-full bg-transparent font-outfit">
      
      {/* Header */}
      <div className="p-5 border-b border-white/5 flex items-center justify-between bg-black/20">
        <div className="flex items-center gap-3">
          <div className="bg-primary/20 p-2 rounded-lg">
            <Users className="w-4 h-4 text-primary" />
          </div>
          <h2 className="text-[13px] font-black text-white uppercase tracking-widest">
            Class Roster
          </h2>
        </div>
        <span className="text-[11px] font-bold text-black bg-primary px-2.5 py-1 rounded-full shadow-[0_0_15px_rgba(235,185,55,0.3)]">
          {participants.length}
        </span>
      </div>

      {/* Participants List */}
      <div className="flex-1 overflow-y-auto p-3 space-y-2">
        {participants.map((p, i) => {
          let role = "participant";
          let avatar = null;
          try {
            if (p.metadata) {
              const meta = JSON.parse(p.metadata);
              role = meta.role;
              avatar = meta.avatar;
            }
          } catch (e) {}

          const isRemoteTeacher = role === "moderator";

          return (
            <motion.div
              key={p.identity}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              className={`flex items-center justify-between p-3.5 rounded-2xl transition-all duration-300 border backdrop-blur-md ${
                isRemoteTeacher
                  ? "bg-primary/10 border-primary/30 shadow-[0_5px_20px_rgba(235,185,55,0.1)]"
                  : "bg-white/5 border-white/5 hover:border-white/20 hover:bg-white/10"
              }`}
            >
              <div className="flex items-center gap-3.5">
                <div className="relative">
                  {avatar ? (
                    <img
                      src={avatar}
                      alt={p.name || "User"}
                      className="w-10 h-10 rounded-full border border-white/10 object-cover shadow-lg"
                    />
                  ) : (
                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-white/20 to-white/5 flex items-center justify-center text-sm font-black text-white shadow-lg border border-white/10">
                      {(p.name || "?").charAt(0).toUpperCase()}
                    </div>
                  )}
                  {isRemoteTeacher && (
                    <div className="absolute -bottom-1 -right-1 bg-primary text-black rounded-full p-1 shadow-lg border-2 border-[#13151A]">
                      <UserCheck className="w-3 h-3" />
                    </div>
                  )}
                </div>
                
                <div className="flex flex-col">
                  <p
                    className={`text-[13px] font-bold leading-none mb-1.5 ${
                      isRemoteTeacher ? "text-primary" : "text-white/90"
                    }`}
                  >
                    {p.name} {p.isLocal ? <span className="text-white/40 font-medium">(You)</span> : ""}
                  </p>
                  <p className="text-[9px] text-white/40 font-bold uppercase tracking-widest">
                    {isRemoteTeacher ? "Teacher" : "Student"}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2.5">
                {p.isMicrophoneEnabled ? (
                  <div className="p-1.5 bg-green-500/10 rounded-full text-green-400">
                    <Mic className="w-3.5 h-3.5" />
                  </div>
                ) : (
                  <div className="p-1.5 bg-red-500/10 rounded-full text-red-500">
                    <MicOff className="w-3.5 h-3.5" />
                  </div>
                )}
                {p.isCameraEnabled ? (
                  <div className="p-1.5 bg-green-500/10 rounded-full text-green-400">
                    <Video className="w-3.5 h-3.5" />
                  </div>
                ) : (
                  <div className="p-1.5 bg-red-500/10 rounded-full text-red-500">
                    <VideoOff className="w-3.5 h-3.5" />
                  </div>
                )}
              </div>
            </motion.div>
          );
        })}

        {participants.length === 0 && (
          <div className="text-center py-16 flex flex-col items-center justify-center">
            <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mb-4">
              <Users className="w-6 h-6 text-white/20" />
            </div>
            <p className="text-[11px] text-white/40 uppercase font-black tracking-[0.2em]">
              Waiting for others
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
