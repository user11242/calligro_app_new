import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../../core/message/app_messenger.dart';

class CourseDetailsStep extends StatefulWidget {
  final String writingType;
  final String courseLevel;
  final List<Map<String, dynamic>> requiredTools;
  final List<String> curriculumSteps;

  final Function(List<Map<String, dynamic>>) onToolsChanged;
  final Function(List<String>) onCurriculumChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const CourseDetailsStep({
    super.key,
    required this.writingType,
    required this.courseLevel,
    required this.requiredTools,
    required this.curriculumSteps,
    required this.onToolsChanged,
    required this.onCurriculumChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<CourseDetailsStep> createState() => _CourseDetailsStepState();
}

class _CourseDetailsStepState extends State<CourseDetailsStep> {
  final TextEditingController _customToolController = TextEditingController();
  final TextEditingController _customCurriculumController =
      TextEditingController();

  // Default selection for the dialog
  String _selectedDialogIconKey = 'generic';

  // --- 1. THE ICON REGISTRY (The "Keys" you save to DB) ---
  final Map<String, IconData> _iconRegistry = {
    'pen': Icons.edit,
    'brush': Icons.brush,
    'paper': Icons.article,
    'ink': Icons.water_drop,
    'ruler': Icons.straighten,
    'book': Icons.menu_book,
    'laptop': Icons.laptop,
    'generic': Icons.star_border,
  };

  List<String> _getCalligraphyTools(AppLocalizations l10n) => [
    l10n.bambooPen,
    l10n.metalNib,
    l10n.likkaSilk,
    l10n.glossyPaper,
    l10n.ink,
  ];

  List<String> _getNormalWritingTools(AppLocalizations l10n) => [
    l10n.ballpointPen,
    l10n.gelPen,
    l10n.linedNotebook,
    l10n.pencilEraser,
    l10n.correctionTape,
  ];

  List<String> get _currentTools {
    final l10n = AppLocalizations.of(context)!;
    return widget.writingType == "Normal Pen Writing"
        ? _getNormalWritingTools(l10n)
        : _getCalligraphyTools(l10n);
  }

  // --- ICON HELPER ---
  IconData _getToolIcon(String toolName, {String? customIconKey}) {
    // 1. If we have a custom icon key, use it
    if (customIconKey != null) {
      return _iconRegistry[customIconKey] ?? Icons.star;
    }

    final l10n = AppLocalizations.of(context)!;
    
    // 2. Fallback for Predefined Tools (Hardcoded visual logic)
    if (toolName == l10n.bambooPen || toolName.contains("Brush")) {
      return Icons.brush;
    }
    if (toolName == l10n.metalNib ||
        toolName == l10n.ballpointPen ||
        toolName == l10n.gelPen ||
        toolName == l10n.pencilEraser) {
      return Icons.create;
    }
    if (toolName == l10n.glossyPaper || toolName == l10n.linedNotebook) {
      return Icons.article;
    }
    if (toolName == l10n.ink || toolName == l10n.likkaSilk) {
      return Icons.water_drop;
    }
    if (toolName == l10n.correctionTape) return Icons.build_circle;

    return Icons.check_circle_outline; // Default fallback
  }

  List<String> get _currentCurriculumSuggestions {
    final l10n = AppLocalizations.of(context)!;
    bool isNormal = widget.writingType == "Normal Pen Writing";
    String level = widget.courseLevel;
    if (isNormal) {
      if (level == 'Intermediate') {
        return [
          l10n.connectingLetters,
          l10n.wordSpacing,
          l10n.lineConsistency,
          l10n.speedWriting,
        ];
      } else if (level == 'Advanced')
        return [
          l10n.cursiveStyle,
          l10n.signatureDesign,
          l10n.fountainPenBasics,
          l10n.businessHandwriting,
        ];
      else
        return [
          l10n.handPosture,
          l10n.paperPosition,
          l10n.basicShapes,
          l10n.lowercaseAM,
          l10n.lowercaseNZ,
        ];
    } else {
      if (level == 'Intermediate') {
        return [
          l10n.reviewBasics,
          l10n.complexConnections,
          l10n.sentenceStructure,
          l10n.inkControl,
        ];
      } else if (level == 'Advanced')
        return [
          l10n.compositionRules,
          l10n.jaliLargeScale,
          l10n.goldLeaf,
          l10n.masterpieceCreation,
        ];
      else
        return [
          l10n.introToTools,
          l10n.holdingThePen,
          l10n.dotsNuqta,
          l10n.letterAlif,
          l10n.lettersBaRa,
        ];
    }
  }

  // --- ACTIONS ---
  void _toggleTool(String toolName, {String? iconKey}) {
    final newList = List<Map<String, dynamic>>.from(widget.requiredTools);
    final int index = newList.indexWhere((t) => t['name'] == toolName);

    if (index != -1) {
      newList.removeAt(index);
    } else {
      newList.add({
        'name': toolName,
        'icon': iconKey ?? _getIconKeyForPredefined(toolName),
      });
    }
    widget.onToolsChanged(newList);
  }

  String _getIconKeyForPredefined(String toolName) {
    final l10n = AppLocalizations.of(context)!;
    if (toolName == l10n.bambooPen || toolName.contains("Brush")) return 'brush';
    if (toolName == l10n.metalNib || toolName == l10n.ballpointPen || toolName == l10n.gelPen || toolName == l10n.pencilEraser || toolName == l10n.correctionTape) return 'pen';
    if (toolName == l10n.glossyPaper || toolName == l10n.linedNotebook) return 'paper';
    if (toolName == l10n.ink || toolName == l10n.likkaSilk) return 'ink';
    if (toolName.contains("Ruler") || toolName.contains("مسطرة")) return 'ruler';
    return 'generic';
  }

  void _addCustomTool() {
    final text = _customToolController.text.trim();
    if (text.isNotEmpty) {
      final newList = List<Map<String, dynamic>>.from(widget.requiredTools);
      newList.add({
        'name': text,
        'icon': _selectedDialogIconKey,
      });
      widget.onToolsChanged(newList);

      _customToolController.clear();
      _selectedDialogIconKey = 'generic'; // Reset
      Navigator.pop(context);
    }
  }

  void _addCurriculumItem(String item) {
    final newList = List<String>.from(widget.curriculumSteps);
    if (!newList.contains(item)) {
      newList.add(item);
      widget.onCurriculumChanged(newList);
    }
    _customCurriculumController.clear();
  }

  void _removeCurriculumItem(int index) {
    final newList = List<String>.from(widget.curriculumSteps);
    newList.removeAt(index);
    widget.onCurriculumChanged(newList);
  }

  void _validateAndProceed() {
    if (widget.requiredTools.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.required,
        message: AppLocalizations.of(context)!.pleaseSelectOneTool,
        type: MessengerType.info,
      );
      return;
    }
    if (widget.curriculumSteps.length < 5) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.required,
        message: AppLocalizations.of(context)!.localeName == 'ar' 
          ? 'يرجى إضافة 5 نتائج تعلم على الأقل.' 
          : 'Please add at least 5 learning outcomes.',
        type: MessengerType.info,
      );
      return;
    }
    widget.onNext();
  }

  // --- DIALOG WITH ICON PICKER ---
  void _showAddCustomToolDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                AppLocalizations.of(context)!.addCustomTool,
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Text Input
                  TextField(
                    controller: _customToolController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.toolNameHint,
                      hintStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.textColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Icon Picker Label
                  Text(
                    AppLocalizations.of(context)!.selectIcon,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  // 3. Icon Grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _iconRegistry.entries.map((entry) {
                      final isSelected = _selectedDialogIconKey == entry.key;
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            _selectedDialogIconKey = entry.key;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.textColor
                                : Colors.grey[800],
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            size: 20,
                            color: isSelected ? Colors.black : Colors.white54,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textColor,
                  ),
                  onPressed: _addCustomTool,
                  child: Text(
                    AppLocalizations.of(context)!.add,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION 1: TOOLS ---
                _buildSectionHeader(AppLocalizations.of(context)!.toolsRequirements),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // 1. Standard Tools
                      ..._currentTools.map((t) => _buildToolChip(t)),

                      // 2. Custom Tools
                      ...widget.requiredTools
                          .where((t) => !_currentTools.contains(t['name']))
                          .map((t) => _buildToolChip(t['name'], customIconKey: t['icon'])),

                      // 3. Add Button (UPDATED)
                      ActionChip(
                        avatar: const Icon(
                          Icons.add,
                          size: 18,
                          color: AppColors.textColor, // Accent color for icon
                        ),
                        label: Text(AppLocalizations.of(context)!.custom),
                        backgroundColor: Colors.grey[850], // Darker background
                        side: const BorderSide(
                          color: Colors.white10,
                          style: BorderStyle.solid,
                        ),
                        labelStyle: const TextStyle(
                          color: Colors.white, // White text
                        ),
                        onPressed: _showAddCustomToolDialog,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- SECTION 2: LEARNING OUTCOMES ---
                _buildSectionHeader(AppLocalizations.of(context)!.localeName == 'ar' ? 'نتائج التعلم' : 'Learning Outcomes'),
                const SizedBox(height: 10),

                // Input Area (UPDATED WITH SHADOW)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _customCurriculumController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.localeName == 'ar' ? 'أضف نتيجة تعلم' : 'Add learning outcome...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor:
                                Colors.transparent, // Let Container color show
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.isNotEmpty) _addCurriculumItem(val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add Button (UPDATED SHADOW FOR CONSISTENCY)
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton.filled(
                        onPressed: () {
                          if (_customCurriculumController.text.isNotEmpty) {
                            _addCurriculumItem(
                              _customCurriculumController.text,
                            );
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add, color: Colors.black),
                      ),
                    ),
                  ],
                ),

                // Suggestions
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: SizedBox(
                    height: 35,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _currentCurriculumSuggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _addCurriculumItem(
                            _currentCurriculumSuggestions[index],
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: Text(
                              "+ ${_currentCurriculumSuggestions[index]}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Timeline List
                if (widget.curriculumSteps.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.redAccent.withOpacity(0.05),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.localeName == 'ar' 
                          ? 'ابدأ بإضافة نتائج التعلم لبناء دورتك.' 
                          : 'Start adding learning outcomes to build your course.',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.curriculumSteps.length,
                    itemBuilder: (context, index) {
                      return _buildTimelineItem(
                        index,
                        widget.curriculumSteps[index],
                      );
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // --- BOTTOM BAR ---
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(16.0),
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
                    onPressed: widget.onBack,
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
                    onPressed: _validateAndProceed,
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
                      AppLocalizations.of(context)!.nextStep,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildToolChip(String label, {String? customIconKey}) {
    final isSelected = widget.requiredTools.any((t) => t['name'] == label);

    // Get the icon (either standard or the one the teacher picked)
    final iconData = _getToolIcon(label, customIconKey: customIconKey);

    return FilterChip(
      selected: isSelected,
      onSelected: (_) => _toggleTool(label, iconKey: customIconKey),
      showCheckmark: false,
      avatar: Icon(
        iconData,
        size: 18,
        color: isSelected ? Colors.black : AppColors.textColor,
      ),
      label: Text(label),
      selectedColor: AppColors.textColor,
      backgroundColor: Colors.grey[850],
      side: BorderSide(
        color: isSelected ? AppColors.textColor : Colors.transparent,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTimelineItem(int index, String text) {
    bool isLast = index == widget.curriculumSteps.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.textColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: Colors.grey[800])),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeCurriculumItem(index),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white30,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
