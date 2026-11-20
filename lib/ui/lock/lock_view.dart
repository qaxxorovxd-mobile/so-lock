import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/intruder_cam.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../../core/security.dart';
import '../../core/store.dart';
import '../../core/vibe.dart';
import 'lock_widgets.dart';
import '../theme.dart';

class LockTarget {
  const LockTarget({this.pkg, required this.name, this.icon});
  final String? pkg; // null = So Lock itself
  final String name;
  final Uint8List? icon;
  bool get isSelf => pkg == null;
}

/// The lock screen. Used by the overlay engine (other apps) and by So Lock itself.
class LockView extends StatefulWidget {
  const LockView({
    super.key,
    required this.config,
    required this.target,
    required this.onUnlock,
    this.bioTrigger,
    this.preview = false,
    this.guardStore = const GuardStore(),
    this.active = true,
  });

  final GuardStore guardStore;
  /// The cached overlay engine can build before an Android Activity is attached.
  final bool active;
  final AppConfig config;
  final LockTarget target;
  final VoidCallback onUnlock;

  /// Bumped whenever the host becomes visible — a good moment to offer biometrics.
  final Listenable? bioTrigger;

  /// Static preview (customisation screen): no auth, no side effects.
  final bool preview;

  @override
  State<LockView> createState() => _LockViewState();
}

