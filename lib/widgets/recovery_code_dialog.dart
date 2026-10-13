// 回復コードを表示するダイアログ
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 回復コードを表示する。「控えました」にチェックするまで閉じられない。
Future<void> showRecoveryCodeDialog(
  BuildContext context,
  String code, {
  String title = '回復コード',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      var saved = false;
      return StatefulBuilder(
        builder: (ctx, setState) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PINを忘れたときに、このコードでPINを再設定できます。'),
                  const SizedBox(height: 12),
                  Center(
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('コピーしました')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('コピー'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '・このコードは今だけ表示されます。必ず他の安全な場所に控えてください。\n'
                    '・使い方：電卓画面の上部「Calculator」の文字を長押し →\n'
                    '　回復コードを入力。\n'
                    '・コードを紛失した場合は、ギャラリー右上の設定から再発行できます。',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: saved,
                    onChanged: (v) => setState(() => saved = v ?? false),
                    title: const Text('控えました'),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: saved ? () => Navigator.of(ctx).pop() : null,
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
