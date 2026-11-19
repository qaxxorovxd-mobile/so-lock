import 'package:flutter/services.dart';

import 'models.dart';
import 'native.dart';

/// Configurable vibration. Android uses the native vibrator (works even when the
/// system "touch feedback" toggle is off); iOS falls back to system haptics.
class Vibe {
  Vibe._();
  static const _ch = MethodChannel('solock/native');

  static void _fire(String kind, int level) {
    if (level <= 0) return;
    if (Native.isAndroid) {
      // Fire-and-forget: never delay a key press.
      _ch.invokeMethod('vibrate', {'kind': kind, 'level': level}).catchError((_) => null);
      return;
    }
    switch (kind) {
      case 'error':
        HapticFeedback.heavyImpact();
      case 'success':
        HapticFeedback.mediumImpact();
      default:
        level >= 3 ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    }
  }

  static void key(LockStyle s) {
    if (s.vibeKeys) _fire('key', s.vibeLevel);
  }

  static void error(LockStyle s) {
    if (s.vibeError) _fire('error', s.vibeLevel);
  }

  static void success(LockStyle s) {
    if (s.vibeSuccess) _fire('success', s.vibeLevel);
  }

  /// Preview a level from settings.
  static void preview(int level) => _fire('key', level);
}
