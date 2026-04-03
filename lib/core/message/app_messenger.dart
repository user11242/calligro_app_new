//Done
import 'dart:async'; // 🔹 Import 'dart:async' for the Timer
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart'; // Assuming this is the correct path

/// Types of messages for styling the snackbar
enum MessengerType { success, error, info }

/// A helper class to show custom, modern animated messages.
class AppMessenger {
  /// Displays a custom message with a slide and fade animation.
  static void showSnackBar(
    BuildContext context, {
    required String title,
    required String message,
    MessengerType type = MessengerType.info,
    Color? backgroundColor,
    Color? titleColor,
    Color? messageColor,
  }) {
    if (!context.mounted) return;

    // 1. Determine colors based on type
    Color finalBackgroundColor;
    IconData icon;
    Color finalTitleColor;

    switch (type) {
      case MessengerType.success:
        finalBackgroundColor = backgroundColor ?? const Color(0xFF2E7D32);
        finalTitleColor = titleColor ?? Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case MessengerType.error:
        finalBackgroundColor = backgroundColor ?? const Color(0xFFC72C41);
        finalTitleColor = titleColor ?? Colors.white;
        icon = Icons.error_outline;
        break;
      case MessengerType.info:
      default:
        finalBackgroundColor = backgroundColor ?? AppColors.accentGold;
        finalTitleColor = titleColor ?? AppColors.primary;
        icon = Icons.info_outline;
        break;
    }

    final Color finalMessageColor = messageColor ?? finalTitleColor.withAlpha(200);

    // Hide any existing SnackBars first
    // Safe localization lookup
    String barrierLabel = "Dismiss";
    try {
      barrierLabel = MaterialLocalizations.of(context).modalBarrierDismissLabel;
    } catch (_) {}

    // Use a helper to find the best context/navigator
    final navigator = Navigator.of(context, rootNavigator: true);

    showGeneralDialog(
      context: navigator.context, // Use the navigator's context to ensure we are in the right tree
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        // Position the content at the bottom
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: _SnackBarContent(
              title: title,
              message: message,
              backgroundColor: finalBackgroundColor,
              titleColor: finalTitleColor,
              messageColor: finalMessageColor,
              icon: icon,
              onClose: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero);
        return SlideTransition(
          position: tween.animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    ).catchError((e) {
      debugPrint("❌ AppMessenger Error: $e");
    });
  }
}

class _SnackBarContent extends StatefulWidget {
  final String title;
  final String message;
  final Color backgroundColor;
  final Color titleColor;
  final Color messageColor;
  final IconData icon;
  final VoidCallback onClose;

  const _SnackBarContent({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.titleColor,
    required this.messageColor,
    required this.icon,
    required this.onClose,
  });

  @override
  State<_SnackBarContent> createState() => _SnackBarContentState();
}

class _SnackBarContentState extends State<_SnackBarContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) widget.onClose();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 50),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(widget.icon, color: widget.titleColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: widget.messageColor, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.close,
              color: widget.titleColor.withAlpha(180),
              size: 20,
            ),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
