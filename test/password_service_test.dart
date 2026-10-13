import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_gallery_3/services/password_service.dart';

PasswordService newService() => PasswordService(iterations: 1000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PIN（既存動作）', () {
    test('設定したPINで解錠でき、違うPINでは解錠できない', () async {
      final s = newService();
      expect(await s.hasPassword(), isFalse);
      await s.setPassword(newPass: '1234');
      expect(await s.hasPassword(), isTrue);
      expect(await s.verify('1234'), isTrue);
      expect(await s.verify('4321'), isFalse);
    });

    test('マスターPIN(9090)ではもう解錠できない', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      expect(await s.verify('9090'), isFalse);
    });

    test('4桁数字以外は拒否', () async {
      final s = newService();
      expect(() => s.setPassword(newPass: '12a4'), throwsFormatException);
      expect(() => s.setPassword(newPass: '123'), throwsFormatException);
    });

    test('旧PINが違うと変更できない', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      expect(
        () => s.setPassword(oldPass: '0000', newPass: '5555'),
        throwsException,
      );
      await s.setPassword(oldPass: '1234', newPass: '5555');
      expect(await s.verify('5555'), isTrue);
    });
  });

  group('回復コード', () {
    test('発行コードは XXXX-XXXX-XXXX 形式で、使用文字は紛らわしい文字を含まない', () async {
      final s = newService();
      final code = await s.issueRecoveryCode();
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$')));
      expect(await s.hasRecoveryCode(), isTrue);
    });

    test('発行のたびに別のコードになる', () async {
      final s = newService();
      final codes = <String>{};
      for (var i = 0; i < 20; i++) {
        codes.add(await s.issueRecoveryCode());
      }
      expect(codes.length, 20);
    });

    test('平文は保存されない（ストレージにコードそのものが無い）', () async {
      final s = newService();
      final code = await s.issueRecoveryCode();
      final all = await const FlutterSecureStorage().readAll();
      final raw = code.replaceAll('-', '');
      for (final v in all.values) {
        expect(v.contains(raw), isFalse);
        expect(v.contains(code), isFalse);
      }
    });

    test('正しいコードでPIN再設定でき、旧PINは無効・新PINが有効', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();

      final res = await s.resetPinWithRecoveryCode(code: code, newPin: '7777');
      expect(res.ok, isTrue);
      expect(await s.verify('7777'), isTrue);
      expect(await s.verify('1234'), isFalse);
    });

    test('使用済みコードは無効になり、新しいコードが返る', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();

      final res = await s.resetPinWithRecoveryCode(code: code, newPin: '7777');
      expect(res.newCode, isNotNull);
      expect(res.newCode, isNot(code));

      final again = await s.resetPinWithRecoveryCode(code: code, newPin: '8888');
      expect(again.ok, isFalse);
      expect(await s.verify('7777'), isTrue);

      final viaNew = await s.resetPinWithRecoveryCode(
        code: res.newCode!,
        newPin: '8888',
      );
      expect(viaNew.ok, isTrue);
      expect(await s.verify('8888'), isTrue);
    });

    test('小文字・空白・ハイフン無しでも受け付ける', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();
      final sloppy = ' ${code.replaceAll('-', '').toLowerCase()} ';
      final res = await s.resetPinWithRecoveryCode(code: sloppy, newPin: '2468');
      expect(res.ok, isTrue);
      expect(await s.verify('2468'), isTrue);
    });

    test('間違ったコードではPINは変わらない', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      await s.issueRecoveryCode();
      final res = await s.resetPinWithRecoveryCode(
        code: 'AAAA-AAAA-AAAA',
        newPin: '7777',
      );
      expect(res.ok, isFalse);
      expect(await s.verify('1234'), isTrue);
      expect(await s.verify('7777'), isFalse);
    });

    test('回復コード未発行なら noRecoveryCode', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final res = await s.resetPinWithRecoveryCode(
        code: 'AAAA-AAAA-AAAA',
        newPin: '7777',
      );
      expect(res.noRecoveryCode, isTrue);
      expect(await s.verify('1234'), isTrue);
    });

    test('新PINが不正なら例外で、何も変わらない', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();
      expect(
        () => s.resetPinWithRecoveryCode(code: code, newPin: '12'),
        throwsFormatException,
      );
      expect(await s.verify('1234'), isTrue);
      // コードは消費されていない
      expect(
        (await s.resetPinWithRecoveryCode(code: code, newPin: '5555')).ok,
        isTrue,
      );
    });

    test('5回失敗するとロックされ、正しいコードでも拒否される', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();

      for (var i = 0; i < 5; i++) {
        final r = await s.resetPinWithRecoveryCode(
          code: 'BBBB-BBBB-BBBB',
          newPin: '7777',
        );
        expect(r.ok, isFalse);
      }
      final locked = await s.resetPinWithRecoveryCode(code: code, newPin: '7777');
      expect(locked.ok, isFalse);
      expect(locked.lockedSeconds, isNotNull);
      expect(locked.lockedSeconds, inInclusiveRange(1, 30));
      expect(await s.verify('1234'), isTrue); // PINは変わっていない
    });

    test('形式不正の入力は失敗回数に数えない', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();
      for (var i = 0; i < 10; i++) {
        final r = await s.resetPinWithRecoveryCode(code: 'abc', newPin: '7777');
        expect(r.ok, isFalse);
        expect(r.lockedSeconds, isNull);
      }
      expect(
        (await s.resetPinWithRecoveryCode(code: code, newPin: '7777')).ok,
        isTrue,
      );
    });

    test('再設定するとPIN側の失敗ロックも解除される', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final code = await s.issueRecoveryCode();
      for (var i = 0; i < 5; i++) {
        expect(await s.verify('0000'), isFalse);
      }
      expect(await s.verify('1234'), isFalse); // ロック中
      final res = await s.resetPinWithRecoveryCode(code: code, newPin: '4321');
      expect(res.ok, isTrue);
      expect(await s.verify('4321'), isTrue);
    });

    test('コード再発行で旧コードは無効', () async {
      final s = newService();
      await s.setPassword(newPass: '1234');
      final old = await s.issueRecoveryCode();
      final fresh = await s.issueRecoveryCode();
      expect(
        (await s.resetPinWithRecoveryCode(code: old, newPin: '7777')).ok,
        isFalse,
      );
      expect(
        (await s.resetPinWithRecoveryCode(code: fresh, newPin: '7777')).ok,
        isTrue,
      );
    });

    test('normalizeRecoveryCode', () {
      expect(PasswordService.normalizeRecoveryCode('abcd-efgh-jkmn'), 'ABCDEFGHJKMN');
      expect(PasswordService.normalizeRecoveryCode('ABCD-EFGH-JKM'), isNull); // 短い
      expect(PasswordService.normalizeRecoveryCode('ABCD-EFGH-JKM0'), isNull); // 0は無い
      expect(PasswordService.normalizeRecoveryCode(''), isNull);
    });
  });
}
