import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/course_materials.dart';
import '../domain/classroom_repositories.dart';

class FirestoreMaterialsRepository implements MaterialsRepository {
  FirestoreMaterialsRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _folders(String courseId) =>
      _db.collection('courses').doc(courseId).collection('materials');

  @override
  Stream<List<CourseMaterialFolder>> watchFolders(String courseId) => _folders(courseId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) CourseMaterialFolder.fromMap(d.id, d.data())]);

  @override
  Stream<CourseMaterialFolder?> watchFolder(String courseId, String folderId) =>
      _folders(courseId).doc(folderId).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : CourseMaterialFolder.fromMap(d.id, data);
      });

  @override
  Future<String> createFolder(String courseId, Map<String, dynamic> folder) async =>
      (await _folders(courseId).add({...folder, 'createdAt': FieldValue.serverTimestamp()})).id;

  @override
  Future<void> renameFolder(String courseId, String folderId, String title) =>
      _folders(courseId).doc(folderId).update({'title': title});

  @override
  Future<void> deleteFolder(String courseId, String folderId) => _folders(courseId).doc(folderId).delete();

  @override
  Future<void> replaceFiles(String courseId, String folderId, List<CourseMaterialFileItem> files) =>
      _folders(courseId).doc(folderId).update({
        'files': [for (final f in files) f.toMap()],
        'itemCount': files.length,
      });

  @override
  Future<String> displayName(String uid) async {
    final d = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    return d['name'] is String ? d['name'] as String : '';
  }
}

class StorageMaterialFiles implements MaterialFiles {
  StorageMaterialFiles({FirebaseStorage? storage}) : _injected = storage;
  final FirebaseStorage? _injected;
  FirebaseStorage get _storage => _injected ?? FirebaseStorage.instance;

  @override
  Future<({String url, String storagePath})> upload(String courseId, String localPath, String fileName) async {
    final storagePath = 'course_materials/$courseId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final task = await _storage.ref().child(storagePath).putFile(File(localPath));
    return (url: await task.ref.getDownloadURL(), storagePath: storagePath);
  }

  @override
  Future<void> delete(String storagePath) => _storage.ref().child(storagePath).delete();
}
