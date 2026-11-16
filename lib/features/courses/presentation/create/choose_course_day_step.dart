import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter/services.dart';
import '../../../../core/message/app_messenger.dart';

class CourseDaysPage extends StatefulWidget {
  final List<String> selectedDays;
  final String startDay;
  final String endDay; // Added: the day the course ends
  final Function(String) onDaySelected;
  final Function onNext;
  final Function onBack;

  const CourseDaysPage({
    super.key,
    required this.selectedDays,
    required this.startDay,
    required this.endDay, // Added to constructor
    required this.onDaySelected,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<CourseDaysPage> createState() => _CourseDaysPageState();
}

class _CourseDaysPageState extends State<CourseDaysPage> {
  // FAST FIX: Track if user has manually interacted with the end day to hide the note permanently
  bool _hasDismissedSuggestion = false;

  String _getLocalizedDay(BuildContext context, String day) {
    final l10n = AppLocalizations.of(context)!;
    switch (day) {
      case 'Sunday': return l10n.sunday;
      case 'Monday': return l10n.monday;
      case 'Tuesday': return l10n.tuesday;
      case 'Wednesday': return l10n.wednesday;
      case 'Thursday': return l10n.thursday;
      case 'Friday': return l10n.friday;
      case 'Saturday': return l10n.saturday;
      default: return day;
    }
  }

  @override
  void initState() {
    super.initState();
    // LOGICAL FIX: Automatically select both days initially, but ONLY if none are selected yet.
    // This preserves manual selections/deselections when returning to this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedDays.isEmpty) {
        if (widget.startDay.isNotEmpty) {
          widget.onDaySelected(widget.startDay);
        }
        if (widget.endDay.isNotEmpty && widget.endDay != widget.startDay) {
          widget.onDaySelected(widget.endDay);
        }
      }
    });
  }

  void _showLimitReachedDialog(BuildContext context) {
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
              const Icon(
                Icons.warning_amber,
                color: Colors.redAccent,
                size: 50,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.cantChooseMoreThanTwoDays,
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
              },
            ),
          ],
        );
      },
    );
  }

  // Validation method to check if at least one day is selected
  void _validateAndProceed(BuildContext context) {
    if (widget.selectedDays.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.required,
        message: AppLocalizations.of(context)!.pleaseSelectAtLeastOneDay,
        type: MessengerType.info,
      );
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Suggestion Note - Only show if end day is selected AND matches strict logic AND not dismissed
              if (widget.selectedDays.contains(widget.endDay) && 
                  widget.startDay != widget.endDay && 
                  !_hasDismissedSuggestion)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.accentGold, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.endDaySuggested(_getLocalizedDay(context, widget.endDay)),
                          style: const TextStyle(color: AppColors.textColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Day selection buttons
              ...daysOfWeek.map((day) {
                final isSelected = widget.selectedDays.contains(day);
                // LOGIC CHANGE: Only Start Day is mandatory now. End Day is optional.
                final isMandatory = day == widget.startDay; 

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();

                      // LOGICAL FIX: Prevent deselecting the mandatory start day
                      if (isMandatory) {
                        AppMessenger.showSnackBar(
                          context,
                          title: AppLocalizations.of(context)!.mandatoryDay,
                          message: AppLocalizations.of(context)!.mandatoryDayConflict(_getLocalizedDay(context, day)),
                          type: MessengerType.info,
                        );
                        return;
                      }

                      // LOGIC: If user deselects the suggestion (endDay), hide the note permanently
                      if (day == widget.endDay && isSelected) {
                        setState(() {
                          _hasDismissedSuggestion = true;
                        });
                      }

                      if (!isSelected && widget.selectedDays.length >= 2) {
                        _showLimitReachedDialog(context);
                      } else {
                        widget.onDaySelected(day);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        // Use accentGold with visible opacity for background
                        color: isSelected
                            ? AppColors.accentGold.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          // Use accentGold for border
                          color: isSelected
                              ? AppColors.accentGold
                              : Colors.transparent,
                          width: isSelected ? 1.5 : 0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            // Optional: Lock icon for mandatory day
                            isMandatory ? Icons.lock : Icons.calendar_today,
                            // Use accentGold for icon
                            color: isSelected
                                ? AppColors.accentGold
                                : Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _getLocalizedDay(context, day),
                            style: TextStyle(
                              // Use accentGold for text
                              color: isSelected
                                  ? AppColors.accentGold
                                  : Colors.white, // White for unselected
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.accentGold,
                            ),
                          if (!isSelected)
                             Icon(
                              Icons.circle_outlined,
                              color: Colors.white.withOpacity(0.3),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Navigation buttons
              const SizedBox(height: 24),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => widget.onBack(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(AppLocalizations.of(context)!.back),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _validateAndProceed(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textColor,
                            foregroundColor:
                                Colors.black, // CONSISTENT BLACK TEXT
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            AppLocalizations.of(context)!.next,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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
