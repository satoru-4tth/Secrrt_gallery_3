// パスワード関係の処理
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasswordService {
  static const _kHashKey = 'vault.pass.hash';
  static const _kSaltKey = 'vault.pass.salt';
  static const _kFailCntKey = 'vault.pass.fail.count';
  static const _kLockUntilKey = 'vault.pass.lock.until'; // epoch ms
  // 追加：パスワードで4桁数字のみ使用可能
  static final _pinRegex = RegExp(r'^\d{4}$');

  final _storage = const FlutterSecureStorage();
  final _algo = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256);
  /// ★ 開発側固定のマスターPIN（変更不可・4桁半角数字）
  static const String _MASTER_PIN = '9090'; // ←好きな4桁に

  Future<bool> hasPassword() async {
    final h = await _storage.read(key: _kHashKey);
    final s = await _storage.read(key: _kSaltKey);
    return (h != null && s != null);
  }

  /// 初回設定 or 変更（oldPassが null のときは初回設定扱い）
  Future<void> setPassword({String? oldPass, required String newPass}) async {
    // 追加：形式チェック
    if (!_pinRegex.hasMatch(newPass)) {
      throw const FormatException('PINは4桁の数字のみです');
    }
    if (oldPass != null && !_pinRegex.hasMatch(oldPass)) {
      // 旧パスがある運用なら（任意）
      throw const FormatException('旧PINは4桁の数字のみです');
    }
    if (await hasPassword()) {
      if (oldPass == null || !await verify(oldPass)) {
        throw Exception('旧パスワードが違います');
      }
    }
    final salt = _randomBytes(16);
    final hash = await _derive(newPass, salt);
    await _storage.write(key: _kHashKey, value: base64Encode(hash));
    await _storage.write(key: _kSaltKey, value: base64Encode(salt));
  }

  /// 検証（ロック/失敗回数も管理）
  Future<bool> verify(String pass) async {
    // ★ 1) マスターPINなら無条件で解錠（ロックも解除）
    if (pass == _MASTER_PIN) {
      // 失敗カウンタ＆ロック解除
      await _storage.delete(key: _kFailCntKey);
      await _storage.delete(key: _kLockUntilKey);
      return true;
    }
    // ★ 2) ここから通常PIN（4桁）として検証
    if (!_pinRegex.hasMatch(pass)) return false;
    // ロック中か？
    final untilStr = await _storage.read(key: _kLockUntilKey);
    if (untilStr != null) {
      final until = int.tryParse(untilStr) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < until) return false;
    }

    final hStr = await _storage.read(key: _kHashKey);
    final sStr = await _storage.read(key: _kSaltKey);
    if (hStr == null || sStr == null) return false;

    final salt = base64Decode(sStr);
    final expected = base64Decode(hStr);
    final actual = await _derive(pass, salt);

    final ok = _constTimeEqual(actual, expected);
    await _updateFailState(ok);
    return ok;
  }

  Future<void> _updateFailState(bool success) async {
    if (success) {
      await _storage.delete(key: _kFailCntKey);
      await _storage.delete(key: _kLockUntilKey);
      return;
    }
    final cnt = int.tryParse((await _storage.read(key: _kFailCntKey)) ?? '0') ?? 0;
    final next = cnt + 1;
    await _storage.write(key: _kFailCntKey, value: '$next');

    // 失敗5回で30秒ロック、以後指数的に延ばす例
    if (next >= 5) {
      final backoffSec = 30 * pow(2, max(0, next - 5)).toInt();
      final until = DateTime.now().millisecondsSinceEpoch + backoffSec * 1000;
      await _storage.write(key: _kLockUntilKey, value: '$until');
    }
  }

  Future<List<int>> _derive(String pass, List<int> salt) async {
    final secret = SecretKey(utf8.encode(pass));
    final newKey = await _algo.deriveKey(secretKey: secret, nonce: salt);
    return await newKey.extractBytes();
    // PBKDF2 は nonce=ソルトを使う
  }

  List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  bool _constTimeEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
