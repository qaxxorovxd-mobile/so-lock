import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// File-based storage, shared by the main app and the lock engine (same app sandbox).
class Store {
  Store._();
  static Directory? _dir;

  static Future<Directory> dir() async {
    return _dir ??= await getApplicationSupportDirectory();
  }

  static Future<File> _file(String name) async => File('${(await dir()).path}/$name');

  static Future<Map<String, dynamic>?> _readJson(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Atomic write: never leaves a half-written config behind.
  static Future<void> _writeJson(String name, Object data) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  static Future<AppConfig> loadConfig() async {
    final j = await _readJson('config.json');
    return j == null ? AppConfig() : AppConfig.fromJson(j);
  }

  static Future<void> saveConfig(AppConfig c) => _writeJson('config.json', c.toJson());

  // ---- brute-force guard (shared between engines) ----
  static Future<(int fails, int until)> loadGuard() async {
    final j = await _readJson('guard.json');
    return ((j?['fails'] as int?) ?? 0, (j?['until'] as int?) ?? 0);
  }

  static Future<void> saveGuard(int fails, int until) => _writeJson('guard.json', {'fails': fails, 'until': until});

  // ---- intruder log ----
  static Future<Directory> intruderDir() async {
    final d = Directory('${(await dir()).path}/intruders');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<List<IntruderEvent>> loadIntruders() async {
    final j = await _readJson('intruders.json');
    final list = (j?['events'] as List?) ?? const [];
    return list.map((e) => IntruderEvent.fromJson(e as Map<String, dynamic>)).toList()..sort((a, b) => b.time.compareTo(a.time));
  }

  static Future<void> addIntruder(IntruderEvent e) async {
    final all = await loadIntruders();
    all.insert(0, e);
    if (all.length > 200) {
      for (final old in all.sublist(200)) {
        await _deletePhotos(old);
      }
      all.removeRange(200, all.length);
    }
    await _writeJson('intruders.json', {'events': all.map((e) => e.toJson()).toList()});
  }

  static Future<void> deleteIntruders(Iterable<String> ids) async {
    final all = await loadIntruders();
    final set = ids.toSet();
    for (final e in all.where((e) => set.contains(e.id))) {
      await _deletePhotos(e);
    }
    all.removeWhere((e) => set.contains(e.id));
    await _writeJson('intruders.json', {'events': all.map((e) => e.toJson()).toList()});
  }

  static Future<void> _deletePhotos(IntruderEvent e) async {
    for (final p in e.photos) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
  }
}
