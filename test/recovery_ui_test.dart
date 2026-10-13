import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_gallery_3/pages/recovery_page.dart';
import 'package:secret_gallery_3/services/password_service.dart';
import 'package:secret_gallery_3/widgets/recovery_code_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> openPage(WidgetTester t, PasswordService svc) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => RecoveryPage(service: svc)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, String code, String p1, String p2) async {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), code);
    await t.enterText(fields.at(1), p1);
    await t.enterText(fields.at(2), p2);
    await t.tap(find.text('再設定'));
  }

  testWidgets('PINが一致しないとエラー表示', (t) async {
    final svc = PasswordService(iterations: 1000);
    await openPage(t, svc);
    await fill(t, 'AAAA-AAAA-AAAA', '1111', '2222');
    await t.pumpAndSettle();
    expect(find.text('新しいPINが一致しません'), findsOneWidget);
  });

  testWidgets('PINが4桁未満だとエラー表示', (t) async {
    final svc = PasswordService(iterations: 1000);
    await openPage(t, svc);
    await fill(t, 'AAAA-AAAA-AAAA', '11', '11');
    await t.pumpAndSettle();
    expect(find.text('新しいPINは「4桁の数字のみ」です'), findsOneWidget);
  });

  testWidgets('回復コード未発行ならその旨を表示', (t) async {
    final svc = PasswordService(iterations: 1000);
    await openPage(t, svc);
    await fill(t, 'AAAA-AAAA-AAAA', '1111', '1111');
    await t.pumpAndSettle();
    expect(find.text('回復コードが登録されていません'), findsOneWidget);
  });

  testWidgets('間違ったコードはエラー表示', (t) async {
    final svc = PasswordService(iterations: 1000);
    await t.runAsync(() => svc.issueRecoveryCode());
    await openPage(t, svc);
    await fill(t, 'AAAA-AAAA-AAAA', '1111', '1111');
    await t.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await t.pumpAndSettle();
    expect(find.text('回復コードが正しくありません'), findsOneWidget);
  });

  testWidgets('成功→新コード表示→「控えました」を押すまで閉じられない→画面が閉じる', (t) async {
    final svc = PasswordService(iterations: 1000);
    late String code;
    await t.runAsync(() async {
      await svc.setPassword(newPass: '1234');
      code = await svc.issueRecoveryCode();
    });
    await openPage(t, svc);
    await fill(t, code, '5678', '5678');
    // PBKDF2 等の非同期処理が終わるまで、実時間待ちとpumpを交互に行う
    for (var i = 0; i < 50 && find.text('PINを再設定しました').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 50));
    }
    // 背後で処理中スピナーが回っているので pumpAndSettle は使えない
    await t.pump(const Duration(milliseconds: 500));

    // 新しい回復コードのダイアログ
    expect(find.text('PINを再設定しました'), findsOneWidget);
    final close = find.widgetWithText(FilledButton, '閉じる');
    expect(tester(close, t).onPressed, isNull); // チェック前は押せない

    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    expect(tester(close, t).onPressed, isNotNull);
    await t.tap(close);
    await t.pumpAndSettle(); // ダイアログが閉じ、画面も閉じてスピナーも消える

    // 再設定画面は閉じて元の画面に戻る
    expect(find.text('PINの再設定'), findsNothing);
    expect(find.text('open'), findsOneWidget);

    await t.runAsync(() async {
      expect(await svc.verify('5678'), isTrue);
      expect(await svc.verify('1234'), isFalse);
    });
  });

  testWidgets('回復コードダイアログ：コードを表示し、チェック前は閉じられない', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showRecoveryCodeDialog(ctx, 'ABCD-EFGH-JKMN'),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('ABCD-EFGH-JKMN'), findsOneWidget);

    // 背景タップでは閉じない
    await t.tapAt(const Offset(2, 2));
    await t.pumpAndSettle();
    expect(find.text('ABCD-EFGH-JKMN'), findsOneWidget);

    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, '閉じる'));
    await t.pumpAndSettle();
    expect(find.text('ABCD-EFGH-JKMN'), findsNothing);
  });
}

FilledButton tester(Finder f, WidgetTester t) => t.widget<FilledButton>(f);
