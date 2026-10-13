// アルバムのメタデータ(データを説明するための付加情報)を管理するモデルクラス(現実のものをプラグラム上で型として表現したもの)
// models/album_meta.dart
class AlbumMeta {
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// フォルダの色（ARGB 32bit）。未設定なら null（＝既定の色）
  final int? colorValue;

  /// フォルダの形の id。未設定なら null（＝既定の形）
  final String? shape;

  const AlbumMeta({
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.colorValue,
    this.shape,
  });

  factory AlbumMeta.initial(String name) {
    final now = DateTime.now();
    return AlbumMeta(name: name, createdAt: now, updatedAt: now);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    // 古いバージョンのファイルと互換にするため、未設定なら書かない
    if (colorValue != null) 'color': colorValue,
    if (shape != null) 'shape': shape,
  };

  factory AlbumMeta.fromJson(Map<String, dynamic> map) {
    final color = map['color'];
    final shape = map['shape'];
    return AlbumMeta(
      name: map['name'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      // 型が想定外でも落とさず、既定値扱いにする
      colorValue: color is num ? color.toInt() : null,
      shape: shape is String ? shape : null,
    );
  }

  /// 指定しなかった項目は今の値を引き継ぐ（色・形が消えないように）
  AlbumMeta copyWith({String? name, int? colorValue, String? shape}) =>
      AlbumMeta(
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        colorValue: colorValue ?? this.colorValue,
        shape: shape ?? this.shape,
      );
}
