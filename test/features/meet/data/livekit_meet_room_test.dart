import 'package:calligro_app/features/meet/data/livekit_meet_room.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  group('LiveKitMeetRoom.isRelayRetryable', () {
    test('should retry on ConnectException with InternalError', () {
      final error = ConnectException('err', reason: ConnectionErrorReason.InternalError);
      expect(LiveKitMeetRoom.isRelayRetryable(error), isTrue);
    });

    test('should retry on ConnectException with Timeout', () {
      final error = ConnectException('err', reason: ConnectionErrorReason.Timeout);
      expect(LiveKitMeetRoom.isRelayRetryable(error), isTrue);
    });

    test('should NOT retry on ConnectException with NotAllowed', () {
      final error = ConnectException('err', reason: ConnectionErrorReason.NotAllowed);
      expect(LiveKitMeetRoom.isRelayRetryable(error), isFalse);
    });

    test('should retry on pure TimeoutException', () {
      final error = TimeoutException('err');
      expect(LiveKitMeetRoom.isRelayRetryable(error), isTrue);
    });

    test('should retry on NegotiationError', () {
      final error = NegotiationError('err');
      expect(LiveKitMeetRoom.isRelayRetryable(error), isTrue);
    });

    test('unknown errors (e.g. socket failures) get one relay attempt', () {
      expect(LiveKitMeetRoom.isRelayRetryable(Exception('socket closed')), isTrue);
    });

    test('should NOT retry on LiveKitE2EEException', () {
      final error = LiveKitE2EEException('err');
      expect(LiveKitMeetRoom.isRelayRetryable(error), isFalse);
    });
  });
}
