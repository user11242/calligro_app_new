import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../theme/colors.dart';

class GuestGuard {
  /// Checks if the user is a guest. 
  /// If [isGuest] is true, shows a login prompt dialog and returns false.
  /// Otherwise, returns true.
  /// [returnTo] is an optional route name to pass to the LoginPage so it can return back here.
  static bool check(BuildContext context, {required bool isGuest, String? returnTo}) {
    if (isGuest) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.accentGold),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.loginRequired, // Maybe update this to "Auth Required" if we have it
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.loginToInteract,
            style: const TextStyle(color: AppColors.textLight, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushNamed(
                    context, 
                    '/LoginPage', 
                    arguments: {
                      'returnTo': returnTo,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  "${AppLocalizations.of(context)!.login} / ${AppLocalizations.of(context)!.register}".toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }
}
