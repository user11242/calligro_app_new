"use client";

import { useState, useEffect } from "react";
import { 
  FileText, 
  Plus, 
  Trash2, 
  Loader2, 
  StickyNote, 
  Calendar, 
  User, 
  Edit3, 
  Check, 
  X,
  AlertCircle
} from "lucide-react";
import { financeService } from "@/lib/financeService";
import { motion, AnimatePresence } from "framer-motion";

export default function AdminNotes() {
  const [notes, setNotes] = useState<any[]>([]);
  const [newNote, setNewNote] = useState("");
  const [loading, setLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setError(null);
    const unsub = financeService.getNotes((data) => {
      setNotes(data || []);
      setLoading(false);
    });
    
    // Safety timeout: if no data in 5 seconds, stop loading
    const timer = setTimeout(() => setLoading(false), 5000);
    
    return () => {
      unsub && unsub();
      clearTimeout(timer);
    };
  }, []);

  const handleAddNote = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newNote.trim()) return;
    
    setIsSubmitting(true);
    setError(null);
    try {
      await financeService.addNote(newNote);
      setNewNote("");
    } catch (err: any) {
      console.error("Failed to add note:", err);
      setError("Failed to publish note. Check your internet or permissions.");
      alert("Error: " + (err.message || "Failed to save note."));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleUpdateNote = async (id: string) => {
    if (!editContent.trim()) return;
    await financeService.updateNote(id, editContent);
    setEditingId(null);
    setEditContent("");
  };

  const handleDeleteNote = async (id: string) => {
    if (confirm("Permanently delete this executive note?")) {
      await financeService.deleteNote(id);
    }
  };

  const formatDate = (timestamp: any) => {
    if (!timestamp) return "Just now";
    try {
      // Handles both Firestore Timestamp and JS Date
      const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
      return date.toLocaleDateString(undefined, { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (e) {
      return "Recent";
    }
  };

  if (loading) {
    return (
      <div className="min-h-[400px] flex flex-col items-center justify-center text-center">
        <Loader2 className="w-8 h-8 animate-spin text-black mb-4" />
        <p className="text-[10px] font-black uppercase tracking-[4px] text-gray-300">Synchronizing Vault...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-[400px] flex flex-col items-center justify-center text-center p-10 bg-red-50 rounded-[40px] border border-red-100">
        <AlertCircle className="w-12 h-12 text-red-500 mb-4" />
        <h3 className="text-sm font-black text-red-900 uppercase tracking-widest">Connection Error</h3>
        <p className="text-xs font-bold text-red-600/60 mt-2 uppercase tracking-tighter">Firestore database may require permissions or indexes.</p>
        <button onClick={() => window.location.reload()} className="mt-8 px-8 py-3 bg-red-500 text-white rounded-2xl font-black text-[10px] uppercase tracking-widest shadow-lg shadow-red-200">Retry Connection</button>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-700 pb-20 text-left">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Executive Notes</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">Secure Internal Strategic Logs</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        {/* Note Creator */}
        <div className="lg:col-span-1">
          <div className="bg-white rounded-[40px] p-10 border border-gray-100 shadow-xl shadow-black/[0.02] sticky top-28">
            <div className="flex items-center gap-3 mb-8">
              <StickyNote className="w-5 h-5 text-gray-400" />
              <h3 className="text-sm font-black uppercase tracking-widest">New Strategy Note</h3>
            </div>
            
            <form onSubmit={handleAddNote} className="space-y-6">
              <textarea 
                value={newNote}
                onChange={(e) => setNewNote(e.target.value)}
                placeholder="Type your strategic thoughts..."
                className="w-full h-56 px-6 py-6 bg-gray-50 border border-gray-100 rounded-[32px] outline-none focus:bg-white focus:border-black transition-all font-bold text-sm resize-none shadow-inner"
              />
              <button 
                type="submit"
                disabled={isSubmitting || !newNote.trim()}
                className="w-full py-5 bg-black text-white rounded-[24px] font-black uppercase tracking-[4px] text-xs shadow-xl shadow-black/20 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-50 disabled:hover:scale-100"
              >
                {isSubmitting ? "Syncing..." : "Publish Note"}
              </button>
            </form>
          </div>
        </div>

        {/* Notes Feed */}
        <div className="lg:col-span-2 space-y-6">
          <AnimatePresence mode="popLayout">
            {notes.map((note) => (
              <motion.div 
                key={note.id}
                layout
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                className="bg-white rounded-[40px] p-10 border border-gray-100 shadow-sm relative group overflow-hidden hover:shadow-md transition-shadow"
              >
                <div className="flex justify-between items-start mb-6 border-b border-gray-50 pb-6">
                  <div className="flex items-center gap-4">
                    <div className="w-10 h-10 rounded-2xl bg-gray-50 flex items-center justify-center border border-gray-100 shadow-sm">
                      <User className="w-4 h-4 text-gray-400" />
                    </div>
                    <div>
                      <p className="text-[10px] font-black uppercase tracking-widest text-gray-900">{note.authorName || "Principal Admin"}</p>
                      <div className="flex items-center gap-2 mt-0.5">
                        <Calendar className="w-3 h-3 text-gray-300" />
                        <p className="text-[9px] font-bold text-gray-400 uppercase tracking-tighter">
                          {formatDate(note.createdAt)}
                        </p>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-all">
                    {editingId === note.id ? (
                      <>
                        <button 
                          onClick={() => handleUpdateNote(note.id)}
                          className="p-2 bg-green-50 text-green-500 rounded-xl hover:bg-green-500 hover:text-white"
                        >
                          <Check className="w-4 h-4" />
                        </button>
                        <button 
                          onClick={() => setEditingId(null)}
                          className="p-2 bg-gray-100 text-gray-500 rounded-xl hover:bg-black hover:text-white"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </>
                    ) : (
                      <>
                        <button 
                          onClick={() => {
                            setEditingId(note.id);
                            setEditContent(note.content);
                          }}
                          className="p-2 bg-gray-50 text-gray-400 rounded-xl hover:bg-black hover:text-white"
                        >
                          <Edit3 className="w-4 h-4" />
                        </button>
                        <button 
                          onClick={() => handleDeleteNote(note.id)}
                          className="p-2 bg-red-50 text-red-400 rounded-xl hover:bg-red-500 hover:text-white"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
                
                {editingId === note.id ? (
                  <textarea 
                    value={editContent}
                    onChange={(e) => setEditContent(e.target.value)}
                    className="w-full h-32 px-4 py-4 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm resize-none"
                    autoFocus
                  />
                ) : (
                  <p className="text-gray-600 text-sm font-medium leading-relaxed whitespace-pre-wrap">
                    {note.content}
                  </p>
                )}

                {note.updatedAt && !editingId && (
                  <div className="mt-4 flex items-center gap-1.5 text-gray-300">
                    <AlertCircle className="w-3 h-3" />
                    <p className="text-[9px] font-bold uppercase tracking-widest italic">Edited {formatDate(note.updatedAt)}</p>
                  </div>
                )}
                
                <div className="absolute top-0 right-0 p-10 opacity-[0.015] pointer-events-none">
                   <FileText className="w-40 h-40" />
                </div>
              </motion.div>
            ))}
          </AnimatePresence>

          {notes.length === 0 && (
            <div className="bg-white rounded-[40px] p-24 text-center border-2 border-dashed border-gray-100 flex flex-col items-center">
               <div className="w-16 h-16 bg-gray-50 rounded-full flex items-center justify-center mb-6">
                 <Plus className="w-8 h-8 text-gray-200" />
               </div>
               <h3 className="text-sm font-black uppercase tracking-widest text-gray-400">Vault is Empty</h3>
               <p className="text-xs font-bold text-gray-300 mt-2 uppercase tracking-tighter">No strategic notes have been published yet</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
