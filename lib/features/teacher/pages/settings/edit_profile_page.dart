import 'dart:async';
import 'dart:io';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:device_region/device_region.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/message/app_messenger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_number/phone_number.dart' as lib_phone;
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/widgets/auth_text_field.dart';
import 'dart:ui';
import 'package:calligro_app/core/utils/numeric_utils.dart';
import 'package:calligro_app/core/utils/image_utils.dart';
import 'package:calligro_app/features/auth/widgets/verification/universal_otp_step.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final _authService = AuthService();
  final _phoneUtil = lib_phone.PhoneNumberUtil();
  bool _isLoading = false;

  // Name validation state
  Timer? _nameDebounce;
  String? _nameError;
  bool _isCheckingName = false;
  bool _isNameValid = false;
  bool _isNameModified = false;

  // Phone validation state
  Timer? _phoneDebounce;
  String? _phoneError;
  bool _isCheckingPhone = false;
  bool _isPhoneValid = false;
  bool _isPhoneModified = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();


  // Phone Data
  String _completePhoneNumber = '';
  String _initialCountryCode = 'JO';
  String _initialNumberValue = '';

  // Image Picking
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String? _currentPhotoUrl;

  // --- STORE INITIAL VALUES ---
  String? _initialName;
  String? _initialPhone;
  String? _initialBio;

  @override
  void initState() {
    super.initState();
    _getInitialCountryCode();
    _fetchUserData();
  }

  Future<void> _getInitialCountryCode() async {
    try {
      // 1. Try SIM Card (Best)
      String? countryCode = await DeviceRegion.getSIMCountryCode();

      // 2. Fallback: Device System Region
      if (countryCode == null || countryCode.isEmpty) {
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        countryCode = locale.countryCode;
      }

      if (mounted && countryCode != null && countryCode.isNotEmpty) {
         // Only update if we haven't already loaded a saved phone number
         // But checking _isLoading or incomplete state is tricky async. 
         // Safest is to just update defaults. If fetchUserData overwrites it later, that's fine.
        setState(() {
           // Only overwrite if we haven't fetched a user-specific one yet
           if (_initialCountryCode == 'JO') { // 'JO' was the default
             _initialCountryCode = countryCode!.toUpperCase();
           }
        });
      }
    } catch (e) {
      debugPrint("Error getting country code: $e");
    }
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _phoneDebounce?.cancel();
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- NAME VALIDATION (same as register form) ---
  void _validateName(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (_nameDebounce?.isActive ?? false) _nameDebounce!.cancel();

    setState(() {
      _nameError = null;
      _isNameValid = false;
      _isCheckingName = true;
      _isNameModified = true;
    });

    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      setState(() {
        _isCheckingName = false;
        _nameError = l10n.enterFullName;
      });
      return;
    }

    // 1. Length Check (3-50)
    if (trimmedValue.length < 3 || trimmedValue.length > 50) {
      setState(() {
        _isCheckingName = false;
        _nameError = l10n.nameLengthError;
      });
      return;
    }

    // 2. Character Set Check (English, Arabic, Turkish letters and spaces)
    if (!RegExp(r'^(?=.*[\p{L}])[\p{L}\p{N}\s]+$', unicode: true).hasMatch(trimmedValue)) {
      setState(() {
        _isCheckingName = false;
        _nameError = l10n.nameCharError;
      });
      return;
    }

    // If name hasn't changed from original, it's still valid (it's their own name)
    if (trimmedValue == (_initialName ?? '').trim()) {
      setState(() {
        _isCheckingName = false;
        _isNameValid = true;
      });
      return;
    }

    _nameDebounce = Timer(const Duration(milliseconds: 600), () async {
      final isTaken = await _authService.isNameTaken(trimmedValue);
      if (!mounted) return;

      setState(() {
        _isCheckingName = false;
        if (isTaken) {
          _nameError = l10n.nameTaken;
          _isNameValid = false;
        } else {
          _nameError = null;
          _isNameValid = true;
        }
      });
    });
  }

  void _validatePhone(String phone, String isoCode) {
    final l10n = AppLocalizations.of(context)!;
    if (_phoneDebounce?.isActive ?? false) _phoneDebounce!.cancel();

    setState(() {
      _phoneError = null;
      _isPhoneValid = false;
      _isCheckingPhone = true; 
      _isPhoneModified = true;
      _completePhoneNumber = NumericUtils.normalize(phone, clean: true);
    });

    _phoneDebounce = Timer(const Duration(milliseconds: 600), () async {
      // 1. Format Check
      bool isValidFormat = false;
      try {
        isValidFormat = await _phoneUtil.validate(_completePhoneNumber, regionCode: isoCode);
      } catch (_) {
        isValidFormat = false;
      }

      if (!mounted) return;

      if (!isValidFormat) {
         setState(() {
           _isCheckingPhone = false;
           if (phone.length > 8) {
             _phoneError = l10n.invalidMobileNumber;
           }
         });
         return;
      }

      // If phone hasn't changed from original, it's still valid
      if (_completePhoneNumber == (_initialPhone ?? '').trim()) {
        setState(() {
          _isCheckingPhone = false;
          _isPhoneValid = true;
        });
        return;
      }

      // 2. Uniqueness Check
      final isTaken = await _authService.isPhoneTaken(_completePhoneNumber);
      if (!mounted) return;

      setState(() {
        _isCheckingPhone = false;
        if (isTaken) {
          _phoneError = l10n.phoneUsed;
          _isPhoneValid = false;
        } else {
          _phoneError = null;
          _isPhoneValid = true;
        }
      });
    });
  }

  // --- 1. FETCH DATA ---
  Future<void> _fetchUserData() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      _emailController.text = currentUser!.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final savedPhone = data['phone'] as String? ?? '';
        final savedName = data['name'] as String? ?? '';
        final savedBio = data['bio'] as String? ?? '';
        final savedPhoto = data['photoUrl'] as String?;

        String isoCode = 'JO';
        String number = '';
        if (savedPhone.startsWith('+962')) {
          isoCode = 'JO';
          number = savedPhone.substring(4);
        } else if (savedPhone.isNotEmpty) {
          number = savedPhone;
        }

        setState(() {
          _nameController.text = savedName;
          _bioController.text = savedBio;
          _currentPhotoUrl = savedPhoto;

          _completePhoneNumber = savedPhone;
          _initialCountryCode = isoCode;
          _initialNumberValue = number;

          _initialName = savedName;
          _initialPhone = savedPhone;
          _initialBio = savedBio;
          _isNameValid = true;
          _isPhoneValid = true;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. PICK IMAGE ---
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 75,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      // Fix EXIF rotation so Android shows the image the same way as iOS
      final File correctedFile = await fixExifRotation(imageFile);
      final String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profile_images')
          .child(currentUser!.uid)
          .child(fileName);
      final UploadTask uploadTask = storageRef.putFile(correctedFile);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  // --- 4. SAVE PROFILE ---
  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || currentUser == null) return;

    // Block save if name/phone has error or is still being checked
    if (_nameError != null || _isCheckingName || _phoneError != null || _isCheckingPhone) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String inputName = _nameController.text.trim();
      final String inputBio = _bioController.text.trim();
      final String inputPhone = _completePhoneNumber.trim();

      // Logic 1: Local Check
      final bool nameHasChanged = inputName != _initialName;
      final bool phoneHasChanged = inputPhone != _initialPhone;

      final l10n = AppLocalizations.of(context)!;
      if (inputName == _initialName &&
          inputPhone == _initialPhone &&
          inputBio == _initialBio &&
          _selectedImage == null) {
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: l10n.info,
            message: l10n.noChangesToSave,
            type: MessengerType.info,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Logic 2: Duplicates
      if (phoneHasChanged) {
        final QuerySnapshot phoneQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: inputPhone)
            .get();

        if (phoneQuery.docs.isNotEmpty) {
          if (phoneQuery.docs.first.id != currentUser!.uid) {
            throw l10n.phoneInUseAlready;
          }
        }

        // Prompt for OTP Verification
        setState(() => _isLoading = false);
        final bool isVerified = await _showPhoneOtpDialog(inputPhone);
        if (!isVerified) return;
        setState(() => _isLoading = true);
      }

      if (nameHasChanged) {
        final QuerySnapshot nameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: inputName)
            .get();

        if (nameQuery.docs.isNotEmpty) {
          if (nameQuery.docs.first.id != currentUser!.uid) {
            throw l10n.nameTaken;
          }
        }
      }

      // Logic 3: Save using WriteBatch
      String? finalPhotoUrl = _currentPhotoUrl;
      if (_selectedImage != null) {
        final String? newUrl = await _uploadImage(_selectedImage!);
        if (newUrl != null) {
          finalPhotoUrl = newUrl;
        }
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      final userRef = firestore.collection('users').doc(currentUser!.uid);
      final userDoc = await userRef.get();
      final role = userDoc.data()?['role'] ?? 'student';

      final Map<String, dynamic> updateData = {
        'name': inputName,
        'name_lower': inputName.toLowerCase(), // ✅ Update search index
        'phone': inputPhone,
        'bio': inputBio,
        'photoUrl': finalPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Update primary 'users' collection
      batch.set(userRef, updateData, SetOptions(merge: true));

      // 2. Update role-specific collection
      if (role == 'teacher') {
        batch.set(firestore.collection('teachers').doc(currentUser!.uid), updateData, SetOptions(merge: true));
      } else if (role == 'student') {
        batch.set(firestore.collection('students').doc(currentUser!.uid), updateData, SetOptions(merge: true));
      }

      // 3. Update locked_usernames if name changed
      if (nameHasChanged) {
        // Delete old username lock
        batch.delete(firestore.collection('locked_usernames').doc((_initialName ?? '').trim().toLowerCase()));
        
        // Create new username lock
        batch.set(
          firestore.collection('locked_usernames').doc(inputName.trim().toLowerCase()),
          {'uid': currentUser!.uid, 'createdAt': FieldValue.serverTimestamp()},
        );
      }

      // 4. Update locked_phones if phone changed
      if (phoneHasChanged) {
        if ((_initialPhone ?? '').isNotEmpty) {
           final oldCleanPhone = NumericUtils.normalize(_initialPhone!, clean: true);
           batch.delete(firestore.collection('locked_phones').doc(oldCleanPhone));
        }

        if (inputPhone.isNotEmpty) {
           final newCleanPhone = NumericUtils.normalize(inputPhone, clean: true);
           batch.set(
             firestore.collection('locked_phones').doc(newCleanPhone),
             {'uid': currentUser!.uid, 'email': currentUser!.email, 'createdAt': FieldValue.serverTimestamp()},
           );
        }
      }

      // --- LOGIC 4: Sync Redundant Data (Courses, Posts, Comments) ---
      // Note: We sync Name and Photo changes to other collections
      
      // 1. Sync to Courses
      final coursesQuery = await firestore
          .collection('courses')
          .where('teacherId', isEqualTo: currentUser!.uid)
          .get();
      
      for (var doc in coursesQuery.docs) {
        batch.update(doc.reference, {
          'teacherName': inputName,
          'teacherProfilePic': finalPhotoUrl,
        });
      }

      // 2. Sync to Community Posts
      final postsQuery = await firestore
          .collection('community_posts')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();
      
      for (var doc in postsQuery.docs) {
        batch.update(doc.reference, {
          'userName': inputName,
          'userImageUrl': finalPhotoUrl,
        });
      }

      // 3. Sync to Comments (Collection Group Query)
      final commentsQuery = await firestore
          .collectionGroup('comments')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();
      
      for (var doc in commentsQuery.docs) {
        batch.update(doc.reference, {
          'userName': inputName,
          'userPhotoUrl': finalPhotoUrl,
        });
      }

      await batch.commit();

      setState(() {
        _currentPhotoUrl = finalPhotoUrl;
        _selectedImage = null;
        _initialName = inputName;
        _initialPhone = inputPhone;
        _initialBio = inputBio;
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith("Exception: ")) {
          errorMsg = errorMsg.substring(11);
        }
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: errorMsg,
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showPhoneOtpDialog(String phoneNumber) async {
    bool isVerified = false;
    final l10n = AppLocalizations.of(context)!;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BackdropFilter(
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
                       Text(
                         l10n.verifyMobile,
                         style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                       ),
                       IconButton(
                         icon: const Icon(Icons.close, color: Colors.white70),
                         onPressed: () => Navigator.pop(dialogContext),
                       ),
                     ],
                   ),
                   const SizedBox(height: 10),
                   UniversalOtpStep(
                     destination: phoneNumber,
                     onVerified: () {
                       isVerified = true;
                       Navigator.pop(dialogContext);
                     },
                   ),
                 ],
               ),
             ),
          ),
        );
      },
    );
    return isVerified;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.editProfile,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(
                Icons.check,
                color: AppColors.accentGold,
                size: 28,
              ),
              onPressed: _saveProfile,
              tooltip: AppLocalizations.of(context)!.save,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarSection(),
                    // Reduced spacing here (was 32)
                    const SizedBox(height: 20),

                    _buildSectionHeader(AppLocalizations.of(context)!.publicInfoCaps),
                    // Reduced spacing here (was 16)
                    const SizedBox(height: 10),

                    AuthTextField(
                      controller: _nameController,
                      hint: AppLocalizations.of(context)!.fullName,
                      icon: Icons.person_outline,
                      onChanged: _validateName,
                      errorText: _isNameModified ? _nameError : null,
                      isLoading: _isCheckingName,
                      isSuccess: _isNameModified && _isNameValid,
                    ),

                    // Reduced spacing here (was 32)
                    const SizedBox(height: 24),

                    _buildSectionHeader(AppLocalizations.of(context)!.privateDetailsCaps),
                    // Reduced spacing here (was 16)
                    const SizedBox(height: 10),

                    _buildTextField(
                      label: AppLocalizations.of(context)!.emailAddress,
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)!.phoneNumber,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    _buildPhoneField(),

                    // Reduced spacing here (was 32)
                    const SizedBox(height: 24),

                    _buildSectionHeader(AppLocalizations.of(context)!.aboutMeCaps),
                    const SizedBox(height: 10),

                    _buildTextField(
                      label: AppLocalizations.of(context)!.bio,
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 150,
                      hint: AppLocalizations.of(context)!.writeShortIntro,
                      keyboardType: TextInputType.multiline,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS ---
  Widget _buildValidationIcon(bool isLoading, bool isValid) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textColor),
            )
          : isValid
              ? Container(
                  key: const ValueKey('success'),
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.greenAccent),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.check, color: Colors.black, size: 14),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              // Reduced radius (was 60)
              radius: 50,
              backgroundColor: Colors.grey[800],
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!) as ImageProvider
                  : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(_currentPhotoUrl!)
                        : null),
              child:
                  (_selectedImage == null &&
                      (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty))
                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8), // Slightly smaller padding
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 18, // Slightly smaller icon
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.accentGold,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
    String? hint,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final EdgeInsets contentPadding = maxLength != null
        ? const EdgeInsets.fromLTRB(20, 16, 20, 32)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 16);

    return Container(
      decoration: BoxDecoration(
        color: isReadOnly
            ? Colors.white.withOpacity(0.02)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            readOnly: isReadOnly,
            keyboardType: keyboardType,
            style: TextStyle(color: isReadOnly ? Colors.white54 : Colors.white),
            cursorColor: AppColors.accentGold,
            validator: (value) =>
                (!isReadOnly &&
                    value != null &&
                    value.isEmpty &&
                    label == "Full Name")
                ? AppLocalizations.of(context)!.nameRequired
                : null,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: icon != null
                  ? Icon(
                      icon,
                      color: isReadOnly ? Colors.white38 : AppColors.accentGold,
                      size: 22,
                    )
                  : null,
              suffixIcon: isReadOnly
                  ? const Icon(
                      Icons.lock_outline,
                      color: Colors.white24,
                      size: 18,
                    )
                  : null,
              border: InputBorder.none,
              counterText: "",
              contentPadding: contentPadding,
            ),
          ),
          if (maxLength != null)
            Positioned(
              bottom: 8,
              right: 16,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return Text(
                    "${value.text.length}/$maxLength",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPhoneModified
                      ? (_phoneError != null
                          ? Colors.redAccent
                          : (_isPhoneValid ? Colors.greenAccent : Colors.white.withOpacity(0.05)))
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: IntlPhoneField(
                invalidNumberMessage: AppLocalizations.of(context)!.invalidMobileNumber,
                style: const TextStyle(color: Colors.white),
                dropdownTextStyle: const TextStyle(color: Colors.white),
                dropdownIcon:
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)!.phoneNumber,
                  hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.3)),
                  counterText: "",
                ),
                initialCountryCode: _initialCountryCode,
                initialValue: _initialNumberValue,
                inputFormatters: [NumericUtils.digitFormatter],
                onChanged: (phone) {
                  _validatePhone(
                    phone.completeNumber,
                    phone.countryISOCode,
                  );
                },
              ),
            ),
            PositionedDirectional(
              end: 16,
              child: _buildValidationIcon(_isCheckingPhone, _isPhoneModified && _isPhoneValid),
            ),
          ],
        ),
        if (_isPhoneModified && _phoneError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              _phoneError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
