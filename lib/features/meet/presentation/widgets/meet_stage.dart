import 'package:flutter/material.dart';

import '../../application/meet_controller.dart';
import 'participant_tile.dart';

/// Speaker layout: one participant full-screen + a single floating PiP.
class MeetStageView extends StatelessWidget {
  final MeetStage stage;
  final Set<String> raisedHands;
  final bool controlsVisible;

  const MeetStageView({super.key, required this.stage, required this.raisedHands, required this.controlsVisible});

  @override
  Widget build(BuildContext context) {
    final pip = stage.pip;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: ParticipantTile(
              key: const Key('stage-focus'),
              participant: stage.focus,
              isHandRaised: raisedHands.contains(stage.focus.identity),
            ),
          ),
        ),
        if (pip != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            bottom: controlsVisible ? 80 : 16,
            left: 16,
            child: Container(
              width: 120, // 16:9
              height: 75,
              decoration: BoxDecoration(
                color: const Color(0xFF13151A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ParticipantTile(
                key: const Key('stage-pip'),
                participant: pip,
                isHandRaised: raisedHands.contains(pip.identity),
                isPiP: true,
              ),
            ),
          ),
      ],
    );
  }
}

/// Gallery layout: every tile in a 16:9 grid. Tapping a tile returns to the speaker layout.
class MeetGridView extends StatelessWidget {
  final MeetController controller;
  final bool controlsVisible;
  final VoidCallback onTileTap;

  const MeetGridView({super.key, required this.controller, required this.controlsVisible, required this.onTileTap});

  @override
  Widget build(BuildContext context) {
    final tiles = controller.participants;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(12, controlsVisible ? 70 : 12, 12, controlsVisible ? 80 : 12),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: controller.gridColumns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 16 / 9,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, index) {
          final p = tiles[index];
          final isTeacherTile = p.isLocal ? controller.isTeacher : p.isModerator;
          return Container(
            key: Key('grid-tile-${p.identity}${p.isScreenShareTile ? '-screen' : ''}'),
            decoration: BoxDecoration(
              color: const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTeacherTile ? const Color(0xFFEBB937).withValues(alpha: 0.6) : Colors.white12,
                width: isTeacherTile ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTileTap,
              child: ParticipantTile(
                participant: p,
                isHandRaised: controller.raisedHands.contains(p.identity),
                isPiP: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
