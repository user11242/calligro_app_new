"use client";

import { useState, useEffect } from "react";
import { db } from "@/lib/firebase";
import { collection, query, where, onSnapshot, doc, updateDoc, serverTimestamp } from "firebase/firestore";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Search, BookOpen, Video, FileQuestion, FileText,
  CheckCircle2, XCircle, Loader2, User, MessageSquare, ArrowLeft, Send, AlertTriangle, Play
} from "lucide-react";
import toast from "react-hot-toast";

type Lesson = {
  id: string;
  title: string;
  type: "video" | "quiz" | "pdf";
  contentUrl?: string;
};

type Section = {
  id: string;
  title: string;
  lessons: Lesson[];
};

type ReviewNote = {
  id: string;
  targetId: string;
  targetType: "field" | "lesson";
  message: string;
  resolved: boolean;
  createdAt: number;
};

type Course = {
  id: string;
  courseName: string;
  teacherName?: string;
  teacherId: string;
  courseDescription?: string;
  writingType?: string;
  price?: number;
  status: string;
  curriculum?: Section[];
  reviewNotes?: ReviewNote[];
};

export default function CourseReviewPage() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Selection State
  const [selectedCourse, setSelectedCourse] = useState<Course | null>(null);
  
  // Viewer State
  const [activeMedia, setActiveMedia] = useState<{ url: string; type: string; title: string } | null>(null);
  
  // Feedback State (Drafting notes before sending)
  const [draftNotes, setDraftNotes] = useState<ReviewNote[]>([]);
  const [activeNoteTarget, setActiveNoteTarget] = useState<string | null>(null);
  const [noteText, setNoteText] = useState("");
  
  // Action State
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  useEffect(() => {
    // Only fetch courses under review or needing revision
    const q = query(collection(db, "courses"), where("status", "in", ["under_review", "needs_revision"]));
    const unsub = onSnapshot(q, (snap) => {
      const fetched = snap.docs.map((d) => ({ id: d.id, ...d.data() } as Course));
      setCourses(fetched);
      
      // Update selected course if it changed in DB
      if (selectedCourse) {
        const updated = fetched.find(c => c.id === selectedCourse.id);
        if (updated) setSelectedCourse(updated);
      }
      setLoading(false);
    });
    return () => unsub();
  }, [selectedCourse]);

  // Handle Note Drafting
  const handleSaveNote = () => {
    if (!noteText.trim() || !activeNoteTarget) return;
    
    const newNote: ReviewNote = {
      id: Math.random().toString(36).substring(7),
      targetId: activeNoteTarget,
      targetType: activeNoteTarget.startsWith("lesson") ? "lesson" : "field",
      message: noteText.trim(),
      resolved: false,
      createdAt: Date.now(),
    };
    
    setDraftNotes(prev => [...prev, newNote]);
    setNoteText("");
    setActiveNoteTarget(null);
  };
  
  const removeDraftNote = (noteId: string) => {
    setDraftNotes(prev => prev.filter(n => n.id !== noteId));
  };

  // Actions
  const handleApprove = async (courseId: string) => {
    setActionLoading("approve");
    try {
      await updateDoc(doc(db, "courses", courseId), {
        status: "published",
        isPublished: true,
        publishedAt: serverTimestamp(),
      });
      toast.success("Course Approved and Published! 🎉");
      setSelectedCourse(null);
    } catch {
      toast.error("Failed to approve course.");
    } finally {
      setActionLoading(null);
    }
  };

  const handleRequestRevisions = async (courseId: string) => {
    if (draftNotes.length === 0) {
      toast.error("Please add at least one review note before requesting revisions.");
      return;
    }
    
    setActionLoading("revise");
    try {
      // Merge draft notes with any existing unresolved notes in DB
      const existingNotes = selectedCourse?.reviewNotes || [];
      const updatedNotes = [...existingNotes, ...draftNotes];
      
      await updateDoc(doc(db, "courses", courseId), {
        status: "needs_revision",
        isPublished: false,
        reviewNotes: updatedNotes,
        lastReviewedAt: serverTimestamp(),
      });
      toast.success("Revision request sent to teacher! 📝");
      setSelectedCourse(null);
      setDraftNotes([]);
    } catch {
      toast.error("Failed to send revision request.");
    } finally {
      setActionLoading(null);
    }
  };

  const handleReject = async (courseId: string) => {
    setActionLoading("reject");
    try {
      await updateDoc(doc(db, "courses", courseId), {
        status: "rejected",
        isPublished: false,
        rejectedAt: serverTimestamp(),
      });
      toast.error("Course rejected completely.");
      setSelectedCourse(null);
    } catch {
      toast.error("Failed to reject course.");
    } finally {
      setActionLoading(null);
    }
  };

  // LIST VIEW RENDERING
  if (!selectedCourse) {
    const filtered = courses.filter(
      (c) =>
        (c.courseName || "").toLowerCase().includes(search.toLowerCase()) ||
        (c.teacherName || "").toLowerCase().includes(search.toLowerCase())
    );

    if (loading) {
      return (
        <div className="min-h-[400px] flex flex-col items-center justify-center">
          <Loader2 className="w-8 h-8 animate-spin text-black mb-4" />
          <p className="text-[10px] font-black uppercase tracking-[4px] text-gray-300">Loading Master Review Queue...</p>
        </div>
      );
    }

    return (
      <div className="space-y-8 animate-in fade-in duration-700 pb-20">
        <div className="flex flex-col sm:flex-row sm:justify-between sm:items-end gap-4">
          <div>
            <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Course Review</h1>
            <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">
              Master Quality Assurance Queue
            </p>
          </div>
          <div className="relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search pending reviews..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-12 pr-6 py-3 bg-white border border-gray-100 rounded-2xl outline-none focus:border-black transition-all text-xs font-bold w-72 shadow-sm"
            />
          </div>
        </div>

        {filtered.length === 0 ? (
          <div className="bg-white rounded-[40px] border border-gray-100 p-20 text-center shadow-sm">
            <CheckCircle2 className="w-12 h-12 text-gray-200 mx-auto mb-4" />
            <p className="text-[10px] font-black uppercase tracking-[4px] text-gray-400">
              {search ? "No courses match your search" : "Inbox Zero. All courses reviewed!"}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
            <AnimatePresence>
              {filtered.map((course) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="group bg-white hover:bg-gray-50 rounded-[32px] border border-gray-100 shadow-sm hover:shadow-xl transition-all overflow-hidden cursor-pointer flex flex-col"
                  onClick={() => {
                    setSelectedCourse(course);
                    setDraftNotes([]);
                    setActiveMedia(null);
                  }}
                >
                  <div className="p-8 flex-1">
                    <div className="flex items-center justify-between mb-4">
                      <span className={`px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest border ${
                        course.status === 'needs_revision' 
                          ? 'bg-red-50 text-red-600 border-red-100'
                          : 'bg-amber-50 text-amber-700 border-amber-100'
                      }`}>
                        {course.status === 'needs_revision' ? 'Waiting on Teacher' : 'Requires Admin Review'}
                      </span>
                      {course.writingType && (
                        <span className="px-3 py-1 bg-gray-50 text-gray-500 border border-gray-100 rounded-full text-[9px] font-black uppercase tracking-widest">
                          {course.writingType}
                        </span>
                      )}
                    </div>
                    
                    <h3 className="text-xl font-black text-gray-900 leading-tight mb-2 group-hover:text-black transition-colors">{course.courseName || "Untitled Course"}</h3>
                    
                    <div className="flex items-center gap-2 text-gray-400 mb-6">
                      <User className="w-3.5 h-3.5" />
                      <span className="text-[10px] font-bold uppercase tracking-wider">{course.teacherName || course.teacherId}</span>
                    </div>

                    <div className="flex items-center gap-4 text-gray-400 text-[10px] font-black uppercase tracking-widest">
                      <div className="flex items-center gap-1.5 bg-white px-3 py-1.5 rounded-lg border border-gray-100 shadow-sm">
                        <BookOpen className="w-3.5 h-3.5 text-gray-500" />
                        <span>{course.curriculum?.length || 0} Sec</span>
                      </div>
                      <div className="flex items-center gap-1.5 bg-white px-3 py-1.5 rounded-lg border border-gray-100 shadow-sm">
                        <Video className="w-3.5 h-3.5 text-gray-500" />
                        <span>
                          {course.curriculum?.reduce((s, sec) => s + (sec.lessons?.filter((l) => l.type === "video").length || 0), 0) || 0} Vids
                        </span>
                      </div>
                      
                      {/* Show unresolved feedback count if any */}
                      {course.reviewNotes && course.reviewNotes.filter(n => !n.resolved).length > 0 && (
                        <div className="flex items-center gap-1.5 bg-red-50 text-red-600 px-3 py-1.5 rounded-lg border border-red-100">
                          <AlertTriangle className="w-3.5 h-3.5" />
                          <span>{course.reviewNotes.filter(n => !n.resolved).length} Unresolved</span>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  <div className="p-4 bg-gray-50 border-t border-gray-100 flex items-center justify-center text-xs font-black uppercase tracking-widest text-gray-400 group-hover:bg-black group-hover:text-white transition-all">
                    Open Review Console
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        )}
      </div>
    );
  }

  // REVIEW CONSOLE RENDERING
  const existingUnresolvedNotes = selectedCourse.reviewNotes?.filter(n => !n.resolved) || [];
  const totalIssues = draftNotes.length + existingUnresolvedNotes.length;

  return (
    <div className="fixed inset-0 z-[100] bg-white flex flex-col animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Top Navigation Bar */}
      <div className="h-20 border-b border-gray-100 flex items-center justify-between px-8 bg-white shrink-0 shadow-sm relative z-20">
        <div className="flex items-center gap-6">
          <button 
            onClick={() => setSelectedCourse(null)}
            className="w-10 h-10 rounded-full bg-gray-50 hover:bg-gray-100 flex items-center justify-center transition-colors"
          >
            <ArrowLeft className="w-4 h-4 text-gray-600" />
          </button>
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-gray-400">Auditing Course</p>
            <h2 className="text-xl font-black text-gray-900 tracking-tight">{selectedCourse.courseName}</h2>
          </div>
        </div>
        
        <div className="flex items-center gap-3">
          <button
            onClick={() => handleReject(selectedCourse.id)}
            disabled={!!actionLoading}
            className="px-6 py-3 bg-red-50 hover:bg-red-100 text-red-600 rounded-xl text-xs font-black uppercase tracking-widest transition-all disabled:opacity-50"
          >
            Reject Permanently
          </button>
          
          <button
            onClick={() => handleRequestRevisions(selectedCourse.id)}
            disabled={!!actionLoading || draftNotes.length === 0}
            className="flex items-center gap-2 px-6 py-3 bg-amber-500 hover:bg-amber-600 text-white rounded-xl text-xs font-black uppercase tracking-widest transition-all disabled:opacity-50 disabled:bg-gray-100 disabled:text-gray-400 shadow-lg shadow-amber-500/20"
          >
            {actionLoading === "revise" ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            Request Revisions ({draftNotes.length})
          </button>
          
          <button
            onClick={() => handleApprove(selectedCourse.id)}
            disabled={!!actionLoading || totalIssues > 0}
            className="flex items-center gap-2 px-6 py-3 bg-black hover:bg-gray-800 text-white rounded-xl text-xs font-black uppercase tracking-widest transition-all disabled:opacity-50 disabled:bg-gray-200 disabled:text-gray-400 shadow-lg shadow-black/10"
          >
            {actionLoading === "approve" ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
            Approve & Publish
          </button>
        </div>
      </div>

      {/* Split Pane Workspace */}
      <div className="flex-1 flex overflow-hidden bg-gray-50/50">
        
        {/* Left Pane: Media Viewer (2/3 width) */}
        <div className="flex-[2] border-r border-gray-200 p-8 flex flex-col relative">
          {!activeMedia ? (
            <div className="flex-1 rounded-[40px] border-2 border-dashed border-gray-200 bg-white flex flex-col items-center justify-center text-center p-12">
              <div className="w-24 h-24 bg-gray-50 rounded-full flex items-center justify-center mb-6">
                <Video className="w-10 h-10 text-gray-300" />
              </div>
              <h3 className="text-2xl font-black text-gray-300 tracking-tight uppercase font-outfit">Quality Assurance Viewer</h3>
              <p className="text-sm font-bold text-gray-400 mt-2 max-w-sm leading-relaxed">
                Select a video, PDF, or quiz from the curriculum panel on the right to inspect it in high detail.
              </p>
            </div>
          ) : (
            <div className="flex-1 flex flex-col bg-black rounded-[40px] overflow-hidden shadow-2xl shadow-black/10 relative group animate-in fade-in duration-500">
              <div className="absolute top-0 left-0 w-full p-6 bg-gradient-to-b from-black/80 to-transparent z-10 pointer-events-none">
                <span className="px-3 py-1 bg-white/20 backdrop-blur-md text-white border border-white/20 rounded-lg text-[10px] font-black uppercase tracking-widest">
                  {activeMedia.type} Preview
                </span>
                <h3 className="text-white font-bold text-lg mt-2 tracking-tight drop-shadow-md">{activeMedia.title}</h3>
              </div>
              
              {activeMedia.type === "video" && (
                <video 
                  src={activeMedia.url} 
                  controls 
                  autoPlay 
                  crossOrigin="anonymous" 
                  className="w-full h-full object-contain bg-black" 
                />
              )}
              
              {activeMedia.type === "pdf" && (
                <iframe 
                  src={activeMedia.url} 
                  className="w-full h-full bg-white"
                />
              )}
              
              {activeMedia.type === "quiz" && (
                <div className="w-full h-full bg-white p-12 overflow-y-auto">
                  <div className="max-w-2xl mx-auto space-y-6">
                    <div className="p-8 bg-blue-50 border border-blue-100 rounded-3xl text-center">
                      <FileQuestion className="w-12 h-12 text-blue-300 mx-auto mb-4" />
                      <h4 className="text-xl font-black text-blue-900 tracking-tight">{activeMedia.title}</h4>
                      <p className="text-blue-600/70 text-sm font-bold mt-2">Interactive Quiz Preview Placeholder</p>
                    </div>
                    {/* In a real scenario, you'd fetch the quiz questions and render them here. */}
                    <div className="p-6 bg-gray-50 border border-gray-100 rounded-2xl">
                      <p className="text-xs font-black uppercase tracking-widest text-gray-400">Admin Note</p>
                      <p className="text-sm font-bold text-gray-600 mt-1">
                        To preview exact quiz questions, the data structure needs a subcollection query here. Currently viewing quiz metadata.
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Right Pane: Curriculum & Feedback Builder (1/3 width) */}
        <div className="flex-1 flex flex-col bg-white overflow-hidden relative">
          <div className="p-6 border-b border-gray-100 bg-gray-50/50 shrink-0">
            <h3 className="text-sm font-black uppercase tracking-widest text-gray-900 flex items-center gap-2">
              <MessageSquare className="w-4 h-4" /> 
              Feedback Builder
            </h3>
            <p className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mt-1">
              Select any item below to inject required revisions.
            </p>
          </div>
          
          <div className="flex-1 overflow-y-auto p-6 space-y-8">
            
            {/* General Feedback Review */}
            <div className="mb-8">
              <p className="text-[10px] font-black uppercase tracking-[3px] text-gray-400 mb-4 px-2">Overall Feedback</p>
              
              <div className="bg-gray-900 border border-black rounded-2xl p-4 shadow-sm group relative">
                <p className="text-[9px] font-black uppercase tracking-widest text-gray-400 mb-1">General Note</p>
                <p className="text-sm font-bold text-white">Add a general note for the entire course.</p>
                
                <div className="absolute top-4 right-4 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button 
                    onClick={() => setActiveNoteTarget("general")}
                    className="px-3 py-1.5 bg-white text-black text-[9px] font-black uppercase tracking-widest rounded-lg"
                  >
                    + Note
                  </button>
                </div>
                
                {/* Feedback Editor Inline */}
                <AnimatePresence>
                  {activeNoteTarget === "general" && (
                    <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
                      <div className="mt-4 pt-4 border-t border-gray-800">
                        <textarea 
                          value={noteText} onChange={e => setNoteText(e.target.value)}
                          placeholder="Type overall feedback here..."
                          className="w-full bg-gray-800 text-white border border-gray-700 rounded-xl p-3 text-xs font-bold outline-none focus:border-white resize-none" rows={3} autoFocus
                        />
                        <div className="flex justify-end gap-2 mt-2">
                          <button onClick={() => setActiveNoteTarget(null)} className="px-4 py-2 text-[10px] font-black uppercase tracking-widest text-gray-400 hover:text-white">Cancel</button>
                          <button onClick={handleSaveNote} className="px-4 py-2 bg-white text-black text-[10px] font-black uppercase tracking-widest rounded-lg">Save Note</button>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
              
              {/* Draft Notes Display for General */}
              {draftNotes.filter(n => n.targetId === "general").map(note => (
                <div key={note.id} className="ml-4 mt-2 p-3 bg-amber-50 border-l-4 border-amber-500 rounded-r-xl">
                  <p className="text-xs font-bold text-amber-900">{note.message}</p>
                  <button onClick={() => removeDraftNote(note.id)} className="text-[9px] font-black uppercase tracking-widest text-amber-500 hover:text-amber-700 mt-2">Remove</button>
                </div>
              ))}
              
              {/* Existing Unresolved Notes Display for General */}
              {selectedCourse.reviewNotes?.filter(n => n.targetId === "general" && !n.resolved).map(note => (
                <div key={note.id} className="ml-4 mt-2 p-3 bg-red-50 border-l-4 border-red-500 rounded-r-xl">
                  <span className="inline-block px-1.5 py-0.5 bg-red-200 text-red-800 text-[8px] font-black uppercase tracking-widest rounded-md mb-1">Unresolved from Teacher</span>
                  <p className="text-xs font-bold text-red-900 leading-snug">{note.message}</p>
                </div>
              ))}
            </div>

            {/* Meta Data Review */}
            <div>
              <p className="text-[10px] font-black uppercase tracking-[3px] text-gray-400 mb-4 px-2">Course Metadata</p>
              <div className="space-y-3">
                
                {/* Field Row: Title */}
                <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm hover:border-black transition-colors group relative">
                  <p className="text-[9px] font-black uppercase tracking-widest text-gray-400 mb-1">Course Title</p>
                  <p className="text-sm font-bold text-gray-900">{selectedCourse.courseName}</p>
                  
                  <div className="absolute top-4 right-4 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button 
                      onClick={() => setActiveNoteTarget("courseName")}
                      className="px-3 py-1.5 bg-black text-white text-[9px] font-black uppercase tracking-widest rounded-lg"
                    >
                      + Note
                    </button>
                  </div>
                  
                  {/* Feedback Editor Inline */}
                  <AnimatePresence>
                    {activeNoteTarget === "courseName" && (
                      <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
                        <div className="mt-4 pt-4 border-t border-gray-100">
                          <textarea 
                            value={noteText} onChange={e => setNoteText(e.target.value)}
                            placeholder="Type required changes for the title..."
                            className="w-full bg-gray-50 border border-gray-200 rounded-xl p-3 text-xs font-bold outline-none focus:border-black resize-none" rows={3} autoFocus
                          />
                          <div className="flex justify-end gap-2 mt-2">
                            <button onClick={() => setActiveNoteTarget(null)} className="px-4 py-2 text-[10px] font-black uppercase tracking-widest text-gray-400 hover:text-gray-900">Cancel</button>
                            <button onClick={handleSaveNote} className="px-4 py-2 bg-black text-white text-[10px] font-black uppercase tracking-widest rounded-lg">Save Note</button>
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
                
                {/* Draft Notes Display for Title */}
                {draftNotes.filter(n => n.targetId === "courseName").map(note => (
                  <div key={note.id} className="ml-4 p-3 bg-amber-50 border-l-4 border-amber-500 rounded-r-xl">
                    <p className="text-xs font-bold text-amber-900">{note.message}</p>
                    <button onClick={() => removeDraftNote(note.id)} className="text-[9px] font-black uppercase tracking-widest text-amber-500 hover:text-amber-700 mt-2">Remove</button>
                  </div>
                ))}
                
              </div>
            </div>
            
            {/* Curriculum Review */}
            <div>
              <p className="text-[10px] font-black uppercase tracking-[3px] text-gray-400 mb-4 px-2">Curriculum Explorer</p>
              {selectedCourse.curriculum?.map((section, sIdx) => (
                <div key={section.id || sIdx} className="mb-6">
                  <div className="px-2 mb-3">
                    <h4 className="text-xs font-black text-gray-900">Sec {sIdx + 1}: {section.title}</h4>
                  </div>
                  
                  <div className="space-y-2">
                    {section.lessons?.map((lesson, lIdx) => {
                      const noteTarget = `lesson_${lesson.id}`;
                      const lessonDraftNotes = draftNotes.filter(n => n.targetId === noteTarget);
                      const lessonExistingNotes = selectedCourse.reviewNotes?.filter(n => n.targetId === noteTarget && !n.resolved) || [];
                      
                      return (
                        <div key={lesson.id || lIdx} className="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow">
                          
                          <div className="p-4 flex items-center justify-between group">
                            <div className="flex items-center gap-3 flex-1 min-w-0 pr-4">
                              <div className="w-8 h-8 rounded-lg bg-gray-50 flex items-center justify-center shrink-0">
                                {lesson.type === "video" ? <Play className="w-3.5 h-3.5 text-blue-500 ml-0.5" /> : 
                                 lesson.type === "pdf" ? <FileText className="w-3.5 h-3.5 text-red-500" /> : 
                                 <FileQuestion className="w-3.5 h-3.5 text-amber-500" />}
                              </div>
                              <div className="truncate">
                                <p className="text-xs font-bold text-gray-900 truncate">{lesson.title}</p>
                                <p className="text-[9px] font-black uppercase tracking-widest text-gray-400 mt-0.5">{lesson.type}</p>
                              </div>
                            </div>
                            
                            <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                              {lesson.contentUrl && (
                                <button 
                                  onClick={() => setActiveMedia({ url: lesson.contentUrl!, type: lesson.type, title: lesson.title })}
                                  className="px-3 py-1.5 bg-blue-50 text-blue-600 text-[9px] font-black uppercase tracking-widest rounded-lg"
                                >
                                  Preview
                                </button>
                              )}
                              <button 
                                onClick={() => setActiveNoteTarget(noteTarget)}
                                className="px-3 py-1.5 bg-black text-white text-[9px] font-black uppercase tracking-widest rounded-lg"
                              >
                                + Note
                              </button>
                            </div>
                          </div>
                          
                          {/* Note Editor Inline */}
                          <AnimatePresence>
                            {activeNoteTarget === noteTarget && (
                              <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden border-t border-gray-100 bg-gray-50/50">
                                <div className="p-4">
                                  <textarea 
                                    value={noteText} onChange={e => setNoteText(e.target.value)}
                                    placeholder={`Required fix for ${lesson.title}...`}
                                    className="w-full bg-white border border-gray-200 rounded-xl p-3 text-xs font-bold outline-none focus:border-black resize-none" rows={3} autoFocus
                                  />
                                  <div className="flex justify-end gap-2 mt-2">
                                    <button onClick={() => setActiveNoteTarget(null)} className="px-4 py-2 text-[10px] font-black uppercase tracking-widest text-gray-400 hover:text-gray-900">Cancel</button>
                                    <button onClick={handleSaveNote} className="px-4 py-2 bg-black text-white text-[10px] font-black uppercase tracking-widest rounded-lg">Save Note</button>
                                  </div>
                                </div>
                              </motion.div>
                            )}
                          </AnimatePresence>
                          
                          {/* Display Notes under this lesson */}
                          {lessonDraftNotes.map(note => (
                            <div key={note.id} className="p-3 bg-amber-50 border-t border-amber-100 flex items-start justify-between gap-4">
                              <div>
                                <span className="inline-block px-1.5 py-0.5 bg-amber-200 text-amber-800 text-[8px] font-black uppercase tracking-widest rounded-md mb-1">New Note</span>
                                <p className="text-xs font-bold text-amber-900 leading-snug">{note.message}</p>
                              </div>
                              <button onClick={() => removeDraftNote(note.id)} className="text-amber-400 hover:text-amber-700 p-1 shrink-0"><XCircle className="w-4 h-4" /></button>
                            </div>
                          ))}
                          
                          {lessonExistingNotes.map(note => (
                            <div key={note.id} className="p-3 bg-red-50 border-t border-red-100">
                              <span className="inline-block px-1.5 py-0.5 bg-red-200 text-red-800 text-[8px] font-black uppercase tracking-widest rounded-md mb-1">Unresolved from Teacher</span>
                              <p className="text-xs font-bold text-red-900 leading-snug">{note.message}</p>
                            </div>
                          ))}
                          
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>

          </div>
        </div>

      </div>
    </div>
  );
}
