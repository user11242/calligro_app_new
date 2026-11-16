import 'package:calligro_app/features/classroom/presentation/chat/course_details_floating_bar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableBar({
    required bool isTeacher,
    required VoidCallback onLiveSessionPressed,
    required VoidCallback onChatPressed,
    Locale locale = const Locale('en'),
    double width = 360,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('tr')],
      home: Scaffold(
        body: SizedBox(width: width, height: 600),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: CourseDetailsFloatingBar(
          isTeacher: isTeacher,
          onLiveSessionPressed: onLiveSessionPressed,
          onChatPressed: onChatPressed,
        ),
      ),
    );
  }

  group('CourseDetailsFloatingBar', () {
    testWidgets('renders Start Live Session and floating Chat button for teacher',
        (tester) async {
      bool liveTapped = false;
      bool chatTapped = false;

      await tester.pumpWidget(buildTestableBar(
        isTeacher: true,
        onLiveSessionPressed: () => liveTapped = true,
        onChatPressed: () => chatTapped = true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('START LIVE SESSION'), findsOneWidget);
      final chatBtn = find.byKey(const Key('floating_course_chat_button'));
      expect(chatBtn, findsOneWidget);

      await tester.tap(chatBtn);
      await tester.pump();
      expect(chatTapped, isTrue);

      await tester.tap(find.text('START LIVE SESSION'));
      await tester.pump();
      expect(liveTapped, isTrue);
    });

    testWidgets('renders Join Live Session on narrow Arabic layout without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableBar(
        isTeacher: false,
        locale: const Locale('ar'),
        width: 320,
        onLiveSessionPressed: () {},
        onChatPressed: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('floating_course_chat_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
