/// 数字键跳台与方向键换台的验证。
///
/// 这两件事的**全部**逻辑都在 `LiveChannelNavigator` 与 `ChannelNumberBuffer`
/// 里 —— app 层那份键盘映射（`live_shortcuts.dart`）只做「哪个键 → 哪个动作」
/// 的查表，没有可测的判断。所以用例集中在这里，把行为规则钉死：环绕、
/// 越界返回 null、频道号字段优先于列表位置、缓冲满时丢最旧的一位。
library;

import 'package:live/live.dart';
import 'package:test/test.dart';

LiveChannel _ch(String name, {String? id, int? number}) => LiveChannel(
  id: id ?? name,
  name: name,
  url: 'http://a/${id ?? name}.m3u8',
  channelNumber: number,
);

/// 造一份 `CH1..CHn` 的列表。
List<LiveChannel> _list(int count) => [
  for (var i = 1; i <= count; i++) _ch('CH$i', id: 'ch$i'),
];

void main() {
  group('ChannelNumberBuffer', () {
    test('连续按下的数字拼起来', () {
      final buffer = ChannelNumberBuffer();
      expect(buffer.isEmpty, isTrue);
      expect(buffer.value, isNull);

      buffer.push(1);
      buffer.push(2);
      expect(buffer.text, '12');
      expect(buffer.value, 12);
    });

    test('空缓冲的 value 是 null 而不是 0', () {
      // 0 是「用户按了 0」这个合法输入，与「什么都没按」必须分得开。
      final buffer = ChannelNumberBuffer();
      expect(buffer.value, isNull);
      buffer.push(0);
      expect(buffer.value, 0);
      expect(buffer.text, '0');
    });

    test('超出最大位数时丢掉最旧的一位', () {
      final buffer = ChannelNumberBuffer(maxDigits: 3);
      [1, 2, 3, 4].forEach(buffer.push);
      // 按满了继续按还能看见数字滚动；忽略新输入会让人以为按键坏了。
      expect(buffer.text, '234');
      buffer.push(5);
      expect(buffer.text, '345');
    });

    test('非 0..9 的输入被丢弃，不影响已有内容', () {
      final buffer = ChannelNumberBuffer()..push(7);
      buffer
        ..push(-1)
        ..push(10)
        ..push(99);
      expect(buffer.text, '7');
    });

    test('clear 之后回到空状态', () {
      final buffer = ChannelNumberBuffer()
        ..push(9)
        ..push(9);
      buffer.clear();
      expect(buffer.isEmpty, isTrue);
      expect(buffer.value, isNull);
      expect(buffer.text, '');
    });

    test('maxDigits 为 1 时只留最新一位', () {
      // 不测构造函数的 assert：垫片用 `dart run` 跑，断言在这个模式下不生效
      // （实测 `maxDigits: 0` 不会抛），写了也是一条永远绿的假用例。
      final buffer = ChannelNumberBuffer(maxDigits: 1);
      buffer
        ..push(3)
        ..push(7);
      expect(buffer.text, '7');
    });
  });

  group('LiveChannelNavigator — 定位', () {
    test('indexOfId 命中与未命中', () {
      final navigator = LiveChannelNavigator(_list(3));
      expect(navigator.indexOfId('ch2'), 1);
      // 频道被重新导入后删掉了：换台键应当什么都不做，而不是跳到错误的下标。
      expect(navigator.indexOfId('不存在'), isNull);
    });

    test('indexOfId 在空列表上返回 null', () {
      expect(LiveChannelNavigator(const []).indexOfId('ch1'), isNull);
    });

    test('channels / length / isEmpty 反映入参', () {
      final navigator = LiveChannelNavigator(_list(4));
      expect(navigator.length, 4);
      expect(navigator.isEmpty, isFalse);
      expect(navigator.channels, hasLength(4));
      expect(LiveChannelNavigator(const []).isEmpty, isTrue);
    });

    test('内部列表不可变，外部改不动', () {
      final source = _list(2);
      final navigator = LiveChannelNavigator(source);
      expect(() => navigator.channels.clear(), throwsUnsupportedError);
    });

    test('channelAt 越界与 null 都返回 null', () {
      final navigator = LiveChannelNavigator(_list(3));
      expect(navigator.channelAt(2)?.id, 'ch3');
      expect(navigator.channelAt(-1), isNull);
      expect(navigator.channelAt(3), isNull);
      expect(navigator.channelAt(null), isNull);
    });
  });

  group('LiveChannelNavigator — 上/下台', () {
    test('往下走一格', () {
      final navigator = LiveChannelNavigator(_list(5));
      expect(navigator.moveFrom(0, 1), 1);
      expect(navigator.moveFrom(3, 1), 4);
    });

    test('往上走一格', () {
      final navigator = LiveChannelNavigator(_list(5));
      expect(navigator.moveFrom(3, -1), 2);
    });

    test('末尾再往下环绕回第一个', () {
      final navigator = LiveChannelNavigator(_list(5));
      // 环绕而不是夹住：按到底就该回到第一个台。夹住会让用户以为遥控器失灵。
      expect(navigator.moveFrom(4, 1), 0);
    });

    test('第一个再往上环绕到最后一个', () {
      final navigator = LiveChannelNavigator(_list(5));
      expect(navigator.moveFrom(0, -1), 4);
    });

    test('空列表返回 null', () {
      expect(LiveChannelNavigator(const []).moveFrom(0, 1), isNull);
      expect(LiveChannelNavigator(const []).moveFrom(0, -1), isNull);
    });

    test('单元素列表原地环绕', () {
      final navigator = LiveChannelNavigator(_list(1));
      expect(navigator.moveFrom(0, 1), 0);
      expect(navigator.moveFrom(0, -1), 0);
    });

    test('当前下标越界时按「从第一个台出发」处理', () {
      // 当前频道不在可见列表里（换了分组筛选）时，往下按一次落到第二个台，
      // 比什么都不做更符合直觉。
      final navigator = LiveChannelNavigator(_list(5));
      expect(navigator.moveFrom(-1, 1), 1);
      expect(navigator.moveFrom(99, 1), 1);
    });
  });

  group('LiveChannelNavigator — 按号跳台', () {
    test('1 起编号映射到列表位置', () {
      final navigator = LiveChannelNavigator(_list(5));
      expect(navigator.indexForNumber(1), 0);
      expect(navigator.indexForNumber(5), 4);
    });

    test('0 与越界都返回 null', () {
      final navigator = LiveChannelNavigator(_list(5));
      // 不回退到第一个台：按了 999 却跳到 CH1，比明确说「没有这个台」更困惑。
      expect(navigator.indexForNumber(0), isNull);
      expect(navigator.indexForNumber(-1), isNull);
      expect(navigator.indexForNumber(6), isNull);
      expect(navigator.indexForNumber(999), isNull);
    });

    test('源声明了 channelNumber 时以它为准', () {
      // 手工造的频道号：第 1 个台声明自己是 8 号。
      final navigator = LiveChannelNavigator([
        _ch('CCTV1', id: 'a', number: 8),
        _ch('CCTV2', id: 'b', number: 2),
      ]);
      expect(navigator.indexForNumber(8), 0);
      expect(navigator.indexForNumber(2), 1);
      // 没有任何台声明 1 号，于是退回到「列表位置」：第 1 个台。
      expect(navigator.indexForNumber(1), 0);
    });

    test('空列表上任何号都返回 null', () {
      final navigator = LiveChannelNavigator(const []);
      expect(navigator.indexForNumber(1), isNull);
    });
  });

  group('LiveChannelNavigator — 缓冲解析', () {
    test('空缓冲解析成 null', () {
      final navigator = LiveChannelNavigator(_list(12));
      expect(navigator.resolveBuffer(ChannelNumberBuffer()), isNull);
    });

    test('按 1 2 跳到第 12 个台', () {
      final navigator = LiveChannelNavigator(_list(12));
      final buffer = ChannelNumberBuffer()
        ..push(1)
        ..push(2);
      expect(navigator.resolveBuffer(buffer), 11);
      expect(navigator.channelAt(navigator.resolveBuffer(buffer))?.id, 'ch12');
    });

    test('数字越界解析成 null', () {
      final navigator = LiveChannelNavigator(_list(12));
      final buffer = ChannelNumberBuffer()
        ..push(9)
        ..push(9)
        ..push(9);
      expect(navigator.resolveBuffer(buffer), isNull);
    });
  });
}
