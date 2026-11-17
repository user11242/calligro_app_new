part of 'student_home_page.dart';

class _CountdownTimer extends StatefulWidget {
  final Map<String, dynamic> course;
  final Function(Duration)? onTimerUpdate;
  const _CountdownTimer({required this.course, this.onTimerUpdate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  Duration _remaining = const Duration(
    hours: 99,
  ); // Start with a safe "long wait" to avoid 0s blink

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculateRemaining();
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _calculateRemaining(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Time to the next class (zero while one is live), moved classes included,
  /// from the one schedule rule. (This used to keep its own copy, which ignored
  /// reschedules and kept counting after the course had ended.)
  void _calculateRemaining() {
    final schedule = CourseSchedule.fromMap(widget.course, fallbackOffset: DateTime.now().timeZoneOffset);
    final now = DateTime.now();
    final next = schedule.next(now);
    final remaining = schedule.live(now) != null
        ? Duration.zero
        : (next == null ? const Duration(hours: 99) : next.start.difference(now));
    if (!mounted) return;
    setState(() => _remaining = remaining);
    widget.onTimerUpdate?.call(remaining);
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = _remaining.inDays.toString();
    final hrs = twoDigits(_remaining.inHours.remainder(24));
    final mins = twoDigits(_remaining.inMinutes.remainder(60));
    final secs = twoDigits(_remaining.inSeconds.remainder(60));

    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimePart(days, l10n.timerDays),
        _buildDivider(),
        _buildTimePart(hrs, l10n.timerHrs),
        _buildDivider(),
        _buildTimePart(mins, l10n.timerMin),
        _buildDivider(),
        _buildTimePart(secs, l10n.timerSec),
      ],
    );
  }

  Widget _buildTimePart(String value, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.8),
                AppColors.primary.withOpacity(0.9),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Center(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        ":",
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
