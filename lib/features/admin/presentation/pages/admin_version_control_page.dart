import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/services/version_check_service.dart';
import 'package:calligro_app/core/services/version_policy.dart';
import 'package:calligro_app/core/theme/colors.dart';

/// Where the update setting is read and saved (Firestore `app_config/version_control`).
abstract interface class VersionConfigStore {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> fields);

  /// This device's installed version, e.g. ('1.0.24', 107).
  Future<(String, int)> installedVersion();
}

class FirestoreVersionConfigStore implements VersionConfigStore {
  final _service = VersionCheckService();

  @override
  Future<Map<String, dynamic>> load() => _service.getConfig();

  @override
  Future<void> save(Map<String, dynamic> fields) => _service.saveFields(fields);

  @override
  Future<(String, int)> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (info.version, int.tryParse(info.buildNumber) ?? 0);
  }
}

/// Admin: who must (or may) update the app, per store, and what they are told.
class AdminVersionControlPage extends StatefulWidget {
  const AdminVersionControlPage({super.key, this.store});

  /// Tests pass a fake; the app uses Firestore.
  final VersionConfigStore? store;

  @override
  State<AdminVersionControlPage> createState() => _AdminVersionControlPageState();
}

class _VersionOption {
  final int build;
  final String version;
  const _VersionOption(this.build, this.version);
  String get label => 'v$version · Build $build';
  Map<String, dynamic> toMap() => {'build': build, 'version': version, 'label': 'v$version (Build $build)'};
}

class _AdminVersionControlPageState extends State<AdminVersionControlPage> {
  late final VersionConfigStore _store = widget.store ?? FirestoreVersionConfigStore();

  static const _danger = Color(0xFFE5484D);
  static const _ok = Color(0xFF3DD68C);
  static const _card = Color(0xFF1E2026);

  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  Map<String, dynamic> _live = const {};
  String _deviceVersion = '';
  int _deviceBuild = 0;
  final List<_VersionOption> _versions = [];

  int? _iosMin;
  int? _androidMin;
  bool _force = false;
  bool _fixedBrokenLinks = false;

  final _titleAr = TextEditingController();
  final _msgAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _msgEn = TextEditingController();
  final _iosUrl = TextEditingController();
  final _androidUrl = TextEditingController();

  /// The form as last loaded/saved, to know if anything changed.
  String _savedSnapshot = '';

