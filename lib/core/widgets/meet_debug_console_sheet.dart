import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calligro_app/core/services/meet_debug_service.dart';

/// A bottom sheet widget that displays persistent LiveKit debug logs.
/// Can be shown from any page using [MeetDebugConsoleSheet.show].
class MeetDebugConsoleSheet extends StatefulWidget {
  const MeetDebugConsoleSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MeetDebugConsoleSheet(),
    );
  }

  @override
  State<MeetDebugConsoleSheet> createState() => _MeetDebugConsoleSheetState();
}

class _MeetDebugConsoleSheetState extends State<MeetDebugConsoleSheet> {
  final ScrollController _scroll = ScrollController();
  final _service = MeetDebugService();
  bool _autoScroll = true;
  String _filter = 'all'; // all | error | warning | success | info

  @override
  void initState() {
    super.initState();
    _service.addListener(_onLogsUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onLogsUpdated() {
    if (mounted) {
      setState(() {});
      if (_autoScroll) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onLogsUpdated);
    _scroll.dispose();
    super.dispose();
  }

  Color _colorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.error:   return const Color(0xFFFF5252);
      case LogLevel.success: return const Color(0xFF69FF8B);
      case LogLevel.warning: return const Color(0xFFFFD740);
      case LogLevel.info:    return const Color(0xFF40C4FF);
      case LogLevel.verbose: return Colors.white54;
    }
  }

  String _badgeForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.error:   return 'ERROR';
      case LogLevel.success: return 'OK';
      case LogLevel.warning: return 'WARN';
      case LogLevel.info:    return 'INFO';
      case LogLevel.verbose: return '···';
    }
  }

  Color _badgeBgForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.error:   return const Color(0x33FF5252);
      case LogLevel.success: return const Color(0x3369FF8B);
      case LogLevel.warning: return const Color(0x33FFD740);
      case LogLevel.info:    return const Color(0x3340C4FF);
      case LogLevel.verbose: return const Color(0x22FFFFFF);
    }
  }

  List<MeetLogEntry> get _filteredLogs {
    final logs = _service.logs;
    if (_filter == 'all') return logs;
    return logs.where((e) {
      switch (_filter) {
        case 'error':   return e.level == LogLevel.error;
        case 'warning': return e.level == LogLevel.warning;
        case 'success': return e.level == LogLevel.success;
        case 'info':    return e.level == LogLevel.info;
        default: return true;
      }
    }).toList();
  }

  void _copyAll() {
    final buffer = StringBuffer();
    for (final e in _service.logs) {
      buffer.writeln('[${e.formattedTime}] [${e.level.name.toUpperCase()}] ${e.message}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 All logs copied to clipboard'),
        backgroundColor: Color(0xFF1A1C23),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white54,
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;
    final all = _service.logs;
    final errorCount = all.where((e) => e.level == LogLevel.error).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.97,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: errorCount > 0
                  ? const Color(0xFFFF5252).withValues(alpha: 0.5)
                  : Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LiveKit Debug Console',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${all.length} entries${errorCount > 0 ? " · $errorCount error${errorCount > 1 ? 's' : ''}" : ""}',
                            style: TextStyle(
                              color: errorCount > 0
                                  ? const Color(0xFFFF5252)
                                  : Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Auto-scroll toggle
                    GestureDetector(
                      onTap: () => setState(() => _autoScroll = !_autoScroll),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _autoScroll
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _autoScroll ? Colors.green : Colors.white24,
                          ),
                        ),
                        child: Text(
                          _autoScroll ? '⬇ AUTO' : '⏸ PAUSED',
                          style: TextStyle(
                            color: _autoScroll ? Colors.green : Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Copy button
                    GestureDetector(
                      onTap: _copyAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          '📋 COPY',
                          style: TextStyle(color: Colors.white54, fontSize: 9),
                        ),
                      ),
                    ),
                    // Clear button
                    GestureDetector(
                      onTap: () {
                        _service.clear();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '🗑 CLEAR',
                          style: TextStyle(color: Colors.red, fontSize: 9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('ALL', 'all', Colors.white),
                      const SizedBox(width: 6),
                      _filterChip('ERRORS', 'error', const Color(0xFFFF5252)),
                      const SizedBox(width: 6),
                      _filterChip('WARNINGS', 'warning', const Color(0xFFFFD740)),
                      const SizedBox(width: 6),
                      _filterChip('SUCCESS', 'success', const Color(0xFF69FF8B)),
                      const SizedBox(width: 6),
                      _filterChip('INFO', 'info', const Color(0xFF40C4FF)),
                    ],
                  ),
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Log entries
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white24, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              all.isEmpty
                                  ? 'No logs yet.\nJoin a classroom to see events here.'
                                  : 'No entries match the "$_filter" filter.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) {
                          final entry = filtered[i];
                          final color = _colorForLevel(entry.level);
                          final isError = entry.level == LogLevel.error;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            color: isError
                                ? const Color(0xFFFF5252).withValues(alpha: 0.06)
                                : Colors.transparent,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Level badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  margin: const EdgeInsets.only(right: 8, top: 1),
                                  decoration: BoxDecoration(
                                    color: _badgeBgForLevel(entry.level),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.4),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    _badgeForLevel(entry.level),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                // Message + timestamp
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.message,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.formattedTime,
                                        style: const TextStyle(
                                          color: Colors.white24,
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
