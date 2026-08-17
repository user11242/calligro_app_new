import { useState, useRef, useCallback } from 'react';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { getApp } from 'firebase/app';

interface UseLocalRecorderOptions {
  courseId: string;
}

export function useLocalRecorder({ courseId }: UseLocalRecorderOptions) {
  const [isRecording, setIsRecording] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const startTimeRef = useRef<number>(0);

  const startRecording = useCallback((stream: MediaStream) => {
    if (isRecording || !stream.active) return;
    
    // Create a clone of the stream to not affect the LiveKit one
    const streamToRecord = stream.clone();
    
    // Safari might not support WebM, but Chrome/Edge do. 
    // We try WebM first, fallback to MP4 if needed.
    const mimeType = MediaRecorder.isTypeSupported('video/webm;codecs=vp8,opus')
      ? 'video/webm;codecs=vp8,opus'
      : 'video/mp4';

    const mediaRecorder = new MediaRecorder(streamToRecord, { mimeType });
    chunksRef.current = [];
    
    mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) {
        chunksRef.current.push(e.data);
      }
    };

    mediaRecorder.start(1000); // chunk every 1 second
    mediaRecorderRef.current = mediaRecorder;
    startTimeRef.current = Date.now();
    setIsRecording(true);
    console.log("Started local recording...");
  }, [isRecording]);

  const stopRecordingAndUpload = useCallback(async () => {
    if (!mediaRecorderRef.current || mediaRecorderRef.current.state === 'inactive') return;

    setIsUploading(true);
    
    // Wait for the recorder to stop and gather final chunks
    const stopPromise = new Promise<Blob>((resolve) => {
      if (!mediaRecorderRef.current) return resolve(new Blob());
      
      mediaRecorderRef.current.onstop = () => {
        const mimeType = mediaRecorderRef.current?.mimeType || 'video/webm';
        const finalBlob = new Blob(chunksRef.current, { type: mimeType });
        resolve(finalBlob);
      };
      
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    });

    const finalBlob = await stopPromise;
    const durationSecs = Math.floor((Date.now() - startTimeRef.current) / 1000);
    
    console.log(`Recording stopped. Size: ${(finalBlob.size / 1024 / 1024).toFixed(2)} MB. Duration: ${durationSecs}s`);

    try {
      const functions = getFunctions(getApp());
      
      // 1. Get Presigned URL
      const generateUrl = httpsCallable<{courseId: string, contentType: string}, {uploadUrl: string, r2FilePath: string}>(functions, 'livekit-generateR2UploadUrl');
      const { data: { uploadUrl, r2FilePath } } = await generateUrl({ 
        courseId, 
        contentType: finalBlob.type 
      });

      // 2. Upload to Cloudflare R2
      console.log("Uploading directly to Cloudflare R2...");
      const uploadRes = await fetch(uploadUrl, {
        method: 'PUT',
        headers: { 'Content-Type': finalBlob.type },
        body: finalBlob
      });

      if (!uploadRes.ok) {
        throw new Error(`Failed to upload to R2: ${uploadRes.statusText}`);
      }

      // 3. Save Metadata
      console.log("Upload complete. Saving metadata...");
      const saveMeta = httpsCallable(functions, 'livekit-saveRecordingMetadata');
      await saveMeta({
        courseId,
        r2FilePath,
        duration: durationSecs
      });

      console.log("Recording successfully saved and linked!");
    } catch (err) {
      console.error("Failed to process local recording:", err);
    } finally {
      setIsUploading(false);
    }
  }, [courseId]);

  return {
    isRecording,
    isUploading,
    startRecording,
    stopRecordingAndUpload
  };
}