  @override
  void initState() {
    super.initState();
    for (final c in [_titleAr, _msgAr, _titleEn, _msgEn, _iosUrl, _androidUrl]) {
      c.addListener(_onEdit);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_titleAr, _msgAr, _titleEn, _msgEn, _iosUrl, _androidUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  String _snapshot() => [
        _iosMin, _androidMin, _force, _titleAr.text, _msgAr.text, _titleEn.text, _msgEn.text, _iosUrl.text, _androidUrl.text,
        _versions.map((v) => v.build).join(','),
      ].join('|');

  bool get _dirty => !_loading && _snapshot() != _savedSnapshot;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final (version, build) = await _store.installedVersion();
      final config = await _store.load();
      if (!mounted) return;
      _apply(config, version, build);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(Map<String, dynamic> config, String deviceVersion, int deviceBuild) {
    _live = config;
    _deviceVersion = deviceVersion;
    _deviceBuild = deviceBuild;

    _versions.clear();
    void add(int? build, String? version) {
      if (build == null || build <= 0 || _versions.any((v) => v.build == build)) return;
      _versions.add(_VersionOption(build, (version == null || version.isEmpty) ? '?' : version));
    }

    for (final raw in (config['available_versions'] as List?) ?? const []) {
      if (raw is Map) add((raw['build'] as num?)?.toInt(), raw['version'] as String?);
    }
    add(deviceBuild, deviceVersion);
    _iosMin = VersionPolicy.minBuild(config, AppPlatform.ios);
    _androidMin = VersionPolicy.minBuild(config, AppPlatform.android);
    add(_iosMin, null);
    add(_androidMin, null);
    _versions.sort((a, b) => b.build.compareTo(a.build));
    _iosMin ??= _versions.isEmpty ? null : _versions.last.build;
    _androidMin ??= _versions.isEmpty ? null : _versions.last.build;

    _force = config['is_force_update'] == true;
    _titleAr.text = config['update_title_ar'] as String? ?? 'تحديث جديد متاح';
    _msgAr.text = config['update_message_ar'] as String? ??
        'يرجى تحديث كاليجرو للاستفادة من أحدث الميزات وتحسينات الأداء.';
    _titleEn.text = config['update_title_en'] as String? ?? 'New Update Available';
    _msgEn.text = config['update_message_en'] as String? ??
        'Please update Calligro to enjoy the latest features and performance improvements.';

    final savedIos = config['ios_store_url'] as String?;
    final savedAndroid = config['android_store_url'] as String?;
    _fixedBrokenLinks = VersionPolicy.isKnownBrokenStoreUrl(savedIos) || VersionPolicy.isKnownBrokenStoreUrl(savedAndroid);
    _iosUrl.text = VersionPolicy.correctedStoreUrl(savedIos, AppPlatform.ios);
    _androidUrl.text = VersionPolicy.correctedStoreUrl(savedAndroid, AppPlatform.android);

    // A corrected broken link counts as an unsaved change (Save puts it right for everyone).
    _savedSnapshot = _fixedBrokenLinks ? '' : _snapshot();
  }

  String _versionName(int? build) => _versions.firstWhere((v) => v.build == build, orElse: () => _VersionOption(build ?? 0, '?')).version;

  Future<void> _save() async {
    final ios = _iosMin, android = _androidMin;
    if (ios == null || android == null || _saving) return;

    if (_force) {
      final ok = await _confirmForce(ios, android);
      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);
    final fields = {
      ...VersionPolicy.configFields(
        iosMinBuild: ios,
        androidMinBuild: android,
        isForceUpdate: _force,
        iosVersionName: _versionName(ios),
        androidVersionName: _versionName(android),
        iosStoreUrl: _iosUrl.text,
        androidStoreUrl: _androidUrl.text,
      ),
      'available_versions': [for (final v in _versions) v.toMap()],
      'update_title_ar': _titleAr.text.trim(),
      'update_message_ar': _msgAr.text.trim(),
      'update_title_en': _titleEn.text.trim(),
      'update_message_en': _msgEn.text.trim(),
    };
    try {
      await _store.save(fields);
      if (!mounted) return;
      setState(() {
        _live = {..._live, ...fields, 'updated_at': DateTime.now()};
        _fixedBrokenLinks = false;
        _savedSnapshot = _snapshot();
      });
      AppMessenger.showSnackBar(
        context,
        title: 'تم الحفظ',
        message: _force ? 'التحديث الإجباري مفعّل الآن' : 'إعدادات التحديث الاختياري محفوظة',
        type: MessengerType.success,
      );
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(context, title: 'تعذّر الحفظ', message: '$e', type: MessengerType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmForce(int ios, int android) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.lock_rounded, color: _danger),
            SizedBox(width: 10),
            Expanded(child: Text('تفعيل التحديث الإجباري؟', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ]),
          content: Text(
            'لن يتمكن هؤلاء من دخول التطبيق حتى يحدّثوه:\n'
            '• آيفون أقدم من Build $ios\n'
            '• أندرويد أقدم من Build $android\n\n'
            'تأكد أن هذين الإصدارين منشوران فعلاً في App Store و Google Play، وإلا سيُمنع المستخدمون دون تحديث متاح لهم.',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              key: const Key('confirmForceUpdate'),
              style: ElevatedButton.styleFrom(backgroundColor: _danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، فعّل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  void _preview() {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final min = (isIos ? _iosMin : _androidMin) ?? 0;
    VersionCheckService().showUpdateDialog(
      context,
      VersionCheckResult(
        status: _force ? VersionStatus.forceUpdate : VersionStatus.optionalUpdate,
        currentBuild: _deviceBuild,
        currentVersion: _deviceVersion,
        minRequiredBuild: min,
        latestBuild: min,
        latestVersionName: _versionName(min),
        isForceUpdate: _force,
        updateTitle: isArabic ? _titleAr.text : _titleEn.text,
        updateMessage: isArabic ? _msgAr.text : _msgEn.text,
        storeUrl: isIos ? _iosUrl.text : _androidUrl.text,
      ),
      preview: true,
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _addVersion() {
    final build = TextEditingController();
    final version = TextEditingController(text: _deviceVersion);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة إصدار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(build, 'رقم البناء (Build)', Icons.tag_rounded, number: true),
          const SizedBox(height: 12),
          _field(version, 'اسم الإصدار (مثال 1.0.25)', Icons.label_outline_rounded),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGold),
            onPressed: () {
              final b = int.tryParse(build.text.trim());
              final v = version.text.trim();
              if (b == null || b <= 0 || v.isEmpty) return;
              setState(() {
                _versions.removeWhere((x) => x.build == b);
                _versions.add(_VersionOption(b, v));
                _versions.sort((a, c) => c.build.compareTo(a.build));
              });
              Navigator.pop(ctx);
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: const Text('تحديث التطبيق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _loadError != null
              ? _loadFailed()
              : _form(),
      bottomNavigationBar: _loading || _loadError != null ? null : _actions(),
    );
  }

  Widget _loadFailed() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text('تعذّر تحميل الإعدادات\n$_loadError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ]),
        ),
      );

  Widget _form() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _liveCard(),
          const SizedBox(height: 24),
          _section('نوع التحديث', 'ماذا يحدث لمن يستخدم إصداراً أقدم؟'),
          Row(children: [
            Expanded(child: _modeCard(force: false)),
            const SizedBox(width: 12),
            Expanded(child: _modeCard(force: true)),
          ]),
          const SizedBox(height: 24),
          _section('الحد الأدنى للإصدار', 'لكل متجر إصداره: اختر إصداراً منشوراً فعلاً في ذلك المتجر.'),
          _panel(Column(children: [
            _platformRow(ios: true),
            const Divider(color: Colors.white10, height: 24),
            _platformRow(ios: false),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _addVersion,
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentGold, size: 20),
                label: const Text('إضافة إصدار للقائمة', style: TextStyle(color: AppColors.accentGold)),
              ),
            ),
          ])),
          const SizedBox(height: 24),
          _section('رسالة التحديث', 'تظهر للمستخدمين بلغة التطبيق لديهم.'),
          _panel(Column(children: [
            _langTag('العربية'),
            _field(_titleAr, 'العنوان', Icons.title_rounded),
            const SizedBox(height: 10),
            _field(_msgAr, 'النص', Icons.notes_rounded, lines: 3),
            const SizedBox(height: 18),
            _langTag('English'),
            _field(_titleEn, 'Title', Icons.title_rounded, ltr: true),
            const SizedBox(height: 10),
            _field(_msgEn, 'Message', Icons.notes_rounded, lines: 3, ltr: true),
          ])),
          const SizedBox(height: 24),
          _section('روابط المتجر', 'زر "تحديث الآن" يفتح هذه الصفحات.'),
          if (_fixedBrokenLinks) _notice('تم تصحيح رابط متجر كان يفتح صفحة غير موجودة. اضغط حفظ ليصل التصحيح لكل المستخدمين.'),
          _panel(Column(children: [
            _linkField(_iosUrl, 'App Store (آيفون)', Icons.apple_rounded),
            const SizedBox(height: 10),
            _linkField(_androidUrl, 'Google Play (أندرويد)', Icons.android_rounded),
          ])),
        ],
      );

  Widget _liveCard() {
    final iosLive = VersionPolicy.minBuild(_live, AppPlatform.ios);
    final androidLive = VersionPolicy.minBuild(_live, AppPlatform.android);
    final forced = _live['is_force_update'] == true;
    final active = iosLive != null || androidLive != null;
    final color = !active ? Colors.white54 : (forced ? _danger : AppColors.accentGold);
    DateTime? updatedAt;
    try {
      final updated = _live['updated_at'];
      updatedAt = updated is DateTime ? updated : (updated as dynamic)?.toDate() as DateTime?; // a Firestore Timestamp
    } catch (_) {}

    return Container(
      key: const Key('liveStatus'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), _card], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(!active ? Icons.check_circle_outline_rounded : (forced ? Icons.lock_rounded : Icons.notifications_active_outlined), color: color),
          const SizedBox(width: 10),
          const Text('المطبّق الآن على المستخدمين', style: TextStyle(color: Colors.white60, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Text(
          !active ? 'لا يوجد طلب تحديث' : (forced ? 'تحديث إجباري' : 'تحديث اختياري'),
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if (active) ...[
          const SizedBox(height: 10),
          _liveLine(Icons.apple_rounded, 'آيفون', iosLive),
          const SizedBox(height: 4),
          _liveLine(Icons.android_rounded, 'أندرويد', androidLive),
        ],
        const Divider(color: Colors.white12, height: 26),
        Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_iphone_rounded, color: Colors.white38, size: 16),
            const SizedBox(width: 6),
            Text('هذا الجهاز: v$_deviceVersion · Build $_deviceBuild', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
          if (updatedAt != null)
            Text('آخر حفظ ${updatedAt.toLocal().toString().substring(0, 16)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _liveLine(IconData icon, String name, int? build) => Row(children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Text('$name: ', style: const TextStyle(color: Colors.white70)),
        Expanded(
          child: Text(build == null ? '—' : 'أقل من Build $build يُطلب منه التحديث',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ]);

  Widget _modeCard({required bool force}) {
    final selected = _force == force;
    final color = force ? _danger : _ok;
    return InkWell(
      key: Key(force ? 'modeForce' : 'modeOptional'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _force = force),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : Colors.white10, width: selected ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(force ? Icons.lock_rounded : Icons.lock_open_rounded, color: color, size: 22),
            const Spacer(),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? color : Colors.white24, size: 20),
          ]),
          const SizedBox(height: 10),
          Text(force ? 'إجباري' : 'اختياري', style: TextStyle(color: selected ? color : Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            force ? 'لا يمكن دخول التطبيق قبل التحديث' : 'تنبيه مع زر "لاحقاً"',
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ]),
      ),
    );
  }

  Widget _platformRow({required bool ios}) {
    final value = ios ? _iosMin : _androidMin;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Icon(ios ? Icons.apple_rounded : Icons.android_rounded, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ios ? 'آيفون · App Store' : 'أندرويد · Google Play',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: Key(ios ? 'iosMin' : 'androidMin'),
              value: value,
              isExpanded: true,
              dropdownColor: _card,
              iconEnabledColor: AppColors.accentGold,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: [
                for (final v in _versions)
                  DropdownMenuItem(
                    value: v.build,
                    child: Text(v.build == _deviceBuild ? '${v.label}  (هذا الجهاز)' : v.label),
                  ),
              ],
              onChanged: (b) => setState(() => ios ? _iosMin = b : _androidMin = b),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _section(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 4, left: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.accentGold, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
        ]),
      );

  Widget _panel(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
        child: child,
      );

  Widget _langTag(String text) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _notice(String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.build_circle_outlined, color: AppColors.accentGold),
          const SizedBox(width: 10),
          Expanded(child: Text(text, key: const Key('fixedLinksNotice'), style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
        ]),
      );

  Widget _field(TextEditingController c, String label, IconData icon, {int lines = 1, bool ltr = false, bool number = false}) =>
      TextField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : null,
        textDirection: ltr ? TextDirection.ltr : null,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.accentGold, size: 20),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );

  Widget _linkField(TextEditingController c, String label, IconData icon) => Row(children: [
        Expanded(child: _field(c, label, icon, ltr: true)),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'فتح الرابط للتأكد منه',
          onPressed: () => _openLink(c.text),
          icon: const Icon(Icons.open_in_new_rounded, color: AppColors.accentGold),
        ),
      ]);

  Widget _actions() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: AppColors.primary, border: Border(top: BorderSide(color: Colors.white10))),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('previewUpdate'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined, color: Colors.white70),
                label: const Text('معاينة', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const Key('saveVersionControl'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _force ? _danger : AppColors.accentGold,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _dirty && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        _dirty ? (_force ? 'حفظ وتفعيل الإجباري' : 'حفظ') : 'لا توجد تغييرات',
                        style: TextStyle(color: _dirty ? (_force ? Colors.white : Colors.black) : Colors.white38, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ]),
        ),
      );
}
