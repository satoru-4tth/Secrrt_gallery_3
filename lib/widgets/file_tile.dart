// ファイルをタイル表示するウィジェット（画像＆動画サムネ対応 / 再生ビューあり / ★ドラッグ対応）
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FileTile extends StatefulWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.onDeleted,
  });

  // このFileをドラッグで他フォルダへ移動したいので、
  // 後でDragTarget側（フォルダ側）がこのFileを受け取れるようにする
  final File file;

  // 画像・動画を削除した後に一覧を更新するためのコールバック
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
    // 画像/動画サムネ本体
    final previewChild = _isVideo
        ? (_thumb != null
        ? Image.memory(_thumb!, fit: BoxFit.cover)
        : const ColoredBox(color: Colors.black26))
        : Image.file(
      widget.file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    // ────────────────────────────────
    // ここが重要：
    // 元は GestureDetector(... child: Stack(...)) でしたが、
    // それを LongPressDraggable<File> でラップします。
    //
    // ・data: widget.file で、このタイルが持つFileをドラッグ情報として渡す
    // ・feedback: ドラッグ中に指の下に出るプレビュー
    // ・child:    もともとのタイル表示
    // ・childWhenDragging: ドラッグ中は元の場所を半透明表示
    // ────────────────────────────────
    return LongPressDraggable<File>(
      data: widget.file,

     // Offsetで値が変わらないため↓の常に指の位置に固定する設定をコメントアウトする
     // dragAnchorStrategy: pointerDragAnchorStrategy,

      // ドラッグ中のファイルの位置
      feedbackOffset: const Offset(-20, -20),

      // 指についてくる見た目（ドラッグ中のプレビュー）
      feedback: _buildDragFeedback(previewChild),

      // ドラッグ中に元の場所へ残す見た目（薄くする等）
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTapArea(previewChild),
      ),

      // 通常表示（タップでビューアを開く挙動は今までどおり維持）
      child: _buildTapArea(previewChild),
    );
  }

  // タップで画像/動画ビューアを開く領域
  Widget _buildTapArea(Widget previewChild) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _ViewerPage(
            file: widget.file,
            isVideo: _isVideo,
            onDeleted: widget.onDeleted,
          ),
        ));
      },
      child: Stack(
        children: [
          // サムネ全体
          Positioned.fill(child: previewChild),

          // 動画アイコン
          if (_isVideo)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(
                Icons.play_circle,
                size: 22,
                color: Colors.white,
              ),
            ),

          // 右上にドラッグできそうなハンドルを少し出しても良い（UIヒント）
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.drag_indicator,
                size: 16,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ドラッグ中カーソル下に表示される仮のプレビュー
  Widget _buildDragFeedback(Widget previewChild) {
    return Opacity(
      opacity: 0.8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purpleAccent, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: previewChild),
              if (_isVideo)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(
                    Icons.play_circle,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== ここから詳細ビュー（画像/動画閲覧画面） =====

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

  // ▼ シークバー用の一時状態
  bool _dragging = false;
  double? _dragValueMs;
  bool _wasPlaying = false;

  Duration get _duration {
    if (_controller == null) return Duration.zero;
    final d = _controller!.value.duration;
    return d == Duration.zero ? const Duration(milliseconds: 1) : d;
  }

  Duration get _position => _controller?.value.position ?? Duration.zero;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.file(widget.file)
        ..addListener(() {
          if (mounted && !_dragging) {
            setState(() {}); // シーク位置や再生状態を更新
          }
        })
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
        content: Text(
          widget.file.path.split(Platform.pathSeparator).last,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('削除'),
          ),
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

    // 画像の場合
    if (!widget.isVideo) {
      return Scaffold(
        appBar: AppBar(actions: actions),
        body: Center(
          child: Image.file(
            widget.file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
            const Text('画像を表示できません'),
          ),
        ),
      );
    }

    // 動画の場合
    final initialized = _ready && _controller != null;
    final totalMs = _duration.inMilliseconds.toDouble();
    final currentMs = (_dragging && _dragValueMs != null)
        ? _dragValueMs!.clamp(0, totalMs)
        : _position.inMilliseconds
        .toDouble()
        .clamp(0, totalMs);

    return Scaffold(
      appBar: AppBar(actions: actions),
      body: initialized
          ? Column(
        children: [
          // 動画表示
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio == 0
                ? 16 / 9
                : _controller!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),

                // タップで再生/停止
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final playing =
                            _controller!.value.isPlaying;
                        playing
                            ? _controller!.pause()
                            : _controller!.play();
                        setState(() {});
                      },
                    ),
                  ),
                ),

                // 再生/一時停止アイコン
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _controller!.value.isPlaying
                        ? 0.0
                        : 1.0,
                    duration:
                    const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.play_circle_outline,
                      size: 84,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // シークバー + 時刻表示
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  _fmt(Duration(
                      milliseconds: currentMs.round())),
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: totalMs,
                    value: currentMs.isNaN
                        ? 0.0
                        : currentMs.toDouble(),
                    onChangeStart: (_) {
                      _dragging = true;
                      _wasPlaying =
                          _controller!.value.isPlaying;
                      _controller!.pause();
                    },
                    onChanged: (v) {
                      setState(() => _dragValueMs = v);
                    },
                    onChangeEnd: (v) async {
                      _dragging = false;
                      _dragValueMs = null;
                      await _controller!.seekTo(Duration(
                          milliseconds: v.round()));
                      if (_wasPlaying) {
                        _controller!.play();
                      }
                      setState(() {});
                    },
                  ),
                ),
                Text(_fmt(_duration)),
              ],
            ),
          ),

          //10秒巻き戻し / 再生 / 10秒送り
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () async {
                  final target =
                      _position - const Duration(seconds: 10);
                  await _controller!.seekTo(
                    target < Duration.zero
                        ? Duration.zero
                        : target,
                  );
                  setState(() {});
                },
              ),
              IconButton(
                icon: Icon(
                  _controller!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: () async {
                  final playing =
                      _controller!.value.isPlaying;
                  if (playing) {
                    await _controller!.pause();
                  } else {
                    await _controller!.play();
                  }
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () async {
                  final target =
                      _position + const Duration(seconds: 10);
                  await _controller!.seekTo(
                    target > _duration
                        ? _duration
                        : target,
                  );
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
