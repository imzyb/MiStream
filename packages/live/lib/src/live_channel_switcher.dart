import 'package:live/src/live_channel.dart';

/// 试播一条线路：能起播返回 `true`，否则 `false`。
///
/// **必须可注入**。真实实现要起播放器、等首帧、判超时，这些东西在测试里
/// 既慢又不可靠（本项目的沙箱还禁止本地回环）。把「能不能播」抽成一个
/// 函数，重试策略才可能被真正覆盖到 —— 否则「按序重试」永远只有人工点
/// 一遍才能验证。
///
/// 实现方需要自己负责超时：这个函数不返回之前，[LiveChannelSwitcher] 会
/// 一直等它。
typedef LiveLineProbe = Future<bool> Function(String url);

/// 一条线路的失败记录。
class LiveLineFailure {
  /// 构造失败记录。
  const LiveLineFailure({
    required this.index,
    required this.url,
    this.error,
  });

  /// 线路序号（1 起，与用户看到的编号一致）。
  final int index;

  /// 线路地址。
  final String url;

  /// 抛出的异常；`null` 表示「试通了但探针说播不了」。
  final Object? error;
}

/// 换台结局。
enum LiveSwitchStatus {
  /// 某条线路起播成功。
  playing,

  /// 所有线路都试过，没有一条能播。
  exhausted,

  /// 中途被取消 —— 用户又换了别的台，或页面关了。
  cancelled,
}

/// 换台结果。
class LiveSwitchResult {
  /// 构造结果。
  const LiveSwitchResult({
    required this.status,
    required this.channel,
    required this.lineCount,
    this.lineIndex = 0,
    this.url,
    this.failures = const [],
  });

  /// 结局。
  final LiveSwitchStatus status;

  /// 目标频道。
  final LiveChannel channel;

  /// 该频道共有多少条线路。
  final int lineCount;

  /// 当前线路序号（1 起）；0 表示没有可播线路。
  final int lineIndex;

  /// 当前线路地址。
  final String? url;

  /// 失败记录，按尝试顺序。
  final List<LiveLineFailure> failures;

  /// 是否已起播。
  bool get isPlaying => status == LiveSwitchStatus.playing;

  /// 是否所有线路都试过且都失败。
  bool get isExhausted => status == LiveSwitchStatus.exhausted;

  /// 展示用的线路标签，形如 `线路 2/3`。
  ///
  /// 单线路频道返回空串：只有一个源的时候显示「线路 1/1」纯属噪音。
  String get lineLabel {
    if (lineCount <= 1 || lineIndex <= 0) return '';
    return '线路 $lineIndex/$lineCount';
  }
}

/// 多线路换台：按序试一个频道的每条地址，直到有一条能播。
///
/// 真实直播源里同一频道挂多条地址是常态（实测 `live.zbds.top` 的 CCTV1
/// 有三条），单条线路挂掉不能等于这个频道不能看。这里的职责只有「按序试
/// 到成功为止」以及「把当前是第几条线路报出去」。
///
/// ⚠️ 不在职责内的两件事，别往这里塞：
/// - **保留上一路画面直到新流首帧** —— 那是 UI 层的事，需要真实播放器；
/// - **记住上次成功的线路** —— 一个合理的优化（省掉每次从第一条重试的
///   开销），但会引入跨频道的状态，等有实测数据说它值得再做。
class LiveChannelSwitcher {
  /// 以试播函数构造。
  LiveChannelSwitcher({required LiveLineProbe probe}) : _probe = probe;

  final LiveLineProbe _probe;

  /// 换台世代号。每次 [switchTo] 自增，旧的循环看到号变了就自己退出。
  ///
  /// 用世代号而不是 `bool cancelled` 标志：标志是全局的，第二次换台会把
  /// 标志复位，于是第一次的循环又「复活」了 —— 快速连按几十次换台键时，
  /// 多个循环会同时往播放器里塞流。世代号是单调的，每个循环只认自己那一代。
  int _generation = 0;

  /// 切到 [channel]，按序试它的每条线路。
  ///
  /// 调用它会自动作废上一次还没跑完的换台。
  Future<LiveSwitchResult> switchTo(LiveChannel channel) async {
    final generation = ++_generation;
    final urls = channel.allUrls;
    final failures = <LiveLineFailure>[];

    for (var i = 0; i < urls.length; i++) {
      if (generation != _generation) {
        return LiveSwitchResult(
          status: LiveSwitchStatus.cancelled,
          channel: channel,
          lineCount: urls.length,
          lineIndex: i,
          failures: failures,
        );
      }

      final url = urls[i];
      try {
        final ok = await _probe(url);
        // ⚠️ 探针是异步的：等它的这段时间里用户完全可能又换了一次台。
        // 只靠循环开头的检查是不够的 —— 那次检查发生在 await **之前**，
        // 于是「上一次换台的探针慢吞吞地成功了」会照样起播，和新流抢播放器
        // （表现是画面来回跳）。await 之后必须重新确认自己还是当前那一代。
        if (generation != _generation) {
          return LiveSwitchResult(
            status: LiveSwitchStatus.cancelled,
            channel: channel,
            lineCount: urls.length,
            lineIndex: i,
            failures: failures,
          );
        }
        if (ok) {
          return LiveSwitchResult(
            status: LiveSwitchStatus.playing,
            channel: channel,
            lineCount: urls.length,
            lineIndex: i + 1,
            url: url,
            failures: failures,
          );
        }
        failures.add(LiveLineFailure(index: i + 1, url: url));
      } on Object catch (error) {
        failures.add(LiveLineFailure(index: i + 1, url: url, error: error));
      }
    }

    return LiveSwitchResult(
      status: LiveSwitchStatus.exhausted,
      channel: channel,
      lineCount: urls.length,
      failures: failures,
    );
  }

  /// 主动作废正在进行的换台（页面关闭时用）。
  void cancel() {
    _generation++;
  }
}
