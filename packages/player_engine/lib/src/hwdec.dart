/// 硬件解码方式、平台优先级链，以及自动降级的判定策略。
library;

import 'dart:io';

import 'package:meta/meta.dart';

/// 一种硬解方式。
///
/// 取值即 mpv `hwdec` 属性的合法值，不做二次抽象——`-copy` 后缀在 mpv 里有
/// 确切含义（解码后把帧拷回系统内存，兼容性最好、开销略高），把它归并成一个
/// 布尔「是否硬解」会直接丢掉 `docs/04-播放器设计.md` §5 那张优先级链表。
enum HwdecMethod {
  /// 让 mpv 自行选择，不做安全性过滤。
  auto('auto'),

  /// 仅对白名单编码启用硬解。§5 规则 1 的默认值。
  autoSafe('auto-safe'),

  /// 自动选择，但强制走 `-copy` 路径。
  autoCopy('auto-copy'),

  /// Windows：Direct3D 11 视频加速，帧拷回系统内存。
  d3d11vaCopy('d3d11va-copy'),

  /// Windows：Direct3D 11 视频加速，零拷贝。
  d3d11va('d3d11va'),

  /// Windows：DXVA2，帧拷回系统内存。老显卡的兜底。
  dxva2Copy('dxva2-copy'),

  /// macOS：VideoToolbox，帧拷回系统内存。
  videotoolboxCopy('videotoolbox-copy'),

  /// macOS：VideoToolbox，零拷贝。
  videotoolbox('videotoolbox'),

  /// Linux：NVIDIA NVDEC，帧拷回系统内存。
  nvdecCopy('nvdec-copy'),

  /// Linux：VA-API，帧拷回系统内存。
  vaapiCopy('vaapi-copy'),

  /// Linux：VA-API，零拷贝。
  vaapi('vaapi'),

  /// 软解。永远是优先级链的最后一档。
  none('no');

  const HwdecMethod(this.mpvValue);

  /// 写给 mpv `hwdec` 属性的值。
  final String mpvValue;

  /// 是否是软解。
  bool get isSoftware => this == HwdecMethod.none;

  /// 按 mpv 取值反查。`hwdec-current` 读回来的字符串走这里。
  ///
  /// 认不出的取值返回 `null` 而不是抛异常：mpv 可能在新版本里给出我们还没见
  /// 过的后端名，那不该让播放中断。调用方把 `null` 当作「未知但在硬解」处理。
  static HwdecMethod? fromMpvValue(String value) {
    for (final method in HwdecMethod.values) {
      if (method.mpvValue == value) return method;
    }
    return null;
  }
}

/// 硬解链所针对的平台。
///
/// 单独一个枚举而不是直接用 `dart:io` 的 [Platform]：优先级链是纯数据，
/// 应该能在任意平台上被测试。否则「Linux 的链对不对」这条用例只能在 Linux
/// 跑，而 CI 的三平台矩阵里每台机器只能验三分之一。
enum HwdecPlatform {
  /// Windows。
  windows,

  /// macOS。
  macos,

  /// Linux。
  linux,

  /// 其它平台，只有软解。
  other;

  /// 当前进程所在的平台。
  static HwdecPlatform get current {
    if (Platform.isWindows) return HwdecPlatform.windows;
    if (Platform.isMacOS) return HwdecPlatform.macos;
    if (Platform.isLinux) return HwdecPlatform.linux;
    return HwdecPlatform.other;
  }
}

/// 一条有序的硬解降级链。
///
/// 对应 `docs/04-播放器设计.md` §5 的平台优先级表。不变量：最后一档恒为
/// [HwdecMethod.none]。少了它，降级到链尾就无路可走，而「软解」永远是有路
/// 可走的——这正是「硬解失败不该黑屏」的兜底。
@immutable
final class HwdecChain {
  /// 按给定顺序构造。若末位不是软解，会自动补上。
  factory HwdecChain(List<HwdecMethod> methods) {
    final normalized = [
      ...methods.where((m) => !m.isSoftware),
      HwdecMethod.none,
    ];
    return HwdecChain._(List.unmodifiable(normalized));
  }

  const HwdecChain._(this.methods);

