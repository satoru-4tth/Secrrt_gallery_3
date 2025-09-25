//秘密ギャラリーの画面を表示する

import 'package:flutter/material.dart';
import '../controllers/gallery_controller.dart';
import '../services/vault_service.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
// import '../pages/change_password_page.dart'; // ← このファイルでは未使用なら消してOK
import '../widgets/settings_menu_button.dart';

class SecretGalleryPage extends StatefulWidget {
  const SecretGalleryPage({super.key});
  @override
  State<SecretGalleryPage> createState() => _SecretGalleryPageState();
}

class _SecretGalleryPageState extends State<SecretGalleryPage> {
  late final GalleryController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = GalleryController(VaultService());
    // 非同期初期化
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.init());
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final crumbs = ctrl.breadcrumbDirs();
        final isLoading = ctrl.current == null;
        final empty = ctrl.dirs.isEmpty && ctrl.files.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('秘密ギャラリー'),
            actions: [
              IconButton(
                onPressed: () => ctrl.importFromSystem(context),
                icon: const Icon(Icons.download),
                tooltip: '取り込み（現在のフォルダ）',
              ),
              IconButton(
                onPressed: () => ctrl.createFolder(context),
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'フォルダ作成',
              ),
              IconButton(
                tooltip: '選択を端末へ戻す',
                onPressed: () => ctrl.exportSelectedToDevice(context),
                icon: const Icon(Icons.undo),
              ),

              // ★ ここに追加（今開いているフォルダごと戻す）
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'export_here') {
                    ctrl.exportCurrentFolderToDevice(context, recursive: true);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'export_here',
                    child: Text('このフォルダを端末へ戻す'),
                  ),
                ],
              ),

              const SettingsMenuButton(), // ← 新しい設定メニュー（パスワード変更/キャッシュクリア）
            ],
            bottom: BreadcrumbBar(
              crumbs: crumbs,
              onUp: ctrl.goUp,
              onTapDir: ctrl.goInto,
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : empty
              ? const Center(child: Text('このフォルダは空です'))
              : GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemCount: ctrl.dirs.length + ctrl.files.length,
            itemBuilder: (_, i) {
              if (i < ctrl.dirs.length) {
                final d = ctrl.dirs[i];
                return FolderTile(
                  dir: d,
                  onOpen: () => ctrl.goInto(d),
                  onDelete: () => ctrl.deleteFolder(d),
                  onExport: (dir) => ctrl.exportFolderToDevice(context, dir, recursive: true), // ★ 追加
                );
              }
              final f = ctrl.files[i - ctrl.dirs.length];
              return FileTile(file: f, onDeleted: ctrl.refresh);
            },
          ),
        );
      },
    );
  }
}
