/// 续播端到端验收（ROADMAP M5 出口标准「关闭重开能从上次位置续播」）。
///
/// 覆盖的是**完整链路**：历史表里已有一部影片的观看进度 → 重新进入播放页
/// → 读到该进度 → 首个播放证据出现后 seek 到续播点。同时验证两条不续播的
/// 边界（进度太靠前、已接近片尾）在真实页面上也确实不 seek。
///
/// 这里驱动真实的 [PlayerPageWrapper]，只把两处外部依赖换成受控实现：
/// 播放引擎（`FakePlayerEngine`，位置可手动推进）与装配（内存库 + mock 源）。
/// 这是该出口标准此前唯一无法自动化的部分——续播判断原先内嵌在 State 里
/// 且依赖全局装配。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/app/router.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:mistream/application/config_install_service.dart';
import 'package:mock_source_server/mock_source_server.dart';
import 'package:player_engine/testing.dart' show FakePlayerEngine;
import 'package:storage/storage.dart';

void main() {
  // 放行真实 HttpClient。
  //
  // `flutter_test` 的 `TestWidgetsFlutterBinding` 初始化时会把
  // `HttpOverrides.global` 换成 mock 实现，此后**所有** HTTP 请求一律返回 400
  // （`_binding_io.dart` 的 `setupHttpOverrides`）。这条保护是防 widget 测试误打
  // 真实网络，但本文件的「受控外部依赖」恰恰就是本地 `MockSourceServer`，
  // 必须放行 —— 否则 `setUp` 里的 `installFromUrl` 直接报
  // `订阅拉取失败：HTTP 400 · 0 字节`，5 条用例全部在 setUp 就挂。
  //
  // mock 只在 binding 初始化时装**一次**（不是每个用例重设），而 `testWidgets`
  // 在 `main()` 注册阶段就把 binding 建好了，所以在这里置 null 能一直生效。
  setUpAll(() {
    HttpOverrides.global = null;
  });

  late MockSourceServer server;
  late AppDatabase db;
  late Repositories repositories;
  late AppAssembly assembly;

  setUp(() async {
    server = MockSourceServer();
    await server.start();
    db = AppDatabase.inMemory();
    repositories = Repositories(db);
    assembly = AppAssembly(db, repositories);
    // 导入 mock 配置，拿到真实站点与播放地址。
    final install = await ConfigInstallService(
      repositories,
    ).installFromUrl('${server.baseUrl}/config.json');
    expect(install.isOk, isTrue, reason: install.errorOrNull?.message);
  });

  tearDown(() async {
    assembly.dispose();
    await db.close();
    await server.close();
  });

  /// 取 type=1 站点（HTTP 运行时，地址由 mock server 提供）。
  Future<Site> httpSite() async {
    final sites = await repositories.sites.enabled();
    return sites.firstWhere((site) => site.typeCode == 1);
  }

  /// 预置一条观看历史。
  Future<void> seedHistory({
    required int siteId,
    required int positionMs,
    required int durationMs,
  }) async {
    await repositories.histories.upsert(
      siteId: siteId,
      vodId: '1001',
      vodName: '测试电影',
      vodPic: null,
      flag: 'qiyi',
      episodeName: '第1集',
      positionMs: positionMs,
      durationMs: durationMs,
    );
  }

  /// 挂载播放页并等到引擎就绪。
  ///
  /// ⚠️ `_init()` 里要**真发一次 HTTP**（`playUseCase.getPlayableSource` 对
  /// type=1 站点会去拉 mock server 的 `api.php`），而 `testWidgets` 默认跑在
  /// FakeAsync 里。只 `pump` 假时钟是不够的：socket 的完成回调来自**真实**事件
  /// 循环，而它在假 zone 里排队的后续微任务要等 `pump` 才刷 —— 两条时间线得
  /// 交替推进，否则 `_init()` 会一直挂在 `getPlayableSource` 上。
  ///
  /// 所以每轮先 `runAsync` 让真实事件循环走一小段，再 `pump` 刷一次假时钟。
  /// （`runAsync` 会 fork 一个用真实定时器/微任务的 zone，是 Flutter 给这种
  /// 「必须真异步」场景的官方口子。）
  Future<FakePlayerEngine> pumpPlayer(
    WidgetTester tester, {
    required int siteId,
    required FakePlayerEngine engine,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPageWrapper(
          siteId: siteId,
          vodId: '1001',
          flag: 'qiyi',
          title: '第1集',
          assembly: assembly,
          engineFactory: () => engine,
        ),
      ),
    );
    // 等异步初始化链：取地址 → open → attach → 读历史。
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    return engine;
  }

  testWidgets('历史进度在中间时，重开播放页会 seek 到上次位置', (tester) async {
    final site = await httpSite();
    const resumeAt = Duration(minutes: 12);
    await seedHistory(
      siteId: site.id,
      positionMs: resumeAt.inMilliseconds,
      durationMs: const Duration(minutes: 45).inMilliseconds,
    );

    final engine = FakePlayerEngine(mediaDuration: const Duration(minutes: 45));
    await pumpPlayer(tester, siteId: site.id, engine: engine);

    // 起播后内核通常从 0 开始，位置还在开头——此时应执行一次续播 seek。
    expect(engine.seekCount, greaterThan(0), reason: '应至少发生一次续播 seek');
    expect(
      engine.lastSeekTarget,
      resumeAt,
      reason: '续播目标应等于历史记录的位置',
    );
  });

  testWidgets('历史进度不足 5s 时不续播', (tester) async {
    final site = await httpSite();
    await seedHistory(
      siteId: site.id,
      positionMs: const Duration(seconds: 3).inMilliseconds,
      durationMs: const Duration(minutes: 45).inMilliseconds,
    );

    final engine = FakePlayerEngine(mediaDuration: const Duration(minutes: 45));
    await pumpPlayer(tester, siteId: site.id, engine: engine);

    expect(engine.seekCount, 0, reason: '刚开头几秒不该快进');
  });

  testWidgets('历史进度已接近片尾时不续播', (tester) async {
    final site = await httpSite();
    await seedHistory(
      siteId: site.id,
      // 距片尾仅 10s，属「已看完」。
      positionMs: (const Duration(minutes: 45) - const Duration(seconds: 10))
          .inMilliseconds,
      durationMs: const Duration(minutes: 45).inMilliseconds,
    );

    final engine = FakePlayerEngine(mediaDuration: const Duration(minutes: 45));
    await pumpPlayer(tester, siteId: site.id, engine: engine);

    expect(engine.seekCount, 0, reason: '看完的内容应从头开始，而非跳到片尾');
  });

  testWidgets('无历史记录时不执行续播 seek', (tester) async {
    final site = await httpSite();
    final engine = FakePlayerEngine(mediaDuration: const Duration(minutes: 45));
    await pumpPlayer(tester, siteId: site.id, engine: engine);

    expect(engine.seekCount, 0);
  });

  testWidgets('播放进度会被写回历史（周期落库）', (tester) async {
    final site = await httpSite();
    final engine = FakePlayerEngine(mediaDuration: const Duration(minutes: 45));
    await pumpPlayer(tester, siteId: site.id, engine: engine);

    // 模拟播到 8 分钟。
    engine.advance(const Duration(minutes: 8));
    await tester.pump();

    // 等一次周期落库（实现里是 5s 一次）。
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));

    final history = await repositories.histories.byVod(site.id, '1001');
    expect(history, isNotNull, reason: '播放中应把进度落库，供下次续播');
    expect(history!.positionMs, greaterThan(0));
  });
}
