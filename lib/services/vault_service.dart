import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class VaultService {
  Future<Directory> ensureVaultRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<(List<Directory>, List<File>)> listEntries(Directory dir) async {
    final d = <Directory>[];
    final f = <File>[];
    for (final e in dir.listSync()) {
      if (e is Directory) d.add(e);
      if (e is File) f.add(e);
    }
    d.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    f.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return (d, f);
  }

  Future<Directory> createFolder(Directory parent, String name) async {
    final safe = name.replaceAll(RegExp(r'[\\/:*?\"<>|]'), '_').trim();
    final newDir = Directory('${parent.path}/$safe');
    if (!await newDir.exists()) {
      return newDir..createSync(recursive: true);
    }
    throw const FileSystemException('Folder already exists');
  }

  Future<void> deleteFolder(Directory dir) async {
    await dir.delete(recursive: true);
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
      final out = File('${target.path}/$name');
      await out.writeAsBytes(bytes, flush: true);
    }
  }

  Future<void> deleteOriginals(List<AssetEntity> selected) async {
    try {
      await PhotoManager.editor.deleteWithIds(selected.map((e) => e.id).toList());
    } catch (_) {/* 無視 */}
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
}
