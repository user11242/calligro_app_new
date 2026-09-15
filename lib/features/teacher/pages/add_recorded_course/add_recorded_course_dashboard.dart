import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import '../add_course/courseFirebaseServices.dart';
import 'steps/recorded_info_step.dart';
import 'steps/recorded_upload_curriculum_step.dart';
import 'recorded_course_onboarding_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

class AddRecordedCourseDashboardPage extends StatefulWidget {
  final String? draftCourseId;
  final Map<String, dynamic>? initialData;

  const AddRecordedCourseDashboardPage({
    super.key,
    this.draftCourseId,
    this.initialData,
  });

  @override
  State<AddRecordedCourseDashboardPage> createState() => _AddRecordedCourseDashboardPageState();
}

class _AddRecordedCourseDashboardPageState extends State<AddRecordedCourseDashboardPage> {
  // --- Navigation State ---
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // --- Services ---
  final CourseFirebaseService _firebaseService = CourseFirebaseService();

  // --- Draft State ---
  String? _courseId;
  bool _isSaving = false;

  // --- Course Data ---
  final _courseNameController = TextEditingController();
  final _courseDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory = 'Beginner';
  String? _selectedWritingType;
  String? _selectedCalligraphyStyle;

  // Teacher Identity
  String teacherId = '';
  String teacherName = '';
  String teacherProfilePic = '';

  // Curriculum Data
  PlatformFile? _introVideo;
  PlatformFile? _explainerVideo;
  List<CurriculumPartData> _curriculumParts = [];

  @override
  void initState() {
    super.initState();
    _courseId = widget.draftCourseId;
    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    }
    _fetchTeacherDetails();
  }

  void _loadInitialData(Map<String, dynamic> data) {
    _courseNameController.text = data['courseName'] ?? '';
    _courseDescriptionController.text = data['courseDescription'] ?? '';
    _priceController.text = (data['price'] ?? '').toString();
    _selectedCategory = data['selectedCategory'] ?? 'Beginner';
    _selectedWritingType = data['writingType'];
    _selectedCalligraphyStyle = data['calligraphyStyle'];
  }

  Future<void> _fetchTeacherDetails() async {
    try {
      var teacherDetails = await _firebaseService.fetchTeacherDetails();
      setState(() {
        teacherId = teacherDetails['teacherId']!;
        teacherName = teacherDetails['teacherName']!;
        teacherProfilePic = teacherDetails['teacherProfilePic'] ?? '';
      });
    } catch (e) {
      _showMessage(AppLocalizations.of(context)!.error, e.toString(), MessengerType.error);
    }
  }

  void _showMessage(String title, String msg, MessengerType type) {
    if (!mounted) return;
    AppMessenger.showSnackBar(context, title: title, message: msg, type: type);
  }

  void _goToNextStep() {
    if (_currentStep == 0) {
      // Push full-screen onboarding, then jump to Upload step
      setState(() => _currentStep = 1);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RecordedCourseOnboardingPage(),
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _currentStep = 2);
          _pageController.animateToPage(
            1, // second page in PageView = Upload
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _goToPreviousStep() {
    if (_currentStep == 2) {
      // Go back from Upload to Info (skip onboarding on back)
      setState(() => _currentStep = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Map<String, dynamic> _collectCourseData({String status = 'draft'}) {
    return {
      'type': 'recorded',
      'status': status,
      'courseName': _courseNameController.text.trim(),
      'courseDescription': _courseDescriptionController.text.trim(),
      'writingType': _selectedWritingType,
      'calligraphyStyle': _selectedCalligraphyStyle,
      'selectedCategory': _selectedCategory,
      'levelColor': _selectedCategory,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherProfilePic': teacherProfilePic,
      'enrolledStudents': [],
      'enrolledCount': 0,
      'introVideoPath': _introVideo?.path ?? '',
      'explainerVideoPath': _explainerVideo?.path ?? '',
      'curriculumParts': _curriculumParts.map((part) => {
        'title': part.title,
        'videos': part.videos.map((v) => v.name).toList(),
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _saveAsDraft() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final data = _collectCourseData(status: 'draft');
      _courseId = await _firebaseService.saveDraftCourse(_courseId, data);
      _showMessage('Saved', 'Course saved as draft successfully.', MessengerType.success);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Error', 'Failed to save draft: $e', MessengerType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publishCourse(PlatformFile? intro, PlatformFile? explainer, List<CurriculumPartData> parts) async {
    if (_isSaving) return;
    if (_courseNameController.text.trim().isEmpty) {
      _showMessage('Error', 'Please provide a title before publishing.', MessengerType.error);
      return;
    }
    
    // Save the curriculum data to state before collecting
    setState(() {
      _introVideo = intro;
      _explainerVideo = explainer;
      _curriculumParts = parts;
      _isSaving = true;
    });
    
    try {
      final data = _collectCourseData(status: 'published');
      await _firebaseService.saveDraftCourse(_courseId, data);
      _showMessage('Success', 'Course published successfully!', MessengerType.success);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Error', 'Failed to publish course: $e', MessengerType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildStepIndicator(int stepNumber, String label) {
    bool isActive = _currentStep == stepNumber;
    bool isCompleted = _currentStep > stepNumber;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.textColor
                  : isCompleted
                  ? Colors.green
                  : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      (stepNumber + 1).toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.textColor : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorLine(int stepNumber) {
    bool isCompleted = _currentStep > stepNumber;
    return Container(
      height: 2,
      color: isCompleted ? Colors.green : Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalLinePadding = (screenWidth / 3) / 2;

    final List<Widget> pages = [
      RecordedInfoStep(
        courseNameController: _courseNameController,
        courseDescriptionController: _courseDescriptionController,
        priceController: _priceController,
        selectedCategory: _selectedCategory,
        selectedWritingType: _selectedWritingType,
        selectedCalligraphyStyle: _selectedCalligraphyStyle,
        onCategoryChanged: (val) => setState(() => _selectedCategory = val),
        onWritingTypeChanged: (type, style) => setState(() {
          _selectedWritingType = type;
          _selectedCalligraphyStyle = style;
        }),
        onNext: _goToNextStep,
      ),
      RecordedUploadCurriculumStep(
        onPublish: _publishCourse,
        onBack: _goToPreviousStep,
        isSaving: _isSaving,
      ),
    ];

    return WillPopScope(
      onWillPop: () async {
        _goToPreviousStep();
        return false; // Prevent default pop
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text(
            'New Recorded Course',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          foregroundColor: AppColors.secondary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToPreviousStep,
          ),
          actions: [
            if (_currentStep < 2)
              TextButton.icon(
                onPressed: _isSaving ? null : _saveAsDraft,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 16, height: 16, 
                        child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2)
                      )
                    : const Icon(Icons.save_outlined, color: AppColors.accentGold, size: 20),
                label: const Text(
                  'Save Draft',
                  style: TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Stack(
                children: [
                  Positioned(
                    top: 17.0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalLinePadding + 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildConnectorLine(0)),
                          Expanded(child: _buildConnectorLine(1)),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStepIndicator(0, 'Info'),
                      _buildStepIndicator(1, 'Format'),
                      _buildStepIndicator(2, 'Upload'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
