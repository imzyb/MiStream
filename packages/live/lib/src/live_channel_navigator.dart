import 'package:live/src/live_channel.dart';

/// 数字键缓冲：连续按下的数字拼成一个频道号。
///
/// 电视遥控器上没有输入框，用户按 `1` `2` 想表达的是「第 12 个台」。这个类
/// 只负责把按键拼起来，**不负责超时** —— 超时要挂 Timer，而 Timer 会把纯逻辑
/// 拖进「跑测试要等真实时间」的泥潭。超时由 UI 层决定何时调 [clear]。
class ChannelNumberBuffer {
  /// 以最大位数构造。
  ChannelNumberBuffer({this.maxDigits = 3})
    : assert(maxDigits > 0, '缓冲至少能装一位数字');

  /// 最多保留几位。
  ///
  /// 三位足够：真实直播源里上千个频道的源极少，而位数不设上限的话，用户
  /// 误触键盘会攒出一串天文数字，最后只得到一句「频道不存在」。
  final int maxDigits;

  String _text = '';

  /// 已按下的数字串（形如 `"12"`）。
  String get text => _text;

  /// 缓冲是否为空。
  bool get isEmpty => _text.isEmpty;

  /// 缓冲里的数字；空缓冲返回 `null`。
  ///
  /// 空缓冲返回 `null` 而不是 `0`：`0` 是一个合法的「用户按了 0」，语义不同。
  int? get value => _text.isEmpty ? null : int.parse(_text);

  /// 追加一位数字。
  ///
  /// 缓冲满时**丢掉最旧的一位**而不是忽略这次按键：按满了继续按还能看见
  /// 屏幕上的数字在滚，忽略新输入会让人以为按键坏了。非 0..9 的输入直接
  /// 丢弃（调用方不该传，但静默丢比抛异常更合适——这是 UI 输入路径）。
  void push(int digit) {
    if (digit < 0 || digit > 9) return;
    _text += '$digit';
    if (_text.length > maxDigits) {
      _text = _text.substring(_text.length - maxDigits);
    }
  }

  /// 清空缓冲。
  void clear() => _text = '';

  @override
  String toString() => 'ChannelNumberBuffer($_text)';
}

/// 在频道列表上做「上/下台」与「按号跳台」。
///
/// 刻意是纯 Dart（不碰 Flutter）：键盘映射在 app 层
/// （`apps/mistream/lib/features/live/live_shortcuts.dart`），这里只回答两个
/// 问题 —— 「从第 i 个台往上/下走一个是谁」「用户按了 12 是哪个台」。把这两
/// 件事从 widget 里抽出来，是它们**唯一**能被自动验证的方式：本项目的
/// widget 测试跑不起来（见 `docs/PROGRESS_AUDIT_2026-09-19.md` 环境限制清单）。
class LiveChannelNavigator {
  /// 以当前可见的频道列表构造。
  ///
  /// 传进来的应当是**用户眼前那份列表**（已按分组筛选、已排序）——
  /// 「下一个台」的含义是列表上的下一个，而不是源里的下一个。
  LiveChannelNavigator(List<LiveChannel> channels)
    : _channels = List<LiveChannel>.unmodifiable(channels);

  final List<LiveChannel> _channels;

  /// 当前可见的频道列表。
  List<LiveChannel> get channels => _channels;

  /// 频道个数。
  int get length => _channels.length;

  /// 列表是否为空。
  bool get isEmpty => _channels.isEmpty;

  /// [channelId] 在列表里的下标；不在列表里返回 `null`。
  ///
  /// 「不在列表里」是常态：用户收藏了某台，之后重新导入订阅把它删了。
  /// 这时换台键应当什么都不做，而不是跳到一个不存在的下标上。
  int? indexOfId(String channelId) {
    for (var i = 0; i < _channels.length; i++) {
      if (_channels[i].id == channelId) return i;
    }
    return null;
  }

  /// 从下标 [index] 走 [step] 步，**环绕**。
  ///
  /// 环绕而不是夹在两端：按到底就该回到第一个台。夹住会让用户以为遥控器
  /// 失灵（按了没反应），而回到第一个台至少是明确的行为。
  ///
  /// [index] 越界（-1 / 超出）时按「从第一个台出发」处理 —— 当前频道不在
  /// 列表里时，往下按一次落到第二个台，比什么都不做更符合直觉。
  /// 列表为空时返回 `null`。
  int? moveFrom(int index, int step) {
    final count = _channels.length;
    if (count == 0) return null;
    final from = (index < 0 || index >= count) ? 0 : index;
    return ((from + step) % count + count) % count;
  }

  /// 按频道号找台。编号 **1 起**。
  ///
  /// 判据顺序：
  /// 1. `channelNumber` 字段精确命中 —— 源自己声明了频道号时以它为准；
  /// 2. 否则按**列表位置**（第 N 个台）。
  ///
  /// 越界返回 `null`：由 UI 决定怎么提示（弹一句「频道不存在」），这里不猜。
  /// 返回 `null` 而不是回退到第一个台 —— 用户按了 999 却跳到 CCTV1，比
  /// 明确告诉他「没有这个台」更让人困惑。
  int? indexForNumber(int number) {
    if (number < 1) return null;
    for (var i = 0; i < _channels.length; i++) {
      if (_channels[i].channelNumber == number) return i;
    }
    if (number <= _channels.length) return number - 1;
    return null;
  }

  /// 把 [buffer] 里的数字解析成下标；缓冲为空或越界返回 `null`。
  int? resolveBuffer(ChannelNumberBuffer buffer) {
    final number = buffer.value;
    if (number == null) return null;
    return indexForNumber(number);
  }

  /// 第 [index] 个台；越界返回 `null`。
  LiveChannel? channelAt(int? index) {
    if (index == null || index < 0 || index >= _channels.length) return null;
    return _channels[index];
  }
}
