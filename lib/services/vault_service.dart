//Vault内のファイルやフォルダを管理し、デバイスギャラリーとのデータのやり取りを行うサービスクラス
import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/album_meta.dart';
import 'dart:typed_data';
import 'dart:async';

const _metaFileName = '.album.meta.json';

extension _VaultMeta on Directory {
  File get metaFile => File(p.join(path, _metaFileName));
}

class ExportResult {
  ExportResult({required this.success, required this.fail, required this.errors});
  final int success;
  final int fail;
  final List<String> errors;
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
    f.sort((a, b) =>
        b
            .statSync()
            .modified
            .compareTo(a
            .statSync()
            .modified));
    return (d, f);
  }

  /// フォルダ作成：表示名(displayName)と物理名(folderName)を分けたい場合に対応。
  /// folderName未指定なら displayName を物理名として使う（禁則文字は置換）。
  Future<Directory> createFolder(Directory parent, String displayName,
      {String? folderName}) async {
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
    if (!perm.hasAccess) throw StateError('no-permission'); // or return ExportResult...

    final list = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (list.isEmpty) return [];
    return list.first.getAssetListPaged(page: 0, size: size);
  }

  Future<void> importAssets(Directory target,
      List<AssetEntity> selected) async {
    for (final a in selected) {
      final bytes = await a.originBytes;
      if (bytes == null) continue;
      final ext = _extFromAsset(a, fallback: (await a.file)?.path
          .split('.')
          .last);
      final ts = DateTime
          .now()
          .millisecondsSinceEpoch;
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

  Future<AssetEntity?> _saveImageWithTimeout(
      Uint8List bytes, {
        required String filename,
        required String title,
        required String relativePath,
        Duration timeout = const Duration(seconds: 20),
      }) {
    return PhotoManager.editor
        .saveImage(bytes, filename: filename, title: title, relativePath: relativePath)
        .timeout(timeout);
  }

  Future<AssetEntity?> _saveVideoWithTimeout(
      File file, {
        required String title,
        required String relativePath,
        Duration timeout = const Duration(seconds: 30),
      }) {
    return PhotoManager.editor
        .saveVideo(file, title: title, relativePath: relativePath)
        .timeout(timeout);
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

  // --- 画像/動画を端末ギャラリーへ保存（ファイル配列専用） ---
  Future<ExportResult> exportToDeviceGallery(List<File> files) async {
    // 1) 権限チェック
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) {
      return ExportResult(
          success: 0, fail: files.length, errors: ['権限が許可されていません']);
    }

    int ok = 0,
        ng = 0;
    final errors = <String>[];

    for (final f in files) {
      try {
        final ext = p.extension(f.path).toLowerCase();
        final name = p.basename(f.path);
        final isImage = _isImageExt(ext);
        final isVideo = _isVideoExt(ext);

        if (isImage) {
          // 画像保存
          final bytes = await f.readAsBytes();
          final entity = await _saveImageWithTimeout(
            bytes,
            filename: name,
            title: name,
            relativePath: 'Pictures/SecretGallery',
          );

          if (entity == null) throw Exception('saveImage が null を返しました');
          ok++;
        } else if (isVideo) {
          // 動画保存
          final entity = await _saveVideoWithTimeout(
            f,
            title: name,
            relativePath: 'Movies/SecretGallery',
          );
          if (entity == null) throw Exception('saveVideo が null を返しました');
          ok++;
        } else {
          // 不明拡張子: 画像→動画の順でトライ
          try {
            final bytes = await f.readAsBytes();
            // try: 画像
            final e1 = await _saveImageWithTimeout(
              bytes,
              filename: name,
              title: name,
              relativePath: 'Pictures/SecretGallery',
            );
            if (e1 == null) throw Exception('unknown->saveImage null');
            ok++;
          } catch (_) {
            // catch: 動画
            final e2 = await _saveVideoWithTimeout(
              f,
              title: name,
              relativePath: 'Movies/SecretGallery',
            );
            if (e2 == null) throw Exception('unknown->saveVideo null');
            ok++;
          }
        }
      } catch (e) {
        ng++;
        errors.add('${f.path}: $e');
      }
    }

    // ギャラリー更新を促す（古い端末だと必要）
    await PhotoManager.clearFileCache();

    return ExportResult(success: ok, fail: ng, errors: errors);
  }

  // --- フォルダ（サブフォルダ含む）を書き出し、相対パスを再現 ---
  Future<ExportResult> exportDirectoryToDeviceGallery(Directory targetDir,
      {bool recursive = true}) async {
    final root = await ensureVaultRoot();

    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) {
      final count = await _countFiles(targetDir, recursive: recursive);
      return ExportResult(
          success: 0, fail: count, errors: ['権限が許可されていません']);
    }

    int ok = 0,
        ng = 0;
    final errors = <String>[];

    await for (final e in targetDir.list(
        recursive: recursive, followLinks: false)) {
      if (e is! File) continue;
      if (_shouldSkip(e)) continue; // メタ/隠しファイル除外

      final rel = p.relative(e.path, from: root.path); // vaultからの相対
      final dirOnly = p.dirname(rel); // 例: Trip/Day1
      final baseName = p.basename(e.path);
      final ext = p.extension(e.path).toLowerCase();

      try {
        if (_isImageExt(ext)) {
          final bytes = await e.readAsBytes();
          final relPath = (dirOnly == '.' || dirOnly.isEmpty)
              ? 'Pictures/SecretGallery'
              : 'Pictures/SecretGallery/$dirOnly';
          // 画像
          final saved = await _saveImageWithTimeout(
            bytes,
            filename: baseName,
            title: baseName,
            relativePath: relPath,
          );
          if (saved == null) throw Exception('saveImage null');
          ok++;
        } else if (_isVideoExt(ext)) {
          final relPath = (dirOnly == '.' || dirOnly.isEmpty)
              ? 'Movies/SecretGallery'
              : 'Movies/SecretGallery/$dirOnly';
          final saved = await _saveVideoWithTimeout(
            e,
            title: baseName,
            relativePath: relPath,
          );
          if (saved == null) throw Exception('saveVideo null');
          ok++;
        } else {
          // 不明拡張子: 画像→動画の順でトライ
          try {
            final bytes = await e.readAsBytes();
            final relPath = (dirOnly == '.' || dirOnly.isEmpty)
                ? 'Pictures/SecretGallery'
                : 'Pictures/SecretGallery/$dirOnly';
            // try: 画像
            final saved = await _saveImageWithTimeout(
            bytes,
            filename: baseName,
            title: baseName,
            relativePath: relPath,
            );
            if (saved == null) throw Exception('unknown->saveImage null');
            ok++;
          } catch (_) {
            final relPath = (dirOnly == '.' || dirOnly.isEmpty)
                ? 'Movies/SecretGallery'
                : 'Movies/SecretGallery/$dirOnly';
            // catch: 動画
            final saved = await _saveVideoWithTimeout(
            e,
            title: baseName,
            relativePath: relPath,
            );
            if (saved == null) throw Exception('unknown->saveVideo null');
            ok++;
          }
        }
      } catch (err) {
        ng++;
        errors.add('${e.path}: $err');
      }
    }

    await PhotoManager.clearFileCache();
    return ExportResult(success: ok, fail: ng, errors: errors);
  }

// --- helpers（VaultServiceクラス内に置く） ---
  bool _isImageExt(String ext) =>
      {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'}.contains(ext);

  bool _isVideoExt(String ext) =>
      {'.mp4', '.mov', '.m4v', '.avi', '.webm'}.contains(ext);

  bool _shouldSkip(File f) {
    final name = p.basename(f.path);
    if (name == _metaFileName) return true; // メタJSON除外
    if (name.startsWith('.')) return true; // 隠し/OSゴミ(.DS_Store等)
    return false;
  }

  Future<int> _countFiles(Directory dir, {bool recursive = true}) async {
    int c = 0;
    await for (final e in dir.list(recursive: recursive, followLinks: false)) {
      if (e is File && !_shouldSkip(e)) c++;
    }
    return c;
  }
}