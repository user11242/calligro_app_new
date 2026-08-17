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

  // Domain-specific terms to avoid Google Translate errors (e.g. Ruq'ah as Patch)
  final Map<String, String> _calligraphyTerms = {
    'رقعة': 'Ruq\'ah',
    'الرقعة': 'Ruq\'ah',
    'ديواني': 'Diwani',
    'الديواني': 'Diwani',
    'نسخ': 'Naskh',
    'النسخ': 'Naskh',
    'ثلث': 'Thuluth',
    'الثلث': 'Thuluth',
    'كوفي': 'Kufic',
    'الكوفي': 'Kufic',
  };

  String _preProcessText(String text, String target) {
    if (target == 'ar') return text;
    String processed = text;
    _calligraphyTerms.forEach((ar, eng) {
      processed = processed.replaceAll(ar, eng);
    });
    return processed;
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
      final textToTranslate = _preProcessText(text, target);
      final translation = await _translator.translate(
        textToTranslate,
        from: source ?? 'auto',
        to: target,
      );
      
      // Store in cache
      String result = translation.text;
      
      // Post-process any weird lingering translations just in case
      if (target == 'en') {
        result = result.replaceAll(RegExp(r'\bpatch\b', caseSensitive: false), 'Ruq\'ah');
      }

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
