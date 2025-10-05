// ファイルをタイル表示するウィジェット（画像＆動画サムネ対応 / 再生ビューあり）
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FileTile extends StatefulWidget {
  const FileTile({super.key, required this.file, required this.onDeleted});
  final File file;
  final Future<void> Function() onDeleted;

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  Uint8List? _thumb;

  bool get _isVideo {
    final p = widget.file.path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm') ||
        p.endsWith('.avi');
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) _loadThumb();
  }

  Future<void> _loadThumb() async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300, // タイル表示に十分
        quality: 60,
      );
      if (!mounted) return;
      setState(() => _thumb = data);
    } catch (_) {
      // 壊れた動画などはサムネ生成失敗→nullのまま
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _isVideo
        ? (_thumb != null
        ? Image.memory(_thumb!, fit: BoxFit.cover)
        : const ColoredBox(color: Colors.black26))
        : Image.file(
      widget.file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ViewerPage(
          file: widget.file,
          isVideo: _isVideo,
          onDeleted: widget.onDeleted,
        ),
      )),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (_isVideo)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(Icons.play_circle, size: 22, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// ===== ここから詳細ビュー =====

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({
    required this.file,
    required this.isVideo,
    required this.onDeleted,
  });

  final File file;
  final bool isVideo;
  final Future<void> Function() onDeleted;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text(widget.file.path.split(Platform.pathSeparator).last),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
        ],
      ),
    ) ??
        false;
    if (!ok) return;

    try {
      await widget.file.delete();
      await widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      IconButton(icon: const Icon(Icons.delete), onPressed: _confirmDelete),
    ];

    if (!widget.isVideo) {
      // 画像表示
      return Scaffold(
        appBar: AppBar(actions: actions),
        body: Center(
          child: Image.file(widget.file, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('画像を表示できません')),
        ),
      );
    }

    // 動画表示
    return Scaffold(
      appBar: AppBar(actions: actions),
      body: Center(
        child: _ready
            ? AspectRatio(
          aspectRatio: _controller!.value.aspectRatio == 0
              ? 16 / 9
              : _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              // タップで再生/一時停止
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final playing = _controller!.value.isPlaying;
                      playing ? _controller!.pause() : _controller!.play();
                      setState(() {});
                    },
                  ),
                ),
              ),
              // 再生/一時停止アイコンを中央に
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.play_circle_outline, size: 84, color: Colors.white70),
                ),
              ),
            ],
          ),
        )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: widget.isVideo && _ready
          ? FloatingActionButton(
        onPressed: () {
          final playing = _controller!.value.isPlaying;
          playing ? _controller!.pause() : _controller!.play();
          setState(() {});
        },
        child: Icon(
          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      )
          : null,
    );
  }
}
