// アルバムのメタデータ(データを説明するための付加情報)を管理するモデルクラス(現実のものをプラグラム上で型として表現したもの)
// models/album_meta.dart
class AlbumMeta {
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlbumMeta({required this.name, required this.createdAt, required this.updatedAt});

  factory AlbumMeta.initial(String name) {
    final now = DateTime.now();
    return AlbumMeta(name: name, createdAt: now, updatedAt: now);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AlbumMeta.fromJson(Map<String, dynamic> map) {
    return AlbumMeta(
      name: map['name'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  AlbumMeta copyWith({String? name}) => AlbumMeta(
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
