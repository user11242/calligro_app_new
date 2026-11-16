import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart';
import '../../../../core/message/app_messenger.dart';

class CourseSchedulePage extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final Function(DateTime?) onStartDateSelected;
  final Function(DateTime?) onEndDateSelected;
  final Function(DateTime?) onStartTimeSelected;
  final Function(DateTime?) onEndTimeSelected;
  final Function onNext;
  final Function onBack;

  const CourseSchedulePage({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.onStartDateSelected,
    required this.onEndDateSelected,
    required this.onStartTimeSelected,
    required this.onEndTimeSelected,
    required this.onNext,
    required this.onBack,
  });

  @override
  _CourseSchedulePageState createState() => _CourseSchedulePageState();
}

class _CourseSchedulePageState extends State<CourseSchedulePage> {
  TimeOfDay? _startTimeLocal;
  TimeOfDay? _endTimeLocal;

  @override
  void initState() {
    super.initState();
    _syncLocalTimes();
  }

  @override
  void didUpdateWidget(covariant CourseSchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTime != oldWidget.startTime ||
        widget.endTime != oldWidget.endTime) {
      _syncLocalTimes();
    }
  }

  void _syncLocalTimes() {
    if (widget.startTime != null) {
      _startTimeLocal = TimeOfDay.fromDateTime(widget.startTime!.toLocal());
    }
    if (widget.endTime != null) {
      _endTimeLocal = TimeOfDay.fromDateTime(widget.endTime!.toLocal());
    }
  }

  // Method to show messages using SnackBar
  void _showMessage(String title, String msg, MessengerType type) {
    AppMessenger.showSnackBar(context, title: title, message: msg, type: type);
  }

  // Validation method for all fields
  void _validateForm() {
    if (widget.startDate == null) {
      _showMessage(
        AppLocalizations.of(context)!.validation,
        AppLocalizations.of(context)!.pleaseSelectStartDate,
        MessengerType.info,
      );
    } else if (widget.endDate == null) {
      _showMessage(
        AppLocalizations.of(context)!.validation,
        AppLocalizations.of(context)!.pleaseSelectEndDate,
        MessengerType.info,
      );
    } else if (_startTimeLocal == null) {
      _showMessage(
        AppLocalizations.of(context)!.validation,
        AppLocalizations.of(context)!.selectStartTime,
        MessengerType.info,
      );
    } else if (_endTimeLocal == null) {
      _showMessage(
        AppLocalizations.of(context)!.validation,
        AppLocalizations.of(context)!.selectEndTime,
        MessengerType.info,
      );
    } else {
      // Time Logic Validation
      final startMinutes = _startTimeLocal!.hour * 60 + _startTimeLocal!.minute;
      final endMinutes = _endTimeLocal!.hour * 60 + _endTimeLocal!.minute;

      if (endMinutes <= startMinutes) {
        _showMessage(
          AppLocalizations.of(context)!.validation,
          AppLocalizations.of(context)!.endTimeBeforeStartTime,
          MessengerType.error,
        );
        return;
      }

      if (endMinutes - startMinutes > 120) {
        _showMessage(
          AppLocalizations.of(context)!.validation,
          AppLocalizations.of(context)!.sessionTooLong,
          MessengerType.error,
        );
        return;
      }

      widget.onNext();
    }
  }

  void _showCustomDialog(
    BuildContext context,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 50),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.gotIt,
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  DateTime _toUtcDateTime(TimeOfDay time) {
    // Use StartDate if selected, otherwise fallback to Now.
    // This ensures we respect the DST offset of the actual course date,
    // not just the current date.
    final date = widget.startDate ?? DateTime.now();
    final localDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return localDateTime.toUtc();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final DateTime twoWeeksFromNow = DateTime.now().add(
      const Duration(days: 14),
    );

    // Calculate the maximum end date (3 months from the start date)
    final DateTime threeMonthsFromStartDate = widget.startDate != null
        ? widget.startDate!.add(const Duration(days: 90))
        : twoWeeksFromNow.add(const Duration(days: 90));

    // Calculate course duration
    int durationInDays = 0;
    if (widget.startDate != null && widget.endDate != null) {
      durationInDays = widget.endDate!.difference(widget.startDate!).inDays + 1;
    }

    final String courseDurationText =
        (widget.startDate != null && widget.endDate != null)
        ? l10n.courseDurationDays(durationInDays)
        : l10n.courseDuration;

    // --- Time Validation Logic ---
    final startMinutes = _startTimeLocal != null
        ? _startTimeLocal!.hour * 60 + _startTimeLocal!.minute
        : null;
    final endMinutes = _endTimeLocal != null
        ? _endTimeLocal!.hour * 60 + _endTimeLocal!.minute
        : null;

    bool isTimeValid = true;
    String? timeErrorMessage;

    if (startMinutes != null && endMinutes != null) {
      if (endMinutes <= startMinutes) {
        isTimeValid = false;
        timeErrorMessage = l10n.endTimeBeforeStartTime;
      } else if (endMinutes - startMinutes > 120) {
        isTimeValid = false;
        timeErrorMessage = l10n.sessionTooLong;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Start Date
                    _buildStepHeader(l10n.selectAStartDate),
                    const SizedBox(height: 12),
                    _buildDateTile(
                      icon: Icons.calendar_today,
                      label: widget.startDate != null
                          ? DateFormat.yMMMd(
                              Localizations.localeOf(context).toString(),
                            ).format(widget.startDate!.toLocal())
                          : l10n.selectAStartDate,
                      onTap: () => _pickStartDate(twoWeeksFromNow),
                    ),
                    const SizedBox(height: 24),

                    // End Date
                    _buildStepHeader(l10n.selectAnEndDate),
                    const SizedBox(height: 12),
                    _buildDateTile(
                      icon: Icons.calendar_today,
                      label: widget.endDate != null
                          ? DateFormat.yMMMd(
                              Localizations.localeOf(context).toString(),
                            ).format(widget.endDate!.toLocal())
                          : l10n.selectAnEndDate,
                      onTap: () => _pickEndDate(
                        threeMonthsFromStartDate,
                        twoWeeksFromNow,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Duration Display
                    if (widget.startDate != null && widget.endDate != null) ...[
                      _buildDateTile(
                        icon: Icons.date_range,
                        label: courseDurationText,
                        isReadOnly: true,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Short Course Warning
                    if (widget.startDate != null && widget.endDate != null && durationInDays < 30)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.accentGold, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.shortCourseWarning,
                                  style: const TextStyle(color: AppColors.textColor, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Time Selection
                    _buildStepHeader(
                      "${l10n.selectStartTime} & ${l10n.selectEndTime}",
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerTile(
                            label: l10n.selectStartTime,
                            selectedTime: _startTimeLocal,
                            onTap: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePickerTile(
                            label: l10n.selectEndTime,
                            selectedTime: _endTimeLocal,
                            onTap: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    if (_startTimeLocal != null || _endTimeLocal != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, left: 4.0),
                        child: Text(
                          '(${l10n.yourTime})',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Panel
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  timeErrorMessage,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => widget.onBack(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              l10n.back,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isTimeValid ? _validateForm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTimeValid
                                  ? AppColors.textColor
                                  : Colors.white.withOpacity(0.1),
                              foregroundColor: isTimeValid
                                  ? Colors.black
                                  : Colors.white24,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: isTimeValid ? 4 : 0,
                            ),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              l10n.next,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildStepHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDateTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isReadOnly = false,
  }) {
    return GestureDetector(
      onTap: isReadOnly ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (!isReadOnly)
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white38,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay? selectedTime,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppColors.textColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedTime?.format(context) ?? "--:--",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Logic Methods ---

  void _pickStartDate(DateTime firstDate) async {
    _showCustomDialog(
      context,
      AppLocalizations.of(context)!.startDateNote,
      () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: widget.startDate ?? firstDate,
          firstDate: firstDate,
          lastDate: DateTime(2101),
          builder: _datePickerTheme,
        );
        if (picked != null) {
          widget.onStartDateSelected(picked);
          if (widget.endDate != null && widget.endDate!.isBefore(picked)) {
            widget.onEndDateSelected(null);
          }
        }
      },
    );
  }

  void _pickEndDate(DateTime lastDate, DateTime firstDate) async {
    _showCustomDialog(
      context,
      AppLocalizations.of(context)!.endDateNote,
      () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: widget.endDate ?? (widget.startDate ?? firstDate),
          firstDate: widget.startDate ?? firstDate,
          lastDate: lastDate,
          builder: _datePickerTheme,
        );
        if (picked != null) {
          widget.onEndDateSelected(picked);
        }
      },
    );
  }

  void _pickTime(bool isStart) async {
    _showCustomDialog(
      context,
      AppLocalizations.of(context)!.timeZoneNote,
      () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime:
              (isStart ? _startTimeLocal : _endTimeLocal) ?? TimeOfDay.now(),
          builder: _datePickerTheme,
        );

        if (picked != null) {
          // Check for AM selection (except 12 AM which is midnight, usually fine, but let's warn for any AM except maybe very early morning?
          // Actually, user said "AM". 12:00 PM is Noon.
          // Logic: if period is AM, warn.

          TimeOfDay finalTime = picked;

          // WARN IF AM (00:00 to 11:59)
          // picked.period == DayPeriod.am covers 00:00 to 11:59.
          if (picked.period == DayPeriod.am) {
            bool? switchToPm = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return Dialog(
                  backgroundColor: AppColors.primary, // Dark elegant background
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wb_sunny_rounded,
                            color: Colors.orangeAccent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          AppLocalizations.of(context)!.morningTimeSelected,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Content
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.morningSelectionWarning(picked.format(context)),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.didYouMeanPm,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false), // Keep AM
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(
                                        0.15,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.keepAm,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pop(true), // Switch to PM
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.switchToPm,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            if (switchToPm == true) {
              // Convert to PM
              // If it was 10:00 AM (hour 10), make it 22:00 (10 PM).
              // If it was 00:00 AM (midnight), make it 12:00 (Noon).
              finalTime = TimeOfDay(
                hour: (picked.hour + 12) % 24,
                minute: picked.minute,
              );
            }
          }

          setState(() {
            if (isStart) {
              _startTimeLocal = finalTime;
            } else {
              _endTimeLocal = finalTime;
            }
          });

          final utcDateTime = _toUtcDateTime(finalTime);
          if (isStart) {
            widget.onStartTimeSelected(utcDateTime);
          } else {
            widget.onEndTimeSelected(utcDateTime);
          }
        }
      },
    );
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.textColor,
          onPrimary: Colors.black,
          surface: AppColors.primary,
          onSurface: Colors.white,
        ),
      ),
      child: child!,
    );
  }
}
