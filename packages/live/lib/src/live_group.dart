/// 直播分组模型。
class LiveGroup {
  /// 分组ID。
  final String id;

  /// 分组名称。
  final String name;

  /// 父分组ID（支持嵌套）。
  final String? parentId;

  /// 排序序号。
  final int order;

  /// 是否为收藏分组。
  final bool isFavorite;

  const LiveGroup({
    required this.id,
    required this.name,
    this.parentId,
    this.order = 0,
    this.isFavorite = false,
  });

  /// 从JSON构造。
  factory LiveGroup.fromJson(Map<String, dynamic> json) {
    return LiveGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      parentId: json['parentId'] as String?,
      order: json['order'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  /// 转换为JSON。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (parentId != null) 'parentId': parentId,
      'order': order,
      'isFavorite': isFavorite,
    };
  }

  /// 复制并修改。
  LiveGroup copyWith({
    String? id,
    String? name,
    String? parentId,
    int? order,
    bool? isFavorite,
  }) {
    return LiveGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      order: order ?? this.order,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LiveGroup(id: $id, name: $name)';
}
