// フォルダをタイル表示するウィジェット
// ・ドラッグ&ドロップ対応（FileTile から落とすと移動）
// ・色と形を変更可能（フォルダ内の .album.meta.json に保存）
// ・フォルダの中の画像を図形の中にプレビュー表示（最大4枚）
// 名前は図形の「外側」の帯に置く。円などの形で文字が切れないようにするため。
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/folder_style.dart';
import '../services/vault_service.dart';
import 'folder_style_sheet.dart';

class FolderTile extends StatefulWidget {
  const FolderTile({
    super.key,
    required this.dir,
    required this.onOpen,
    required this.onDelete,
    this.onExport, // もともとのやつ（未使用でもOK）
    required this.onFileDropped, // ★ 追加：ファイルがドロップされたとき
    this.revision = 0,
    this.vault,
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

  /// 一覧が更新されるたびに増える番号。変わったらプレビューを読み直す。
  final int revision;

  /// テスト用に差し替え可能
  final VaultService? vault;

  @override
  State<FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<FolderTile> {
  late final VaultService _vault = widget.vault ?? VaultService();
  FolderStyle _style = FolderStyle.defaults;
  List<File> _previews = const [];
  int _loadSeq = 0; // 古い読み込み結果で上書きしないための番号

  String get _name => widget.dir.path.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FolderTile old) {
    super.didUpdateWidget(old);
    if (old.dir.path != widget.dir.path || old.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    try {
      final style = await _vault.readFolderStyle(widget.dir);
      final previews = await _vault.previewImages(widget.dir);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _style = style;
        _previews = previews;
      });
    } catch (_) {
      // 読めなくても既定の見た目のまま表示する
    }
  }

  Future<void> _editStyle() async {
    final picked = await showFolderStyleSheet(
      context,
      initial: _style,
      folderName: _name,
    );
    if (picked == null || picked == _style) return;
    try {
      await _vault.setAlbumStyle(widget.dir, picked);
      if (!mounted) return;
      setState(() => _style = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('デザインの保存に失敗しました: $e')));
    }
  }

  Future<void> _confirmDelete() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('フォルダを削除しますか？'),
            content: Text('$_name\n（中身もすべて削除されます）'),
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
    if (ok) await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<File>(
      // ドロップ可能か？ true を返せばハイライトが出る
      onWillAcceptWithDetails: (details) {
        // ここで条件付けも可能（例：同じディレクトリなら拒否など）
        return true;
      },

      // 実際にドロップ（指を離した）とき
      onAcceptWithDetails: (details) async {
        await widget.onFileDropped(details.data, widget.dir);
      },

      builder: (context, candidateData, rejectedData) {
        // candidateData が空でなければ「いま上にドラッグされてる途中」
        final highlighted = candidateData.isNotEmpty;
        final fill = highlighted ? Colors.purple.shade400 : _style.color;

        // 端末の文字サイズ設定が極端でもタイルが崩れないよう上限をかける
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.15,
          child: InkWell(
            onTap: widget.onOpen,
            onLongPress: _editStyle, // 長押しでもデザイン変更
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 図形（色の枠＋中身のプレビュー）
                Expanded(child: _buildShape(fill, highlighted)),
                const SizedBox(height: 4),
                _buildLabel(fill, highlighted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShape(Color fill, bool highlighted) {
    final shape = _style.shape.border.copyWith(
      side: highlighted
          ? const BorderSide(color: Colors.purpleAccent, width: 3)
          : BorderSide.none,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: shape),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: _style.shape.border),
          child: _previews.isEmpty
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.folder,
                        size: 48,
                        color: readableOn(fill),
                      ),
                    ),
                  ),
                )
              : _Collage(files: _previews),
        ),
      ),
    );
  }

  Widget _buildLabel(Color fill, bool highlighted) {
    final fg = readableOn(fill);
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // フォルダ名（長いときは … で省略。色に合わせて文字色を自動選択）
          Expanded(
            child: Tooltip(
              message: _name,
              child: Text(
                _name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: PopupMenuButton<String>(
              tooltip: 'フォルダのメニュー',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, size: 20, color: fg),
              onSelected: (v) {
                if (v == 'style') _editStyle();
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'style', child: Text('色と形を変更')),
                PopupMenuItem(value: 'delete', child: Text('フォルダ削除')),
              ],
            ),
          ),
          // 端末に戻す（いまはUI非表示のまま）
          // if (widget.onExport != null) ...
        ],
      ),
    );
  }
}

/// 画像 1〜4 枚のコラージュ。重い写真でもメモリを使いすぎないよう縮小して読む。
class _Collage extends StatelessWidget {
  const _Collage({required this.files});
  final List<File> files;

  Widget _img(File f) => Image.file(
    f,
    fit: BoxFit.cover,
    cacheWidth: 240,
    gaplessPlayback: true,
    errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
  );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 1, height: 1);
    switch (files.length) {
      case 1:
        return SizedBox.expand(child: _img(files[0]));
      case 2:
        return Row(
          children: [
            Expanded(child: SizedBox.expand(child: _img(files[0]))),
            gap,
            Expanded(child: SizedBox.expand(child: _img(files[1]))),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(child: SizedBox.expand(child: _img(files[0]))),
            gap,
            Expanded(
              child: Column(
                children: [
                  Expanded(child: SizedBox.expand(child: _img(files[1]))),
                  gap,
                  Expanded(child: SizedBox.expand(child: _img(files[2]))),
                ],
              ),
            ),
          ],
        );
      default:
        return Column(
          children: [
            for (var r = 0; r < 2; r++) ...[
              if (r == 1) gap,
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox.expand(child: _img(files[r * 2])),
                    ),
                    gap,
                    Expanded(
                      child: SizedBox.expand(child: _img(files[r * 2 + 1])),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
    }
  }
}
