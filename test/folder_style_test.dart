import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_gallery_3/models/album_meta.dart';
import 'package:secret_gallery_3/models/folder_style.dart';
import 'package:secret_gallery_3/services/vault_service.dart';

// 1x1 の有効な PNG
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  group('文字の読みやすさ', () {
    test('選べる色すべてで、文字色とのコントラストが 4.5:1 以上', () {
      for (final c in FolderStyle.palette) {
        expect(contrastRatio(c, readableOn(c)), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });

    test('どんな色でも（色相×明度×彩度の総当たり）4.5:1 以上', () {
      for (var h = 0; h < 360; h += 15) {
        for (var s = 0.0; s <= 1.0; s += 0.25) {
          for (var l = 0.0; l <= 1.0; l += 0.05) {
            final c = HSLColor.fromAHSL(1, h.toDouble(), s, l).toColor();
            expect(
              contrastRatio(c, readableOn(c)),
              greaterThanOrEqualTo(4.5),
              reason: 'h=$h s=$s l=$l',
            );
          }
        }
      }
    });

    test('明るい色には暗い文字、暗い色には明るい文字', () {
      expect(readableOn(const Color(0xFFF5F5F5)).computeLuminance(), lessThan(0.1));
      expect(readableOn(const Color(0xFF212121)).computeLuminance(), greaterThan(0.9));
      expect(readableOn(const Color(0xFFFFEE58)).computeLuminance(), lessThan(0.1));
    });
  });

  group('FolderShape / FolderStyle', () {
    test('id は重複せず、未知の id は角丸に戻る', () {
      final ids = FolderShape.values.map((s) => s.id).toSet();
      expect(ids.length, FolderShape.values.length);
      expect(FolderShape.fromId('nope'), FolderShape.rounded);
      expect(FolderShape.fromId(null), FolderShape.rounded);
      for (final s in FolderShape.values) {
        expect(FolderShape.fromId(s.id), s);
      }
    });

    test('既定は従来の見た目（青・角丸）', () {
      expect(FolderStyle.defaults.color, Colors.blue.shade300);
      expect(FolderStyle.defaults.shape, FolderShape.rounded);
    });

    test('パレットに重複が無く、既定色を含む', () {
      expect(FolderStyle.palette.toSet().length, FolderStyle.palette.length);
      expect(FolderStyle.palette, contains(FolderStyle.defaultColor));
    });
  });

  group('AlbumMeta', () {
    test('色・形が無い古いファイルも読める（既定扱い）', () {
      final m = AlbumMeta.fromJson({
        'name': '旅行',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-01-02T00:00:00.000',
      });
      expect(m.name, '旅行');
      expect(m.colorValue, isNull);
      expect(m.shape, isNull);
    });

    test('未設定なら JSON に色・形を書かない（古い版と互換）', () {
      final j = AlbumMeta.initial('a').toJson();
      expect(j.containsKey('color'), isFalse);
      expect(j.containsKey('shape'), isFalse);
    });

    test('往復で色・形が保たれる', () {
      final m = AlbumMeta.initial('a').copyWith(colorValue: 0xFFEF5350, shape: 'circle');
      final back = AlbumMeta.fromJson(jsonDecode(jsonEncode(m.toJson())));
      expect(back.colorValue, 0xFFEF5350);
      expect(back.shape, 'circle');
    });

    test('copyWith(name:) だけでも色・形が消えない（取り込み時のメタ更新）', () {
      final m = AlbumMeta.initial('a').copyWith(colorValue: 0xFF66BB6A, shape: 'beveled');
      final renamed = m.copyWith(name: 'b');
      expect(renamed.colorValue, 0xFF66BB6A);
      expect(renamed.shape, 'beveled');
      expect(renamed.createdAt, m.createdAt);
    });

    test('型が壊れていても例外にならず既定扱い', () {
      final m = AlbumMeta.fromJson({'name': 'x', 'color': 'red', 'shape': 5});
      expect(m.colorValue, isNull);
      expect(m.shape, isNull);
    });
  });

  group('VaultService（色・形・プレビュー）', () {
    late Directory tmp;
    final vault = VaultService();

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('folder_style_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<File> img(Directory d, String name, {DateTime? modified, List<int>? bytes}) async {
      final f = File('${d.path}/$name');
      await f.writeAsBytes(bytes ?? _png);
      if (modified != null) await f.setLastModified(modified);
      return f;
    }

    test('メタが無いフォルダは既定の見た目で、読むだけではファイルを作らない', () async {
      final st = await vault.readFolderStyle(tmp);
      expect(st, FolderStyle.defaults);
      expect(File('${tmp.path}/.album.meta.json').existsSync(), isFalse);
    });

    test('メタが壊れていても既定の見た目になる', () async {
      await File('${tmp.path}/.album.meta.json').writeAsString('{ broken');
      expect(await vault.readFolderStyle(tmp), FolderStyle.defaults);
    });

    test('未知の形は角丸、色が無ければ既定色', () async {
      await File('${tmp.path}/.album.meta.json').writeAsString(jsonEncode({'name': 'x', 'shape': 'star'}));
      final st = await vault.readFolderStyle(tmp);
      expect(st.shape, FolderShape.rounded);
      expect(st.color, FolderStyle.defaultColor);
    });

    test('保存した色・形を読み戻せる', () async {
      const s = FolderStyle(color: Color(0xFFAB47BC), shape: FolderShape.circle);
      await vault.setAlbumStyle(tmp, s);
      expect(await vault.readFolderStyle(tmp), s);
    });

    test('保存しても名前（日本語・絵文字）と作成日は変わらない', () async {
      final created = DateTime(2025, 1, 1);
      final meta = AlbumMeta(
        name: '旅行📷「春」',
        createdAt: created,
        updatedAt: created,
      );
      await vault.writeMeta(tmp, meta);
      await vault.setAlbumStyle(
        tmp,
        const FolderStyle(color: Color(0xFFEF5350), shape: FolderShape.squircle),
      );
      final raw = jsonDecode(await File('${tmp.path}/.album.meta.json').readAsString());
      expect(raw['name'], '旅行📷「春」');
      expect(raw['createdAt'], created.toIso8601String());
      expect(raw['shape'], 'squircle');
    });

    test('保存後に一時ファイルが残らない', () async {
      await vault.setAlbumStyle(tmp, FolderStyle.defaults);
      await vault.setAlbumStyle(tmp, FolderStyle.defaults.copyWith(shape: FolderShape.square));
      final names = tmp.listSync().map((e) => e.path.split('/').last).toList();
      expect(names, ['.album.meta.json']);
    });

    test('壊れたメタの上からでも保存できる', () async {
      await File('${tmp.path}/.album.meta.json').writeAsString('not json');
      await vault.setAlbumStyle(tmp, FolderStyle.defaults.copyWith(shape: FolderShape.beveled));
      expect((await vault.readFolderStyle(tmp)).shape, FolderShape.beveled);
    });

    test('プレビュー：新しい順に最大4枚', () async {
      final base = DateTime(2025, 1, 1);
      for (var i = 0; i < 6; i++) {
        await img(tmp, 'p$i.jpg', modified: base.add(Duration(days: i)));
      }
      final got = await vault.previewImages(tmp);
      expect(got.map((f) => f.path.split('/').last).toList(), ['p5.jpg', 'p4.jpg', 'p3.jpg', 'p2.jpg']);
      expect((await vault.previewImages(tmp, max: 2)).length, 2);
      expect(await vault.previewImages(tmp, max: 0), isEmpty);
    });

    test('プレビュー：画像以外・隠し・サムネ・0バイトは除く', () async {
      await img(tmp, 'ok.png');
      await img(tmp, 'movie.mp4');
      await img(tmp, 'note.txt');
      await img(tmp, '.hidden.jpg');
      await img(tmp, 'thumb_1.jpg');
      await img(tmp, 'empty.jpg', bytes: const []);
      final got = await vault.previewImages(tmp);
      expect(got.map((f) => f.path.split('/').last).toList(), ['ok.png']);
    });

    test('プレビュー：直下が少なければサブフォルダの画像で補う', () async {
      await img(tmp, 'top.jpg');
      final sub = await Directory('${tmp.path}/sub').create();
      await img(sub, 's1.jpg');
      await img(sub, 's2.jpg');
      final hidden = await Directory('${tmp.path}/.hidden').create();
      await img(hidden, 'h.jpg');
      final got = await vault.previewImages(tmp);
      expect(got.length, 3);
      expect(got.first.path.endsWith('top.jpg'), isTrue);
      expect(got.any((f) => f.path.contains('.hidden')), isFalse);
    });

    test('プレビュー：画像が無い・フォルダが無いときは空', () async {
      expect(await vault.previewImages(tmp), isEmpty);
      expect(await vault.previewImages(Directory('${tmp.path}/none')), isEmpty);
    });
  });
}
