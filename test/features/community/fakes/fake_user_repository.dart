import 'package:calligro_app/features/community/domain/models/community_user.dart';
import 'package:calligro_app/features/community/domain/repositories/user_repository.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, CommunityUser> users = {};

  void addUser(CommunityUser user) {
    users[user.id] = user;
  }

  @override
  Future<CommunityUser> getUser(String userId) async {
    final user = users[userId];
    if (user != null) return user;
    return CommunityUser(id: userId, name: 'User_$userId');
  }

  @override
  Future<List<CommunityUser>> getUsers(List<String> userIds) async {
    return userIds.map((id) => users[id] ?? CommunityUser(id: id, name: 'User_$id')).toList();
  }

  @override
  Future<List<CommunityUser>> searchUsers(String query, {int limit = 20}) async {
    final lower = query.toLowerCase();
    return users.values
        .where((u) => u.name.toLowerCase().contains(lower))
        .take(limit)
        .toList();
  }
}

