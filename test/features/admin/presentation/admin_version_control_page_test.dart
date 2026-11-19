import 'package:calligro_app/core/services/version_policy.dart';
import 'package:calligro_app/features/admin/presentation/pages/admin_version_control_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStore implements VersionConfigStore {
  FakeStore(this.config);
  Map<String, dynamic> config;
  final saves = <Map<String, dynamic>>[];
  Object? failSave;

  @override
  Future<Map<String, dynamic>> load() async => config;

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    if (failSave != null) throw failSave!;
    saves.add(fields);
  }

  @override
  Future<(String, int)> installedVersion() async => ('1.0.24', 107);
}

void main() {
  // What production holds today (one shared minimum, the old broken links).
  Map<String, dynamic> todays() => {
        'min_required_build': 104,
        'latest_build': 104,
        'is_force_update': false,
        'available_versions': [
          {'build': 104, 'version': '1.0.23'},
          {'build': 102, 'version': '1.0.21'},
        ],
        'ios_store_url': 'https://apps.apple.com/app/calligro/id6670783307',
        'android_store_url': 'https://play.google.com/store/apps/details?id=com.yazan.calligroApp',
      };

  Future<FakeStore> open(WidgetTester tester, Map<String, dynamic> config) async {
    final store = FakeStore(config);
    await tester.binding.setSurfaceSize(const Size(500, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: AdminVersionControlPage(store: store),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> pick(WidgetTester tester, String dropdown, String label) async {
    await tester.tap(find.byKey(Key(dropdown)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows what users get today, per store', (tester) async {
    await open(tester, todays());
    final live = find.byKey(const Key('liveStatus'));
    expect(find.descendant(of: live, matching: find.text('تحديث اختياري')), findsOneWidget);
    expect(find.descendant(of: live, matching: find.text('أقل من Build 104 يُطلب منه التحديث')), findsNWidgets(2));
    expect(find.descendant(of: live, matching: find.textContaining('Build 107')), findsOneWidget, reason: 'this device');
  });

  testWidgets('the broken store links are corrected, flagged, and saving is offered', (tester) async {
    final store = await open(tester, todays());
    expect(find.byKey(const Key('fixedLinksNotice')), findsOneWidget);
    expect(find.text(VersionPolicy.iosStoreUrl), findsOneWidget);
    expect(find.text(VersionPolicy.androidStoreUrl), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveVersionControl')));
    await tester.pumpAndSettle();
    expect(store.saves.single['ios_store_url'], VersionPolicy.iosStoreUrl);
    expect(store.saves.single['android_store_url'], VersionPolicy.androidStoreUrl);
    expect(find.byKey(const Key('fixedLinksNotice')), findsNothing);
  });

  testWidgets('forcing: per-store minimums, a confirmation first, and old apps get the safer value', (tester) async {
    final store = await open(tester, todays());
    await tester.tap(find.byKey(const Key('modeForce')));
    await pick(tester, 'iosMin', 'v1.0.24 · Build 107  (هذا الجهاز)');
    await pick(tester, 'androidMin', 'v1.0.21 · Build 102');

    await tester.tap(find.byKey(const Key('saveVersionControl')));
    await tester.pumpAndSettle();
    expect(find.textContaining('آيفون أقدم من Build 107'), findsOneWidget);
    expect(store.saves, isEmpty, reason: 'nothing saved before confirming');

    await tester.tap(find.byKey(const Key('confirmForceUpdate')));
    await tester.pumpAndSettle();
    final f = store.saves.single;
    expect(f['is_force_update'], isTrue);
    expect(f['min_required_build_ios'], 107);
    expect(f['min_required_build_android'], 102);
    expect(f['min_required_build'], 102, reason: 'old Android apps (102, the Play version) are not locked out');
    expect(find.descendant(of: find.byKey(const Key('liveStatus')), matching: find.text('تحديث إجباري')), findsOneWidget);
  });

  testWidgets('cancelling the confirmation saves nothing', (tester) async {
    final store = await open(tester, todays());
    await tester.tap(find.byKey(const Key('modeForce')));
    await tester.tap(find.byKey(const Key('saveVersionControl')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء').last);
    await tester.pumpAndSettle();
    expect(store.saves, isEmpty);
  });

  testWidgets('nothing changed → Save is off; a save error is shown, not thrown', (tester) async {
    final clean = {
      ...todays(),
      'ios_store_url': VersionPolicy.iosStoreUrl,
      'android_store_url': VersionPolicy.androidStoreUrl,
    };
    final store = await open(tester, clean);
    final save = tester.widget<ElevatedButton>(find.byKey(const Key('saveVersionControl')));
    expect(save.onPressed, isNull);

    store.failSave = Exception('permission-denied');
    await tester.enterText(find.widgetWithText(TextField, 'العنوان'), 'تحديث مهم');
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveVersionControl')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.saves, isEmpty);
  });

  testWidgets('the preview of a FORCED update can be closed by the admin', (tester) async {
    await open(tester, {...todays(), 'is_force_update': true});
    await tester.tap(find.byKey(const Key('previewUpdate')));
    await tester.pumpAndSettle();
    expect(find.text('تحديث الآن'), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeUpdatePreview')));
    await tester.pumpAndSettle();
    expect(find.text('تحديث الآن'), findsNothing);
  });
}
