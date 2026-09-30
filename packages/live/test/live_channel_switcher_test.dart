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

  group('LiveChannelSwitcher 长跑（50 次换台）', () {
    test('连续换台 50 次，每次结果都正确且互不影响', () async {
      // 每个频道的第 2 条线路能播、其余不能 —— 50 次都必须落在「线路 2/3」。
      final switcher = LiveChannelSwitcher(
        probe: (url) async => url.endsWith('/2.m3u8'),
      );

      for (var i = 0; i < 50; i++) {
        final result = await switcher.switchTo(
          LiveChannel(
            id: 'ch$i',
            name: 'CH$i',
            url: 'http://a/$i/1.m3u8',
            extraUrls: ['http://a/$i/2.m3u8', 'http://a/$i/3.m3u8'],
          ),
        );
        expect(result.status, LiveSwitchStatus.playing);
        expect(result.lineIndex, 2);
        expect(result.lineLabel, '线路 2/3');
      }
    });

    test('连续换台 50 次后不持有任何频道与结果', () async {
      final switcher = LiveChannelSwitcher(probe: (_) async => true);

      // ⚠️ 造对象、逼 GC、下判据必须分在三个帧里：在**分配者自己的帧**里
      // 判回收会误判 —— 帧上还留着最后一次迭代的局部变量（实测那会稳定
      // 剩 1 个「未回收」）。
      final refs = await _switchMany(switcher, 50);
      await _gcPressure();

      final alive = refs.where((r) => r.target != null).toList();
      expect(
        alive,
        isEmpty,
        reason: '50 次换台的频道与结果都该可回收（${alive.length} 个仍存活）',
      );
    });

    test('对照：仍被持有的频道不会被回收（证明上面不是空断言）', () async {
      // 若 `WeakReference` 恒为 null，这条会红 —— 它保证上一条测的是
      // 「换台器没留引用」，而不是「探针本身失效」。
      final ref = WeakReference<LiveChannel>(_threeLines);
      await _gcPressure();
      expect(ref.target, same(_threeLines));
    });
  });
}

/// 换台 [count] 次，返回每次的频道与结果的弱引用。
///
/// 刻意**不在这里**做 GC 也不检查：本函数返回后帧就没了，弱引用指向的对象
/// 才真正不可达。
Future<List<WeakReference<Object>>> _switchMany(
  LiveChannelSwitcher switcher,
  int count,
) async {
  final refs = <WeakReference<Object>>[];
  for (var i = 0; i < count; i++) {
    final channel = LiveChannel(
      id: 'ch$i',
      name: 'CH$i',
      url: 'http://a/$i.m3u8',
    );
    refs.add(WeakReference<Object>(channel));
    final result = await switcher.switchTo(channel);
    refs.add(WeakReference<Object>(result));
  }
  return refs;
}

/// 逼 VM 回收不可达对象。
///
/// 反复分配大块内存把新生代挤爆，再让出事件循环。本机 Dart VM 上实测稳定
/// （`.workbuddy-ai/scripts/probe_weakref.dart` 三种写法各 5 轮都是 0 个残留）。
/// 没有这一步，`WeakReference` 断言就是在看运气。
Future<void> _gcPressure() async {
  for (var round = 0; round < 8; round++) {
    final junk = <List<int>>[];
    for (var i = 0; i < 200; i++) {
      junk.add(List<int>.filled(64 * 1024, i));
    }
    junk.clear();
    await Future<void>.delayed(Duration.zero);
  }
}
