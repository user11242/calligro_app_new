import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import '../../l10n/app_localizations.dart';

/// A widget that automatically translates its text into the app's current language
/// using the web-based TranslationService.
class AutoTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool useShimmer;

  const AutoTranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.useShimmer = false,
  });

  @override
  State<AutoTranslatedText> createState() => _AutoTranslatedTextState();
}

class _AutoTranslatedTextState extends State<AutoTranslatedText> {
  final TranslationService _translationService = TranslationService();
  String? _translatedText;
  bool _isTranslating = false;
  String? _lastText;

  String? _lastTargetLang;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndTranslate();
  }

  @override
  void didUpdateWidget(AutoTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _checkAndTranslate();
    }
  }

  Future<void> _checkAndTranslate() async {
    if (widget.text.isEmpty || widget.text == "Untitled") return;
    
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final targetLang = l10n.localeName; // 'en', 'ar', 'tr'
    
    // If we've already translated this exact text for THIS language, don't do it again
    if (widget.text == _lastText && targetLang == _lastTargetLang) return;

    setState(() {
      _isTranslating = true;
      _lastText = widget.text;
      _lastTargetLang = targetLang;
    });

    try {
      // 1. Identify source language
      final sourceLang = await _translationService.identifyLanguage(widget.text);
      
      // 2. Translate if languages differ
      if (sourceLang != targetLang && sourceLang != 'und') {
        final result = await _translationService.translate(
          text: widget.text,
          target: targetLang,
        );
        
        if (mounted) {
          setState(() {
            _translatedText = result;
            _isTranslating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _translatedText = null; // Use original
            _isTranslating = false;
          });
        }
      }
    } catch (e) {
      debugPrint("AutoTranslatedText error: $e");
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _translatedText ?? widget.text;

    if (_isTranslating && widget.useShimmer) {
      // Basic fade transition for translating state
      return Opacity(
        opacity: 0.5,
        child: Text(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
          overflow: widget.overflow,
          maxLines: widget.maxLines,
        ),
      );
    }

    return Text(
      displayText,
      style: widget.style,
      textAlign: widget.textAlign,
      overflow: widget.overflow,
      maxLines: widget.maxLines,
    );
  }
}
