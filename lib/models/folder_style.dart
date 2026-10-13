// フォルダの見た目（色と形）を表すモデル
import 'package:flutter/material.dart';

/// フォルダの形。保存するのは [id] だけなので、並べ替えや名前変更をしても壊れない。
enum FolderShape {
  rounded('rounded', '角丸'),
  square('square', '四角'),
  circle('circle', '円'),
  squircle('squircle', 'まる四角'),
  beveled('beveled', '面取り');

  const FolderShape(this.id, this.label);
  final String id;
  final String label;

  /// 未知・null は既定（角丸）に戻す
  static FolderShape fromId(String? id) {
    for (final s in FolderShape.values) {
      if (s.id == id) return s;
    }
    return FolderShape.rounded;
  }

  OutlinedBorder get border {
    switch (this) {
      case FolderShape.rounded:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
      case FolderShape.square:
        return const RoundedRectangleBorder();
      case FolderShape.circle:
        return const CircleBorder();
      case FolderShape.squircle:
        return ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(36),
        );
      case FolderShape.beveled:
        return BeveledRectangleBorder(borderRadius: BorderRadius.circular(14));
    }
  }
}

@immutable
class FolderStyle {
  const FolderStyle({required this.color, required this.shape});

  /// 従来の見た目（青・角丸）
  static const FolderStyle defaults = FolderStyle(
    color: defaultColor,
    shape: FolderShape.rounded,
  );

  static const Color defaultColor = Color(0xFF64B5F6); // Colors.blue.shade300

  /// 選べる色
  static const List<Color> palette = [
    defaultColor,
    Color(0xFFEF5350), // 赤
    Color(0xFFEC407A), // ピンク
    Color(0xFFFFA726), // オレンジ
    Color(0xFFFFEE58), // 黄
    Color(0xFF66BB6A), // 緑
    Color(0xFF26A69A), // ティール
    Color(0xFF5C6BC0), // 藍
    Color(0xFFAB47BC), // 紫
    Color(0xFF8D6E63), // 茶
    Color(0xFF78909C), // グレー
    Color(0xFF37474F), // 濃紺グレー
    Color(0xFFF5F5F5), // 白
    Color(0xFF212121), // 黒
  ];

  final Color color;
  final FolderShape shape;

  /// この色の上に載せる文字・アイコンの色（白か黒の、コントラストが高い方）
  Color get foreground => readableOn(color);

  FolderStyle copyWith({Color? color, FolderShape? shape}) =>
      FolderStyle(color: color ?? this.color, shape: shape ?? this.shape);

  @override
  bool operator ==(Object other) =>
      other is FolderStyle && other.color == color && other.shape == shape;

  @override
  int get hashCode => Object.hash(color, shape);
}

/// WCAG のコントラスト比
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [background] の上で最も読みやすい文字色（白 or 黒）を返す。
/// どの色でも 4.5:1 以上のコントラストが確保される。
Color readableOn(Color background) {
  // 純黒なら、白との二択でどんな背景でも最悪 4.58:1 を確保できる
  const dark = Color(0xFF000000);
  const light = Color(0xFFFFFFFF);
  return contrastRatio(background, light) >= contrastRatio(background, dark)
      ? light
      : dark;
}
