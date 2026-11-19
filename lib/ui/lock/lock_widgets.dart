import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../theme.dart';

const _letters = ['', '', 'ABC', 'DEF', 'GHI', 'JKL', 'MNO', 'PQRS', 'TUV', 'WXYZ'];

/// Numeric keypad. Pressed keys light up instantly and fade out — like iOS.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.order,
    required this.style,
    required this.accent,
    required this.onDigit,
    required this.onDelete,
    this.leftAction,
    this.canDelete = true,
    this.enabled = true,
    this.feedback,
    this.animate = true,
  });

  /// 10 digits; positions 0..8 fill the 3x3 grid, position 9 sits under the middle column.
  final List<int> order;
  final KeypadStyle style;
  final Color accent;
  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final Widget? leftAction;
  final bool canDelete;
  final bool enabled;

  /// Called on every key press (vibration).
  final VoidCallback? feedback;

  /// Press "squish" animation.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final size = min(80.0, min(w / 4.7, h / 10.5));
    final gapX = size * 0.36;
    final gapY = size * 0.2;

    Widget key(int d) => _Key(
      digit: d,
      size: size,
      style: style,
      accent: accent,
      feedback: feedback,
      animate: animate,
      onTap: enabled ? () => onDigit(d) : null,
    );

    Widget row(List<Widget> c) => Padding(
      padding: EdgeInsets.only(bottom: gapY),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          c[0],
          SizedBox(width: gapX),
          c[1],
          SizedBox(width: gapX),
          c[2],
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([key(order[0]), key(order[1]), key(order[2])]),
          row([key(order[3]), key(order[4]), key(order[5])]),
          row([key(order[6]), key(order[7]), key(order[8])]),
          row([
            SizedBox(
              width: size,
              height: size,
              child: Center(child: leftAction),
            ),
            key(order[9]),
            SizedBox(
              width: size,
              height: size,
              child: AnimatedScale(
                scale: canDelete ? 1 : 0.6,
                duration: Duration(milliseconds: animate ? 180 : 0),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: canDelete ? 1 : 0,
                  duration: Duration(milliseconds: animate ? 140 : 0),
                  child: _IconKey(
                    icon: CupertinoIcons.delete_left,
                    onTap: canDelete && enabled ? onDelete : null,
                    feedback: feedback,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.digit,
    required this.size,
    required this.style,
    required this.accent,
    required this.onTap,
    required this.feedback,
    required this.animate,
  });
  final int digit;
  final double size;
  final KeypadStyle style;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback? feedback;
  final bool animate;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  void _up() {
    if (_down) setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final a = widget.accent;
    final Color fill;
    final Border? border;
    switch (widget.style) {
      case KeypadStyle.filled:
        fill = _down ? a.withValues(alpha: 0.42) : Colors.white.withValues(alpha: 0.11);
        border = null;
      case KeypadStyle.ring:
        fill = _down ? a.withValues(alpha: 0.32) : Colors.transparent;
        border = Border.all(color: a.withValues(alpha: _down ? 0.9 : 0.38), width: 1.3);
      case KeypadStyle.minimal:
        fill = _down ? Colors.white.withValues(alpha: 0.14) : Colors.transparent;
        border = null;
    }
    return Listener(
      onPointerDown: (_) {
        if (widget.onTap == null) return;
        widget.feedback?.call();
        setState(() => _down = true);
        widget.onTap!();
      },
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: AnimatedScale(
        // Instant squish on touch, springy release.
        scale: widget.animate && _down ? 0.92 : 1,
        duration: Duration(milliseconds: _down ? 60 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 0 : 260),
          curve: Curves.easeOut,
          width: s,
          height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: border),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.digit}',
                style: TextStyle(
                  fontSize: s * 0.42,
                  height: 1.05,
                  fontWeight: widget.style == KeypadStyle.minimal ? FontWeight.w300 : FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.style != KeypadStyle.minimal && _letters[widget.digit].isNotEmpty)
                Text(
                  _letters[widget.digit],
                  style: TextStyle(
                    fontSize: s * 0.125,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconKey extends StatefulWidget {
  const _IconKey({required this.icon, required this.onTap, this.feedback});
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? feedback;
  @override
  State<_IconKey> createState() => _IconKeyState();
}

class _IconKeyState extends State<_IconKey> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapUp: (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    onTap: widget.onTap == null
        ? null
        : () {
            widget.feedback?.call();
            widget.onTap!();
          },
    child: Center(
      child: AnimatedScale(
        scale: _down ? 0.88 : 1,
        duration: Duration(milliseconds: _down ? 60 : 220),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _down ? 0.45 : 1,
          duration: Duration(milliseconds: _down ? 0 : 200),
          child: Icon(widget.icon, color: Colors.white, size: 27),
        ),
      ),
    ),
  );
}

/// Round button for the biometric action in the keypad.
class BioButton extends StatelessWidget {
  const BioButton({super.key, required this.onTap, this.face = false, this.feedback});
  final VoidCallback onTap;
  final bool face;
  final VoidCallback? feedback;
  @override
  Widget build(BuildContext context) =>
      _IconKey(icon: face ? CupertinoIcons.viewfinder : Icons.fingerprint_rounded, onTap: onTap, feedback: feedback);
}

/// Code progress dots. Each dot "pops" when filled; all dots tint on error/success.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled, required this.color, this.animate = true, this.tint});
  final int length;
  final int filled;
  final Color color;
  final bool animate;

  /// Temporary colour override (red on wrong code, green on success).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (i) {
        final on = i < filled || tint != null;
        final dot = AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? c : Colors.transparent,
            border: Border.all(color: c, width: 1.4),
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: !animate
              ? dot
              : TweenAnimationBuilder<double>(
                  key: ValueKey(on),
                  tween: Tween(begin: on ? 1.45 : 0.8, end: 1),
                  duration: Duration(milliseconds: on ? 260 : 160),
                  curve: on ? Curves.easeOutBack : Curves.easeOut,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: dot,
                ),
        );
      }),
    );
  }
}

/// Damped horizontal shake for wrong codes.
class Shake extends AnimatedWidget {
  const Shake({super.key, required Animation<double> animation, required this.child}) : super(listenable: animation);
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final dx = sin(t * pi * 6) * 14 * (1 - t);
    return Transform.translate(offset: Offset(dx, 0), child: child);
  }
}

/// Configurable background. Cached in its own layer so keypad taps never repaint it.
class LockBackground extends StatelessWidget {
  const LockBackground({super.key, required this.style});
  final LockStyle style;

  @override
  Widget build(BuildContext context) {
    Widget bg;
    final img = style.imagePath;
    if (style.background == -1 && img != null && File(img).existsSync()) {
      bg = Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur, tileMode: TileMode.clamp),
            child: Image.file(File(img), fit: BoxFit.cover, gaplessPlayback: true),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: style.dim)),
        ],
      );
    } else {
      final p = LockBg.presets[style.background.clamp(0, LockBg.presets.length - 1)];
      bg = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: p.colors,
            stops: const [0, 0.55, 1],
          ),
        ),
      );
    }
    return RepaintBoundary(child: SizedBox.expand(child: bg));
  }
}

List<int> keypadOrder(bool shuffle) {
  if (!shuffle) return const [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
  return List<int>.generate(10, (i) => i)..shuffle(Random.secure());
}
