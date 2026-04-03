import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/message/app_messenger.dart';

class PayoutSettingsPage extends StatefulWidget {
  final bool isFromWizard;
  const PayoutSettingsPage({super.key, this.isFromWizard = false});

  @override
  State<PayoutSettingsPage> createState() => _PayoutSettingsPageState();
}

class _PayoutSettingsPageState extends State<PayoutSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // Track the User's selection vs What is saved in DB
  String _selectedMethod = 'cliq'; // The one the user is clicking/viewing
  String? _savedMethod; // The one currently active in Firebase

  // --- CONTROLLERS ---
  final TextEditingController _cliqAliasController = TextEditingController();
  final TextEditingController _cliqNameController = TextEditingController();
  final TextEditingController _wuNameController = TextEditingController();
  final TextEditingController _wuCityController = TextEditingController();
  final TextEditingController _wuPhoneController = TextEditingController();
  final TextEditingController _wuPurposeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPayoutSettings();
  }

  @override
  void dispose() {
    _cliqAliasController.dispose();
    _cliqNameController.dispose();
    _wuNameController.dispose();
    _wuCityController.dispose();
    _wuPhoneController.dispose();
    _wuPurposeController.dispose();
    super.dispose();
  }

  // --- 1. FETCH DATA ---
  Future<void> _fetchPayoutSettings() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('payoutSettings')) {
        final data = doc.data()!['payoutSettings'] as Map<String, dynamic>;

        setState(() {
          // Set both the UI selection and the "Saved" tracker
          _savedMethod = data['selectedMethod'] ?? 'cliq';
          _selectedMethod = _savedMethod!;

          // Load CliQ
          final cliq = data['cliq'] ?? {};
          _cliqAliasController.text = cliq['alias'] ?? '';
          _cliqNameController.text = cliq['holderName'] ?? '';

          // Load WU
          final wu = data['western'] ?? {};
          _wuNameController.text = wu['fullName'] ?? '';
          _wuCityController.text = wu['city'] ?? '';
          _wuPhoneController.text = wu['phone'] ?? '';
          _wuPurposeController.text = wu['purpose'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error loading payout settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. CONFIRMATION LOGIC ---
  void _onSavePressed() {
    FocusScope.of(context).unfocus();

    // 1. Basic Validation
    if (!_formKey.currentState!.validate()) return;

    // 2. Check if the user is changing the method
    // If _savedMethod is null (first time), we just save.
    // If they are the same, we just save (updating details).
    // If they are DIFFERENT, we warn the user.
    if (_savedMethod != null && _selectedMethod != _savedMethod) {
      _showChangeConfirmationDialog();
    } else {
      _performSave();
    }
  }

  void _showChangeConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          AppLocalizations.of(context)!.changePayoutMethodQuestion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context)!.payoutMethodSwitchWarning(
            _getReadableName(_savedMethod!),
            _getReadableName(_selectedMethod),
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performSave(); // Proceed to save
            },
            child: Text(
              AppLocalizations.of(context)!.confirmChange,
              style: const TextStyle(color: AppColors.accentGold),
            ),
          ),
        ],
      ),
    );
  }

  String _getReadableName(String key) {
    switch (key) {
      case 'cliq':
        return 'CliQ';
      case 'western':
        return AppLocalizations.of(context)!.westernUnion;
      default:
        return key;
    }
  }

  // --- 3. SAVE DATA (ACTUAL LOGIC) ---
  Future<void> _performSave() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> payoutData = {
        'selectedMethod': _selectedMethod,

        // Smart wiping: Only save active method, wipe others
        'cliq': _selectedMethod == 'cliq'
            ? {
                'alias': _cliqAliasController.text.trim(),
                'holderName': _cliqNameController.text.trim(),
              }
            : null,
        'western': _selectedMethod == 'western'
            ? {
                'fullName': _wuNameController.text.trim(),
                'city': _wuCityController.text.trim(),
                'phone': _wuPhoneController.text.trim(),
                'purpose': _wuPurposeController.text.trim(),
              }
            : null,
      };

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final userRef = firestore.collection('users').doc(currentUser!.uid);
      final teacherRef = firestore.collection('teachers').doc(currentUser!.uid);

      final updateData = {
        'payoutSettings': payoutData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(userRef, updateData, SetOptions(merge: true));
      batch.set(teacherRef, updateData, SetOptions(merge: true));

      await batch.commit();

      // Update local state to reflect the new "Saved" status
      setState(() {
        _savedMethod = _selectedMethod;
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: "${AppLocalizations.of(context)!.error}: $e",
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.payoutSettings,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
              onPressed: _onSavePressed,
              tooltip: AppLocalizations.of(context)!.saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      AppLocalizations.of(context)!.selectPayoutMethodCaps,
                    ),
                    const SizedBox(height: 15),

                    // --- METHOD SELECTOR CARDS ---
                    SizedBox(
                      height: 120,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildMethodCard(
                              value: "cliq",
                              assetPath: "assets/backgrounds/cliq.png",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMethodCard(
                              value: "western",
                              assetPath: "assets/backgrounds/union.png",
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- DYNAMIC FORM ---
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildActiveForm(),
                    ),

                    const SizedBox(height: 40),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.payoutsProcessedMonthly,
                              style: TextStyle(
                                color: Colors.blue[100],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (widget.isFromWizard) ...[
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onSavePressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.accentGold.withOpacity(0.4),
                          ),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.saveAndReturnToCourse.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // --- DYNAMIC FORM BUILDER ---
  Widget _buildActiveForm() {
    switch (_selectedMethod) {
      case 'cliq':
        return Column(
          key: const ValueKey('cliq'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionHeader(
                  AppLocalizations.of(context)!.cliqDetailsCaps,
                ),
                const SizedBox(width: 8),
                _buildJordanTag(),
              ],
            ),
            const SizedBox(height: 15),
            _buildTextField(
              label: AppLocalizations.of(context)!.cliqAliasHint,
              controller: _cliqAliasController,
              icon: Icons.link,
              hint: "e.g. 079XXXXXXX",
              isRequired: true,
              // We use text here because Aliases can be names too, not just phones
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              label: AppLocalizations.of(context)!.accountHolderNameOptional,
              controller: _cliqNameController,
              icon: Icons.person_outline,
              hint: AppLocalizations.of(context)!.optional,
              isRequired: false,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        );

      case 'western':
        return Column(
          key: const ValueKey('western'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              AppLocalizations.of(context)!.wuMoneyTransferCaps,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              label: AppLocalizations.of(context)!.receiverFullName,
              controller: _wuNameController,
              icon: Icons.person_pin_outlined,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              label: AppLocalizations.of(context)!.cityCountry,
              controller: _wuCityController,
              icon: Icons.location_city,
              hint: "e.g. Amman, Jordan",
              isRequired: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              label: AppLocalizations.of(context)!.phoneNumber,
              controller: _wuPhoneController,
              icon: Icons.phone_iphone,
              isRequired: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              label: AppLocalizations.of(context)!.purposeOfTransferOptional,
              controller: _wuPurposeController,
              icon: Icons.info_outline,
              hint: AppLocalizations.of(context)!.optional,
              isRequired: false,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // --- WIDGET HELPERS ---

  Widget _buildMethodCard({
    required String value,
    String? title,
    String? assetPath,
    IconData? iconData,
  }) {
    bool isSelected = _selectedMethod == value;
    bool isSavedActive =
        _savedMethod == value; // Check if this is the "Live" method

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMethod = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          // If selected, Gold border. If NOT selected but is the Saved method, Green border.
          border: Border.all(
            color: isSelected
                ? AppColors.accentGold
                : (isSavedActive
                      ? Colors.greenAccent
                      : Colors.white.withOpacity(0.1)),
            width: isSavedActive ? 2 : (isSelected ? 2 : 1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. The Content (Image or Icon)
              if (assetPath != null)
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  color: isSelected
                      ? null
                      : Colors.white.withOpacity(0.8), // Dim untoggled images slightly
                  colorBlendMode: isSelected ? null : BlendMode.modulate,
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconData,
                        color: isSelected ? Colors.black : Colors.white54,
                        size: 35,
                      ),
                      if (title != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // 2. The "Active" Badge (Only shows if this is the SAVED method)
              if (isSavedActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green, // Active Green
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.activeCaps,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJordanTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Text(
        AppLocalizations.of(context)!.jordanOnly,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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
    String? hint,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        cursorColor: AppColors.accentGold,

        // Settings for keyboard/text type
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,

        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return AppLocalizations.of(context)!.validationRequired(label);
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: icon != null
              ? Icon(icon, color: AppColors.accentGold, size: 22)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
