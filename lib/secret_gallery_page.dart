import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// 秘密ギャラリー
/// - /Documents/vault を“ルート”にして、その配下にフォルダも作れる
/// - フォルダ/ファイルのグリッド表示、パンくず移動
/// - 取り込み先は「いま開いているフォルダ」
class SecretGalleryPage extends StatefulWidget {
  const SecretGalleryPage({super.key});
  @override
  State<SecretGalleryPage> createState() => _SecretGalleryPageState();
}

class _SecretGalleryPageState extends State<SecretGalleryPage> {
  late Future<Directory> _vaultRootF;
  Directory? _currentDir; // いま表示中のディレクトリ
  List<Directory> _dirs = [];
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _vaultRootF = _ensureVaultRoot();
    _initCurrent();
  }

  Future<void> _initCurrent() async {
    final root = await _vaultRootF;
    setState(() => _currentDir = root);
    await _refresh();
  }

  Future<Directory> _ensureVaultRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _refresh() async {
    final dir = _currentDir;
    if (dir == null) return;

    final entries = dir.listSync();
    final d = <Directory>[];
    final f = <File>[];
    for (final e in entries) {
      if (e is Directory) d.add(e);
      if (e is File) f.add(e);
    }
    d.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    f.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() {
      _dirs = d;
      _files = f;
    });
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('新しいフォルダ'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'フォルダ名'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('作成')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final safe = name.replaceAll(RegExp(r'[\\/:*?\"<>|]'), '_');
    final newDir = Directory('${_currentDir!.path}/$safe');
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
      await _refresh();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同名フォルダが既にあります')),
        );
      }
    }
  }

  Future<void> _importFromSystem() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真へのアクセスが許可されていません')),
        );
      }
      return;
    }

    final pathList = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (pathList.isEmpty) return;

    final recent = pathList.first;
    final assets = await recent.getAssetListPaged(page: 0, size: 200);

    final selected = await showModalBottomSheet<List<AssetEntity>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssetPickerSheet(assets: assets),
    );
    if (selected == null || selected.isEmpty) return;

    final dir = _currentDir ?? await _vaultRootF;

    for (final asset in selected) {
      final file = await asset.file;
      final bytes = await asset.originBytes;
      if (bytes == null) continue;

      final ext = _extFromAsset(asset, fallback: file?.path.split('.').last);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final name = 'vault_${ts}_${asset.id}.$ext';
      final out = File('${dir.path}/$name');
      await out.writeAsBytes(bytes, flush: true);

      final ok = await _confirmDeleteOriginal(asset);
      if (ok) {
        try { await PhotoManager.editor.deleteWithIds([asset.id]); } catch (_) {}
      }
    }

    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取り込みが完了しました')),
      );
    }
  }

  String _extFromAsset(AssetEntity a, {String? fallback}) {
    final m = a.mimeType?.toLowerCase() ?? '';
    if (m.contains('jpeg')) return 'jpg';
    if (m.contains('png')) return 'png';
    if (m.contains('heic')) return 'heic';
    if (m.contains('webp')) return 'webp';
    if (m.contains('gif')) return 'gif';
    if (m.contains('mp4')) return 'mp4';
    if (m.contains('quicktime') || m.contains('mov')) return 'mov';
    return (fallback != null && fallback.isNotEmpty) ? fallback : 'bin';
  }

  Future<bool> _confirmDeleteOriginal(AssetEntity asset) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('元の写真/動画を削除しますか？'),
        content: Text('タイトル: ${asset.title ?? '(不明)'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('いいえ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除する')),
        ],
      ),
    ) ??
        false;
  }

  void _goInto(Directory d) {
    setState(() => _currentDir = d);
    _refresh();
  }

  Future<void> _goUp() async {
    final root = await _vaultRootF;
    final cur = _currentDir;
    if (cur == null) return;
    if (cur.path == root.path) return; // already at root
    setState(() => _currentDir = cur.parent);
    await _refresh();
  }

  List<Directory> _breadcrumb() {
    final cur = _currentDir;
    if (cur == null) return [];
    final parts = <Directory>[];
    Directory? it = cur;
    while (true) {
      parts.insert(0, it!);
      final parent = it.parent;
      if (parent.path == it.path) break; // safety
      it = parent;
      if (it.path.endsWith('/Documents') || it.path.endsWith('Documents')) break; // 上の階層で打ち切り
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final cur = _currentDir;
    final crumbs = _breadcrumb();

    return Scaffold(
      appBar: AppBar(
        title: const Text('秘密ギャラリー'),
        actions: [
          IconButton(
            onPressed: _importFromSystem,
            icon: const Icon(Icons.download),
            tooltip: '取り込み（現在のフォルダ）',
          ),
          IconButton(
            onPressed: _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'フォルダ作成',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                FilledButton.tonal(
                  onPressed: _goUp,
                  child: const Row(children: [Icon(Icons.arrow_upward, size: 16), SizedBox(width: 4), Text('上へ')]),
                ),
                const SizedBox(width: 8),
                ...List.generate(crumbs.length, (i) {
                  final d = crumbs[i];
                  final isLast = i == crumbs.length - 1;
                  final label = d.path.split(Platform.pathSeparator).last.isEmpty
                      ? 'root'
                      : d.path.split(Platform.pathSeparator).last;
                  return Row(children: [
                    ActionChip(
                      label: Text(label),
                      onPressed: isLast ? null : () => _goInto(d),
                    ),
                    const Icon(Icons.chevron_right, size: 16),
                  ]);
                }),
              ],
            ),
          ),
        ),
      ),
      body: cur == null
          ? const Center(child: CircularProgressIndicator())
          : (_dirs.isEmpty && _files.isEmpty)
          ? const Center(child: Text('このフォルダは空です'))
          : GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
        ),
        itemCount: _dirs.length + _files.length,
        itemBuilder: (ctx, i) {
          if (i < _dirs.length) {
            final d = _dirs[i];
            final name = d.path.split(Platform.pathSeparator).last;
            return _FolderTile(
              name: name,
              onOpen: () => _goInto(d),
              onDelete: () async {
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
                ) ??
                    false;
                if (ok) {
                  await d.delete(recursive: true);
                  await _refresh();
                }
              },
            );
          }
          final f = _files[i - _dirs.length];
          final isVideo = f.path.toLowerCase().endsWith('.mp4') || f.path.toLowerCase().endsWith('.mov');
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ViewerPage(file: f, isVideo: isVideo, onDeleted: _refresh),
            )),
            child: Stack(children: [
              Positioned.fill(child: Image.file(f, fit: BoxFit.cover)),
              if (isVideo)
                const Positioned(
                  right: 4, bottom: 4,
                  child: Icon(Icons.play_circle, size: 20, color: Colors.white),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.name, required this.onOpen, required this.onDelete});
  final String name;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: Icon(Icons.folder, size: 48),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'フォルダ削除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetPickerSheet extends StatefulWidget {
  const _AssetPickerSheet({required this.assets});
  final List<AssetEntity> assets;

  @override
  State<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<_AssetPickerSheet> {
  final _selected = <AssetEntity>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('取り込む写真/動画を選択', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6,
                ),
                itemCount: widget.assets.length,
                itemBuilder: (_, i) {
                  final a = widget.assets[i];
                  return FutureBuilder<Uint8List?>
                    (future: a.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                    builder: (_, snap) {
                      final th = snap.data;
                      final selected = _selected.contains(a);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) { _selected.remove(a); } else { _selected.add(a); }
                          });
                        },
                        child: Stack(children: [
                          Positioned.fill(
                            child: th != null
                                ? Image.memory(th, fit: BoxFit.cover)
                                : const ColoredBox(color: Colors.black12),
                          ),
                          if (selected)
                            const Positioned(
                              right: 4, top: 4,
                              child: Icon(Icons.check_circle, color: Colors.lightBlueAccent),
                            ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                    child: Text('取り込み (${_selected.length})'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
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
              ) ??
                  false;
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