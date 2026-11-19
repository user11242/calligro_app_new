/// The app-update rule (pure Dart): who must or may update, and to which store.
///
/// The config lives in Firestore `app_config/version_control`. iPhone and Android have
/// their OWN minimum build, because the stores are not in step (one platform can be
/// several builds ahead). App versions older than this rule only read the shared
/// `min_required_build`; the admin page writes there the LOWER of the two, so an old
/// app is never forced to a build its store does not have.
library;

enum AppPlatform { ios, android }

enum UpdateDecision { upToDate, optional, required }

class VersionPolicy {
  VersionPolicy._();

  /// The real store pages (checked: they open the Calligro app).
  static const iosStoreUrl = 'https://apps.apple.com/app/id6761537808';
  static const androidStoreUrl = 'https://play.google.com/store/apps/details?id=com.yazan.calligro_app';

  /// Links that were shipped by mistake and lead to "not found" pages.
  static const _brokenStoreUrls = {
    'https://apps.apple.com/app/calligro/id6670783307',
    'https://apps.apple.com/app/id6670783307',
    'https://play.google.com/store/apps/details?id=com.yazan.calligroApp',
  };

  static String _key(AppPlatform p) => p == AppPlatform.ios ? 'ios' : 'android';

  static int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  /// The minimum build for [platform] (its own value, else the shared one), or null.
  static int? minBuild(Map<String, dynamic> config, AppPlatform platform) =>
      _int(config['min_required_build_${_key(platform)}']) ?? _int(config['min_required_build']);

  /// Whether this install must update, may update, or is fine.
  static UpdateDecision decide(Map<String, dynamic> config, AppPlatform platform, int currentBuild) {
    final min = minBuild(config, platform);
    if (min != null && currentBuild < min) {
      return config['is_force_update'] == true ? UpdateDecision.required : UpdateDecision.optional;
    }
    final latest = _int(config['latest_build_${_key(platform)}']) ?? _int(config['latest_build']);
    if (latest != null && currentBuild < latest) return UpdateDecision.optional;
    return UpdateDecision.upToDate;
  }

  /// The store page to open for [platform]; a missing or known-broken link is replaced.
  static String storeUrl(Map<String, dynamic> config, AppPlatform platform) {
    final saved = config[platform == AppPlatform.ios ? 'ios_store_url' : 'android_store_url'];
    return correctedStoreUrl(saved is String ? saved : null, platform);
  }

  static String correctedStoreUrl(String? url, AppPlatform platform) {
    final fallback = platform == AppPlatform.ios ? iosStoreUrl : androidStoreUrl;
    final u = url?.trim() ?? '';
    if (u.isEmpty || _brokenStoreUrls.contains(u)) return fallback;
    return u;
  }

  static bool isKnownBrokenStoreUrl(String? url) => url != null && _brokenStoreUrls.contains(url.trim());

  /// What older app versions read (shared fields): the lower of the two minimums, so
  /// no old app is pushed to a build its store does not have yet.
  static int legacyMinBuild(int iosMin, int androidMin) => iosMin < androidMin ? iosMin : androidMin;

  /// The fields the admin page saves.
  static Map<String, dynamic> configFields({
    required int iosMinBuild,
    required int androidMinBuild,
    required bool isForceUpdate,
    required String iosVersionName,
    required String androidVersionName,
    required String iosStoreUrl,
    required String androidStoreUrl,
  }) {
    final legacy = legacyMinBuild(iosMinBuild, androidMinBuild);
    return {
      'min_required_build_ios': iosMinBuild,
      'min_required_build_android': androidMinBuild,
      'latest_build_ios': iosMinBuild,
      'latest_build_android': androidMinBuild,
      // Older app versions:
      'min_required_build': legacy,
      'latest_build': legacy,
      'latest_version_name': iosMinBuild <= androidMinBuild ? iosVersionName : androidVersionName,
      'is_force_update': isForceUpdate,
      'ios_store_url': correctedStoreUrl(iosStoreUrl, AppPlatform.ios),
      'android_store_url': correctedStoreUrl(androidStoreUrl, AppPlatform.android),
    };
  }
}
