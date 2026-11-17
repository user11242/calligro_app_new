import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show HitTestResult, RenderMetaData;
import 'package:livekit_client/livekit_client.dart' show VideoTrack, VideoTrackRenderer, VideoViewFit;

import '../../domain/meet_participant.dart';
import '../../domain/meet_room.dart';

/// Renders a [MeetVideo]. The real room puts a LiveKit VideoTrack in the handle;
/// anything else (tests) renders an empty black box.
class MeetVideoView extends StatelessWidget {
  final MeetVideo video;
  final bool cover;
  const MeetVideoView(this.video, {super.key, this.cover = false});

  @override
  Widget build(BuildContext context) {
    final handle = video.handle;
    final Widget view = handle is VideoTrack
        ? VideoTrackRenderer(handle, fit: cover ? VideoViewFit.cover : VideoViewFit.contain)
        : const ColoredBox(key: Key('meet-video'), color: Colors.black);
    // Every video is tagged, so the meet page can tell WHICH picture is under a tap
    // (our own camera → tap-to-focus; anyone else's → show / hide the controls).
    if (!video.isLocalCamera) return MetaData(metaData: MeetVideoTag.other, behavior: HitTestBehavior.opaque, child: view);
    // Our own camera: LiveKit's built-in pinch zoom and tap-to-focus are switched off
    // (its zoom restarted from 1x on every pinch); the meet page does both instead.
    return MetaData(metaData: MeetVideoTag.localCamera, behavior: HitTestBehavior.opaque, child: IgnorePointer(child: view));
  }
}

/// What a video picture is, for finding the one under a tap.
enum MeetVideoTag { localCamera, other }

/// The picture under [globalPosition]: our own camera (with the tap as fractions
/// of that picture), another video, or nothing.
({MeetVideoTag tag, Offset fraction})? meetVideoAt(Offset globalPosition, int viewId) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData && target.metaData is MeetVideoTag && target.hasSize) {
      final local = target.globalToLocal(globalPosition);
      return (
        tag: target.metaData as MeetVideoTag,
        fraction: Offset(local.dx / target.size.width, local.dy / target.size.height),
      );
    }
  }
  return null;
}

/// One participant tile (full-screen stage, PiP or grid cell).
class ParticipantTile extends StatelessWidget {
  final MeetParticipant participant;
  final bool isHandRaised;
  final bool isPiP;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isHandRaised = false,
    this.isPiP = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final displayName = p.displayName;
    final avatarUrl = p.avatarUrl;
    final video = p.video;
    final showVideo = video != null && !video.isMuted && (p.isScreenShareTile || p.isCameraEnabled);

    final (IconData qualityIcon, Color qualityColor) = switch (p.connectionQuality) {
      MeetConnectionQuality.excellent => (Icons.signal_wifi_4_bar, const Color(0xFF22C55E)),
      MeetConnectionQuality.good => (Icons.network_wifi_3_bar, const Color(0xFFEBB937)),
      MeetConnectionQuality.poor => (Icons.network_wifi_1_bar, const Color(0xFFEF4444)),
      MeetConnectionQuality.unknown => (Icons.signal_wifi_4_bar, Colors.white38),
    };

    return Container(
      decoration: isPiP
          ? BoxDecoration(
              color: const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: p.isSpeaking
                    ? const Color(0xFF22C55E)
                    : (isHandRaised ? const Color(0xFFEBB937) : Colors.white24),
                width: p.isSpeaking || isHandRaised ? 2 : 1,
              ),
            )
          : const BoxDecoration(color: Colors.black),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showVideo)
            isPiP
                ? ClipRRect(borderRadius: BorderRadius.circular(11), child: MeetVideoView(video, cover: true))
                : MeetVideoView(video)
          else
            Container(
              color: const Color(0xFF13151A),
              child: Center(
                child: (avatarUrl != null)
                    ? CircleAvatar(radius: isPiP ? 20 : 48, backgroundImage: NetworkImage(avatarUrl))
                    : CircleAvatar(
                        radius: isPiP ? 20 : 48,
                        backgroundColor: const Color(0xFFEBB937),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: isPiP ? 16 : 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
              ),
            ),

          // Connection quality + raised hand (top-left)
          Positioned(
            top: 8,
            left: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(qualityIcon, color: qualityColor, size: isPiP ? 10 : 14),
                ),
                if (isHandRaised) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: const Key('tile-hand'),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBB937),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.pan_tool, color: Colors.black, size: isPiP ? 10 : 14),
                  ),
                ],
              ],
            ),
          ),

          // Name tag (bottom-left)
          Positioned(
            bottom: isPiP ? 6 : 16,
            left: isPiP ? 6 : 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isPiP ? 6 : 10, vertical: isPiP ? 3 : 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isPiP ? 80 : 160),
                        child: Text(
                          displayName,
                          style: TextStyle(color: Colors.white, fontSize: isPiP ? 10 : 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!p.isMicrophoneEnabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                          child: Icon(Icons.mic_off, color: Colors.white, size: isPiP ? 8 : 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
