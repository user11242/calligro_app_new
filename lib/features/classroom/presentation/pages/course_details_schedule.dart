part of 'course_details_page.dart';

/// Split out of course_details_page.dart (unchanged code): sections that only
/// read the page's state.
extension _ScheduleSections on _CourseDetailsPageState {
  Widget _buildScheduleTab() {
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat dateFormatter = DateFormat.yMMMd(locale);
    final DateFormat timeFormatter = DateFormat.jm(locale);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.startDate,
                          startDate,
                          dateFormatter,
                          Icons.calendar_month_rounded,
                        ),
                        Container(
                          height: 50,
                          width: 1.5,
                          color: Colors.white12,
                        ),
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.endDate,
                          endDate,
                          dateFormatter,
                          Icons.event_available_rounded,
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Divider(color: Colors.white10, thickness: 1.5),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.startTime,
                          selectedTime,
                          timeFormatter,
                          Icons.access_time_filled_rounded,
                        ),
                        Container(
                          height: 50,
                          width: 1.5,
                          color: Colors.white12,
                        ),
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.endTime,
                          endTime,
                          timeFormatter,
                          Icons.update_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (selectedDays.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.sessionBreakdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.totalClasses(totalSessions).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: sessionDates.entries.map((entry) {
                if (entry.value.isEmpty) return const SizedBox.shrink();
                final dayName = entry.key;
                final dates = entry.value;
                final isExpanded = expandedDay == dayName;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.accentGold.withOpacity(0.05)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExpanded
                          ? AppColors.accentGold.withOpacity(0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => _toggleDayExpansion(dayName),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: isExpanded
                                ? AppColors.accentGold
                                : Colors.white54,
                          ),
                        ),
                        title: Text(
                          _getLocalizedDay(context, dayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppColors.accentGold.withOpacity(0.1)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: isExpanded
                                ? AppColors.accentGold
                                : Colors.white30,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isExpanded
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: dates
                                        .map(
                                          (date) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 12,
                                                  color: AppColors.accentGold,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  dateFormatter.format(date),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getLocalizedDay(BuildContext context, String day) {
    final l10n = AppLocalizations.of(context)!;
    switch (day) {
      case 'Sunday':
        return l10n.sunday;
      case 'Monday':
        return l10n.monday;
      case 'Tuesday':
        return l10n.tuesday;
      case 'Wednesday':
        return l10n.wednesday;
      case 'Thursday':
        return l10n.thursday;
      case 'Friday':
        return l10n.friday;
      case 'Saturday':
        return l10n.saturday;
      default:
        return day;
    }
  }

  Widget _buildDynamicSchedulingCard() {
    final hasReschedule = _rescheduledData != null;
    final bool isSessionToday = _isSessionToday();

    if (!isTeacher && !hasReschedule) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hasReschedule
            ? Colors.orangeAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: hasReschedule
              ? Colors.orangeAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_send_rounded,
                color: hasReschedule ? Colors.orangeAccent : Colors.white60,
              ),
              const SizedBox(width: 12),
              Text(
                hasReschedule
                    ? AppLocalizations.of(context)!.sessionRescheduled
                    : AppLocalizations.of(context)!.todaysSchedule,
                style: TextStyle(
                  color: hasReschedule ? Colors.orangeAccent : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasReschedule) ...[
            Text(
              AppLocalizations.of(context)!.teacherMovedSession,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${AppLocalizations.of(context)!.newTime} ${DateFormat.jm(Localizations.localeOf(context).toString()).format((_rescheduledData!['newStartTime'] as Timestamp).toDate())}",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ] else
            Text(
              AppLocalizations.of(context)!.sessionOnTime,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          if (isTeacher) ...[
            if (!isSessionToday && !hasReschedule) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.cannotRescheduleNotMeetingDay,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isSessionToday || hasReschedule)
                    ? _showRescheduleDialog
                    : null,
                icon: Icon(
                  hasReschedule ? Icons.edit_calendar : Icons.more_time,
                  size: 18,
                ),
                label: _isSavingReschedule
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        hasReschedule
                            ? AppLocalizations.of(context)!.updateReschedule
                            : AppLocalizations.of(context)!.rescheduleToday,
                      ),
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  disabledForegroundColor: Colors.white30,
                  backgroundColor: hasReschedule
                      ? Colors.orangeAccent
                      : AppColors.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (hasReschedule)
              TextButton(
                onPressed: _cancelReschedule,
                child: Text(
                  AppLocalizations.of(context)!.cancelReschedule,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _isSessionToday() {
    if (selectedDays.isEmpty) return false;

    // Check if the course is currently active
    if (startDate == null || endDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);

    if (today.isBefore(startDay)) return false; // Course hasn't started yet
    if (today.isAfter(endDay)) return false; // Course has already ended

    final todayName = DateFormat('EEEE').format(now);
    return selectedDays.contains(todayName);
  }
}
