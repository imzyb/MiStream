/// 浏览器内核发现。
///
/// ADR-005 决定嗅探走独立进程 + CDP，但**不随包浏览器内核**（体积预算与
/// npm 依赖树的取舍见该 ADR 的备选方案表）。因此运行时必须自己找到可用的
/// 内核：显式配置优先，其次扫本机已装的 Chromium 系浏览器。
///
/// 找不到就是 `SNIFFER_UNAVAILABLE`（-32300），要让用户看到「装个 Edge/Chrome
/// 就能用」而不是一个无信息转圈——这正是 ADR-005 对 Linux 缺 CEF 时要求的
/// 优雅降级，这里把它推广到全平台。
library;

import 'dart:io';

/// 内核种类。
enum SnifferKernelKind {
  /// Microsoft Edge（Windows 默认存在，内核与 WebView2 同源）。
  edge,

  /// Google Chrome。
  chrome,

  /// Chromium（Linux 发行版包）。
  chromium,

  /// Brave。
  brave,

  /// 用户显式指定的路径。
  custom;

  /// 展示名。
  String get label => switch (this) {
    SnifferKernelKind.edge => 'Microsoft Edge',
    SnifferKernelKind.chrome => 'Google Chrome',
    SnifferKernelKind.chromium => 'Chromium',
    SnifferKernelKind.brave => 'Brave',
    SnifferKernelKind.custom => '自定义内核',
  };
}

/// 一个可用的内核。
class SnifferKernel {
  /// 构造内核描述。
  const SnifferKernel({required this.path, required this.kind});

  /// 可执行文件绝对路径。
  final String path;

  /// 内核种类。
  final SnifferKernelKind kind;

  @override
  String toString() => 'SnifferKernel(${kind.label}: $path)';

  @override
  bool operator ==(Object other) =>
      other is SnifferKernel && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);
}

/// 找不到可用内核。
class SnifferUnavailableException implements Exception {
  /// 构造错误。
  const SnifferUnavailableException([this.detail]);

  /// 补充说明（例如探测过的路径）。
  final String? detail;

  /// 对应 RPC 错误码 `SNIFFER_UNAVAILABLE`。
  int get code => -32300;

  @override
  String toString() =>
      'SnifferUnavailableException(SNIFFER_UNAVAILABLE${detail == null ? '' : ': $detail'})';
}

/// 内核发现器。
///
/// 探测顺序是有意为之：Edge 放最前，因为 Windows 上它随系统存在，命中率
/// 最高；而且 Edge 与 WebView2 同源，行为与 ADR-005 的预期内核一致。
class SnifferKernelLocator {
  /// 构造发现器。
  ///
  /// [explicitPath] 非空时**只**用它——显式配置就该覆盖探测，否则用户
  /// 设了路径却不生效会很难排查。
  const SnifferKernelLocator({
    this.explicitPath,
    this.fileExists = _defaultFileExists,
  });

  /// 用户显式配置的内核路径。
  final String? explicitPath;

  /// 可注入的存在性检查，便于测试。
  final bool Function(String path) fileExists;

  /// 探测可用内核，找不到返回 null。
  SnifferKernel? locate() {
    final explicit = explicitPath;
    if (explicit != null && explicit.trim().isNotEmpty) {
      final p = explicit.trim();
      return _exists(p)
          ? SnifferKernel(path: p, kind: SnifferKernelKind.custom)
          : null;
    }

    for (final candidate in _candidates()) {
      if (_exists(candidate.path)) return candidate;
    }
    return null;
  }

  /// 包一层防御：探测一个路径失败（权限、非法字符、网络盘掉线）不该让
  /// 整个发现流程崩掉。发现流程是嗅探的第一步，它崩了后面全无从谈起。
  bool _exists(String path) {
    try {
      return fileExists(path);
    } on Object {
      return false;
    }
  }

  /// 探测，找不到则抛 [SnifferUnavailableException]。
  SnifferKernel locateOrThrow() {
    final kernel = locate();
    if (kernel != null) return kernel;
    throw SnifferUnavailableException(
      '未找到可用的浏览器内核（探测过 ${_candidates().length} 个常见路径）',
    );
  }

  /// 候选列表，按优先级排序。
  ///
  /// 路径写死而不查注册表：注册表读取在受限环境会被拦，且 Windows 的
  /// App Paths 未必有这些浏览器（实测本机就没有）。固定路径 + 用户配置
  /// 覆盖，比依赖注册表更可预测。
  List<SnifferKernel> _candidates() => switch (Platform.operatingSystem) {
    'windows' => _windowsCandidates(),
    'macos' => _macCandidates(),
    _ => _linuxCandidates(),
  };

  List<SnifferKernel> _windowsCandidates() {
    final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final pf86 =
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final local = Platform.environment['LOCALAPPDATA'] ?? '';

    return <SnifferKernel>[
      SnifferKernel(
        path: '$pf86\\Microsoft\\Edge\\Application\\msedge.exe',
        kind: SnifferKernelKind.edge,
      ),
      SnifferKernel(
        path: '$pf\\Microsoft\\Edge\\Application\\msedge.exe',
        kind: SnifferKernelKind.edge,
      ),
      SnifferKernel(
        path: '$pf\\Google\\Chrome\\Application\\chrome.exe',
        kind: SnifferKernelKind.chrome,
      ),
      SnifferKernel(
        path: '$pf86\\Google\\Chrome\\Application\\chrome.exe',
        kind: SnifferKernelKind.chrome,
      ),
      if (local.isNotEmpty)
        SnifferKernel(
          path: '$local\\Google\\Chrome\\Application\\chrome.exe',
          kind: SnifferKernelKind.chrome,
        ),
      SnifferKernel(
        path: '$pf\\BraveSoftware\\Brave-Browser\\Application\\brave.exe',
        kind: SnifferKernelKind.brave,
      ),
    ];
  }

  List<SnifferKernel> _macCandidates() => const <SnifferKernel>[
    SnifferKernel(
      path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      kind: SnifferKernelKind.chrome,
    ),
    SnifferKernel(
      path: '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      kind: SnifferKernelKind.edge,
    ),
    SnifferKernel(
      path: '/Applications/Chromium.app/Contents/MacOS/Chromium',
      kind: SnifferKernelKind.chromium,
    ),
  ];

  List<SnifferKernel> _linuxCandidates() => const <SnifferKernel>[
    SnifferKernel(
      path: '/usr/bin/chromium',
      kind: SnifferKernelKind.chromium,
    ),
    SnifferKernel(
      path: '/usr/bin/chromium-browser',
      kind: SnifferKernelKind.chromium,
    ),
    SnifferKernel(
      path: '/usr/bin/google-chrome',
      kind: SnifferKernelKind.chrome,
    ),
    SnifferKernel(
      path: '/usr/bin/microsoft-edge',
      kind: SnifferKernelKind.edge,
    ),
  ];

  static bool _defaultFileExists(String path) {
    try {
      return File(path).existsSync();
    } on Object {
      return false;
    }
  }
}
