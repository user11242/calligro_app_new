import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../application/classroom_assignments.dart';
import '../application/classroom_materials.dart';
import '../application/classroom_recordings.dart';
import '../application/classroom_board.dart';
import '../data/firestore_board_repository.dart';
import '../data/firestore_materials_repository.dart';
import '../data/firestore_recordings_repository.dart';
import '../data/firestore_assignment_repository.dart';

/// What the in-course screens talk to. The ONLY place that picks real implementations.
class ClassroomServices {
  ClassroomServices({
    required this.assignments,
    required this.materials,
    ClassroomRecordings? recordings,
    ClassroomBoard? board,
  })  : recordings = recordings ?? ClassroomRecordings(repository: FirestoreRecordingsRepository()),
        board = board ??
            ClassroomBoard(
              repository: FirestoreBoardRepository(),
              currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
            );

  factory ClassroomServices.firebase() => ClassroomServices(
        assignments: ClassroomAssignments(
          repository: FirestoreAssignmentRepository(),
          files: StorageSubmissionFiles(),
          currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
        materials: ClassroomMaterials(
          repository: FirestoreMaterialsRepository(),
          files: StorageMaterialFiles(),
          currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      );

  final ClassroomAssignments assignments;
  final ClassroomMaterials materials;
  final ClassroomRecordings recordings;
  final ClassroomBoard board;
}

class ClassroomScope extends InheritedWidget {
  const ClassroomScope({super.key, required this.services, required super.child});

  final ClassroomServices services;
  static ClassroomServices? _fallback;

  /// In-course pages are pushed routes: without a scope the same cached real services are used.
  static ClassroomServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClassroomScope>()?.services ??
      (_fallback ??= ClassroomServices.firebase());

  @override
  bool updateShouldNotify(ClassroomScope oldWidget) => services != oldWidget.services;
}
