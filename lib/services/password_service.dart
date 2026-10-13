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

  // 回復コード関連
  static const _kRecHashKey = 'vault.recovery.hash';
  static const _kRecSaltKey = 'vault.recovery.salt';
  static const _kRecFailCntKey = 'vault.recovery.fail.count';
  static const _kRecLockUntilKey = 'vault.recovery.lock.until'; // epoch ms

  /// 回復コードに使う文字（見間違えやすい I / O / 0 / 1 は除外した32種）
  static const _recAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _recLength = 12;
  static const _recMaxLockSec = 3600; // 回復コードの失敗ロックは最長1時間

  final FlutterSecureStorage _storage;
  final Pbkdf2 _algo;

  PasswordService({FlutterSecureStorage? storage, int iterations = 120000})
    : _storage = storage ?? const FlutterSecureStorage(),
      _algo = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

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
    await _writePin(newPass);
  }

  Future<void> _writePin(String pin) async {
    final salt = _randomBytes(16);
    final hash = await _derive(pin, salt);
    await _storage.write(key: _kHashKey, value: base64Encode(hash));
    await _storage.write(key: _kSaltKey, value: base64Encode(salt));
  }

  /// 検証（ロック/失敗回数も管理）
  Future<bool> verify(String pass) async {
    // 通常PIN（4桁）として検証
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
    final cnt =
        int.tryParse((await _storage.read(key: _kFailCntKey)) ?? '0') ?? 0;
    final next = cnt + 1;
    await _storage.write(key: _kFailCntKey, value: '$next');

    // 失敗5回で30秒ロック、以後指数的に延ばす例
    if (next >= 5) {
      final backoffSec = 30 * pow(2, max(0, next - 5)).toInt();
      final until = DateTime.now().millisecondsSinceEpoch + backoffSec * 1000;
      await _storage.write(key: _kLockUntilKey, value: '$until');
    }
  }

  // ================= 回復コード =================

  Future<bool> hasRecoveryCode() async {
    final h = await _storage.read(key: _kRecHashKey);
    final s = await _storage.read(key: _kRecSaltKey);
    return (h != null && s != null);
  }

  /// 回復コードを新規発行して保存する（既存のコードは無効になる）。
  /// 戻り値は表示用の平文コード（XXXX-XXXX-XXXX）。保存されるのはハッシュのみ。
  Future<String> issueRecoveryCode() async {
    final r = Random.secure();
    final raw = List.generate(
      _recLength,
      (_) => _recAlphabet[r.nextInt(_recAlphabet.length)],
    ).join();
    final salt = _randomBytes(16);
    final hash = await _derive(raw, salt);
    await _storage.write(key: _kRecHashKey, value: base64Encode(hash));
    await _storage.write(key: _kRecSaltKey, value: base64Encode(salt));
    await _storage.delete(key: _kRecFailCntKey);
    await _storage.delete(key: _kRecLockUntilKey);
    return formatRecoveryCode(raw);
  }

  /// 入力された回復コードを正規化する（大文字化・空白とハイフン除去）。
  /// 形式が不正なら null。
  static String? normalizeRecoveryCode(String input) {
    final t = input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (t.length != _recLength) return null;
    for (final c in t.split('')) {
      if (!_recAlphabet.contains(c)) return null;
    }
    return t;
  }

  static String formatRecoveryCode(String raw) {
    final parts = <String>[];
    for (var i = 0; i < raw.length; i += 4) {
      parts.add(raw.substring(i, min(i + 4, raw.length)));
    }
    return parts.join('-');
  }

  /// 回復コードで本人確認し、PINを newPin に再設定する。
  /// 成功時は回復コードを作り直して [RecoveryResult.newCode] で返す
  /// （使用済みのコードは無効になる）。
  Future<RecoveryResult> resetPinWithRecoveryCode({
    required String code,
    required String newPin,
  }) async {
    if (!_pinRegex.hasMatch(newPin)) {
      throw const FormatException('PINは4桁の数字のみです');
    }

    final untilStr = await _storage.read(key: _kRecLockUntilKey);
    final until = int.tryParse(untilStr ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < until) {
      return RecoveryResult.locked(((until - now) / 1000).ceil());
    }

    final hStr = await _storage.read(key: _kRecHashKey);
    final sStr = await _storage.read(key: _kRecSaltKey);
    if (hStr == null || sStr == null) return const RecoveryResult.noCode();

    final raw = normalizeRecoveryCode(code);
    if (raw == null) return const RecoveryResult.invalid(); // 形式不正は失敗に数えない

    final actual = await _derive(raw, base64Decode(sStr));
    if (!_constTimeEqual(actual, base64Decode(hStr))) {
      final cnt =
          int.tryParse((await _storage.read(key: _kRecFailCntKey)) ?? '0') ??
          0;
      final next = cnt + 1;
      await _storage.write(key: _kRecFailCntKey, value: '$next');
      if (next >= 5) {
        final sec = min(_recMaxLockSec, 30 * (1 << min(next - 5, 10)));
        final lockUntil = DateTime.now().millisecondsSinceEpoch + sec * 1000;
        await _storage.write(key: _kRecLockUntilKey, value: '$lockUntil');
      }
      return const RecoveryResult.invalid();
    }

    await _writePin(newPin);
    // PIN側の失敗回数・ロックも解除
    await _storage.delete(key: _kFailCntKey);
    await _storage.delete(key: _kLockUntilKey);
    final newCode = await issueRecoveryCode(); // 失敗カウンタもここでリセットされる
    return RecoveryResult.success(newCode);
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

/// 回復コードによるPIN再設定の結果
class RecoveryResult {
  final bool ok;
  final String? newCode; // 成功時：新しく発行した回復コード
  final int? lockedSeconds; // ロック中：残り秒数
  final bool noRecoveryCode; // 回復コードが未発行

  const RecoveryResult._({
    required this.ok,
    this.newCode,
    this.lockedSeconds,
    this.noRecoveryCode = false,
  });

  const RecoveryResult.success(String code)
    : this._(ok: true, newCode: code);
  const RecoveryResult.invalid() : this._(ok: false);
  const RecoveryResult.locked(int seconds)
    : this._(ok: false, lockedSeconds: seconds);
  const RecoveryResult.noCode() : this._(ok: false, noRecoveryCode: true);
}
