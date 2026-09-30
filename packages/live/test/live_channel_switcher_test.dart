import 'dart:async';

import 'package:live/live.dart';
import 'package:test/test.dart';

const _threeLines = LiveChannel(
  id: 'a',
  name: 'CCTV1',
  url: 'http://a/1.m3u8',
  extraUrls: ['http://a/2.m3u8', 'http://a/3.m3u8'],
);

void main() {
  group('LiveChannelSwitcher 按序重试', () {
    test('第一条就能播时不再试后面的', () async {
      final probed = <String>[];
      final switcher = LiveChannelSwitcher(
        probe: (url) async {
          probed.add(url);
          return true;
        },
      );

      final result = await switcher.switchTo(_threeLines);

      expect(result.status, LiveSwitchStatus.playing);
      expect(result.url, 'http://a/1.m3u8');
      expect(result.lineIndex, 1);
      expect(result.lineCount, 3);
      expect(probed, ['http://a/1.m3u8']);
    });

    test('第一条不通时自动试第二条', () async {
      final probed = <String>[];
      final switcher = LiveChannelSwitcher(
        probe: (url) async {
          probed.add(url);
          return url.endsWith('/2.m3u8');
        },
      );

      final result = await switcher.switchTo(_threeLines);

      expect(result.status, LiveSwitchStatus.playing);
      expect(result.url, 'http://a/2.m3u8');
      expect(result.lineIndex, 2);
      expect(result.failures.length, 1);
      expect(result.failures.single.index, 1);
      expect(result.failures.single.error, isNull);
      expect(probed, ['http://a/1.m3u8', 'http://a/2.m3u8']);
    });

    test('探针抛异常也算这条线路失败，继续下一条', () async {
      final switcher = LiveChannelSwitcher(
        probe: (url) async {
          if (url.endsWith('/1.m3u8')) throw StateError('连接被拒绝');
          return true;
        },
      );

      final result = await switcher.switchTo(_threeLines);

      expect(result.isPlaying, isTrue);
      expect(result.failures.single.error, isA<StateError>());
    });

    test('全部线路失败时返回 exhausted 并带上每条失败', () async {
      final switcher = LiveChannelSwitcher(probe: (url) async => false);

      final result = await switcher.switchTo(_threeLines);

      expect(result.status, LiveSwitchStatus.exhausted);
      expect(result.isExhausted, isTrue);
      expect(result.lineIndex, 0);
      expect(result.failures.map((f) => f.index), [1, 2, 3]);
    });

    test('按 allUrls 的顺序试，不重排', () async {
      final probed = <String>[];
      final switcher = LiveChannelSwitcher(
        probe: (url) async {
          probed.add(url);
          return false;
        },
      );

      await switcher.switchTo(_threeLines);

      expect(probed, _threeLines.allUrls);
    });
  });

  group('当前线路标签', () {
    test('单线路频道不显示线路标签', () async {
      final switcher = LiveChannelSwitcher(probe: (url) async => true);

      final result = await switcher.switchTo(
        const LiveChannel(id: 'b', name: 'B', url: 'http://b/1.m3u8'),
      );

      expect(result.lineLabel, '');
    });

    test('多线路频道显示 `线路 n/总数`', () async {
      final switcher = LiveChannelSwitcher(
        probe: (url) async => url.endsWith('/2.m3u8'),
      );

      final result = await switcher.switchTo(_threeLines);

      expect(result.lineLabel, '线路 2/3');
    });

    test('全部失败时没有线路标签', () async {
      final switcher = LiveChannelSwitcher(probe: (url) async => false);

      final result = await switcher.switchTo(_threeLines);

      expect(result.lineLabel, '');
    });
  });

  group('取消', () {
    test('换台途中又换了别的台，旧的换台被作废', () async {
      final first = Completer<bool>();
      final second = Completer<bool>();
      var call = 0;
      final switcher = LiveChannelSwitcher(
        probe: (url) {
          call++;
          return call == 1 ? first.future : second.future;
        },
      );

      final oldSwitch = switcher.switchTo(_threeLines);
      final newSwitch = switcher.switchTo(
        const LiveChannel(id: 'b', name: 'B', url: 'http://b/1.m3u8'),
      );

      second.complete(true);
      first.complete(true);

      expect((await newSwitch).status, LiveSwitchStatus.playing);
      expect(
        (await oldSwitch).status,
        LiveSwitchStatus.cancelled,
        reason: '旧换台的探针即使返回成功也不能再起播，否则会和新的流抢播放器',
      );
    });

    test('cancel() 作废正在进行的换台', () async {
      final gate = Completer<bool>();
      final switcher = LiveChannelSwitcher(probe: (url) => gate.future);

      final pending = switcher.switchTo(_threeLines);
      switcher.cancel();
      gate.complete(true);

      expect((await pending).status, LiveSwitchStatus.cancelled);
    });

    test('已完成的换台不受后续 cancel 影响', () async {
      final switcher = LiveChannelSwitcher(probe: (url) async => true);

      final result = await switcher.switchTo(_threeLines);
      switcher.cancel();

      expect(result.status, LiveSwitchStatus.playing);
    });

    test('作废后不再继续试剩下的线路', () async {
      final gate = Completer<bool>();
      var probes = 0;
      final switcher = LiveChannelSwitcher(
        probe: (url) {
          probes++;
          return gate.future;
        },
      );

      final pending = switcher.switchTo(_threeLines);
      switcher.cancel();
      gate.complete(false);

      expect((await pending).status, LiveSwitchStatus.cancelled);
      expect(probes, 1, reason: '作废后不该再去试第 2、3 条线路');
    });
  });
}
