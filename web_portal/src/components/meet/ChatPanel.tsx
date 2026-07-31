"use client";

import React, { useEffect, useState, useRef } from "react";
import { useChat, useLocalParticipant } from "@livekit/components-react";
import { translateText } from "@/lib/translateText";
import { Send, MessageSquare } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

interface ChatPanelProps {
  isTeacher: boolean;
}

interface TranslatedMessage {
  id: string;
  original: string;
  translated?: string;
  senderName: string;
  isSelf: boolean;
  isTeacher: boolean;
  timestamp: number;
}

export default function ChatPanel({ isTeacher }: ChatPanelProps) {
  const { send, chatMessages } = useChat();
  const { localParticipant } = useLocalParticipant();
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<TranslatedMessage[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const processMessages = async () => {
      const processed: TranslatedMessage[] = [];
      for (const msg of chatMessages) {
        const isSelf = msg.from?.identity === localParticipant.identity;
        let role = "participant";
        try {
          if (msg.from?.metadata) {
            const meta = JSON.parse(msg.from.metadata);
            role = meta.role;
          }
        } catch (e) {}

        const isRemoteTeacher = role === "moderator";

        let translatedText = undefined;
        if (!isSelf) {
          translatedText = await translateText(msg.message, "ar", "auto"); 
          if (translatedText === msg.message) translatedText = undefined;
        }

        processed.push({
          id: msg.id,
          original: msg.message,
          translated: translatedText,
          senderName: msg.from?.name || "Unknown",
          isSelf,
          isTeacher: isSelf ? isTeacher : isRemoteTeacher,
          timestamp: msg.timestamp,
        });
      }
      setMessages(processed);
    };

    processMessages();
  }, [chatMessages, localParticipant.identity, isTeacher]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSend = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim()) return;
    send(input);
    setInput("");
  };

  return (
    <div className="flex flex-col h-full bg-transparent font-outfit">
      
      {/* Header */}
      <div className="p-5 border-b border-white/5 flex items-center gap-3 bg-black/20">
        <div className="bg-primary/20 p-2 rounded-lg">
          <MessageSquare className="w-4 h-4 text-primary" />
        </div>
        <h2 className="text-[13px] font-black text-white uppercase tracking-widest">
          Class Chat
        </h2>
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-5">
        <AnimatePresence initial={false}>
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, scale: 0.9, originY: 1, originX: msg.isSelf ? 1 : 0 }}
              animate={{ opacity: 1, scale: 1 }}
              layout
              className={`flex flex-col ${
                msg.isSelf ? "items-end" : "items-start"
              }`}
            >
              <span className={`text-[10px] uppercase tracking-wider font-bold mb-1.5 ${msg.isSelf ? 'text-primary' : 'text-white/40'}`}>
                {msg.isSelf ? "You" : msg.senderName} {msg.isTeacher && " 🌟"}
              </span>
              
              <div
                className={`p-3.5 rounded-[20px] max-w-[85%] shadow-lg ${
                  msg.isSelf
                    ? "bg-gradient-to-br from-primary to-primary/90 text-black rounded-tr-sm"
                    : msg.isTeacher
                    ? "bg-[#1A1C23] text-white rounded-tl-sm border border-primary/30 shadow-[0_0_15px_rgba(235,185,55,0.1)]"
                    : "bg-[#1A1C23] text-white rounded-tl-sm border border-white/5"
                }`}
              >
                <p className="text-[13px] font-medium leading-relaxed">{msg.original}</p>
                
                {msg.translated && (
                  <div className="mt-2 pt-2 border-t border-white/10">
                    <p className={`text-[11px] font-bold ${msg.isTeacher ? 'text-primary/90' : 'text-white/50'}`}>
                      {msg.translated}
                    </p>
                  </div>
                )}
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
        
        {messages.length === 0 && (
          <div className="h-full flex flex-col items-center justify-center text-center opacity-40">
            <MessageSquare className="w-8 h-8 mb-4 text-white/50" />
            <p className="text-[11px] uppercase tracking-widest font-black text-white">No messages yet</p>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="p-4 bg-black/40 border-t border-white/5 backdrop-blur-md">
        <form onSubmit={handleSend} className="relative flex items-center">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Type a message..."
            className="w-full bg-[#13151A] border border-white/10 rounded-full py-3.5 pl-5 pr-14 text-[13px] text-white font-medium focus:outline-none focus:border-primary/50 focus:bg-white/5 transition-all shadow-inner placeholder:text-white/20"
          />
          <button
            type="submit"
            disabled={!input.trim()}
            className="absolute right-2 p-2.5 bg-primary text-black rounded-full disabled:opacity-0 disabled:scale-75 transition-all duration-300 hover:scale-105 shadow-[0_0_15px_rgba(235,185,55,0.3)]"
          >
            <Send className="w-4 h-4 ml-0.5" />
          </button>
        </form>
      </div>
    </div>
  );
}
