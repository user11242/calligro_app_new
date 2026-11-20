import 'dart:async';

import 'package:calligro_app/features/admin/presentation/widgets/join_lock_switch_card.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<Map<String, dynamic>?> db;
  late List<bool> writes;
  Object? fail;

  Future<void> open(WidgetTester tester, Map<String, dynamic>? doc) async {
    db = StreamController<Map<String, dynamic>?>.broadcast();
    writes = [];
    fail = null;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: JoinLockSwitchCard(
          features: db.stream,
          setJoinLock: (on) async {
            if (fail != null) throw fail!;
            writes.add(on);
            db.add({'joinLock': on}); // the database answers with the new value
          },
        ),
      ),
    ));
    db.add(doc);
    await tester.pumpAndSettle();
  }

  testWidgets('no setting yet → shows ON (the normal lock)', (tester) async {
    await open(tester, null);
    expect(tester.widget<Switch>(find.byKey(const Key('joinLockSwitch'))).value, isTrue);
    expect(find.textContaining('ON:'), findsOneWidget);
  });

  testWidgets('turning it OFF saves false and shows OFF; back ON saves true', (tester) async {
    await open(tester, {'joinLock': true});
    await tester.tap(find.byKey(const Key('joinLockSwitch')));
    await tester.pumpAndSettle();
    expect(writes, [false]);
    expect(find.textContaining('OFF:'), findsOneWidget);
    await tester.tap(find.byKey(const Key('joinLockSwitch')));
    await tester.pumpAndSettle();
    expect(writes, [false, true]);
  });

  testWidgets('a save error is shown, not thrown, and the switch keeps the real value', (tester) async {
    await open(tester, {'joinLock': true});
    fail = Exception('permission-denied');
    await tester.tap(find.byKey(const Key('joinLockSwitch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('joinLockError')), findsOneWidget);
    expect(tester.widget<Switch>(find.byKey(const Key('joinLockSwitch'))).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
