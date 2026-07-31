"use client";

import React, { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";
import { getFunctions, httpsCallable } from "firebase/functions";
import { auth, app, db } from "@/lib/firebase";
import { getDoc, doc } from "firebase/firestore";
import { Loader2, ShieldAlert, ArrowLeft } from "lucide-react";
import Link from "next/link";
import CalligroMeetRoom from "@/components/meet/CalligroMeetRoom";

export default function ClassroomPage() {
  const { id } = useParams();
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [user, setUser] = useState<any>(null);
  const [isTeacher, setIsTeacher] = useState(false);
  const [courseName, setCourseName] = useState("");
  const [livekitData, setLivekitData] = useState<{ token: string; serverUrl: string } | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      if (u) {
        setUser(u);
      } else {
        router.push("/login");
      }
    });
    return () => unsubscribe();
  }, [router]);

  useEffect(() => {
    if (!id || !user) return;

    const fetchToken = async () => {
      try {
        let courseTeacherId = "";
        // Fetch basic course info for the header
        const docRef = doc(db, "courses", id as string);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          const data = docSnap.data();
          setCourseName(data.title || data.courseName || "Classroom");
          setIsTeacher(data.teacherId === user.uid);
          courseTeacherId = data.teacherId;
        }

        // Call Cloud Function to get LiveKit Token
        const functions = getFunctions(app);
        const getLiveKitToken = httpsCallable(functions, 'livekit-generateLiveKitToken');
        const result = await getLiveKitToken({ courseId: id });
        
        const data = result.data as { token: string; serverUrl: string; roomName: string };
        
        setLivekitData({
          token: data.token,
          serverUrl: data.serverUrl,
        });

        // Trigger Automated YouTube Recording for everyone (temporarily for testing)
        const startAutomatedRecording = httpsCallable(functions, 'livekit-startAutomatedRecording');
        startAutomatedRecording({ courseId: id }).catch(e => console.error("Failed to start auto recording:", e));

      } catch (err: any) {
        console.error("Error generating token:", err);
        setError(err.message || "Failed to load secure classroom.");
      } finally {
        setLoading(false);
      }
    };

    fetchToken();
  }, [id, user]);

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex flex-col items-center justify-center space-y-4">
        <Loader2 className="w-12 h-12 text-primary animate-spin" />
        <p className="text-white/60 font-medium font-outfit uppercase tracking-widest text-sm">
          Authenticating Secure Connection...
        </p>
      </div>
    );
  }

  if (error || !livekitData) {
    return (
      <div className="min-h-screen bg-black flex flex-col items-center justify-center p-6 text-center">
        <div className="w-20 h-20 bg-red-500/20 rounded-full flex items-center justify-center mb-6">
          <ShieldAlert className="w-10 h-10 text-red-500" />
        </div>
        <h1 className="text-2xl font-black text-white mb-2">Access Denied</h1>
        <p className="text-white/40 max-w-md mx-auto mb-8 font-medium">{error || "Token generation failed"}</p>
        <Link 
          href={`/courses/${id}`}
          className="px-8 py-3 bg-white/10 hover:bg-white/20 text-white rounded-xl font-bold transition-all flex items-center gap-2"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Course
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-screen bg-black overflow-hidden relative font-outfit">
      {/* Premium Glass Header */}
      <div className="absolute top-0 left-0 right-0 h-16 bg-gradient-to-b from-black/80 to-transparent z-40 pointer-events-none flex items-start">
        <div className="w-full flex items-center justify-between px-6 pt-4 pointer-events-auto">
          {/* Left Side: Logo & Course Name */}
          <div className="flex items-center gap-4 bg-[#13151A]/60 backdrop-blur-xl border border-white/10 rounded-2xl px-4 py-2 shadow-2xl">
            <Link href={`/courses/${id}`} className="p-1.5 hover:bg-white/10 rounded-full transition-colors group">
              <ArrowLeft className="w-4 h-4 text-white/60 group-hover:text-white" />
            </Link>
            <div className="w-px h-5 bg-white/10" />
            <div className="flex items-center gap-3">
              <img src="/assets/images/Logo.png" alt="Calligro" className="w-6 h-6 object-contain drop-shadow-[0_0_10px_rgba(235,185,55,0.4)]" />
              <div className="flex flex-col">
                <div className="flex items-center gap-2">
                  <span className="text-[10px] font-black text-primary tracking-[0.2em] uppercase">Calligro Live</span>
                </div>
                <h1 className="text-[11px] font-bold text-white/80 truncate max-w-[200px]">
                  {courseName}
                </h1>
              </div>
            </div>
          </div>
          
          {/* Right Side: Security Badge */}
          <div className="hidden sm:flex items-center gap-2 bg-[#13151A]/60 backdrop-blur-xl border border-white/10 rounded-2xl px-4 py-2.5 shadow-2xl">
             <div className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </div>
            <span className="text-[10px] font-black uppercase tracking-widest text-emerald-400/90">
              Encrypted Session
            </span>
          </div>
        </div>
      </div>

      {/* Main Meet Room */}
      <CalligroMeetRoom
        token={livekitData.token}
        serverUrl={livekitData.serverUrl}
        courseId={id as string}
        isTeacher={isTeacher}
        onLeave={() => router.push(`/courses/${id}`)}
      />
    </div>
  );
}
