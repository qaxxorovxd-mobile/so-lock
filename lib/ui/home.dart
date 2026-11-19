import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/apps_page.dart';
import 'pages/security_page.dart';
import 'pages/settings_page.dart';
import 'pages/smart_page.dart';
import 'theme.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  // Quick cross-fade on tab switch (state of every tab is preserved).
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 180), value: 1);

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  int _tab = 0;
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _built = <int>{0};

  static const _items = [
    (CupertinoIcons.lock, CupertinoIcons.lock_fill, 'Apps'),
    (CupertinoIcons.wand_stars, CupertinoIcons.wand_stars, 'Smart'),
    (CupertinoIcons.shield, CupertinoIcons.shield_fill, 'Security'),
    (CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill, 'Settings'),
  ];

  Widget _page(int i) => switch (i) {
    0 => const AppsPage(),
    1 => const SmartPage(),
    2 => const SecurityPage(),
    _ => const SettingsPage(),
  };

  void _select(int i) {
    if (i == _tab) {
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    HapticFeedback.selectionClick();
    _fade.forward(from: 0.35);
    setState(() {
      _tab = i;
      _built.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        final nav = _navKeys[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: Stack(
            children: [
              // Tabs are built lazily and kept alive — switching is instant.
              for (var i = 0; i < 4; i++)
                Offstage(
                  offstage: _tab != i,
                  child: TickerMode(
                    enabled: _tab == i,
                    child: _built.contains(i)
                        ? Navigator(
                            key: _navKeys[i],
                            onGenerateRoute: (_) => CupertinoPageRoute(builder: (_) => _page(i)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xF50E0E11),
            border: Border(top: BorderSide(color: C.sep, width: 0.5)),
          ),
          padding: EdgeInsets.only(bottom: bottom),
          height: 54 + bottom,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _select(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_tab == i ? _items[i].$2 : _items[i].$1, size: 25, color: _tab == i ? C.text : C.text3),
                        const SizedBox(height: 3),
                        Text(
                          _items[i].$3,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: _tab == i ? C.text : C.text3,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
