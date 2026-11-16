import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import '../../../../core/message/app_messenger.dart';

class CourseInformationPage extends StatefulWidget {
  final TextEditingController courseNameController;
  final TextEditingController courseDescriptionController;
  final TextEditingController numberOfStudentsController;
  final String? selectedCategory;
  final String? selectedAgeGroup;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onAgeGroupChanged;
  final void Function(String writingType, String? calligraphyStyle) onNext;

  const CourseInformationPage({
    super.key,
    required this.courseNameController,
    required this.courseDescriptionController,
    required this.numberOfStudentsController,
    required this.selectedCategory,
    required this.selectedAgeGroup,
    required this.onCategoryChanged,
    required this.onAgeGroupChanged,
    required this.onNext,
  });

  @override
  _CourseInformationPageState createState() => _CourseInformationPageState();
}

class _CourseInformationPageState extends State<CourseInformationPage> {
  int _numberOfStudents = 1;
  String? _selectedWritingType;
  String? _selectedCalligraphyStyle;

  List<String> _getWritingTypes(AppLocalizations l10n) => [
    l10n.arabicCalligraphy,
    l10n.normalPenWriting,
  ];

  List<String> _getCalligraphyTypes(AppLocalizations l10n) => [
    l10n.kufi,
    l10n.naskh,
    l10n.ruqah,
    l10n.thuluth,
    l10n.jaliThuluth,
    l10n.diwani,
    l10n.jaliDiwani,
    l10n.persianTaliq,
    l10n.ijaza,
    l10n.muhaqqaq,
    l10n.rayhani,
  ];

  String _getAgeGroupLabel(String ageGroup, String locale) {
    if (ageGroup == '7-10') {
      if (locale == 'ar') return '7-10 سنوات';
      if (locale == 'tr') return '7-10 Yaş Arası';
      return '7-10 Years Old';
    } else if (ageGroup == '11-16') {
      if (locale == 'ar') return '11-16 سنة';
      if (locale == 'tr') return '11-16 Yaş Arası';
      return '11-16 Years Old';
    } else if (ageGroup == '17+') {
      if (locale == 'ar') return '17+ سنة';
      if (locale == 'tr') return '17+ Yaş';
      return '17+ Years Old';
    }
    return ageGroup;
  }

  bool get _isNameEnabled {
    if (_selectedWritingType == null) return false;
    if (widget.selectedCategory == null) return false;
    if (_selectedWritingType == "Arabic Calligraphy" &&
        _selectedCalligraphyStyle == null) {
      return false;
    }
    return true;
  }

  bool get _isDescriptionEnabled => _isNameEnabled;

