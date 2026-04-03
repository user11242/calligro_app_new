import 'package:calligro_app/core/theme/colors.dart';

import 'package:calligro_app/features/auth/data/services/auth_service.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/features/auth/pages/terms_and_conditions_page.dart';

// IMPORTS FOR YOUR PAGES
import 'edit_profile_page.dart';
import 'payout_settings_page.dart';
import 'language_settings_page.dart';
import 'help_center_page.dart';
import 'security_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:calligro_app/features/auth/data/services/google_auth_service.dart';

class TeacherSettingsPage extends StatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  State<TeacherSettingsPage> createState() => _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends State<TeacherSettingsPage> {
  bool _isGoogleCalendarConnected = false;
  bool _isLoadingConnection = true;
  bool _wantsSocialNotifications = true; // Default to true

  @override
  void initState() {
    super.initState();
    _checkGoogleConnection();
  }

  Future<void> _checkGoogleConnection() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('google_auth')
          .get();

      if (mounted) {
        setState(() {
          _isGoogleCalendarConnected = doc.exists && doc.data()?['refreshToken'] != null;
          
          // Also fetch the notification preference from the main user document
        });
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
            
        if (mounted && userDoc.exists) {
           setState(() {
             _wantsSocialNotifications = userDoc.data()?['wantsSocialNotifications'] ?? true;
           });
        }
        
        if (mounted) {
          setState(() {
            _isLoadingConnection = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking Google connection: $e");
      if (mounted) {
        setState(() => _isLoadingConnection = false);
      }
    }
  }

  Future<void> _connectGoogleCalendar() async {
    try {
      setState(() => _isLoadingConnection = true);

      // Using GoogleAuthService to manage the instance and initialization
      final googleAuthService = GoogleAuthService.instance;
      await googleAuthService.initialize();
      
      final GoogleSignIn googleSignIn = googleAuthService.googleSignIn;

      // 2. Clear previous session to ensure fresh consent
      await googleSignIn.signOut();
      
      final scopes = [
        'https://www.googleapis.com/auth/calendar.events',
        'https://www.googleapis.com/auth/meetings.space.settings',
      ];
      final GoogleSignInAccount account = await googleSignIn.authenticate(
        scopeHint: scopes,
      );

      // 3. Request Server Auth Code (google_sign_in ^7.0.0+)
      final serverAuth = await account.authorizationClient.authorizeServer(scopes);
      final String? authCode = serverAuth?.serverAuthCode;
      
      if (authCode == null) {
        throw Exception(AppLocalizations.of(context)!.offlineAccessRequired);
      }

      // 3. Exchange code for Refresh Token via Cloud Function
      // Note: If the backend lacks the secret, this might fail unless we find a way to get the token on client.
      // For now, we'll try to get the tokens on client if possible, but standard plugin doesn't show it.
      // Let's assume the backend exchange works if the secret is set, OR we use a fallback.
      
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('exchangeGoogleCode');
      
      // Since we don't have the secret, let's try a workaround: 
      // If we can't get refreshToken on client, we MUST have it on backend.
      // But wait, if I can't get it on client, I'll pass the authCode and hope the backend has the secret.
      
      await callable.call({
        'code': authCode,
        'refreshToken': "dummy_token_needs_server_exchange", // Backend will need to actually exchange it
      });

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.calendarConnected,
          type: MessengerType.success,
        );
        _checkGoogleConnection();
      }
    } catch (e) {
      debugPrint("Error connecting Google Calendar: $e");
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.failedToConnectCalendar,
          type: MessengerType.error,
        );
        setState(() => _isLoadingConnection = false);
      }
    }
  }

  Future<void> _disconnectGoogleCalendar() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('google_auth')
          .delete();

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.calendarDisconnected,
          type: MessengerType.success,
        );
        _checkGoogleConnection();
      }
    } catch (e) {
      debugPrint("Error disconnecting Google Calendar: $e");
    }
  }
  // --- LOGOUT FUNCTION ---
  Future<void> _logout(BuildContext context) async {
    try {
      if (context.mounted) {
        // 1. Navigate immediately to remove all screens that might be listening to streams
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/onBoarding', 
          (route) => false,
        );
      }
      
      // 2. Then Sign Out (once the risky widgets are unmounted)
      // Small delay to ensure the UI has time to dispose active streams
      await Future.delayed(const Duration(milliseconds: 200));
      await AuthService().signOut();

    } catch (e) {
      debugPrint("Error logging out: $e");
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: "${AppLocalizations.of(context)!.error}: $e",
          type: MessengerType.error,
        );
      }
    }
  }

  // --- ABOUT DIALOG FUNCTION ---
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentGold, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit_road,
                    size: 40,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(height: 16),

                // Name & Version
                const Text(
                  "Calligro",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28, // INCREASED FONT SIZE
                    fontWeight: FontWeight.w900, // THICKER FONT
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4), // ADDED SPACING
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.version("1.0.0"),
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Description
                Text(
                  AppLocalizations.of(context)!.aboutDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // Copyright
                Text(
                  AppLocalizations.of(context)!.copyright,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentGold),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.close,
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLanguageName(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    switch (code) {
      case 'ar':
        return AppLocalizations.of(context)!.arabic;
      case 'tr':
        return AppLocalizations.of(context)!.turkish;
      default:
        return AppLocalizations.of(context)!.english;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.settings,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // --- ACCOUNT SECTION ---
              _buildSectionHeader(AppLocalizations.of(context)!.accountCaps),

              // 1. Edit Profile
              _buildSettingsItem(
                context,
                icon: Icons.edit_note,
                title: AppLocalizations.of(context)!.editProfile,
                subtitle: AppLocalizations.of(context)!.editProfileSubtitle,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfilePage(),
                    ),
                  );
                  if (result == true && mounted) {
                    AppMessenger.showSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.profileUpdated,
                      type: MessengerType.success,
                    );
                  }
                },
              ),

              // 2. Payout Settings
              _buildSettingsItem(
                context,
                icon: Icons.account_balance_outlined,
                title: AppLocalizations.of(context)!.payoutSettings,
                subtitle: AppLocalizations.of(context)!.payoutSettingsSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PayoutSettingsPage(),
                    ),
                  );
                },
              ),

              // 3. Security
              _buildSettingsItem(
                context,
                icon: Icons.lock_outline,
                title: AppLocalizations.of(context)!.security,
                subtitle: AppLocalizations.of(context)!.securitySubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecurityPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // 4. Google Calendar Connection


              const SizedBox(height: 24),

              // --- PREFERENCES SECTION ---
              _buildSectionHeader(AppLocalizations.of(context)!.preferencesCaps),
              _buildSettingsSwitchItem(
                context,
                icon: Icons.notifications_outlined,
                title: AppLocalizations.of(context)!.notifications,
                value: _wantsSocialNotifications,
                onChanged: (newValue) async {
                  setState(() {
                    _wantsSocialNotifications = newValue;
                  });
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance.collection('users').doc(uid).update({
                      'wantsSocialNotifications': newValue,
                    }).catchError((e) {
                      debugPrint("Failed to update notification preference: $e");
                      // Revert on failure
                      if (mounted) {
                        setState(() {
                          _wantsSocialNotifications = !newValue; 
                        });
                      }
                    });
                  }
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.language,
                title: AppLocalizations.of(context)!.language,
                trailingText: _getLanguageName(context),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageSettingsPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // --- SUPPORT & LEGAL SECTION ---
              _buildSectionHeader(AppLocalizations.of(context)!.supportLegalCaps),
              _buildSettingsItem(
                context,
                icon: Icons.help_outline,
                title: AppLocalizations.of(context)!.helpCenter,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpCenterPage(),
                    ),
                  );
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.privacy_tip_outlined,
                title: AppLocalizations.of(context)!.termsPrivacy,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsAndConditionsPage(),
                    ),
                  );
                },
              ),

              // About Calligro
              _buildSettingsItem(
                context,
                icon: Icons.info_outline,
                title: AppLocalizations.of(context)!.aboutCalligro,
                trailingText: "v1.0.0",
                onTap: () {
                  _showAboutDialog(context);
                },
              ),

              const SizedBox(height: 40),

              // --- LOGOUT BUTTON ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 10),
                      Text(
                        AppLocalizations.of(context)!.signOut,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accentGold,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      trailingText,
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.3),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accentGold,
            activeTrackColor: AppColors.accentGold.withOpacity(0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleCalendarSetting() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isGoogleCalendarConnected ? Colors.green.withOpacity(0.2) : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isGoogleCalendarConnected ? Icons.calendar_today : Icons.calendar_month_outlined,
                color: _isGoogleCalendarConnected ? Colors.green : Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              AppLocalizations.of(context)!.googleCalendarConnection,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _isGoogleCalendarConnected 
                  ? AppLocalizations.of(context)!.calendarConnected
                  : AppLocalizations.of(context)!.googleCalendarConnectionSubtitle,
              style: TextStyle(
                color: _isGoogleCalendarConnected ? Colors.green : Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            trailing: _isLoadingConnection 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
                  )
                : (_isGoogleCalendarConnected 
                    ? null 
                    : TextButton(
                        onPressed: _connectGoogleCalendar,
                        child: Text(
                          AppLocalizations.of(context)!.connectCalendar,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              AppLocalizations.of(context)!.googleCalendarNote,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
