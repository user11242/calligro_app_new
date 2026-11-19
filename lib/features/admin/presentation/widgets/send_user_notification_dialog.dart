import 'package:flutter/material.dart';

import 'package:calligro_app/l10n/app_localizations.dart';

/// The admin's "send a notification to this user" dialog.
///
/// While sending, the button shows a spinner and cannot be tapped again (a slow
/// send used to invite a second tap, which sent the message twice). A failure is
/// shown in the dialog instead of escaping as an unhandled error (which the crash
/// reporter treated as fatal). Pops `true` once sent.
class SendUserNotificationDialog extends StatefulWidget {
  const SendUserNotificationDialog({super.key, required this.userName, required this.send});

  final String userName;
  final Future<void> Function(String title, String body) send;

  @override
  State<SendUserNotificationDialog> createState() => _SendUserNotificationDialogState();
}

class _SendUserNotificationDialogState extends State<SendUserNotificationDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (_sending || title.isEmpty || body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.send(title, body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e';
      });
    }
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(l10n.sendToUser(widget.userName),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              enabled: !_sending,
              style: const TextStyle(color: Colors.white),
              decoration: _field(l10n.notificationTitle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              enabled: !_sending,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _field(l10n.notificationBody),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text('${l10n.error}: $_error',
                  key: const Key('sendNotificationError'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(l10n.send, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
