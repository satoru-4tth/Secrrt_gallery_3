// フォルダの色と形を選ぶボトムシート
import 'package:flutter/material.dart';
import '../models/folder_style.dart';

/// 保存を押したら選んだ [FolderStyle]、キャンセルなら null。
Future<FolderStyle?> showFolderStyleSheet(
  BuildContext context, {
  required FolderStyle initial,
  required String folderName,
}) {
  return showModalBottomSheet<FolderStyle>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FolderStyleSheet(initial: initial, folderName: folderName),
  );
}

class _FolderStyleSheet extends StatefulWidget {
  const _FolderStyleSheet({required this.initial, required this.folderName});
  final FolderStyle initial;
  final String folderName;

  @override
  State<_FolderStyleSheet> createState() => _FolderStyleSheetState();
}

class _FolderStyleSheetState extends State<_FolderStyleSheet> {
  late FolderStyle _style = widget.initial;

  @override
  Widget build(BuildContext context) {
    // 端末の文字サイズ設定が極端でもレイアウトが崩れないよう上限をかける
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'フォルダのデザイン',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Center(child: _preview()),
              const SizedBox(height: 20),
              const Text('色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in FolderStyle.palette) _colorDot(c),
                ],
              ),
              const SizedBox(height: 20),
              const Text('形'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in FolderShape.values) _shapeChoice(s),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _style),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 実際のタイルに近い見た目のプレビュー（図形＋名前の帯）
  Widget _preview() {
    final fg = _style.foreground;
    return SizedBox(
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 96,
            width: 140,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: _style.color,
                shape: _style.shape.border,
              ),
              child: Icon(Icons.folder, size: 48, color: fg),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _style.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.folderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color c) {
    final selected = c == _style.color;
    return Semantics(
      button: true,
      selected: selected,
      label: '色 ${c.toARGB32().toRadixString(16)}',
      child: GestureDetector(
        key: ValueKey('folder_color_${c.toARGB32()}'),
        onTap: () => setState(() => _style = _style.copyWith(color: c)),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              // 背景色に溶けて見えなくならないよう、薄い枠線を常に付ける
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 20, color: readableOn(c))
              : null,
        ),
      ),
    );
  }

  Widget _shapeChoice(FolderShape s) {
    final selected = s == _style.shape;
    return Semantics(
      button: true,
      selected: selected,
      label: '形 ${s.label}',
      child: GestureDetector(
        key: ValueKey('folder_shape_${s.id}'),
        onTap: () => setState(() => _style = _style.copyWith(shape: s)),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: _style.color,
                      shape: s.border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
