import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../widgets/auth_text_field.dart';
import '../../../../core/theme/colors.dart';

class StepTeacherPortfolio extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final Function(String)? onChanged;
  final VoidCallback? onPaste;
  final List<String> selectedLanguages;
  final Function(List<String>) onLanguagesChanged;

  const StepTeacherPortfolio({
    super.key, 
    required this.controller,
    this.errorText,
    this.onChanged,
    this.onPaste,
    required this.selectedLanguages,
    required this.onLanguagesChanged,
  });

  @override
  State<StepTeacherPortfolio> createState() => _StepTeacherPortfolioState();
}

class _StepTeacherPortfolioState extends State<StepTeacherPortfolio> {
  final List<String> _languagesList = [
    "Arabic",
    "English",
    "Turkish",
    "Other"
  ];

  void _addCustomLanguageDialog() {
    final List<String> availableOthers = [
      "Urdu",
      "Malay",
      "Bengali",
      "Farsi",
      "French",
      "Hausa",
      "Swahili",
      "Somali",
      "Kurdish",
      "Albanian"
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          Localizations.localeOf(context).languageCode == 'ar' ? "اختر لغة أخرى" : "Select Other Language",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableOthers.map((lang) {
              String labelText = lang;
              if (lang == "Bengali") labelText = "বাংলা";
              if (lang == "Urdu") labelText = "اردو";
              if (lang == "Farsi") labelText = "فارسی";
              if (lang == "Kurdish") labelText = "کوردي";

              return InkWell(
                onTap: () {
                  setState(() {
                    final otherIdx = _languagesList.indexOf("Other");
                    if (otherIdx != -1) {
                      if (!_languagesList.contains(lang)) {
                        _languagesList.insert(otherIdx, lang);
                      }
                    } else {
                      if (!_languagesList.contains(lang)) {
                        _languagesList.add(lang);
                      }
                    }
                    final newLangs = List<String>.from(widget.selectedLanguages);
                    if (!newLangs.contains(lang)) {
                      newLangs.add(lang);
                      widget.onLanguagesChanged(newLangs);
                    }
                  });
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentGold.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    labelText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              Localizations.localeOf(context).languageCode == 'ar' ? "إلغاء" : "Cancel",
              style: const TextStyle(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.portfolioLink,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: widget.controller,
          hint: l10n.portfolioHint,
          icon: Icons.link,
          onChanged: widget.onChanged,
          errorText: widget.errorText,
          keyboardType: TextInputType.url,
          isSuccess: widget.errorText == null && widget.controller.text.isNotEmpty,
          onPaste: widget.onPaste,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.localeName == 'ar' ? 'اللغات المنطوقة' : 'Spoken Languages',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _languagesList.map((lang) {
            final isSel = widget.selectedLanguages.contains(lang);
            String labelText = lang;
            if (lang == "Arabic") labelText = "العربية";
            if (lang == "Turkish") labelText = "Türkçe";
            if (lang == "Bengali") labelText = "বাংলা";
            if (lang == "Urdu") labelText = "اردو";
            if (lang == "Farsi") labelText = "فارسی";
            if (lang == "Kurdish") labelText = "کوردي";
            if (lang == "Other") {
              labelText = Localizations.localeOf(context).languageCode == 'ar' ? "+ أخرى" : "+ Other";
            }

            return InkWell(
              onTap: () {
                if (lang == "Other") {
                  _addCustomLanguageDialog();
                } else {
                  final newLangs = List<String>.from(widget.selectedLanguages);
                  if (isSel) {
                    newLangs.remove(lang);
                  } else {
                    if (!newLangs.contains(lang)) newLangs.add(lang);
                  }
                  widget.onLanguagesChanged(newLangs);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: (isSel && lang != "Other") ? AppColors.accentGold : AppColors.accentGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isSel && lang != "Other") ? AppColors.accentGold : AppColors.accentGold.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  labelText,
                  style: TextStyle(
                    color: (isSel && lang != "Other") ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
