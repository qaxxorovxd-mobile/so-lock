import 'dart:convert';

enum LockType { pin4, pin6, password }

extension LockTypeX on LockType {
  bool get isPin => this != LockType.password;
  int get length => this == LockType.pin6 ? 6 : 4;
  String get label => switch (this) {
    LockType.pin4 => '4-digit PIN',
    LockType.pin6 => '6-digit PIN',
    LockType.password => 'Password',
  };
}

/// What happens when a secret (duress) code is entered.
enum DuressAction { lockScreen, goHome, fakeCrash, silentOpen }

extension DuressActionX on DuressAction {
  String get title => switch (this) {
    DuressAction.lockScreen => 'Lock the screen',
    DuressAction.goHome => 'Go to home screen',
    DuressAction.fakeCrash => 'Show a fake crash',
    DuressAction.silentOpen => 'Open & take a silent photo',
  };
  String get subtitle => switch (this) {
    DuressAction.lockScreen => 'The phone screen locks instantly',
    DuressAction.goHome => 'Closes the app and shows the home screen',
    DuressAction.fakeCrash => 'Shows an “app keeps stopping” dialog',
    DuressAction.silentOpen => 'Opens the app; you review the photo later',
  };
}

class DuressCode {
  DuressCode({required this.id, required this.hash, required this.action, this.label = '', this.photo = true});
  final String id;
  String hash;
  DuressAction action;
  String label;
  bool photo;

  Map<String, dynamic> toJson() => {'id': id, 'hash': hash, 'action': action.name, 'label': label, 'photo': photo};
  factory DuressCode.fromJson(Map<String, dynamic> j) => DuressCode(
    id: j['id'] as String,
    hash: j['hash'] as String,
    action: DuressAction.values.firstWhere((a) => a.name == j['action'], orElse: () => DuressAction.lockScreen),
    label: j['label'] as String? ?? '',
    photo: j['photo'] as bool? ?? true,
  );
}

class TrustedPlace {
  TrustedPlace({required this.name, required this.lat, required this.lng, this.radius = 150});
  String name;
  double lat, lng;
  double radius;
  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng, 'r': radius};
  factory TrustedPlace.fromJson(Map<String, dynamic> j) => TrustedPlace(
    name: j['name'] as String? ?? 'Place',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    radius: (j['r'] as num?)?.toDouble() ?? 150,
  );
}

class SmartConfig {
  bool scheduleOn = false;
  int start = 9 * 60; // minute of day
  int end = 18 * 60;
  Set<int> days = {1, 2, 3, 4, 5, 6, 7};
  bool wifiOn = false;
  List<String> ssids = [];
  bool placesOn = false;
  List<TrustedPlace> places = [];

  Map<String, dynamic> toJson() => {
    'schedule': {'on': scheduleOn, 'start': start, 'end': end, 'days': days.toList()..sort()},
    'wifi': {'on': wifiOn, 'ssids': ssids},
    'places': {'on': placesOn, 'list': places.map((p) => p.toJson()).toList()},
  };

  static SmartConfig fromJson(Map<String, dynamic>? j) {
    final s = SmartConfig();
    if (j == null) return s;
    final sc = j['schedule'] as Map<String, dynamic>?;
    if (sc != null) {
      s.scheduleOn = sc['on'] as bool? ?? false;
      s.start = sc['start'] as int? ?? s.start;
      s.end = sc['end'] as int? ?? s.end;
      s.days = ((sc['days'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7]).cast<int>().toSet();
    }
    final w = j['wifi'] as Map<String, dynamic>?;
    if (w != null) {
      s.wifiOn = w['on'] as bool? ?? false;
      s.ssids = ((w['ssids'] as List?) ?? const []).cast<String>().toList();
    }
    final p = j['places'] as Map<String, dynamic>?;
    if (p != null) {
      s.placesOn = p['on'] as bool? ?? false;
      s.places = ((p['list'] as List?) ?? const []).map((e) => TrustedPlace.fromJson(e as Map<String, dynamic>)).toList();
    }
    return s;
  }
}

enum KeypadStyle { filled, ring, minimal }

class LockStyle {
  int accent = 0xFFF2F2F7;
  int background = 0; // index into presets, -1 = custom image
  String? imagePath;
  double dim = 0.35;
  double blur = 18;
  KeypadStyle keypad = KeypadStyle.filled;
  bool shuffle = false;
  bool showIcon = true;

  /// Vibration strength: 0 off, 1 light, 2 medium, 3 strong.
  int vibeLevel = 2;
  bool vibeKeys = true;
  bool vibeError = true;
  bool vibeSuccess = true;
  bool animations = true;

  bool get haptics => vibeLevel > 0;

  Map<String, dynamic> toJson() => {
    'accent': accent,
    'bg': background,
    'img': imagePath,
    'dim': dim,
    'blur': blur,
    'keypad': keypad.name,
    'shuffle': shuffle,
    'icon': showIcon,
    'vibeLevel': vibeLevel,
    'vibeKeys': vibeKeys,
    'vibeError': vibeError,
    'vibeSuccess': vibeSuccess,
    'anim': animations,
  };

