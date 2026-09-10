import 'package:media_kit/media_kit.dart';

/// Returns a [Player] for a bundled asset video.
Future<Player> createAssetVideoController(String assetPath) async {
  final player = Player();
  await player.open(Media('asset://$assetPath'), play: false);
  return player;
}
