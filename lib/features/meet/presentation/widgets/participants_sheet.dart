import 'package:flutter/material.dart';

import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/meet_controller.dart';
import '../../domain/meet_participant.dart';
import 'meet_dialogs.dart';

void showParticipantsSheet(BuildContext context, MeetController controller) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF13151A),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ParticipantsSheet(controller: controller),
  );
}

/// Teacher's class roster: hands, mute mic/camera, remove.
class ParticipantsSheet extends StatefulWidget {
  final MeetController controller;
  const ParticipantsSheet({super.key, required this.controller});

  @override
  State<ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends State<ParticipantsSheet> {
  // Flip the icon immediately after a successful mute (before LiveKit reports it).
  final _mutedMic = <String>{};
  final _mutedCamera = <String>{};

  MeetController get c => widget.controller;

  Future<void> _mute(MeetParticipant p, {required bool mic}) async {
    if (!await showConfirmMuteDialog(context, mic: mic)) return;
    final ok = await c.muteParticipant(p.identity, mic: mic);
    if (ok && mounted) setState(() => (mic ? _mutedMic : _mutedCamera).add(p.identity));
  }

  Future<void> _kick(MeetParticipant p) async {
    if (!await showConfirmKickDialog(context)) return;
    await c.kick(p.identity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        // One row per person (screen-share tiles share the identity); us first.
        final people = <String, MeetParticipant>{
          for (final p in c.participants.where((p) => !p.isScreenShareTile)) p.identity: p,
        }.values.toList()
          ..sort((a, b) => a.isLocal == b.isLocal ? 0 : (a.isLocal ? -1 : 1));

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.participants,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                    child: Text('${people.length}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: people.isEmpty
                    ? Center(child: Text(l10n.noOtherParticipants, style: const TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: people.length,
                        itemBuilder: (context, i) => _row(context, l10n, people[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, MeetParticipant p) {
    final name = p.displayName;
    final avatar = p.avatarUrl;
    final micOn = !_mutedMic.contains(p.identity) && p.isMicrophoneEnabled;
    final camOn = !_mutedCamera.contains(p.identity) && p.isCameraEnabled;

    Widget action(Key key, IconData icon, Color color, VoidCallback onTap, {double size = 22}) => Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: color, size: size)),
          ),
        );

    return Padding(
      key: Key('participant-row-${p.identity}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEBB937),
            radius: 18,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    p.isLocal ? '$name ${l10n.youLabel}' : name,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (p.isModerator) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: Text(l10n.adminLabel,
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          if (c.raisedHands.contains(p.identity)) ...[
            action(Key('lower-hand-${p.identity}'), Icons.pan_tool, const Color(0xFFEBB937),
                () => c.forceLowerHand(p.identity),
                size: 20),
            const SizedBox(width: 4),
          ],
          // Only students can be moderated (the server refuses moderators anyway).
          if (!p.isLocal && !p.isModerator && c.isTeacher) ...[
            action(Key('mute-mic-${p.identity}'), micOn ? Icons.mic : Icons.mic_off,
                micOn ? Colors.white : Colors.red, () => _mute(p, mic: true)),
            const SizedBox(width: 4),
            action(Key('mute-camera-${p.identity}'), camOn ? Icons.videocam : Icons.videocam_off,
                camOn ? Colors.white : Colors.red, () => _mute(p, mic: false)),
            const SizedBox(width: 4),
            action(Key('kick-${p.identity}'), Icons.person_remove, Colors.redAccent, () => _kick(p)),
          ],
        ],
      ),
    );
  }
}
