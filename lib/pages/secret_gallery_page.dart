//秘密ギャラリーの画面を表示する

import 'package:flutter/material.dart';
import 'package:secret_gallery_3/controllers/gallery_controller.dart';
import '../services/vault_service.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
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
            title: ctrl.isSelecting
                ? Text('選択中: ${ctrl.selectedCount} 件')
                : const Text('秘密ギャラリー'),
            actions: [
              if (ctrl.isSelecting) ...[
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: '選択を書き出し',
                  onPressed: () => ctrl.exportSelectedToDevice(context, askMove: true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '選択削除',
                  onPressed: () => ctrl.deleteSelected(context),
                ),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: '全選択',
                  onPressed: ctrl.selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '選択解除',
                  onPressed: ctrl.clearSelection,
                ),
              ] else ...[
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
                //上のメニューバーのフォルダを端末に戻す項目を表示するところ
                // PopupMenuButton<String>(
                //   onSelected: (v) {
                //     if (v == 'export_here') {
                //       ctrl.exportCurrentFolderToDevice(context, recursive: true);
                //     }
                //   },
                //   itemBuilder: (_) => const [
                //     PopupMenuItem(
                //       value: 'export_here',
                //       child: Text('このフォルダを端末へ戻す'),
                //     ),
                //   ],
                // ),
                const SettingsMenuButton(),
              ],
            ],
            bottom: BreadcrumbBar(
              crumbs: crumbs,
              onUp: ctrl.goUp,
              onTapDir: ctrl.goInto,
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              // : empty
              // ? const Center(child: Text('このフォルダは空です'))
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
              final selected = ctrl.isSelected(f);

              return GestureDetector(
                // 長押しで選択開始/切替
                onLongPress: () => ctrl.toggleSelect(f),

                // 選択モード中だけタップ=トグル、通常時は子にタップを渡す（FileTileの既存挙動を維持）
                onTap: ctrl.isSelecting ? () => ctrl.toggleSelect(f) : null,
                behavior: HitTestBehavior.opaque,

                child: Stack(
                  children: [
                    // 既存の表示はそのまま
                    Positioned.fill(
                      child: FileTile(
                        file: f,
                        onDeleted: ctrl.refresh,
                      ),
                    ),

                    // 選択中の見た目（枠＆チェック）。IgnorePointerで下の操作を邪魔しない
                    if (selected) ...[
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: Icon(Icons.check_circle, size: 20),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
