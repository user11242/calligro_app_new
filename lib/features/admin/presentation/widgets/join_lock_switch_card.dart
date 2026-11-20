import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/courses/application/join_lock.dart';
import 'package:calligro_app/features/courses/data/firestore_app_features.dart';

/// Admin home: the remote switch for the students' Join-button lock. Turning it OFF
/// lets every student join at any time, on every phone, within seconds (no update).
class JoinLockSwitchCard extends StatefulWidget {
  const JoinLockSwitchCard({super.key, this.features, this.setJoinLock});

  /// Tests pass fakes; the app uses Firestore `app_config/features`.
  final Stream<Map<String, dynamic>?>? features;
  final Future<void> Function(bool on)? setJoinLock;

  @override
  State<JoinLockSwitchCard> createState() => _JoinLockSwitchCardState();
}

class _JoinLockSwitchCardState extends State<JoinLockSwitchCard> {
  late final FirestoreAppFeatures? _firestore =
      widget.features == null || widget.setJoinLock == null ? FirestoreAppFeatures() : null;
  late final Stream<Map<String, dynamic>?> _features = widget.features ?? _firestore!.watch();
  bool _saving = false;
  String? _error;

  Future<void> _set(bool on) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.setJoinLock ?? _firestore!.setJoinLock)(on);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _features,
      builder: (context, snap) {
        final on = JoinLock.enabledFrom(snap.data);
        final color = on ? AppColors.accentGold : const Color(0xFFE5484D);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2026),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(on ? Icons.schedule_rounded : Icons.lock_open_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ar ? 'قفل زر الانضمام للطلاب' : 'Students\' Join button lock',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    on
                        ? (ar ? 'مفعّل: الانضمام من 10 دقائق قبل الحصة حتى 30 دقيقة بعدها'
                            : 'ON: join from 10 min before a class until 30 min after')
                        : (ar ? 'متوقف: يمكن للطلاب الانضمام في أي وقت' : 'OFF: students can join at any time'),
                    key: const Key('joinLockState'),
                    style: TextStyle(color: on ? Colors.white60 : color, fontSize: 12.5, height: 1.4),
                  ),
                ]),
              ),
              _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold))
                  : Switch(
                      key: const Key('joinLockSwitch'),
                      value: on,
                      activeThumbColor: AppColors.accentGold,
                      onChanged: snap.connectionState == ConnectionState.waiting ? null : _set,
                    ),
            ]),
            const SizedBox(height: 10),
            Text(
              ar
                  ? 'إذا أبلغ طالب أن الحصة بدأت ولا يستطيع الانضمام، أوقف القفل هنا: يطبّق على كل الهواتف خلال ثوانٍ.'
                  : 'If a student reports a class is on but they can\'t join, turn it OFF here: every phone follows within seconds.',
              style: const TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.4),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text('${ar ? 'تعذّر الحفظ' : 'Could not save'}: $_error',
                  key: const Key('joinLockError'), style: const TextStyle(color: Color(0xFFE5484D), fontSize: 12)),
            ],
          ]),
        );
      },
    );
  }
}
