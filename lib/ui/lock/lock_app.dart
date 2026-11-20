import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../core/native.dart';
import '../../core/store.dart';
import '../theme.dart';
import 'lock_view.dart';

/// Root of the pre-warmed lock engine (shown over protected apps).
class LockApp extends StatefulWidget {
  const LockApp({super.key});
  @override
  State<LockApp> createState() => _LockAppState();
}

class _LockAppState extends State<LockApp> {
  AppConfig? _cfg;
  LockTarget? _target;
  int _session = 0;
  bool _done = true;
  bool _hostResumed = false;
  int _visibilityEpoch = 0;
  int _request = 0;
  String? _opening;
  final _bio = _Pulse();
  final Map<String, (String, Uint8List?)> _info = {};

  @override
  void initState() {
    super.initState();
    Native.setHandler((call) async {
      switch (call.method) {
        case 'target':
          await _open(call.arguments as String?);
        case 'resumed':
          final visibility = ++_visibilityEpoch;
          final pkg = call.arguments as String?;
          if (pkg != null && (pkg != _target?.pkg || _done)) await _open(pkg);
          if (!mounted || visibility != _visibilityEpoch) return null;
          setState(() => _hostResumed = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _bio.pulse());
        case 'stopped':
          _visibilityEpoch++;
          _hostResumed = false;
          _request++;
          _opening = null;
          if (mounted) {
            setState(() {
              _done = true;
              _target = null;
            });
          }
      }
      return null;
    });
    // Warm caches so the very first lock is instant.
    Store.loadConfig().then((c) => _cfg ??= c);
    Native.getLockTarget().then((p) {
      if (p != null) _open(p);
    });
  }

  Future<void> _open(String? pkg) async {
    if (pkg == null) return;
    if (_opening == pkg) return;
    if (pkg == _target?.pkg && !_done) return; // same lock still on screen — keep typed digits
    final request = ++_request;
    _opening = pkg;
    final cfgF = Store.loadConfig();
    final cached = _info[pkg];
    String name = cached?.$1 ?? '';
    Uint8List? icon = cached?.$2;
    if (cached == null) {
      final m = await Native.getAppInfo(pkg);
      name = (m?['name'] as String?) ?? pkg;
      icon = m?['icon'] as Uint8List?;
      _info[pkg] = (name, icon);
    }
    final cfg = await cfgF;
    if (!mounted || request != _request) return;
    _opening = null;
    setState(() {
      _cfg = cfg;
      _target = LockTarget(pkg: pkg, name: name, icon: icon);
      _session++;
      _done = false;
    });
  }

  void _unlocked() {
    if (_done) return;
    final pkg = _target?.pkg;
    _done = true;
    Native.unlockSuccess(pkg);
  }

  @override
  void dispose() {
    _request++;
    Native.setHandler((_) async => null);
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lockOverlayStyle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0C),
          resizeToAvoidBottomInset: false,
          body: _cfg == null || _target == null
              ? const ColoredBox(color: Color(0xFF0A0A0C))
              : LockView(
                  key: ValueKey(_session),
                  config: _cfg!,
                  active: _hostResumed,
                  target: _target!,
                  bioTrigger: _bio,
                  onUnlock: _unlocked,
                ),
        ),
      ),
    );
  }
}

class _Pulse extends ChangeNotifier {
  void pulse() => notifyListeners();
}
