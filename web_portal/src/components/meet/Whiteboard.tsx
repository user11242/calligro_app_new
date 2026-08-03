"use client";
import React, { useEffect, useState, useRef } from "react";
import { Tldraw, Editor } from "@tldraw/tldraw";
import "@tldraw/tldraw/tldraw.css";
import { Loader2, PenTool, LayoutDashboard } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { useDataChannel, useParticipants, useConnectionState } from "@livekit/components-react";
import { ConnectionState } from "livekit-client";
import CalligraphyBoard from "./CalligraphyBoard";

interface WhiteboardProps {
  isTeacher: boolean;
  mode: "standard" | "calligraphy";
  onModeChange: (mode: "standard" | "calligraphy") => void;
}

export default function Whiteboard({ isTeacher, mode, onModeChange }: WhiteboardProps) {
  const [mounted, setMounted] = useState(false);
  const editorRef = useRef<Editor | null>(null);

  // ── Tldraw Data Channel Sync ──────────────────────────────────────────────
  const { send } = useDataChannel("tldraw-sync", (msg) => {
    if (isTeacher) return;
    try {
      const data = JSON.parse(new TextDecoder().decode(msg.payload));
      if (editorRef.current && data.type === 'TLDRAW_PATCH') {
        const { added, updated, removed } = data.changes;
        editorRef.current.store.mergeRemoteChanges(() => {
          if (added && Object.keys(added).length > 0) {
            editorRef.current!.store.put(Object.values(added));
          }
          if (updated && Object.keys(updated).length > 0) {
            editorRef.current!.store.put(Object.values(updated).map((v: any) => v[1]));
          }
          if (removed && Object.keys(removed).length > 0) {
            editorRef.current!.store.remove(Object.values(removed));
          }
        });
      } else if (editorRef.current && data.type === 'TLDRAW_SNAPSHOT') {
        editorRef.current.store.loadStoreSnapshot(data.snapshot);
      }
    } catch (e) {}
  });

  const participants = useParticipants();
  const connectionState = useConnectionState();

  // Re-broadcast all shapes when a new participant joins
  useEffect(() => {
    if (!isTeacher || !editorRef.current || connectionState !== ConnectionState.Connected) return;
    
    // Debounce slightly to ensure connection is ready
    const timer = setTimeout(() => {
      try {
        const p = send(new TextEncoder().encode(JSON.stringify({ 
          type: 'TLDRAW_SNAPSHOT', 
          snapshot: editorRef.current!.store.getStoreSnapshot()
        })), { reliable: true });
        if (p && p.catch) p.catch(() => {});
      } catch (e) {}
    }, 1000);
    
    return () => clearTimeout(timer);
  }, [participants.length, isTeacher, send, connectionState]);

  const handleTldrawMount = (editor: Editor) => {
    editorRef.current = editor;
    
    // Only teacher broadcasts changes
    if (isTeacher) {
      editor.store.listen(
        (update) => {
          if (update.source === 'user' && connectionState === ConnectionState.Connected) {
            try {
              const p = send(new TextEncoder().encode(JSON.stringify({ 
                type: 'TLDRAW_PATCH', 
                changes: update.changes 
              })), { reliable: true });
              if (p && p.catch) p.catch(() => {});
            } catch (e) {}
          }
        },
        { scope: 'document' } // document changes only (ignores UI/presence)
      );
    }
  };

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <div className="w-full h-full flex flex-col items-center justify-center bg-[#13151A] rounded-3xl border border-white/5">
        <Loader2 className="w-8 h-8 text-primary animate-spin mb-4" />
        <p className="text-white/40 text-xs font-bold uppercase tracking-widest">Loading Canvas...</p>
      </div>
    );
  }

  return (
    <div className="w-full h-full relative rounded-3xl overflow-hidden shadow-2xl border border-white/10" style={{ zIndex: 10 }}>
      
      {/* ── MODE TOGGLE (Floating Top Center) ── */}
      {isTeacher && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-50 bg-[#13110C]/90 backdrop-blur-md border border-white/10 p-1 rounded-full flex items-center shadow-2xl">
          <button
            onClick={() => onModeChange("standard")}
            className={`flex items-center gap-2 px-6 py-2 rounded-full text-xs font-bold uppercase tracking-widest transition-all ${
              mode === "standard" ? "bg-white/10 text-white" : "text-white/40 hover:text-white"
            }`}
          >
            <LayoutDashboard className="w-4 h-4" />
            Calligro Board
          </button>
          <button
            onClick={() => onModeChange("calligraphy")}
            className={`flex items-center gap-2 px-6 py-2 rounded-full text-xs font-bold uppercase tracking-widest transition-all ${
              mode === "calligraphy" ? "bg-blue-600 text-white shadow-[0_0_15px_rgba(37,99,235,0.4)]" : "text-white/40 hover:text-white"
            }`}
          >
            <PenTool className="w-4 h-4" />
            Calligro Paint
          </button>
        </div>
      )}

      <AnimatePresence mode="wait">
        {mode === "standard" ? (
          <motion.div 
            key="standard"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="w-full h-full whiteboard-container relative"
          >
            <style dangerouslySetInnerHTML={{__html: `
              .whiteboard-container .tl-watermark_logo,
              .whiteboard-container .tl-watermark_link,
              .whiteboard-container .tlui-layout__watermark,
              .whiteboard-container [class*="watermark"],
              .whiteboard-container a[href*="tldraw"] {
                display: none !important;
                opacity: 0 !important;
                pointer-events: none !important;
              }

              /* 1) Grab the Main Toolbar and rotate it vertically */
              .whiteboard-container .tlui-main-toolbar {
                position: absolute !important;
                top: 480px !important; /* Move it down further so it doesn't collide when rotated */
                right: -90px !important; /* Adjust right placement due to rotation pivot */
                left: auto !important;
                bottom: auto !important;
                z-index: 999 !important;
                
                /* Rotate the entire horizontal toolbar -90 degrees to make it vertical */
                transform: rotate(-90deg) !important;
                transform-origin: center center !important;
                
                /* Reset width overrides so it flows naturally before rotation */
                width: max-content !important;
                height: auto !important;
              }
              
              /* 2) Counter-rotate the individual buttons so the icons stand upright */
              .whiteboard-container .tlui-button__tool,
              .whiteboard-container .tlui-main-toolbar__overflow {
                transform: rotate(90deg) !important;
              }

              /* 3) Fix borders/dividers to look correct after rotation */
              .whiteboard-container .tlui-main-toolbar__group {
                border-right: 1px solid var(--tl-color-divider) !important;
                border-bottom: none !important;
                margin-right: 2px !important;
              }

              /* 4) Reset the horizontal padding */
              .whiteboard-container .tlui-main-toolbar--horizontal {
                padding: 0 !important;
                max-width: none !important;
              }
              
              /* Hide the empty bottom layout container so it doesn't block clicks */
              .whiteboard-container .tlui-layout__bottom {
                pointer-events: none !important;
              }

              /* Hide UI for students completely */
              ${!isTeacher ? `
                .whiteboard-container .tlui-layout {
                  display: none !important;
                }
              ` : ''}
            `}} />
            <Tldraw 
              onMount={handleTldrawMount}
              // @ts-ignore
              isReadonly={!isTeacher}
            />
          </motion.div>
        ) : (
          <motion.div
            key="calligraphy"
            initial={{ opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.98 }}
            transition={{ duration: 0.3 }}
            className="w-full h-full"
          >
            <CalligraphyBoard 
              isTeacher={isTeacher}
            />
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  );
}
