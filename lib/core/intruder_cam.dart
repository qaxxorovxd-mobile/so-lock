import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'native.dart';
import 'store.dart';

/// Silent capture from front (and optionally back) camera.
/// Exposes the live controller so the lock screen can mount a 1px preview
/// (some devices refuse to capture without an attached surface).
class IntruderCam {
  IntruderCam._();
  static final ValueNotifier<CameraController?> active = ValueNotifier(null);
  static bool _busy = false;

  static Future<List<String>> capture({bool back = false}) async {
    if (_busy || !Native.isAndroid) return const [];
    if (!await Native.hasPermission('camera')) return const [];
    _busy = true;
    final out = <String>[];
    try {
      final cams = await availableCameras();
      final lenses = [CameraLensDirection.front, if (back) CameraLensDirection.back];
      for (final lens in lenses) {
        final cam = cams.where((c) => c.lensDirection == lens).firstOrNull;
        if (cam == null) continue;
        final path = await _shoot(cam);
        if (path != null) out.add(path);
      }
    } catch (_) {
      // Camera busy / blocked by the system — never break the lock screen.
    } finally {
      _busy = false;
    }
    return out;
  }

  static Future<String?> _shoot(CameraDescription cam) async {
    final ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await ctrl.initialize().timeout(const Duration(seconds: 4));
      active.value = ctrl;
      try {
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}
      // Let auto-exposure settle so the face is visible.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final x = await ctrl.takePicture().timeout(const Duration(seconds: 4));
      final dir = await Store.intruderDir();
      final name = '${DateTime.now().millisecondsSinceEpoch}_${cam.lensDirection.name}.jpg';
      final dest = '${dir.path}/$name';
      await File(x.path).copy(dest);
      try {
        await File(x.path).delete();
      } catch (_) {}
      return dest;
    } catch (_) {
      return null;
    } finally {
      active.value = null;
      await ctrl.dispose();
    }
  }
}
