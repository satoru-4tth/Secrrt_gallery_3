// lib/utils/first_launch_popup.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchPopup {
  static const _kShownKey = 'first_launch_popup_shown_v1';

  /// 初回だけダイアログを表示
  static Future<void> showIfFirstOpen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_kShownKey) ?? false;
    if (shown) return;

    // 画面描画後に出す（initState直後の呼び出しに安全）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showDialog(
        context: context,
        barrierDismissible: false, // 外タップで消えない
        builder: (ctx) => AlertDialog(
          title: const Text('初回のご案内'),
          content: const Text(
              '初期パスワードは 1234= です。\n'
                  '計算機画面で「1 2 3 4 =」と入力して開いてください。'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // OK後に二度と出ないようフラグを保存
      await prefs.setBool(_kShownKey, true);
    });
  }

  /// デバッグ用（必要なら）：表示フラグをリセット
  static Future<void> resetForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kShownKey);
  }
}
