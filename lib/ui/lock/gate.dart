import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'lock_view.dart';

/// Locks So Lock itself whenever it returns from the background.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child, this.startLocked = true});
  final Widget child;
  final bool startLocked;

  static DateTime? _suppressUntil;

  /// Call before opening system screens we launched ourselves (settings, pickers, permission dialogs).
  static void suppress() => _suppressUntil = DateTime.now().add(const Duration(minutes: 3));

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = widget.startLocked && AppState.I.config.lockSelf;
  int _session = 0;

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
    if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
      final suppressed = LockGate._suppressUntil != null && DateTime.now().isBefore(LockGate._suppressUntil!);
      if (!suppressed && AppState.I.config.lockSelf && !_locked) {
        // Lock before the app is visible again, so contents never flash.
        setState(() {
          _locked = true;
          _session++;
        });
      }
    } else if (s == AppLifecycleState.resumed) {
      LockGate._suppressUntil = null;
      AppState.I.refreshStatus();
      AppState.I.loadIntruders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Content stays mounted (instant unlock) but is hidden from the tree while locked.
        Offstage(
          offstage: _locked,
          child: TickerMode(enabled: !_locked, child: widget.child),
        ),
        if (_locked)
          LockView(
            key: ValueKey(_session),
            config: AppState.I.config,
            target: const LockTarget(name: 'So Lock'),
            onUnlock: () => setState(() => _locked = false),
          ),
      ],
    );
  }
}
