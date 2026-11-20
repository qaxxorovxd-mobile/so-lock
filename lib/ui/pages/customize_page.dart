import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/vibe.dart';
import '../lock/gate.dart';
import '../lock/lock_view.dart';
import '../theme.dart';
import '../widgets.dart';

class CustomizePage extends StatelessWidget {
  const CustomizePage({super.key});

  Future<void> _pickImage(BuildContext context) async {
    LockGate.suppress();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (x == null) return;
    final dir = await Store.dir();
    final dest = '${dir.path}/lock_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dest);
    final old = AppState.I.config.style.imagePath;
    AppState.I.update((c) {
      c.style.imagePath = dest;
      c.style.background = -1;
    });
    if (old != null && old != dest) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final st = s.config.style;
        void set(void Function(LockStyle st) f) => s.update((c) => f(c.style));

        return SubPage(
          title: 'Lock Screen',
          children: [
            // ---- live preview ----
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Center(child: _Preview(config: s.config)),
            ),
            Section(
              header: 'Accent',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      for (final a in LockBg.accents)
                        GestureDetector(
                          onTap: () => set((st) => st.accent = a),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(a),
                              border: Border.all(color: st.accent == a ? C.text : Colors.transparent, width: 2.5),
                              boxShadow: st.accent == a ? const [BoxShadow(color: C.bg, spreadRadius: -4.5)] : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Section(
              header: 'Background',
              children: [
                SizedBox(
                  height: 116,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    children: [
                      _BgThumb(
                        selected: st.background == -1,
                        onTap: () => _pickImage(context),
                        label: 'Photo',
                        child: st.imagePath != null && File(st.imagePath!).existsSync()
                            ? Image.file(File(st.imagePath!), fit: BoxFit.cover, cacheWidth: 160)
                            : const ColoredBox(
                                color: C.card2,
                                child: Icon(CupertinoIcons.photo, color: C.text2),
                              ),
                      ),
                      for (var i = 0; i < LockBg.presets.length; i++)
                        _BgThumb(
                          selected: st.background == i,
                          onTap: () => set((st) => st.background = i),
                          label: LockBg.presets[i].name,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: LockBg.presets[i].colors,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (st.background == -1) ...[
                  _SliderTile(
                    label: 'Blur',
                    value: st.blur,
                    min: 0,
                    max: 40,
                    onChanged: (v) => set((st) => st.blur = v),
                  ),
                  _SliderTile(label: 'Dim', value: st.dim, min: 0, max: 0.8, onChanged: (v) => set((st) => st.dim = v)),
                ],
              ],
            ),
            Section(
              header: 'Keypad',
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<KeypadStyle>(
                      groupValue: st.keypad,
                      backgroundColor: C.card2,
                      thumbColor: C.pressed,
                      children: const {
                        KeypadStyle.filled: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Filled')),
                        KeypadStyle.ring: Text('Ring'),
                        KeypadStyle.minimal: Text('Minimal'),
                      },
                      onValueChanged: (v) => set((st) => st.keypad = v ?? KeypadStyle.filled),
                    ),
                  ),
                ),
                SwitchTile(
                  title: 'Shuffle keys',
                  subtitle: 'Key order changes every time — no smudge or shoulder tracking',
                  value: st.shuffle,
                  onChanged: (v) => set((st) => st.shuffle = v),
                ),
              ],
            ),
            Section(
              header: 'Vibration',
              footer: 'Uses the phone’s vibration motor directly, so it works even when system touch feedback is off.',
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: st.vibeLevel,
                      backgroundColor: C.card2,
                      thumbColor: C.pressed,
                      children: const {
                        0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Off')),
                        1: Text('Light'),
                        2: Text('Medium'),
                        3: Text('Strong'),
                      },
                      onValueChanged: (v) {
                        set((st) => st.vibeLevel = v ?? 2);
                        Vibe.preview(v ?? 0);
                      },
                    ),
                  ),
                ),
                if (st.vibeLevel > 0) ...[
                  SwitchTile(title: 'Key presses', value: st.vibeKeys, onChanged: (v) => set((st) => st.vibeKeys = v)),
                  SwitchTile(
                    title: 'Wrong code',
                    subtitle: 'Triple buzz on a wrong code',
                    value: st.vibeError,
                    onChanged: (v) {
                      set((st) => st.vibeError = v);
                      if (v) Vibe.error(st);
                    },
                  ),
                  SwitchTile(
                    title: 'Unlock',
                    subtitle: 'Soft double tap when unlocked',
                    value: st.vibeSuccess,
                    onChanged: (v) {
                      set((st) => st.vibeSuccess = v);
                      if (v) Vibe.success(st);
                    },
                  ),
                ],
              ],
            ),
            Section(
              header: 'Appearance',
              children: [
                SwitchTile(title: 'Show app icon', value: st.showIcon, onChanged: (v) => set((st) => st.showIcon = v)),
                SwitchTile(
                  title: 'Animations',
                  subtitle: 'Smooth entrance, key squish, dot pop, shake on wrong code',
                  value: st.animations,
                  onChanged: (v) => set((st) => st.animations = v),
                ),
              ],
            ),
            Section(
              children: [
                Tile(title: 'Reset to default', titleColor: C.red, onTap: () => s.update((c) => c.style = LockStyle())),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Scaled-down, non-interactive render of the real lock screen.
class _Preview extends StatelessWidget {
  const _Preview({required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    const w = 200.0;
    final screen = MediaQuery.sizeOf(context);
    final h = w * screen.height / screen.width;
    return Container(
      width: w + 8,
      height: h + 8,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF2A2A2E), borderRadius: BorderRadius.circular(30)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: IgnorePointer(
          child: FittedBox(
            child: SizedBox(
              width: screen.width,
              height: screen.height,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 30, bottom: 20)),
                child: LockView(
                  key: ValueKey(config.style.toJson().toString()),
                  config: config,
                  target: const LockTarget(name: 'Telegram'),
                  onUnlock: () {},
                  preview: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BgThumb extends StatelessWidget {
  const _BgThumb({required this.selected, required this.onTap, required this.child, required this.label});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String label;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 50,
            height: 72,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? C.silver : Colors.transparent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox.expand(child: child),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: selected ? C.text : C.text2)),
        ],
      ),
    ),
  );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: T.body)),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ],
    ),
  );
}