  void _updateDescription({String? explicitCategory}) {
    final l10n = AppLocalizations.of(context)!;
    final category = explicitCategory ?? widget.selectedCategory;

    if (_selectedWritingType == null) {
      widget.courseDescriptionController.clear();
      return;
    }

    if (_selectedWritingType == "Arabic Calligraphy" &&
        _selectedCalligraphyStyle == null) {
      widget.courseDescriptionController.clear();
      return;
    }

    if (category == null) {
      widget.courseDescriptionController.clear();
      return;
    }

    String newDescription = "";

    // IMPORTANT: Keys are now English ("Normal Pen Writing", "Beginner", etc.)
    if (_selectedWritingType == "Normal Pen Writing") {
        if (category == 'Beginner') {
          newDescription = l10n.beginnerDescriptionNormal;
        } else if (category == 'Intermediate') {
          newDescription = l10n.intermediateDescriptionNormal;
        } else if (category == 'Advanced') {
          newDescription = l10n.advancedDescriptionNormal;
        }
    } else if (_selectedWritingType == "Arabic Calligraphy" &&
        _selectedCalligraphyStyle != null) {
      // Map the internal English style key to the localized string for the description function
      // (Assuming the description function expects the LOCALIZED style name, usually)
      // HOWEVER, looking at helper logic, it usually just inserts the string.
      // Let's pass the Localized version to the helper text if possible.
      
      // Better yet, let's just pass the style key. It will appear in the text.
      // If the description needs the localized name of the style (e.g. "Kufi Course..."),
      // we should probably map it. 
      // For simplicity, let's map keys to localized names for the generated description.
      String localizedStyleName = _selectedCalligraphyStyle!;
      if (_selectedCalligraphyStyle == "Kufi") {
        localizedStyleName = l10n.kufi;
      } else if (_selectedCalligraphyStyle == "Naskh") localizedStyleName = l10n.naskh;
      else if (_selectedCalligraphyStyle == "Ruq'ah") localizedStyleName = l10n.ruqah;
      else if (_selectedCalligraphyStyle == "Thuluth") localizedStyleName = l10n.thuluth;
      else if (_selectedCalligraphyStyle == "Jali Thuluth") localizedStyleName = l10n.jaliThuluth;
      else if (_selectedCalligraphyStyle == "Diwani") localizedStyleName = l10n.diwani;
      else if (_selectedCalligraphyStyle == "Jali Diwani") localizedStyleName = l10n.jaliDiwani;
      else if (_selectedCalligraphyStyle == "Persian (Ta'liq)") localizedStyleName = l10n.persianTaliq;
      else if (_selectedCalligraphyStyle == "Ijaza") localizedStyleName = l10n.ijaza;
      else if (_selectedCalligraphyStyle == "Muhaqqaq") localizedStyleName = l10n.muhaqqaq;
      else if (_selectedCalligraphyStyle == "Rayhani") localizedStyleName = l10n.rayhani;

      if (category == 'Beginner') {
        newDescription = l10n.beginnerDescriptionCalligraphy(localizedStyleName);
      } else if (category == 'Intermediate') {
        newDescription = l10n.intermediateDescriptionCalligraphy(localizedStyleName);
      } else if (category == 'Advanced') {
        newDescription = l10n.advancedDescriptionCalligraphy(localizedStyleName);
      }
    }

    if (newDescription.isNotEmpty) {
      widget.courseDescriptionController.text = newDescription;
    } else {
      widget.courseDescriptionController.clear();
    }

    _updateGeneratedName(explicitCategory: explicitCategory);
  }

  void _updateGeneratedName({String? explicitCategory}) {
    if (!_isNameEnabled) return;

    final l10n = AppLocalizations.of(context)!;
    final categoryKey = explicitCategory ?? widget.selectedCategory;

    String subject = "";
    if (_selectedWritingType == "Normal Pen Writing") {
      subject = l10n.normalPenWriting;
    } else if (_selectedWritingType == "Arabic Calligraphy" && _selectedCalligraphyStyle != null) {
      // Mapping style keys to localized names
      if (_selectedCalligraphyStyle == "Kufi") {
        subject = l10n.kufi;
      } else if (_selectedCalligraphyStyle == "Naskh") subject = l10n.naskh;
      else if (_selectedCalligraphyStyle == "Ruq'ah") subject = l10n.ruqah;
      else if (_selectedCalligraphyStyle == "Thuluth") subject = l10n.thuluth;
      else if (_selectedCalligraphyStyle == "Jali Thuluth") subject = l10n.jaliThuluth;
      else if (_selectedCalligraphyStyle == "Diwani") subject = l10n.diwani;
      else if (_selectedCalligraphyStyle == "Jali Diwani") subject = l10n.jaliDiwani;
      else if (_selectedCalligraphyStyle == "Persian (Ta'liq)") subject = l10n.persianTaliq;
      else if (_selectedCalligraphyStyle == "Ijaza") subject = l10n.ijaza;
      else if (_selectedCalligraphyStyle == "Muhaqqaq") subject = l10n.muhaqqaq;
      else if (_selectedCalligraphyStyle == "Rayhani") subject = l10n.rayhani;
    }

    String level = "";
    if (categoryKey == 'Beginner') {
      level = l10n.beginner;
    } else if (categoryKey == 'Intermediate') level = l10n.intermediate;
    else if (categoryKey == 'Advanced') level = l10n.advanced;

    if (subject.isNotEmpty && level.isNotEmpty) {
      widget.courseNameController.text = l10n.courseNameTemplate(level, subject);
    }
  }

