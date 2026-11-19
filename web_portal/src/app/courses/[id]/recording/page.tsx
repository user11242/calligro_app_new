"use client";

import { LiveKitRoom } from "@livekit/components-react";
import "@livekit/components-styles";
import CalligroMeetLayout from "@/components/meet/CalligroMeetLayout";
import { useParams, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";

// The page LiveKit egress opens to record a class. Next 15 passes page params as a
// Promise, so the course id is read with useParams() (like every other page).
export default function RecordingLayoutPage() {
  const { id } = useParams<{ id: string }>();
  const searchParams = useSearchParams();
  const token = searchParams.get("token");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return <div className="h-screen w-screen bg-black" />;

  if (!token) {
    return (
      <div className="h-screen w-screen flex items-center justify-center bg-[#0A0A0B] text-white">
        <p>Missing Egress Token.</p>
      </div>
    );
  }

  return (
    <LiveKitRoom
      video={false} // Egress bot doesn't publish video
      audio={false} // Egress bot doesn't publish audio
      token={token}
      serverUrl="wss://calligro-54copltu.livekit.cloud"
      className="h-screen w-screen"
    >
      <CalligroMeetLayout 
        courseId={id} 
        isTeacher={false} 
        onLeave={() => {}} 
        isRecordingMode={true} 
      />
    </LiveKitRoom>
  );
}
