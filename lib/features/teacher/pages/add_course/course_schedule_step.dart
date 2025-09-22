import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CourseSchedulePage extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? selectedTime;
  final Function(DateTime?) onStartDateSelected;
  final Function(DateTime?) onEndDateSelected;
  final Function(DateTime?) onTimeSelected;
  final Function onNext;
  final Function onBack;

  const CourseSchedulePage({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.selectedTime,
    required this.onStartDateSelected,
    required this.onEndDateSelected,
    required this.onTimeSelected,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  _CourseSchedulePageState createState() => _CourseSchedulePageState();
}

class _CourseSchedulePageState extends State<CourseSchedulePage> {
  bool _isLoadingTimeZone = true;
  String _timeZoneName = 'Unknown';
  tz.Location? _userTimeZone;
  // This state variable stores the locally selected time for UI display
  TimeOfDay? _selectedTimeLocal;

  @override
  void initState() {
    super.initState();
    _initializeTimeZone();
    // Initialize the local time state from the widget's selectedTime
    if (widget.selectedTime != null) {
      _selectedTimeLocal = TimeOfDay.fromDateTime(widget.selectedTime!.toLocal());
    }
  }

  Future<void> _initializeTimeZone() async {
    try {
      tz.initializeTimeZones();
      // Request permission
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingTimeZone = false;
        });
        _showCustomDialog(context, "Location permission is required to handle time zones accurately.", () {});
        return;
      }

      // Get current position to ensure location service is enabled
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      
      // Get the local time zone from the timezone package
      final location = tz.local;
      
      setState(() {
        _userTimeZone = location;
        _timeZoneName = location.toString();
        _isLoadingTimeZone = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTimeZone = false;
        _timeZoneName = 'Error';
      });
      _showCustomDialog(context, "Could not determine your time zone.", () {});
    }
  }

  // Method to show messages using SnackBar
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Validation method for all fields
  void _validateForm() {
    if (widget.startDate == null) {
      _showMessage('Please select a start date.');
      return;
    }
    if (widget.endDate == null) {
      _showMessage('Please select an end date.');
      return;
    }
    if (widget.selectedTime == null) {
      _showMessage('Please select a time.');
      return;
    }

    // If all validations pass, proceed to the next step
    widget.onNext();
  }

  void _showCustomDialog(BuildContext context, String message, VoidCallback onConfirm) {
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
                Icons.info_outline,
                color: Colors.white,
                size: 50,
              ),
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
              child: const Text(
                'Got It',
                style: TextStyle(color: Colors.white),
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

  // Helper function to format the time for display
  String _formatTime(DateTime? time) {
    if (time == null) {
      return 'Select a Time';
    }
    final TimeOfDay timeOfDay = TimeOfDay.fromDateTime(time);
    return timeOfDay.format(context);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the minimum start date (2 weeks from now)
    final DateTime twoWeeksFromNow = DateTime.now().add(const Duration(days: 14));

    // Calculate the maximum end date (3 months from the start date)
    final DateTime threeMonthsFromStartDate = widget.startDate != null
        ? widget.startDate!.add(const Duration(days: 90))
        : twoWeeksFromNow.add(const Duration(days: 90));

    // Calculate course duration
    final String courseDurationText = (widget.startDate != null && widget.endDate != null)
        ? 'Course Duration: ${widget.endDate!.difference(widget.startDate!).inDays + 1} days'
        : 'Course Duration';

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start Date with Custom Design
            GestureDetector(
              onTap: () async {
                _showCustomDialog(
                  context,
                  "Note: Due to making enough time for students to enroll, you can't choose a start date before two weeks from now.",
                  () async {
                    final DateTime? selectedStartDate = await showDatePicker(
                      context: context,
                      initialDate: widget.startDate ?? twoWeeksFromNow,
                      firstDate: twoWeeksFromNow,
                      lastDate: DateTime(2101),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.textColor,
                              onPrimary: Colors.white,
                              surface: AppColors.primary,
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: AppColors.primary,
                            textTheme: const TextTheme(
                              bodyLarge: TextStyle(color: Colors.white),
                              bodyMedium: TextStyle(color: Colors.white),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selectedStartDate != null) {
                      widget.onStartDateSelected(selectedStartDate);
                      if (widget.endDate != null && widget.endDate!.isBefore(selectedStartDate)) {
                        widget.onEndDateSelected(null);
                      }
                    }
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.startDate?.toLocal().toString().split(' ')[0] ?? 'Select a Start Date',
                        style: const TextStyle(color: Colors.white, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End Date with Custom Design
            GestureDetector(
              onTap: () async {
                _showCustomDialog(
                  context,
                  "Note: The course can't be longer than 90 days.",
                  () async {
                    final DateTime? selectedEndDate = await showDatePicker(
                      context: context,
                      initialDate: widget.endDate ?? (widget.startDate ?? twoWeeksFromNow),
                      firstDate: widget.startDate ?? twoWeeksFromNow,
                      lastDate: threeMonthsFromStartDate,
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.textColor,
                              onPrimary: Colors.white,
                              surface: AppColors.primary,
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: AppColors.primary,
                            textTheme: const TextTheme(
                              bodyLarge: TextStyle(color: Colors.white),
                              bodyMedium: TextStyle(color: Colors.white),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selectedEndDate != null) {
                      widget.onEndDateSelected(selectedEndDate);
                    }
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.endDate?.toLocal().toString().split(' ')[0] ?? 'Select an End Date',
                        style: const TextStyle(color: Colors.white, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Course Duration
            if (widget.startDate != null && widget.endDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: AppColors.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        courseDurationText,
                        style: const TextStyle(color: Colors.white, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.startDate != null && widget.endDate != null)
              const SizedBox(height: 16),

            // Time with Custom Design
            GestureDetector(
              onTap: () async {
                if (_isLoadingTimeZone) {
                  // Show a loading indicator if the timezone is still being determined
                  _showCustomDialog(context, 'Please wait while we get your location for time zone handling...', () {});
                  return;
                }
                
                _showCustomDialog(
                  context,
                  "Note: The time you choose will be displayed in your local time zone, but it will be adjusted to the local time zone of each student's country.",
                  () async {
                    final TimeOfDay? selectedTimePicker = await showTimePicker(
                      context: context,
                      initialTime: _selectedTimeLocal ?? TimeOfDay.now(),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.textColor,
                              onPrimary: Colors.white,
                              surface: AppColors.primary,
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: AppColors.primary,
                            textTheme: const TextTheme(
                              bodyLarge: TextStyle(color: Colors.white),
                              bodyMedium: TextStyle(color: Colors.white),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selectedTimePicker != null) {
                      // Update the local time state for display
                      setState(() {
                        _selectedTimeLocal = selectedTimePicker;
                      });
                      
                      // Combine the selected time with a mock date and convert to UTC
                      final now = DateTime.now();
                      final selectedDateTimeLocal = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        selectedTimePicker.hour,
                        selectedTimePicker.minute,
                      );
                      final localLocation = _userTimeZone ?? tz.local;
                      final zonedTime = tz.TZDateTime.from(selectedDateTimeLocal, localLocation);
                      widget.onTimeSelected(zonedTime.toUtc());

                      // This debug print will show the UTC time in the console.
                      // Please check the "Debug Console" in your IDE.
                      print('Selected Time (UTC): ${zonedTime.toUtc()}');
                    }
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedTimeLocal != null ? '${_selectedTimeLocal!.format(context)} (Your Time)' : 'Select a Time',
                        style: const TextStyle(color: Colors.white, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Back and Next buttons in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onBack(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Back"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _validateForm, // Call the validation method here
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text("Next"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  }
}
