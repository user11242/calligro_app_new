import 'dart:async';

import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:calligro_app/features/notifications/domain/notification_repositories.dart';

class RecordingNavigator implements NotificationNavigator {
  final opened = <NotificationTarget>[];
  @override
  void open(NotificationTarget target) => opened.add(target);
}

class FakePushGateway implements PushGateway {
  String? currentToken = 'tok-1';
  int deletes = 0;
  @override
  Future<String?> token() async => currentToken;
  @override
  Future<void> deleteToken() async {
    deletes++;
    currentToken = 'tok-${deletes + 1}';
  }
}

class FakePushTokenStore implements PushTokenStore {
  final tokens = <String, String>{};
  @override
  Future<void> save(String uid, String token, {required String language}) async => tokens[uid] = token;
  @override
  Future<void> clear(String uid, String token) async {
    if (tokens[uid] == token) tokens.remove(uid);
  }
}

class FakeInboxRepository implements InboxRepository {
  final items = <String, List<InboxItem>>{};
  final readCalls = <String>[];
  final _changes = StreamController<void>.broadcast(sync: true);

  void put(String uid, InboxItem item) {
    (items[uid] ??= []).insert(0, item);
    _changes.add(null);
  }

  Stream<T> _live<T>(T Function() read) {
    late final StreamController<T> c;
    StreamSubscription<void>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = _changes.stream.listen((_) => c.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<List<InboxItem>> watch(String uid) => _live(() => List.of(items[uid] ?? const []));
  @override
  Stream<int> watchUnreadCount(String uid) => _live(() => (items[uid] ?? const []).where((i) => !i.read).length);

  void _setRead(String uid, bool Function(InboxItem) which) {
    items[uid] = [
      for (final i in items[uid] ?? const <InboxItem>[])
        which(i)
            ? InboxItem(id: i.id, title: i.title, body: i.body, type: i.type, read: true, createdAt: i.createdAt, target: i.target)
            : i,
    ];
    _changes.add(null);
  }

  @override
  Future<void> markRead(String uid, String itemId) async {
    readCalls.add(itemId);
    _setRead(uid, (i) => i.id == itemId);
  }

  @override
  Future<void> markAllRead(String uid) async => _setRead(uid, (_) => true);
}
