/// 直播频道模型。
class LiveChannel {
  /// 频道ID。
  final String id;

  /// 频道名称。
  final String name;

  /// 播放地址。
  final String url;

  /// 频道图标URL（可选）。
  final String? logo;

  /// 分组ID（可选）。
  final String? groupId;

  /// 频道号（可选）。
  final int? channelNumber;

  /// 是否为高清源。
  final bool isHd;

  /// 最后更新时间戳。
  final int? updatedAt;

  const LiveChannel({
    required this.id,
    required this.name,
    required this.url,
    this.logo,
    this.groupId,
    this.channelNumber,
    this.isHd = false,
    this.updatedAt,
  });

  /// 从JSON构造。
  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    return LiveChannel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      logo: json['logo'] as String?,
      groupId: json['groupId'] as String?,
      channelNumber: json['channelNumber'] as int?,
      isHd: json['isHd'] as bool? ?? false,
      updatedAt: json['updatedAt'] as int?,
    );
  }

  /// 转换为JSON。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      if (logo != null) 'logo': logo,
      if (groupId != null) 'groupId': groupId,
      if (channelNumber != null) 'channelNumber': channelNumber,
      'isHd': isHd,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  /// 复制并修改。
  LiveChannel copyWith({
    String? id,
    String? name,
    String? url,
    String? logo,
    String? groupId,
    int? channelNumber,
    bool? isHd,
    int? updatedAt,
  }) {
    return LiveChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      logo: logo ?? this.logo,
      groupId: groupId ?? this.groupId,
      channelNumber: channelNumber ?? this.channelNumber,
      isHd: isHd ?? this.isHd,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveChannel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url;

  @override
  int get hashCode => id.hashCode ^ url.hashCode;

  @override
  String toString() => 'LiveChannel(id: $id, name: $name)';
}
