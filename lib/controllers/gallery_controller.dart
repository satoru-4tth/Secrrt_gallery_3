import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/vault_service.dart';
import 'dart:typed_data';

class GalleryController extends ChangeNotifier {
  GalleryController(this._service);

  final VaultService _service;

  Directory? _root;
  Directory? _current;
  List<Directory> _dirs = [];
  List<File> _files = [];

  Directory? get current => _current;
  List<Directory> get dirs => _dirs;
  List<File> get files => _files;


  Future<void> deleteFolder(Directory dir) async {
    await _service.deleteFolder(dir);
    await refresh();
  }

  Future<void> init() async {
    _root = await _service.ensureVaultRoot();
    _current = _root;
    await refresh();
  }

  Future<void> refresh() async {
    if (_current == null) return;
    final (d, f) = await _service.listEntries(_current!);
    _dirs = d;
    _files = f;
    notifyListeners();
  }

  Future<void> createFolder(BuildContext context) async {
    final name = await _askFolderName(context);
    if (name == null || name.isEmpty) return;
    try {
      await _service.createFolder(_current!, name);
      await refresh();
    } on FileSystemException {
      _toast(context, '同名フォルダが既にあります');
    }
  }

  Future<void> importFromSystem(BuildContext context) async {
    try {
      final assets = await _service.browseRecentAssets();
      if (assets.isEmpty) return;
      final selected = await _openPicker(context, assets);
      if (selected == null || selected.isEmpty) return;

      await _service.importAssets(_current!, selected);

      final delete = await _askDeleteOriginal(context);
      if (delete == true) {
        await _service.deleteOriginals(selected);
      }
      await refresh();
      _toast(context, '取り込みが完了しました');
    } on StateError {
      _toast(context, '写真へのアクセスが許可されていません');
    }
  }

  void goInto(Directory d) {
    _current = d;
    refresh();
  }

  Future<void> goUp() async {
    if (_root == null || _current == null) return;
    if (_current!.path == _root!.path) return;
    _current = _current!.parent;
    await refresh();
  }

  /// root → current の順に Directory を並べて返す
  List<Directory> breadcrumbDirs() {
    if (_root == null || _current == null) return const [];
    final chain = <Directory>[];
    var cur = _current!;
    while (true) {
      chain.add(cur);
      if (_root!.path == cur.path) break;
      cur = cur.parent;
    }
    return chain.reversed.toList(); // root → ... → current
  }

  // ---------- 小さなUIヘルパ（ダイアログ/トースト） ----------
  Future<String?> _askFolderName(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいフォルダ'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'フォルダ名'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('作成')),
        ],
      ),
    );
  }

  Future<List<AssetEntity>?> _openPicker(BuildContext context, List<AssetEntity> assets) {
    return showModalBottomSheet<List<AssetEntity>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssetPickerSheet(assets: assets),
    );
  }

  Future<bool?> _askDeleteOriginal(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('元の写真/動画を削除しますか？'),
        content: const Text('取り込み後に端末の写真から削除します'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('いいえ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除する')),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// 最低限：ここで完結させたいので簡易版のピッカーを内包
class _AssetPickerSheet extends StatefulWidget {
  const _AssetPickerSheet({required this.assets});
  final List<AssetEntity> assets;
  @override
  State<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<_AssetPickerSheet> {
  final _sel = <AssetEntity>{};
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, sc) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12), child: Text('取り込む写真/動画を選択', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: GridView.builder(
                controller: sc, padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemCount: widget.assets.length,
                itemBuilder: (_, i) {
                  final a = widget.assets[i];
                  return FutureBuilder<Uint8List?>(
                    future: a.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                    builder: (_, s) {
                      final th = s.data;
                      final on = _sel.contains(a);
                      return GestureDetector(
                        onTap: () => setState(() => on ? _sel.remove(a) : _sel.add(a)),
                        child: Stack(children: [
                          Positioned.fill(child: th != null ? Image.memory(th, fit: BoxFit.cover) : const ColoredBox(color: Colors.black12)),
                          if (on) const Positioned(right: 4, top: 4, child: Icon(Icons.check_circle, color: Colors.lightBlueAccent)),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _sel.isEmpty ? null : () => Navigator.pop(context, _sel.toList()),
                    child: Text('取り込み (${_sel.length})'))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
