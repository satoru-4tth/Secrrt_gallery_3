// ファイルをフォルダタイル／「一つ上へ」にドロップしたときの動作
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_gallery_3/widgets/breadcrumb_bar.dart';
import 'package:secret_gallery_3/widgets/folder_tile.dart';

void main() {
  final file = File('/vault/a.jpg');
  final dir = Directory('/vault/album');

  Widget draggable() => Draggable<File>(
    data: file,
    feedback: const SizedBox(width: 20, height: 20),
    child: const SizedBox(key: Key('src'), width: 60, height: 60, child: Text('src')),
  );

  testWidgets('FolderTile にドロップすると (file, dir) が渡る', (t) async {
    File? gotFile;
    Directory? gotDir;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              draggable(),
              SizedBox(
                width: 120,
                height: 120,
                child: FolderTile(
                  dir: dir,
                  onOpen: () {},
                  onDelete: () async {},
                  onFileDropped: (f, d) async {
                    gotFile = f;
                    gotDir = d;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final from = t.getCenter(find.byKey(const Key('src')));
    final to = t.getCenter(find.byType(FolderTile));
    final g = await t.startGesture(from);
    await g.moveTo(to);
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(gotFile?.path, file.path);
    expect(gotDir?.path, dir.path);
  });

  testWidgets('「一つ上へ」にドロップすると親フォルダが渡る', (t) async {
    File? gotFile;
    Directory? gotParent;
    final parent = Directory('/vault');
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: BreadcrumbBar(
            crumbs: [parent, dir],
            onUp: () {},
            onTapDir: (_) {},
            onFileDroppedToParent: (f, d) async {
              gotFile = f;
              gotParent = d;
            },
          ),
          body: Align(alignment: Alignment.bottomCenter, child: draggable()),
        ),
      ),
    );
    final from = t.getCenter(find.byKey(const Key('src')));
    final target = find.byType(DragTarget<File>);
    expect(target, findsOneWidget);
    final g = await t.startGesture(from);
    await g.moveTo(t.getCenter(target));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(gotFile?.path, file.path);
    expect(gotParent?.path, parent.path);
  });
}
