import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';

class RecordedInfoStep extends StatefulWidget {
  final TextEditingController courseNameController;
  final TextEditingController courseDescriptionController;
  final TextEditingController priceController;
  final String? selectedCategory;
  final String? selectedWritingType;
  final String? selectedCalligraphyStyle;
  final Function(String?) onCategoryChanged;
  final Function(String?, String?) onWritingTypeChanged;
  final VoidCallback onNext;

  const RecordedInfoStep({
    super.key,
    required this.courseNameController,
    required this.courseDescriptionController,
    required this.priceController,
    required this.selectedCategory,
    required this.selectedWritingType,
    required this.selectedCalligraphyStyle,
    required this.onCategoryChanged,
    required this.onWritingTypeChanged,
    required this.onNext,
  });

  @override
  State<RecordedInfoStep> createState() => _RecordedInfoStepState();
}

class _RecordedInfoStepState extends State<RecordedInfoStep> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Course Information",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Course Name
            TextFormField(
              controller: widget.courseNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Course Title',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accentGold), borderRadius: BorderRadius.circular(10)),
                fillColor: AppColors.cardBackground,
                filled: true,
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: widget.courseDescriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Course Description',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accentGold), borderRadius: BorderRadius.circular(10)),
                fillColor: AppColors.cardBackground,
                filled: true,
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: widget.selectedCategory,
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Level / Category',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accentGold), borderRadius: BorderRadius.circular(10)),
                fillColor: AppColors.cardBackground,
                filled: true,
              ),
              items: ['Beginner', 'Intermediate', 'Advanced'].map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: widget.onCategoryChanged,
            ),
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: widget.priceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Course Price (\$)',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accentGold), borderRadius: BorderRadius.circular(10)),
                fillColor: AppColors.cardBackground,
                filled: true,
                prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please enter a price';
                if (double.tryParse(val) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Next Step',
                style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
