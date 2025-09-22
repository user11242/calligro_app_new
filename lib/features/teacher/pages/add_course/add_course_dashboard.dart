import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';  // Import the AppColors
import 'course_information_step.dart';
import 'course_schedule_step.dart';
import 'choose_course_day_step.dart';
import 'pricing_step.dart';
import 'generate_google_meet_link_step.dart';
import 'courseFirebaseServices.dart';  // Import the Firebase Service
import 'package:intl/intl.dart';

class AddCourseDashboardPage extends StatefulWidget {
  const AddCourseDashboardPage({super.key});

  @override
  _AddCourseDashboardPageState createState() => _AddCourseDashboardPageState();
}

class _AddCourseDashboardPageState extends State<AddCourseDashboardPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  final _courseNameController = TextEditingController();
  final _courseDescriptionController = TextEditingController();
  final _numberOfStudentsController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory = 'Beginner';
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _selectedTime;
  List<String> _selectedDays = [];
  String teacherId = '';
  String teacherName = '';
  String googleMeetLink = '';

  final CourseFirebaseService _firebaseService = CourseFirebaseService();

  @override
  void initState() {
    super.initState();
    _fetchTeacherDetails();
  }

  Future<void> _fetchTeacherDetails() async {
    try {
      var teacherDetails = await _firebaseService.fetchTeacherDetails();
      setState(() {
        teacherId = teacherDetails['teacherId']!;
        teacherName = teacherDetails['teacherName']!;
      });
    } catch (e) {
      _showMessage('Error fetching teacher details: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goToNextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveCourse();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GoogleMeetPage(
            courseName: _courseNameController.text,
            teacherId: teacherId,
            teacherName: teacherName,
            courseType: _selectedCategory ?? 'Beginner',
            maxStudents: _parseMaxStudents(),
            courseDescription: _courseDescriptionController.text,
            startDate: _startDate!,
            endDate: _endDate!,
            selectedTimeFormatted: _selectedTime != null ? DateFormat('HH:mm').format(_selectedTime!) : '',
            selectedDays: _selectedDays,
            price: double.tryParse(_priceController.text) ?? 0.0,
            onFinish: () {
              Navigator.pushReplacementNamed(context, '/teacherDashboard');
            },
            onBack: () {
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
  }

  Future<void> _saveCourse() async {
    try {
      Map<String, dynamic> courseData = {
        'courseName': _courseNameController.text,
        'courseDescription': _courseDescriptionController.text,
        'numberOfStudents': _parseMaxStudents(), // Use the safe parse function
        'selectedCategory': _selectedCategory,
        'startDate': _startDate,
        'endDate': _endDate,
        'selectedTime': _selectedTime,
        'selectedDays': _selectedDays,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'enrolledStudents': 0,
        'price': double.tryParse(_priceController.text) ?? 0.0, // Use safe parsing
        'googleMeetLink': googleMeetLink,
        'maxStudents': _parseMaxStudents(), // Use the safe parse function
      };

      await _firebaseService.saveCourse(courseData);
      _showMessage('Course added successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Error adding course: $e');
    }
  }

  // Corrected function to safely parse the number of students.
  // It now uses the correct controller: _numberOfStudentsController
  int _parseMaxStudents() {
    final parsedValue = int.tryParse(_numberOfStudentsController.text);
    if (parsedValue != null && parsedValue > 0) {
      return parsedValue;
    }
    return 30; // Default value if parsing fails or value is not positive
  }

  Widget _buildStepIndicator(int stepNumber, String label) {
    bool isActive = _currentStep == stepNumber;
    bool isCompleted = _currentStep > stepNumber;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isActive
                ? AppColors.textColor
                : isCompleted
                  ? Colors.green
                  : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      (stepNumber + 1).toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.textColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          "Add New Course",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: AppColors.secondary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(0, "Info"),
                _buildStepIndicator(1, "Schedule"),
                _buildStepIndicator(2, "Days"),
                _buildStepIndicator(3, "Price"),
                _buildStepIndicator(4, "Link"),
              ],
            ),
          ),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                CourseInformationPage(
                  courseNameController: _courseNameController,
                  courseDescriptionController: _courseDescriptionController,
                  numberOfStudentsController: _numberOfStudentsController,
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (newCategory) {
                    setState(() {
                      _selectedCategory = newCategory;
                    });
                  },
                  onNext: _goToNextStep,
                ),
                CourseSchedulePage(
                  startDate: _startDate,
                  endDate: _endDate,
                  selectedTime: _selectedTime,
                  onStartDateSelected: (date) => setState(() => _startDate = date),
                  onEndDateSelected: (date) => setState(() => _endDate = date),
                  onTimeSelected: (time) => setState(() => _selectedTime = time),
                  onNext: _goToNextStep,
                  onBack: () {
                    setState(() {
                      _currentStep--;
                    });
                    _pageController.animateToPage(
                      _currentStep,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                CourseDaysPage(
                  selectedDays: _selectedDays,
                  onDaySelected: (day) {
                    setState(() {
                      if (_selectedDays.contains(day)) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  onNext: _goToNextStep,
                  onBack: () {
                    setState(() {
                      _currentStep--;
                    });
                    _pageController.animateToPage(
                      _currentStep,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                CoursePricePage(
                  priceController: _priceController,
                  onNext: _goToNextStep,
                  onBack: () {
                    setState(() {
                      _currentStep--;
                    });
                    _pageController.animateToPage(
                      _currentStep,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                GoogleMeetPage(
                  courseName: _courseNameController.text,
                  teacherId: teacherId,
                  teacherName: teacherName,
                  courseType: _selectedCategory ?? 'Beginner',
                  maxStudents: _parseMaxStudents(),
                  courseDescription: _courseDescriptionController.text,
                  startDate: _startDate ?? DateTime.now(),
                  endDate: _endDate ?? DateTime.now(),
                  selectedTimeFormatted: _selectedTime != null ? DateFormat('HH:mm').format(_selectedTime!) : '',
                  selectedDays: _selectedDays,
                  price: double.tryParse(_priceController.text) ?? 0.0,
                  onFinish: () {
                    Navigator.pushReplacementNamed(context, '/teacherDashboard');
                  },
                  onBack: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}