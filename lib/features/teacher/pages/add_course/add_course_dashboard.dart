import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:calligro_app/features/courses/application/course_creation.dart';
import 'package:calligro_app/features/courses/domain/course_draft.dart';
import 'package:calligro_app/features/courses/presentation/course_scope.dart';

// --- Import Steps ---
import 'course_information_step.dart';
import 'course_details_step.dart';
import 'course_schedule_step.dart';
import 'choose_course_day_step.dart';
import 'pricing_step.dart';

// --- Import Summary & Services ---
import 'course_summary_page.dart';
import '../../../../core/message/app_messenger.dart';
import '../settings/payout_settings_page.dart';

class AddCourseDashboardPage extends StatefulWidget {
  const AddCourseDashboardPage({super.key});

  @override
  _AddCourseDashboardPageState createState() => _AddCourseDashboardPageState();
}

class _AddCourseDashboardPageState extends State<AddCourseDashboardPage> {
  // --- Navigation State ---
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // --- Services (validation, payout check and the atomic write live in CourseCreation) ---
  CourseCreation? _creation;
  bool _saving = false;

  // --- Step 0: Information Data ---
  final _courseNameController = TextEditingController();
  final _courseDescriptionController = TextEditingController();
  final _numberOfStudentsController = TextEditingController();
  String? _selectedCategory = 'Beginner';
  String? _selectedAgeGroup;
  String? _selectedWritingType;
  String? _selectedCalligraphyStyle;

  // --- Step 1: Details Data ---
  List<Map<String, dynamic>> _requiredTools = [];
  List<String> _curriculumSteps = [];

  // --- Step 2, 3, 4: Schedule & Price Data ---
  final _priceController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _startTime;
  DateTime? _endTime;
  final List<String> _selectedDays = [];

