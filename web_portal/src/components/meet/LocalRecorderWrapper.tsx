import React, { useEffect, useState, useRef } from 'react';
import { useLocalParticipant } from '@livekit/components-react';
import { Track } from 'livekit-client';
import { useLocalRecorder } from './hooks/useLocalRecorder';

export default function LocalRecorderWrapper({ courseId, isTeacher }: { courseId: string, isTeacher: boolean }) {
  const { localParticipant } = useLocalParticipant();
  const { startRecording, stopRecordingAndUpload, isUploading } = useLocalRecorder({ courseId });
  const [isRecording, setIsRecording] = useState(false);

  // We need to listen to when the window unloads or component unmounts to trigger upload
  const hasTriggeredUpload = useRef(false);

  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (isRecording && !hasTriggeredUpload.current) {
        // If they try to refresh or close tab mid-recording
        e.preventDefault();
        e.returnValue = "Recording will be lost if you leave without clicking End Class!";
      }
    };
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [isRecording]);

  useEffect(() => {
    // Only teachers should record locally
    if (!isTeacher || isRecording) return;

    // Get the camera and microphone tracks from LiveKit's local participant
    const camPub = localParticipant.getTrackPublication(Track.Source.Camera);
    const micPub = localParticipant.getTrackPublication(Track.Source.Microphone);

    const camTrack = camPub?.track?.mediaStreamTrack;
    const micTrack = micPub?.track?.mediaStreamTrack;

    // Wait until they actually turn on their camera and mic
    if (camTrack && micTrack) {
      // Assemble them into a new standard MediaStream
      const stream = new MediaStream([camTrack, micTrack]);
      startRecording(stream);
      setIsRecording(true);
    }
  }, [localParticipant, isRecording, startRecording, isTeacher]);

  useEffect(() => {
    // Cleanup/Upload on unmount (triggered when they click "End Class" which unmounts the Room)
    return () => {
      if (isTeacher && isRecording && !hasTriggeredUpload.current) {
        hasTriggeredUpload.current = true;
        // Fire and forget the upload
        stopRecordingAndUpload().catch(e => console.error(e));
      }
    };
  }, [stopRecordingAndUpload, isTeacher, isRecording]);

  if (isUploading) {
    return (
      <div className="fixed inset-0 z-[9999] bg-black/80 flex flex-col items-center justify-center backdrop-blur-md">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-accentGold mb-4"></div>
        <h2 className="text-white text-xl font-bold">Uploading Recording...</h2>
        <p className="text-white/60 text-sm mt-2">Please do not close this tab.</p>
      </div>
    );
  }

  return null;
}
