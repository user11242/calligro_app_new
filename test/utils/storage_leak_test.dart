import 'package:flutter_test/flutter_test.dart';

// Simulating Storage Leak Prevention logic

class MockCloudStorage {
  final List<String> firestoreDocuments = ['post_1'];
  final List<String> storageFiles = ['images/post_1.jpg'];

  void deleteCommunityPost(String postId) {
    // 1. Delete the Firestore database document
    firestoreDocuments.remove(postId);

    // 2. Safely extract the image URL and delete it from the heavy storage
    // If we only delete the document, we cause a "Storage Leak" costing money!
    storageFiles.remove('images/$postId.jpg');
  }
}

void main() {
  group('Domain 6: Storage Leak Prevention (Test 31)', () {
    test('Test Case 31: Deleting a post removes both Document AND Storage Image', () {
      final storage = MockCloudStorage();
      
      // Verify initial state
      expect(storage.firestoreDocuments.length, 1);
      expect(storage.storageFiles.length, 1);

      // Perform deletion
      storage.deleteCommunityPost('post_1');

      // Verify the leak prevention math
      expect(storage.firestoreDocuments, isEmpty, reason: 'Firestore document must be deleted');
      expect(storage.storageFiles, isEmpty, reason: 'CRITICAL: Heavy image must be deleted from cloud storage to prevent billing leaks');
    });
  });
}