  // Teacher Identity
  String teacherId = '';
  String teacherName = '';
  String teacherProfilePic = '';
  bool _hasCommissionRate = false;
  double _teacherEarningPercentage = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_creation == null) {
      _creation = CourseScope.of(context).creation;
      _fetchTeacherDetails();
    }
  }

  Future<void> _fetchTeacherDetails() async {
    try {
      final author = await _creation!.loadAuthor();
      if (author == null) throw Exception('User not logged in');
      if (!mounted) return;
      setState(() {
        teacherId = author.id;
        teacherName = author.name;
        teacherProfilePic = author.photoUrl;
        _hasCommissionRate = author.hasCommissionRate;
        _teacherEarningPercentage = author.earningPercentage;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(AppLocalizations.of(context)!.error, AppLocalizations.of(context)!.errorFetchingUserData(e.toString()), MessengerType.error);
    }
  }

  void _showMessage(String title, String msg, MessengerType type) {
    if (!mounted) return;
    AppMessenger.showSnackBar(context, title: title, message: msg, type: type);
  }

  String _assignCourseImage() => CourseDraft.bannerFor(_selectedWritingType, _selectedCalligraphyStyle);

  int _parseMaxStudents() => CourseDraft.parseMaxStudents(_numberOfStudentsController.text);

  CourseDraft _draft() => CourseDraft(
        courseName: _courseNameController.text,
        courseDescription: _courseDescriptionController.text,
        writingType: _selectedWritingType,
        calligraphyStyle: _selectedCalligraphyStyle,
        level: _selectedCategory ?? 'Beginner',
        ageCategory: _selectedAgeGroup,
        startDate: _startDate,
        endDate: _endDate,
        startTime: _startTime,
        endTime: _endTime,
        selectedDays: _selectedDays,
        requiredTools: _requiredTools,
        curriculumSteps: _curriculumSteps,
        price: double.tryParse(CourseUtils.normalizeNumerics(_priceController.text)) ?? 0.0,
        maxStudents: _parseMaxStudents(),
      );

  // --- Logic: Navigation & Handoff ---
  void _goToNextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- Logic: Save (one atomic write: course + private meeting settings) ---
  Future<void> _saveCourseToFirebase(Map<String, String> meetData) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final generatedName = CourseUtils.getLocalizedCourseName(context, {
      'writingType': _selectedWritingType,
      'calligraphyStyle': _selectedCalligraphyStyle,
      'selectedCategory': _selectedCategory,
    });
    _saving = true;
    final result = await _creation!.create(
      _draft(),
      generatedName: generatedName,
      meetLink: meetData['link'] ?? '',
    );
    _saving = false;
    if (!mounted) return;
    switch (result.outcome) {
      case CreateCourseOutcome.created:
        Navigator.pop(context, true);
      case CreateCourseOutcome.needsPayout:
        _showPayoutRequiredDialog(meetData);
      case CreateCourseOutcome.needsCommission:
        _showMessage(l10n.actionRequired, l10n.cannotProceedNoCommission, MessengerType.error);
      case CreateCourseOutcome.invalid:
        final datesProblem = result.problems.contains(DraftProblem.missingDates) ||
            result.problems.contains(DraftProblem.endBeforeStart);
        _showMessage(l10n.validation, datesProblem ? l10n.selectStartEndDates : l10n.error, MessengerType.info);
      case CreateCourseOutcome.notSignedIn:
        _showMessage(l10n.error, l10n.errorFetchingUserData('not signed in'), MessengerType.error);
      case CreateCourseOutcome.failed:
        _showMessage(l10n.error, '${l10n.error}: ${result.message}', MessengerType.error);
      case CreateCourseOutcome.busy:
        break;
    }
  }

  void _showPayoutRequiredDialog(Map<String, String> meetData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accentGold),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.payoutRequirementTitle,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.payoutRequirementMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PayoutSettingsPage(isFromWizard: true)),
              );

              // The teacher is re-read on save: if the details are still
              // missing, the dialog simply shows again.
              if (result == true && mounted) _saveCourseToFirebase(meetData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              AppLocalizations.of(context)!.setupNow,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Builders ---
  Widget _buildStepIndicator(int stepNumber, String label) {
    bool isActive = _currentStep == stepNumber;
    bool isCompleted = _currentStep > stepNumber;
    bool isSummaryStep = stepNumber == 5;

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
    final double horizontalLinePadding = (screenWidth / 6) / 2;

    final List<Widget> pages = [
      // Step 0: Info
      CourseInformationPage(
        courseNameController: _courseNameController,
        courseDescriptionController: _courseDescriptionController,
        numberOfStudentsController: _numberOfStudentsController,
        selectedCategory: _selectedCategory,
        selectedAgeGroup: _selectedAgeGroup,
        onCategoryChanged: (newCategory) =>
            setState(() => _selectedCategory = newCategory),
        onAgeGroupChanged: (newAgeGroup) =>
            setState(() => _selectedAgeGroup = newAgeGroup),
        onNext: (type, style) {
          setState(() {
            _selectedWritingType = type;
            _selectedCalligraphyStyle = style;
          });
          _goToNextStep();
        },
      ),

      // Step 1: Details (UPDATED)
      CourseDetailsStep(
        writingType: _selectedWritingType ?? 'Arabic Calligraphy',
        courseLevel: _selectedCategory ?? 'Beginner',
        requiredTools: _requiredTools,
        curriculumSteps: _curriculumSteps,
        onToolsChanged: (tools) => setState(() => _requiredTools = tools),
        onCurriculumChanged: (curriculum) =>
            setState(() => _curriculumSteps = curriculum),
        onNext: _goToNextStep,
        onBack: () {
          setState(() => _currentStep--);
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),

      // Step 2: Schedule
      CourseSchedulePage(
        startDate: _startDate,
        endDate: _endDate,
        startTime: _startTime,
        endTime: _endTime,
        onStartDateSelected: (date) {
          setState(() {
            _startDate = date;
            _selectedDays.clear(); // Reset days when date changes
          });
        },
        onEndDateSelected: (date) {
          setState(() {
            _endDate = date;
            _selectedDays.clear(); // Reset days when date changes
          });
        },
        onStartTimeSelected: (time) => setState(() => _startTime = time),
        onEndTimeSelected: (time) => setState(() => _endTime = time),
        onNext: _goToNextStep,
        onBack: () {
          setState(() => _currentStep--);
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),

      // Step 3: Days
      CourseDaysPage(
        selectedDays: _selectedDays,
        startDay: _startDate != null
            ? DateFormat('EEEE', 'en').format(_startDate!)
            : '',
        endDay: _endDate != null ? DateFormat('EEEE', 'en').format(_endDate!) : '',
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
          setState(() => _currentStep--);
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),

      // Step 4: Price
      CoursePricePage(
        priceController: _priceController,
        teacherEarningPercentage: _teacherEarningPercentage,
        hasCommissionRate: _hasCommissionRate,
        onNext: _goToNextStep,
        onBack: () {
          setState(() => _currentStep--);
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),

      // Step 5: Summary
      CourseSummaryPage(
        courseName: _courseNameController.text.isEmpty
            ? CourseUtils.getLocalizedCourseName(context, {
                'writingType': _selectedWritingType,
                'calligraphyStyle': _selectedCalligraphyStyle,
                'selectedCategory': _selectedCategory,
                'isAutoGeneratedName': true,
              })
            : _courseNameController.text.trim(),
        teacherId: teacherId,
        teacherName: teacherName,
        teacherProfilePic: teacherProfilePic,
        courseBanner: _assignCourseImage(), // PASS BANNER PATH
        courseType: _selectedCategory ?? 'Beginner',
        ageCategory: _selectedAgeGroup ?? '17+',
        maxStudents: _parseMaxStudents(),
        courseDescription: _courseDescriptionController.text,
        startDate: _startDate ?? DateTime.now(),
        endDate: _endDate ?? DateTime.now(),
        startTime: _startTime,
        endTime: _endTime,
        selectedTimeFormatted: _startTime != null
            ? DateFormat('hh:mm a', Localizations.localeOf(context).toString()).format(_startTime!.toLocal())
            : AppLocalizations.of(context)!.tbd,
        selectedEndTimeFormatted: _endTime != null
            ? DateFormat('hh:mm a', Localizations.localeOf(context).toString()).format(_endTime!.toLocal())
            : AppLocalizations.of(context)!.tbd,
        selectedDays: _selectedDays,
        requiredTools: _requiredTools,
        curriculumSteps: _curriculumSteps,
        price: double.tryParse(_priceController.text) ?? 0.0,
        onFinish: (meetData) async => await _saveCourseToFirebase(meetData),
        onBack: () {
          setState(() => _currentStep--);
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          AppLocalizations.of(context)!.addNewCourse,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: AppColors.secondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                        Expanded(child: _buildConnectorLine(2)),
                        Expanded(child: _buildConnectorLine(3)),
                        Expanded(child: _buildConnectorLine(4)),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(0, AppLocalizations.of(context)!.info),
                    _buildStepIndicator(1, AppLocalizations.of(context)!.details),
                    _buildStepIndicator(2, AppLocalizations.of(context)!.schedule),
                    _buildStepIndicator(3, AppLocalizations.of(context)!.days),
                    _buildStepIndicator(4, AppLocalizations.of(context)!.price),
                    _buildStepIndicator(5, AppLocalizations.of(context)!.summary),
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
    );
  }
}
