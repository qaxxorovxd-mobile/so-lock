import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../../core/security.dart';
import '../code_entry.dart';
import '../lock/gate.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customize_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _changeCode(BuildContext context) async {
    final s = AppState.I;
    if (!await verifyCurrent(context, s.config, (c) => Security.isMain(s.config, c))) return;
    if (!context.mounted) return;
    final r = await CodeEntryPage.open(
      context,
      type: s.config.type,
      title: 'New code',
      subtitle: 'New code for your protected apps',
      allowTypeSwitch: true,
      validate: (c) {
        final h = Security.hash(c, s.config.salt);
        if (s.config.duress.any((d) => d.hash == h)) return 'This code is used as a decoy code';
        return null;
      },
    );
    if (r == null || !context.mounted) return;
    final dropDuress = r.type.length != s.config.type.length || r.type.isPin != s.config.type.isPin;
    if (dropDuress && s.config.duress.isNotEmpty) {
      final ok = await confirm(
        context,
        'Decoy codes will be removed',
        'The code type changed, so existing decoy codes no longer match and will be removed. You can add new ones afterwards.',
        ok: 'Continue',
        destructive: true,
      );
      if (!ok) return;
    }
    s.update((c) {
      c.type = r.type;
      c.hash = Security.hash(r.code, c.salt);
      if (dropDuress) c.duress.clear();
    });
    if (context.mounted) toast(context, 'Code updated');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final c = s.config;
        return LargeTitlePage(
          title: 'Settings',
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset('assets/logo.webp', width: 60, height: 60),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'So Lock',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: C.text, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s.accessibilityOn && c.enabled ? 'Protection on · ${c.locked.length} apps' : 'Protection is off',
                                style: T.sub,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Section(
                  header: 'Access',
                  children: [
                    Tile(
                      leading: const Glyph(CupertinoIcons.lock_fill, C.blue),
                      title: 'Change code',
                      value: c.type.label,
                      chevron: true,
                      onTap: () => _changeCode(context),
                    ),
                    SwitchTile(
                      leading: const Glyph(Icons.fingerprint_rounded, C.green),
                      title: 'Biometrics',
                      subtitle: s.biometricAvailable ? 'Falls back to your code if it fails' : 'Not set up on this device',
                      value: c.biometrics && s.biometricAvailable,
                      onChanged: s.biometricAvailable ? (v) => s.update((c) => c.biometrics = v) : null,
                    ),
                    SwitchTile(
                      leading: const Glyph(CupertinoIcons.shield_lefthalf_fill, C.indigo),
                      title: 'Lock So Lock itself',
                      value: c.lockSelf,
                      onChanged: (v) => s.update((c) => c.lockSelf = v),
                    ),
                  ],
                ),
                Section(
                  header: 'Appearance',
                  children: [
                    Tile(
                      leading: const Glyph(CupertinoIcons.paintbrush_fill, C.pink),
                      title: 'Lock Screen',
                      subtitle: 'Fon, rang, klaviatura, animatsiya',
                      chevron: true,
                      onTap: () => push(context, const CustomizePage()),
                    ),
                  ],
                ),
                if (Native.isAndroid)
                  Section(
                    header: 'Permissions',
                    children: [
                      Tile(
                        leading: const Glyph(CupertinoIcons.eye_fill, C.blue),
                        title: 'App detection',
                        value: s.accessibilityOn ? 'On' : 'Off',
                        chevron: true,
                        onTap: () {
                          LockGate.suppress();
                          Native.openAccessibility();
                        },
                      ),
                      Tile(
                        leading: const Glyph(CupertinoIcons.gear_alt_fill, Color(0xFF636366)),
                        title: 'App permissions',
                        chevron: true,
                        onTap: () {
                          LockGate.suppress();
                          Native.openAppSettings();
                        },
                      ),
                    ],
                  ),
                const Section(
                  header: 'About',
                  footer: 'All data stays on this device. Codes are stored only as salted hashes.',
                  children: [Tile(title: 'Version', value: '1.1.0')],
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
