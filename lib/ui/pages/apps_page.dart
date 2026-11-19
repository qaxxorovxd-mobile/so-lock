import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/native.dart';
import '../lock/gate.dart';
import '../theme.dart';
import '../widgets.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});
  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  String _q = '';
  int _filter = 0; // 0 all, 1 locked

  @override
  void initState() {
    super.initState();
    AppState.I.loadApps();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final q = _q.trim().toLowerCase();
        final list = s.apps
            .where((a) {
              if (_filter == 1 && !s.isLocked(a.pkg)) return false;
              return q.isEmpty || a.lower.contains(q) || a.pkg.contains(q);
            })
            .toList(growable: false);

        return LargeTitlePage(
          title: 'Apps',
          slivers: [
            SliverToBoxAdapter(child: _StatusCard(state: s)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: CupertinoSearchTextField(
                  placeholder: 'Search',
                  backgroundColor: C.card,
                  style: T.body,
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _filter,
                  backgroundColor: C.card,
                  thumbColor: C.pressed,
                  children: {
                    0: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('All', style: TextStyle(fontSize: 14)),
                    ),
                    1: Text('Locked · ${s.config.locked.length}', style: const TextStyle(fontSize: 14)),
                  },
                  onValueChanged: (v) => setState(() => _filter = v ?? 0),
                ),
              ),
            ),
            if (s.appsLoading && s.apps.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.only(top: 60), child: CupertinoActivityIndicator(radius: 12)),
              )
            else if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(child: Text(_filter == 1 ? 'No apps locked yet' : 'Nothing found', style: T.sub)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) =>
                      _AppRow(app: list[i], locked: s.isLocked(list[i].pkg), first: i == 0, last: i == list.length - 1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.locked, required this.first, required this.last});
  final AppInfo app;
  final bool locked;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.vertical(
      top: first ? const Radius.circular(14) : Radius.zero,
      bottom: last ? const Radius.circular(14) : Radius.zero,
    );
    return ClipRRect(
      borderRadius: r,
      child: Pressable(
        onTap: () => AppState.I.toggleApp(app.pkg),
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  AppIcon(app.icon, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body),
                  ),
                  _LockToggle(on: locked),
                  const SizedBox(width: 14),
                ],
              ),
            ),
            if (!last)
              const Padding(
                padding: EdgeInsets.only(left: 68),
                child: Divider(height: 0.5, thickness: 0.5, color: C.sep),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lock glyph that morphs between open and closed.
class _LockToggle extends StatelessWidget {
  const _LockToggle({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 36,
      height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.silver : C.card2),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        transitionBuilder: (c, a) => ScaleTransition(
          scale: Tween(begin: 0.7, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: c),
        ),
        child: Icon(
          on ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open,
          key: ValueKey(on),
          size: 17,
          color: on ? Colors.black : C.text2,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (Native.isAndroid && !s.accessibilityOn) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Pressable(
          onTap: () {
            LockGate.suppress();
            Native.openAccessibility();
          },
          radius: BorderRadius.circular(16),
          color: const Color(0xFF2A1A12),
          pressedColor: const Color(0xFF3A2418),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle_fill, color: C.orange, size: 26),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Protection is not running', style: T.title),
                      SizedBox(height: 2),
                      Text('Enable So Lock in Accessibility settings', style: T.sub),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_forward, color: C.text3, size: 18),
              ],
            ),
          ),
        ),
      );
    }
    final on = s.config.enabled;
    final n = s.config.locked.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.green.withValues(alpha: 0.16) : C.card2),
              child: Icon(
                on ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.shield_slash,
                color: on ? C.green : C.text3,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(on ? 'Protection on' : 'Protection paused', style: T.title),
                  const SizedBox(height: 2),
                  Text(n == 0 ? 'Choose apps to lock' : '$n apps locked', style: T.sub),
                ],
              ),
            ),
            SLSwitch(value: on, onChanged: (v) => s.update((c) => c.enabled = v)),
          ],
        ),
      ),
    );
  }
}
