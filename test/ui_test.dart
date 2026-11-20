import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_lock/core/app_state.dart';
import 'package:so_lock/core/models.dart';
import 'package:so_lock/ui/home.dart';
import 'package:so_lock/ui/onboarding.dart';
import 'package:so_lock/ui/code_entry.dart';
import 'package:so_lock/ui/lock/lock_view.dart';
import 'package:so_lock/ui/pages/apps_page.dart';
import 'package:so_lock/ui/pages/smart_page.dart';
import 'package:so_lock/ui/pages/security_page.dart';
import 'package:so_lock/ui/pages/settings_page.dart';
import 'package:so_lock/ui/pages/customize_page.dart';
import 'package:so_lock/ui/pages/intruder_page.dart';
import 'package:so_lock/ui/pages/duress_page.dart';
import 'package:so_lock/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontPath = String.fromEnvironment('PREVIEW_FONT');
    if (fontPath.isNotEmpty) {
      final bytes = ByteData.sublistView(await File(fontPath).readAsBytes());
      for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay', 'Ahem', 'Roboto', '.SF Pro Text', '.SF Pro Display', '.SF UI Text', '.SF UI Display']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
      await (FontLoader(
        'CupertinoIcons',
      )..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
      await (FontLoader(
        'packages/cupertino_icons/CupertinoIcons',
      )..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  final pages = <String, Widget>{
    'intruders': const IntruderPage(), 'decoy': const DuressEditPage(),
    'apps': const AppsPage(),
    'smart': const SmartPage(),
    'security': const SecurityPage(),
    'settings': const SettingsPage(),
    'customize': const CustomizePage(),
    'onboarding': Onboarding(onDone: () {}),
    'home': const Home(),
    'code': const CodeEntryPage(type: LockType.pin4, title: 'Create a code'),
    'lock': LockView(
      config: AppConfig(),
      target: const LockTarget(name: 'So Lock'),
      preview: true,
      onUnlock: () {},
    ),
  };
  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    for (final page in pages.entries) {
      testWidgets('${page.key} fits $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppState.I.config = AppConfig();
        AppState.I.config.smart.scheduleOn = true;
        AppState.I.apps = [
          AppInfo('messages', 'Messages', null),
          AppInfo('photos', 'Photos', null),
          AppInfo('bank', 'Banking', null),
        ];
        AppState.I.accessibilityOn = true;
        AppState.I.config.locked = ['messages', 'photos'];
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: RepaintBoundary(key: key, child: page.value),
          ),
        );
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          await tester.runAsync(() => precacheImage(const AssetImage('assets/logo.webp'), tester.element(find.byType(MaterialApp))));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 390 && const bool.fromEnvironment('CAPTURE_UI')) {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('build/ui-preview');
            await dir.create(recursive: true);
            await File('build/ui-preview/${page.key}.png').writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
