// lib/core/services/security_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calligro_app/core/services/deep_link_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class SecurityService with WidgetsBindingObserver {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  static const _channel = MethodChannel('com.calligro.app/security');

  bool _isProtectionEnabled = false;

  /// Initialize security features
  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshotTaken') {
        _showScreenshotWarning();
      }
    });

    WidgetsBinding.instance.addObserver(this);

    // Default: Protection is disabled on startup
    await disableScreenshotProtection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If we are resuming, ensure protection is correctly applied/cleared
    if (state == AppLifecycleState.resumed) {
      if (_isProtectionEnabled) {
        enableScreenshotProtection();
      } else {
        disableScreenshotProtection();
      }
    }
  }

  /// Enable screenshot/screen recording protection
  Future<void> enableScreenshotProtection() async {
    _isProtectionEnabled = true;
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('enableSecure');
        debugPrint('🔓 SecurityService: FLAG_SECURE ENABLED');
      } catch (e) {
        debugPrint('❌ Failed to enable screenshot protection: $e');
      }
    }
  }

  /// Disable screenshot/screen recording protection
  Future<void> disableScreenshotProtection() async {
    _isProtectionEnabled = false;
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('disableSecure');
        debugPrint('🔒 SecurityService: FLAG_SECURE DISABLED');
      } catch (e) {
        debugPrint('❌ Failed to disable screenshot protection: $e');
      }
    }
  }


  bool _isDialogShowing = false;

  void _showScreenshotWarning() {
    if (!_isProtectionEnabled || _isDialogShowing) return;

    final navigatorState = DeepLinkService().navigatorKey.currentState;
    if (navigatorState == null) {
      debugPrint("❌ SecurityService: Navigator state not available.");
      return;
    }

    _isDialogShowing = true;
    final context = navigatorState.context;
    
    // Use fallback strings if localization is missing for any reason
    final l10n = AppLocalizations.of(context);
    final String title = l10n?.screenshotWarningTitle ?? "Screenshots Restricted";
    final String message = l10n?.screenshotWarningMessage ?? "To protect premium artwork, screenshots are not permitted in this view.";

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: _ScreenshotWarningDialog(
              title: title,
              message: message,
              onClose: () {
                _isDialogShowing = false;
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
  }
}

class _ScreenshotWarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onClose;

  const _ScreenshotWarningDialog({
    required this.title,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.accentGold.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🛡️ Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.accentGold,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              
              // 📝 Text
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              
              // 🔘 Action
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "OK",
                    style: GoogleFonts.outfit(
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
    );
  }
}
