import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'models.dart';
import 'native.dart';
import 'store.dart';

class AppInfo {
  AppInfo(this.pkg, this.name, this.icon);
  final String pkg;
  final String name;
  final Uint8List? icon;
  late final String lower = name.toLowerCase();
}

/// Single source of truth for the main app.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  AppConfig config = AppConfig();
  List<AppInfo> apps = const [];
  bool appsLoading = false;
  bool accessibilityOn = false;
  bool biometricAvailable = false;
  List<IntruderEvent> intruders = const [];

  Timer? _saveDebounce;

  Future<void> init() async {
    config = await Store.loadConfig();
    unawaited(refreshStatus());
    unawaited(loadIntruders());
  }

  Future<void> refreshStatus() async {
    accessibilityOn = await Native.accessibilityEnabled();
    try {
      final la = LocalAuthentication();
      biometricAvailable = await la.canCheckBiometrics && (await la.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      biometricAvailable = false;
    }
    notifyListeners();
  }

  Future<void> loadApps({bool force = false}) async {
    if (appsLoading || (apps.isNotEmpty && !force)) return;
    appsLoading = true;
    notifyListeners();
    final raw = await Native.getApps();
    apps = raw.map((m) => AppInfo(m['pkg'] as String, m['name'] as String, m['icon'] as Uint8List?)).toList(growable: false);
    appsLoading = false;
    notifyListeners();
  }

  Future<void> loadIntruders() async {
    intruders = await Store.loadIntruders();
    notifyListeners();
  }

  /// Mutate, notify immediately (UI stays instant), persist shortly after.
  void update(void Function(AppConfig c) fn) {
    fn(config);
    notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), save);
  }

  Future<void> save() async {
    _saveDebounce?.cancel();
    await Store.saveConfig(config);
    await Native.saveConfig(config.toNativeJson());
  }

  bool isLocked(String pkg) => config.locked.contains(pkg);

  void toggleApp(String pkg) => update((c) {
    if (!c.locked.remove(pkg)) c.locked.add(pkg);
  });
}
