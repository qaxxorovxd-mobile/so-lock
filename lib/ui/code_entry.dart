import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/vibe.dart';
import 'lock/lock_widgets.dart';
import 'theme.dart';

/// Full-screen code input used for creating / changing codes.
/// Returns the code, or null if cancelled.
class CodeEntryPage extends StatefulWidget {
  const CodeEntryPage({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.confirm = true,
    this.validate,
    this.allowTypeSwitch = false,
  });

  final LockType type;
  final String title;
  final String? subtitle;
  final bool confirm;

  /// Return an error message to reject the code.
  final String? Function(String code)? validate;

  /// Shows a "Kod turi" switcher (setup / change code). Result type is read via [CodeEntryResult].
  final bool allowTypeSwitch;

  static Future<CodeEntryResult?> open(
    BuildContext context, {
    required LockType type,
    required String title,
    String? subtitle,
    bool confirm = true,
    String? Function(String)? validate,
    bool allowTypeSwitch = false,
  }) {
    return Navigator.of(context, rootNavigator: true).push<CodeEntryResult>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => CodeEntryPage(
          type: type,
          title: title,
          subtitle: subtitle,
          confirm: confirm,
          validate: validate,
          allowTypeSwitch: allowTypeSwitch,
        ),
      ),
    );
  }

  @override
  State<CodeEntryPage> createState() => _CodeEntryPageState();
}

class CodeEntryResult {
  const CodeEntryResult(this.code, this.type);
  final String code;
  final LockType type;
}

class _CodeEntryPageState extends State<CodeEntryPage> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late LockType _type = widget.type;
  final _pwd = TextEditingController();
  String _input = '';
  String? _first;
  String? _error;

  @override
  void dispose() {
    _shake.dispose();
    _pwd.dispose();
    super.dispose();
  }

  void _digit(int d) {
    if (_input.length >= _type.length) return;
    setState(() {
      _input += '$d';
      _error = null;
    });
    if (_input.length == _type.length) {
      Future.delayed(const Duration(milliseconds: 90), () => _commit(_input));
    }
  }

  void _commit(String code) {
    if (!_type.isPin && code.length < 4) {
      _fail('Password must be at least 4 characters');
      return;
    }
    if (_first == null) {
      final err = widget.validate?.call(code);
      if (err != null) {
        _fail(err);
        return;
      }
      if (!widget.confirm) {
        Navigator.pop(context, CodeEntryResult(code, _type));
        return;
      }
      setState(() {
        _first = code;
        _input = '';
        _pwd.clear();
      });
    } else {
      if (code == _first) {
        Vibe.success(AppState.I.config.style);
        Navigator.pop(context, CodeEntryResult(code, _type));
      } else {
        _first = null;
        _fail('Codes didn’t match. Try again');
      }
    }
  }

  void _fail(String msg) {
    Vibe.error(AppState.I.config.style);
    _shake.forward(from: 0);
    setState(() {
      _error = msg;
      _input = '';
      _pwd.clear();
    });
  }

  Future<void> _switchType() async {
    final t = await showCupertinoModalPopup<LockType>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          for (final t in LockType.values) CupertinoActionSheetAction(onPressed: () => Navigator.pop(c, t), child: Text(t.label)),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
      ),
    );
    if (t != null && t != _type) {
      setState(() {
        _type = t;
        _input = '';
        _first = null;
        _error = null;
        _pwd.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final title = _first == null ? widget.title : 'Confirm your code';
    return Scaffold(
      backgroundColor: C.bg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SizedBox(height: pad.top + 4),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: C.silver, fontSize: 16)),
              ),
              const Spacer(),
              if (widget.allowTypeSwitch && _first == null)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: _switchType,
                  child: Text(_type.label, style: const TextStyle(color: C.silver, fontSize: 16)),
                ),
            ],
          ),
          const Spacer(flex: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Column(
              key: ValueKey(title),
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: C.text, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _first == null ? (widget.subtitle ?? '') : 'Enter the same code once more',
                    textAlign: TextAlign.center,
                    style: T.sub.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          Shake(
            animation: _shake,
            child: _type.isPin
                ? PinDots(length: _type.length, filled: _input.length, color: C.silver)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.only(left: 16, right: 6),
                      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: ValueKey('pwd$_first'),
                              controller: _pwd,
                              autofocus: true,
                              obscureText: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: const TextStyle(color: C.text, fontSize: 17, letterSpacing: 2),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Password',
                                hintStyle: TextStyle(color: C.text3, letterSpacing: 0),
                              ),
                              onSubmitted: _commit,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _commit(_pwd.text),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(color: C.silver, shape: BoxShape.circle),
                              child: const Icon(CupertinoIcons.arrow_right, color: Colors.black, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 20,
            child: Text(_error ?? '', style: const TextStyle(color: C.red, fontSize: 13.5)),
          ),
          const Spacer(flex: 2),
          if (_type.isPin)
            Keypad(
              order: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 0],
              style: KeypadStyle.filled,
              accent: C.silver,
              onDigit: _digit,
              feedback: () => Vibe.key(AppState.I.config.style),
              onDelete: () {
                if (_input.isNotEmpty) setState(() => _input = _input.substring(0, _input.length - 1));
              },
              canDelete: _input.isNotEmpty,
            )
          else
            const Spacer(flex: 3),
          SizedBox(height: pad.bottom + 26),
        ],
      ),
    );
  }
}

/// Verify the current main code before sensitive changes.
Future<bool> verifyCurrent(BuildContext context, AppConfig cfg, bool Function(String) isMain) async {
  final r = await CodeEntryPage.open(
    context,
    type: cfg.type,
    title: 'Enter current code',
    subtitle: 'Enter your main code to continue',
    confirm: false,
    validate: (c) => isMain(c) ? null : 'Wrong code',
  );
  return r != null;
}
