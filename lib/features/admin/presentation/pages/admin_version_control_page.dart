import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:calligro_app/core/services/version_check_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/message/app_messenger.dart';

class AdminVersionControlPage extends StatefulWidget {
  const AdminVersionControlPage({super.key});

  @override
  State<AdminVersionControlPage> createState() => _AdminVersionControlPageState();
}

class _AdminVersionControlPageState extends State<AdminVersionControlPage> {
  final VersionCheckService _versionService = VersionCheckService();

  bool _isLoading = true;
  bool _isSaving = false;

  int _currentDeviceBuild = 104;
  String _currentDeviceVersion = '1.0.23';

  // Form State
  int? _selectedMinBuild;
  bool _isForceUpdate = false;

  List<Map<String, dynamic>> _availableVersions = [];

  final TextEditingController _titleArCtrl = TextEditingController();
  final TextEditingController _titleEnCtrl = TextEditingController();
  final TextEditingController _msgArCtrl = TextEditingController();
  final TextEditingController _msgEnCtrl = TextEditingController();
  final TextEditingController _iosUrlCtrl = TextEditingController();
  final TextEditingController _androidUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleArCtrl.dispose();
    _titleEnCtrl.dispose();
    _msgArCtrl.dispose();
    _msgEnCtrl.dispose();
    _iosUrlCtrl.dispose();
    _androidUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentDeviceBuild = int.tryParse(packageInfo.buildNumber) ?? 104;
      _currentDeviceVersion = packageInfo.version;
    } catch (e) {
      debugPrint('Failed to read package info: $e');
    }

    final config = await _versionService.getConfig();

    final rawList = config['available_versions'] as List<dynamic>? ?? [];
    _availableVersions = rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Default builds list if empty
    if (_availableVersions.isEmpty) {
      _availableVersions = [
        {'build': 105, 'version': '1.0.23', 'label': 'v1.0.23 (Build 105)'},
        {'build': 104, 'version': '1.0.23', 'label': 'v1.0.23 (Build 104)'},
        {'build': 103, 'version': '1.0.22', 'label': 'v1.0.22 (Build 103)'},
        {'build': 102, 'version': '1.0.21', 'label': 'v1.0.21 (Build 102)'},
        {'build': 101, 'version': '1.0.21', 'label': 'v1.0.21 (Build 101)'},
        {'build': 100, 'version': '1.0.20', 'label': 'v1.0.20 (Build 100)'},
      ];
    }

    _selectedMinBuild = (config['min_required_build'] as num?)?.toInt() ?? _availableVersions.first['build'] as int;
    _isForceUpdate = (config['is_force_update'] as bool?) ?? false;

    _titleArCtrl.text = config['update_title_ar'] ?? 'تحديث جديد متاح';
    _titleEnCtrl.text = config['update_title_en'] ?? 'New Update Available';
    _msgArCtrl.text = config['update_message_ar'] ??
        'يرجى تحديث كاليجرو للاستفادة من أحدث ميزات تسجيل الدروس وشاشة الاجتماعات.';
    _msgEnCtrl.text = config['update_message_en'] ??
        'Please update Calligro to enjoy the latest video recordings and meeting features.';
    _iosUrlCtrl.text = config['ios_store_url'] ??
        'https://apps.apple.com/app/calligro/id6670783307';
    _androidUrlCtrl.text = config['android_store_url'] ??
        'https://play.google.com/store/apps/details?id=com.yazan.calligroApp';

    // If current build is not present in available versions, offer to insert it
    final exists = _availableVersions.any((v) => v['build'] == _currentDeviceBuild);
    if (!exists) {
      _availableVersions.insert(0, {
        'build': _currentDeviceBuild,
        'version': _currentDeviceVersion,
        'label': 'v$_currentDeviceVersion (Build $_currentDeviceBuild) - الحالي',
      });
    }

    // Ensure selected build exists in the list
    if (!_availableVersions.any((v) => v['build'] == _selectedMinBuild)) {
      _selectedMinBuild = _availableVersions.first['build'] as int;
    }

    setState(() => _isLoading = false);
  }

  void _addNewVersionDialog() {
    final buildCtrl = TextEditingController();
    final versionCtrl = TextEditingController(text: _currentDeviceVersion);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2026),
          title: const Text('إضافة إصدار جديد للقائمة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: buildCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'رقم البناء (Build Number e.g. 105)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: versionCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الإصدار (Version Name e.g. 1.0.23)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                final buildNum = int.tryParse(buildCtrl.text.trim());
                final vName = versionCtrl.text.trim();
                if (buildNum != null && vName.isNotEmpty) {
                  setState(() {
                    _availableVersions.removeWhere((v) => v['build'] == buildNum);
                    _availableVersions.insert(0, {
                      'build': buildNum,
                      'version': vName,
                      'label': 'v$vName (Build $buildNum)',
                    });
                    _availableVersions.sort((a, b) => (b['build'] as int).compareTo(a['build'] as int));
                    _selectedMinBuild = buildNum;
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGold),
              child: const Text('إضافة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    if (_selectedMinBuild == null) return;

    setState(() => _isSaving = true);

    try {
      final selectedVersionObj = _availableVersions.firstWhere(
        (v) => v['build'] == _selectedMinBuild,
        orElse: () => {
          'build': _selectedMinBuild!,
          'version': _currentDeviceVersion,
          'label': 'v$_currentDeviceVersion (Build $_selectedMinBuild)',
        },
      );

      await _versionService.saveConfig(
        minRequiredBuild: _selectedMinBuild!,
        isForceUpdate: _isForceUpdate,
        latestBuild: _selectedMinBuild!,
        latestVersionName: selectedVersionObj['version'] as String? ?? _currentDeviceVersion,
        availableVersions: _availableVersions,
        updateTitleAr: _titleArCtrl.text.trim(),
        updateTitleEn: _titleEnCtrl.text.trim(),
        updateMessageAr: _msgArCtrl.text.trim(),
        updateMessageEn: _msgEnCtrl.text.trim(),
        iosStoreUrl: _iosUrlCtrl.text.trim(),
        androidStoreUrl: _androidUrlCtrl.text.trim(),
      );

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'تم الحفظ بنجاح',
          message: _isForceUpdate
              ? 'تم تفعيل التحديث الإجباري للإصدار Build $_selectedMinBuild'
              : 'تم حفظ إعدادات التحديث (اختياري)',
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'خطأ أثناء الحفظ',
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'إدارة إصدارات التطبيق والتحديث',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Current Build Info Card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E2026),
                          AppColors.accentGold.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accentGold, width: 1.5),
                          ),
                          child: const Icon(Icons.phone_iphone_rounded, color: AppColors.accentGold, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إصدار التطبيق المثبت على هذا الجهاز:',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'v$_currentDeviceVersion (Build $_currentDeviceBuild)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Section 1: Choose Version to Enforce ──
                  const Text(
                    '1. اختر الإصدار المطلوب تطبيقه:',
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر الإصدار من القائمة التي لدينا دون الحاجة لكتابة أرقام يدوياً:',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2026),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMinBuild,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E2026),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold),
                        items: _availableVersions.map((v) {
                          final buildNum = v['build'] as int;
                          final label = v['label'] as String? ?? 'Build $buildNum';
                          final isCurrent = buildNum == _currentDeviceBuild;

                          return DropdownMenuItem<int>(
                            value: buildNum,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: 18,
                                  color: isCurrent ? AppColors.accentGold : Colors.white60,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: isCurrent ? AppColors.accentGold : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMinBuild = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addNewVersionDialog,
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.accentGold, size: 18),
                      label: const Text(
                        'إضافة إصدار جديد للقائمة',
                        style: TextStyle(color: AppColors.accentGold, fontSize: 13),
                      ),
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 32),

                  // ── Section 2: Force Update Toggle ──
                  const Text(
                    '2. حالة الإلزام (إجباري أم اختياري):',
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2026),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isForceUpdate
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isForceUpdate
                                    ? Colors.redAccent.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isForceUpdate
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                color: _isForceUpdate ? Colors.redAccent : Colors.greenAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isForceUpdate
                                        ? 'إلزام المستخدمين بالتحديث (إجباري)'
                                        : 'تحديث اختياري (تنبيه فقط)',
                                    style: TextStyle(
                                      color: _isForceUpdate ? Colors.redAccent : Colors.greenAccent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isForceUpdate
                                        ? 'المستخدمون على إصدار أقدم لن يتمكنوا من فتح التطبيق إلا بعد التحديث.'
                                        : 'سيظهر إشعار عند فتح التطبيق مع إمكانية الضغط على "لاحقاً".',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isForceUpdate,
                              activeTrackColor: Colors.redAccent.withValues(alpha: 0.3),
                              inactiveThumbColor: Colors.white70,
                              inactiveTrackColor: Colors.white24,
                              onChanged: (val) {
                                setState(() => _isForceUpdate = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 32),

                  // ── Section 3: Messages ──
                  const Text(
                    '3. رسالة التحديث للمستخدمين:',
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildCustomTextField(
                    controller: _titleArCtrl,
                    label: 'عنوان التنبيه (عربي)',
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _msgArCtrl,
                    label: 'نص التنبيه وشرح التحديث (عربي)',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 16),

                  _buildCustomTextField(
                    controller: _titleEnCtrl,
                    label: 'Alert Title (English)',
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _msgEnCtrl,
                    label: 'Update Message (English)',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 28),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'حفظ وتطبيق إعدادات التحديث',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2026),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.accentGold, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
