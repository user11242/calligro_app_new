import 'dart:async';

import 'package:flutter/material.dart';

import 'package:calligro_app/core/services/meet_debug_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/meet_controller.dart';
import '../../data/livekit_meet_room.dart';
import '../../data/meet_backend.dart';
import '../../data/meet_platform.dart';
import '../../domain/meet_policies.dart';
import '../../domain/meet_room.dart';
import '../../domain/shared_work.dart';
import '../../data/shared_work_pages.dart';
import 'package:calligro_app/features/classroom/presentation/pages/share_submission_sheet.dart';
import '../widgets/meet_controls.dart';
import '../widgets/meet_dialogs.dart';
import '../widgets/meet_overlays.dart';
import '../widgets/meet_stage.dart';
import '../widgets/participant_tile.dart';
import '../widgets/participants_sheet.dart';
import '../widgets/shared_work_stage.dart';

const _gold = Color(0xFFEBB937);

/// The live class screen. UI only: every decision is made by [MeetController].
class CalligroMeetPage extends StatefulWidget {
  final String token;
  final String serverUrl;
  final String roomName;
  final String courseId;
  final bool isTeacher;
  final String? teacherId;
  final bool startWithMic;
  final bool startWithCamera;
  final MeetCameraPosition startCameraPosition;

  /// Test seams (default: real LiveKit room, real Cloud Functions, real device).
  final MeetRoom Function()? roomFactory;
  final MeetBackend? backend;
  final MeetPlatform? platform;
  final Duration connectGrace;

  /// Test seams for "show a student's work": the picker and the file loader.
  final Future<SubmissionToShare?> Function(BuildContext context, String courseId)? pickSubmission;
  final SharedWorkPageLoader? loadSharedWorkPages;

  const CalligroMeetPage({
    super.key,
    required this.token,
    required this.serverUrl,
    required this.roomName,
    required this.courseId,
    this.isTeacher = false,
    this.teacherId,
    this.startWithMic = false,
    this.startWithCamera = false,
    this.startCameraPosition = MeetCameraPosition.front,
    @visibleForTesting this.roomFactory,
    @visibleForTesting this.backend,
    @visibleForTesting this.platform,
    @visibleForTesting this.connectGrace = const Duration(milliseconds: 800),
    @visibleForTesting this.pickSubmission,
    @visibleForTesting this.loadSharedWorkPages,
  });

  @override
  State<CalligroMeetPage> createState() => _CalligroMeetPageState();
}

class _CalligroMeetPageState extends State<CalligroMeetPage> with WidgetsBindingObserver {
  late final MeetPlatform _platform = widget.platform ?? DeviceMeetPlatform();
  late final MeetController _controller;
  late final StreamSubscription<MeetEffect> _effects;
  final _debug = MeetDebugService();

