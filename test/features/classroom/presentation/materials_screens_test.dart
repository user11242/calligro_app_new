import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/application/classroom_materials.dart';
import 'package:calligro_app/features/classroom/domain/course_materials.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/features/teacher/pages/course_details/course_materials_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_classroom.dart';

void main() {
  late FakeMaterialsRepository repo;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final services = ClassroomServices(
      assignments: ClassroomAssignments(repository: FakeAssignmentRepository(), files: FakeSubmissionFiles(), currentUid: () => 'x'),
      materials: ClassroomMaterials(repository: repo, files: FakeMaterialFiles(), currentUid: () => 't1'),
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => ClassroomScope(services: services, child: child!),
      home: screen,
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void init() {
    repo = FakeMaterialsRepository()
      ..put('c1', const CourseMaterialFolder(id: 'f1', title: 'Week 1 sheets', type: 'pdf', totalSize: '2 KB', uploadedByName: 'Ali', files: [
        CourseMaterialFileItem(title: 'Alif', fileName: 'alif.pdf', fileUrl: 'https://x/alif.pdf', fileSize: '2 KB', storagePath: 'p', type: 'pdf'),
      ]));
  }

  testWidgets('students see the folders, live, but no upload button', (tester) async {
    init();
    await pump(tester, const CourseMaterialsPage(courseId: 'c1', courseName: 'Thuluth'));
    expect(find.text('Week 1 sheets'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    repo.put('c1', const CourseMaterialFolder(id: 'f2', title: 'Week 2 sheets', type: 'pdf', totalSize: '', uploadedByName: 'Ali', files: []));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Week 2 sheets'), findsOneWidget);
  });

  testWidgets('the course\'s teacher gets the upload button', (tester) async {
    init();
    await pump(tester, const CourseMaterialsPage(courseId: 'c1', courseName: 'Thuluth', isTeacher: true));
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
