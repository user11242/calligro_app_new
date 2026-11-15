import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

/// Text field + send button. Pure UI: the sheet's controller does the sending.
class AddCommentBar extends StatefulWidget {
  const AddCommentBar({
    super.key,
    required this.onSend,
    required this.onCancelReply,
    this.replyToUserName,
    this.isSending = false,
  });

  /// "Replying to" banner name; null for a top-level comment.
  final String? replyToUserName;
  final bool isSending;
  final VoidCallback onCancelReply;

  /// True when sent; the field is cleared only then.
  final Future<bool> Function(String text) onSend;

  @override
  State<AddCommentBar> createState() => _AddCommentBarState();
}

class _AddCommentBarState extends State<AddCommentBar> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _bannerAnimController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  late final Animation<double> _bannerAnimation =
      CurvedAnimation(parent: _bannerAnimController, curve: Curves.easeOut);

  bool get _isPosting => widget.isSending;

  @override
  void initState() {
    super.initState();
    if (widget.replyToUserName != null) _bannerAnimController.forward();
  }

  @override
  void didUpdateWidget(AddCommentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyToUserName != null && oldWidget.replyToUserName != widget.replyToUserName) {
      _focusNode.requestFocus();
      _bannerAnimController.forward(from: 0);
    } else if (widget.replyToUserName == null && oldWidget.replyToUserName != null) {
      _bannerAnimController.reverse();
    }
  }

  Future<void> _handleSubmit() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;
    if (await widget.onSend(text) && mounted) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _bannerAnimController.dispose();
    _focusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isReplying = widget.replyToUserName != null;

    return Container(
      color: AppColors.primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Reply Banner
          SizeTransition(
            sizeFactor: _bannerAnimation,
            axisAlignment: -1,
            child: isReplying
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.08),
                      border: Border(
                        top: BorderSide(
                          color: AppColors.accentGold.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left accent bar
                        Container(
                          width: 3,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.accentGold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.reply_rounded,
                          color: AppColors.accentGold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.replyingTo,
                                style: TextStyle(
                                  color: AppColors.accentGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                widget.replyToUserName!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          key: const Key('cancel-reply'),
                          onTap: widget.onCancelReply,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.textLight.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.textLight.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Input Row
          Container(
            padding: EdgeInsets.fromLTRB(
              12.0,
              8.0,
              8.0,
              8.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(22.0),
                      border: Border.all(
                        color: isReplying
                            ? AppColors.accentGold.withOpacity(0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      key: const Key('comment-field'),
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isReplying
                            ? l10n.replyTo(widget.replyToUserName!)
                            : l10n.addComment,
                        hintStyle: TextStyle(
                          color: AppColors.textLight.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                _isPosting
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.accentGold,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Material(
                        color: AppColors.accentGold,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('send-comment'),
                          customBorder: const CircleBorder(),
                          onTap: _handleSubmit,
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
