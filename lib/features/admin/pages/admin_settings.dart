import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/auth/data/services/auth_service.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// Reuse existing pages where possible
import '../../teacher/pages/settings/edit_profile_page.dart';
import '../../teacher/pages/settings/language_settings_page.dart';
import '../../teacher/pages/settings/help_center_page.dart';
import '../../teacher/pages/settings/security_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/onBoarding', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppMessenger.showSnackBar(context, title: l10n.error, message: e.toString(), type: MessengerType.error);
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentGold, width: 2),
                  ),
                  child: const Icon(Icons.edit_road, size: 40, color: AppColors.accentGold),
                ),
                const SizedBox(height: 16),
                const Text("Calligro", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text("v1.0.0 (Admin Console)", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.aboutDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentGold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(AppLocalizations.of(context)!.close, style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppLocalizations.of(context)!.adminSettings, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildSectionHeader(AppLocalizations.of(context)!.adminAccountHeader),
              _buildSettingsItem(
                context,
                icon: Icons.edit_note,
                title: AppLocalizations.of(context)!.editProfile,
                subtitle: AppLocalizations.of(context)!.editProfileAdminSubtitle,
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                  if (result == true && mounted) {
                    final l10n = AppLocalizations.of(context)!;
                    AppMessenger.showSnackBar(context, title: l10n.success, message: l10n.profileUpdated, type: MessengerType.success);
                  }
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.lock_outline,
                title: AppLocalizations.of(context)!.security,
                subtitle: AppLocalizations.of(context)!.securityAdminSubtitle,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityPage())),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(AppLocalizations.of(context)!.preferencesHeader),
              _buildSettingsItem(
                context,
                icon: Icons.language,
                title: AppLocalizations.of(context)!.language,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageSettingsPage())),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(AppLocalizations.of(context)!.supportHeader),
              _buildSettingsItem(
                context,
                icon: Icons.help_outline,
                title: AppLocalizations.of(context)!.helpCenter,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterPage())),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.info_outline,
                title: AppLocalizations.of(context)!.aboutCalligro,
                onTap: () => _showAboutDialog(context),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, size: 20),
                      const SizedBox(width: 10),
                      Text(AppLocalizations.of(context)!.signOut, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(color: AppColors.accentGold, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
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
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
