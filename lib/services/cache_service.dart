// アプリ内のキャッシュを削除する
// lib/services/cache_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static Future<void> clearAll() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final tmp = await getTemporaryDirectory();
    await _deleteChildren(tmp);

    // ※ 独自キャッシュディレクトリがあればここで削除追記
    // final support = await getApplicationSupportDirectory();
    // await _deleteChildren(Directory('${support.path}/thumbs'));
  }

  static Future<void> _deleteChildren(Directory dir) async {
    if (!await dir.exists()) return;

    try {
      await for (final e in dir.list(followLinks: false)) {
        try {
          if (e is File) {
            await e.delete();
          } else if (e is Directory) {
            await _deleteChildren(e);
            if (await e.exists()) {
              await e.delete();
            }
          }
        } catch (_) {
          // ロック中・OS管理下は無視
        }
      }
    } catch (_) {
      // list 自体が失敗するケース（今回のエラー）
    }
  }

}
