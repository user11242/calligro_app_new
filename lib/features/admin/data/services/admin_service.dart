import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:calligro_app/core/utils/date_utils.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATS ---

  /// Returns a real-time stream of global counts and metrics
  Stream<Map<String, dynamic>> getGlobalStats() {
    // Using snapshots() ensures real-time updates. 
    // We use .map to handle potential errors and ensure it emits even if empty.
    final usersStream = _firestore.collection('users').snapshots();
    final coursesStream = _firestore.collection('courses').snapshots();
    final postsStream = _firestore.collection('community_posts').snapshots();
    final pendingTeachersStream = _firestore.collection('users').where('role', isEqualTo: 'teacher').where('status', isEqualTo: 'pending').snapshots();
    final withdrawalsStream = _firestore.collection('withdrawal_requests').where('status', isEqualTo: 'pending').snapshots();

    return Rx.combineLatest5(
      usersStream,
      coursesStream,
      postsStream,
      pendingTeachersStream,
      withdrawalsStream,
      (users, courses, posts, pendingTeachers, withdrawals) {
        return {
          'totalUsers': users.docs.length,
          'totalCourses': courses.docs.length,
          'totalPosts': posts.docs.length,
          'pendingTeachers': pendingTeachers.docs.length,
          'pendingWithdrawals': withdrawals.docs.length,
        };
      },
    );
  }

  /// Fetches a merged stream of recent activities across the platform
  Stream<List<Map<String, dynamic>>> getRecentActivity() {
    final users = _firestore.collection('users').orderBy('createdAt', descending: true).limit(5).snapshots();
    final posts = _firestore.collection('community_posts').orderBy('createdAt', descending: true).limit(5).snapshots();
    final courses = _firestore.collection('courses').orderBy('createdAt', descending: true).limit(5).snapshots();

    return Rx.combineLatest3(
      users,
      posts,
      courses,
      (uSnap, pSnap, cSnap) {
        final List<Map<String, dynamic>> items = [];
        
        for (var doc in uSnap.docs) {
          final d = doc.data();
          // Filter out rejected users from activity log
          if (d['status'] == 'rejected') continue;
          
          items.add({
            'type': 'user',
            'title': 'newUserJoined',
            'subtitle': d['name'] ?? 'Someone new',
            'time': d['createdAt'],
            'icon': Icons.person_add_outlined,
            'color': Colors.blue,
          });
        }
        for (var doc in pSnap.docs) {
          final d = doc.data();
          items.add({
            'type': 'post',
            'title': 'newCommunityPost',
            'subtitle': d['content']?.toString().substring(0, d['content'].toString().length > 30 ? 30 : d['content'].toString().length) ?? 'No content',
            'time': d['createdAt'],
            'icon': Icons.campaign_outlined,
            'color': Colors.purple,
          });
        }
        for (var doc in cSnap.docs) {
          final d = doc.data();
          items.add({
            'type': 'course',
            'title': 'newCourseCreated',
            'subtitle': d['courseName'] ?? 'Untitled',
            'time': d['createdAt'],
            'icon': Icons.library_add_outlined,
            'color': Colors.amber,
          });
        }

        // Sort combined list by time using a robust parser
        items.sort((a, b) {
          final aTime = _toDateTime(a['time']);
          final bTime = _toDateTime(b['time']);
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return items.take(10).toList();
      },
    );
  }

  /// Safely converts various date formats (Timestamp, String, DateTime) to DateTime
  DateTime? _toDateTime(dynamic value) {
    return CalligroDateUtils.toDateTime(value);
  }

  /// Sends a broadcast notification (simulated via high-level log or actual FCM)
  Future<void> broadcastMessage(String title, String message, String audience) async {
    // This will trigger a Cloud Function that sends the actual FCM push
    await _firestore.collection('broadcasts').add({
      'title': title,
      'message': message,
      'targetAudience': audience,
      'createdAt': FieldValue.serverTimestamp(),
      'sentBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  // --- MODERATION ---

  /// Deletes a course from the platform
  Future<void> deleteCourse(String courseId) async {
    await _firestore.collection('courses').doc(courseId).delete();
  }

  /// Deletes a community post
  Future<void> deletePost(String postId) async {
    await _firestore.collection('community_posts').doc(postId).delete();
  }

  // --- ROLE MANAGEMENT ---

  /// Returns a stream of all admins/co-admins
  Stream<List<Map<String, dynamic>>> getAdmins() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList());
  }

  /// Promotes a user to co-admin by email
  Future<void> promoteToAdminByEmail(String email) async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("User not found with this email");
    }

    await query.docs.first.reference.update({'role': 'admin'});
  }

  /// Revokes admin status from a user
  Future<void> revokeAdminStatus(String uid) async {
    // Safety check: Don't allow revoking self (optional, usually handled in UI)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == uid) {
      throw Exception("You cannot revoke your own admin status");
    }

    await _firestore.collection('users').doc(uid).update({'role': 'student'});
  }

  /// Deletes a user document from Firestore AND Authentication
  Future<void> deleteUser(String uid) async {
    debugPrint("----------------------------------------------------------------");
    debugPrint("DEBUG: Deleting User: $uid");

    try {
      // 1. Fetch user data to know what to clean up
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        debugPrint("WARNING: User $uid not found in users collection. Proceeding with blind cleanup.");
      }

      final data = userDoc.data() ?? {};
      final email = data['email'] as String? ?? '';
      final name = data['name'] as String? ?? '';
      final phone = data['phone'] as String?;
      final role = data['role'] as String? ?? 'student';

      // 2. Call Cloud Function to delete Auth Account
      try {
        debugPrint("DEBUG: Calling cloud function deleteUserAccount...");
        final functions = FirebaseFunctions.instance;
        final result = await functions.httpsCallable('deleteUserAccount').call(
          {'uid': uid},
        );
        debugPrint("DEBUG: Cloud Function Result: ${result.data}");
      } on FirebaseFunctionsException catch (e) {
        debugPrint("ERROR: Cloud Function failed!");
        debugPrint("  Code: ${e.code}");
        debugPrint("  Message: ${e.message}");
        debugPrint("  Details: ${e.details}");
      } catch (e) {
        debugPrint("ERROR: General failure in cloud function call: $e");
      }

      // 3. Batch Delete Firestore Data
      final batch = _firestore.batch();

      // A. Main User Doc
      batch.delete(_firestore.collection('users').doc(uid));

      // B. Role Specific Doc
      if (role == 'teacher') {
        batch.delete(_firestore.collection('teachers').doc(uid));
      } else if (role == 'student') {
        batch.delete(_firestore.collection('students').doc(uid));
      }

      // C. Locked Identifiers
      if (email.isNotEmpty) {
        batch.delete(_firestore.collection('locked_emails').doc(email.trim().toLowerCase()));
      }
      if (name.isNotEmpty) {
        batch.delete(_firestore.collection('locked_usernames').doc(name.trim().toLowerCase()));
      }
      if (phone != null && phone.isNotEmpty) {
        final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
        batch.delete(_firestore.collection('locked_phones').doc(cleanPhone));
      }

      await batch.commit();
      debugPrint("DEBUG: User deletion complete.");
      debugPrint("----------------------------------------------------------------");

    } catch (e) {
      debugPrint("ERROR: Failed to delete user: $e");
      throw Exception("Failed to delete user: $e");
    }
  }

  /// Rejects a teacher application by setting status to 'rejected'
  Future<void> rejectTeacher(String uid) async {
    debugPrint("----------------------------------------------------------------");
    debugPrint("DEBUG: Rejecting Teacher: $uid");
    
    try {
      final batch = _firestore.batch();

      // 1. Update status in users collection
      // We keep the user document so they can see the rejection screen
      batch.update(_firestore.collection('users').doc(uid), {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // 2. Delete from teachers collection
      // This ensures they don't show up in any teacher lists or searches
      batch.delete(_firestore.collection('teachers').doc(uid));

      await batch.commit();
      debugPrint("DEBUG: Rejection status set and teacher doc removed.");
    } catch (e) {
      debugPrint("ERROR: Failed to reject teacher: $e");
      rethrow;
    }
    debugPrint("----------------------------------------------------------------");
  }

  /// Changes a user's role directly
  Future<void> changeUserRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({'role': newRole});
  }

  /// Sends a targeted notification to a specific user
  Future<void> sendUserNotification(String uid, String title, String message) async {
    await _firestore.collection('users').doc(uid).collection('notifications').add({
      'title': title,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'admin_message',
    });
  }

  // --- CONTENT STREAMS ---

  Stream<List<Map<String, dynamic>>> getAllCourses() {
    return _firestore.collection('courses').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getAllPosts() {
    return _firestore
        .collection('community_posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // --- PAYOUTS ---

  /// Returns a stream of all teacher withdrawal requests
  Stream<List<Map<String, dynamic>>> getWithdrawalRequests() {
    return _firestore
        .collection('withdrawal_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }

  /// Updates the status of a withdrawal request
  Future<void> updateWithdrawalStatus({
    required String requestId,
    required String status,
    String? adminNote,
  }) async {
    final updateData = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (adminNote != null) {
      updateData['adminNote'] = adminNote;
    }

    await _firestore.collection('withdrawal_requests').doc(requestId).update(updateData);

    // If completed or rejected, we could notify the teacher here
    if (status == 'completed' || status == 'rejected') {
      final doc = await _firestore.collection('withdrawal_requests').doc(requestId).get();
      final teacherId = doc.data()?['teacherId'];
      if (teacherId != null) {
        final title = status == 'completed' ? 'Payout Completed' : 'Payout Rejected';
        final message = status == 'completed' 
            ? 'Your withdrawal request has been processed successfully.' 
            : 'Your withdrawal request was rejected. Note: ${adminNote ?? "No reason provided"}';
        
      }
    }
  }

  // --- FINANCIALS ---
  
  /// Returns a stream of all financial transactions
  Stream<List<Map<String, dynamic>>> getFinancialTransactions() {
    return _firestore
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }

  /// Updates a transaction status (e.g., from 'pending_store' to 'settled')
  Future<void> updateTransactionStatus(String transactionId, String newStatus) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': newStatus,
      'settledAt': newStatus == 'settled' ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Aggregates financial data by Teacher
  Stream<Map<String, Map<String, dynamic>>> getTeacherFinancialSnapshots() {
    return getFinancialTransactions().map((transactions) {
      final Map<String, Map<String, dynamic>> teacherStats = {};
      
      for (var tx in transactions) {
        final tid = tx['teacherId'] as String? ?? 'unknown';
        final tname = tx['teacherName'] as String? ?? 'Unknown';
        final amount = (tx['amount'] ?? 0).toDouble();
        final teacherShare = (tx['teacherShare'] ?? 0).toDouble();
        final status = tx['status'] as String? ?? 'pending_store';
        
        if (!teacherStats.containsKey(tid)) {
          teacherStats[tid] = {
            'name': tname,
            'totalGross': 0.0,
            'totalTeacherShare': 0.0,
            'pendingAmount': 0.0,
            'settledAmount': 0.0,
            'courses': <String, Map<String, dynamic>>{}, // cid -> stats
          };
        }
        
        teacherStats[tid]!['totalGross'] += amount;
        teacherStats[tid]!['totalTeacherShare'] += teacherShare;
        
        if (status == 'settled') {
          teacherStats[tid]!['settledAmount'] += teacherShare;
        } else {
          teacherStats[tid]!['pendingAmount'] += teacherShare;
        }
        
        // Per-Course granularity
        final cid = tx['courseId'] as String? ?? 'unknown';
        final cname = tx['courseName'] as String? ?? 'Unknown Course';
        final Map<String, dynamic> courses = teacherStats[tid]!['courses'];
        
        if (!courses.containsKey(cid)) {
          courses[cid] = {
            'name': cname,
            'gross': 0.0,
            'share': 0.0,
            'count': 0,
          };
        }
        courses[cid]!['gross'] += amount;
        courses[cid]!['share'] += teacherShare;
        courses[cid]!['count'] += 1;
      }
      
      return teacherStats;
    });
  }
}
