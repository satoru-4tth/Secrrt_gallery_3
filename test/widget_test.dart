// 電卓画面（MyApp）の導線テスト：計算と、回復画面への入口（タイトル長押し）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secret_gallery_3/main.dart';

// 画面の数字表示と同じ文字が電卓ボタンにもあるため、ボタン（ツリーの後ろ側）を選ぶ
Finder key(String s) => find.text(s).last;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'init_pass_info_shown_v1': true});
    // AdMob のプラグイン呼び出しをダミー化
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'plugins.flutter.io/google_mobile_ads',
          // 独自コーデックのため中身は読まず、常に「成功(null)」を返す
          (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
        );
  });

  testWidgets('電卓として計算できる', (t) async {
    await t.pumpWidget(const MyApp());
    await t.pump();
    await t.tap(key('7'));
    await t.tap(key('+'));
    await t.tap(key('5'));
    await t.tap(key('='));
    await t.pump();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('タイトル長押しで PIN再設定画面が開く', (t) async {
    await t.pumpWidget(const MyApp());
    await t.pump();
    expect(find.text('PINの再設定'), findsNothing);
    await t.longPress(find.byKey(const Key('calc_title')));
    await t.pumpAndSettle();
    expect(find.text('PINの再設定'), findsOneWidget);
    expect(find.byKey(const Key('recovery_code_field')), findsOneWidget);
  });
}
