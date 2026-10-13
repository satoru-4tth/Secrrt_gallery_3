import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_gallery_3/models/folder_style.dart';
import 'package:secret_gallery_3/services/vault_service.dart';
import 'package:secret_gallery_3/widgets/folder_tile.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('folder_tile_test');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<Directory> mk(WidgetTester t, String name, {int images = 0}) {
    return t.runAsync(() async {
      final d = await Directory('${root.path}/$name').create();
      for (var i = 0; i < images; i++) {
        await File('${d.path}/p$i.png').writeAsBytes(_png);
      }
      return d;
    }).then((d) => d!);
  }

  // 実時間の I/O とフレームを交互に進めて読み込み完了を待つ
  // until が指定されたら、満たされるまで（最大約5秒）待つ
  Future<void> settle(WidgetTester t, {bool Function()? until}) async {
    for (var i = 0; i < 200; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 25)));
      await t.pump(const Duration(milliseconds: 25));
      if (until == null ? i >= 7 : until()) return;
    }
  }

  Future<void> show(
    WidgetTester t,
    Directory dir, {
    double width = 120,
    double height = 120,
    double textScale = 1.0,
    int revision = 0,
    Future<void> Function()? onDelete,
    bool Function()? until,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: FolderTile(
                dir: dir,
                revision: revision,
                onOpen: () {},
                onDelete: onDelete ?? () async {},
                onFileDropped: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(t, until: until);
  }

  Color shapeFill(WidgetTester t) {
    // 図形の塗り色：ShapeDecoration を持つ最初の DecoratedBox
    final boxes = t.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    final d = boxes.map((b) => b.decoration).whereType<ShapeDecoration>().first;
    return d.color!;
  }

  testWidgets('既定は従来どおり青＋フォルダアイコン＋名前', (t) async {
    final d = await mk(t, 'Album');
    await show(t, d);
    expect(find.text('Album'), findsOneWidget);
    expect(find.byIcon(Icons.folder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(shapeFill(t), FolderStyle.defaultColor);
  });

  for (final n in [1, 2, 3, 4, 7]) {
    testWidgets('中の画像を表示する（$n枚入り → 最大4枚まで）', (t) async {
      final d = await mk(t, 'pics', images: n);
      await show(t, d, until: () => find.byType(Image).evaluate().length == (n > 4 ? 4 : n));
      expect(find.byType(Image), findsNWidgets(n > 4 ? 4 : n));
      expect(find.byIcon(Icons.folder), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('一覧の更新(revision)でプレビューが読み直される', (t) async {
    final d = await mk(t, 'live');
    await show(t, d);
    expect(find.byType(Image), findsNothing);
    await t.runAsync(() => File('${d.path}/new.png').writeAsBytes(_png));
    await show(t, d, revision: 1, until: () => find.byType(Image).evaluate().length == 1);
    expect(find.byType(Image), findsOneWidget);
  });

  group('文字がおかしくならない', () {
    testWidgets('長い名前は省略され、はみ出しエラーが出ない（狭い幅）', (t) async {
      final d = await mk(t, 'とても長いフォルダの名前をつけた場合でも表示が崩れないこと' * 2);
      await show(t, d, width: 90, height: 100);
      expect(t.takeException(), isNull);
      final text = t.widget<Text>(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('とても')));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('端末の文字サイズが最大級(3倍)でも崩れない', (t) async {
      final d = await mk(t, 'フォルダ名');
      await show(t, d, textScale: 3.0, width: 100, height: 100);
      expect(t.takeException(), isNull);
    });

    testWidgets('絵文字・日本語・記号の名前もそのまま表示', (t) async {
      final d = await mk(t, '旅行📷「春」_#1');
      await show(t, d);
      expect(find.text('旅行📷「春」_#1'), findsOneWidget);
    });

    for (final s in FolderShape.values) {
      testWidgets('形「${s.label}」でも名前の帯が切れず、エラーが出ない', (t) async {
        final d = await mk(t, 'shape_${s.id}', images: 4);
        await t.runAsync(() => VaultService().setAlbumStyle(
              d,
              FolderStyle(color: FolderStyle.palette[3], shape: s),
            ));
        await show(t, d, width: 110, height: 110, until: () => shapeFill(t) == FolderStyle.palette[3]);
        expect(shapeFill(t), FolderStyle.palette[3]);
        expect(t.takeException(), isNull);
        // 名前は図形の外側（下）にあり、タイルの枠内に収まっている
        final tile = t.getRect(find.byType(FolderTile));
        final label = t.getRect(find.text('shape_${s.id}'));
        expect(tile.contains(label.topLeft), isTrue);
        expect(tile.contains(label.bottomRight), isTrue);
      });
    }

    for (final c in FolderStyle.palette) {
      testWidgets('背景色 ${c.toARGB32().toRadixString(16)} で名前が読める色になる', (t) async {
        final d = await mk(t, 'nm');
        await t.runAsync(() => VaultService().setAlbumStyle(d, FolderStyle(color: c, shape: FolderShape.rounded)));
        await show(t, d, until: () => shapeFill(t) == c);
        expect(shapeFill(t), c);
        final text = t.widget<Text>(find.text('nm'));
        expect(contrastRatio(c, text.style!.color!), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('色と形の変更', () {
    Future<void> openSheet(WidgetTester t) async {
      await t.tap(find.byIcon(Icons.more_vert));
      await t.pumpAndSettle();
      await t.tap(find.text('色と形を変更'));
      await t.pumpAndSettle();
      expect(find.text('フォルダのデザイン'), findsOneWidget);
    }

    testWidgets('メニュー→色と形を選んで保存 → タイルに反映され、ファイルにも保存', (t) async {
      final d = await mk(t, 'Album');
      await show(t, d);
      await openSheet(t);

      final red = FolderStyle.palette[1];
      await t.tap(find.byKey(ValueKey('folder_color_${red.toARGB32()}')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('folder_shape_circle')));
      await t.pump();
      await t.tap(find.text('保存'));
      await t.pumpAndSettle();
      await settle(t, until: () => shapeFill(t) == red);

      expect(find.text('フォルダのデザイン'), findsNothing);
      expect(shapeFill(t), red);
      final saved = await t.runAsync(() => VaultService().readFolderStyle(d));
      expect(saved, FolderStyle(color: red, shape: FolderShape.circle));
      expect(t.takeException(), isNull);
    });

    testWidgets('保存した見た目は作り直しても復元される', (t) async {
      final d = await mk(t, 'Album');
      final purple = FolderStyle.palette[8];
      await t.runAsync(() => VaultService().setAlbumStyle(d, FolderStyle(color: purple, shape: FolderShape.beveled)));
      await show(t, d, until: () => shapeFill(t) == purple);
      expect(shapeFill(t), purple);
    });

    testWidgets('キャンセルすると何も変わらない', (t) async {
      final d = await mk(t, 'Album');
      await show(t, d);
      await openSheet(t);
      await t.tap(find.byKey(ValueKey('folder_color_${FolderStyle.palette[1].toARGB32()}')));
      await t.pump();
      await t.tap(find.text('キャンセル'));
      await t.pumpAndSettle();
      expect(shapeFill(t), FolderStyle.defaultColor);
      expect(File('${d.path}/.album.meta.json').existsSync(), isFalse);
    });

    testWidgets('長押しでもデザイン変更画面が開く', (t) async {
      final d = await mk(t, 'Album');
      await show(t, d);
      await t.longPress(find.byType(FolderTile));
      await t.pumpAndSettle();
      expect(find.text('フォルダのデザイン'), findsOneWidget);
    });

    testWidgets('シートが小さい画面・大きい文字でも崩れない', (t) async {
      t.view.physicalSize = const Size(320, 480);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final d = await mk(t, 'とても長い名前のフォルダ' * 3);
      await show(t, d, textScale: 2.0);
      await openSheet(t);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('メニューの削除は確認後に onDelete が呼ばれる', (t) async {
    final d = await mk(t, 'Album');
    var deleted = 0;
    await show(t, d, onDelete: () async => deleted++);
    await t.tap(find.byIcon(Icons.more_vert));
    await t.pumpAndSettle();
    await t.tap(find.text('フォルダ削除'));
    await t.pumpAndSettle();
    expect(find.text('フォルダを削除しますか？'), findsOneWidget);
    await t.tap(find.text('キャンセル'));
    await t.pumpAndSettle();
    expect(deleted, 0);

    await t.tap(find.byIcon(Icons.more_vert));
    await t.pumpAndSettle();
    await t.tap(find.text('フォルダ削除'));
    await t.pumpAndSettle();
    await t.tap(find.text('削除'));
    await t.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('存在しないフォルダでも落ちずに既定表示', (t) async {
    await show(t, Directory('${root.path}/missing'));
    expect(t.takeException(), isNull);
    expect(find.text('missing'), findsOneWidget);
  });
}
