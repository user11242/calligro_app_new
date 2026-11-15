import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/utils/numeric_utils.dart';
import 'package:calligro_app/features/auth/widgets/auth_text_field.dart';
import 'package:calligro_app/features/auth/widgets/verification/universal_otp_step.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/edit_profile_controller.dart';
import '../../domain/profile_edit.dart';
import '../../domain/profile_models.dart';
import '../profile_scope.dart';

/// Edit your own profile (all roles). Pops `true` after a save.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key, this.verifyPhone});

  /// Replaces the SMS-code dialog (tests).
  final Future<bool> Function(BuildContext context, String phone)? verifyPhone;

  @override
  Widget build(BuildContext context) {
    return ProfileViewerGate(
      builder: (context, viewer) => _EditProfile(viewer: viewer, verifyPhone: verifyPhone),
    );
  }
}

class _EditProfile extends StatefulWidget {
  const _EditProfile({required this.viewer, this.verifyPhone});
  final ProfileViewer viewer;
  final Future<bool> Function(BuildContext context, String phone)? verifyPhone;

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  EditProfileController? _controller;
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _email = TextEditingController();
  String _initialCountry = 'US';
  String _initialNumber = '';
  bool _ready = false;

  EditProfileController get c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final s = ProfileScope.of(context);
    _controller = EditProfileController(uid: widget.viewer.userId, editor: s.editor, photos: s.photos, phones: s.phones);
    _load(s);
  }

  Future<void> _load(ProfileServices s) async {
    await c.load();
    final o = c.original;
    var country = await s.phones.deviceCountry();
    var number = '';
    if (o != null && o.phone.isNotEmpty) {
      final split = await s.phones.split(o.phone);
      if (split != null) {
        (country, number) = split;
      } else {
        number = o.phone;
      }
    }
    if (!mounted) return;
    setState(() {
      _name.text = c.name;
      _bio.text = c.bio;
      _email.text = o?.email ?? '';
      _initialCountry = country;
      _initialNumber = number;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _name.dispose();
    _bio.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final path = await ProfileScope.of(context).pickPhoto();
      if (path != null) c.pickPhoto(path);
    } catch (e) {
      debugPrint('Photo could not be picked: $e');
    }
  }

  Future<bool> _verify(String phone) {
    final override = widget.verifyPhone;
    return override != null ? override(context, phone) : _showOtpDialog(phone);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;
    c.bio = _bio.text;
    final result = await c.save(verifyPhone: _verify);
    if (!mounted) return;
    void error(String m) => AppMessenger.showSnackBar(context, title: l10n.error, message: m, type: MessengerType.error);
    switch (result) {
      case EditResult.saved:
        Navigator.pop(context, true);
      case EditResult.noChanges:
        AppMessenger.showSnackBar(context, title: l10n.info, message: l10n.noChangesToSave, type: MessengerType.info);
      case EditResult.nameTaken:
        error(l10n.nameTaken);
      case EditResult.phoneTaken:
        error(l10n.phoneInUseAlready);
      case EditResult.failed:
        error(l10n.failedToSaveChanges);
      case EditResult.invalid || EditResult.phoneNotVerified || EditResult.busy:
        break; // the fields already show what is wrong / nothing to do
    }
  }

  Future<bool> _showOtpDialog(String phone) async {
    var verified = false;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Dialog(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.verifyMobile,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                UniversalOtpStep(
                  destination: phone,
                  onVerified: () {
                    verified = true;
                    Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return verified;
  }

  String? _nameError(AppLocalizations l10n) {
    if (c.nameTaken) return l10n.nameTaken;
    return switch (c.nameProblem) {
      NameProblem.empty => l10n.enterFullName,
      NameProblem.length => l10n.nameLengthError,
      NameProblem.characters => l10n.nameCharError,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final busy = !_ready || c.isLoading || c.isSaving;
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            title: Text(l10n.editProfile, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!busy && !c.notFound)
                IconButton(
                  key: const Key('save-profile'),
                  icon: const Icon(Icons.check, color: AppColors.accentGold, size: 28),
                  onPressed: _save,
                  tooltip: l10n.save,
                ),
            ],
          ),
          body: busy
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
              : c.notFound
                  ? Center(child: Text(l10n.userNotFound, style: const TextStyle(color: Colors.white)))
                  : _form(l10n),
        );
      },
    );
  }

  Widget _form(AppLocalizations l10n) {
    final nameEdited = c.nameStatus != FieldStatus.ok || c.name.trim() != (c.original?.name ?? '').trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(photoUrl: c.photoUrl, newPhotoPath: c.newPhotoPath, onPick: _pickPhoto),
          const SizedBox(height: 20),
          _SectionHeader(l10n.publicInfoCaps),
          const SizedBox(height: 10),
          AuthTextField(
            key: const Key('edit-name'),
            controller: _name,
            hint: l10n.fullName,
            icon: Icons.person_outline,
            onChanged: c.onNameChanged,
            errorText: nameEdited ? _nameError(l10n) : null,
            isLoading: c.nameStatus == FieldStatus.checking,
            isSuccess: nameEdited && c.nameStatus == FieldStatus.ok,
          ),
          const SizedBox(height: 24),
          _SectionHeader(l10n.privateDetailsCaps),
          const SizedBox(height: 10),
          _Field(label: l10n.emailAddress, controller: _email, icon: Icons.email_outlined, readOnly: true),
          const SizedBox(height: 20),
          Text(l10n.phoneNumber, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          _PhoneField(
            initialCountry: _initialCountry,
            initialNumber: _initialNumber,
            controller: c,
            onChanged: (complete, iso) => c.onPhoneChanged(NumericUtils.normalize(complete, clean: true), iso),
          ),
          const SizedBox(height: 24),
          _SectionHeader(l10n.aboutMeCaps),
          const SizedBox(height: 10),
          _Field(
            key: const Key('edit-bio'),
            label: l10n.bio,
            controller: _bio,
            maxLines: 4,
            maxLength: ProfileEditPolicy.bioMaxLength,
            hint: l10n.writeShortIntro,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.newPhotoPath, required this.onPick});
  final String photoUrl;
  final String? newPhotoPath;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = newPhotoPath != null
        ? FileImage(File(newPhotoPath!))
        : (photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null);
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.cardBackground, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[800],
              backgroundImage: image,
              onBackgroundImageError: image == null ? null : (_, _) {},
              child: image == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              key: const Key('pick-photo'),
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final String? hint;
  final bool readOnly;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.white.withOpacity(0.02) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            readOnly: readOnly,
            keyboardType: keyboardType,
            style: TextStyle(color: readOnly ? Colors.white54 : Colors.white),
            cursorColor: AppColors.accentGold,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon:
                  icon != null ? Icon(icon, color: readOnly ? Colors.white38 : AppColors.accentGold, size: 22) : null,
              suffixIcon: readOnly ? const Icon(Icons.lock_outline, color: Colors.white24, size: 18) : null,
              border: InputBorder.none,
              counterText: '',
              contentPadding: maxLength != null
                  ? const EdgeInsets.fromLTRB(20, 16, 20, 32)
                  : const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          if (maxLength != null)
            Positioned(
              bottom: 8,
              right: 16,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) => Text(
                  '${value.text.length}/$maxLength',
                  style: TextStyle(
                    color: value.text.length > maxLength! ? Colors.redAccent : Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.initialCountry,
    required this.initialNumber,
    required this.controller,
    required this.onChanged,
  });

  final String initialCountry;
  final String initialNumber;
  final EditProfileController controller;
  final void Function(String completeNumber, String isoCode) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = controller;
    final edited = c.phone.trim() != (c.original?.phone ?? '').trim() || c.phoneStatus != FieldStatus.ok;
    final problem = switch (c.phoneProblem) {
      PhoneProblem.invalid => l10n.invalidMobileNumber,
      PhoneProblem.taken => l10n.phoneUsed,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !edited
                  ? Colors.white.withOpacity(0.05)
                  : (problem != null
                      ? Colors.redAccent
                      : (c.phoneStatus == FieldStatus.ok ? Colors.greenAccent : Colors.white.withOpacity(0.05))),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: IntlPhoneField(
            key: ValueKey('$initialCountry-$initialNumber'),
            invalidNumberMessage: l10n.invalidMobileNumber,
            style: const TextStyle(color: Colors.white),
            dropdownTextStyle: const TextStyle(color: Colors.white),
            dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: l10n.phoneNumber,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              counterText: '',
              suffixIcon: c.phoneStatus == FieldStatus.checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            initialCountryCode: initialCountry,
            initialValue: initialNumber,
            inputFormatters: [NumericUtils.digitFormatter],
            onChanged: (p) => onChanged(p.completeNumber, p.countryISOCode),
          ),
        ),
        if (edited && problem != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(problem, key: const Key('phone-error'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
      ],
    );
  }
}
