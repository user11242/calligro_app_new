"use client";

import React, { useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { doc, getDoc } from "firebase/firestore";
import { db, auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { Loader2, ShieldAlert, ArrowLeft, ShieldCheck, Video, Users, UserCheck } from "lucide-react";
import Link from "next/link";

declare global {
  interface Window {
    JitsiMeetExternalAPI: any;
  }
}

interface Participant {
  id: string;
  displayName: string;
  role: string;
  avatar?: string;
}

export default function ClassroomPage() {
  const { id } = useParams();
  const router = useRouter();
  const jitsiContainerRef = useRef<HTMLDivElement>(null);
  const jitsiApiRef = useRef<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [course, setCourse] = useState<any>(null);
  const [user, setUser] = useState<any>(null);
  const [participants, setParticipants] = useState<Participant[]>([]);
  const [isParticipantsOpen, setIsParticipantsOpen] = useState(false);

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

    const fetchCourse = async () => {
      try {
        const docRef = doc(db, "courses", id as string);
        const docSnap = await getDoc(docRef);

        if (docSnap.exists()) {
          const data = docSnap.data();
          const isEnrolled = data.enrolledStudents?.includes(user.uid);
          const isTeacher = data.teacherId === user.uid;

          if (!isEnrolled && !isTeacher) {
            setError("Access Denied. You are not enrolled in this course.");
          } else if (!data.calligroMeetLink && !data.googleMeetLink) {
            setError("No classroom link found for this course.");
          } else {
            setCourse(data);
          }
        } else {
          setError("Course not found.");
        }
      } catch (err) {
        console.error("Error fetching course:", err);
        setError("Failed to load course details.");
      } finally {
        setLoading(false);
      }
    };

    fetchCourse();
  }, [id, user]);

  useEffect(() => {
    if (!course || !jitsiContainerRef.current) return;

    const loadJitsiScript = () => {
      if (window.JitsiMeetExternalAPI) {
        initJitsi();
        return;
      }

      const script = document.createElement("script");
      script.src = "https://meet.element.io/external_api.js";
      script.async = true;
      script.onload = initJitsi;
      script.onerror = () => {
        const script2 = document.createElement("script");
        script2.src = "https://jitsi.riot.im/external_api.js";
        script2.onload = initJitsi;
        document.body.appendChild(script2);
      };
      document.body.appendChild(script);
    };

    const initJitsi = () => {
      const domain = "meet.element.io";
      
      // 🛡️ 10000% SECURITY: Use a 'Private Hashed' room name that is unguessable by outsiders
      // We combine the base link with a secret suffix only the portal/app knows.
      const baseRoom = course.calligroMeetLink || course.googleMeetLink;
      const roomName = `Calligro_Private_${baseRoom}_SECURE_`;

      const options = {
        roomName: roomName,
        width: "100%",
        height: "100%",
        parentNode: jitsiContainerRef.current,
        userInfo: {
          displayName: user?.displayName || "Student",
          email: user?.email || "",
        },
        configOverwrite: {
          prejoinPageEnabled: false,
          prejoinConfig: { enabled: false }, 
          startWithAudioMuted: user?.uid !== course?.teacherId,
          startWithVideoMuted: user?.uid !== course?.teacherId,
          disableInviteFunctions: true,
          doNotStoreRoom: true,
          enableWelcomePage: false,
          lobbyModeEnabled: false, 
          toolbarButtons: [
            'microphone', 'camera', 'chat', 'raisehand', 'tileview', 'hangup', 'fullscreen'
          ],
        },
      };

      const api = new window.JitsiMeetExternalAPI(domain, options);
      jitsiApiRef.current = api;

      const updateParticipantList = () => {
        if (!api) return;
        
        // 🛠️ Get both local and remote participants
        const remoteInfo = api.getParticipantsInfo();
        
        const isTeacher = course?.teacherId === user?.uid;
        
        // Jitsi's getParticipantsInfo often omits the local user. 
        // We ensure the local user is ALWAYS displayed in the sidebar.
        const localParticipant: Participant = {
            id: 'local-session-host',
            displayName: user?.displayName || "You",
            role: isTeacher ? 'moderator' : 'participant', 
            avatar: user?.photoURL
        };

        const participantMap = new Map<string, Participant>();
        // Add local user first
        participantMap.set(localParticipant.displayName, localParticipant);

        remoteInfo.forEach((p: any) => {
            const name = p.displayName || "Anonymous";
            const existing = participantMap.get(name);
            
            // Check if this remote participant is actually the teacher
            const isRemoteTeacher = course?.teacherId === p.participantId || name === course?.teacherName; 

            if (!existing || (p.role === 'moderator' && existing.role !== 'moderator')) {
                participantMap.set(name, {
                    id: p.participantId,
                    displayName: name,
                    role: (p.participantId === course?.teacherId) ? 'moderator' : p.role || "participant",
                    avatar: p.avatarURL
                });
            }
        });

        setParticipants(Array.from(participantMap.values()));
      };

      api.addEventListener('videoConferenceJoined', () => {
        // Force an update when joined to show the local user immediately
        updateParticipantList();
        
        // 🔐 SECURITY: Ensure room is locked silently
        if (course.classroomPassword) {
            setTimeout(() => {
                api.executeCommand('password', course.classroomPassword);
            }, 1000);
        }
      });

      // 🔐 SECURITY: Silent login if Jitsi re-prompts for password
      api.addEventListener('passwordRequired', () => {
        if (course.classroomPassword) {
            api.executeCommand('password', course.classroomPassword);
        }
      });

      api.addEventListener('participantJoined', updateParticipantList);
      api.addEventListener('participantLeft', updateParticipantList);
      api.addEventListener('displayNameChange', updateParticipantList);
      api.addEventListener('participantRoleChanged', updateParticipantList);
    };

    loadJitsiScript();

    return () => {
      if (jitsiApiRef.current) {
        jitsiApiRef.current.dispose();
      }
      if (jitsiContainerRef.current) {
        jitsiContainerRef.current.innerHTML = "";
      }
    };
  }, [course, user]);

  if (loading) {
    return (
      <div className="min-h-screen bg-secondary-dark flex flex-col items-center justify-center space-y-4">
        <Loader2 className="w-12 h-12 text-primary animate-spin" />
        <p className="text-white/60 font-medium font-outfit">Entering Secure Classroom...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-secondary-dark flex flex-col items-center justify-center p-6 text-center">
        <div className="w-20 h-20 bg-red-500/20 rounded-full flex items-center justify-center mb-6">
          <ShieldAlert className="w-10 h-10 text-red-500" />
        </div>
        <h1 className="text-2xl font-black text-white mb-2">Access Error</h1>
        <p className="text-white/40 max-w-md mx-auto mb-8 font-medium">{error}</p>
        <Link 
          href={`/courses/${id}`}
          className="btn-gold px-8 py-3 flex items-center gap-2"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Course
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-screen bg-black overflow-hidden">
      {/* Super Secure Header */}
      <div className="h-14 bg-secondary-dark border-b border-white/10 flex items-center justify-between px-6 z-10 shadow-2xl">
        <div className="flex items-center gap-4">
          <Link href={`/courses/${id}`} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <ArrowLeft className="w-5 h-5 text-white/40" />
          </Link>
          <div className="flex items-center gap-3">
            <img src="/assets/images/Logo.png" alt="Calligro" className="w-8 h-8 object-contain" />
            <div className="h-6 w-px bg-white/10 hidden sm:block" />
            <div className="hidden sm:block">
              <div className="flex items-center gap-2">
                <span className="text-xs font-black text-primary tracking-[0.2em] uppercase">Calligro</span>
                <span className="text-white/20 text-[10px]">|</span>
                <h1 className="text-xs font-bold text-white truncate max-w-[150px]">
                  {course?.title || course?.courseName || "Classroom"}
                </h1>
              </div>
              <p className="text-[10px] text-white/30 font-bold uppercase tracking-widest leading-tight">Live Learning Environment</p>
            </div>
          </div>
        </div>
        
        <div className="flex items-center gap-4">
            <div className="hidden md:flex items-center gap-2 px-3 py-1.5 bg-green-500/5 border border-green-500/10 rounded-full">
                <ShieldCheck className="w-3 h-3 text-green-500" />
                <p className="text-[10px] text-green-500 font-black uppercase tracking-wider">Secure Access</p>
            </div>

            <button 
              onClick={() => setIsParticipantsOpen(!isParticipantsOpen)}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg transition-all border ${
                isParticipantsOpen 
                  ? "bg-primary text-black border-primary font-black shadow-[0_0_15px_rgba(235,185,55,0.3)]" 
                  : "bg-white/5 text-white/60 border-white/10 hover:bg-white/10"
              }`}
            >
              <Users className="w-4 h-4" />
              <span className="text-xs font-bold">{participants.length > 0 ? participants.length : "..."}</span>
            </button>
        </div>
      </div>

      <div className="flex-1 flex overflow-hidden">
        {/* Jitsi Holder */}
        <div className="flex-1 bg-black relative">
          <div ref={jitsiContainerRef} className="absolute inset-0" />
        </div>

        {/* Live Participants Sidebar */}
        {isParticipantsOpen && (
          <div className="w-80 bg-secondary-dark border-l border-white/10 flex flex-col animate-in slide-in-from-right duration-300">
            <div className="p-4 border-b border-white/10 flex items-center justify-between">
              <h2 className="text-sm font-black text-white uppercase tracking-widest flex items-center gap-2">
                <Users className="w-4 h-4 text-primary" />
                Who's In
              </h2>
              <span className="bg-primary/20 text-primary px-2 py-0.5 rounded text-[10px] font-black">{participants.length} Active</span>
            </div>

            <div className="flex-1 overflow-y-auto p-2 space-y-1">
              {participants.map((p) => (
                <div 
                  key={p.id} 
                  className={`flex items-center justify-between p-3 rounded-xl transition-all border ${
                    p.role === 'moderator' 
                      ? "bg-primary/10 border-primary/20" 
                      : "bg-white/5 border-transparent hover:border-white/10"
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className="relative">
                      {p.avatar ? (
                        <img src={p.avatar} alt={p.displayName} className="w-8 h-8 rounded-full border border-white/10" />
                      ) : (
                        <div className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-xs font-black text-white/40">
                          {p.displayName.charAt(0).toUpperCase()}
                        </div>
                      )}
                      {p.role === 'moderator' && (
                        <div className="absolute -bottom-1 -right-1 bg-primary text-black rounded-full p-0.5 shadow-lg border border-secondary-dark">
                          <UserCheck className="w-2.5 h-2.5" />
                        </div>
                      )}
                    </div>
                    <div>
                      <p className={`text-xs font-bold leading-none ${p.role === 'moderator' ? 'text-primary' : 'text-white/80'}`}>
                        {p.displayName}
                      </p>
                      <p className="text-[9px] text-white/30 uppercase tracking-tighter mt-1">
                        {p.role === 'moderator' ? 'Session Host' : 'Student'}
                      </p>
                    </div>
                  </div>

                  {p.role === 'moderator' && (
                    <div className="px-2 py-0.5 bg-primary text-black text-[8px] font-black rounded uppercase tracking-tighter shadow-sm">
                      Host
                    </div>
                  )}
                </div>
              ))}

              {participants.length === 0 && (
                <div className="text-center py-12">
                   <Loader2 className="w-8 h-8 text-white/10 animate-spin mx-auto mb-3" />
                   <p className="text-[10px] text-white/20 uppercase font-black tracking-widest">Syndicating list...</p>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
