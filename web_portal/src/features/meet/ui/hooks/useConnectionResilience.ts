import { useEffect, useRef } from "react";
import { useRoomContext } from "@livekit/components-react";
import { ConnectionQuality, RoomEvent, Participant } from "livekit-client";

/**
 * Hook to manage connection resilience state machine.
 * Triggers the `onTriggerAudioOnly` callback if the local participant's
 * connection quality is Poor or Lost for 10 continuous seconds.
 */
export function useConnectionResilience(onTriggerAudioOnly: () => void) {
  const room = useRoomContext();
  const qualityTimerRef = useRef<NodeJS.Timeout | null>(null);
  const cooldownRef = useRef<boolean>(false);

  useEffect(() => {
    if (!room) return;

    const handleQuality = (quality: ConnectionQuality, participant: Participant) => {
      // We only care about the local participant's connection to the LiveKit server
      if (participant.sid !== room.localParticipant.sid) return;

      if (quality === ConnectionQuality.Poor || quality === ConnectionQuality.Lost) {
        if (!qualityTimerRef.current && !cooldownRef.current) {
          console.warn("[Resilience] Poor connection detected. Starting 10s hysteresis timer...");
          qualityTimerRef.current = setTimeout(() => {
            console.warn("[Resilience] Connection poor for 10s. Triggering audio-only prompt.");
            onTriggerAudioOnly();
            qualityTimerRef.current = null;
          }, 10000);
        }
      } else {
        if (qualityTimerRef.current) {
          console.log("[Resilience] Connection recovered. Cancelling hysteresis timer.");
          clearTimeout(qualityTimerRef.current);
          qualityTimerRef.current = null;
        }
      }
    };

    room.on(RoomEvent.ConnectionQualityChanged, handleQuality);
    
    return () => {
      room.off(RoomEvent.ConnectionQualityChanged, handleQuality);
      if (qualityTimerRef.current) {
        clearTimeout(qualityTimerRef.current);
      }
    };
  }, [room, onTriggerAudioOnly]);

  const setCooldown = () => {
    console.log("[Resilience] User dismissed prompt. Enforcing 60s cooldown.");
    cooldownRef.current = true;
    if (qualityTimerRef.current) {
      clearTimeout(qualityTimerRef.current);
      qualityTimerRef.current = null;
    }
    
    setTimeout(() => {
      console.log("[Resilience] Cooldown ended. Hysteresis can trigger again.");
      cooldownRef.current = false;
    }, 60000);
  };

  return { setCooldown };
}
