import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class StepTeacherFinish extends StatelessWidget {
  const StepTeacherFinish({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 50),
          const SizedBox(height: 20),
          Text(
            l10n.teacherFinishMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