class _LockViewState extends State<LockView> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  late final Future<void> _guardReady;
  bool _completed = false;
  bool _retryOnResume = false;
  bool _foreground = true;
  int _authEpoch = 0;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 170));

  /// Entrance: header drops in, dots + keypad rise. Short and subtle.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: widget.config.style.animations && !widget.preview ? 0 : 1,
  );
  Color? _tint;
  late final List<int> _order = keypadOrder(widget.config.style.shuffle && !widget.preview);
  final _pwd = TextEditingController();
  final _pwdFocus = FocusNode();

  String _input = '';
  String? _msg;
  bool _busy = false;
  bool _bioAvailable = false;
  bool _bioFace = false;
  bool _bioRunning = false;
  bool _fakeCrash = false;
  int _sessionFails = 0;
  int _guardFails = 0;
  DateTime? _lockedUntil;
  Timer? _tick;

  AppConfig get cfg => widget.config;
  LockStyle get st => cfg.style;
  Color get accent => Color(st.accent);

  @override
  void initState() {
    super.initState();
    if (widget.preview) return;
    _in.forward();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _guardReady = _loadGuard();
    widget.bioTrigger?.addListener(_onBioTrigger);
    _bioReady = _initBio();
  }

  Future<void>? _bioReady;

  @override
  void didUpdateWidget(covariant LockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.preview && widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runBio());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authEpoch++;
    if (_bioRunning) unawaited(_stopBio());
    widget.bioTrigger?.removeListener(_onBioTrigger);
    _shake.dispose();
    _out.dispose();
    _in.dispose();
    _tick?.cancel();
    _pwd.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  // ---------------- biometrics (with PIN fallback) ----------------

  Future<void> _stopBio() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.preview) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _foreground = false;
      _authEpoch++;
      if (_bioRunning) unawaited(_stopBio());
    } else if (state == AppLifecycleState.resumed) {
      final wasAway = !_foreground;
      _foreground = true;
      if (wasAway) {
        if (_completed) {
          _completed = false;
          _busy = false;
          _out.reset();
        }
        if (_bioRunning) {
          _retryOnResume = true;
        } else {
          _onBioTrigger();
        }
      }
    }
  }

  Future<void> _initBio() async {
    if (!cfg.biometrics) return;
    try {
      final types = await _auth.getAvailableBiometrics();
      if (!mounted) return;
      setState(() {
        _bioAvailable = types.isNotEmpty;
        _bioFace = types.contains(BiometricType.face) && !types.contains(BiometricType.fingerprint);
      });
      if (_bioAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _runBio());
      }
    } catch (_) {}
  }

  void _onBioTrigger() => _runBio();

  Future<void> _runBio() async {
    await _bioReady;
    await _guardReady;
    if (!mounted ||
        !widget.active ||
        !_foreground ||
        _completed ||
        !_bioAvailable ||
        _bioRunning ||
        _busy ||
        _isLockedOut ||
        _fakeCrash) {
      return;
    }
    _bioRunning = true;
    final epoch = _authEpoch;
    try {
      final ok = await _auth.authenticate(
        localizedReason: widget.target.isSelf ? 'Unlock So Lock' : 'Unlock ${widget.target.name}',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
      if (ok && mounted && _foreground && epoch == _authEpoch && !_busy && !_completed && !_isLockedOut) {
        await _success();
      }
    } catch (_) {
      // Sensor failed / locked out / unavailable → the PIN pad is the fallback.
      if (mounted && _foreground && epoch == _authEpoch && !_completed) {
        setState(() => _msg = 'Use your code, or tap to retry biometrics');
      }
    } finally {
      _bioRunning = false;
      if (_retryOnResume && mounted && _foreground) {
        _retryOnResume = false;
        unawaited(_runBio());
      }
    }
  }

  // ---------------- brute-force guard ----------------

  bool get _isLockedOut => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  Future<void> _loadGuard() async {
    final (fails, until) = await widget.guardStore.load();
    if (!mounted) return;
    _guardFails = fails;
    if (until > DateTime.now().millisecondsSinceEpoch) {
      _startLockout(DateTime.fromMillisecondsSinceEpoch(until));
    }
  }

  void _startLockout(DateTime until) {
    _lockedUntil = until;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (!_isLockedOut) {
        t.cancel();
        setState(() {
          _lockedUntil = null;
          _msg = null;
        });
      } else {
        setState(() {});
      }
    });
    if (mounted) setState(() {});
  }

  // ---------------- input ----------------

  void _digit(int d) {
    if (!mounted || _busy || _completed || _isLockedOut || widget.preview) return;
    if (_input.length >= cfg.type.length) return;
    setState(() {
      _input += '$d';
      _msg = null;
    });
    if (_input.length == cfg.type.length) {
      // Let the last dot render before verifying.
      final code = _input;
      Future.delayed(const Duration(milliseconds: 70), () {
        if (mounted && _input == code) _submit(code);
      });
    }
  }

  void _delete() {
    if (_input.isEmpty || _busy) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _submit(String code) async {
    if (widget.preview) return;
    await _guardReady;
    if (!mounted || !widget.active || !_foreground || _busy || _completed || _isLockedOut || code.isEmpty) return;
    _busy = true;
    _authEpoch++;
    if (_bioRunning) await _stopBio();
    if (!mounted) return;
    final r = Security.check(cfg, code);
    switch (r) {
      case CheckOk():
        await _success();
      case CheckDuress(:final code):
        await _duress(code);
      case CheckWrong():
        await _wrong();
    }
  }

  Future<void> _success() async {
    if (!mounted || _completed) return;
    _completed = true;
    final epoch = _authEpoch;
    _busy = true;
    _guardFails = 0;
    unawaited(widget.guardStore.save(0, 0));
    Vibe.success(st);
    if (st.animations && mounted) {
      setState(() => _tint = const Color(0xFF30D158));
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted || !_foreground || epoch != _authEpoch) return;
      await _out.forward();
    }
    if (mounted && _foreground && epoch == _authEpoch) widget.onUnlock();
  }

  Future<void> _wrong() async {
    _sessionFails++;
    _guardFails++;
    final lock = Security.lockoutFor(_guardFails);
    final until = lock == Duration.zero ? 0 : DateTime.now().add(lock).millisecondsSinceEpoch;
    unawaited(widget.guardStore.save(_guardFails, until));
    Vibe.error(st);
    if (st.animations) {
      setState(() => _tint = const Color(0xFFFF453A));
      _shake.forward(from: 0);
    }
    if (cfg.intruderOn && _sessionFails >= cfg.intruderAfter && (_sessionFails - cfg.intruderAfter) % 3 == 0) {
      unawaited(_record('wrong', photo: true));
    }
    await Future<void>.delayed(Duration(milliseconds: st.animations ? 380 : 120));
    if (!mounted) return;
    setState(() {
      _input = '';
      _pwd.clear();
      _msg = _sessionFails >= 3 ? 'Wrong code · $_sessionFails attempts' : 'Wrong code';
      _busy = false;
      _tint = null;
    });
    if (until != 0) _startLockout(DateTime.fromMillisecondsSinceEpoch(until));
  }

  Future<void> _duress(DuressCode d) async {
    // Looks like a normal, successful entry from the outside.
    _guardFails = 0;
    unawaited(widget.guardStore.save(0, 0));
    var action = d.action;
    if (widget.target.isSelf && action == DuressAction.silentOpen) action = DuressAction.fakeCrash;

    switch (action) {
      case DuressAction.fakeCrash:
        setState(() => _fakeCrash = true);
        unawaited(_record('duress', photo: d.photo));
      case DuressAction.silentOpen:
        // Take the photo first (camera needs the screen), then open the app.
        await _record('duress', photo: d.photo, timeout: const Duration(milliseconds: 2200));
        if (mounted && _foreground) widget.onUnlock();
        return;
      case DuressAction.lockScreen:
        await _record('duress', photo: d.photo, timeout: const Duration(milliseconds: 1800));
        final ok = await Native.lockDevice();
        if (!ok) await (widget.target.isSelf ? Native.moveToBack() : Native.goHome());
      case DuressAction.goHome:
        await _record('duress', photo: d.photo, timeout: const Duration(milliseconds: 1800));
        await (widget.target.isSelf ? Native.moveToBack() : Native.goHome());
    }
    if (!mounted) return;
    setState(() {
      _input = '';
      _pwd.clear();
      _busy = false;
    });
  }

  Future<void> _record(String reason, {required bool photo, Duration? timeout}) async {
    Future<void> job() async {
      final photos = photo ? await IntruderCam.capture(back: cfg.intruderBack) : const <String>[];
      await Store.addIntruder(
        IntruderEvent(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          time: DateTime.now(),
          pkg: widget.target.pkg ?? 'uz.solock.so_lock',
          appName: widget.target.name,
          reason: reason,
          attempts: _sessionFails,
          photos: photos,
        ),
      );
    }

    final f = job();
    if (timeout != null) {
      await f.timeout(timeout, onTimeout: () {});
    } else {
      await f;
    }
  }

  void _closeFakeCrash() {
    setState(() => _fakeCrash = false);
    widget.target.isSelf ? Native.moveToBack() : Native.goHome();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final content = Column(
      children: [
        SizedBox(height: pad.top + 32),
        _enter(_header(), from: -14, start: 0),
        const Spacer(flex: 2),
        if (cfg.type.isPin) ...[
          _enter(
            Shake(
              animation: _shake,
              child: PinDots(
                length: cfg.type.length,
                filled: widget.preview ? 2 : _input.length,
                color: accent,
                tint: _tint,
                animate: st.animations,
              ),
            ),
            from: 18,
            start: 0.12,
          ),
          const SizedBox(height: 18),
          _message(),
          const Spacer(flex: 2),
          _enter(
            Keypad(
              order: _order,
              style: st.keypad,
              accent: accent,
              feedback: widget.preview ? null : () => Vibe.key(st),
              animate: st.animations,
              enabled: !_isLockedOut && !_busy && !_completed,
              onDigit: _digit,
              onDelete: _delete,
              canDelete: _input.isNotEmpty,
              leftAction: _bioAvailable
                  ? BioButton(onTap: _runBio, face: _bioFace, feedback: () => Vibe.key(st))
                  : null,
            ),
            from: 34,
            start: 0.22,
          ),
        ] else ...[
          _enter(Shake(animation: _shake, child: _passwordField()), from: 18, start: 0.12),
          const SizedBox(height: 14),
          _message(),
          const Spacer(flex: 3),
          if (_bioAvailable) BioButton(onTap: _runBio, face: _bioFace),
          const Spacer(flex: 2),
        ],
        SizedBox(height: pad.bottom + 26),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lockOverlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || widget.preview) return;
          widget.target.isSelf ? Native.moveToBack() : Native.goHome();
        },
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LockBackground(style: st),
              FadeTransition(
                opacity: ReverseAnimation(_out),
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _out, curve: Curves.easeIn)),
                  child: content,
                ),
              ),
              // A hidden 1px camera surface while capturing (required on some devices).
              if (!widget.preview)
                ValueListenableBuilder<CameraController?>(
                  valueListenable: IntruderCam.active,
                  builder: (_, c, _) => c == null || !c.value.isInitialized
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: 0,
                          top: 0,
                          width: 1,
                          height: 1,
                          child: Opacity(opacity: 0.01, child: CameraPreview(c)),
                        ),
                ),
              if (_fakeCrash) _FakeCrash(appName: widget.target.name, onClose: _closeFakeCrash),
            ],
          ),
        ),
      ),
    );
  }

  /// Staggered fade + slide used by the entrance animation.
  Widget _enter(Widget child, {required double from, required double start}) {
    final a = CurvedAnimation(
      parent: _in,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (_, c) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, from * (1 - a.value)), child: c),
      ),
    );
  }

  Widget _header() {
    final t = widget.target;
    return Column(
      children: [
        if (st.showIcon)
          SizedBox(
            width: 58,
            height: 58,
            child: t.isSelf || t.icon == null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/logo.webp', fit: BoxFit.cover),
                  )
                : Image.memory(t.icon!, gaplessPlayback: true),
          )
        else
          Icon(CupertinoIcons.lock_fill, color: accent, size: 26),
        const SizedBox(height: 16),
        Text(
          cfg.type.isPin ? 'Enter code' : 'Enter password',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.4),
        ),
        const SizedBox(height: 4),
        Text(t.name, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6), letterSpacing: -0.1)),
      ],
    );
  }

  Widget _message() {
    String? text = _msg;
    if (_isLockedOut) {
      final s = _lockedUntil!.difference(DateTime.now()).inSeconds + 1;
      text = 'Too many attempts. Try again in ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }
    return SizedBox(
      height: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Text(
          text ?? '',
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.75), letterSpacing: -0.1),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        height: 52,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.only(left: 16, right: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pwd,
                focusNode: _pwdFocus,
                autofocus: !widget.preview,
                enabled: !_isLockedOut && !_busy && !_completed && !widget.preview,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                cursorColor: accent,
                style: const TextStyle(color: Colors.white, fontSize: 17, letterSpacing: 2),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0),
                ),
                onSubmitted: (v) => _submit(v),
              ),
            ),
            GestureDetector(
              onTap: () => _submit(_pwd.text),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.arrow_right, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imitates a system "app has stopped" dialog.
class _FakeCrash extends StatelessWidget {
  const _FakeCrash({required this.appName, required this.onClose});
  final String appName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 24, 12, 8),
          decoration: BoxDecoration(color: const Color(0xFF2B2B2F), borderRadius: BorderRadius.circular(26)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$appName keeps stopping',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 18),
              _row(Icons.close_rounded, 'Close app', onClose),
              _row(Icons.info_outline_rounded, 'About', onClose),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData i, String t, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(i, color: Colors.white70, size: 22),
          const SizedBox(width: 18),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    ),
  );
}
