import 'package:flutter/foundation.dart';

import '../domain/meet_media.dart';
import '../domain/meet_participant.dart';
import '../domain/meet_room.dart';

/// What the user chose on the pre-join screen.
class PreJoinSettings {
  final bool startWithMic;
  final bool startWithCamera;
  final MeetCameraPosition cameraPosition;
  const PreJoinSettings({required this.startWithMic, required this.startWithCamera, required this.cameraPosition});
}

/// The pre-join screen: who is joining, mic/camera choices, camera preview.
/// Talks to the device only through [MeetMediaDevices] / [MeetProfileSource].
class PreJoinController extends ChangeNotifier {
  static const fallbackName = 'Calligro User';

  final MeetMediaDevices _devices;
  final MeetProfileSource _profile;
  final bool isTeacher;
  final void Function(String) _log;

  PreJoinController({
    required MeetMediaDevices devices,
    required MeetProfileSource profile,
    required this.isTeacher,
    void Function(String message)? log,
  })  : _devices = devices,
        _profile = profile,
        _log = log ?? ((_) {});

  bool _disposed = false;

  // ── State ──────────────────────────────────────────────────────────────
  bool _micOn = false;
  bool get micOn => _micOn;

  MeetCameraPreview? _preview;
  bool get cameraOn => _preview != null;
  MeetVideo? get preview => _preview?.video;

  MeetCameraPosition _cameraPosition = MeetCameraPosition.front;
  MeetCameraPosition get cameraPosition => _cameraPosition;

  /// A camera open/close/flip is in progress (taps are ignored meanwhile).
  bool _isBusy = false;
  bool get isBusy => _isBusy;

  bool _isJoining = false;
  bool get isJoining => _isJoining;

  /// Null while loading.
  String? _userName;
  String? get userName => _userName;
  String? _avatarUrl;
  String? get avatarUrl => _avatarUrl;

  /// Why the last mic/camera action didn't work (permission denied, camera busy…).
  String? _lastError;
  String? get lastError => _lastError;

  // ── Setup ──────────────────────────────────────────────────────────────
  /// Teachers start with mic + camera on (both needed for the automatic recording),
  /// but only with the user's permission.
  Future<void> init() async {
    await Future.wait([
      _loadProfile(),
      if (isTeacher) _enableTeacherDefaults(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _profile.load();
      _userName = p.name.isNotEmpty ? p.name : fallbackName;
      _avatarUrl = (p.avatarUrl?.isNotEmpty ?? false) ? p.avatarUrl : null;
    } catch (e) {
      _log('Profile could not be loaded: $e');
      _userName = fallbackName;
      _avatarUrl = null;
    }
    _notify();
  }

  Future<void> _enableTeacherDefaults() async {
    _micOn = await _devices.requestMicrophonePermission();
    if (!_micOn) _lastError = 'Microphone permission denied';
    _notify();
    await _runCameraOp(_openCamera);
  }

  // ── Microphone ─────────────────────────────────────────────────────────
  Future<void> toggleMicrophone() async {
    if (_micOn) {
      _micOn = false;
    } else if (await _devices.requestMicrophonePermission()) {
      _micOn = true;
      _lastError = null;
    } else {
      _lastError = 'Microphone permission denied';
    }
    _notify();
  }

  // ── Camera ─────────────────────────────────────────────────────────────
  Future<void> toggleCamera() => _runCameraOp(cameraOn ? _closeCamera : _openCamera);

  /// Recreates the preview at the other position (restarting is what makes iOS flip).
  Future<void> flipCamera() async {
    if (!cameraOn) return;
    await _runCameraOp(() async {
      final target = _cameraPosition == MeetCameraPosition.front ? MeetCameraPosition.back : MeetCameraPosition.front;
      await _closeCamera();
      _cameraPosition = target;
      await _openCamera(askPermission: false);
    });
  }

  /// One camera operation at a time: a double tap must never open two cameras.
  Future<void> _runCameraOp(Future<void> Function() op) async {
    if (_isBusy || _disposed) return;
    _isBusy = true;
    _notify();
    try {
      await op();
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> _openCamera({bool askPermission = true}) async {
    if (askPermission && !await _devices.requestCameraPermission()) {
      _lastError = 'Camera permission denied';
      return;
    }
    try {
      final preview = await _devices.startCameraPreview(_cameraPosition);
      if (_disposed) {
        await preview.stop(); // the user left while the camera was opening
        return;
      }
      _preview = preview;
      _lastError = null;
    } catch (e) {
      _log('Camera preview error: $e');
      _lastError = 'Camera error: $e';
    }
  }

  Future<void> _closeCamera() async {
    final preview = _preview;
    _preview = null;
    await preview?.stop();
  }

  // ── Join ───────────────────────────────────────────────────────────────
  /// Final choices for the class, or null if a join is already in progress.
  /// Re-checks permissions (they may have been revoked) and frees the camera,
  /// which the class needs.
  Future<PreJoinSettings?> join() async {
    if (_isJoining || _disposed) return null;
    _isJoining = true;
    _notify();
    final wantCamera = cameraOn;
    final mic = _micOn && await _devices.requestMicrophonePermission();
    final camera = wantCamera && await _devices.requestCameraPermission();
    await _closeCamera();
    return PreJoinSettings(startWithMic: mic, startWithCamera: camera, cameraPosition: _cameraPosition);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final preview = _preview;
    _preview = null;
    preview?.stop();
    super.dispose();
  }
}
