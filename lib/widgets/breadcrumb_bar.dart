// パンくずリストを表示するためのバーを表示する
import 'dart:io';
import 'package:flutter/material.dart';

class BreadcrumbBar extends StatelessWidget implements PreferredSizeWidget {
  const BreadcrumbBar({
    super.key,
    required this.crumbs,
    required this.onUp,
    required this.onTapDir,
  });

  final List<Directory> crumbs;
  final VoidCallback onUp;
  final void Function(Directory) onTapDir;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final atRoot = crumbs.length <= 1; // ルート判定

    return PreferredSize(
      preferredSize: preferredSize,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // ルートの時は「上へ」を出さない
            if (!atRoot)
            FilledButton.tonal(
              onPressed: onUp,
              child: const Row(children: [Icon(Icons.arrow_upward, size: 16), SizedBox(width: 4), Text('上へ')]),
            ),


            if (!atRoot) const SizedBox(width: 8),
            //パンくず
            ...List.generate(crumbs.length, (i) {
              final d = crumbs[i];
              final isLast = i == crumbs.length - 1;
              final isRoot = i == 0; //ルート判定

              final parts = d.path.split(Platform.pathSeparator);
              final tail = parts.isNotEmpty ? parts.last : '';

              final label = isRoot ? 'ホーム' : (tail.isEmpty ? 'root' : tail);


              return Row(children: [
                ActionChip(label: Text(label), onPressed: isLast ? null : () => onTapDir(d)),
                if (!isLast) const Icon(Icons.chevron_right, size: 16),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}
