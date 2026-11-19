import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'models.dart';

sealed class CheckResult {
  const CheckResult();
}

class CheckOk extends CheckResult {
  const CheckOk();
}

class CheckDuress extends CheckResult {
  const CheckDuress(this.code);
  final DuressCode code;
}

class CheckWrong extends CheckResult {
  const CheckWrong();
}

class Security {
  Security._();

  static String newSalt() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Salted, stretched hash. Codes are never stored in plain text.
  static String hash(String code, String salt) {
    final key = utf8.encode(salt);
    var digest = Hmac(sha256, key).convert(utf8.encode(code)).bytes;
    for (var i = 0; i < 1500; i++) {
      digest = Hmac(sha256, key).convert(digest).bytes;
    }
    return base64UrlEncode(digest);
  }

  static bool _eq(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }

  /// Main code → open. A duress code → its action. Anything else → wrong.
  static CheckResult check(AppConfig c, String input) {
    final h = hash(input, c.salt);
    if (_eq(h, c.hash)) return const CheckOk();
    for (final d in c.duress) {
      if (_eq(h, d.hash)) return CheckDuress(d);
    }
    return const CheckWrong();
  }

  static bool isMain(AppConfig c, String input) => _eq(hash(input, c.salt), c.hash);

  /// Lockout after repeated failures: 5 → 30s, then doubling, capped at 15 min.
  static Duration lockoutFor(int fails) {
    if (fails < 5) return Duration.zero;
    final secs = 30 * pow(2, (fails - 5) ~/ 2).toInt();
    return Duration(seconds: min(secs, 900));
  }
}