  /// 取 [platform] 的默认链（§5 那张表）。
  factory HwdecChain.forPlatform(HwdecPlatform platform) => switch (platform) {
    HwdecPlatform.windows => HwdecChain(const [
      HwdecMethod.d3d11vaCopy,
      HwdecMethod.d3d11va,
      HwdecMethod.dxva2Copy,
    ]),
    HwdecPlatform.macos => HwdecChain(const [
      HwdecMethod.videotoolboxCopy,
      HwdecMethod.videotoolbox,
    ]),
    HwdecPlatform.linux => HwdecChain(const [
      HwdecMethod.nvdecCopy,
      HwdecMethod.vaapiCopy,
      HwdecMethod.vaapi,
    ]),
    HwdecPlatform.other => HwdecChain(const []),
  };

  /// 取当前平台的默认链。
  factory HwdecChain.platformDefault() =>
      HwdecChain.forPlatform(HwdecPlatform.current);

  /// 只用软解，不尝试任何硬解。
  ///
  /// 用户在设置里关掉硬解，或某个源被记录过硬解失败时用它
  /// （§5 规则 4 的「下次同类内容直接用有效配置起播」）。
  factory HwdecChain.softwareOnly() => HwdecChain(const []);

  /// 链上的各档，末位恒为 [HwdecMethod.none]。
  final List<HwdecMethod> methods;

  /// 首选档。
  HwdecMethod get first => methods.first;

  /// 是否只有软解一档。
  bool get isSoftwareOnly => methods.length == 1;

  /// [current] 之后的下一档；已在末位则返回 `null`。
  ///
  /// [current] 不在链上时返回软解——出现这种情况说明是用户在设置里强制指定
  /// 了某个硬解方式（§5 规则 3），它失败之后没有「链上的下一档」可谈，直接
  /// 落到兜底。
  HwdecMethod? next(HwdecMethod current) {
    final index = methods.indexOf(current);
    if (index < 0) return HwdecMethod.none;
    if (index >= methods.length - 1) return null;
    return methods[index + 1];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HwdecChain &&
          other.methods.length == methods.length &&
          _sameOrder(other.methods, methods));

  @override
  int get hashCode => Object.hashAll(methods);

  @override
  String toString() =>
      'HwdecChain(${methods.map((m) => m.mpvValue).join(' → ')})';

  static bool _sameOrder(List<HwdecMethod> a, List<HwdecMethod> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 何时判定「硬解不行，降级」。
///
/// `docs/04-播放器设计.md` §5 规则 2 写的是「首次解码在 3 秒内产生 ≥N 次解码
/// 错误」，没有给出 N。这里取 3：再少会把偶发的坏帧误判成硬解不可用，再多则
/// 用户已经看了好几秒花屏。这个值是可调的，不是从测量得来的常数。
@immutable
final class HwdecFallbackPolicy {
  /// 构造一条判定策略。
  const HwdecFallbackPolicy({
    this.window = const Duration(seconds: 3),
    this.errorThreshold = 3,
  }) : assert(errorThreshold > 0, 'errorThreshold 必须为正');

  /// 只在起播后这段时间内统计。
  final Duration window;

  /// 窗口内达到几次解码错误就降级。
  final int errorThreshold;
}

/// 按 [HwdecFallbackPolicy] 累计解码错误并给出降级判定。
///
/// 时间由调用方以「距起播多久」的形式传入，而不是内部读时钟：判定逻辑因此
/// 完全可测，不需要为了测三秒窗口真的等三秒，也不需要注入假时钟。
final class HwdecFallbackDetector {
  /// 按 [policy] 构造。
  HwdecFallbackDetector({
    this.policy = const HwdecFallbackPolicy(),
  });

  /// 判定策略。
  final HwdecFallbackPolicy policy;

  int _errorsInWindow = 0;
  bool _tripped = false;

  /// 窗口内已计入的解码错误次数。
  int get errorCount => _errorsInWindow;

  /// 是否已经判定为需要降级。
  bool get hasTripped => _tripped;

  /// 记一次解码错误，[sinceOpen] 是距本次 `open()` 的时长。
  ///
  /// 返回 `true` 表示「就是这一次让它越过阈值的」——调用方据此**只**降级一
  /// 次并只提示一次。之后继续报错也只返回 `false`，否则一段花屏会刷出十几条
  /// 「已降级到软解」的提示。
  bool recordDecodeError(Duration sinceOpen) {
    if (_tripped) return false;
    if (sinceOpen > policy.window) return false;

    _errorsInWindow++;
    if (_errorsInWindow < policy.errorThreshold) return false;

    _tripped = true;
    return true;
  }

  /// 换了媒体或换了硬解档位后重新开始统计。
  void reset() {
    _errorsInWindow = 0;
    _tripped = false;
  }
}
