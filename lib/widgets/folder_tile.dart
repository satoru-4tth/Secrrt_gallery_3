// フォルダをタイル表示するウィジェット
// ★ ドラッグ&ドロップ対応版
import 'dart:io';
import 'package:flutter/material.dart';

class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.dir,
    required this.onOpen,
    required this.onDelete,
    this.onExport, // もともとのやつ（未使用でもOK）
    required this.onFileDropped, // ★ 追加：ファイルがドロップされたとき
  });

  final Directory dir;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;
  final Future<void> Function(Directory dir)? onExport;

  // ★ 新規
  // FileTile 側の LongPressDraggable<File> から落ちてきた File を受け取りたいので、
  // (file, targetDir) を上位（secret_gallery_pageなど）に渡して、実際の移動＋refreshをやってもらう
  final Future<void> Function(File droppedFile, Directory targetDir)
  onFileDropped;

  @override
  Widget build(BuildContext context) {
    final name = dir.path.split(Platform.pathSeparator).last;

    return DragTarget<File>(
      // ドロップ可能か？ true を返せばハイライトが出る
      onWillAccept: (data) {
        // ここで条件付けも可能（例：同じディレクトリなら拒否など）
        return data != null;
      },

      // 実際にドロップ（指を離した）とき
      onAccept: (file) async {
        await onFileDropped(file, dir);
      },

      builder: (context, candidateData, rejectedData) {
        // candidateData が空でなければ「いま上にドラッグされてる途中」
        final isHighlighted = candidateData.isNotEmpty;

        return InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              // ★ ドラッグ中は色や枠線を変えてユーザーに分かりやすくする
              color: isHighlighted
                  ? Colors.purple.shade400
                  : Colors.blue.shade300,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHighlighted ? Colors.purpleAccent : Colors.transparent,
                width: isHighlighted ? 3 : 0,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // フォルダアイコン
                Expanded(
                  child: Icon(
                    Icons.folder,
                    size: 48,
                    color: isHighlighted ? Colors.white : Colors.white,
                  ),
                ),

                Row(
                  children: [
                    // フォルダ名
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14, // 少し大きく
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // 削除ボタン
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.white,
                      tooltip: 'フォルダ削除',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('フォルダを削除しますか？'),
                            content: Text(
                              '$name\n（中身もすべて削除されます）',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(c, false),
                                child: const Text('キャンセル'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(c, true),
                                child: const Text('削除'),
                              ),
                            ],
                          ),
                        ) ??
                            false;
                        if (ok) await onDelete();
                      },
                    ),

                    // 端末に戻す（いまはUI非表示のまま）
                    // if (onExport != null)
                    //   PopupMenuButton<String>(
                    //     onSelected: (v) async {
                    //       if (v == 'export_folder') {
                    //         await onExport!(dir);
                    //       }
                    //     },
                    //     itemBuilder: (_) => const [
                    //       PopupMenuItem(
                    //         value: 'export_folder',
                    //         child: Text('このフォルダを端末へ戻す'),
                    //       ),
                    //     ],
                    //   ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
