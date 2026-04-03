import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  /// 🔹 Switch the locale and persist it
  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language_code', languageCode);
  }

  /// 🔹 Load the persisted locale on startup
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('selected_language_code');
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }
}
