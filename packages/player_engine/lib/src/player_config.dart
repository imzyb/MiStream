/// 引擎初始化参数。
library;

import 'package:meta/meta.dart';
import 'package:player_engine/src/hwdec.dart';
import 'package:player_engine/src/player_log.dart';

/// 网络中断后的重连策略。
///
/// `docs/04-播放器设计.md` §6 写的是「指数退避重连（1s/2s/4s/8s，上限 5 次），
/// 保持当前播放位置」。文档列了四个延迟却给了五次上限，这里的读法是：延迟按
/// 2 的幂递增但**封顶在 [maxDelay]**，第五次仍等 8 秒。让它一路涨到 16 秒对
/// 用户没有意义——人在第 30 秒还盯着转圈的时候，早就自己点重试了。
@immutable
final class ReconnectPolicy {
  /// 构造一条重连策略。
  const ReconnectPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 8),
    this.maxAttempts = 5,
  }) : assert(maxAttempts >= 0, 'maxAttempts 不能为负');

  /// 完全不重连。
  static const none = ReconnectPolicy(maxAttempts: 0);

  /// 首次重连前等待的时长。
  final Duration initialDelay;

  /// 单次等待的上限。
  final Duration maxDelay;

  /// 最多重连几次。
  final int maxAttempts;

  /// 是否启用重连。
  bool get isEnabled => maxAttempts > 0;

  /// 第 [attempt] 次重连前应等待多久，[attempt] 从 1 开始。
  ///
  /// 超过 [maxAttempts] 返回 `null`，表示不再重连。
  Duration? delayForAttempt(int attempt) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', '重连次数从 1 开始');
    }
    if (attempt > maxAttempts) return null;

    final scaled = initialDelay * (1 << (attempt - 1));
    return scaled > maxDelay ? maxDelay : scaled;
  }
}

/// 引擎初始化参数。
@immutable
final class PlayerConfig {
  /// 构造一份配置。
  const PlayerConfig({
    this.hwdec,
    this.hwdecFallback = const HwdecFallbackPolicy(),
    this.vodCacheBytes = 64 * 1024 * 1024,
    this.liveCacheBytes = 16 * 1024 * 1024,
    this.reconnect = const ReconnectPolicy(),
    this.proxy,
    this.logLevel = PlayerLogLevel.warn,
    this.positionUpdateInterval = const Duration(milliseconds: 250),
    this.keepAudioPitch = true,
  }) : assert(vodCacheBytes > 0, 'vodCacheBytes 必须为正'),
       assert(liveCacheBytes > 0, 'liveCacheBytes 必须为正');

  /// 硬解优先级链；`null` 表示用当前平台的默认链。
  ///
  /// 不在构造函数里直接调 `HwdecChain.platformDefault()` 作默认值：那会让
  /// 这个类的默认构造依赖 `dart:io` 的平台判断，于是「在 Linux 上测 Windows
  /// 的配置」就做不到了。留 `null` 由引擎在 `initialize` 时解析。
  final HwdecChain? hwdec;

  /// 何时判定硬解不可用并降级。
  final HwdecFallbackPolicy hwdecFallback;

  /// 点播的解复用缓冲上限（字节）。
  final int vodCacheBytes;

  /// 直播的解复用缓冲上限（字节）。低延迟优先，所以比点播小得多。
  final int liveCacheBytes;

  /// 网络中断后的重连策略。
  final ReconnectPolicy reconnect;

  /// 代理地址。
  ///
  /// `docs/04-播放器设计.md` §6：全局代理必须同时作用于 Dio 与 mpv，只配一
  /// 边会出现「列表能刷出来但播不了」这种最难排查的现象。
  final Uri? proxy;

  /// 透出多详细的内核日志。
  final PlayerLogLevel logLevel;

  /// 播放位置的上报间隔。
  ///
  /// 默认 250ms 即 §3 要求的「节流至 ~4Hz」。进度条只有几百像素宽，一秒推
  /// 送几十次位置除了唤醒 UI 线程之外不产生任何可见差别。
  final Duration positionUpdateInterval;

  /// 变速时是否保持音高（mpv 的 `af=scaletempo2`）。
  final bool keepAudioPitch;

  /// 取实际生效的硬解链：未指定时回落到当前平台默认。
  HwdecChain resolveHwdecChain() => hwdec ?? HwdecChain.platformDefault();

  /// 按是否直播取缓冲上限。
  int cacheBytesFor({required bool isLive}) =>
      isLive ? liveCacheBytes : vodCacheBytes;

  /// 复制并覆盖部分字段。
  PlayerConfig copyWith({
    HwdecChain? hwdec,
    HwdecFallbackPolicy? hwdecFallback,
    int? vodCacheBytes,
    int? liveCacheBytes,
    ReconnectPolicy? reconnect,
    Uri? proxy,
    PlayerLogLevel? logLevel,
    Duration? positionUpdateInterval,
    bool? keepAudioPitch,
  }) => PlayerConfig(
    hwdec: hwdec ?? this.hwdec,
    hwdecFallback: hwdecFallback ?? this.hwdecFallback,
    vodCacheBytes: vodCacheBytes ?? this.vodCacheBytes,
    liveCacheBytes: liveCacheBytes ?? this.liveCacheBytes,
    reconnect: reconnect ?? this.reconnect,
    proxy: proxy ?? this.proxy,
    logLevel: logLevel ?? this.logLevel,
    positionUpdateInterval:
        positionUpdateInterval ?? this.positionUpdateInterval,
    keepAudioPitch: keepAudioPitch ?? this.keepAudioPitch,
  );
}
