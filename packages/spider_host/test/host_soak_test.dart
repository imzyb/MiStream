import 'dart:async';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/host/host_api.dart';
import 'package:spider_host/src/host/spider_host.dart';
import 'package:test/test.dart';

import 'support/child_staging.dart';
import 'support/tcp_process_launcher.dart';

/// 真子进程的长跑与崩溃循环验收（ROADMAP M5「源崩溃 100% 不影响主进程」）。
///
/// 已有测试各自差一截：`spider_host_test.dart` 用**假进程**，状态机能验但验不到
/// 真进程生命周期；`real_process_host_test.dart` 用真进程，但只走正常路径。
/// 这里补的是中间的空白：**真子进程反复被强杀**，看宿主能不能一直自愈、
/// 会不会多起进程、会不会泄漏。
///
/// 循环规模可用环境变量放大到真机长跑：
///
/// ```bash
/// # 固定轮数（默认 8 轮，CI 友好）
/// MISTREAM_SOAK_CYCLES=200 dart run test/host_soak_test.dart
/// # 按时间跑（2 小时长跑验收）
/// MISTREAM_SOAK_SECONDS=7200 dart run test/host_soak_test.dart
/// ```
///
/// 本文件必须 `cd packages/spider_host` 再跑：子进程桩走的是相对路径。
void main() {
  group('SpiderHost 真子进程长跑', () {
    late List<LaunchedChild> children;
    late Directory stubDir;

    // 在 group 层读：`test` 的超时要按它算，见 [soakTimeout]。
    final maxCycles = envInt('MISTREAM_SOAK_CYCLES', 8);
    final maxSeconds = envInt('MISTREAM_SOAK_SECONDS', 0);

    setUp(() {
      children = [];
      // 桩先搬到本机 C: 盘再跑。长跑每轮都要起一个 `dart run`，就地跑会读
      // I: 盘（虚拟化文件系统）的 package_config —— 8660 轮后开始被系统
      // 拒绝访问，子进程起不来，整条长跑判红。见 [stageChildStubs]。
      stubDir = stageChildStubs([
        resolveTestSupportFile('rpc_child.dart'),
        resolveTestSupportFile('rpc_child_crash.dart'),
      ]);
    });

    tearDown(() async {
      // 收尾：把还活着的子进程都杀掉，别留下孤儿。
      for (final child in children) {
        child.process.kill();
      }
      cleanChildStubs();
    });

    /// 桩在本机磁盘上的绝对路径。
    String stubPath(String name) =>
        '${stubDir.path}${Platform.pathSeparator}$name';

    /// 造宿主。[onSpawn] 在每次子进程真正起来后回调，用来计数。
    SpiderHost newHost({required int threshold, void Function()? onSpawn}) {
      final base = tcpProcessLauncher(children: children);
      return SpiderHost(
        executable: Platform.resolvedExecutable,
        arguments: ['run', stubPath('rpc_child.dart')],
        sourceTearDownsPerProcess: threshold,
        // 退避压到 0：长跑要的是「崩溃—自愈」的循环次数，不是等退避。
        backoffFor: (_) => Duration.zero,
        launcher: onSpawn == null
            ? base
            : (executable, args) async {
                final proc = await base(executable, args);
                onSpawn();
                return proc;
              },
        hostApi: HostApi(),
      );
    }

    test('反复真崩溃后自愈：进程数恰好 1+N，宿主内存不无界增长', () async {
      // 累计启动过的子进程数。Dart 闭包捕获的是**变量**，所以这里加得出去。
      var spawned = 0;
      final host = newHost(threshold: 999, onSpawn: () => spawned++);
      addTearDown(host.dispose);

      final started = await host.start().timeout(const Duration(seconds: 30));
      expect(started.isOk, isTrue, reason: '初始握手应当成功');
      expect(spawned, 1);

      // 每轮结束后采一次宿主 RSS。预热段丢掉：首次分配（缓冲区、定时器表、
      // 符号表）不是泄漏，算进去会把基线压低、制造假阳性。
      final rssSamples = <int>[];
      const warmupSamples = 2;

      final stopwatch = Stopwatch()..start();
      var cycle = 0;
      while (true) {
        // 按轮数或按时间结束，两者给一个即可。
        if (maxSeconds > 0) {
          if (stopwatch.elapsed.inSeconds >= maxSeconds) break;
        } else if (cycle >= maxCycles) {
          break;
        }

        // 崩溃前必须是就绪的，否则这一轮什么都没验到。
        expect(host.isReady, isTrue, reason: '第 $cycle 轮开始时宿主应当就绪');

        // 真崩溃：SIGKILL，不给它优雅退出的机会。这就是「源崩溃」。
        children.last.process.kill(ProcessSignal.sigkill);

        // 宿主应当自己发现、重启、重新握手就绪 —— 全程没有外部干预。
        final recovered = await waitFor(
          () => spawned >= cycle + 2 && host.isReady,
          timeout: const Duration(seconds: 30),
        );
        expect(recovered, isTrue, reason: '第 $cycle 轮崩溃后宿主没能自愈');
        // 主进程还活着才会走到这里，这就是「源崩溃不影响主进程」。
        expect(host.isReady, isTrue);

        // 收掉刚被换下来的死进程，并**摘掉引用**。
        //
        // 这步是必须的：`ProcessInfo.currentRss` 量的是**本测试进程**，而子进程
        // 对象挂在 `children` 上。不摘的话测试自己就随轮数线性增长，量出来的
        // 「宿主内存增长」根本分不清是宿主泄漏还是测试在攒垃圾 —— 686 轮那次
        // 就多算了约 48MB，险些据此得出错误结论。
        while (children.length > 1) {
          final dead = children.removeAt(0);
          await dead.process.exitCode.timeout(
            const Duration(seconds: 10),
            onTimeout: () => fail('第 $cycle 轮被换下的子进程没退出，成了孤儿'),
          );
        }

        cycle++;
        rssSamples.add(ProcessInfo.currentRss);
        // 长跑时每 50 轮打一个点：一次运行就能看出增长是**线性**（真泄漏）
        // 还是**收敛/抖动**（GC 滞后），不必靠多次运行对比端点。
        if (cycle % 50 == 0) {
          // ignore: avoid_print - 同上
          print('  [第 $cycle 轮] 宿主 RSS ${mb(ProcessInfo.currentRss)}');
        }
      }

      expect(cycle, greaterThan(0), reason: '一轮都没跑，配置有问题');

      // 每轮崩溃恰好换一个新进程：多了说明重复建宿主（历史上真出过），
      // 少了说明某次崩溃没被宿主发现。
      expect(spawned, cycle + 1, reason: '每轮崩溃应当恰好拉起一个新子进程，不多不少');

      if (rssSamples.length > warmupSamples) {
        final baseline = rssSamples[warmupSamples];
        final end = rssSamples.last;
        final growthMb = (end - baseline) / (1024 * 1024);
        // ignore: avoid_print - 长跑护栏要打出实测值供人工/真机核对
        print(
          '宿主 RSS: 基线 ${mb(baseline)} → 结束 ${mb(end)}'
          '（增长 ${growthMb.toStringAsFixed(1)}MB，共 $cycle 轮， '
          '耗时 ${stopwatch.elapsed.inSeconds}s）',
        );
        // 护栏不是精确基准：挡的是「每轮崩溃都泄漏」这类无界增长。
        expect(
          growthMb,
          lessThan(64),
          reason: '每轮崩溃都在宿主侧泄漏的话，长跑必然 OOM',
        );
      } else {
        // 样本不够就明说，别装作验过了 —— 静默跳过是本项目反复踩过的坑。
        // ignore: avoid_print - 同上
        print(
          '宿主内存护栏未生效：只有 ${rssSamples.length} 轮样本 '
          '（需要 > $warmupSamples 轮）。 '
          '想验内存请把 MISTREAM_SOAK_CYCLES 提到 3 以上。',
        );
      }
    }, timeout: soakTimeout(maxCycles, maxSeconds));

    test(
      '持续崩溃触发熔断：主进程不崩，call 明确失败，reset 能重新尝试',
      () async {
        const maxRestart = 3;
        final crashScript = stubPath('rpc_child_crash.dart');

        final host = SpiderHost(
          executable: Platform.resolvedExecutable,
          arguments: ['run', crashScript],
          maxRestartAttempts: maxRestart,
          backoffFor: (_) => Duration.zero,
          launcher: tcpProcessLauncher(children: children),
          hostApi: HostApi(),
        );
        addTearDown(host.dispose);

        // 首次启动必然失败：子进程连上就崩，握手拿不到应答。
        final first = await host.start().timeout(const Duration(seconds: 30));
        expect(first.isErr, isTrue, reason: '子进程连上就崩，握手应当失败');

        // 之后由宿主自己重启，一直试到超过上限：总共 maxRestart + 1 个进程。
        final spawned = await waitFor(
          () => children.length >= maxRestart + 1,
          timeout: const Duration(seconds: 60),
        );
        expect(spawned, isTrue, reason: '应当一路重启到上限');

        // 熔断后再等一会儿，不该再冒新进程。
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(
          children,
          hasLength(maxRestart + 1),
          reason: '熔断后不该继续自动重启',
        );
        expect(host.isReady, isFalse);

        // 关键：宿主不可用时，调用方拿到的是**明确错误**，而不是异常或挂死。
        final call = await host
            .call('spider.create')
            .timeout(const Duration(seconds: 10));
        expect(call.isErr, isTrue);
        expect(
          call.errorOrNull?.code,
          ErrorCode.runtimeNotReady,
          reason: '不可用时要给出可读错误码，让上层能降级而不是崩',
        );

        // 等待者立刻拿到 false，不必空等满超时。
        final ready = await host.waitReady(
          timeout: const Duration(seconds: 10),
        );
        expect(ready, isFalse);

        // reset 复位熔断并重新尝试。
        final before = children.length;
        await host.reset().timeout(const Duration(seconds: 30));
        final respawned = await waitFor(
          () => children.length > before,
          timeout: const Duration(seconds: 30),
        );
        expect(respawned, isTrue, reason: 'reset 后应当重新尝试拉起子进程');
      },
      timeout: const Timeout(Duration(seconds: 180)),
    );

    test('启动阶段就抛异常时也会退避重试，直到熔断', () async {
      // 这条路径此前完全没有覆盖：launcher 自己抛异常（exe 不存在、权限被拒、
      // 端口耗尽），进程根本没起来，走的是 `start()` 的 catch 分支，而不是
      // 「进程退出 → 重启」。不挂重试的话宿主会**永久停在未就绪态**。
      //
      // 不是假想：2 小时长跑第 8660 轮就是这么红的 —— I: 盘的
      // `.dart_tool/package_config.json` 被系统拒绝访问，子进程起不来。
      var attempts = 0;
      const maxRestart = 2;
      final host = SpiderHost(
        executable: Platform.resolvedExecutable,
        arguments: const ['run', '不存在的桩.dart'],
        maxRestartAttempts: maxRestart,
        backoffFor: (_) => Duration.zero,
        launcher: (executable, args) async {
          attempts++;
          throw ProcessException(executable, args, '注入的启动失败', 5);
        },
        hostApi: HostApi(),
      );
      addTearDown(host.dispose);

      final first = await host.start().timeout(const Duration(seconds: 10));
      expect(first.isErr, isTrue, reason: '启动失败应当如实返回 Err');

      // 首次 + 最多 maxRestart 次自动重试。
      final retried = await waitFor(
        () => attempts >= maxRestart + 1,
        timeout: const Duration(seconds: 10),
      );
      expect(retried, isTrue, reason: '启动失败也必须走退避重启，否则宿主永久失能');

      // 熔断后不再重试，与「进程崩溃」用同一把上限。
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(attempts, maxRestart + 1, reason: '熔断后不该继续重试');
      expect(host.isTripped, isTrue);
      expect(host.isReady, isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('dispose 后不留孤儿进程', () async {
      final host = newHost(threshold: 999);
      await host.start().timeout(const Duration(seconds: 30));
      expect(children, hasLength(1));

      await host.dispose();

      for (var i = 0; i < children.length; i++) {
        await children[i].process.exitCode.timeout(
          const Duration(seconds: 10),
          onTimeout: () => fail('dispose 后第 $i 个子进程仍在运行'),
        );
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

/// 长跑用例的超时预算。
///
/// `package:test` 默认单测只给 **30 秒**，长跑必然被框架掐断 —— 报错是
/// `TimeoutException after 0:00:30`，看起来像宿主挂了，实际是配置没放开。
/// 8 轮的短跑约 14 秒，刚好躲过默认值，所以这个坑要跑到几十轮才暴露。
Timeout soakTimeout(int cycles, int seconds) {
  final budget = seconds > 0 ? seconds : cycles * 10;
  return Timeout(Duration(seconds: budget + 120));
}

/// 读一个整型环境变量，缺失或非法时用 [fallback]。
int envInt(String name, int fallback) {
  final raw = Platform.environment[name];
  if (raw == null || raw.isEmpty) return fallback;
  return int.tryParse(raw) ?? fallback;
}

/// 轮询等条件成立，超时返回 `false`（真进程启动没有假进程那么快）。
Future<bool> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return true;
}

/// 字节数转 MB 文案，供打印核对。
String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
