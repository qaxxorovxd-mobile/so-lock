import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:so_lock/core/models.dart';
import 'package:so_lock/core/security.dart';
import 'package:so_lock/core/store.dart';
import 'package:so_lock/ui/lock/lock_view.dart';
import 'package:so_lock/ui/theme.dart';

class MemoryGuard extends GuardStore {
  (int, int) value = (0, 0);
  @override
  Future<(int, int)> load() async => value;
  @override
  Future<void> save(int fails, int until) async {
    value = (fails, until);
  }
}

class FakeAuth extends LocalAuthPlatform {
  final attempts = <Completer<bool>>[];
  int stops = 0;
  bool unavailable = false;
  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => [BiometricType.fingerprint];
  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) {
    if (unavailable) throw StateError('sensor unavailable');
    final result = Completer<bool>();
    attempts.add(result);
    return result.future;
  }

  @override
  Future<bool> stopAuthentication() async {
    stops++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryGuard guard;
  late FakeAuth auth;
  late AppConfig config;
  int unlocked = 0;
  setUp(() async {
    guard = MemoryGuard();
    auth = FakeAuth();
    LocalAuthPlatform.instance = auth;
    config = AppConfig()
      ..salt = 'test-salt'
      ..hash = Security.hash('1550', 'test-salt')
      ..intruderOn = false;
    config.style.animations = false;
    config.style.vibeLevel = 0;
    unlocked = 0;
    await guard.save(0, 0);
  });
  Future<void> show(WidgetTester tester, {Listenable? trigger}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: LockView(
            config: config,
            guardStore: guard,
            target: const LockTarget(name: 'Test'),
            bioTrigger: trigger,
            onUnlock: () => unlocked++,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester, String code) async {
    for (final digit in code.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  testWidgets('initial overlay prompts without a lost resume event; repeated triggers do not overlap', (tester) async {
    final pulse = ChangeNotifier();
    await show(tester, trigger: pulse);
    expect(auth.attempts.length, 1);
    pulse.notifyListeners();
    pulse.notifyListeners();
    await tester.pump();
    expect(auth.attempts.length, 1);
    auth.attempts.single.complete(true);
    await tester.pump();
    expect(unlocked, 1);
    pulse.notifyListeners();
    await tester.pump();
    expect(auth.attempts.length, 1);
    await tester.pumpWidget(const SizedBox());
    pulse.dispose();
  });
  testWidgets('disposed screen cancels auth and ignores a late success', (tester) async {
    await show(tester);
    final attempt = auth.attempts.single;
    await tester.pumpWidget(const SizedBox());
    expect(auth.stops, 1);
    attempt.complete(true);
    await tester.pump();
    expect(unlocked, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('background success is rejected and resume permits a fresh attempt', (tester) async {
    await show(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    auth.attempts.first.complete(true);
    await tester.pump();
    expect(unlocked, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.attempts.length, 2);
    auth.attempts.last.complete(true);
    await tester.pump();
    expect(unlocked, 1);
  });
  testWidgets('PIN remains usable when the sensor fails', (tester) async {
    auth.unavailable = true;
    await show(tester);
    expect(find.text('Use your code, or tap to retry biometrics'), findsOneWidget);
    await enter(tester, '1550');
    expect(unlocked, 1);
  });
  testWidgets('PIN success cancels pending biometric and unlocks only once', (tester) async {
    await show(tester);
    await enter(tester, '1550');
    expect(unlocked, 1);
    auth.attempts.single.complete(true);
    await tester.pump();
    expect(unlocked, 1);
    expect(auth.stops, 1);
  });
  testWidgets('persisted lockout blocks both PIN and biometrics on first frame', (tester) async {
    await guard.save(5, DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch);
    await show(tester);
    expect(auth.attempts, isEmpty);
    await enter(tester, '1550');
    expect(unlocked, 0);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('password submit cannot bypass lockout', (tester) async {
    config.type = LockType.password;
    await guard.save(5, DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch);
    await show(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.text = '1550';
    await tester.tap(find.byIcon(CupertinoIcons.arrow_right));
    await tester.pump();
    expect(unlocked, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('prewarmed overlay waits until the host is active', (tester) async {
    Widget screen(bool active) => MaterialApp(theme: buildTheme(), home: Scaffold(body: LockView(
      config: config, guardStore: guard, active: active, target: const LockTarget(name: 'Test'), onUnlock: () => unlocked++)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(screen(false)); await tester.pump(); await tester.pump();
    expect(auth.attempts, isEmpty);
    await tester.pumpWidget(screen(true)); await tester.pump();
    expect(auth.attempts.length, 1);
    auth.attempts.single.complete(true); await tester.pump(); expect(unlocked, 1);
  });
  testWidgets('resume during cancellation retries after the old request settles', (tester) async {
    await show(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await tester.pump();
    expect(auth.attempts.length, 1);
    auth.attempts.first.complete(true); await tester.pump();
    expect(unlocked, 0); expect(auth.attempts.length, 2);
    auth.attempts.last.complete(true); await tester.pump(); expect(unlocked, 1);
  });
  test('lockout stays capped even for very large persisted counters', () {
    expect(Security.lockoutFor(4), Duration.zero);
    expect(Security.lockoutFor(5), const Duration(seconds: 30));
    expect(Security.lockoutFor(100000), const Duration(minutes: 15));
  });
}
