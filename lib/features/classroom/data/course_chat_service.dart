import 'dart:io';

import 'package:calligro_app/features/classroom/domain/course_chat_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Handles Firestore persistence, Storage image uploads, and moderation
/// actions for a course's group chat (`courses/{courseId}/messages`).
class CourseChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CourseChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// The signed-in user (screens ask here, not FirebaseAuth).
  String? get currentUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _messagesRef(String courseId) {
    return _firestore.collection('courses').doc(courseId).collection('messages');
  }

  /// Streams messages for [courseId] ordered newest-first for reverse chat lists.
  Stream<List<CourseChatMessage>> getMessagesStream(
    String courseId, {
    int limit = 100,
  }) {
    return _messagesRef(courseId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => [for (final d in snap.docs) CourseChatMessage.fromMap(d.id, d.data())]);
  }

  /// Sends a text, image and/or PDF message into [courseId]'s group chat.
  /// Only the course's teacher may attach a PDF ([pdfFile], shown as [pdfName]).
  Future<void> sendMessage({
    required String courseId,
    required String text,
    File? imageFile,
    File? pdfFile,
    String? pdfName,
    String? courseTeacherId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to send messages.');
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty && imageFile == null && pdfFile == null) {
      return;
    }
    if (trimmedText.length > ChatPolicy.maxTextLength) throw const ChatMessageTooLong();
    if (pdfFile != null) {
      if (courseTeacherId == null || courseTeacherId != user.uid) throw const ChatFileNotAllowed();
      if (await pdfFile.length() > ChatPolicy.maxPdfBytes) throw const ChatFileTooLarge();
    }

    final profile = await _resolveSenderProfile(user);
    final senderRole = _resolveSenderRole(
      uid: user.uid,
      profileRole: profile.role,
      courseTeacherId: courseTeacherId,
    );

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadChatImage(courseId, user.uid, imageFile);
    }

    String? fileUrl;
    String? fileName;
    if (pdfFile != null) {
      fileUrl = await _uploadChatPdf(courseId, user.uid, pdfFile);
      fileName = _cleanPdfName(pdfName);
    }

    await _messagesRef(courseId).add({
      'senderId': user.uid,
      'senderName': profile.name,
      'senderPhotoUrl': profile.photoUrl,
      'senderRole': senderRole,
      'text': trimmedText,
      'imageUrl': imageUrl,
      // Only written with a PDF, so text and image messages keep the exact shape older apps write.
      'fileUrl': ?fileUrl,
      'fileName': ?fileName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a single message document from [courseId]'s chat.
  Future<void> deleteMessage({
    required String courseId,
    required String messageId,
  }) async {
    await _messagesRef(courseId).doc(messageId).delete();
  }

  /// Files a moderation report for an inappropriate chat message.
  Future<void> reportMessage({
    required String courseId,
    required String messageId,
    required String reportedUserId,
    required String reason,
    String? messageText,
  }) async {
    final reporterId = _auth.currentUser?.uid;
    if (reporterId == null) {
      throw Exception('You must be signed in to report messages.');
    }

    await _firestore.collection('reports').add({
      'type': 'course_chat_message',
      'courseId': courseId,
      'messageId': messageId,
      'reportedUserId': reportedUserId,
      'reportedByUserId': reporterId, // the field firestore.rules check (as community reports)
      'reason': reason,
      'messageText': messageText ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<({String name, String? photoUrl, String role})> _resolveSenderProfile(
    User user,
  ) async {
    String name = user.displayName?.trim() ?? '';
    String? photoUrl = user.photoURL;
    String role = 'student';

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? const <String, dynamic>{};
        final fullName = data['fullName']?.toString().trim();
        final shortName = data['name']?.toString().trim();
        if (fullName != null && fullName.isNotEmpty) {
          name = fullName;
        } else if (shortName != null && shortName.isNotEmpty) {
          name = shortName;
        }
        final storedPhoto = (data['photoUrl'] ?? data['photoURL'])?.toString().trim();
        if (storedPhoto != null && storedPhoto.isNotEmpty) {
          photoUrl = storedPhoto;
        }
        if (data['role'] != null) {
          role = data['role'].toString();
        }
      }
    } catch (_) {
      // Fall back gracefully to FirebaseAuth profile fields.
    }

    return (
      name: name.isNotEmpty ? name : 'Member',
      photoUrl: photoUrl,
      role: role,
    );
  }

  String _resolveSenderRole({
    required String uid,
    required String profileRole,
    String? courseTeacherId,
  }) =>
      ChatPolicy.senderRole(uid: uid, profileRole: profileRole, courseTeacherId: courseTeacherId);

  Future<String> _uploadChatImage(
    String courseId,
    String uid,
    File imageFile,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('course_chats')
        .child(courseId)
        .child('${uid}_$timestamp.jpg');

    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }

  /// The name shown on the file card: the picked name, ending in ".pdf", at most
  /// [ChatPolicy.maxFileNameLength] characters.
  static String _cleanPdfName(String? name) {
    var clean = (name ?? '').trim();
    if (clean.isEmpty) clean = 'document.pdf';
    if (!clean.toLowerCase().endsWith('.pdf')) clean = '$clean.pdf';
    if (clean.length > ChatPolicy.maxFileNameLength) {
      clean = '${clean.substring(0, ChatPolicy.maxFileNameLength - 4)}.pdf';
    }
    return clean;
  }

  Future<String> _uploadChatPdf(String courseId, String uid, File pdfFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('course_chats').child(courseId).child('${uid}_$timestamp.pdf');
    // storage.rules accept a chat PDF only as application/pdf.
    await ref.putFile(pdfFile, SettableMetadata(contentType: 'application/pdf'));
    return ref.getDownloadURL();
  }
}
