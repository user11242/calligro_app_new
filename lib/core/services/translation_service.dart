import 'package:translator/translator.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final _translator = GoogleTranslator();
  
  // Simple in-memory cache to prevent flickering and reduce API calls
  static final Map<String, String> _cache = {};

  /// Identifies the language of the text.
  /// Returns 'ar', 'en', 'tr' or 'und' (undefined).
  Future<String> identifyLanguage(String text) async {
    if (text.isEmpty) return 'und';
    try {
      final translation = await _translator.translate(text);
      return translation.sourceLanguage.code;
    } catch (e) {
      return 'und';
    }
  }

  /// Translates text from source to target.
  Future<String> translate({
    required String text,
    String? source,
    required String target,
  }) async {
    if (text.isEmpty) return text;
    
    // Check cache first
    final String cacheKey = '${text}_$target';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    try {
      final translation = await _translator.translate(
        text,
        from: source ?? 'auto',
        to: target,
      );
      
      // Store in cache
      final result = translation.text;
      _cache[cacheKey] = result;
      
      return result;
    } catch (e) {
      return text;
    }
  }

  /// Mock for compatibility (Model management no longer needed)
  Future<bool> isModelDownloaded(dynamic language) async {
    return true;
  }

  /// Mock for compatibility
  Future<void> downloadModel(dynamic language) async {
    return;
  }

  /// Mock for compatibility
  Future<void> deleteModel(dynamic language) async {
    return;
  }
  
  /// Helper string to TranslateLanguage mock (not used in web translator but kept for signature)
  String? getLanguage(String code) {
    if (['ar', 'en', 'tr'].contains(code)) return code;
    return null;
  }
}