  bool _showControls = true;
  bool _isGridView = false;
  bool _closing = false;
  double _zoomAtPinchStart = 1;
  Offset? _focusRingAt;
  Timer? _focusRingTimer;
  Timer? _controlsTimer;
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = MeetController(
      room: widget.roomFactory?.call() ?? LiveKitMeetRoom(log: _debug.log),
      backend: widget.backend ?? MeetBackend(courseId: widget.courseId),
      token: widget.token,
      serverUrl: widget.serverUrl,
      isTeacher: widget.isTeacher,
      teacherId: widget.teacherId,
      startWithMic: widget.startWithMic,
      startWithCamera: widget.startWithCamera,
      cameraPosition: widget.startCameraPosition,
      connectGrace: widget.connectGrace,
      log: _debug.log,
    );
    _effects = _controller.effects.listen(_onEffect);
    WidgetsBinding.instance.addObserver(this);
    _platform.enterMeeting();
    _startControlsTimer();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final since = _controller.connectedAt;
      if (mounted && since != null) setState(() => _elapsed = DateTime.now().difference(since));
    });
    _controller.join().then((_) {
      if (_controller.phase == MeetPhase.connected) _platform.startBackgroundAudio();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never react to the transient 'inactive' state (call banner, control center…).
    if (state == AppLifecycleState.paused) _controller.onAppPaused();
    if (state == AppLifecycleState.resumed) _controller.onAppResumed();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _focusRingTimer?.cancel();
    _clock?.cancel();
    _effects.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _platform.exitMeeting();
    _controller.dispose(); // also stops a running recording (fail-safe) and the room
    super.dispose();
  }

  // ── Auto-hiding controls ───────────────────────────────────────────────
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) setState(() => _showControls = false);
    });
  }

  /// A tap on the stage: on the teacher's own camera → focus there; anywhere else → show / hide controls.
  void _onStageTap(TapUpDetails d) {
    if (_controller.canZoomCamera) {
      final hit = meetVideoAt(d.globalPosition, View.of(context).viewId);
      if (hit != null && hit.tag == MeetVideoTag.localCamera) {
        _controller.focusCamera(hit.fraction.dx, hit.fraction.dy);
        _focusRingTimer?.cancel();
        setState(() => _focusRingAt = d.localPosition);
        _focusRingTimer = Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _focusRingAt = null);
        });
        return;
      }
    }
    _toggleControls();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _showControls ? _startControlsTimer() : _controlsTimer?.cancel();
  }

  // ── Effects from the controller ────────────────────────────────────────
  void _onEffect(MeetEffect effect) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (effect) {
      case MeetNoticeEffect(:final notice, :final name):
        switch (notice) {
          case MeetNotice.handRaised:
            _pill(const Icon(Icons.pan_tool, color: Colors.white, size: 18), l10n.studentRaisedHand(name ?? 'Student'),
                background: const Color(0xFF1E2028).withValues(alpha: 0.95), foreground: Colors.white);
          case MeetNotice.teacherEndedMeeting:
            _pill(const WavingIcon(icon: Icons.waving_hand, color: Colors.black, size: 18), l10n.teacherEndedMeeting,
                seconds: 2);
          case MeetNotice.mutedByTeacher:
            _pill(const Icon(Icons.mic_off, color: Colors.black, size: 18), l10n.teacherMutedMic);
          case MeetNotice.cameraDisabledByTeacher:
            _pill(const Icon(Icons.videocam_off, color: Colors.black, size: 18), l10n.teacherDisabledCamera);
          case MeetNotice.kicked:
            _pill(const Icon(Icons.person_remove, color: Colors.white, size: 18), l10n.kickedFromMeeting,
                background: Colors.redAccent, foreground: Colors.white, seconds: 2);
          case MeetNotice.recordingStarted:
            _pill(const Icon(Icons.fiber_manual_record, color: Colors.white, size: 18),
                '${l10n.recordingStarted} · ${l10n.classIsBeingRecorded}',
                background: const Color(0xFF2E7D32), foreground: Colors.white);
          case MeetNotice.audioOnlyOn:
            _pill(const Icon(Icons.headset, color: Colors.black, size: 18), l10n.meetAudioOnlyOn);
          case MeetNotice.audioOnlyOff:
            _pill(const Icon(Icons.videocam, color: Colors.black, size: 18), l10n.meetAudioOnlyOff);
        }
      case MeetErrorEffect(:final message):
        _pill(const Icon(Icons.error_outline, color: Colors.white, size: 18), message,
            background: Colors.red, foreground: Colors.white, seconds: 6);
      case RecordingFailedEffect(:final message):
        _pill(const Icon(Icons.error_outline, color: Colors.white, size: 18), '${l10n.recordingError}: $message',
            background: const Color(0xFFC72C41), foreground: Colors.white, seconds: 5);
      case PlaySoundEffect(:final sound):
        _platform.playSound(sound);
      case PromptAudioOnlyEffect():
        _promptAudioOnly();
      case LeaveMeetingEffect(:final delay):
        Future<void>.delayed(delay, _close);
    }
  }

  /// Compact notice that floats ABOVE the bottom control bar, so it never covers a button.
  void _pill(Widget icon, String text,
      {Color background = _gold, Color foreground = Colors.black, int seconds = 3}) {
    final side = ((MediaQuery.sizeOf(context).width - 420) / 2).clamp(16.0, double.infinity);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: foreground, fontWeight: FontWeight.bold))),
          ],
        ),
        duration: Duration(seconds: seconds),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(side, 0, side, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: background,
      ),
    );
  }

  Future<void> _promptAudioOnly() async {
    if (_controller.isAudioOnly) return;
    final accept = await showAudioOnlyPrompt(context);
    _controller.audioOnlyPromptClosed();
    if (accept) await _controller.setAudioOnly(true);
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  // ── Leaving ────────────────────────────────────────────────────────────
  Future<void> _onLeavePressed() async {
    if (!widget.isTeacher) {
      if (await showStudentLeaveDialog(context)) {
        await _controller.leave();
        _close();
      }
      return;
    }
    final choice = await showTeacherLeaveDialog(context);
    if (!mounted) return;
    switch (choice) {
      case TeacherLeaveChoice.cancel:
        return;
      case TeacherLeaveChoice.endForAll:
        if (!mounted) return;
        showBlockingProgress(context); // the server needs a few seconds
        await _controller.endForAll();
        if (mounted) Navigator.of(context).pop(); // progress dialog
        _close();
    }
  }

  // ── Showing a student's work (teacher) ─────────────────────────────────
  Future<void> _onShowWork() async {
    final pick = widget.pickSubmission ?? (ctx, courseId) => showShareSubmissionSheet(ctx, courseId: courseId);
    final chosen = await pick(context, widget.courseId);
    if (chosen == null || !mounted) return;
    final kind = SharedWorkKind.fromFile(fileName: chosen.fileName, url: chosen.url);
    if (kind == null) {
      _pill(const Icon(Icons.info_outline, color: Colors.white, size: 18), AppLocalizations.of(context)!.meetShowWorkUnsupported,
          background: const Color(0xFF1E2028).withValues(alpha: 0.95), foreground: Colors.white, seconds: 4);
      return;
    }
    _controller.showWork(url: chosen.url, kind: kind, studentName: chosen.studentName, assignmentTitle: chosen.assignmentTitle);
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // leaving must go through the red button (stops recording / confirms)
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final phase = _controller.phase;
            if (phase == MeetPhase.connecting || phase == MeetPhase.failed) {
              return MeetConnectingView(
                onCancel: _close,
                debugConsole: phase == MeetPhase.failed ? const MeetDebugConsole() : null,
              );
            }
            final zoom = _controller.canZoomCamera;
            final tapLayer = Positioned.fill(
              child: GestureDetector(
                key: const Key('tap-layer'),
                behavior: HitTestBehavior.translucent,
                onTapUp: _onStageTap,
                // Teacher with the camera on: pinch zooms the camera; pinches add up (CameraZoomPolicy).
                onScaleStart: zoom ? (_) => _zoomAtPinchStart = _controller.cameraZoom : null,
                onScaleUpdate: zoom
                    ? (d) {
                        if (d.pointerCount < 2) return;
                        _controller.setCameraZoom(
                            CameraZoomPolicy.afterPinch(start: _zoomAtPinchStart, pinchScale: d.scale));
                      }
                    : null,
                child: const SizedBox.expand(),
              ),
            );
            final grid = _isGridView && _controller.stage != null;
            // The teacher is showing a student's work: it takes the whole stage (it handles its own taps).
            final sharing = _controller.sharedWork != null;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (sharing)
                  Positioned.fill(
                    child: SharedWorkStage(
                      controller: _controller,
                      onTap: _toggleControls,
                      loadPages: widget.loadSharedWorkPages ?? loadSharedWorkPages,
                    ),
                  )
                else ...[
                  // Speaker view: the tap layer sits ABOVE the native video views (they swallow taps).
                  // Grid view: tiles must stay tappable (tap → speaker view), so it sits BELOW them.
                  if (grid) tapLayer,
                  Positioned.fill(child: _buildStage(context)),
                  if (!grid) tapLayer,
                ],
                MeetTopBar(
                  controller: _controller,
                  elapsed: _elapsed,
                  visible: _showControls,
                  isGridView: _isGridView,
                  onInteraction: _startControlsTimer,
                  onToggleLayout: () => setState(() => _isGridView = !_isGridView),
                  onLeave: _onLeavePressed,
                ),
                MeetControlBar(
                  controller: _controller,
                  visible: _showControls,
                  onInteraction: _startControlsTimer,
                  onOpenParticipants: () => showParticipantsSheet(context, _controller),
                  onShowWork: widget.isTeacher ? _onShowWork : null,
                ),
                if (_focusRingAt != null && !sharing)
                  Positioned(
                    left: _focusRingAt!.dx - 36,
                    top: _focusRingAt!.dy - 36,
                    child: IgnorePointer(
                      child: Container(
                        key: const Key('camera-focus-ring'),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(border: Border.all(color: _gold, width: 2)),
                      ),
                    ),
                  ),
                if (phase == MeetPhase.reconnecting || phase == MeetPhase.disconnected)
                  MeetReconnectOverlay(
                    reconnecting: phase == MeetPhase.reconnecting,
                    onRejoin: _controller.rejoin,
                    onLeave: _close,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    final stage = _controller.stage;
    if (stage == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(AppLocalizations.of(context)!.waitingForOthersToJoin, style: const TextStyle(color: Colors.white54)),
      );
    }
    if (_isGridView) {
      return MeetGridView(
        controller: _controller,
        controlsVisible: _showControls,
        onTileTap: () => setState(() => _isGridView = false),
      );
    }
    return MeetStageView(stage: stage, raisedHands: _controller.raisedHands, controlsVisible: _showControls);
  }
}
