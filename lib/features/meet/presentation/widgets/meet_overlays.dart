import 'package:flutter/material.dart';

import 'package:calligro_app/core/services/meet_debug_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

const _gold = Color(0xFFEBB937);

/// Shown while connecting (and when connecting failed).
class MeetConnectingView extends StatelessWidget {
  final VoidCallback onCancel;
  final Widget? debugConsole;
  const MeetConnectingView({
    super.key,
    required this.onCancel,
    this.debugConsole,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C23),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              color: _gold,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            l10n.connectingToClassroom,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.connectingDisclaimer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 48),
          TextButton.icon(
            key: const Key('cancel-connection'),
            onPressed: onCancel,
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            label: Text(
              l10n.cancelConnection,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    // The debug log sits BESIDE the status (landscape), never on top of the Cancel button.
    return Container(
      color: const Color(0xFF0F1115),
      child: debugConsole == null
          ? status
          : SafeArea(
              child: Row(
                children: [
                  Expanded(child: SingleChildScrollView(child: status)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: debugConsole!,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// "Reconnecting…" spinner, or "Connection lost" with Rejoin / Leave.
class MeetReconnectOverlay extends StatelessWidget {
  final bool reconnecting;
  final VoidCallback onRejoin;
  final VoidCallback onLeave;

  const MeetReconnectOverlay({
    super.key,
    required this.reconnecting,
    required this.onRejoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF13151A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: reconnecting
                ? [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.reconnecting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.connectionDropped,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]
                : [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.connectionLost,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.sessionEndedOrCouldNotBeEstablished,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('rejoin'),
                        onPressed: onRejoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Rejoin Classroom',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('leave-after-disconnect'),
                      onPressed: onLeave,
                      child: Text(
                        'Leave Class',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

/// In-app LiveKit debug log (shown when connecting fails).
class MeetDebugConsole extends StatefulWidget {
  const MeetDebugConsole({super.key});

  @override
  State<MeetDebugConsole> createState() => _MeetDebugConsoleState();
}

class _MeetDebugConsoleState extends State<MeetDebugConsole> {
  final _debug = MeetDebugService();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.orange.withValues(alpha: 0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🐛 LiveKit Debug Log',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(_debug.clear),
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(8),
                itemCount: _debug.logs.length,
                itemBuilder: (_, i) {
                  final entry = _debug.logs[i];
                  final color = switch (entry.level) {
                    LogLevel.error => const Color(0xFFFF6B6B),
                    LogLevel.success => const Color(0xFF69FF8B),
                    LogLevel.warning => Colors.yellow,
                    LogLevel.info => const Color(0xFF69C4FF),
                    _ => Colors.white70,
                  };
                  return Text(
                    '[${entry.formattedTime}] ${entry.message}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
