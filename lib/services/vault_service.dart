import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/album_meta.dart';

const _metaFileName = '.album.meta.json';

extension _VaultMeta on Directory {
  File get metaFile => File(p.join(path, _metaFileName));
}

class VaultService {
  Future<Directory> ensureVaultRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    // ルートにもメタを作っておく（初回のみ）
    await readOrCreateMeta(dir);
    return dir;
  }

  Future<(List<Directory>, List<File>)> listEntries(Directory dir) async {
    final d = <Directory>[];
    final f = <File>[];
    for (final e in dir.listSync()) {
      if (e is Directory) d.add(e);
      if (e is File) f.add(e);
    }
    // フォルダは名前昇順、ファイルは更新日降順（お好みで）
    d.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    f.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return (d, f);
  }

  /// フォルダ作成：表示名(displayName)と物理名(folderName)を分けたい場合に対応。
  /// folderName未指定なら displayName を物理名として使う（禁則文字は置換）。
  Future<Directory> createFolder(Directory parent, String displayName, {String? folderName}) async {
    final phys = (folderName ?? displayName)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    if (phys.isEmpty) {
      throw const FileSystemException('Invalid folder name');
    }
    final newDir = Directory(p.join(parent.path, phys));
    if (await newDir.exists()) {
      throw const FileSystemException('Folder already exists');
    }
    await newDir.create(recursive: true);
    // ★ 作成と同時にメタ作成（論理名=displayName）
    await writeMeta(newDir, AlbumMeta.initial(displayName));
    return newDir;
  }

  Future<void> deleteFolder(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<List<AssetEntity>> browseRecentAssets({int size = 200}) async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) throw StateError('no-permission');
    final list = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (list.isEmpty) return [];
    return list.first.getAssetListPaged(page: 0, size: size);
  }

  Future<void> importAssets(Directory target, List<AssetEntity> selected) async {
    for (final a in selected) {
      final bytes = await a.originBytes;
      if (bytes == null) continue;
      final ext = _extFromAsset(a, fallback: (await a.file)?.path.split('.').last);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final name = 'vault_${ts}_${a.id}.$ext';
      final out = File(p.join(target.path, name));
      await out.writeAsBytes(bytes, flush: true);
    }
    // 取り込み先のメタ更新（更新日を今に）
    final meta = await readOrCreateMeta(target);
    await writeMeta(target, meta.copyWith(name: meta.name));
  }

  Future<void> deleteOriginals(List<AssetEntity> selected) async {
    try {
      await PhotoManager.editor.deleteWithIds(
        selected.map((e) => e.id).toList(),
      );
    } catch (_) {
      // 端末/OSによってはゴミ箱行きなどの差異あり。失敗は握りつぶす。
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

  // ===== ここからメタ（論理名）関連 =====

  Future<AlbumMeta> readOrCreateMeta(Directory dir) async {
    final mf = dir.metaFile;
    if (await mf.exists()) {
      final txt = await mf.readAsString();
      return AlbumMeta.fromJson(jsonDecode(txt) as Map<String, dynamic>);
    } else {
      final defaultName = p.basename(dir.path); // 既定は物理フォルダ名
      final meta = AlbumMeta.initial(defaultName);
      await mf.writeAsString(jsonEncode(meta.toJson()));
      return meta;
    }
  }

  Future<void> writeMeta(Directory dir, AlbumMeta meta) async {
    await dir.metaFile.writeAsString(jsonEncode(meta.toJson()));
  }

  /// 既存フォルダの論理名だけ変えたいとき
  Future<void> renameAlbum(Directory dir, String newDisplayName) async {
    final current = await readOrCreateMeta(dir);
    await writeMeta(dir, current.copyWith(name: newDisplayName));
  }
}
