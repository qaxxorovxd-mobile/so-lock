import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper over the Android side. Every call is safe on iOS (returns a neutral value).
class Native {
  Native._();
  static const _ch = MethodChannel('solock/native');
  static bool get isAndroid => Platform.isAndroid;

  static Future<T?> _call<T>(String m, [Object? a]) async {
    if (!isAndroid) return null;
    try {
      return await _ch.invokeMethod<T>(m, a);
    } catch (_) {
      return null;
    }
  }

  static void setHandler(Future<dynamic> Function(MethodCall c) h) => _ch.setMethodCallHandler(h);

  static Future<List<Map<dynamic, dynamic>>> getApps() async =>
      (await _call<List<dynamic>>('getApps'))?.cast<Map<dynamic, dynamic>>() ?? const [];
  static Future<Map<dynamic, dynamic>?> getAppInfo(String pkg) => _call('getAppInfo', pkg);
  static Future<void> saveConfig(String json) => _call('saveConfig', json);
  static Future<bool> accessibilityEnabled() async => await _call<bool>('accessibilityEnabled') ?? false;
  static Future<void> openAccessibility() => _call('openAccessibility');
  static Future<void> openAppSettings() => _call('openAppSettings');
  static Future<bool> hasPermission(String name) async => await _call<bool>('hasPermission', name) ?? false;
  static Future<bool> requestPermission(String name) async => await _call<bool>('requestPermission', name) ?? false;
  static Future<String?> currentWifi() => _call<String>('currentWifi');
  static Future<Map<dynamic, dynamic>?> currentLocation() => _call('currentLocation');
  static Future<bool> lockDevice() async => await _call<bool>('lockDevice') ?? false;
  static Future<void> goHome() => _call('goHome');
  static Future<void> moveToBack() => _call('moveToBack');
  static Future<void> unlockSuccess(String? pkg) => _call('unlockSuccess', pkg);
  static Future<String?> getLockTarget() => _call<String>('getLockTarget');
}
