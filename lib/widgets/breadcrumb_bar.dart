// パンくずリストを表示するためのバーを表示する
import 'dart:io';
import 'package:flutter/material.dart';

class BreadcrumbBar extends StatelessWidget implements PreferredSizeWidget {
  const BreadcrumbBar({
    super.key,
    required this.crumbs,
    required this.onUp,
    required this.onTapDir,
    required this.onFileDroppedToParent, // ★ 追加
  });

  final List<Directory> crumbs;
  final VoidCallback onUp;
  final void Function(Directory) onTapDir;

  // ★ 追加: 「一つ上のフォルダへ」の所にドロップされたとき呼ばれる
  // 親フォルダ = crumbs[crumbs.length - 2] をターゲットにする想定
  final Future<void> Function(File droppedFile, Directory parentDir)
  onFileDroppedToParent;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final atRoot = crumbs.length <= 1; // ルート判定

    // 親ディレクトリ（1つ上）があるならここで取れる
    final Directory? parentDir =
    atRoot ? null : crumbs[crumbs.length - 2];

    return PreferredSize(
      preferredSize: preferredSize,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // ルートでなければ「一つ上のフォルダへ」ボタンを表示
            if (!atRoot)
              _buildParentDropTarget(
                context: context,
                parentDir: parentDir!,
              ),

            if (!atRoot) const SizedBox(width: 8),

            // パンくず
            ...List.generate(crumbs.length, (i) {
              final d = crumbs[i];
              final isLast = i == crumbs.length - 1;
              final isRoot = i == 0; // ルート判定

              final parts = d.path.split(Platform.pathSeparator);
              final tail = parts.isNotEmpty ? parts.last : '';
              final label = isRoot ? 'ホーム' : (tail.isEmpty ? 'root' : tail);

              return Row(
                children: [
                  ActionChip(
                    label: Text(label),
                    onPressed: isLast ? null : () => onTapDir(d),
                  ),
                  if (!isLast) const Icon(Icons.chevron_right, size: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ★ 追加: 「一つ上のフォルダへ」ボタンを DragTarget<File> 化したもの
  Widget _buildParentDropTarget({
    required BuildContext context,
    required Directory parentDir,
  }) {
    return DragTarget<File>(
      onWillAccept: (data) {
        // data != null なら受け入れOK
        return data != null;
      },
      onAccept: (file) async {
        // ファイルを親フォルダへ移動させる処理は
        // 親ウィジェット(SecretGalleryPage)側にやってもらう
        await onFileDroppedToParent(file, parentDir);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '上のフォルダに移動しました: ${_fileName(file)}',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return FilledButton.tonal(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (_) => isHighlighted
                  ? Colors.purple.shade400
                  : null, // 通常はデフォルト、ドラッグ中は紫強調
            ),
            side: WidgetStateProperty.resolveWith<BorderSide?>(
                  (_) => isHighlighted
                  ? const BorderSide(
                color: Colors.purpleAccent,
                width: 2,
              )
                  : null,
            ),
          ),
          onPressed: onUp,
          child: Row(
            children: [
              const Icon(Icons.arrow_upward, size: 16),
              const SizedBox(width: 4),
              Text(
                isHighlighted ? 'ここにドロップで一つ上のフォルダへ移動' : '一つ上のフォルダへ',
              ),
            ],
          ),
        );
      },
    );
  }

  String _fileName(File f) {
    final parts = f.path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : f.path;
  }
}
