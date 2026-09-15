import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:calligro_app/features/auth/data/services/email_service.dart';

import 'email_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('Layer 2: EmailService Tests (Coverage)', () {
    late MockClient mockClient;
    late EmailService emailService;

    setUp(() async {
      mockClient = MockClient();
      emailService = EmailService.forTest(client: mockClient);
      
      await dotenv.load(mergeWith: {'BREVO_API_KEY': 'test_key'});
    });

    test('sendOtp() returns true on success', () async {
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Success', 200));

      final result = await emailService.sendOtp('test@test.com', '123456');
      expect(result, true);
    });

    test('sendOtp() returns false on failure', () async {
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Error', 400));

      final result = await emailService.sendOtp('test@test.com', '123456');
      expect(result, false);
    });
    
    test('sendOtp() handles exceptions', () async {
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenThrow(Exception('Network Error'));

      final result = await emailService.sendOtp('test@test.com', '123456');
      expect(result, false);
    });
  });
}
