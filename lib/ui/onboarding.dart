import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/native.dart';
import '../core/security.dart';
import 'code_entry.dart';
import 'theme.dart';
import 'widgets.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> with WidgetsBindingObserver {
  int _step = 0;
  bool _camera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await AppState.I.refreshStatus();
    _camera = await Native.hasPermission('camera');
    if (mounted) setState(() {});
  }

  Future<void> _createCode() async {
    final r = await CodeEntryPage.open(
      context,
      type: AppState.I.config.type,
      title: 'Create a code',
      subtitle: 'This code unlocks your protected apps',
      allowTypeSwitch: true,
    );
    if (r == null) return;
    final salt = Security.newSalt();
    AppState.I.update((c) {
      c.type = r.type;
      c.salt = salt;
      c.hash = Security.hash(r.code, salt);
    });
    await _refresh();
    setState(() => _step = 2);
  }

  Future<void> _finish() async {
    AppState.I.update((c) => c.setupDone = true);
    await AppState.I.save();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_step), child: _step == 0 ? _welcome() : _permissions()),
      ),
    );
  }

  Widget _welcome() {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(28, pad.top + 40, 28, pad.bottom + 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x33FFFFFF), blurRadius: 40, spreadRadius: -12)],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(26), child: Image.asset('assets/logo.webp')),
          ),
          const SizedBox(height: 26),
          const Text(
            'So Lock',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -1.2),
          ),
          const SizedBox(height: 8),
          Text('Your apps. Only for you.', style: T.sub.copyWith(fontSize: 16)),
          const Spacer(flex: 2),
          const _Feature(CupertinoIcons.lock_shield_fill, 'Lock any app', 'With PIN, password or biometrics'),
          const _Feature(
            CupertinoIcons.exclamationmark_shield_fill,
            'Decoy codes',
            'Under pressure? A decoy code locks the screen or fakes a crash',
          ),
          const _Feature(CupertinoIcons.camera_fill, 'Intruder Alert', 'Catch whoever enters a wrong code'),
          const _Feature(CupertinoIcons.location_fill, 'Smart Lock', 'Automatic by time, place and Wi‑Fi'),
          const Spacer(flex: 3),
          PrimaryButton(
            'Get Started',
            onTap: () {
              setState(() => _step = 1);
              _createCode().then((_) {
                if (_step == 1 && mounted) setState(() => _step = 0);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _permissions() {
    final pad = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        return ListView(
          padding: EdgeInsets.fromLTRB(0, pad.top + 40, 0, pad.bottom + 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text('Permissions', style: T.big),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 26),
              child: Text(
                'So Lock needs a few permissions. Nothing ever leaves your phone.',
                style: T.sub.copyWith(fontSize: 15),
              ),
            ),
            Section(
              footer: 'Accessibility → So Lock → On. Used only to detect which app is opened.',
              children: [
                Tile(
                  leading: const Glyph(CupertinoIcons.eye_fill, C.blue),
                  title: 'App detection',
                  subtitle: s.accessibilityOn ? 'On' : 'Required',
                  trailing: _StatusButton(on: s.accessibilityOn, onTap: Native.openAccessibility),
                ),
              ],
            ),
            Section(
              footer: 'Takes a photo when someone enters a wrong code.',
              children: [
                Tile(
                  leading: const Glyph(CupertinoIcons.camera_fill, C.orange),
                  title: 'Camera',
                  subtitle: _camera ? 'Granted' : 'Optional',
                  trailing: _StatusButton(
                    on: _camera,
                    onTap: () async {
                      _camera = await Native.requestPermission('camera');
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            if (s.biometricAvailable)
              Section(
                children: [
                  SwitchTile(
                    leading: const Glyph(Icons.fingerprint_rounded, C.green),
                    title: 'Biometrics',
                    subtitle: 'Unlock with fingerprint or face',
                    value: s.config.biometrics,
                    onChanged: (v) => s.update((c) => c.biometrics = v),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PrimaryButton('Continue', onTap: _finish),
            ),
          ],
        );
      },
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.sub);
  final IconData icon;
  final String title, sub;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: C.silver, size: 26),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.title.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text(sub, style: T.sub),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (on) return const Icon(CupertinoIcons.checkmark_circle_fill, color: C.green, size: 26);
    return Pressable(
      onTap: onTap,
      color: C.silver,
      pressedColor: C.text2,
      radius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          'Enable',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}
