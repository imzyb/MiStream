/// 版本号的**比较**语义。
///
/// 为什么自己写而不引 `pub_semver`：这里要比较的是**应用版本**，来源是
/// `pubspec.yaml` 的 `version:` 字段（`0.1.0+1`）与更新 feed 里的字符串，
/// 两边都可能带构建号或预发布后缀。规则只需要三条，引一个包反而要多解释
/// 一层「谁的语义为准」。
///
/// 规则（与 semver 2.0 对齐，但**忽略** build metadata）：
///   1. 依次比 major / minor / patch；
///   2. 主次版本相同时，**没有**预发布后缀的更大（`1.0.0 > 1.0.0-beta`）；
///   3. 都有预发布后缀时按 `.` 切段比：两段都是数字按数值比，否则按字符串比，
///      数字段小于非数字段（`1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-beta`）。
///
/// 构建号（`+45`）**不参与比较** —— 它表示「同一个版本的又一次构建」，用它
/// 判断要不要更新会导致同版本反复提示。
library;

/// 一个可比较的应用版本。
final class AppVersion implements Comparable<AppVersion> {
  /// 直接构造；一般用 [parse]。
  const AppVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = '',
    this.build = '',
    this.raw = '',
  });

  /// 解析 `1.2.3` / `1.2.3-beta.1` / `1.2.3+45` / `1.2.3-beta.1+45`。
  ///
  /// 不合法时抛 [FormatException] —— **不要**在这里宽容：版本号解析失败
  /// 意味着 feed 或 pubspec 写错了，静默当成 `0.0.0` 会让「永远提示有更新」
  /// 或「永远不提示」这种最难查的 bug 出现。
  factory AppVersion.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const FormatException('版本号为空');
    }
    // 先切掉 build metadata（`+` 之后一律不参与比较）。
    final plus = text.indexOf('+');
    final core = plus >= 0 ? text.substring(0, plus) : text;
    final build = plus >= 0 ? text.substring(plus + 1) : '';
    // 再切预发布后缀（第一个 `-`）。
    final dash = core.indexOf('-');
    final numbers = dash >= 0 ? core.substring(0, dash) : core;
    final pre = dash >= 0 ? core.substring(dash + 1) : '';

    final parts = numbers.split('.');
    if (parts.length < 2 || parts.length > 3) {
      throw FormatException('版本号段数不对（要 2~3 段）: $raw');
    }
    int at(int index) {
      if (index >= parts.length) return 0;
      final value = int.tryParse(parts[index]);
      if (value == null || value < 0) {
        throw FormatException('版本号里有非数字段: $raw');
      }
      return value;
    }

    return AppVersion(
      at(0),
      at(1),
      at(2),
      preRelease: pre,
      build: build,
      raw: text,
    );
  }

  /// 解析失败时返回 `null`（只给「不确定就别拦」的场景用）。
  static AppVersion? tryParse(String raw) {
    try {
      return AppVersion.parse(raw);
    } on FormatException {
      return null;
    }
  }

  /// 主版本号。
  final int major;

  /// 次版本号。
  final int minor;

  /// 修订号。
  final int patch;

  /// 预发布后缀（不含 `-`），如 `beta.1`；没有则为空串。
  final String preRelease;

  /// 构建号（不含 `+`）；**不参与比较**。
  final String build;

  /// 原始字符串（诊断用）。
  final String raw;

  /// 是否是预发布版本。
  bool get isPreRelease => preRelease.isNotEmpty;

  /// 是否严格大于 [other]。
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // 正式版 > 预发布版。
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    return _comparePre(preRelease, other.preRelease);
  }

  static int _comparePre(String a, String b) {
    final left = a.split('.');
    final right = b.split('.');
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      // 段数少的更小：`alpha < alpha.1`。
      if (i >= left.length) return -1;
      if (i >= right.length) return 1;
      final l = left[i];
      final r = right[i];
      final ln = int.tryParse(l);
      final rn = int.tryParse(r);
      if (ln != null && rn != null) {
        if (ln != rn) return ln.compareTo(rn);
      } else if (ln != null) {
        // 数字段 < 非数字段。
        return -1;
      } else if (rn != null) {
        return 1;
      } else {
        final c = l.compareTo(r);
        if (c != 0) return c;
      }
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() {
    final pre = preRelease.isEmpty ? '' : '-$preRelease';
    final meta = build.isEmpty ? '' : '+$build';
    return '$major.$minor.$patch$pre$meta';
  }
}
