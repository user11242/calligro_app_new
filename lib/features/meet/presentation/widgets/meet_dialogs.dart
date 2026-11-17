import 'package:flutter/material.dart';

import 'package:calligro_app/l10n/app_localizations.dart';

const _dialogBg = Color(0xFF13151A);
const _titleStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
const _bodyStyle = TextStyle(color: Colors.white70);

enum TeacherLeaveChoice { cancel, endForAll }

/// Teacher: leaving ends the class for everyone (there is no "leave only").
Future<TeacherLeaveChoice> showTeacherLeaveDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showDialog<TeacherLeaveChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.leaveClass, style: _titleStyle),
      content: Text(l10n.meetTeacherEndConfirm, style: _bodyStyle),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: () => Navigator.of(ctx).pop(TeacherLeaveChoice.cancel),
          child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          key: const Key('dialog-end-for-all'),
          onPressed: () => Navigator.of(ctx).pop(TeacherLeaveChoice.endForAll),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: Text(l10n.endForAll, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return choice ?? TeacherLeaveChoice.cancel;
}

/// Student: confirm leaving the class.
Future<bool> showStudentLeaveDialog(BuildContext context) =>
    _confirm(context,
        title: (l) => l.leaveClass,
        body: (l) => l.leaveClassroomConfirmation,
        confirm: (l) => l.leave,
        color: Colors.redAccent,
        confirmKey: const Key('dialog-confirm-leave'));

/// Teacher: confirm muting a student's mic or camera.
Future<bool> showConfirmMuteDialog(BuildContext context, {required bool mic}) =>
    _confirm(context,
        title: (l) => l.confirmMuteTitle,
        body: (l) => mic ? l.confirmMuteMic : l.confirmMuteCamera,
        confirm: (l) => l.confirm,
        color: Colors.orange,
        confirmKey: const Key('dialog-confirm-mute'),
        small: true);

/// Teacher: confirm removing a student.
Future<bool> showConfirmKickDialog(BuildContext context) =>
    _confirm(context,
        title: (l) => l.removeParticipantTitle,
        body: (l) => l.removeParticipantConfirm,
        confirm: (l) => l.confirm,
        color: Colors.red,
        confirmKey: const Key('dialog-confirm-kick'),
        small: true);

/// Weak connection: offer audio-only mode. True = switch to audio only.
Future<bool> showAudioOnlyPrompt(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E2028),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.network_check, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          Text(l10n.meetWeakConnectionTitle, style: _titleStyle.copyWith(fontSize: 16)),
        ],
      ),
      content: Text(l10n.meetWeakConnectionBody, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          key: const Key('dialog-audio-only'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEBB937), foregroundColor: Colors.black),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.meetEnableAudioOnly, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Blocking spinner while the server ends the class.
void showBlockingProgress(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(key: Key('ending-progress'), color: Color(0xFFEBB937))),
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String Function(AppLocalizations) title,
  required String Function(AppLocalizations) body,
  required String Function(AppLocalizations) confirm,
  required Color color,
  required Key confirmKey,
  bool small = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: small ? const Color(0xFF1E2028) : _dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 16 : 20)),
      title: Text(title(l10n), style: _titleStyle),
      content: Text(body(l10n), style: _bodyStyle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          key: confirmKey,
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: small ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : null,
          ),
          child: Text(confirm(l10n), style: small ? null : const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return result ?? false;
}
