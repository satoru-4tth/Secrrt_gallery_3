import 'dart:io';
import 'package:flutter/material.dart';

class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.dir,
    required this.onOpen,
    required this.onDelete,
  });

  final Directory dir;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final name = dir.path.split(Platform.pathSeparator).last;
    return InkWell(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Expanded(child: Icon(Icons.folder, size: 48)),
          Row(children: [
            Expanded(
                child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,                // ← 少し大きく
                      fontWeight: FontWeight.bold, // ← 太字で見やすく
                      color: Colors.grey,          // ← 白以外にしたい場合
                    ),
                ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'フォルダ削除',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('フォルダを削除しますか？'),
                    content: Text('$name\n（中身もすべて削除されます）'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
                    ],
                  ),
                ) ?? false;
                if (ok) await onDelete();
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
