"use client";

import React, { useState, useEffect } from "react";
import { useRoomContext, useLocalParticipant } from "@livekit/components-react";
import { useConnectionResilience } from "./hooks/useConnectionResilience";
import AudioOnlyPrompt from "./AudioOnlyPrompt";

export default function ResilienceManager() {
  const room = useRoomContext();
  const { localParticipant } = useLocalParticipant();
  const [showPrompt, setShowPrompt] = useState(false);
  const [isAudioOnlyMode, setIsAudioOnlyMode] = useState(false);

  // Hook into our hysteresis state machine
  const { setCooldown } = useConnectionResilience(() => {
    if (!isAudioOnlyMode) {
      setShowPrompt(true);
    }
  });

  const handleAcceptAudioOnly = () => {
    console.log("[Resilience] Switching to Audio-Only Mode");
    setShowPrompt(false);
    setIsAudioOnlyMode(true);

    // 1. Disable local camera upload to save upload bandwidth
    if (localParticipant && localParticipant.isCameraEnabled) {
      localParticipant.setCameraEnabled(false);
    }

    // 2. Unsubscribe from all existing remote video tracks to save download bandwidth
    if (room) {
      Array.from(room.remoteParticipants.values()).forEach((participant) => {
        Array.from(participant.videoTrackPublications.values()).forEach((pub) => {
          if (pub.isSubscribed) {
            console.log(`[Resilience] Unsubscribing from remote video track: ${pub.trackSid}`);
            pub.setSubscribed(false);
          }
        });
      });
    }
  };

  const handleDismissPrompt = () => {
    setShowPrompt(false);
    setCooldown();
  };

  // 3. Proactively unsubscribe from any NEW video tracks if Audio-Only mode is active
  useEffect(() => {
    if (!room || !isAudioOnlyMode) return;

    const handleTrackSubscribed = (track: any, publication: any, participant: any) => {
      if (track.kind === "video") {
        console.log(`[Resilience] Audio-Only active: Unsubscribing from new video track from ${participant.identity}`);
        publication.setSubscribed(false);
      }
    };

    room.on("trackSubscribed", handleTrackSubscribed);
    return () => {
      room.off("trackSubscribed", handleTrackSubscribed);
    };
  }, [room, isAudioOnlyMode]);

  return (
    <AudioOnlyPrompt
      isOpen={showPrompt}
      onAccept={handleAcceptAudioOnly}
      onDismiss={handleDismissPrompt}
    />
  );
}
