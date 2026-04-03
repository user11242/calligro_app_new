import 'package:calligro_app/core/theme/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/message/app_messenger.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  // Mock state for UI demonstration only.
  // In the future, this will connect to your localization provider.
  String _selectedLanguageCode = 'en';
  bool _isInitialized = false;

  List<Map<String, String>> _getLanguages(BuildContext context) => [
    {'code': 'en', 'name': AppLocalizations.of(context)!.english, 'native': 'English'},
    {'code': 'ar', 'name': AppLocalizations.of(context)!.arabic, 'native': 'العربية'},
    {'code': 'tr', 'name': AppLocalizations.of(context)!.turkish, 'native': 'Türkçe'},
  ];
  
  bool _isLoading = true;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      // ✅ FIX: Read exactly what LocaleProvider has loaded from memory instantly,
      // instead of relying on the system locale which might default to 'en' briefly.
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      _selectedLanguageCode = localeProvider.locale?.languageCode ?? 'en';
      
      _loadUserLanguage();
    }
  }

  Future<void> _loadUserLanguage() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
      if (doc.exists && mounted) {
        final savedLanguage = doc.data()?['language'];
        if (savedLanguage != null) {
          setState(() {
            _selectedLanguageCode = savedLanguage;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading language: $e");
    }
  }

  Future<void> _updateLanguage(String newCode) async {
    if (_user == null || newCode == _selectedLanguageCode) return;

    setState(() {
      _selectedLanguageCode = newCode;
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      final userRef = firestore.collection('users').doc(_user.uid);
      final userDoc = await userRef.get();
      final role = userDoc.data()?['role'] ?? 'student';

      batch.update(userRef, {'language': newCode});

      if (role == 'teacher') {
        batch.update(firestore.collection('teachers').doc(_user.uid), {'language': newCode});
      } else if (role == 'student') {
        batch.update(firestore.collection('students').doc(_user.uid), {'language': newCode});
      }

      await batch.commit();

      if (mounted) {
        // Update global locale
        Provider.of<LocaleProvider>(context, listen: false).setLocale(newCode);
        
        // LOAD NEW LOCALIZATIONS MANUALLY for the snackbar
        final newL10n = await AppLocalizations.delegate.load(Locale(newCode));

        setState(() => _isLoading = false);
        AppMessenger.showSnackBar(
          context,
          title: newL10n.success,
          message: newL10n.languageUpdated,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Use generic message to avoid mixed language (Arabic Title + English Error)
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.somethingWentWrong,
          type: MessengerType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.language,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.selectPreferredLanguageCaps,
              style: const TextStyle(
                color: AppColors.accentGold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Generate the list of language cards
            _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
              : Column(children: _getLanguages(context).map((lang) => _buildLanguageCard(lang)).toList()),

            const SizedBox(height: 30),

            // Optional: Info Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!.languageRestartNote,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(Map<String, String> lang) {
    bool isSelected = _selectedLanguageCode == lang['code'];

    return GestureDetector(
      onTap: _isLoading ? null : () => _updateLanguage(lang['code']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Language Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  lang['native']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Selection Radio/Icon
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.accentGold : Colors.white24,
                  width: 2,
                ),
                color: isSelected ? AppColors.accentGold : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 16, color: Colors.black),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
