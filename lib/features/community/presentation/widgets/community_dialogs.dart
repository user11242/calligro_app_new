import 'package:flutter/material.dart';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

/// Cancel / [confirmLabel] dialog (the confirm button is red). True when confirmed.
Future<bool> confirmCommunityAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      content: Text(body, style: const TextStyle(color: AppColors.textLight)),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textLight)),
        ),
        TextButton(
          key: const Key('dialog-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showCommunitySuccess(BuildContext context, String message) => AppMessenger.showSnackBar(context,
    title: AppLocalizations.of(context)!.success, message: message, type: MessengerType.success);

void showCommunityError(BuildContext context, String message) => AppMessenger.showSnackBar(context,
    title: AppLocalizations.of(context)!.error, message: message, type: MessengerType.error);
