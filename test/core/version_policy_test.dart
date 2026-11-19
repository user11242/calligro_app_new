import 'package:calligro_app/core/services/version_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ios = AppPlatform.ios, android = AppPlatform.android;

  group('who must update', () {
    final config = {
      'min_required_build_ios': 107,
      'min_required_build_android': 102,
      'is_force_update': true,
    };

    test('each platform has its own minimum (stores are not in step)', () {
      expect(VersionPolicy.decide(config, ios, 106), UpdateDecision.required);
      expect(VersionPolicy.decide(config, ios, 107), UpdateDecision.upToDate);
      expect(VersionPolicy.decide(config, android, 102), UpdateDecision.upToDate, reason: 'Android 102 is the newest on Play');
      expect(VersionPolicy.decide(config, android, 101), UpdateDecision.required);
    });

    test('not forced → "may update" below the minimum', () {
      final c = {...config, 'is_force_update': false};
      expect(VersionPolicy.decide(c, ios, 100), UpdateDecision.optional);
      expect(VersionPolicy.decide(c, ios, 107), UpdateDecision.upToDate);
    });

    test('a config saved before this rule (one shared minimum) still works', () {
      final old = {'min_required_build': 104, 'latest_build': 105, 'is_force_update': true};
      expect(VersionPolicy.decide(old, android, 103), UpdateDecision.required);
      expect(VersionPolicy.decide(old, android, 104), UpdateDecision.optional, reason: 'below latest');
      expect(VersionPolicy.decide(old, ios, 105), UpdateDecision.upToDate);
      expect(VersionPolicy.decide(const {}, ios, 1), UpdateDecision.upToDate);
    });

    test('numbers stored as text are read', () {
      expect(VersionPolicy.decide({'min_required_build_ios': '110', 'is_force_update': true}, ios, 107), UpdateDecision.required);
    });
  });

  group('older apps (they only read the shared minimum)', () {
    test('get the LOWER of the two, so nobody is forced to a build their store lacks', () {
      final f = VersionPolicy.configFields(
        iosMinBuild: 107, androidMinBuild: 102, isForceUpdate: true,
        iosVersionName: '1.0.24', androidVersionName: '1.0.21',
        iosStoreUrl: '', androidStoreUrl: '',
      );
      expect(f['min_required_build'], 102);
      expect(f['latest_build'], 102);
      expect(f['latest_version_name'], '1.0.21');
      expect(f['min_required_build_ios'], 107);
      expect(f['min_required_build_android'], 102);
      // An old Android app at 102 (the Play version) is NOT locked out:
      expect(VersionPolicy.decide({'min_required_build': f['min_required_build'], 'is_force_update': true}, android, 102),
          UpdateDecision.upToDate);
    });
  });

  group('store links', () {
    test('the links in use before were "not found" pages and are replaced', () {
      for (final bad in [
        'https://apps.apple.com/app/calligro/id6670783307',
        'https://play.google.com/store/apps/details?id=com.yazan.calligroApp',
      ]) {
        expect(VersionPolicy.isKnownBrokenStoreUrl(bad), isTrue);
      }
      expect(VersionPolicy.storeUrl({'ios_store_url': 'https://apps.apple.com/app/calligro/id6670783307'}, ios),
          'https://apps.apple.com/app/id6761537808');
      expect(VersionPolicy.storeUrl({'android_store_url': 'https://play.google.com/store/apps/details?id=com.yazan.calligroApp'}, android),
          'https://play.google.com/store/apps/details?id=com.yazan.calligro_app');
    });

    test('missing → the real store; a different saved link is respected', () {
      expect(VersionPolicy.storeUrl(const {}, ios), VersionPolicy.iosStoreUrl);
      expect(VersionPolicy.storeUrl({'android_store_url': '  '}, android), VersionPolicy.androidStoreUrl);
      expect(VersionPolicy.storeUrl({'ios_store_url': 'https://apps.apple.com/app/id1'}, ios), 'https://apps.apple.com/app/id1');
    });

    test('saving never stores a broken link', () {
      final f = VersionPolicy.configFields(
        iosMinBuild: 1, androidMinBuild: 1, isForceUpdate: false, iosVersionName: '', androidVersionName: '',
        iosStoreUrl: 'https://apps.apple.com/app/calligro/id6670783307', androidStoreUrl: '',
      );
      expect(f['ios_store_url'], VersionPolicy.iosStoreUrl);
      expect(f['android_store_url'], VersionPolicy.androidStoreUrl);
    });
  });
}
