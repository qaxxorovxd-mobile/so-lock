import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'ui/home.dart';
import 'ui/lock/gate.dart';
import 'ui/lock/lock_app.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  await AppState.I.init();
  runApp(const SoLock());
}

/// Entry point of the pre-warmed lock engine (started natively).
@pragma('vm:entry-point')
void lockMain() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LockApp());
}

class SoLock extends StatefulWidget {
  const SoLock({super.key});
  @override
  State<SoLock> createState() => _SoLockState();
}

class _SoLockState extends State<SoLock> {
  late bool _setup = AppState.I.config.setupDone;
  bool _justSetup = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp(
        title: 'So Lock',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: _setup
            ? LockGate(startLocked: !_justSetup, child: const Home())
            : Onboarding(onDone: () => setState(() => _setup = _justSetup = true)),
        builder: (context, child) => MediaQuery(
          // Keep the carefully tuned layout stable under extreme font scaling.
          data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2)),
          child: child!,
        ),
      ),
    );
  }
}
