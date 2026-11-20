import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'package:calligro_app/features/classroom/domain/course_chat_message.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Displays an individual group chat message bubble with sender role badges,
/// optional image preview, timestamp, and long-press interaction hook.
class ChatMessageBubble extends StatelessWidget {
  final CourseChatMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onImageTap;
  /// Tapping the PDF card (download, then the phone's save / open sheet).
  final VoidCallback? onFileTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onLongPress,
    this.onImageTap,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bubbleColor = isMine
        ? AppColors.accentGold.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.07);
    final borderColor = isMine
        ? AppColors.accentGold.withValues(alpha: 0.45)
        : (message.isTeacher
            ? AppColors.accentGold.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.1));

    return Align(
      alignment:
          isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(isMine ? 18 : 4),
                bottomEnd: Radius.circular(isMine ? 4 : 18),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  _buildSenderHeader(context, l10n),
                  const SizedBox(height: 6),
                ],
                if (message.hasImage) ...[
                  _buildImageAttachment(message.imageUrl!),
                  if (message.text.isNotEmpty || message.hasFile) const SizedBox(height: 8),
                ],
                if (message.hasFile) ...[
                  _buildFileAttachment(l10n),
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    _formatTimestamp(context, l10n),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSenderHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message.senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: message.isTeacher
                  ? AppColors.accentGold
                  : Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        if (message.isTeacher || message.isAdmin) ...[
          const SizedBox(width: 6),
          _buildRoleBadge(l10n),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    final photo = message.senderPhotoUrl;
    if (photo != null && photo.isNotEmpty) {
      return ClipOval(
        child: SmartImage(
          imageUrl: photo,
          width: 22,
          height: 22,
          errorWidget: _buildInitialCircle(),
        ),
      );
    }
    return _buildInitialCircle();
  }

  Widget _buildInitialCircle() {
    final initial =
        message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'M';
    return CircleAvatar(
      radius: 11,
      backgroundColor: message.isTeacher
          ? AppColors.accentGold
          : Colors.white.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: message.isTeacher ? Colors.black : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleBadge(AppLocalizations l10n) {
    final label = message.isTeacher ? l10n.teacherBadge : l10n.adminBadge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accentGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFileAttachment(AppLocalizations l10n) {
    return InkWell(
      key: const Key('chat_file_attachment'),
      onTap: onFileTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 30),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.fileName ?? 'PDF',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.chatPdfTapToSave,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download_rounded, color: AppColors.accentGold, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAttachment(String url) {
    return GestureDetector(
      onTap: onImageTap != null ? () => onImageTap!(url) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: SmartImage(
            imageUrl: url,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(BuildContext context, AppLocalizations l10n) {
    final createdAt = message.createdAt;
    if (createdAt == null) return l10n.justNow;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.jm(locale).format(createdAt);
  }
}