  static LockStyle fromJson(Map<String, dynamic>? j) {
    final s = LockStyle();
    if (j == null) return s;
    s.accent = j['accent'] as int? ?? s.accent;
    s.background = j['bg'] as int? ?? 0;
    s.imagePath = j['img'] as String?;
    s.dim = (j['dim'] as num?)?.toDouble() ?? s.dim;
    s.blur = (j['blur'] as num?)?.toDouble() ?? s.blur;
    s.keypad = KeypadStyle.values.firstWhere((k) => k.name == j['keypad'], orElse: () => KeypadStyle.filled);
    s.shuffle = j['shuffle'] as bool? ?? false;
    s.showIcon = j['icon'] as bool? ?? true;
    // Older configs stored a single on/off "haptics" flag.
    s.vibeLevel = j['vibeLevel'] as int? ?? ((j['haptics'] as bool? ?? true) ? 2 : 0);
    s.vibeKeys = j['vibeKeys'] as bool? ?? true;
    s.vibeError = j['vibeError'] as bool? ?? true;
    s.vibeSuccess = j['vibeSuccess'] as bool? ?? true;
    s.animations = j['anim'] as bool? ?? true;
    return s;
  }

  LockStyle copy() => LockStyle.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);
}

class AppConfig {
  bool setupDone = false;
  LockType type = LockType.pin4;
  String hash = '';
  String salt = '';
  bool biometrics = true;
  bool enabled = true;
  bool lockSelf = true;
  List<String> locked = [];
  String relock = 'exit'; // exit | screen | timeout
  int relockMinutes = 1;
  List<DuressCode> duress = [];
  bool intruderOn = true;
  int intruderAfter = 2;
  bool intruderBack = false;
  SmartConfig smart = SmartConfig();
  LockStyle style = LockStyle();

  Map<String, dynamic> toJson() => {
    'setupDone': setupDone,
    'type': type.name,
    'hash': hash,
    'salt': salt,
    'biometrics': biometrics,
    'enabled': enabled,
    'lockSelf': lockSelf,
    'locked': locked,
    'relock': relock,
    'relockMinutes': relockMinutes,
    'duress': duress.map((d) => d.toJson()).toList(),
    'intruderOn': intruderOn,
    'intruderAfter': intruderAfter,
    'intruderBack': intruderBack,
    'smart': smart.toJson(),
    'style': style.toJson(),
  };

  /// Only what the background service needs — no secrets leave Dart.
  String toNativeJson() => jsonEncode({
    'enabled': enabled && setupDone,
    'locked': locked,
    'relock': relock,
    'relockMinutes': relockMinutes,
    'smart': smart.toJson(),
  });

  static AppConfig fromJson(Map<String, dynamic> j) {
    final c = AppConfig();
    c.setupDone = j['setupDone'] as bool? ?? false;
    c.type = LockType.values.firstWhere((t) => t.name == j['type'], orElse: () => LockType.pin4);
    c.hash = j['hash'] as String? ?? '';
    c.salt = j['salt'] as String? ?? '';
    c.biometrics = j['biometrics'] as bool? ?? true;
    c.enabled = j['enabled'] as bool? ?? true;
    c.lockSelf = j['lockSelf'] as bool? ?? true;
    c.locked = ((j['locked'] as List?) ?? const []).cast<String>().toList();
    c.relock = j['relock'] as String? ?? 'exit';
    c.relockMinutes = j['relockMinutes'] as int? ?? 1;
    c.duress = ((j['duress'] as List?) ?? const []).map((e) => DuressCode.fromJson(e as Map<String, dynamic>)).toList();
    c.intruderOn = j['intruderOn'] as bool? ?? true;
    c.intruderAfter = j['intruderAfter'] as int? ?? 2;
    c.intruderBack = j['intruderBack'] as bool? ?? false;
    c.smart = SmartConfig.fromJson(j['smart'] as Map<String, dynamic>?);
    c.style = LockStyle.fromJson(j['style'] as Map<String, dynamic>?);
    return c;
  }
}

class IntruderEvent {
  IntruderEvent({
    required this.id,
    required this.time,
    required this.pkg,
    required this.appName,
    required this.reason,
    required this.attempts,
    required this.photos,
  });
  final String id;
  final DateTime time;
  final String pkg;
  final String appName;
  final String reason; // wrong | duress
  final int attempts;
  final List<String> photos;

  Map<String, dynamic> toJson() => {
    'id': id,
    't': time.millisecondsSinceEpoch,
    'pkg': pkg,
    'app': appName,
    'reason': reason,
    'n': attempts,
    'photos': photos,
  };
  factory IntruderEvent.fromJson(Map<String, dynamic> j) => IntruderEvent(
    id: j['id'] as String,
    time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    pkg: j['pkg'] as String? ?? '',
    appName: j['app'] as String? ?? '',
    reason: j['reason'] as String? ?? 'wrong',
    attempts: j['n'] as int? ?? 0,
    photos: ((j['photos'] as List?) ?? const []).cast<String>().toList(),
  );
}
