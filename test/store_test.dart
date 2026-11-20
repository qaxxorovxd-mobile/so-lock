import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:so_lock/core/store.dart';
class Paths extends PathProviderPlatform {
  Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('overlapping guard writes preserve order and readers see the final value', () async {
    final dir = await Directory.systemTemp.createTemp('solock-store-');
    PathProviderPlatform.instance = Paths(dir.path);
    try {
      final writes = List.generate(20, (i) => Store.saveGuard(i, i * 100));
      final value = await Store.loadGuard();
      await Future.wait(writes);
      expect(value, (19, 1900));
      expect(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.tmp')), isEmpty);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
