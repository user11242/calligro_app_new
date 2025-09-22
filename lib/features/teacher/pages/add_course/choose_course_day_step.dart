import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter/services.dart';

class CourseDaysPage extends StatelessWidget {
  final List<String> selectedDays;
  final Function(String) onDaySelected;
  final Function onNext;
  final Function onBack;

  const CourseDaysPage({
    Key? key,
    required this.selectedDays,
    required this.onDaySelected,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

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
              const Text(
                "You can't choose more than two days.",
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Got It',
                style: TextStyle(color: Colors.white),
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

  // Method to show a snack bar message
  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Validation method to check if at least one day is selected
  void _validateAndProceed(BuildContext context) {
    if (selectedDays.isEmpty) {
      _showMessage(context, 'Please select at least one day.');
    } else {
      onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Day selection buttons
              ...daysOfWeek.map((day) {
                final isSelected = selectedDays.contains(day);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (!isSelected && selectedDays.length >= 2) {
                        _showLimitReachedDialog(context);
                      } else {
                        onDaySelected(day);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.textColor.withOpacity(0.2)
                            : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isSelected ? AppColors.textColor : Colors.transparent,
                          width: isSelected ? 2 : 0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: isSelected ? AppColors.textColor : Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 16),
                          Text(
                            day,
                            style: TextStyle(
                              color: isSelected ? AppColors.textColor : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_circle, color: AppColors.textColor),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onBack(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text("Back", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _validateAndProceed(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text("Next", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}