import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/community/services/user_service.dart';

void main() {
  group('Layer 2: UserService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService userService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      userService = UserService(firestore: fakeFirestore);
    });

    test('getUserRole() returns role when user exists', () async {
      await fakeFirestore.collection('users').doc('u1').set({'role': 'teacher'});
      final role = await userService.getUserRole('u1');
      expect(role, 'teacher');
    });

    test('getUserRole() defaults to student when role missing', () async {
      await fakeFirestore.collection('users').doc('u2').set({'name': 'John'});
      final role = await userService.getUserRole('u2');
      expect(role, 'student');
    });

    test('getUserRole() defaults to student when doc does not exist', () async {
      final role = await userService.getUserRole('u3');
      expect(role, 'student');
    });

    test('getUserRole() defaults to student when userId is empty', () async {
      final role = await userService.getUserRole('');
      expect(role, 'student');
    });

    test('getUserStream() returns a stream', () {
      expect(userService.getUserStream('u1'), isA<Stream>());
    });

    test('searchUsersByName() returns empty list for empty query', () async {
      final results = await userService.searchUsersByName('   ');
      expect(results, isEmpty);
    });

    test('searchUsersByName() returns matching users', () async {
      await fakeFirestore.collection('users').doc('u1').set({'name_lower': 'alice'});
      await fakeFirestore.collection('users').doc('u2').set({'name_lower': 'bob'});
      await fakeFirestore.collection('users').doc('u3').set({'name_lower': 'alicia'});

      final results = await userService.searchUsersByName('ali');
      
      expect(results.length, 2);
      final ids = results.map((r) => r['id']).toList();
      expect(ids, containsAll(['u1', 'u3']));
    });
  });
}
