import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../lock/gate.dart';
import '../theme.dart';
import '../widgets.dart';
import 'duress_page.dart';
import 'intruder_page.dart';
import 'smart_page.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final c = s.config;
        final recent = s.intruders.take(6).toList();
        return LargeTitlePage(
          title: 'Security',
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                // ---- Duress codes ----
                const _Hero(),
                Section(
                  header: 'Decoy codes',
                  footer:
                      'A decoy code looks like a normal code to anyone watching. When entered, the chosen action runs.',
                  children: [
                    for (final d in c.duress)
                      Tile(
                        leading: Glyph(_icon(d.action), _color(d.action)),
                        title: d.label.isEmpty ? 'Decoy code' : d.label,
                        subtitle: d.action.title + (d.photo ? ' · photo' : ''),
                        chevron: true,
                        onTap: () => push(context, DuressEditPage(code: d)),
                      ),
                    Tile(
                      leading: const SizedBox(
                        width: 30,
                        child: Icon(CupertinoIcons.add_circled_solid, color: C.blue, size: 24),
                      ),
                      title: 'Add decoy code',
                      titleColor: C.blue,
                      onTap: () => push(context, const DuressEditPage()),
                    ),
                  ],
                ),
                // ---- Intruder ----
                Section(
                  header: 'Intruder Alert',
                  footer: 'Takes a front-camera photo after wrong attempts. Some devices show a system camera-in-use indicator.',
                  children: [
                    SwitchTile(
                      leading: const Glyph(CupertinoIcons.camera_fill, C.orange),
                      title: 'Take photos',
                      value: c.intruderOn,
                      onChanged: (v) async {
                        if (v) {
                          LockGate.suppress();
                          final ok = await Native.requestPermission('camera');
                          if (!ok) {
                            if (context.mounted) toast(context, 'Camera permission denied');
                            return;
                          }
                        }
                        s.update((c) => c.intruderOn = v);
                      },
                    ),
                    if (c.intruderOn) ...[
                      Tile(
                        title: 'After wrong attempts',
                        trailing: StepperControl(
                          value: c.intruderAfter,
                          min: 1,
                          max: 5,
                          onChanged: (v) => s.update((c) => c.intruderAfter = v),
                        ),
                      ),
                      SwitchTile(
                        title: 'Back camera too',
                        value: c.intruderBack,
                        onChanged: (v) => s.update((c) => c.intruderBack = v),
                      ),
                    ],
                  ],
                ),
                // ---- Log ----
                Section(
                  header: 'Events',
                  children: [
                    if (recent.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Center(child: Text('No intrusion attempts yet', style: T.sub)),
                      )
                    else ...[
                      for (final e in recent) IntruderTile(event: e),
                      if (s.intruders.length > recent.length)
                        Tile(
                          title: 'See all',
                          value: '${s.intruders.length}',
                          chevron: true,
                          onTap: () => push(context, const IntruderPage()),
                        ),
                    ],
                  ],
                ),
              ]),
            ),
          ],
        );
      },
    );
  }

  static IconData _icon(DuressAction a) => switch (a) {
    DuressAction.lockScreen => CupertinoIcons.lock_fill,
    DuressAction.goHome => CupertinoIcons.house_fill,
    DuressAction.fakeCrash => CupertinoIcons.exclamationmark_triangle_fill,
    DuressAction.silentOpen => CupertinoIcons.eye_slash_fill,
  };

  static Color _color(DuressAction a) => switch (a) {
    DuressAction.lockScreen => C.red,
    DuressAction.goHome => C.indigo,
    DuressAction.fakeCrash => C.orange,
    DuressAction.silentOpen => C.teal,
  };
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [C.card, C.card], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.exclamationmark_shield_fill, color: C.silver, size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('If you’re forced', style: T.title),
                SizedBox(height: 4),
                Text(
                  'Example: main code 1550, decoy code 1050. If someone forces you to unlock, give them 1050 — the app won’t open and the screen locks instantly.',
                  style: T.sub,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class IntruderTile extends StatelessWidget {
  const IntruderTile({super.key, required this.event});
  final IntruderEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final photo = e.photos.isEmpty ? null : e.photos.first;
    return Tile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: photo != null && File(photo).existsSync()
              ? Image.file(File(photo), fit: BoxFit.cover, cacheWidth: 140, gaplessPlayback: true)
              : ColoredBox(
                  color: C.card2,
                  child: Icon(
                    e.reason == 'duress'
                        ? CupertinoIcons.exclamationmark_shield
                        : CupertinoIcons.person_crop_circle_badge_xmark,
                    color: C.text2,
                    size: 22,
                  ),
                ),
        ),
      ),
      title: e.appName,
      subtitle: '${e.reason == 'duress' ? 'Decoy code' : '${e.attempts} wrong attempts'} · ${fmtTime(e.time)}',
      chevron: true,
      onTap: () => push(context, IntruderDetailPage(event: e)),
    );
  }
}

String fmtTime(DateTime t) {
  final now = DateTime.now();
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (now.year == t.year && now.month == t.month && now.day == t.day) return 'Today $hm';
  final y = now.subtract(const Duration(days: 1));
  if (y.year == t.year && y.month == t.month && y.day == t.day) return 'Yesterday $hm';
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year} $hm';
}
