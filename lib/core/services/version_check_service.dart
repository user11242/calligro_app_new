import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calligro_app/core/theme/colors.dart';

enum VersionStatus {
  upToDate,
  optionalUpdate,
  forceUpdate,
}

class VersionCheckResult {
  final VersionStatus status;
  final int currentBuild;
  final String currentVersion;
  final int minRequiredBuild;
  final int latestBuild;
  final String latestVersionName;
  final bool isForceUpdate;
  final String updateTitle;
  final String updateMessage;
  final String storeUrl;

  const VersionCheckResult({
    required this.status,
    required this.currentBuild,
    required this.currentVersion,
    required this.minRequiredBuild,
    required this.latestBuild,
    required this.latestVersionName,
    required this.isForceUpdate,
    required this.updateTitle,
    required this.updateMessage,
    required this.storeUrl,
  });
}

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _defaultIosUrl =
      'https://apps.apple.com/app/calligro/id6670783307';
  static const String _defaultAndroidUrl =
      'https://play.google.com/store/apps/details?id=com.yazan.calligroApp';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('app_config').doc('version_control');

  Stream<DocumentSnapshot<Map<String, dynamic>>> getConfigStream() {
    return _configRef.snapshots();
  }

  Future<Map<String, dynamic>> getConfig() async {
    try {
      final doc = await _configRef.get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      debugPrint('[VersionCheckService] Failed to load config: $e');
    }

    // Default configuration if not found
    return {
      'min_required_build': 100,
      'latest_build': 104,
      'latest_version_name': '1.0.23',
      'is_force_update': false,
      'ios_store_url': _defaultIosUrl,
      'android_store_url': _defaultAndroidUrl,
      'update_title_ar': 'تحديث جديد متاح',
      'update_title_en': 'New Update Available',
      'update_message_ar':
          'يرجى تحديث كاليجرو للاستفادة من أحدث الميزات وتحسينات الأداء.',
      'update_message_en':
          'Please update Calligro to enjoy the latest features and performance improvements.',
      'available_versions': [
        {'build': 105, 'version': '1.0.23', 'label': 'v1.0.23 (Build 105)'},
        {'build': 104, 'version': '1.0.23', 'label': 'v1.0.23 (Build 104)'},
        {'build': 103, 'version': '1.0.22', 'label': 'v1.0.22 (Build 103)'},
        {'build': 102, 'version': '1.0.21', 'label': 'v1.0.21 (Build 102)'},
        {'build': 101, 'version': '1.0.21', 'label': 'v1.0.21 (Build 101)'},
        {'build': 100, 'version': '1.0.20', 'label': 'v1.0.20 (Build 100)'},
      ],
    };
  }

  Future<VersionCheckResult> checkVersion({bool isArabic = true}) async {
    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('[VersionCheckService] Failed to read package info: $e');
      packageInfo = PackageInfo(
        appName: 'Calligro',
        packageName: 'com.yazan.calligroApp',
        version: '1.0.23',
        buildNumber: '104',
      );
    }

    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 104;
    final currentVersion = packageInfo.version;

    final config = await getConfig();
    final minRequiredBuild = (config['min_required_build'] as num?)?.toInt() ?? 100;
    final latestBuild = (config['latest_build'] as num?)?.toInt() ?? 104;
    final latestVersionName = (config['latest_version_name'] as String?) ?? currentVersion;
    final isForceUpdate = (config['is_force_update'] as bool?) ?? false;

    final updateTitle = (isArabic
            ? config['update_title_ar']
            : config['update_title_en']) ??
        (isArabic ? 'تحديث متاح للتطبيق' : 'App Update Available');

    final updateMessage = (isArabic
            ? config['update_message_ar']
            : config['update_message_en']) ??
        (isArabic
            ? 'يرجى تحديث كاليجرو للاستفادة من أحدث الميزات وتحسينات الأداء.'
            : 'Please update Calligro to enjoy the latest features and performance improvements.');

    final storeUrl = Platform.isIOS
        ? ((config['ios_store_url'] as String?)?.isNotEmpty == true
            ? config['ios_store_url'] as String
            : _defaultIosUrl)
        : ((config['android_store_url'] as String?)?.isNotEmpty == true
            ? config['android_store_url'] as String
            : _defaultAndroidUrl);

    VersionStatus status;
    if (currentBuild < minRequiredBuild) {
      status = isForceUpdate ? VersionStatus.forceUpdate : VersionStatus.optionalUpdate;
    } else if (currentBuild < latestBuild) {
      status = VersionStatus.optionalUpdate;
    } else {
      status = VersionStatus.upToDate;
    }

    return VersionCheckResult(
      status: status,
      currentBuild: currentBuild,
      currentVersion: currentVersion,
      minRequiredBuild: minRequiredBuild,
      latestBuild: latestBuild,
      latestVersionName: latestVersionName,
      isForceUpdate: isForceUpdate,
      updateTitle: updateTitle,
      updateMessage: updateMessage,
      storeUrl: storeUrl,
    );
  }

  Future<void> saveConfig({
    required int minRequiredBuild,
    required bool isForceUpdate,
    required int latestBuild,
    required String latestVersionName,
    required List<Map<String, dynamic>> availableVersions,
    String? updateTitleAr,
    String? updateTitleEn,
    String? updateMessageAr,
    String? updateMessageEn,
    String? iosStoreUrl,
    String? androidStoreUrl,
  }) async {
    await _configRef.set({
      'min_required_build': minRequiredBuild,
      'is_force_update': isForceUpdate,
      'latest_build': latestBuild,
      'latest_version_name': latestVersionName,
      'available_versions': availableVersions,
      'update_title_ar': updateTitleAr ?? 'تحديث جديد متاح',
      'update_title_en': updateTitleEn ?? 'New Update Available',
      'update_message_ar': updateMessageAr ??
          'يرجى تحديث كاليجرو للاستفادة من أحدث الميزات وتحسينات الأداء.',
      'update_message_en': updateMessageEn ??
          'Please update Calligro to enjoy the latest features and performance improvements.',
      'ios_store_url': iosStoreUrl ?? _defaultIosUrl,
      'android_store_url': androidStoreUrl ?? _defaultAndroidUrl,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> launchStore(String storeUrl) async {
    final uri = Uri.parse(storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[VersionCheckService] Failed to launch store URL: $e');
    }
  }

  Future<bool> showUpdateDialog(
    BuildContext context,
    VersionCheckResult result,
  ) async {
    final isForced = result.status == VersionStatus.forceUpdate;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final dismissed = await showDialog<bool>(
      context: context,
      barrierDismissible: !isForced,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isForced,
          child: Dialog(
            backgroundColor: const Color(0xFF1E2026),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isForced
                    ? AppColors.accentGold.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Icon / Upgrade Graphic
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentGold,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      size: 38,
                      color: AppColors.accentGold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    isForced
                        ? (isArabic
                            ? 'تحديث إجباري للتطبيق'
                            : 'Mandatory Update Required')
                        : result.updateTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Version tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${isArabic ? "الإصدار الجديد" : "New Version"}: v${result.latestVersionName} (${result.latestBuild})',
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    result.updateMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // "Update Now" Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => launchStore(result.storeUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'تحديث الآن' : 'Update Now',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // "Later" button only if NOT forced
                  if (!isForced) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        isArabic ? 'لاحقاً' : 'Later',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    return dismissed ?? false;
  }
}
