import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'dart:io' show Platform;

class EditCommentSheet extends StatefulWidget {
  final String initialText;
  final Future<void> Function(String) onSave;
  final bool isReply;

  const EditCommentSheet({
    super.key,
    required this.initialText,
    required this.onSave,
    this.isReply = false,
  });

  @override
  State<EditCommentSheet> createState() => _EditCommentSheetState();
}

class _EditCommentSheetState extends State<EditCommentSheet> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final text = _controller.text.trim();
    
    // If text is same as initial, just close
    if (text == widget.initialText) {
      Navigator.pop(context);
      return;
    }

    // Don't allow saving empty text - treat as cancel if they just cleared it
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(text);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String title = widget.isReply ? l10n.editReply : l10n.editComment;

    // Use a Dialog layout on Android to completely bypass the BottomSheet bug
    if (Platform.isAndroid) {
      return Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isSaving)
                    const SizedBox(
                       width: 20,
                       height: 20,
                       child: CircularProgressIndicator(
                         strokeWidth: 2,
                         color: AppColors.accentGold,
                       ),
                    )
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                maxLines: 5,
                minLines: 1,
                enabled: !_isSaving,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: l10n.writeUpdateHint,
                  hintStyle: TextStyle(
                    color: AppColors.textLight.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: AppColors.primary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Default to bottom sheet for iOS
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentGold,
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    maxLines: 5,
                    minLines: 1,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: l10n.writeUpdateHint,
                      hintStyle: TextStyle(
                        color: AppColors.textLight.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.primary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: Text(
                          l10n.cancel,
                          style: const TextStyle(color: AppColors.textLight),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