  void _showMessage(String msg) {
    AppMessenger.showSnackBar(
      context,
      title: AppLocalizations.of(context)!.validation,
      message: msg,
      type: MessengerType.info,
    );
  }

  void _validateForm() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedWritingType == null) {
      _showMessage(l10n.pleaseSelectWritingType);
      return;
    }

    if (_selectedWritingType == "Arabic Calligraphy" &&
        _selectedCalligraphyStyle == null) {
      _showMessage(l10n.pleaseSelectCalligraphyStyle);
      return;
    }

    if (widget.selectedCategory == null) {
      _showMessage(l10n.pleaseSelectCategory);
      return;
    }

    if (widget.selectedAgeGroup == null) {
      _showMessage('Please select an age group');
      return;
    }

    if (widget.courseDescriptionController.text.isEmpty) {
      _showMessage(l10n.descriptionRequired);
      return;
    }

    if (widget.numberOfStudentsController.text.isEmpty) {
      _showMessage(l10n.maxStudentsRequired);
      return;
    }

    // Now simply pass the English keys directly
    widget.onNext(_selectedWritingType!, _selectedCalligraphyStyle);
  }

  void _showStudentCountPicker() {
    int tempNumberOfStudents = _numberOfStudents;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: StatefulBuilder(
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.selectNumberOfStudents,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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
                          HapticFeedback.selectionClick();
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
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
              child: Text(AppLocalizations.of(context)!.done, style: const TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() {
                  _numberOfStudents = tempNumberOfStudents;
                  widget.numberOfStudentsController.text = _numberOfStudents
                      .toString();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String? hintText, IconData icon) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Urbanist'),
      prefixIcon: Icon(icon, color: AppColors.textColor),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.textColor, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define a solid dark color for the dropdown menu card
    // slightly lighter than black so it's visible as a separate card
    final Color dropdownMenuColor = const Color(0xFF2C2C2C);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DROPDOWN #1 – Writing Type
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedWritingType,
                  dropdownColor: dropdownMenuColor,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 10,
                  hint: Text(
                    AppLocalizations.of(context)!.chooseWritingType,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Urbanist',
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedWritingType = value;
                      _selectedCalligraphyStyle = null;
                      _updateDescription();
                    });
                  },
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: [
                    DropdownMenuItem(
                      value: "Arabic Calligraphy", 
                      child: Text(AppLocalizations.of(context)!.arabicCalligraphy),
                    ),
                    DropdownMenuItem(
                      value: "Normal Pen Writing", 
                      child: Text(AppLocalizations.of(context)!.normalPenWriting),
                    ),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Urbanist',
                  ),
                  decoration: _buildInputDecoration(null, Icons.brush),
                ),
              ),

              // DROPDOWN #2 – Calligraphy Styles
              if (_selectedWritingType == "Arabic Calligraphy")
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCalligraphyStyle,
                    dropdownColor: dropdownMenuColor,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 10,
                    hint: Text(
                      AppLocalizations.of(context)!.chooseCalligraphyStyle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Urbanist',
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedCalligraphyStyle = value;
                        _updateDescription();
                      });
                    },
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    items: [
                      DropdownMenuItem(value: "Kufi", child: Text(AppLocalizations.of(context)!.kufi)),
                      DropdownMenuItem(value: "Naskh", child: Text(AppLocalizations.of(context)!.naskh)),
                      DropdownMenuItem(value: "Ruq'ah", child: Text(AppLocalizations.of(context)!.ruqah)),
                      DropdownMenuItem(value: "Thuluth", child: Text(AppLocalizations.of(context)!.thuluth)),
                      DropdownMenuItem(value: "Jali Thuluth", child: Text(AppLocalizations.of(context)!.jaliThuluth)),
                      DropdownMenuItem(value: "Diwani", child: Text(AppLocalizations.of(context)!.diwani)),
                      DropdownMenuItem(value: "Jali Diwani", child: Text(AppLocalizations.of(context)!.jaliDiwani)),
                      DropdownMenuItem(value: "Persian (Ta'liq)", child: Text(AppLocalizations.of(context)!.persianTaliq)),
                      DropdownMenuItem(value: "Ijaza", child: Text(AppLocalizations.of(context)!.ijaza)),
                      DropdownMenuItem(value: "Muhaqqaq", child: Text(AppLocalizations.of(context)!.muhaqqaq)),
                      DropdownMenuItem(value: "Rayhani", child: Text(AppLocalizations.of(context)!.rayhani)),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Urbanist',
                    ),
                    decoration: _buildInputDecoration(null, Icons.edit),
                  ),
                ),

              // DROPDOWN #3 - Category
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<String>(
                  initialValue: widget.selectedCategory,
                  dropdownColor: dropdownMenuColor,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 10,
                  hint: Text(
                    AppLocalizations.of(context)!.chooseCategory,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Urbanist',
                    ),
                  ),
                  onChanged: (value) {
                    widget.onCategoryChanged(value);
                    _updateDescription(explicitCategory: value);
                  },
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: [
                    DropdownMenuItem(
                      value: 'Beginner',
                      child: Text(AppLocalizations.of(context)!.beginner),
                    ),
                    DropdownMenuItem(
                      value: 'Intermediate',
                      child: Text(AppLocalizations.of(context)!.intermediate),
                    ),
                    DropdownMenuItem(
                      value: 'Advanced',
                      child: Text(AppLocalizations.of(context)!.advanced),
                    ),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Urbanist',
                  ),
                  decoration: _buildInputDecoration(null, Icons.category),
                ),
              ),

              // DROPDOWN #4 - Age Category
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<String>(
                  initialValue: widget.selectedAgeGroup,
                  dropdownColor: dropdownMenuColor,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 10,
                  hint: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'اختر الفئة العمرية'
                        : Localizations.localeOf(context).languageCode == 'tr'
                            ? 'Yaş Grubunu Seçin'
                            : 'Choose Age Group',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Urbanist',
                    ),
                  ),
                  onChanged: (value) {
                    widget.onAgeGroupChanged(value);
                  },
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: [
                    DropdownMenuItem(
                      value: '7-10',
                      child: Text(_getAgeGroupLabel('7-10', Localizations.localeOf(context).languageCode)),
                    ),
                    DropdownMenuItem(
                      value: '11-16',
                      child: Text(_getAgeGroupLabel('11-16', Localizations.localeOf(context).languageCode)),
                    ),
                    DropdownMenuItem(
                      value: '17+',
                      child: Text(_getAgeGroupLabel('17+', Localizations.localeOf(context).languageCode)),
                    ),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Urbanist',
                  ),
                  decoration: _buildInputDecoration(null, Icons.child_care_rounded),
                ),
              ),

              // TEXT FIELD - Course Name (Moved & Conditional)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: widget.courseNameController,
                  enabled: _isNameEnabled,
                  style: TextStyle(
                    color: _isNameEnabled ? Colors.white : Colors.white38,
                    fontFamily: 'Urbanist',
                  ),
                  decoration: _buildInputDecoration(
                    AppLocalizations.of(context)!.courseName,
                    Icons.title_rounded,
                  ),
                ),
              ),

              // TEXT FIELD - Course Description
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: widget.courseDescriptionController,
                  readOnly: !_isDescriptionEnabled,
                  maxLines: 8,
                  minLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Urbanist',
                  ),
                  decoration: _buildInputDecoration(
                    AppLocalizations.of(context)!.enterCourseDescription,
                    Icons.description,
                  ),
                ),
              ),

              // TEXT FIELD - Number of Students
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: widget.numberOfStudentsController,
                  readOnly: true,
                  onTap: _showStudentCountPicker,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Urbanist',
                  ),
                  decoration: _buildInputDecoration(
                    AppLocalizations.of(context)!.maxStudentsHint,
                    Icons.group,
                  ),
                ),
              ),

              // --- NAVIGATION BUTTONS ---
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
                        child: ElevatedButton.icon(
                          onPressed: _validateForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textColor,
                            foregroundColor: Colors.black,
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
