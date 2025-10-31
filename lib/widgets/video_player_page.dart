// lib/pages/video_player_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SimpleVideoPlayerPage extends StatefulWidget {
  const SimpleVideoPlayerPage({super.key, required this.file});
  final File file;

  @override
  State<SimpleVideoPlayerPage> createState() => _SimpleVideoPlayerPageState();
}

class _SimpleVideoPlayerPageState extends State<SimpleVideoPlayerPage> {
  late final VideoPlayerController _vc;
  bool _ready = false;

  // シーク用の状態
  bool _dragging = false;
  double? _dragValueMs;
  bool _wasPlaying = false;

  // 倍速候補と現在の速度
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _speed = 1.0;

  Future<void> _setSpeed(double s) async {
    _speed = s;
    await _vc.setPlaybackSpeed(s);
    if (mounted) setState(() {});
  }

  Duration get _duration {
    final d = _vc.value.duration;
    return d == Duration.zero ? const Duration(milliseconds: 1) : d;
  }

  Duration get _position => _vc.value.position;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _vc = VideoPlayerController.file(widget.file)
      ..addListener(() {
        if (mounted && !_dragging) setState(() {});
      })
      ..initialize().then((_) async {
        if (!mounted) return;
        await _vc.setPlaybackSpeed(_speed); // 初期速度を適用
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _ready && _vc.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PLAYER(SG)'),
        actions: [
          if (initialized)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<double>(
                onSelected: _setSpeed,
                itemBuilder: (context) => _speeds.map((s) {
                  final selected = (_vc.value.playbackSpeed - s).abs() < 0.001;
                  return PopupMenuItem<double>(
                    value: s,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${s}x'),
                        if (selected) const Icon(Icons.check, size: 18),
                      ],
                    ),
                  );
                }).toList(),
                child: Tooltip(
                  message: '再生速度を変更',
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_vc.value.playbackSpeed.toStringAsFixed(2)}x'),
                  ),
                ),
              ),
            ),
        ],
      ),

      body: initialized
          ? SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const controlsHeight = 120.0; // 下部コントロールの想定高さ
            final playerHeight =
            (constraints.maxHeight - controlsHeight).clamp(100.0, constraints.maxHeight);

            final totalMs = _duration.inMilliseconds.toDouble();
            final currentMs = (_dragging && _dragValueMs != null)
                ? _dragValueMs!.clamp(0, totalMs)
                : _position.inMilliseconds.toDouble().clamp(0, totalMs);

            return Column(
              children: [
                // ① プレイヤー領域
                SizedBox(
                  height: playerHeight,
                  width: double.infinity,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio:
                      (_vc.value.aspectRatio > 0) ? _vc.value.aspectRatio : 16 / 9,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_vc),
                          // タップで再生/一時停止
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  if (_vc.value.isPlaying) {
                                    await _vc.pause();
                                  } else {
                                    await _vc.play();
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          // 停止中アイコン
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: _vc.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 150),
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
                  ),
                ),

                // ② コントロール群
                SizedBox(
                  height: controlsHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // シークバー＋時間
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Text(_fmt(Duration(milliseconds: currentMs.round()))),
                            Expanded(
                              child: Slider(
                                min: 0.0,
                                max: totalMs,
                                value: currentMs.isNaN ? 0.0 : currentMs.toDouble(),
                                onChangeStart: (_) {
                                  _dragging = true;
                                  _wasPlaying = _vc.value.isPlaying;
                                  _vc.pause();
                                },
                                onChanged: (v) => setState(() => _dragValueMs = v),
                                onChangeEnd: (v) async {
                                  _dragging = false;
                                  _dragValueMs = null;
                                  await _vc.seekTo(Duration(milliseconds: v.round()));
                                  if (_wasPlaying) await _vc.play();
                                  setState(() {});
                                },
                              ),
                            ),
                            Text(_fmt(_duration)),
                          ],
                        ),
                      ),

                      // ±10秒 と 再生/一時停止 + 倍速
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              onPressed: () async {
                                final target =
                                    _position - const Duration(seconds: 10);
                                await _vc.seekTo(
                                  target < Duration.zero ? Duration.zero : target,
                                );
                                setState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _vc.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              onPressed: () async {
                                if (_vc.value.isPlaying) {
                                  await _vc.pause();
                                } else {
                                  await _vc.play();
                                }
                                setState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              onPressed: () async {
                                final target =
                                    _position + const Duration(seconds: 10);
                                await _vc.seekTo(
                                  target > _duration ? _duration : target,
                                );
                                setState(() {});
                              },
                            ),

                            const SizedBox(width: 8),
                            PopupMenuButton<double>(
                              onSelected: _setSpeed,
                              itemBuilder: (context) => _speeds.map((s) {
                                final selected =
                                    (_vc.value.playbackSpeed - s).abs() < 0.001;
                                return PopupMenuItem<double>(
                                  value: s,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${s}x'),
                                      if (selected)
                                        const Icon(Icons.check, size: 18),
                                    ],
                                  ),
                                );
                              }).toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_vc.value.playbackSpeed.toStringAsFixed(2)}x',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
