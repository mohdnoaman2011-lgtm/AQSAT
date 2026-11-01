import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// قفل التطبيق برمز من 4 أرقام.
/// يُخزَّن الرمز مُشفَّرًا (SHA-256 مع قيمة عشوائية) ومنفصلًا عن بيانات العقود،
/// فلا يدخل في النسخ الاحتياطي ولا يتأثر بالاستعادة.
class AppLock extends ChangeNotifier {
  SharedPreferences? _p;
  String? _hash, _salt;
  bool locked = false;
  int _fails = 0;
  DateTime? _until;

  bool get enabled => _hash != null;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _hash = _p!.getString('pin_hash');
    _salt = _p!.getString('pin_salt');
    _fails = _p!.getInt('pin_fails') ?? 0;
    final u = _p!.getInt('pin_until');
    _until = u == null ? null : DateTime.fromMillisecondsSinceEpoch(u);
    locked = enabled; // يُقفل عند كل تشغيل
  }

  String _h(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    _salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    _hash = _h(pin, _salt!);
    await _p!.setString('pin_hash', _hash!);
    await _p!.setString('pin_salt', _salt!);
    notifyListeners();
  }

  Future<void> clear() async {
    _hash = null;
    _salt = null;
    locked = false;
    _fails = 0;
    _until = null;
    for (final k in ['pin_hash', 'pin_salt', 'pin_fails', 'pin_until']) {
      await _p!.remove(k);
    }
    notifyListeners();
  }

  bool check(String pin) => enabled && _h(pin, _salt!) == _hash;

  /// الثواني المتبقية للانتظار بعد محاولات خاطئة متكررة (كل 5 محاولات).
  int get wait {
    final u = _until;
    if (u == null) return 0;
    final s = u.difference(DateTime.now()).inSeconds + 1;
    return s > 0 ? s : 0;
  }

  bool tryUnlock(String pin) {
    if (wait > 0) return false;
    if (check(pin)) {
      _fails = 0;
      _until = null;
      _p?.setInt('pin_fails', 0);
      _p?.remove('pin_until');
      locked = false;
      notifyListeners();
      return true;
    }
    _fails++;
    if (_fails % 5 == 0) {
      _until = DateTime.now().add(Duration(seconds: 30 * (_fails ~/ 5)));
      _p?.setInt('pin_until', _until!.millisecondsSinceEpoch);
    }
    _p?.setInt('pin_fails', _fails);
    notifyListeners();
    return false;
  }

  void lockNow() {
    if (enabled && !locked) {
      locked = true;
      notifyListeners();
    }
  }
}

final appLock = AppLock();
