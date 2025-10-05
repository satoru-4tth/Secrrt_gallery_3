
// ファイルをタイル表示するウィジェットを定義している
import 'dart:io';
import 'package:flutter/material.dart';

class FileTile extends StatelessWidget {
  const FileTile({super.key, required this.file, required this.onDeleted});
  final File file;
  final Future<void> Function() onDeleted;

  bool get _isVideo {
    final p = file.path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ViewerPage(file: file, isVideo: _isVideo, onDeleted: onDeleted),
      )),
      child: Stack(children: [
        Positioned.fill(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            // ★ ファイル壊れてる場合でもエラーメッセージを出さずに空表示にする
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
        if (_isVideo) const Positioned(right: 4, bottom: 4, child: Icon(Icons.play_circle, size: 20, color: Colors.white)),
      ]),
    );
  }
}

class _ViewerPage extends StatelessWidget {
  const _ViewerPage({required this.file, required this.isVideo, required this.onDeleted});
  final File file;
  final bool isVideo;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return Scaffold(
        appBar: AppBar(actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('削除しますか？'),
                  content: Text(file.path.split('/').last),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
                  ],
                ),
              ) ?? false;
              if (ok) {
                await file.delete();
                await onDeleted();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ]),
        body: Center(child: Image.file(file, fit: BoxFit.contain)),
      );
    }
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('動画: ${file.path.split('/').last}\n（必要なら video_player 連携を追加）', textAlign: TextAlign.center),
      ),
    );
  }
}
