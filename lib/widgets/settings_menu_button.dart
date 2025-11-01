// 右上に配置する「設定メニュー」ボタンを定義している
import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import '../pages/change_password_page.dart';

class SettingsMenuButton extends StatelessWidget {
  const SettingsMenuButton({super.key});

  Future<void> _onSelected(BuildContext context, String value) async {
    switch (value) {
      case 'pw':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
        break;

      case 'cache':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('キャッシュをクリアしますか？'),
            content: const Text(
              '一時ファイルや画像キャッシュを削除します。\n※ 秘密ギャラリー本体データは削除しません。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('クリア'),
              ),
            ],
          ),
        );

        if (ok == true) {
          try {
            await CacheService.clearAll();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('キャッシュをクリアしました')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('クリアに失敗: $e')));
            }
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: '設定',
      onSelected: (v) => _onSelected(context, v),
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'pw', child: Text('パスワードを変更')),
        PopupMenuItem(value: 'cache', child: Text('キャッシュをクリア')),
      ],
    );
  }
}
