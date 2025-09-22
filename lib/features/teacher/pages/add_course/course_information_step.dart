import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback
import 'package:calligro_app/features/auth/widgets/auth_text_field.dart';
import 'package:calligro_app/core/theme/colors.dart';

class CourseInformationPage extends StatefulWidget {
  final TextEditingController courseNameController;
  final TextEditingController courseDescriptionController;
  final TextEditingController numberOfStudentsController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final Function onNext;

  const CourseInformationPage({
    Key? key,
    required this.courseNameController,
    required this.courseDescriptionController,
    required this.numberOfStudentsController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onNext,
  }) : super(key: key);

  @override
  _CourseInformationPageState createState() => _CourseInformationPageState();
}

class _CourseInformationPageState extends State<CourseInformationPage> {
  // Use a nullable int to represent the selected number of students
  int _numberOfStudents = 1;

  @override
  void initState() {
    super.initState();
    // Removed the line that initializes the controller.
    // The hint text will now be visible by default.
  }

  // Method to show messages using SnackBar
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Validation method
  void _validateForm() {
    if (widget.courseNameController.text.isEmpty) {
      _showMessage('Course name is required');
      return;
    }
    if (widget.courseDescriptionController.text.isEmpty) {
      _showMessage('Course description is required');
      return;
    }
    if (widget.selectedCategory == null) {
      _showMessage('Please select a category');
      return;
    }
    // Added validation for the number of students
    if (widget.numberOfStudentsController.text.isEmpty) {
      _showMessage('Maximum number of students is required');
      return;
    }

    // If all validations pass, proceed to the next step
    widget.onNext();
  }

  // Method to show the student count picker dialog
  void _showStudentCountPicker() {
    int tempNumberOfStudents = _numberOfStudents; // Use a temporary variable for the dialog's state

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          elevation: 10, // Added a shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: StatefulBuilder( // Use StatefulBuilder to update the dialog content
            builder: (context, setState) {
              return SizedBox(
                height: 250,
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const Text(
                      'Select Number of Students',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 50,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            tempNumberOfStudents = index + 1;
                          });
                          HapticFeedback.heavyImpact(); // Haptic feedback
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            final number = index + 1;
                            final isSelected = number == tempNumberOfStudents;
                            return Center(
                              child: Text(
                                '$number',
                                style: TextStyle(
                                  fontSize: isSelected ? 32 : 24,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                                ),
                              ),
                            );
                          },
                          childCount: 50,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white), // Changed text color to white
              ),
              onPressed: () {
                setState(() {
                  _numberOfStudents = tempNumberOfStudents;
                  widget.numberOfStudentsController.text = _numberOfStudents.toString();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthTextField(
                controller: widget.courseNameController,
                hint: 'Enter Course Name',
                icon: Icons.book,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: widget.courseDescriptionController,
                hint: 'Enter Course Description',
                icon: Icons.description,
                obscure: false,
                keyboardType: TextInputType.multiline,
                showToggle: false,
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(bottom: 15),
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
                child: DropdownButtonFormField<String>(
                  value: widget.selectedCategory,
                  onChanged: widget.onCategoryChanged,
                  isExpanded: true, // This ensures the dropdown takes full width
                  items: ['Beginner', 'Intermediate', 'Advanced']
                      .map((category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    hintText: 'Choose Category',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                    prefixIcon: Icon(Icons.category, color: AppColors.textColor),
                    filled: true,
                    fillColor: Colors.transparent, // Changed to transparent as parent Container handles color
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.textColor, width: 2),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppColors.primary, // Updated dropdown background color to be solid
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: widget.numberOfStudentsController,
                hint: 'Maximum number of students to enroll',
                icon: Icons.group,
                readOnly: true,
                onTap: _showStudentCountPicker,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _validateForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text("Next", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}