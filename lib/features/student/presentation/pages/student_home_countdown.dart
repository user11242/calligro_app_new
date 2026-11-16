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

  void _calculateRemaining() {
    try {
      final startTimeData = widget.course['startTime'];
      final startDateData = widget.course['startDate'];
      final selectedDays = List<String>.from(
        widget.course['selectedDays'] ?? [],
      );

      // Fallback: If data is missing, we keep it disabled
      if (startTimeData == null || selectedDays.isEmpty) {
        if (mounted) {
          setState(() => _remaining = const Duration(hours: 99));
          widget.onTimerUpdate?.call(const Duration(hours: 99));
        }
        return;
      }

      DateTime startTime;
      if (startTimeData is Timestamp) {
        startTime = startTimeData.toDate().toLocal();
      } else if (startTimeData is DateTime) {
        startTime = startTimeData.toLocal();
      } else {
        if (mounted) {
          setState(() => _remaining = const Duration(hours: 99));
          widget.onTimerUpdate?.call(const Duration(hours: 99));
        }
        return;
      }

      DateTime? startDate;
      if (startDateData is Timestamp) {
        startDate = startDateData.toDate().toLocal();
      } else if (startDateData is DateTime) {
        startDate = startDateData.toLocal();
      }

      final now = DateTime.now();

      DateTime? nextSession;
      bool isCurrentlyLive = false;

      final dayFormat = DateFormat('EEEE', 'en_US');

      for (int i = -1; i <= 30; i++) {
        final checkDate = DateTime(now.year, now.month, now.day + i);

        if (startDate != null) {
          final startDay = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          final checkDay = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
          );
          if (checkDay.isBefore(startDay)) continue;
        }

        final dayName = dayFormat.format(checkDate);

        if (selectedDays.contains(dayName)) {
          final localStartTime = startTime.toLocal();
          final sessionTime = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
            localStartTime.hour,
            localStartTime.minute,
          );

          Duration sessionDuration = const Duration(minutes: 90);
          if (widget.course['endTime'] != null) {
            DateTime? endDateTime;
            if (widget.course['endTime'] is Timestamp) {
              endDateTime = (widget.course['endTime'] as Timestamp)
                  .toDate()
                  .toLocal();
            } else if (widget.course['endTime'] is DateTime) {
              endDateTime = widget.course['endTime'].toLocal();
            }

            DateTime? originalStartDateTime;
            if (widget.course['startTime'] is Timestamp) {
              originalStartDateTime = (widget.course['startTime'] as Timestamp)
                  .toDate()
                  .toLocal();
            } else if (widget.course['startTime'] is DateTime) {
              originalStartDateTime = widget.course['startTime'].toLocal();
            }

            if (endDateTime != null && originalStartDateTime != null) {
              final dummyStart = DateTime(
                2000,
                1,
                1,
                originalStartDateTime.hour,
                originalStartDateTime.minute,
              );
              final dummyEnd = DateTime(
                2000,
                1,
                1,
                endDateTime.hour,
                endDateTime.minute,
              );
              var diff = dummyEnd.difference(dummyStart);
              if (diff.isNegative) diff = diff + const Duration(days: 1);

              sessionDuration = diff;
              if (sessionDuration.inMinutes <= 0 ||
                  sessionDuration.inHours > 6) {
                sessionDuration = const Duration(minutes: 90);
              }
            }
          }

          final sessionEndTime = sessionTime.add(sessionDuration);

          if (now.isAfter(sessionTime) && now.isBefore(sessionEndTime)) {
            isCurrentlyLive = true;
            break;
          }

          if (sessionTime.isAfter(now)) {
            nextSession = sessionTime;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          if (isCurrentlyLive) {
            _remaining = Duration.zero;
          } else if (nextSession != null) {
            _remaining = nextSession.difference(now);
          } else {
            _remaining = const Duration(hours: 99);
          }
        });
        widget.onTimerUpdate?.call(
          isCurrentlyLive ? Duration.zero : _remaining,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _remaining = const Duration(hours: 99));
        widget.onTimerUpdate?.call(const Duration(hours: 99));
      }
    }
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
