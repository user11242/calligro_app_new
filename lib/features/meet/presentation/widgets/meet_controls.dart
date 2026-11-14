import 'package:flutter/material.dart';

import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/meet_controller.dart';

const _gold = Color(0xFFEBB937);

/// Round control button of the bottom pill.
class MeetControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color? color;
  final Color iconColor;

  const MeetControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = true,
    this.color,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? (isActive ? Colors.white24 : Colors.red.withValues(alpha: 0.8)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

/// Small waving-hand animation used in the "teacher ended the class" notice.
class WavingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  const WavingIcon({super.key, required this.icon, required this.color, required this.size});

  @override
  State<WavingIcon> createState() => _WavingIconState();
}

class _WavingIconState extends State<WavingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(duration: const Duration(milliseconds: 400), vsync: this)..repeat(reverse: true);
  late final Animation<double> _animation =
      Tween<double>(begin: -0.1, end: 0.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _animation, child: Icon(widget.icon, color: widget.color, size: widget.size));
}

String formatMeetDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}

/// Shows/hides a bar with a slide + fade (tap-to-show immersive controls).
class _AutoHide extends StatelessWidget {
  final bool visible;
  final bool top;
  final Widget child;
  const _AutoHide({required this.visible, required this.top, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      top: top ? (visible ? 0 : -90) : null,
      bottom: top ? null : (visible ? 14 : -90),
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1.0 : 0.0,
          child: SafeArea(top: top, bottom: !top, child: child),
        ),
      ),
    );
  }
}

/// Top bar: secure badge + class timer · REC badge / start-recording · layout toggle · leave.
class MeetTopBar extends StatelessWidget {
  final MeetController controller;
  final Duration elapsed;
  final bool visible;
  final bool isGridView;
  final VoidCallback onInteraction;
  final VoidCallback onToggleLayout;
  final VoidCallback onLeave;

  const MeetTopBar({
    super.key,
    required this.controller,
    required this.elapsed,
    required this.visible,
    required this.isGridView,
    required this.onInteraction,
    required this.onToggleLayout,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _AutoHide(
      visible: visible,
      top: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.black.withValues(alpha: 0.0)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formatMeetDuration(elapsed),
                    key: const Key('meet-timer'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (controller.isRecording) ...[
                  Container(
                    key: const Key('rec-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                        ),
                        SizedBox(width: 6),
                        Text('REC',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (controller.isTeacher) ...[
                  IconButton(
                    key: const Key('start-recording'),
                    icon: const Icon(Icons.radio_button_unchecked, color: Colors.white54),
                    tooltip: l10n.startRecording,
                    onPressed: () {
                      onInteraction();
                      controller.startRecording();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  key: const Key('toggle-layout'),
                  icon: Icon(
                    isGridView ? Icons.featured_play_list_outlined : Icons.grid_view,
                    color: isGridView ? _gold : Colors.white70,
                  ),
                  tooltip: isGridView ? l10n.meetSpeakerView : l10n.meetGridView,
                  onPressed: () {
                    onInteraction();
                    onToggleLayout();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('leave'),
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  tooltip: controller.isTeacher ? l10n.endForAll : l10n.leave,
                  onPressed: () {
                    onInteraction();
                    onLeave();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom pill: mic · camera · flip · (audio-only exit) · participants (teacher) / raise hand (student).
class MeetControlBar extends StatelessWidget {
  final MeetController controller;
  final bool visible;
  final VoidCallback onInteraction;
  final VoidCallback onOpenParticipants;

  const MeetControlBar({
    super.key,
    required this.controller,
    required this.visible,
    required this.onInteraction,
    required this.onOpenParticipants,
  });

  void Function() _tap(void Function() action) => () {
        onInteraction();
        action();
      };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _AutoHide(
      visible: visible,
      top: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF13151A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MeetControlButton(
                key: const Key('toggle-mic'),
                icon: c.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                isActive: c.isMicrophoneEnabled,
                onTap: _tap(c.toggleMicrophone),
              ),
              const SizedBox(width: 14),
              MeetControlButton(
                key: const Key('toggle-camera'),
                icon: c.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                isActive: c.isCameraEnabled,
                onTap: _tap(c.toggleCamera),
              ),
              if (c.isCameraEnabled) ...[
                const SizedBox(width: 14),
                MeetControlButton(key: const Key('flip-camera'), icon: Icons.flip_camera_ios, onTap: _tap(c.flipCamera)),
              ],
              const SizedBox(width: 14),
              if (c.isAudioOnly) ...[
                MeetControlButton(
                  key: const Key('exit-audio-only'),
                  icon: Icons.headset,
                  color: _gold,
                  iconColor: Colors.black,
                  onTap: _tap(() => c.setAudioOnly(false)),
                ),
                const SizedBox(width: 14),
              ],
              if (c.isTeacher)
                MeetControlButton(key: const Key('open-participants'), icon: Icons.people, onTap: _tap(onOpenParticipants))
              else
                MeetControlButton(
                  key: const Key('raise-hand'),
                  icon: Icons.pan_tool,
                  color: c.isHandRaised ? _gold : Colors.white24,
                  iconColor: c.isHandRaised ? Colors.black : Colors.white,
                  onTap: _tap(c.toggleHand),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
