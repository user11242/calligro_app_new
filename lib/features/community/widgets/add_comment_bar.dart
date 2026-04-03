// lib/features/community/widgets/add_comment_bar.dart
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../services/community_service.dart';
import '../../../core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

final CommunityService _communityService = CommunityService();

class AddCommentBar extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> currentUserData;
  final String? replyToUserName;
  final VoidCallback? onCancelReply;
  final Function(String text)? onSendReply;

  const AddCommentBar({
    super.key,
    required this.postId,
    required this.currentUserData,
    this.replyToUserName,
    this.onCancelReply,
    this.onSendReply,
  });

  @override
  State<AddCommentBar> createState() => _AddCommentBarState();
}

class _AddCommentBarState extends State<AddCommentBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;
  final FocusNode _focusNode = FocusNode();
  AnimationController? _bannerAnimController;
  Animation<double>? _bannerAnimation;

  @override
  void initState() {
    super.initState();
    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _bannerAnimation = CurvedAnimation(
      parent: _bannerAnimController!,
      curve: Curves.easeOut,
    );
    if (widget.replyToUserName != null) {
      _bannerAnimController!.forward();
    }
  }

  @override
  void didUpdateWidget(AddCommentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyToUserName != null &&
        oldWidget.replyToUserName != widget.replyToUserName) {
      _focusNode.requestFocus();
      _bannerAnimController?.forward(from: 0);
    } else if (widget.replyToUserName == null &&
        oldWidget.replyToUserName != null) {
      _bannerAnimController?.reverse();
    }
  }

  Future<void> _handleSubmit() async {
    final String text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    if (widget.replyToUserName != null && widget.onSendReply != null) {
      widget.onSendReply!(text);
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } else {
      await _postComment(text);
    }
  }

  Future<void> _postComment(String text) async {
    setState(() => _isPosting = true);

    final String userId = widget.currentUserData['id'];
    final String userName =
        widget.currentUserData['name'] ?? AppLocalizations.of(context)!.user;
    final String userPhotoUrl = widget.currentUserData['photoUrl'] ?? '';
    final String userRole = widget.currentUserData['role'] ?? 'student';

    try {
      await _communityService.addComment(
        postId: widget.postId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        userRole: userRole,
        text: text,
      );
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.failedToPostComment,
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _bannerAnimController?.dispose();
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
          if (_bannerAnimation != null)
          SizeTransition(
            sizeFactor: _bannerAnimation!,
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
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        // FIX: call replyTo(name) properly instead of using it as a string
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
