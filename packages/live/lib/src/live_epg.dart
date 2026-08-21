/// 电子节目单（EPG）模型。
class LiveEpg {
  const LiveEpg({
    required this.channelId,
    required this.channelName,
    required this.programs,
  });

  /// 从XMLTV格式解析。
  factory LiveEpg.fromXmltv(String channelId, String channelName, String xml) {
    final programs = <EpgProgram>[];
    final programMatches = RegExp(
      '<programme[^>]+start="([^"]+)"[^>]+stop="([^"]+)"[^>]*>.*?</programme>',
      dotAll: true,
    ).allMatches(xml);

    for (final match in programMatches) {
      final startStr = match.group(1);
      final stopStr = match.group(2);
      final content = match.group(0)!;

      if (startStr != null && stopStr != null) {
        final titleMatch = RegExp(
          '<title[^>]*>([^<]+)</title>',
        ).firstMatch(content);
        final descMatch = RegExp(
          '<desc[^>]*>([^<]+)</desc>',
        ).firstMatch(content);

        programs.add(
          EpgProgram(
            title: titleMatch?.group(1) ?? '',
            description: descMatch?.group(1),
            startTime: _parseXmltvTime(startStr),
            endTime: _parseXmltvTime(stopStr),
          ),
        );
      }
    }

    return LiveEpg(
      channelId: channelId,
      channelName: channelName,
      programs: programs,
    );
  }

  /// 频道ID。
  final String channelId;

  /// 频道名称。
  final String channelName;

  /// 节目列表。
  final List<EpgProgram> programs;

  /// 获取当前节目。
  EpgProgram? get currentProgram {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final program in programs) {
      if (program.startTime <= now && program.endTime > now) {
        return program;
      }
    }
    return null;
  }

  /// 获取下一个节目。
  EpgProgram? get nextProgram {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final program in programs) {
      if (program.startTime > now) {
        return program;
      }
    }
    return null;
  }

  /// 解析XMLTV时间格式。
  static int _parseXmltvTime(String time) {
    // 格式: 20250115120000 +0800
    try {
      final cleaned = time.replaceAll(RegExp(r'\s+[+-]\d{4}$'), '');
      final year = int.parse(cleaned.substring(0, 4));
      final month = int.parse(cleaned.substring(4, 6));
      final day = int.parse(cleaned.substring(6, 8));
      final hour = int.parse(cleaned.substring(8, 10));
      final minute = int.parse(cleaned.substring(10, 12));
      final second = int.parse(cleaned.substring(12, 14));

      final dt = DateTime(year, month, day, hour, minute, second);
      return dt.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return 0;
    }
  }
}

/// EPG节目。
class EpgProgram {
  const EpgProgram({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
  });

  /// 节目标题。
  final String title;

  /// 节目描述。
  final String? description;

  /// 开始时间（Unix时间戳，秒）。
  final int startTime;

  /// 结束时间（Unix时间戳，秒）。
  final int endTime;

  /// 节目时长（秒）。
  int get duration => endTime - startTime;

  /// 节目时长（分钟）。
  int get durationMinutes => duration ~/ 60;

  /// 是否正在播出。
  bool get isAiring {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return startTime <= now && endTime > now;
  }

  /// 进度百分比（0-100）。
  int get progress {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!isAiring) return 0;
    final elapsed = now - startTime;
    return ((elapsed / duration) * 100).clamp(0, 100).toInt();
  }

  @override
  String toString() =>
      'EpgProgram(title: $title, start: $startTime, end: $endTime)';
}
