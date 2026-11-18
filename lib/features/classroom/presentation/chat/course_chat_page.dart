import 'dart:io';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'package:calligro_app/features/classroom/domain/course_chat_message.dart';
import 'package:calligro_app/features/classroom/data/course_chat_service.dart';
import 'package:calligro_app/features/classroom/presentation/chat/chat_message_bubble.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Real-time group chat room shared by a course's teacher, enrolled students,
/// and academy admins.
class CourseChatPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String? courseTeacherId;
  final bool isTeacher;
  final bool isAdmin;
  final CourseChatService? chatService;
  final String? currentUserId;

  const CourseChatPage({
    super.key,
    required this.courseId,
    required this.courseName,
    this.courseTeacherId,
    this.isTeacher = false,
    this.isAdmin = false,
    this.chatService,
    this.currentUserId,
  });

  @override
  State<CourseChatPage> createState() => _CourseChatPageState();
}

class _CourseChatPageState extends State<CourseChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  late final CourseChatService _chatService;
  late final Stream<List<CourseChatMessage>> _messagesStream;

  File? _selectedImage;
  bool _isSending = false;

  String? get _uid => widget.currentUserId ?? _chatService.currentUid;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? CourseChatService();
    _messagesStream = _chatService.getMessagesStream(widget.courseId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (_) {
      // Ignore picker cancellation or platform permission declines gracefully.
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _messageController.text.trim();
    final image = _selectedImage;
    if (text.isEmpty && image == null) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        courseId: widget.courseId,
        text: text,
        imageFile: image,
        courseTeacherId: widget.courseTeacherId,
      );

      if (mounted) {
        _messageController.clear();
        setState(() => _selectedImage = null);
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: l10n.sendMessageFailed,
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _openImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: SmartImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(CourseChatMessage message) {
    final l10n = AppLocalizations.of(context)!;
    final isMine = message.senderId == _uid;
    final canDelete = ChatPolicy.canDelete(message, _uid, isTeacher: widget.isTeacher, isAdmin: widget.isAdmin);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white),
                  title: Text(
                    l10n.copyMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    Navigator.pop(sheetCtx);
                    AppMessenger.showSnackBar(
                      context,
                      title: l10n.success,
                      message: l10n.messageCopied,
                      type: MessengerType.success,
                    );
                  },
                ),
              if (!isMine)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                  title: Text(
                    l10n.reportMessage,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _reportMessage(message);
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(
                    l10n.deleteMessage,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmDeleteMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteMessage(CourseChatMessage message) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          l10n.deleteMessage,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.deleteMessageConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatService.deleteMessage(
        courseId: widget.courseId,
        messageId: message.id,
      );
    }
  }

  Future<void> _reportMessage(CourseChatMessage message) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _chatService.reportMessage(
        courseId: widget.courseId,
        messageId: message.id,
        reportedUserId: message.senderId,
        reason: 'Reported by user from course group chat',
        messageText: message.text,
      );
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.success,
          message: l10n.messageReportedSuccess,
          type: MessengerType.success,
        );
      }
    } catch (_) {
      // Ignore transient errors cleanly.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              l10n.courseGroupChat,
              style: TextStyle(
                color: AppColors.accentGold.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CourseChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.errorLoadingChat,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accentGold),
                  );
                }

                final messages = snapshot.data ?? const <CourseChatMessage>[];
                if (messages.isEmpty) {
                  return _buildEmptyState(l10n);
                }

                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = _uid != null && message.senderId == _uid;
                    return ChatMessageBubble(
                      message: message,
                      isMine: isMine,
                      onLongPress: () => _showMessageActions(message),
                      onImageTap: _openImagePreview,
                    );
                  },
                );
              },
            ),
          ),
          _buildComposer(l10n),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noMessagesYet,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.startCourseConversation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImage != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black87,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _isSending ? null : _pickImage,
                  icon: Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ChatPolicy.maxTextLength, // the rules refuse longer
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.typeMessageHint,
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.accentGold,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('course_chat_send_button'),
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
