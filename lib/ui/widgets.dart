import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Press feedback without ripples: instant highlight, soft release.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.color = C.card,
    this.pressedColor = C.pressed,
    this.radius,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color pressedColor;
  final BorderRadius? radius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 0 : 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(color: _down ? widget.pressedColor : widget.color, borderRadius: widget.radius),
          child: widget.child,
        ),
      ),
    );
  }
}

/// iOS-style inset grouped section.
class Section extends StatelessWidget {
  const Section({super.key, this.header, this.footer, required this.children});
  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(height: 0.5, thickness: 0.5, color: C.sep),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(header!, style: T.header),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: C.card,
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(footer!, style: T.caption),
            ),
        ],
      ),
    );
  }
}

/// Small rounded-square glyph, like iOS Settings.
class Glyph extends StatelessWidget {
  const Glyph(this.icon, this.color, {super.key, this.size = 30});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(size * 0.25)),
    child: Icon(icon, size: size * 0.6, color: C.text2),
  );
}

class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron = false,
    this.titleColor,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: T.body.copyWith(color: titleColor)),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: T.sub)],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: T.body.copyWith(color: C.text2),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron) ...[
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_forward, size: 17, color: C.text3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Tile(
    title: title,
    subtitle: subtitle,
    leading: leading,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: SLSwitch(value: value, onChanged: onChanged),
  );
}

class SLSwitch extends StatelessWidget {
  const SLSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => CupertinoSwitch(
    value: value,
    activeTrackColor: C.green,
    onChanged: onChanged == null
        ? null
        : (v) {
            HapticFeedback.selectionClick();
            onChanged!(v);
          },
  );
}

class Check extends StatelessWidget {
  const Check(this.on, {super.key});
  final bool on;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: on ? 1 : 0,
    duration: const Duration(milliseconds: 120),
    child: const Icon(CupertinoIcons.checkmark_alt, color: C.blue, size: 22),
  );
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.bytes, {super.key, this.size = 40});
  final Uint8List? bytes;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(size * 0.24)),
        child: Icon(CupertinoIcons.app, color: C.text3, size: size * 0.55),
      );
    }
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.memory(
      bytes!,
      width: size,
      height: size,
      cacheWidth: px,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Large-title page with iOS collapse behaviour.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.leading,
    this.previousTitle,
  });
  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Widget? leading;
  final String? previousTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            leading: leading,
            previousPageTitle: previousTitle,
            backgroundColor: C.bg.withValues(alpha: 0.94),
            border: null,
            stretch: true,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// Simple pushed page with a compact nav bar.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            previousPageTitle: 'Back',
            trailing: trailing,
            backgroundColor: C.bg.withValues(alpha: 0.94),
            border: null,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList(delegate: SliverChildListDelegate(children)),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 30)),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onTap, this.color = C.silver, this.textColor = Colors.white});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    color: onTap == null ? C.card2 : color,
    pressedColor: onTap == null ? C.card2 : Color.lerp(color, Colors.black, 0.18)!,
    radius: BorderRadius.circular(18),
    child: SizedBox(
      height: 54,
      width: double.infinity,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: onTap == null ? C.text3 : textColor,
          ),
        ),
      ),
    ),
  );
}

Future<R?> push<R>(BuildContext context, Widget page) =>
    Navigator.of(context).push<R>(CupertinoPageRoute(builder: (_) => page));

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'Yes',
  bool destructive = false,
}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    builder: (c) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => _Toast(msg: msg, onDone: () => e.remove()),
  );
  overlay.insert(e);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.msg, required this.onDone});
  final String msg;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
    ..forward();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(context).bottom + 96,
      child: FadeTransition(
        opacity: _c,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xF22C2C30), borderRadius: BorderRadius.circular(22)),
              child: Text(widget.msg, style: T.body.copyWith(fontSize: 15), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
