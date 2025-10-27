// 秘密ギャラリーの画面を表示する

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:secret_gallery_3/controllers/gallery_controller.dart';
import '../services/vault_service.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
import '../widgets/settings_menu_button.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ★ 追加

class SecretGalleryPage extends StatefulWidget {
  const SecretGalleryPage({super.key});
  @override
  State<SecretGalleryPage> createState() => _SecretGalleryPageState();
}

class _SecretGalleryPageState extends State<SecretGalleryPage> {
  late final GalleryController ctrl;
  final VaultService _vault = VaultService(); // ★ 追加: 移動に使う

  // ▼ バナー用フィールド
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    ctrl = GalleryController(_vault);
    // 非同期初期化
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.init());

    // ▼ バナー読み込み（ギャラリー用のユニットIDに差し替え推奨）
    _banner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // ★ Androidバナー公式テストID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, err) {
          debugPrint('Gallery banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    ctrl.dispose();
    super.dispose();
  }

  // =====================================================
  // ★ 追加：ファイル移動処理
  //
  // FileTile が LongPressDraggable<File> で送る File を
  // FolderTile 側の DragTarget<File> が受け取った時に呼ばれる。
  //
  // 1) 物理的にファイルを targetDir へ移動
  // 2) ctrl.refresh() でUI更新
  // =====================================================
  Future<void> _handleFileDropped(File droppedFile, Directory targetDir) async {
    try {
      await _moveFileIntoDir(droppedFile, targetDir);
      await ctrl.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('移動しました: ${_fileName(droppedFile)} → ${_dirName(targetDir)}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移動に失敗しました: $e')),
      );
    }
  }

  // 実際の物理移動。VaultServiceに正式なAPIがあるならそちらを使ってよい。
  Future<void> _moveFileIntoDir(File src, Directory destDir) async {
    final oldPath = src.path;
    final fileName = oldPath.split(Platform.pathSeparator).last;
    final newPath = '${destDir.path}${Platform.pathSeparator}$fileName';

    // 同一ボリューム内なら rename が速い。失敗したら copy+delete でフォールバック。
    try {
      await src.rename(newPath);
    } catch (_) {
      final newFile = await src.copy(newPath);
      await src.delete();
      // newFile は使わないが、将来ログ等で使いたければ保持可
    }
  }

  String _fileName(File f) {
    final parts = f.path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : f.path;
  }

  String _dirName(Directory d) {
    final parts = d.path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : d.path;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final crumbs = ctrl.breadcrumbDirs();
        final isLoading = ctrl.current == null;

        return Scaffold(
          appBar: AppBar(
            title: ctrl.isSelecting
                ? Text('選択中: ${ctrl.selectedCount} 件')
                : const Text('Secret Gallery'),
            actions: [
              if (ctrl.isSelecting) ...[
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: '選択を書き出し',
                  onPressed: () => ctrl.exportSelectedToDevice(
                    context,
                    askMove: true,
                  ),
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
                const SettingsMenuButton(),
              ],
            ],
            bottom: BreadcrumbBar(
              crumbs: crumbs,
              onUp: ctrl.goUp,
              onTapDir: ctrl.goInto,
              onFileDroppedToParent: (file, parentDir) async {
                // すでに SecretGalleryPage の中にある
                // _handleFileDropped(File droppedFile, Directory targetDir)
                await _handleFileDropped(file, parentDir);
              },
            ),

          ),
          body: SafeArea(
            child: Column(
              children: [
                // =====================================================
                // ★ 追加：フォルダ一覧を先に表示したい場合は
                //   GridViewとは別に横スクロールなどで出しても良い。
                //   今回は既存レイアウトを大きく壊さず、GridView内で
                //   フォルダもファイルも混在表示する方式を続ける。
                //   → なので、下の GridView.builder 内で FolderTile に
                //     onFileDropped を渡すようにする。
                // =====================================================

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: ctrl.dirs.length + ctrl.files.length,
                    itemBuilder: (_, i) {
                      // ---------- フォルダ ----------
                      if (i < ctrl.dirs.length) {
                        final d = ctrl.dirs[i];
                        return FolderTile(
                          dir: d,
                          onOpen: () => ctrl.goInto(d),
                          onDelete: () => ctrl.deleteFolder(d),
                          onExport: (dir) => ctrl.exportFolderToDevice(
                            context,
                            dir,
                            recursive: true,
                          ),
                          // ★ ドロップを受けたらファイル移動してリフレッシュ
                          onFileDropped: _handleFileDropped,
                        );
                      }

                      // ---------- ファイル ----------
                      final f = ctrl.files[i - ctrl.dirs.length];
                      final selected = ctrl.isSelected(f);

                      // ここで FileTile はすでに LongPressDraggable<File> 化済み
                      // そのまま並べる
                      return GestureDetector(
                        onLongPress: () => ctrl.toggleSelect(f),
                        onTap: ctrl.isSelecting
                            ? () => ctrl.toggleSelect(f)
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FileTile(
                                file: f,
                                onDeleted: ctrl.refresh,
                              ),
                            ),

                            // 選択状態のオーバーレイ
                            if (selected) ...[
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(width: 2),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 6,
                                top: 6,
                                child: Icon(Icons.check_circle,
                                    size: 20),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ▼ バナー（最下部）
                if (_banner != null)
                  SizedBox(
                    width: _banner!.size.width.toDouble(),
                    height: _banner!.size.height.toDouble(),
                    child: AdWidget(ad: _banner!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
