import 'dart:io';

import 'package:flutter/material.dart';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/post_editor_controller.dart';
import '../../domain/models/community_models.dart';
import '../../domain/models/community_post.dart';
import '../../domain/policies/community_policy.dart';
import '../community_scope.dart';
import '../widgets/community_dialogs.dart';

/// The one editor screen behind [AddPostPage] and [EditPostPage].
/// Pops `true` after a successful save.
class PostEditorPage extends StatefulWidget {
  const PostEditorPage({super.key, required this.session, this.post});

  final CommunitySession session;

  /// The post being edited; null to create a new one.
  final CommunityPost? post;

  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends State<PostEditorPage> {
  late final TextEditingController _caption = TextEditingController(text: widget.post?.caption ?? '');
  final _linkUrl = TextEditingController();
  final _linkTitle = TextEditingController();
  bool _showLinkInput = false;
  PostEditorController? _controller;
  PostEditorController get c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final services = CommunityScope.of(context);
    final post = widget.post;
    _controller = post == null
        ? PostEditorController.create(repository: services.repository, media: services.media, session: widget.session)
        : PostEditorController.edit(
            post: post, repository: services.repository, media: services.media, session: widget.session);
  }

  @override
  void dispose() {
    _caption.dispose();
    _linkUrl.dispose();
    _linkTitle.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context)!;
    if (!c.canAddImages) {
      AppMessenger.showSnackBar(context,
          title: l10n.info,
          message: l10n.limitPhotosReached(CommunityPolicy.maxImagesPerPost),
          type: MessengerType.info);
      return;
    }
    try {
      await c.addImages(CommunityScope.of(context).imagePicker(context));
    } catch (e) {
      if (mounted) showCommunityError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submit() async {
    c
      ..caption = _caption.text
      ..linkUrl = _linkUrl.text
      ..linkTitle = _linkTitle.text;
    final result = await c.submit();
    if (!mounted) return;
    switch (result) {
      case EditorResult.saved:
        Navigator.pop(context, true);
      case EditorResult.invalid:
        showCommunityError(
          context,
          c.error == CommunityValidationError.tooManyImages
              ? AppLocalizations.of(context)!.canOnlySelectUpTo(CommunityPolicy.maxImagesPerPost)
              : 'You cannot create an empty post.',
        );
      case EditorResult.failed:
        showCommunityError(context, AppLocalizations.of(context)!.failedToSaveChanges);
      case EditorResult.needsAccount || EditorResult.notAllowed || EditorResult.busy:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textLight),
            onPressed: c.isSaving ? null : () => Navigator.pop(context),
          ),
          title: Text(c.isEditing ? l10n.editPost : l10n.addNewPost,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _AuthorHeader(session: widget.session),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            key: const Key('caption-field'),
                            controller: _caption,
                            maxLines: null,
                            autofocus: true,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: c.isEditing ? l10n.updateCaptionHint : l10n.shareMasterpiece,
                              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 16),
                              border: InputBorder.none,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (c.canUseAdminOptions && (_showLinkInput || _linkUrl.text.isNotEmpty))
                            _LinkInput(
                              url: _linkUrl,
                              title: _linkTitle,
                              onClose: () => setState(() {
                                _linkUrl.clear();
                                _linkTitle.clear();
                                _showLinkInput = false;
                              }),
                            ),
                          _ImagePreviews(controller: c),
                        ],
                      ),
                    ),
                  ),
                  _toolbar(l10n),
                  const SizedBox(height: 20),
                  _submitButton(l10n),
                  if (!c.isEditing) const SizedBox(height: 120),
                ],
              ),
            ),
            if (c.isSaving)
              Container(
                color: AppColors.primary.withOpacity(0.7),
                child: const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(AppLocalizations l10n) {
    return Row(
      children: [
        IconButton(
          key: const Key('add-photo'),
          icon: Icon(
            Icons.add_photo_alternate_outlined,
            color: c.canAddImages ? AppColors.textLight : AppColors.textLight.withOpacity(0.3),
            size: 28,
          ),
          onPressed: _pickImages,
          tooltip: c.canAddImages ? l10n.addPhoto : l10n.limitPhotosReached(CommunityPolicy.maxImagesPerPost),
        ),
        if (c.canUseAdminOptions) ...[
          IconButton(
            key: const Key('toggle-link'),
            icon: Icon(
              _showLinkInput || _linkUrl.text.isNotEmpty ? Icons.link : Icons.add_link,
              color: _showLinkInput || _linkUrl.text.isNotEmpty ? AppColors.accentGold : AppColors.textLight,
              size: 28,
            ),
            onPressed: () => setState(() => _showLinkInput = !_showLinkInput),
            tooltip: 'Attach Link',
          ),
          const Spacer(),
          _AdminToggle(
            key: const Key('toggle-hide'),
            label: 'Hide',
            on: c.hide,
            color: Colors.orange,
            textColor: Colors.orangeAccent,
            icon: c.hide ? Icons.visibility_off : Icons.visibility_off_outlined,
            onTap: () => setState(() => c.hide = !c.hide),
          ),
          const SizedBox(width: 8),
          _AdminToggle(
            key: const Key('toggle-pin'),
            label: 'Pin Post',
            on: c.pin,
            color: AppColors.accentGold,
            textColor: AppColors.accentGold,
            icon: c.pin ? Icons.push_pin : Icons.push_pin_outlined,
            onTap: () => setState(() => c.pin = !c.pin),
          ),
        ],
      ],
    );
  }

  Widget _submitButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const Key('submit-post'),
        onPressed: c.isSaving ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: c.isSaving
            ? const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, size: 20),
                  const SizedBox(width: 8),
                  Text(c.isEditing ? l10n.save : l10n.post,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
      ),
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({required this.session});
  final CommunitySession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(imageUrl: session.photoUrl, radius: 22),
        const SizedBox(width: 12),
        Text(
          session.name.isEmpty ? AppLocalizations.of(context)!.anonymous : session.name,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _AdminToggle extends StatelessWidget {
  const _AdminToggle({
    super.key,
    required this.label,
    required this.on,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool on;
  final Color color;
  final Color textColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? textColor : AppColors.textLight;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? color : AppColors.textLight.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LinkInput extends StatelessWidget {
  const _LinkInput({required this.url, required this.title, required this.onClose});
  final TextEditingController url;
  final TextEditingController title;
  final VoidCallback onClose;

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.5), fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentGold),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: AppColors.accentGold, size: 18),
              const SizedBox(width: 8),
              const Text('Attach Link',
                  style: TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              GestureDetector(onTap: onClose, child: const Icon(Icons.close, color: AppColors.textLight, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('link-url'),
            controller: url,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            keyboardType: TextInputType.url,
            decoration: _decoration('https://... (e.g. https://calligroacademy.com)'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('link-title'),
            controller: title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _decoration('Link title / button label (optional, e.g. Visit Website)'),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviews extends StatelessWidget {
  const _ImagePreviews({required this.controller});
  final PostEditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.imageCount == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (i, url) in c.existingImageUrls.indexed)
            _PreviewCard(
              key: Key('existing-image-$i'),
              onRemove: () => c.removeExistingImage(i),
              child: Image.network(url, fit: BoxFit.cover, width: 100, height: 120,
                  errorBuilder: (_, _, _) => const SizedBox(width: 100, height: 120)),
            ),
          for (final (i, path) in c.newImagePaths.indexed)
            _PreviewCard(
              key: Key('new-image-$i'),
              onRemove: () => c.removeNewImage(i),
              child: Image.file(File(path), fit: BoxFit.cover, width: 100, height: 120,
                  errorBuilder: (_, _, _) => const SizedBox(width: 100, height: 120)),
            ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({super.key, required this.child, required this.onRemove});
  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              key: const Key('remove-image'),
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
